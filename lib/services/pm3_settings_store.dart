import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pm3gui/core/pm3/pm3_client_settings.dart';

typedef SettingsDirectoryProvider = Future<Directory> Function();

abstract interface class Pm3SettingsRepository {
  Future<void> save(Pm3ClientSettings settings);

  Future<Pm3ClientSettings?> load();
}

/// Stores desktop PM3 client settings outside the working directory.
final class Pm3SettingsStore implements Pm3SettingsRepository {
  Pm3SettingsStore({SettingsDirectoryProvider? directoryProvider})
      : _directoryProvider =
            directoryProvider ?? getApplicationSupportDirectory;

  static const _fileName = 'pm3_settings.json';

  final SettingsDirectoryProvider _directoryProvider;

  @override
  Future<void> save(Pm3ClientSettings settings) async {
    final directory = await _directoryProvider();
    await directory.create(recursive: true);
    final file = File('${directory.path}${Platform.pathSeparator}$_fileName');
    await file.writeAsString(jsonEncode(settings.toJson()));
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
}
