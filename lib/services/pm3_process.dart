/// PM3 进程管理器 — 通过 dart:io Process 包装 pm3 命令行二进制文件
///
/// 设计参考 Proxmark3GUI/src/common/pm3process.cpp:
///   - 通过 stdin/stdout 管道实现持久化交互会话
///   - 通过 -c 标志执行单个命令
///   - 通过监视 "os:" 提示符检测连接状态
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// PM3 客户端进程的连接状态
enum Pm3State { 
  disconnected,  // 未连接
  connecting,    // 正在连接
  connected      // 已连接
}

/// 包装 pm3 命令行进程以进行通信
class Pm3Process {
  Process? _process;          // PM3 进程实例
  Pm3State _state = Pm3State.disconnected;  // 当前连接状态
  String _version = '';       // PM3 版本信息
  String _lastError = '';     // 最后一次错误信息
  DateTime? _lastConnectAttempt;  // 最后一次连接尝试时间

  /// 来自 pm3 stdout/stderr 的行流
  final _outputController = StreamController<String>.broadcast();

  /// 状态变化的流
  final _stateController = StreamController<Pm3State>.broadcast();

  /// 用于响应匹配的累积输出缓冲区
  final _responseBuffer = StringBuffer();

  Stream<String> get outputStream => _outputController.stream;
  Stream<Pm3State> get stateStream => _stateController.stream;
  Pm3State get state => _state;
  String get version => _version;
  String get lastError => _lastError;
  bool get isConnected => _state == Pm3State.connected;

  /// 连接尝试之间的最小间隔（防止重试风暴）
  static const _connectCooldown = Duration(seconds: 3);

  /// 解析 pm3 可执行文件路径
  ///
  /// 按以下顺序尝试：
  ///  1. 如果用户提供的路径作为绝对路径存在
  ///  2. 用户提供的路径相对于常见 PM3 根目录
  ///  3. 系统 PATH 上的 'proxmark3'
  ///  4. 基于应用自身目录的猜测位置
  ///
  /// 返回记录 (resolvedPath, workingDirectory?) 或 null
  static (String, String?)? resolvePm3Path(String userPath) {
    // 1. 直接尝试（绝对路径或相对当前目录）
    if (File(userPath).existsSync()) {
      // 为相对脚本如 "./pm3" 确定工作目录
      final file = File(userPath);
      return (file.absolute.path, file.absolute.parent.path);
    }

    // 2. 常见位置
    final candidates = [
      '/root/dev/proxmark3/pm3',
      '/root/dev/proxmark3/client/proxmark3',
      '/usr/local/bin/proxmark3',
      '/usr/bin/proxmark3',
    ];
    for (final c in candidates) {
      if (File(c).existsSync()) {
        return (c, File(c).parent.path);
      }
    }

    // 3. 通过 `which` 检查 PATH
    try {
      final result = Process.runSync('which', [userPath]);
      if (result.exitCode == 0) {
        final p = (result.stdout as String).trim();
        if (p.isNotEmpty && File(p).existsSync()) {
          return (p, null);
        }
      }
    } catch (_) {}

    return null;
  }

  /// 连接到 PM3 设备
  ///
  /// [pm3Path] - pm3 可执行文件路径（例如 "./pm3" 或完整路径）
  /// [port] - 串口（例如 "/dev/ttyACM0", "COM3"）
  Future<bool> connect(String pm3Path, String port) async {
    // 冷却期 — 防止重试风暴
    if (_lastConnectAttempt != null) {
      final elapsed = DateTime.now().difference(_lastConnectAttempt!);
      if (elapsed < _connectCooldown) {
        final wait = _connectCooldown - elapsed;
        _lastError = '请等待 ${wait.inSeconds + 1} 秒后再试';
        _outputController.add('[请等待冷却: ${wait.inSeconds + 1}s]');
        return false;
      }
    }
    _lastConnectAttempt = DateTime.now();
    _lastError = '';

    if (_state != Pm3State.disconnected) {
      await disconnect();
    }

    _setState(Pm3State.connecting);

    try {
      // 解析实际可执行文件路径
      final resolved = resolvePm3Path(pm3Path);
      if (resolved == null) {
        _lastError = '找不到 PM3 程序: $pm3Path\n'
            '请在连接页面设置正确的 PM3 程序路径，例如:\n'
            '  /root/dev/proxmark3/pm3\n'
            '  /usr/local/bin/proxmark3';
        _outputController.add('[错误] $_lastError');
        _setState(Pm3State.disconnected);
        return false;
      }

      final (execPath, workDir) = resolved;
      _outputController.add('[使用 PM3: $execPath]');
      if (workDir != null) {
        _outputController.add('[工作目录: $workDir]');
      }

      // 启动 pm3，使用 -p port -f（实时输出的刷新模式）
      _process = await Process.start(
        execPath,
        ['-p', port, '-f'],
        workingDirectory: workDir,
        mode: ProcessStartMode.normal,
      );

      final completer = Completer<bool>();
      var connected = false;

      // 监听 stdout
      _process!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        _outputController.add(line);
        _responseBuffer.writeln(line);

        // 检测致命错误 — 立即停止
        if (_detectFatalError(line)) {
          if (!completer.isCompleted) completer.complete(false);
          return;
        }

        // 检测成功连接（pm3 在连接时打印 OS 信息）
        if (!connected && _isConnectionPrompt(line)) {
          connected = true;
          _extractVersion(line);
          _setState(Pm3State.connected);
          if (!completer.isCompleted) completer.complete(true);
        }
      });

      // 监听 stderr
      _process!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        _outputController.add('[ERR] $line');
        _detectFatalError(line);
      });

      // 处理进程退出
      _process!.exitCode.then((code) {
        _outputController.add('[PM3 进程退出, code=$code]');
        if (_state != Pm3State.disconnected) {
          _setState(Pm3State.disconnected);
        }
        _process = null;
      });

      // 等待连接，带超时
      return await completer.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          if (!connected) {
            _lastError = '连接超时 (15s)，请检查设备是否已连接';
            _outputController.add('[连接超时]');
            disconnect();
          }
          return false;
        },
      );
    } on ProcessException catch (e) {
      _lastError = '无法启动 PM3 程序: ${e.message}\n'
          '路径: $pm3Path\n'
          '请检查路径是否正确，程序是否已编译';
      _outputController.add('[错误] $_lastError');
      _setState(Pm3State.disconnected);
      return false;
    } catch (e) {
      _lastError = '连接失败: $e';
      _outputController.add('[错误] $_lastError');
      _setState(Pm3State.disconnected);
      return false;
    }
  }

  /// 执行单个命令并返回完整输出
  /// 使用 pm3 -c "command" 进行非交互式执行
  Future<String> executeCommand(
    String pm3Path,
    String port,
    String command,
  ) async {
    try {
      final resolved = resolvePm3Path(pm3Path);
      if (resolved == null) {
        return '[错误] 找不到 PM3 程序: $pm3Path';
      }
      final (execPath, workDir) = resolved;
      final result = await Process.run(
        execPath,
        ['-p', port, '-c', command],
        workingDirectory: workDir,
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      return '${result.stdout}${result.stderr}';
    } catch (e) {
      return '[Error: $e]';
    }
  }

  /// 向交互式会话发送命令
  Future<void> sendCommand(String command) async {
    if (_process == null || _state != Pm3State.connected) {
      _outputController.add('[未连接]');
      return;
    }
    _responseBuffer.clear();
    _outputController.add('[pm3] $command');
    _process!.stdin.writeln(command);
    await _process!.stdin.flush();
  }

  /// 发送命令并等待输出稳定
  /// [timeout] - 超时时间，默认为10秒
  Future<String> sendCommandAndWait(String command,
      {Duration timeout = const Duration(seconds: 10)}) async {
    if (_process == null || _state != Pm3State.connected) {
      return '[未连接]';
    }

    _responseBuffer.clear();
    _process!.stdin.writeln(command);
    await _process!.stdin.flush();

    // 等待输出停止
    var lastLength = 0;
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 200));
      final currentLength = _responseBuffer.length;
      if (currentLength > 0 && currentLength == lastLength) {
        break; // 输出已稳定
      }
      lastLength = currentLength;
    }

    return _responseBuffer.toString();
  }

  /// 断开与 PM3 的连接
  Future<void> disconnect() async {
    if (_process != null) {
      try {
        _process!.stdin.writeln('quit');
        await _process!.stdin.flush();
        // 给它一点时间优雅退出
        await Future.delayed(const Duration(milliseconds: 500));
        _process!.kill();
      } catch (_) {}
      _process = null;
    }
    _setState(Pm3State.disconnected);
  }

  /// 释放资源
  void dispose() {
    disconnect();
    _outputController.close();
    _stateController.close();
  }

  /// 检测致命错误，这意味着我们应该停止尝试
  bool _detectFatalError(String line) {
    final lower = line.toLowerCase();

    if (lower.contains('claimed by another process') ||
        lower.contains('is claimed by')) {
      _lastError = '串口 已被其他进程占用\n'
          '请关闭其他使用该端口的程序（如另一个 pm3 终端）';
      return true;
    }
    if (lower.contains('no such file or directory') &&
        lower.contains('serial')) {
      _lastError = '串口设备不存在，请检查 PM3 是否已通过 USB 连接';
      return true;
    }
    if (lower.contains('permission denied')) {
      _lastError = '串口权限不足\n'
          '请尝试: sudo chmod 666 /dev/ttyACM0\n'
          '或将用户加入 dialout 组';
      return true;
    }
    if (lower.contains('error') && lower.contains('serial port')) {
      _lastError = '串口连接错误: $line';
      return true;
    }
    return false;
  }

  // 从输出行检测连接成功
  // 匹配 Proxmark3GUI 模式: QRegularExpression("(os:\s+|OS\.+\s+)")
  bool _isConnectionPrompt(String line) {
    return RegExp(r'(os:\s+|OS\.+\s+)', caseSensitive: false).hasMatch(line) ||
        line.toLowerCase().contains('communicating with pm3 over usb-cdc') ||
        line.contains('[usb]') ||
        line.contains('[bt]') ||
        line.contains('pm3 -->');
  }

  /// 从行中提取版本信息
  void _extractVersion(String line) {
    // 尝试从例如 "os: ... v4.16717" 中提取版本
    final match = RegExp(r'v[\d.]+').firstMatch(line);
    if (match != null) {
      _version = match.group(0) ?? '';
    }
  }

  /// 设置状态并通知监听器
  void _setState(Pm3State newState) {
    _state = newState;
    _stateController.add(newState);
  }
}
