import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pm3gui/core/pm3/pm3_client_settings.dart';
import 'package:pm3gui/services/pm3_settings_store.dart';
import 'package:pm3gui/state/connection_state.dart';

void main() {
  test('initialize restores persisted desktop client settings', () async {
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
    final state = ConnectionState(settingsStore: store);
    addTearDown(state.dispose);

    await state.initialize();

    expect(state.pm3Path, expected.executable);
    expect(state.portName, expected.port);
    expect(state.pm3Arguments, expected.arguments);
    expect(state.pm3WorkingDirectory, expected.workingDirectory);
  });

  test('client setting setters persist a complete snapshot', () async {
    final directory = await Directory.systemTemp.createTemp('pm3-settings-');
    addTearDown(() => directory.delete(recursive: true));
    final store = Pm3SettingsStore(directoryProvider: () async => directory);
    final state = ConnectionState(settingsStore: store);
    addTearDown(state.dispose);

    await state.setPm3Path(r'C:\tools\proxmark3.exe');
    await state.setPort('COM7');
    await state.setPm3Arguments(['--flush']);
    await state.setPm3WorkingDirectory(r'C:\tools');

    expect(
      await store.load(),
      const Pm3ClientSettings(
        executable: r'C:\tools\proxmark3.exe',
        port: 'COM7',
        arguments: ['--flush'],
        workingDirectory: r'C:\tools',
      ),
    );
  });
}
