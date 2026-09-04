import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pm3gui/core/pm3/pm3_client_settings.dart';
import 'package:pm3gui/services/pm3_settings_store.dart';

void main() {
  test('round-trips desktop client settings', () async {
    final directory = await Directory.systemTemp.createTemp('pm3-settings-');
    addTearDown(() => directory.delete(recursive: true));
    final store = Pm3SettingsStore(directoryProvider: () async => directory);
    const expected = Pm3ClientSettings(
      executable: r'C:\tools\proxmark3.exe',
      port: 'COM7',
      arguments: ['--flush'],
      workingDirectory: r'C:\tools',
    );

    await store.save(expected);

    expect(await store.load(), expected);
    expect(
      await directory.list().map((entry) => entry.path).toList(),
      [
        '${directory.path}${Platform.pathSeparator}pm3_settings.json',
      ],
    );
  });

  test('failed atomic replacement preserves old settings and removes temp file',
      () async {
    final directory = await Directory.systemTemp.createTemp('pm3-settings-');
    addTearDown(() => directory.delete(recursive: true));
    final originalStore =
        Pm3SettingsStore(directoryProvider: () async => directory);
    const original = Pm3ClientSettings(
      executable: 'original-client',
      port: 'COM7',
    );
    await originalStore.save(original);
    final failingStore = Pm3SettingsStore(
      directoryProvider: () async => directory,
      fileReplacer: (_, __) async =>
          throw FileSystemException('replace failed'),
    );

    await expectLater(
      failingStore.save(const Pm3ClientSettings(
        executable: 'new-client',
        port: 'COM8',
      )),
      throwsA(isA<FileSystemException>()),
    );

    expect(await originalStore.load(), original);
    expect(
      await directory.list().map((entry) => entry.path).toList(),
      [
        '${directory.path}${Platform.pathSeparator}pm3_settings.json',
      ],
    );
  });

  test('invalid JSON falls back without throwing', () async {
    final directory = await Directory.systemTemp.createTemp('pm3-settings-');
    addTearDown(() => directory.delete(recursive: true));
    final file =
        File('${directory.path}${Platform.pathSeparator}pm3_settings.json');
    await file.writeAsString('{not valid json');
    final store = Pm3SettingsStore(directoryProvider: () async => directory);

    expect(await store.load(), isNull);
  });

  test('invalid setting fields fall back without throwing', () async {
    final directory = await Directory.systemTemp.createTemp('pm3-settings-');
    addTearDown(() => directory.delete(recursive: true));
    final file =
        File('${directory.path}${Platform.pathSeparator}pm3_settings.json');
    await file.writeAsString('{"executable": 3, "port": "COM7"}');
    final store = Pm3SettingsStore(directoryProvider: () async => directory);

    expect(await store.load(), isNull);
  });
}
