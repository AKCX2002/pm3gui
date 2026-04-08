/// Home page with bottom navigation — main app shell.
///
/// Tabs: Connection, Terminal, Dump Viewer, Mifare, LF, Settings
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pm3gui/state/app_state.dart';
import 'package:pm3gui/services/pm3_process.dart';
import 'package:pm3gui/ui/pages/connection_page.dart';
import 'package:pm3gui/ui/pages/terminal_page.dart';
import 'package:pm3gui/ui/pages/dump_viewer_page.dart';
import 'package:pm3gui/ui/pages/mifare_page.dart';
import 'package:pm3gui/ui/pages/lf_page.dart';
import 'package:pm3gui/ui/pages/settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  final _pages = const [
    ConnectionPage(),
    TerminalPage(),
    DumpViewerPage(),
    MifarePage(),
    LfPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isConnected = appState.connectionState == Pm3State.connected;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              Icons.nfc,
              color: isConnected ? Colors.greenAccent : Colors.grey,
            ),
            const SizedBox(width: 8),
            const Text('PM3 GUI'),
            if (appState.pm3Version.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                appState.pm3Version,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[400],
                ),
              ),
            ],
          ],
        ),
        actions: [
          // Connection status indicator
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isConnected
                  ? Colors.green.withValues(alpha: 0.2)
                  : Colors.red.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isConnected ? Colors.greenAccent : Colors.redAccent,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isConnected ? '已连接' : '未连接',
                  style: TextStyle(
                    fontSize: 12,
                    color: isConnected ? Colors.greenAccent : Colors.redAccent,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(appState.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: appState.toggleTheme,
            tooltip: '切换主题',
          ),
        ],
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.usb),
            selectedIcon: Icon(Icons.usb, color: Colors.blue),
            label: '连接',
          ),
          NavigationDestination(
            icon: Icon(Icons.terminal),
            selectedIcon: Icon(Icons.terminal, color: Colors.blue),
            label: '终端',
          ),
          NavigationDestination(
            icon: Icon(Icons.file_open),
            selectedIcon: Icon(Icons.file_open, color: Colors.blue),
            label: 'Dump',
          ),
          NavigationDestination(
            icon: Icon(Icons.nfc),
            selectedIcon: Icon(Icons.nfc, color: Colors.blue),
            label: '高频',
          ),
          NavigationDestination(
            icon: Icon(Icons.radio),
            selectedIcon: Icon(Icons.radio, color: Colors.blue),
            label: '低频',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings),
            selectedIcon: Icon(Icons.settings, color: Colors.blue),
            label: '设置',
          ),
        ],
      ),
    );
  }
}
