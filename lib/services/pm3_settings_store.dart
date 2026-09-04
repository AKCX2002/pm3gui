import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pm3gui/core/pm3/pm3_client_settings.dart';

typedef SettingsDirectoryProvider = Future<Directory> Function();
typedef SettingsFileReplacer = Future<void> Function(File source, File target);

abstract interface class Pm3SettingsRepository {
  Future<void> save(Pm3ClientSettings settings);

  Future<Pm3ClientSettings?> load();
}

/// Stores desktop PM3 client settings outside the working directory.
final class Pm3SettingsStore implements Pm3SettingsRepository {
  Pm3SettingsStore({
    SettingsDirectoryProvider? directoryProvider,
    SettingsFileReplacer? fileReplacer,
  })  : _fileReplacer = fileReplacer ?? _replaceFile,
        _directoryProvider =
            directoryProvider ?? getApplicationSupportDirectory;

  static const _fileName = 'pm3_settings.json';
  static var _tempSequence = 0;

  final SettingsDirectoryProvider _directoryProvider;
  final SettingsFileReplacer _fileReplacer;

  @override
  Future<void> save(Pm3ClientSettings settings) async {
    final directory = await _directoryProvider();
    await directory.create(recursive: true);
    final file = File('${directory.path}${Platform.pathSeparator}$_fileName');
    final tempFile = File(
      '${file.path}.$pid.${_tempSequence++}.tmp',
    );
    try {
      await tempFile.create(exclusive: true);
      await tempFile.writeAsString(
        jsonEncode(settings.toJson()),
        flush: true,
      );
      await _fileReplacer(tempFile, file);
    } finally {
      if (await tempFile.exists()) await tempFile.delete();
    }
  }

  @override
  Future<Pm3ClientSettings?> load() async {
    try {
      final directory = await _directoryProvider();
      final file = File('${directory.path}${Platform.pathSeparator}$_fileName');
      if (!await file.exists()) return null;
      return Pm3ClientSettings.fromJson(jsonDecode(await file.readAsString()));
    } on FormatException {
      return null;
    } on FileSystemException {
      return null;
    }
  }

  static Future<void> _replaceFile(File source, File target) async {
    await source.rename(target.path);
  }
}
