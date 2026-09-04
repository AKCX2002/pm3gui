import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pm3gui/backend/mock/mock_pm3_backend.dart';
import 'package:pm3gui/core/pm3/pm3_backend.dart';
import 'package:pm3gui/core/pm3/pm3_client_settings.dart';
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

  test('shutdown waits for the last settings save', () async {
    final saveGate = Completer<void>();
    final settingsStore = _DelayedSettingsStore(saveGate);
    final state = AppState(
      connectionState: ConnectionState(
        controller: Pm3Controller(MockPm3Backend()),
        settingsStore: settingsStore,
      ),
    );

    state.setPm3Path('last-client');
    var completed = false;
    final shuttingDown = state.shutdown()..then((_) => completed = true);
    await Future<void>.delayed(Duration.zero);
    expect(completed, isFalse);

    saveGate.complete();
    await shuttingDown;

    expect(settingsStore.persisted?.executable, 'last-client');
  });

  test('shutdown waits for backend subscriptions and resources', () async {
    final shutdownGate = Completer<void>();
    final backend = _FinalOutputOnDisconnectBackend(
      shutdownGate: shutdownGate.future,
    );
    final state = AppState(
      connectionState: ConnectionState(
        controller: Pm3Controller(backend),
        settingsStore: _NoopSettingsStore(),
      ),
    );
    var completed = false;

    final shuttingDown = state.shutdown()..then((_) => completed = true);
    await Future<void>.delayed(Duration.zero);

    expect(completed, isFalse);
    shutdownGate.complete();
    await shuttingDown;
    expect(backend.disposeCount, 1);
  });

  test('batch connection does not send a second hw version command', () async {
    final connectionState = ConnectionState(
      controller: Pm3Controller(MockPm3Backend()),
      settingsStore: _NoopSettingsStore(),
    )
      ..pm3Path = r'C:\proxmark3\pm3.bat'
      ..portName = '';
    final commands = <String>[];
    final commandSubscription =
        connectionState.controller.commands.listen((command) {
      commands.add(command.executable);
    });
    final state = AppState(connectionState: connectionState);

    expect(await state.connect(), isTrue);
    await Future<void>.delayed(Duration.zero);

    expect(commands, isEmpty);
    await state.shutdown();
    await commandSubscription.cancel();
  });
}

final class _DelayedSettingsStore implements Pm3SettingsRepository {
  _DelayedSettingsStore(this.saveGate);

  final Completer<void> saveGate;
  Pm3ClientSettings? persisted;

  @override
  Future<Pm3ClientSettings?> load() async => null;

  @override
  Future<void> save(Pm3ClientSettings settings) async {
    await saveGate.future;
    persisted = settings;
  }
}

final class _NoopSettingsStore implements Pm3SettingsRepository {
  @override
  Future<Never?> load() async => null;

  @override
  Future<void> save(_) async {}
}

final class _FinalOutputOnDisconnectBackend implements Pm3Backend {
  _FinalOutputOnDisconnectBackend({this.shutdownGate});

  final Future<void>? shutdownGate;
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
  Future<void> shutdown() async {
    disposeCount++;
    await shutdownGate;
    await _events.close();
  }

  void _setState(Pm3ConnectionState state) {
    _state = state;
    _events.add(Pm3StateChangedEvent(DateTime.now(), state));
  }
}
