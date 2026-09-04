import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pm3gui/backend/mock/mock_pm3_backend.dart';
import 'package:pm3gui/core/pm3/pm3_backend.dart';
import 'package:pm3gui/core/pm3/pm3_command.dart';
import 'package:pm3gui/core/pm3/pm3_connection.dart';
import 'package:pm3gui/core/pm3/pm3_controller.dart';
import 'package:pm3gui/core/pm3/pm3_event.dart';
import 'package:pm3gui/core/pm3/pm3_result.dart';
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

  test('shutdown records final output and releases PM3 resources once',
      () async {
    final directory = await Directory.systemTemp.createTemp('pm3-session-');
    addTearDown(() => directory.delete(recursive: true));
    final recorder = Pm3SessionRecorder(
      rootDirectoryProvider: () async => directory,
    );
    final backend = _FinalOutputOnDisconnectBackend();
    final connectionState = ConnectionState(
      controller: Pm3Controller(backend),
      settingsStore: _NoopSettingsStore(),
    )
      ..pm3Path = 'proxmark3.exe'
      ..portName = 'COM7';
    final state = AppState(
      connectionState: connectionState,
      sessionRecorder: recorder,
    );

    expect(await state.connect(), isTrue);
    await state.shutdown();
    await state.shutdown();
    state.dispose();

    final terminal = await File(
      '${recorder.sessionPath}${Platform.pathSeparator}terminal.log',
    ).readAsString();
    final metadata = jsonDecode(
      await File('${recorder.sessionPath}${Platform.pathSeparator}session.json')
          .readAsString(),
    ) as Map<String, dynamic>;
    expect(terminal, contains('[+] final output'));
    expect(metadata['endedAt'], isA<String>());
    expect(backend.disconnectCount, 1);
    expect(backend.disposeCount, 1);
  });
}

final class _NoopSettingsStore implements Pm3SettingsRepository {
  @override
  Future<Never?> load() async => null;

  @override
  Future<void> save(_) async {}
}

final class _FinalOutputOnDisconnectBackend implements Pm3Backend {
  final StreamController<Pm3Event> _events =
      StreamController<Pm3Event>.broadcast(sync: true);
  Pm3ConnectionState _state = Pm3ConnectionState.disconnected;
  int disconnectCount = 0;
  int disposeCount = 0;

  @override
  Stream<Pm3Event> get events => _events.stream;

  @override
  Pm3ConnectionState get state => _state;

  @override
  String get version => 'test';

  @override
  String get lastError => '';

  @override
  Future<void> cancel() async {}

  @override
  Future<void> connect(Pm3ConnectionConfig config) async {
    _setState(Pm3ConnectionState.connecting);
    _setState(Pm3ConnectionState.connected);
  }

  @override
  Future<void> disconnect() async {
    disconnectCount++;
    _events.add(Pm3OutputEvent(DateTime.now(), '[+] final output'));
    _setState(Pm3ConnectionState.disconnected);
  }

  @override
  Future<Pm3Result> execute(Pm3Command command, {Duration? timeout}) async {
    final now = DateTime.now();
    return Pm3Result(
      command: command,
      output: '',
      startedAt: now,
      finishedAt: now,
    );
  }

  @override
  void dispose() {
    disposeCount++;
    _events.close();
  }

  void _setState(Pm3ConnectionState state) {
    _state = state;
    _events.add(Pm3StateChangedEvent(DateTime.now(), state));
  }
}
