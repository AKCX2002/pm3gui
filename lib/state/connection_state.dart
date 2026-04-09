/// 设备连接状态管理
library;

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pm3gui/services/pm3_process.dart';

class ConnectionState extends ChangeNotifier {
  final Pm3Process pm3 = Pm3Process();

  String pm3Path = '';
  String portName = '';
  List<String> availablePorts = [];

  Pm3State get connectionState => pm3.state;
  String get pm3Version => pm3.version;
  bool get isConnected => pm3.state == Pm3State.connected;
  String get lastError => pm3.lastError;

  ConnectionState() {
    pm3Path = _detectPm3Path();
  }

  Future<bool> connect() async {
    if (portName.isEmpty) return false;

    final result = await pm3.connect(pm3Path, portName);
    return result;
  }

  Future<void> disconnect() async {
    await pm3.disconnect();
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
    await pm3.sendCommand(cmd);
  }

  @override
  void dispose() {
    pm3.dispose();
    super.dispose();
  }

  static String _detectPm3Path() {
    final candidates = [
      '/root/dev/proxmark3/pm3',
      '/usr/local/bin/proxmark3',
      '/usr/bin/proxmark3',
    ];
    for (final c in candidates) {
      if (FileSystemEntity.isFileSync(c)) return c;
    }
    try {
      final r = Process.runSync('which', ['proxmark3']);
      if (r.exitCode == 0) {
        final p = (r.stdout as String).trim();
        if (p.isNotEmpty) return p;
      }
    } catch (_) {}
    return './pm3';
  }
}
