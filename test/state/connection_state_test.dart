import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pm3gui/backend/mock/mock_pm3_backend.dart';
import 'package:pm3gui/core/pm3/pm3_client_settings.dart';
import 'package:pm3gui/core/pm3/pm3_controller.dart';
import 'package:pm3gui/services/pm3_settings_store.dart';
import 'package:pm3gui/state/connection_state.dart';

void main() {
  test('Windows batch client can connect without a selected port', () async {
    if (!Platform.isWindows) return;

    final state = ConnectionState(
      controller: Pm3Controller(MockPm3Backend()),
    )
      ..pm3Path = r'C:\proxmark3\pm3.bat'
      ..portName = '';
    addTearDown(state.dispose);

    expect(await state.connect(), isTrue);
  });

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

  test(
      'new input during initialization is not overwritten by restored settings',
      () async {
    final restoredSettings = const Pm3ClientSettings(
      executable: 'restored-proxmark3',
      port: 'COM7',
    );
    final loadCompleter = Completer<Pm3ClientSettings?>();
    final saveCompleter = Completer<void>();
    final store = DelayedSettingsStore(
      loadFuture: loadCompleter.future,
      saveGates: [saveCompleter],
    );
    final state = ConnectionState(settingsStore: store);
    addTearDown(state.dispose);

    final initializing = state.initialize();
    final saving = state.setPm3Path('user-selected-proxmark3');
    loadCompleter.complete(restoredSettings);
    await initializing;

    expect(state.pm3Path, 'user-selected-proxmark3');

    saveCompleter.complete();
    await saving;
  });

  test('initialization merges a changed path with persisted client settings',
      () async {
    const restoredSettings = Pm3ClientSettings(
      executable: 'restored-proxmark3',
      port: 'COM7',
      arguments: ['--flush'],
      workingDirectory: 'C:/pm3',
    );
    const expected = Pm3ClientSettings(
      executable: 'user-selected-proxmark3',
      port: 'COM7',
      arguments: ['--flush'],
      workingDirectory: 'C:/pm3',
    );
    final loadCompleter = Completer<Pm3ClientSettings?>();
    final saveCompleter = Completer<void>();
    final store = DelayedSettingsStore(
      loadFuture: loadCompleter.future,
      saveGates: [saveCompleter],
    );
    final state = ConnectionState(settingsStore: store);
    addTearDown(state.dispose);

    final initializing = state.initialize();
    final saving = state.setPm3Path(expected.executable);
    loadCompleter.complete(restoredSettings);
    await initializing;

    expect(state.pm3Path, expected.executable);
    expect(state.portName, expected.port);
    expect(state.pm3Arguments, expected.arguments);
    expect(state.pm3WorkingDirectory, expected.workingDirectory);

    saveCompleter.complete();
    await saving;
    expect(store.persisted, expected);
  });

  test(
      'fire-and-forget setters persist the last input when writes complete out of order',
      () async {
    final firstSaveGate = Completer<void>();
    final lastSaveGate = Completer<void>();
    final store = DelayedSettingsStore(
      loadFuture: Future.value(null),
      saveGates: [firstSaveGate, lastSaveGate],
    );
    final state = ConnectionState(settingsStore: store);
    addTearDown(state.dispose);

    final firstSave = state.setPm3Path('first-proxmark3');
    final lastSave = state.setPm3Path('last-proxmark3');
    lastSaveGate.complete();
    await Future<void>.delayed(Duration.zero);
    firstSaveGate.complete();
    await Future.wait([firstSave, lastSave]);

    expect(store.persisted?.executable, 'last-proxmark3');
  });

  test('save failure is consumed and exposed through observable state',
      () async {
    final state = ConnectionState(settingsStore: _ThrowingSettingsStore());
    addTearDown(state.dispose);
    var notifications = 0;
    state.addListener(() => notifications++);

    await expectLater(state.setPm3Path('new-client'), completes);

    expect(state.isSavingSettings, isFalse);
    expect(state.settingsError, contains('save failed'));
    expect(notifications, greaterThanOrEqualTo(2));
  });

  test('flushSettings waits for initialization and the final queued save',
      () async {
    final saveGate = Completer<void>();
    final store = DelayedSettingsStore(
      loadFuture: Future.value(null),
      saveGates: [saveGate],
    );
    final state = ConnectionState(settingsStore: store);
    addTearDown(state.dispose);

    state.setPm3Path('last-client');
    var flushed = false;
    final flushing = state.flushSettings()..then((_) => flushed = true);
    await Future<void>.delayed(Duration.zero);
    expect(state.isSavingSettings, isTrue);
    expect(flushed, isFalse);

    saveGate.complete();
    await flushing;

    expect(state.isSavingSettings, isFalse);
    expect(store.persisted?.executable, 'last-client');
  });
}

final class _ThrowingSettingsStore implements Pm3SettingsRepository {
  @override
  Future<Pm3ClientSettings?> load() async => null;

  @override
  Future<void> save(Pm3ClientSettings settings) async {
    throw StateError('save failed');
  }
}

final class DelayedSettingsStore implements Pm3SettingsRepository {
  DelayedSettingsStore({
    required this.loadFuture,
    required this.saveGates,
  });

  final Future<Pm3ClientSettings?> loadFuture;
  final List<Completer<void>> saveGates;
  Pm3ClientSettings? persisted;

  @override
  Future<Pm3ClientSettings?> load() => loadFuture;

  @override
  Future<void> save(Pm3ClientSettings settings) async {
    final gate = saveGates.removeAt(0);
    await gate.future;
    persisted = settings;
  }
}
