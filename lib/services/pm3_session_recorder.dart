import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pm3gui/core/pm3/pm3_session.dart';

typedef SessionRootDirectoryProvider = Future<Directory> Function();
typedef SessionClock = DateTime Function();
typedef SessionMetadataFileReservation = Future<void> Function(File file);
typedef SessionMetadataFileWriter = Future<void> Function(
  File file,
  String contents,
);

/// Writes one local-only log directory for each successful PM3 connection.
final class Pm3SessionRecorder {
  Pm3SessionRecorder({
    SessionRootDirectoryProvider? rootDirectoryProvider,
    SessionClock? now,
    SessionMetadataFileReservation? metadataFileReservation,
    SessionMetadataFileWriter? metadataFileWriter,
  })  : _rootDirectoryProvider = rootDirectoryProvider ?? _defaultRootDirectory,
        _now = now ?? DateTime.now,
        _metadataFileReservation =
            metadataFileReservation ?? _reserveMetadataFile,
        _metadataFileWriter = metadataFileWriter ?? _writeMetadataFile;

  static const maxSessionCreationAttempts = 8;
  final SessionRootDirectoryProvider _rootDirectoryProvider;
  final SessionClock _now;
  final SessionMetadataFileReservation _metadataFileReservation;
  final SessionMetadataFileWriter _metadataFileWriter;
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
      _session = await _createSession(
        root,
        devicePort: devicePort,
        executable: executable,
      );
    });
  }

  Future<void> recordCommand(String command) {
    return _enqueue(() async {
      final session = _activeSession;
      if (session == null) return;
      await _commandsFile(session).writeAsString(
        '${jsonEncode(<String, String>{
              'timestamp': _now().toUtc().toIso8601String(),
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
    final closedSession = session.close(_now());
    await _metadataFileWriter(
      _metadataFile(closedSession),
      jsonEncode(closedSession.toJson()),
    );
    _session = closedSession;
  }

  Future<Pm3Session> _createSession(
    Directory root, {
    required String devicePort,
    required String executable,
  }) async {
    var time = _now();
    for (var attempt = 0; attempt < maxSessionCreationAttempts; attempt++) {
      final directory = Directory(
        '${root.path}${Platform.pathSeparator}${_directoryName(time)}',
      );
      if (await directory.exists()) {
        time = time.add(const Duration(milliseconds: 1));
        continue;
      }
      try {
        await directory.create();
      } on FileSystemException catch (error) {
        if (_isAlreadyExists(error)) {
          time = time.add(const Duration(milliseconds: 1));
          continue;
        }
        rethrow;
      }

      final session = Pm3Session(
        directoryPath: directory.path,
        devicePort: devicePort,
        executable: executable,
        startedAt: _now(),
      );
      final metadataFile = _metadataFile(session);
      try {
        await _metadataFileReservation(metadataFile);
      } on FileSystemException catch (error) {
        if (_isAlreadyExists(error)) {
          time = time.add(const Duration(milliseconds: 1));
          continue;
        }
        rethrow;
      }
      // Do not delete this directory if the write below fails. A competing
      // process may own it, so preserving the partial directory is safer than
      // risking deletion of an existing Session; later starts skip its name.
      await _metadataFileWriter(metadataFile, jsonEncode(session.toJson()));
      return session;
    }
    throw StateError(
      'Unable to allocate a PM3 session directory after '
      '$maxSessionCreationAttempts attempts',
    );
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

  static Future<void> _reserveMetadataFile(File file) =>
      file.create(exclusive: true);

  static Future<void> _writeMetadataFile(File file, String contents) =>
      file.writeAsString(contents, flush: true);

  static bool _isAlreadyExists(FileSystemException error) {
    final code = error.osError?.errorCode;
    return code == 17 || code == 80 || code == 183;
  }

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
