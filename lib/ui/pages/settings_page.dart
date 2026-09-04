/// Settings page — app configuration.
library;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pm3gui/core/pm3/pm3_argument_codec.dart';
import 'package:pm3gui/services/file_dialog_service.dart';
import 'package:pm3gui/state/app_state.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _pm3PathController = TextEditingController();
  final _argumentsController = TextEditingController();
  final _workingDirectoryController = TextEditingController();
  final _argumentsFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _argumentsFocusNode.addListener(_refreshAfterArgumentsEditing);
  }

  @override
  void dispose() {
    _pm3PathController.dispose();
    _argumentsController.dispose();
    _argumentsFocusNode
      ..removeListener(_refreshAfterArgumentsEditing)
      ..dispose();
    _workingDirectoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    _syncController(_pm3PathController, appState.pm3Path);
    if (!_argumentsFocusNode.hasFocus) {
      _syncController(
        _argumentsController,
        encodePm3Arguments(appState.pm3Arguments),
      );
    }
    _syncController(
      _workingDirectoryController,
      appState.pm3WorkingDirectory ?? '',
    );

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
                    controller: _pm3PathController,
                    decoration: InputDecoration(
                      labelText: 'PM3 程序路径',
                      hintText: Platform.isWindows
                          ? r'官方发行包根目录\pm3.bat'
                          : '/usr/bin/proxmark3',
                      helperText: Platform.isWindows
                          ? 'Windows 推荐选择发行包根目录的 pm3.bat'
                          : null,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.folder_open),
                        tooltip: '选择 PM3 程序',
                        onPressed: () async {
                          final path =
                              await FileDialogService.pickSingleFilePath();
                          if (path != null) await appState.setPm3Path(path);
                        },
                      ),
                    ),
                    onChanged: appState.setPm3Path,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _argumentsController,
                    focusNode: _argumentsFocusNode,
                    decoration: InputDecoration(
                      labelText: 'PM3 启动参数',
                      hintText: '--flush\n--example=value with spaces',
                      helperText: Platform.isWindows
                          ? '选择 pm3.bat 时由脚本自行初始化并自动检测设备，'
                              '此处参数不会传给脚本。每行一个参数；空格、引号和反斜杠按原样保留'
                          : '每行一个参数；空格、引号和反斜杠按原样保留',
                    ),
                    minLines: 2,
                    maxLines: 6,
                    onChanged: (value) => appState.setPm3Arguments(
                      decodePm3Arguments(value),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _workingDirectoryController,
                    decoration: const InputDecoration(
                      labelText: 'PM3 工作目录（可选）',
                    ),
                    onChanged: appState.setPm3WorkingDirectory,
                  ),
                  if (appState.isSavingSettings) ...[
                    const SizedBox(height: 12),
                    const Row(
                      key: ValueKey('settings-saving'),
                      children: [
                        SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('正在保存设置…'),
                      ],
                    ),
                  ],
                  if (appState.settingsError case final error?) ...[
                    const SizedBox(height: 12),
                    Text(
                      error,
                      key: const ValueKey('settings-error'),
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
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

  void _syncController(TextEditingController controller, String value) {
    if (controller.text == value) return;
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  void _refreshAfterArgumentsEditing() {
    if (!_argumentsFocusNode.hasFocus && mounted) setState(() {});
  }
}
