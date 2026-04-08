/// Home page with sidebar navigation — main app shell.
///
/// Sidebar: Connection, Terminal, Dump Viewer, Dump Compare, Mifare, LF, Settings
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pm3gui/state/app_state.dart';
import 'package:pm3gui/services/pm3_process.dart';
import 'package:pm3gui/ui/pages/connection_page.dart';
import 'package:pm3gui/ui/pages/terminal_page.dart';
import 'package:pm3gui/ui/pages/dump_viewer_page.dart';
import 'package:pm3gui/ui/pages/dump_compare_page.dart';
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
  bool _sidebarExpanded = true;

  final _pages = const [
    ConnectionPage(),
    TerminalPage(),
    DumpViewerPage(),
    DumpComparePage(),
    MifarePage(),
    LfPage(),
    SettingsPage(),
  ];

  static const _navItems = [
    _NavItem(Icons.usb, Icons.usb, '连接', '设备连接'),
    _NavItem(Icons.terminal, Icons.terminal, '终端', '交互终端'),
    _NavItem(Icons.file_open, Icons.file_open, 'Dump', '转储查看/编辑'),
    _NavItem(Icons.compare_arrows, Icons.compare_arrows, '对比', 'Dump 对比'),
    _NavItem(Icons.nfc, Icons.nfc, '高频', 'Mifare 操作'),
    _NavItem(Icons.radio, Icons.radio, '低频', 'LF 操作'),
    _NavItem(Icons.settings, Icons.settings, '设置', '应用设置'),
  ];

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isConnected = appState.connectionState == Pm3State.connected;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Row(
        children: [
          // ========== 侧边栏 ==========
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _sidebarExpanded ? 200 : 72,
            child: Material(
              color: isDark ? const Color(0xFF161622) : const Color(0xFFF0F2F5),
              child: Column(
                children: [
                  // Logo header
                  Container(
                    height: 64,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Icon(Icons.nfc,
                            color:
                                isConnected ? Colors.greenAccent : Colors.grey,
                            size: 28),
                        if (_sidebarExpanded) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('PM3 GUI',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                                if (appState.pm3Version.isNotEmpty)
                                  Text(appState.pm3Version,
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey[500]),
                                      overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // Connection status pill
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: _sidebarExpanded ? 12 : 8, vertical: 8),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: _sidebarExpanded ? 10 : 6, vertical: 6),
                      decoration: BoxDecoration(
                        color: isConnected
                            ? Colors.green.withValues(alpha: 0.15)
                            : Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isConnected
                                  ? Colors.greenAccent
                                  : Colors.redAccent,
                            ),
                          ),
                          if (_sidebarExpanded) ...[
                            const SizedBox(width: 8),
                            Text(
                              isConnected ? '已连接' : '未连接',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isConnected
                                    ? Colors.greenAccent
                                    : Colors.redAccent,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Nav items
                  Expanded(
                    child: ListView.builder(
                      itemCount: _navItems.length,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      itemBuilder: (context, index) {
                        final item = _navItems[index];
                        final selected = index == _currentIndex;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Material(
                            color: selected
                                ? theme.colorScheme.primary
                                    .withValues(alpha: 0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () =>
                                  setState(() => _currentIndex = index),
                              child: Container(
                                height: 44,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: Row(
                                  children: [
                                    Icon(
                                      selected ? item.selectedIcon : item.icon,
                                      size: 22,
                                      color: selected
                                          ? theme.colorScheme.primary
                                          : Colors.grey,
                                    ),
                                    if (_sidebarExpanded) ...[
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          item.label,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: selected
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                            color: selected
                                                ? theme.colorScheme.primary
                                                : null,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Bottom: collapse + theme toggle
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        // Theme toggle
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: appState.toggleTheme,
                          child: Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                Icon(
                                  appState.isDarkMode
                                      ? Icons.light_mode
                                      : Icons.dark_mode,
                                  size: 20,
                                  color: Colors.grey,
                                ),
                                if (_sidebarExpanded) ...[
                                  const SizedBox(width: 12),
                                  const Text('切换主题',
                                      style: TextStyle(fontSize: 13)),
                                ],
                              ],
                            ),
                          ),
                        ),
                        // Collapse toggle
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => setState(
                              () => _sidebarExpanded = !_sidebarExpanded),
                          child: Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                Icon(
                                  _sidebarExpanded
                                      ? Icons.chevron_left
                                      : Icons.chevron_right,
                                  size: 20,
                                  color: Colors.grey,
                                ),
                                if (_sidebarExpanded) ...[
                                  const SizedBox(width: 12),
                                  const Text('收起菜单',
                                      style: TextStyle(fontSize: 13)),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Sidebar divider
          VerticalDivider(
              width: 1,
              color: isDark ? const Color(0xFF2A2A3C) : Colors.grey[300]),
          // ========== 主内容区 (IndexedStack 保持页面状态) ==========
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: _pages,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String tooltip;
  const _NavItem(this.icon, this.selectedIcon, this.label, this.tooltip);
}
