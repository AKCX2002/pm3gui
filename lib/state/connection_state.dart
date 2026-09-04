/// 设备连接状态管理
library;

import 'package:flutter/foundation.dart';
import 'package:pm3gui/backend/desktop_cli/desktop_cli_backend.dart';
import 'package:pm3gui/core/pm3/pm3_connection.dart';
import 'package:pm3gui/core/pm3/pm3_controller.dart';

class ConnectionState extends ChangeNotifier {
  ConnectionState({Pm3Controller? controller})
      : controller = controller ?? Pm3Controller(DesktopCliBackend()) {
    pm3Path = DesktopCliBackend.detectExecutable();
  }

  final Pm3Controller controller;

  String pm3Path = '';
  String portName = '';
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
    ));
  }

  Future<void> disconnect() async {
    await controller.disconnect();
    notifyListeners();
  }

  void setPort(String port) {
    portName = port;
    notifyListeners();
  }

  void setPm3Path(String path) {
    pm3Path = path;
    notifyListeners();
  }

  void setAvailablePorts(List<String> ports) {
    availablePorts = ports;
    notifyListeners();
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
