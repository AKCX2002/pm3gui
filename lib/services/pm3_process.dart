/// PM3 process manager — wraps the pm3 CLI binary via dart:io Process.
///
/// Design mirrors Proxmark3GUI/src/common/pm3process.cpp:
///   - Persistent interactive session via stdin/stdout pipes
///   - Single-command execution via -c flag
///   - Connection detection by watching for "os:" prompt
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Connection state of the PM3 client process.
enum Pm3State { disconnected, connecting, connected }

/// Wraps a pm3 CLI process for communication.
class Pm3Process {
  Process? _process;
  Pm3State _state = Pm3State.disconnected;
  String _version = '';
  String _lastError = '';
  DateTime? _lastConnectAttempt;

  /// Stream of lines from pm3 stdout/stderr.
  final _outputController = StreamController<String>.broadcast();

  /// Stream of state changes.
  final _stateController = StreamController<Pm3State>.broadcast();

  /// Accumulated output buffer for response matching.
  final _responseBuffer = StringBuffer();

  Stream<String> get outputStream => _outputController.stream;
  Stream<Pm3State> get stateStream => _stateController.stream;
  Pm3State get state => _state;
  String get version => _version;
  String get lastError => _lastError;
  bool get isConnected => _state == Pm3State.connected;

  /// Minimum interval between connect attempts (prevent retry storm).
  static const _connectCooldown = Duration(seconds: 3);

  /// Resolve pm3 executable path.
  ///
  /// Tries in order:
  ///  1. User-supplied path if it exists as absolute
  ///  2. User-supplied path relative to common PM3 root dirs
  ///  3. 'proxmark3' on system PATH
  ///  4. Guessed locations based on the app's own directory
  ///
  /// Returns a record (resolvedPath, workingDirectory?) or null.
  static (String, String?)? resolvePm3Path(String userPath) {
    // 1. Try as-is (absolute or cwd-relative)
    if (File(userPath).existsSync()) {
      // Determine working directory for relative scripts like "./pm3"
      final file = File(userPath);
      return (file.absolute.path, file.absolute.parent.path);
    }

    // 2. Well-known locations
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

    // 3. Check PATH via `which`
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

  /// Connect to PM3 device.
  ///
  /// [pm3Path] - path to pm3 executable (e.g., "./pm3" or full path)
  /// [port] - serial port (e.g., "/dev/ttyACM0", "COM3")
  Future<bool> connect(String pm3Path, String port) async {
    // Cooldown — prevent retry storms
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
      // Resolve the actual executable path
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

      // Launch pm3 with -p port -f (flush mode for real-time output)
      _process = await Process.start(
        execPath,
        ['-p', port, '-f'],
        workingDirectory: workDir,
        mode: ProcessStartMode.normal,
      );

      final completer = Completer<bool>();
      var connected = false;

      // Listen to stdout
      _process!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        _outputController.add(line);
        _responseBuffer.writeln(line);

        // Detect fatal errors — stop immediately
        if (_detectFatalError(line)) {
          if (!completer.isCompleted) completer.complete(false);
          return;
        }

        // Detect successful connection (pm3 prints OS info on connect)
        if (!connected && _isConnectionPrompt(line)) {
          connected = true;
          _extractVersion(line);
          _setState(Pm3State.connected);
          if (!completer.isCompleted) completer.complete(true);
        }
      });

      // Listen to stderr
      _process!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        _outputController.add('[ERR] $line');
        _detectFatalError(line);
      });

      // Handle process exit
      _process!.exitCode.then((code) {
        _outputController.add('[PM3 进程退出, code=$code]');
        if (_state != Pm3State.disconnected) {
          _setState(Pm3State.disconnected);
        }
        _process = null;
      });

      // Wait for connection with timeout
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

  /// Execute a single command and return full output.
  /// Uses pm3 -c "command" for non-interactive execution.
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

  /// Send a command to the interactive session.
  Future<void> sendCommand(String command) async {
    if (_process == null || _state != Pm3State.connected) {
      _outputController.add('[Not connected]');
      return;
    }
    _responseBuffer.clear();
    _outputController.add('[pm3] $command');
    _process!.stdin.writeln(command);
    await _process!.stdin.flush();
  }

  /// Send command and wait for output to stabilize.
  Future<String> sendCommandAndWait(String command,
      {Duration timeout = const Duration(seconds: 10)}) async {
    if (_process == null || _state != Pm3State.connected) {
      return '[Not connected]';
    }

    _responseBuffer.clear();
    _process!.stdin.writeln(command);
    await _process!.stdin.flush();

    // Wait for output to stop arriving
    var lastLength = 0;
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 200));
      final currentLength = _responseBuffer.length;
      if (currentLength > 0 && currentLength == lastLength) {
        break; // Output stabilized
      }
      lastLength = currentLength;
    }

    return _responseBuffer.toString();
  }

  /// Disconnect from PM3.
  Future<void> disconnect() async {
    if (_process != null) {
      try {
        _process!.stdin.writeln('quit');
        await _process!.stdin.flush();
        // Give it a moment to exit gracefully
        await Future.delayed(const Duration(milliseconds: 500));
        _process!.kill();
      } catch (_) {}
      _process = null;
    }
    _setState(Pm3State.disconnected);
  }

  void dispose() {
    disconnect();
    _outputController.close();
    _stateController.close();
  }

  /// Detect fatal errors that mean we should stop trying.
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

  // Detect connection success from output line
  // Matches Proxmark3GUI pattern: QRegularExpression("(os:\\s+|OS\\.+\\s+)")
  bool _isConnectionPrompt(String line) {
    return RegExp(r'(os:\s+|OS\.+\s+)', caseSensitive: false).hasMatch(line) ||
        line.toLowerCase().contains('communicating with pm3 over usb-cdc') ||
        line.contains('[usb]') ||
        line.contains('[bt]') ||
        line.contains('pm3 -->');
  }

  void _extractVersion(String line) {
    // Try to extract version from e.g. "os: ... v4.16717"
    final match = RegExp(r'v[\d.]+').firstMatch(line);
    if (match != null) {
      _version = match.group(0) ?? '';
    }
  }

  void _setState(Pm3State newState) {
    _state = newState;
    _stateController.add(newState);
  }
}
