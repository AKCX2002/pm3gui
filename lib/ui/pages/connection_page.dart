/// Connection page — select port, connect/disconnect, show device info.
library;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pm3gui/state/app_state.dart';
import 'package:pm3gui/services/pm3_process.dart';

class ConnectionPage extends StatefulWidget {
  const ConnectionPage({super.key});

  @override
  State<ConnectionPage> createState() => _ConnectionPageState();
}

class _ConnectionPageState extends State<ConnectionPage> {
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    _scanPorts();
  }

  Future<void> _scanPorts() async {
    setState(() => _scanning = true);
    final appState = context.read<AppState>();

    try {
      final ports = <String>[];

      if (Platform.isLinux) {
        // Scan /dev/ttyACM* and /dev/ttyUSB*
        final devDir = Directory('/dev');
        if (devDir.existsSync()) {
          for (final entity in devDir.listSync()) {
            final name = entity.path;
            if (name.contains('ttyACM') || name.contains('ttyUSB')) {
              ports.add(name);
            }
          }
        }
      } else if (Platform.isWindows) {
        // Try COM1-COM20
        for (var i = 1; i <= 20; i++) {
          ports.add('COM$i');
        }
      }

      ports.sort();
      appState.availablePorts = ports;
      if (ports.isNotEmpty && appState.portName.isEmpty) {
        appState.setPort(ports.first);
      }
    } catch (e) {
      // Ignore scan errors
    }

    setState(() => _scanning = false);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isConnected = appState.connectionState == Pm3State.connected;
    final isConnecting = appState.connectionState == Pm3State.connecting;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // PM3 Path
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PM3 程序路径',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: appState.pm3Path,
                    decoration: const InputDecoration(
                      hintText: './pm3 或 /usr/bin/proxmark3',
                      prefixIcon: Icon(Icons.folder_open),
                    ),
                    onChanged: appState.setPm3Path,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Port Selection
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        '串口选择',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: _scanning
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh),
                        onPressed: _scanning ? null : _scanPorts,
                        tooltip: '刷新端口',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (appState.availablePorts.isEmpty)
                    const Text(
                      '未找到串口。请连接 PM3 设备。',
                      style: TextStyle(color: Colors.orange),
                    )
                  else
                    DropdownButtonFormField<String>(
                      value: appState.availablePorts.contains(appState.portName)
                          ? appState.portName
                          : null,
                      items: appState.availablePorts
                          .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                          .toList(),
                      onChanged: isConnected
                          ? null
                          : (v) {
                              if (v != null) appState.setPort(v);
                            },
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.usb),
                      ),
                    ),
                  const SizedBox(height: 8),
                  // Manual port entry
                  TextFormField(
                    initialValue: appState.portName,
                    decoration: const InputDecoration(
                      hintText: '或手动输入端口...',
                      prefixIcon: Icon(Icons.edit),
                    ),
                    onChanged: isConnected ? null : appState.setPort,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Connect/Disconnect button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: isConnecting
                  ? null
                  : () async {
                      if (isConnected) {
                        await appState.disconnect();
                      } else {
                        await appState.connect();
                      }
                    },
              icon: isConnecting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(isConnected ? Icons.link_off : Icons.link),
              label: Text(
                isConnecting
                    ? '连接中...'
                    : isConnected
                        ? '断开连接'
                        : '连接',
                style: const TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isConnected ? Colors.red : null,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Device info (when connected)
          if (isConnected)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '设备信息',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const Divider(),
                    _infoRow('端口', appState.portName),
                    _infoRow('版本', appState.pm3Version),
                    _infoRow('状态', '已连接'),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () {
                        appState.sendCommand('hw version');
                      },
                      child: const Text('查询硬件版本'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}
