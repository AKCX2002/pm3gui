/// Settings page — app configuration.
library;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pm3gui/state/app_state.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '设置',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Appearance
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.palette),
                  title: const Text('深色模式'),
                  subtitle: const Text('切换深色/浅色主题'),
                  trailing: Switch(
                    value: appState.isDarkMode,
                    onChanged: (_) => appState.toggleTheme(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // PM3 Configuration
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ListTile(
                    leading: Icon(Icons.terminal),
                    title: Text('PM3 配置'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  TextFormField(
                    initialValue: appState.pm3Path,
                    decoration: const InputDecoration(
                      labelText: 'PM3 程序路径',
                      hintText: './pm3 或 /usr/bin/proxmark3',
                    ),
                    onChanged: appState.setPm3Path,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // About
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('关于 PM3 GUI'),
                  subtitle: Text('基于 Flutter 的 Proxmark3 图形界面'),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.code),
                  title: const Text('平台'),
                  subtitle: Text(Platform.operatingSystem),
                ),
                const ListTile(
                  leading: Icon(Icons.architecture),
                  title: Text('架构'),
                  subtitle: Text('CLI Wrapper (兼容未来更新)'),
                ),
                const ListTile(
                  leading: Icon(Icons.layers),
                  title: Text('支持格式'),
                  subtitle: Text('.eml, .bin/.dump, .json (PM3 Jansson)'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Quick actions
          const Text(
            '维护',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => appState.clearTerminal(),
                icon: const Icon(Icons.delete_sweep),
                label: const Text('清除终端'),
              ),
              if (appState.isConnected)
                OutlinedButton.icon(
                  onPressed: () => appState.sendCommand('hw version'),
                  icon: const Icon(Icons.info),
                  label: const Text('硬件版本'),
                ),
              if (appState.isConnected)
                OutlinedButton.icon(
                  onPressed: () => appState.sendCommand('hw tune'),
                  icon: const Icon(Icons.tune),
                  label: const Text('天线调谐'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
