/// 设备连接状态管理
library;

import 'package:flutter/foundation.dart';
import 'package:pm3gui/backend/desktop_cli/desktop_cli_backend.dart';
import 'package:pm3gui/core/pm3/pm3_client_settings.dart';
import 'package:pm3gui/core/pm3/pm3_connection.dart';
import 'package:pm3gui/core/pm3/pm3_controller.dart';
import 'package:pm3gui/services/pm3_settings_store.dart';

class ConnectionState extends ChangeNotifier {
  ConnectionState({
    Pm3Controller? controller,
    Pm3SettingsRepository? settingsStore,
  })  : controller = controller ?? Pm3Controller(DesktopCliBackend()),
        _settingsStore = settingsStore ?? Pm3SettingsStore() {
    pm3Path = DesktopCliBackend.detectExecutable();
  }

  final Pm3Controller controller;
  final Pm3SettingsRepository _settingsStore;
  Future<void>? _initialization;
  Future<void> _settingsQueue = Future.value();
  bool _pm3PathDirty = false;
  bool _portDirty = false;
  bool _argumentsDirty = false;
  bool _workingDirectoryDirty = false;

  String pm3Path = '';
  String portName = '';
  List<String> pm3Arguments = const [];
  String? pm3WorkingDirectory;
  List<String> availablePorts = [];

  Pm3ConnectionState get connectionState => controller.state;
  String get pm3Version => controller.version;
  bool get isConnected => controller.isConnected;
  String get lastError => controller.lastError;

  Future<bool> connect() async {
    if (portName.isEmpty) return false;

    return controller.connect(Pm3ConnectionConfig(
      executable: pm3Path,
      port: portName,
      arguments: pm3Arguments,
      workingDirectory: pm3WorkingDirectory,
    ));
  }

  Future<void> initialize() =>
      _initialization ??= _enqueueSettingsOperation(_restoreSettings);

  Future<void> _restoreSettings() async {
    final settings = await _settingsStore.load();
    if (settings == null) return;

    if (!_pm3PathDirty) pm3Path = settings.executable;
    if (!_portDirty) portName = settings.port;
    if (!_argumentsDirty) {
      pm3Arguments = List<String>.unmodifiable(settings.arguments);
    }
    if (!_workingDirectoryDirty) {
      pm3WorkingDirectory = settings.workingDirectory;
    }
    notifyListeners();
  }

  Future<void> disconnect() async {
    await controller.disconnect();
    notifyListeners();
  }

  Future<void> setPort(String port) {
    portName = port;
    _portDirty = true;
    notifyListeners();
    return _saveSettings();
  }

  Future<void> setPm3Path(String path) {
    pm3Path = path;
    _pm3PathDirty = true;
    notifyListeners();
    return _saveSettings();
  }

  Future<void> setPm3Arguments(List<String> arguments) {
    pm3Arguments = List<String>.unmodifiable(arguments);
    _argumentsDirty = true;
    notifyListeners();
    return _saveSettings();
  }

  Future<void> setPm3WorkingDirectory(String? workingDirectory) {
    pm3WorkingDirectory =
        workingDirectory?.trim().isEmpty ?? true ? null : workingDirectory;
    _workingDirectoryDirty = true;
    notifyListeners();
    return _saveSettings();
  }

  void setAvailablePorts(List<String> ports) {
    availablePorts = ports;
    notifyListeners();
  }

  Future<void> _saveSettings() {
    initialize();
    return _enqueueSettingsOperation(
      () => _settingsStore.save(_currentSettings()),
    );
  }

  Pm3ClientSettings _currentSettings() => Pm3ClientSettings(
        executable: pm3Path,
        port: portName,
        arguments: pm3Arguments,
        workingDirectory: pm3WorkingDirectory,
      );

  Future<void> _enqueueSettingsOperation(Future<void> Function() operation) {
    final next = _settingsQueue.then((_) => operation());
    _settingsQueue = next.then<void>(
      (_) {},
      onError: (_, __) {},
    );
    return next;
  }

  Future<void> sendCommand(String cmd) async {
    if (cmd.trim().isEmpty) return;
    await controller.send(cmd);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
