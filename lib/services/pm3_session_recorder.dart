import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pm3gui/core/pm3/pm3_session.dart';

typedef SessionRootDirectoryProvider = Future<Directory> Function();

/// Writes one local-only log directory for each successful PM3 connection.
final class Pm3SessionRecorder {
  Pm3SessionRecorder({SessionRootDirectoryProvider? rootDirectoryProvider})
      : _rootDirectoryProvider = rootDirectoryProvider ?? _defaultRootDirectory;

  final SessionRootDirectoryProvider _rootDirectoryProvider;
  Future<void> _writeQueue = Future.value();
  Pm3Session? _session;

  String get sessionPath {
    final session = _session;
    if (session == null) throw StateError('No PM3 session has been started');
    return session.directoryPath;
  }

  Future<void> start({
    required String devicePort,
    required String executable,
  }) {
    return _enqueue(() async {
      await _closeActiveSession();
      final root = await _rootDirectoryProvider();
      await root.create(recursive: true);
      final sessionDirectory = await _createSessionDirectory(root);
      final session = Pm3Session(
        directoryPath: sessionDirectory.path,
        devicePort: devicePort,
        executable: executable,
        startedAt: DateTime.now(),
      );
      await _metadataFile(session).writeAsString(
        jsonEncode(session.toJson()),
        flush: true,
      );
      _session = session;
    });
  }

  Future<void> recordCommand(String command) {
    return _enqueue(() async {
      final session = _activeSession;
      if (session == null) return;
      await _commandsFile(session).writeAsString(
        '${jsonEncode(<String, String>{
              'timestamp': DateTime.now().toUtc().toIso8601String(),
              'command': command,
            })}\n',
        mode: FileMode.append,
        flush: true,
      );
    });
  }

  Future<void> recordOutput(String line) {
    return _enqueue(() async {
      final session = _activeSession;
      if (session == null) return;
      await _terminalFile(session).writeAsString(
        '$line\n',
        mode: FileMode.append,
        flush: true,
      );
    });
  }

  Future<void> close() => _enqueue(_closeActiveSession);

  Pm3Session? get _activeSession {
    final session = _session;
    return session?.endedAt == null ? session : null;
  }

  Future<void> _closeActiveSession() async {
    final session = _activeSession;
    if (session == null) return;
    final closedSession = session.close(DateTime.now());
    await _metadataFile(closedSession).writeAsString(
      jsonEncode(closedSession.toJson()),
      flush: true,
    );
    _session = closedSession;
  }

  Future<Directory> _createSessionDirectory(Directory root) async {
    var time = DateTime.now();
    while (true) {
      final directory = Directory(
        '${root.path}${Platform.pathSeparator}${_directoryName(time)}',
      );
      if (!await directory.exists()) {
        await directory.create();
        return directory;
      }
      time = time.add(const Duration(milliseconds: 1));
    }
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final next = _writeQueue.then((_) => operation());
    _writeQueue = next.then<void>(
      (_) {},
      onError: (_, __) {},
    );
    return next;
  }

  File _metadataFile(Pm3Session session) => File(
        '${session.directoryPath}${Platform.pathSeparator}session.json',
      );
  File _terminalFile(Pm3Session session) => File(
        '${session.directoryPath}${Platform.pathSeparator}terminal.log',
      );
  File _commandsFile(Pm3Session session) => File(
        '${session.directoryPath}${Platform.pathSeparator}commands.jsonl',
      );

  static Future<Directory> _defaultRootDirectory() async {
    final supportDirectory = await getApplicationSupportDirectory();
    return Directory(
        '${supportDirectory.path}${Platform.pathSeparator}sessions');
  }

  static String _directoryName(DateTime time) =>
      '${time.year.toString().padLeft(4, '0')}-'
      '${time.month.toString().padLeft(2, '0')}-'
      '${time.day.toString().padLeft(2, '0')}_'
      '${time.hour.toString().padLeft(2, '0')}'
      '${time.minute.toString().padLeft(2, '0')}'
      '${time.second.toString().padLeft(2, '0')}_'
      '${time.millisecond.toString().padLeft(3, '0')}';
}
