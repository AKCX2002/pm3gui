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
  bool get isConnected => _state == Pm3State.connected;

  /// Connect to PM3 device.
  ///
  /// [pm3Path] - path to pm3 executable (e.g., "./pm3" or full path)
  /// [port] - serial port (e.g., "/dev/ttyACM0", "COM3")
  Future<bool> connect(String pm3Path, String port) async {
    if (_state != Pm3State.disconnected) {
      await disconnect();
    }

    _setState(Pm3State.connecting);

    try {
      // Launch pm3 with -p port -f (flush mode for real-time output)
      _process = await Process.start(
        pm3Path,
        ['-p', port, '-f'],
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
      });

      // Handle process exit
      _process!.exitCode.then((code) {
        _outputController.add('[PM3 process exited with code $code]');
        _setState(Pm3State.disconnected);
        _process = null;
      });

      // Wait for connection with timeout
      return await completer.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          if (!connected) {
            _outputController.add('[Timeout waiting for PM3 connection]');
            disconnect();
          }
          return false;
        },
      );
    } catch (e) {
      _outputController.add('[Error starting PM3: $e]');
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
      final result = await Process.run(
        pm3Path,
        ['-p', port, '-c', command],
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

  // Detect connection success from output line
  // Matches Proxmark3GUI pattern: QRegularExpression("(os:\\s+|OS\\.+\\s+)")
  bool _isConnectionPrompt(String line) {
    return RegExp(r'(os:\s+|OS\.+\s+)', caseSensitive: false)
        .hasMatch(line) ||
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
