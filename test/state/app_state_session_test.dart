import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pm3gui/backend/mock/mock_pm3_backend.dart';
import 'package:pm3gui/core/pm3/pm3_controller.dart';
import 'package:pm3gui/services/pm3_session_recorder.dart';
import 'package:pm3gui/services/pm3_settings_store.dart';
import 'package:pm3gui/state/app_state.dart';
import 'package:pm3gui/state/connection_state.dart';

void main() {
  test('successful connection starts a session before its hw version command',
      () async {
    final directory = await Directory.systemTemp.createTemp('pm3-session-');
    addTearDown(() => directory.delete(recursive: true));
    final recorder = Pm3SessionRecorder(
      rootDirectoryProvider: () async => directory,
    );
    final connectionState = ConnectionState(
      controller: Pm3Controller(MockPm3Backend()),
      settingsStore: _NoopSettingsStore(),
    )
      ..pm3Path = 'proxmark3.exe'
      ..portName = 'COM7';
    final state = AppState(
      connectionState: connectionState,
      sessionRecorder: recorder,
    );
    addTearDown(state.dispose);

    expect(await state.connect(), isTrue);
    await state.disconnect();

    final commands = await File(
      '${recorder.sessionPath}${Platform.pathSeparator}commands.jsonl',
    ).readAsString();
    expect(commands, contains('hw version'));
  });
}

final class _NoopSettingsStore implements Pm3SettingsRepository {
  @override
  Future<Never?> load() async => null;

  @override
  Future<void> save(_) async {}
}
