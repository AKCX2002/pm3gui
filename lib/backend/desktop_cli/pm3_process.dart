/// PM3 进程管理器 — 通过 dart:io Process 包装 pm3 命令行二进制文件
///
/// 设计参考 Proxmark3GUI/src/common/pm3process.cpp:
///   - 通过 stdin/stdout 管道实现持久化交互会话
///   - 原生客户端通过 -p/-f 进入交互会话
///   - 官方 Windows pm3.bat 通过 cmd.exe 保留 stdin/stdout 交互
///   - 通过真实 pm3/USB/BT/OS 提示符检测连接状态
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// PM3 客户端进程的连接状态
enum Pm3ProcessState {
  disconnected, // 未连接
  connecting, // 正在连接
  connected // 已连接
}

/// 交互式 PM3 子进程所需的最小句柄，供生命周期测试注入可控实现。
abstract interface class Pm3ProcessHandle {
  Stream<List<int>> get stdout;
  Stream<List<int>> get stderr;
  Future<int> get exitCode;

  Future<void> writeLine(String line);
  Future<bool> terminate({required bool force});
}

typedef Pm3ProcessStarter = Future<Pm3ProcessHandle> Function(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
});

final class _IoPm3ProcessHandle implements Pm3ProcessHandle {
  _IoPm3ProcessHandle(this._process);

  final Process _process;

  @override
  Stream<List<int>> get stdout => _process.stdout;

  @override
  Stream<List<int>> get stderr => _process.stderr;

  @override
  Future<int> get exitCode => _process.exitCode;

  @override
  Future<bool> terminate({required bool force}) async {
    if (!Platform.isWindows) {
      return _process.kill(
        force ? ProcessSignal.sigkill : ProcessSignal.sigterm,
      );
    }

    final arguments = ['/PID', '${_process.pid}', '/T', '/F'];
    final result = await Process.run(
      'taskkill',
      arguments,
      runInShell: false,
    );
    if (result.exitCode == 0) return true;
    final detail = '${result.stderr}${result.stdout}'.trim();
    throw ProcessException(
      'taskkill',
      arguments,
      '整树终止失败 (exit=${result.exitCode})${detail.isEmpty ? '' : ': $detail'}',
      result.exitCode,
    );
  }

  @override
  Future<void> writeLine(String line) async {
    _process.stdin.writeln(line);
    await _process.stdin.flush();
  }
}

Future<Pm3ProcessHandle> _startPm3Process(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
}) async =>
    _IoPm3ProcessHandle(await Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      mode: ProcessStartMode.normal,
    ));

/// 包装 pm3 命令行进程以进行通信
class Pm3Process {
  Pm3ProcessHandle? _process; // PM3 进程实例
  StreamSubscription<String>? _stdoutSubscription;
  StreamSubscription<String>? _stderrSubscription;
  Future<bool>? _connectingFuture;
  Future<void>? _disconnectingFuture;
  Future<Pm3ProcessHandle>? _startingFuture;
  Pm3ProcessHandle? _unownedProcess;
  Future<void>? _unownedTermination;
  Completer<bool>? _connectionCompleter;
  bool _disposed = false;
  int _processGeneration = 0;
  Pm3ProcessState _state = Pm3ProcessState.disconnected; // 当前连接状态
  String _version = ''; // PM3 版本信息
  String _lastError = ''; // 最后一次错误信息
  DateTime? _lastConnectAttempt; // 最后一次连接尝试时间

  /// 来自 pm3 stdout/stderr 的行流
  final _outputController = StreamController<String>.broadcast(sync: true);

  /// 状态变化的流
  final _stateController =
      StreamController<Pm3ProcessState>.broadcast(sync: true);

  /// 用于响应匹配的累积输出缓冲区
  final _responseBuffer = StringBuffer();

  Stream<String> get outputStream => _outputController.stream;
  Stream<Pm3ProcessState> get stateStream => _stateController.stream;
  Pm3ProcessState get state => _state;
  String get version => _version;
  String get lastError => _lastError;
  bool get isConnected => _state == Pm3ProcessState.connected;

  /// 连接尝试之间的最小间隔（防止重试风暴）
  static const _defaultConnectCooldown = Duration(seconds: 3);

  Pm3Process({
    Duration connectCooldown = _defaultConnectCooldown,
    Duration gracefulExitTimeout = const Duration(milliseconds: 500),
    Duration connectTimeout = const Duration(seconds: 15),
    Duration killExitTimeout = const Duration(seconds: 2),
    Pm3ProcessStarter processStarter = _startPm3Process,
  })  : _connectCooldown = connectCooldown,
        _gracefulExitTimeout = gracefulExitTimeout,
        _connectTimeout = connectTimeout,
        _killExitTimeout = killExitTimeout,
        _processStarter = processStarter;

  final Duration _connectCooldown;
  final Duration _gracefulExitTimeout;
  final Duration _connectTimeout;
  final Duration _killExitTimeout;
  final Pm3ProcessStarter _processStarter;

  /// 解析 pm3 可执行文件路径
  ///
  /// 按以下顺序尝试：
  ///  1. 用户提供的绝对或相对路径
  ///  2. Windows/Linux 系统 PATH
  ///
  /// 返回记录 (resolvedPath, workingDirectory?) 或 null
  static (String, String?)? resolvePm3Path(String userPath) {
    // 1. 直接尝试（绝对路径或相对当前目录）
    if (File(userPath).existsSync()) {
      // 为相对脚本如 "./pm3" 确定工作目录
      final file = File(userPath);
      return (file.absolute.path, file.absolute.parent.path);
    }

    // 2. 通过平台命令检查 PATH
    try {
      final result = Process.runSync(
        Platform.isWindows ? 'where' : 'which',
        [userPath],
      );
      if (result.exitCode == 0) {
        final p =
            (result.stdout as String).trim().split(RegExp(r'[\r\n]+')).first;
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
  Future<bool> connect(
    String pm3Path,
    String port, {
    List<String> arguments = const [],
    String? workingDirectory,
  }) {
    if (_disposed) {
      _lastError = 'PM3 进程管理器已释放';
      return Future.value(false);
    }
    if (_connectingFuture != null) return _connectingFuture!;

    late final Future<bool> connection;
    connection = _connect(
      pm3Path,
      port,
      arguments: arguments,
      workingDirectory: workingDirectory,
    ).whenComplete(() {
      if (identical(_connectingFuture, connection)) {
        _connectingFuture = null;
      }
    });
    _connectingFuture = connection;
    return connection;
  }

  Future<bool> _connect(
    String pm3Path,
    String port, {
    required List<String> arguments,
    required String? workingDirectory,
  }) async {
    // 冷却期 — 防止重试风暴
    if (_lastConnectAttempt != null) {
      final elapsed = DateTime.now().difference(_lastConnectAttempt!);
      if (elapsed < _connectCooldown) {
        final wait = _connectCooldown - elapsed;
        _lastError = '请等待 ${wait.inSeconds + 1} 秒后再试';
        _emitOutput('[请等待冷却: ${wait.inSeconds + 1}s]');
        return false;
      }
    }
    _lastConnectAttempt = DateTime.now();
    _lastError = '';

    if (_state != Pm3ProcessState.disconnected) {
      await disconnect();
    }

    _setState(Pm3ProcessState.connecting);
    final connectionGeneration = ++_processGeneration;

    try {
      // 解析实际可执行文件路径
      final resolved = resolvePm3Path(pm3Path);
      if (resolved == null) {
        _lastError = '找不到 PM3 程序: $pm3Path\n'
            'Windows 请优先选择官方发行包根目录的 pm3.bat；'
            'Linux 请选择 proxmark3';
        _emitOutput('[错误] $_lastError');
        _setState(Pm3ProcessState.disconnected);
        return false;
      }

      final (execPath, resolvedWorkDir) = resolved;
      final workDir = workingDirectory ?? resolvedWorkDir;
      _emitOutput('[使用 PM3: $execPath]');
      if (workDir != null) {
        _emitOutput('[工作目录: $workDir]');
      }

      // 官方 Windows 发行包以根目录 pm3.bat 作为入口。脚本会自行完成
      // 环境初始化并由内部 pm3 客户端自动探测设备，因此不能假设它会
      // 转发 GUI 侧的端口或启动参数。
      final isWindowsBatch = Platform.isWindows &&
          (execPath.toLowerCase().endsWith('.bat') ||
              execPath.toLowerCase().endsWith('.cmd'));
      final launchExecutable = isWindowsBatch ? 'cmd.exe' : execPath;
      final launchArguments = isWindowsBatch
          ? ['/d', '/c', 'call', execPath]
          : [...arguments, '-p', port, '-f'];
      final starting = _processStarter(
        launchExecutable,
        launchArguments,
        workingDirectory: workDir,
      );
      _startingFuture = starting;
      final process = await starting;
      if (identical(_startingFuture, starting)) {
        _startingFuture = null;
      }

      if (_disposed || connectionGeneration != _processGeneration) {
        await _terminateUnownedOnce(process);
        return false;
      }
      _process = process;

      final completer = Completer<bool>();
      _connectionCompleter = completer;
      var connected = false;
      var batchHandshakeSent = false;
      var stdoutPending = '';

      void handleStdoutRecord(String line) {
        if (!identical(_process, process) || _disposed) return;
        // 始终写入响应缓冲区，以便 sendCommandAndWait 等函数
        // 能够获得完整输出，即使 UI 出于限流而丢弃显示行。
        _responseBuffer.writeln(line);

        // 检测致命错误和连接提示
        if (_detectFatalError(line)) {
          _failConnecting(completer, 'PM3 stdout 出现致命错误');
          unawaited(_closeCurrentProcess(
            process,
            connectionGeneration,
            forceKill: true,
          ));
          return;
        }

        if (!connected &&
            _isConnectionPrompt(line, allowOsVersion: !isWindowsBatch)) {
          connected = true;
          _extractVersion(line);
          _setState(Pm3ProcessState.connected);
          if (!completer.isCompleted) completer.complete(true);
        }

        if (isWindowsBatch &&
            !connected &&
            !batchHandshakeSent &&
            line
                .toLowerCase()
                .contains('communicating with pm3 over usb-cdc')) {
          batchHandshakeSent = true;
          unawaited(() async {
            try {
              await process.writeLine('hw version');
            } catch (error) {
              if (!identical(_process, process) || _disposed) return;
              _lastError = 'PM3 BAT 只读握手写入失败: $error';
              _emitOutput('[错误] $_lastError');
              _failConnecting(completer, _lastError);
              await _closeCurrentProcess(
                process,
                connectionGeneration,
                forceKill: true,
              );
            }
          }());
        }

        // 所有记录直接发送给 UI，不做限流，避免长命令输出被截断。
        _emitOutput(line);
      }

      void handleStdoutChunk(String chunk) {
        if (!identical(_process, process) || _disposed) return;
        stdoutPending += chunk;
        while (true) {
          final newlineIndex = stdoutPending.indexOf('\n');
          if (newlineIndex < 0) break;
          var line = stdoutPending.substring(0, newlineIndex);
          stdoutPending = stdoutPending.substring(newlineIndex + 1);
          if (line.endsWith('\r')) line = line.substring(0, line.length - 1);
          handleStdoutRecord(line);
        }

        // RRG 交互提示符在等待 stdin 时通常没有换行。只对明确的
        // pm3 提示符提前提交片段；普通启动文本继续等待换行，避免把
        // "Communicating with PM3 over USB-CDC" 误判成连接成功。
        if (stdoutPending.contains('pm3 -->')) {
          final prompt = stdoutPending;
          stdoutPending = '';
          handleStdoutRecord(prompt);
        }
      }

      // 监听 stdout
      _stdoutSubscription = process.stdout.transform(utf8.decoder).listen(
        handleStdoutChunk,
        onError: (Object error, StackTrace stackTrace) {
          _failConnecting(completer, 'PM3 stdout 流错误: $error');
          unawaited(_closeCurrentProcess(
            process,
            connectionGeneration,
            forceKill: true,
          ));
        },
        onDone: () {
          if (stdoutPending.isNotEmpty) {
            handleStdoutRecord(stdoutPending);
            stdoutPending = '';
          }
          unawaited(_handleStreamClosed(
            process,
            connectionGeneration,
            completer,
            'stdout',
          ));
        },
      );

      // 监听 stderr
      _stderrSubscription = process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        if (!identical(_process, process) || _disposed) return;
        if (_detectFatalError(line)) {
          _failConnecting(completer, 'PM3 stderr 出现致命错误');
          unawaited(_closeCurrentProcess(
            process,
            connectionGeneration,
            forceKill: true,
          ));
          return;
        }
        _emitOutput('[ERR] $line');
      }, onError: (Object error, StackTrace stackTrace) {
        _failConnecting(completer, 'PM3 stderr 流错误: $error');
        unawaited(_closeCurrentProcess(
          process,
          connectionGeneration,
          forceKill: true,
        ));
      }, onDone: () {
        unawaited(_handleStreamClosed(
          process,
          connectionGeneration,
          completer,
          'stderr',
        ));
      });

      // 处理进程退出
      unawaited(process.exitCode.then<void>(
        (code) async {
          if (!identical(_process, process) || _disposed) return;
          _emitOutput('[PM3 进程退出, code=$code]');
          if (!connected) {
            _lastError = 'PM3 进程在连接提示前退出 (code=$code)';
            if (!completer.isCompleted) completer.complete(false);
          }
          await _closeCurrentProcess(process, connectionGeneration);
        },
        onError: (Object error, StackTrace stackTrace) async {
          _failConnecting(completer, 'PM3 进程退出状态错误: $error');
          await _closeCurrentProcess(
            process,
            connectionGeneration,
            forceKill: true,
          );
        },
      ));

      // 等待连接，带超时
      try {
        return await completer.future.timeout(_connectTimeout);
      } on TimeoutException {
        if (!connected && identical(_process, process)) {
          _lastError = '连接超时 (${_connectTimeout.inSeconds}s)，请检查设备是否已连接';
          _emitOutput('[连接超时]');
          await _closeCurrentProcess(
            process,
            connectionGeneration,
            requestQuit: true,
          );
        }
        return false;
      }
    } on ProcessException catch (e) {
      _startingFuture = null;
      _lastError = '无法启动 PM3 程序: ${e.message}\n'
          '路径: $pm3Path\n'
          '请检查路径是否正确，程序是否已编译';
      _emitOutput('[错误] $_lastError');
      if (connectionGeneration == _processGeneration) {
        _setState(Pm3ProcessState.disconnected);
      }
      return false;
    } catch (e) {
      _startingFuture = null;
      _lastError = '连接失败: $e';
      _emitOutput('[错误] $_lastError');
      if (connectionGeneration == _processGeneration) {
        _setState(Pm3ProcessState.disconnected);
      }
      return false;
    }
  }

  /// 向交互式会话发送命令
  Future<void> sendCommand(String command) async {
    if (_process == null || _state != Pm3ProcessState.connected) {
      _emitOutput('[未连接]');
      return;
    }
    _responseBuffer.clear();
    _emitOutput('[pm3] $command');
    await _process!.writeLine(command);
  }

  /// 发送命令并等待输出稳定
  /// [timeout] - 超时时间，默认为10秒
  /// Send a command and wait until output stabilizes or a known terminator
  /// pattern appears. This helps capture long multi-line tables (e.g. autopwn)
  /// that may finish with a table footer instead of a clear pause.
  Future<String> sendCommandAndWait(String command,
      {Duration timeout = const Duration(seconds: 10),
      RegExp? terminator}) async {
    if (_process == null || _state != Pm3ProcessState.connected) {
      return '[未连接]';
    }

    _responseBuffer.clear();
    _emitOutput('[pm3] $command');
    await _process!.writeLine(command);

    // Wait until either output stabilizes or a terminator pattern is observed.
    var lastLength = 0;
    final deadline = DateTime.now().add(timeout);
    // Default terminator: table footer or legend that many pm3 commands emit.
    final defaultTerminator = RegExp(r'-----\+-----\+|\[=\]\s*\(');
    final term = terminator ?? defaultTerminator;

    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 200));
      final current = _responseBuffer.toString();

      // If we detect a terminator string in the accumulated output, stop waiting
      if (term.hasMatch(current)) {
        break;
      }

      final currentLength = current.length;
      if (currentLength > 0 && currentLength == lastLength) {
        break; // output appears stable
      }
      lastLength = currentLength;
    }

    return _responseBuffer.toString();
  }

  /// 断开与 PM3 的连接
  Future<void> disconnect() {
    if (_disconnectingFuture != null) return _disconnectingFuture!;

    late final Future<void> disconnecting;
    disconnecting = _disconnect().whenComplete(() {
      if (identical(_disconnectingFuture, disconnecting)) {
        _disconnectingFuture = null;
      }
    });
    _disconnectingFuture = disconnecting;
    return disconnecting;
  }

  /// 释放资源
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    ++_processGeneration;
    final connectionCompleter = _connectionCompleter;
    if (connectionCompleter != null && !connectionCompleter.isCompleted) {
      connectionCompleter.complete(false);
    }
    _connectionCompleter = null;
    final process = _process;
    _process = null;
    final stdoutSubscription = _stdoutSubscription;
    final stderrSubscription = _stderrSubscription;
    _stdoutSubscription = null;
    _stderrSubscription = null;
    try {
      if (process != null) {
        // async 函数在首个 await 前立即尝试 kill；随后保持有限后台收束。
        unawaited(_consumeBackground(_killAndWait(process)));
      }
    } finally {
      unawaited(_cancelSubscription(stdoutSubscription));
      unawaited(_cancelSubscription(stderrSubscription));
      try {
        _outputController.close();
      } catch (_) {}
      try {
        _stateController.close();
      } catch (_) {}
    }
  }

  Future<void> _disconnect() async {
    final disconnectGeneration = ++_processGeneration;
    final connectionCompleter = _connectionCompleter;
    if (connectionCompleter != null && !connectionCompleter.isCompleted) {
      connectionCompleter.complete(false);
    }
    if (identical(_connectionCompleter, connectionCompleter)) {
      _connectionCompleter = null;
    }
    final process = _process;
    final starting = _startingFuture;
    try {
      if (process != null) {
        await _closeCurrentProcess(
          process,
          disconnectGeneration,
          requestQuit: true,
          publishDisconnected: false,
        );
      }
      if (starting != null) {
        try {
          final startedProcess = await starting;
          await _terminateUnownedOnce(startedProcess);
        } catch (error) {
          _recordLifecycleError('等待 PM3 启动失败: $error');
        }
      }
    } finally {
      if (!_disposed && disconnectGeneration == _processGeneration) {
        _setState(Pm3ProcessState.disconnected);
      }
    }
  }

  Future<void> _closeCurrentProcess(
    Pm3ProcessHandle process,
    int generation, {
    bool requestQuit = false,
    bool forceKill = false,
    bool publishDisconnected = true,
  }) async {
    if (!identical(_process, process)) return;
    _process = null;
    final stdoutSubscription = _stdoutSubscription;
    final stderrSubscription = _stderrSubscription;
    _stdoutSubscription = null;
    _stderrSubscription = null;
    try {
      if (requestQuit) {
        try {
          await process.writeLine('quit');
        } catch (error) {
          _recordLifecycleError('发送 quit 失败: $error');
        }
        final exited = await _waitForExit(process, _gracefulExitTimeout);
        if (!exited) forceKill = true;
      }
      if (forceKill) {
        await _killAndWait(process);
      }
    } finally {
      await _cancelSubscription(stdoutSubscription);
      await _cancelSubscription(stderrSubscription);
      if (publishDisconnected &&
          !_disposed &&
          generation == _processGeneration) {
        _setState(Pm3ProcessState.disconnected);
      }
    }
  }

  Future<void> _terminateUnownedOnce(Pm3ProcessHandle process) {
    if (identical(_unownedProcess, process) && _unownedTermination != null) {
      return _unownedTermination!;
    }
    _unownedProcess = process;
    late final Future<void> termination;
    termination = _killAndWait(process).whenComplete(() {
      if (identical(_unownedTermination, termination)) {
        _unownedProcess = null;
        _unownedTermination = null;
      }
    });
    _unownedTermination = termination;
    return termination;
  }

  Future<void> _handleStreamClosed(
    Pm3ProcessHandle process,
    int generation,
    Completer<bool> completer,
    String streamName,
  ) async {
    if (!identical(_process, process) || _disposed) return;
    // 管道关闭通常早于 exitCode 回调；短暂等待能保留真实退出码，
    // 但绝不退回到连接的 15 秒超时。
    try {
      final code = await process.exitCode.timeout(
        const Duration(milliseconds: 100),
      );
      if (!identical(_process, process) || _disposed) return;
      _emitOutput('[PM3 进程退出, code=$code]');
      _lastError = 'PM3 进程在连接提示前退出 (code=$code)';
      _failConnecting(completer, _lastError);
      await _closeCurrentProcess(process, generation);
      return;
    } on TimeoutException {
      // 输出管道孤立关闭，以下路径强制收口该进程。
    } catch (error) {
      _recordLifecycleError('PM3 $streamName 流关闭后读取退出状态失败: $error');
    }
    if (!identical(_process, process) || _disposed) return;
    _failConnecting(completer, 'PM3 $streamName 流已关闭');
    await _closeCurrentProcess(process, generation, forceKill: true);
  }

  Future<bool> _waitForExit(Pm3ProcessHandle process, Duration timeout) async {
    try {
      await process.exitCode.timeout(timeout);
      return true;
    } on TimeoutException {
      return false;
    } catch (error) {
      _recordLifecycleError('等待 PM3 退出失败: $error');
      return false;
    }
  }

  Future<void> _killAndWait(Pm3ProcessHandle process) async {
    final terminated = await _tryTerminate(process, force: false);
    if (!terminated) {
      _recordLifecycleError('终止 PM3 进程失败: TERM/整树终止未成功');
    }
    var exited = await _waitForExit(process, _killExitTimeout);
    if (!exited) {
      final forceTerminated = await _tryTerminate(process, force: true);
      if (!forceTerminated) {
        _recordLifecycleError('强制终止 PM3 进程失败: KILL/整树终止未成功');
      }
      exited = await _waitForExit(process, _killExitTimeout);
    }
    if (!exited) {
      _recordLifecycleError('终止 PM3 后等待退出超时');
    }
  }

  Future<bool> _tryTerminate(
    Pm3ProcessHandle process, {
    required bool force,
  }) async {
    try {
      final terminated = await process.terminate(force: force);
      if (!terminated) {
        _recordLifecycleError(
          '终止 PM3 进程失败: ${force ? 'KILL' : 'TERM'} 返回 false',
        );
      }
      return terminated;
    } catch (error) {
      _recordLifecycleError('终止 PM3 进程失败: $error');
      return false;
    }
  }

  Future<void> _consumeBackground(Future<void> future) async {
    try {
      await future;
    } catch (_) {
      // dispose 不可把后台收束异常泄露到 zone。
    }
  }

  Future<void> _cancelSubscription(
      StreamSubscription<String>? subscription) async {
    if (subscription == null) return;
    try {
      await subscription.cancel();
    } catch (_) {
      // 所有取消 Future 都在此处被消费，避免进入未处理 zone error。
    }
  }

  void _failConnecting(Completer<bool> completer, String fallbackError) {
    if (_disposed) return;
    if (_lastError.isEmpty) _lastError = fallbackError;
    if (!completer.isCompleted) completer.complete(false);
  }

  void _recordLifecycleError(String message) {
    if (_lastError.isEmpty) {
      _lastError = message;
    } else if (!_lastError.contains(message)) {
      _lastError = '$_lastError；$message';
    }
    _emitOutput('[错误] $message');
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

  // 原生客户端保留旧 OS 版本行兼容；Windows BAT 的握手命令会在提示符
  // 前输出 OS 信息，因此 BAT 必须等到真实 pm3 提示符。
  bool _isConnectionPrompt(String line, {required bool allowOsVersion}) {
    return line.contains('pm3 -->') ||
        (allowOsVersion &&
            RegExp(r'(os:\s+|OS\.+\s+)', caseSensitive: false).hasMatch(line));
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
  void _setState(Pm3ProcessState newState) {
    if (_disposed || _state == newState) return;
    _state = newState;
    _stateController.add(newState);
  }

  void _emitOutput(String line) {
    if (!_disposed) _outputController.add(line);
  }
}
