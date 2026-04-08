/// LF (Low Frequency) operations page.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pm3gui/state/app_state.dart';
import 'package:pm3gui/services/pm3_commands.dart';

class LfPage extends StatefulWidget {
  const LfPage({super.key});

  @override
  State<LfPage> createState() => _LfPageState();
}

class _LfPageState extends State<LfPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _em410xId = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _execute(String cmd) {
    final appState = context.read<AppState>();
    if (!appState.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未连接 PM3')),
      );
      return;
    }
    appState.sendCommand(cmd);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '通用'),
            Tab(text: 'EM4x05'),
            Tab(text: 'T55xx'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildGeneral(),
              _buildEm4x(),
              _buildT55xx(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGeneral() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _actionCard('低频搜索', '自动检测低频标签', Icons.search, () {
            _execute(Pm3Commands.lfSearch());
          }),
          _actionCard('低频读取', '读取低频原始信号', Icons.sensors, () {
            _execute(Pm3Commands.lfRead());
          }),
          _actionCard('低频喗探', '捕获低频通信', Icons.hearing, () {
            _execute(Pm3Commands.lfSniff());
          }),
          _actionCard('天线调谐', '检查天线调谐状态', Icons.tune, () {
            _execute(Pm3Commands.lfTune());
          }),
        ],
      ),
    );
  }

  Widget _buildEm4x() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _actionCard('读取 EM410x', '读取 EM4100 标签 ID', Icons.nfc, () {
            _execute(Pm3Commands.lfEm410xRead());
          }),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('克隆 EM410x', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: '标签 ID (10位 hex)',
                      hintText: '例如 0102030405',
                    ),
                    style: const TextStyle(fontFamily: 'monospace'),
                    onChanged: (v) => _em410xId = v,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      if (_em410xId.length == 10) {
                        _execute(Pm3Commands.lfEm410xClone(_em410xId));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('ID 必须是 10 位 hex 字符')),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('克隆'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildT55xx() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _actionCard('检测', '检测 T55xx 芯片配置', Icons.memory, () {
            _execute(Pm3Commands.lfT55xxDetect());
          }),
          _actionCard('信息', '显示 T55xx 配置信息', Icons.info_outline, () {
            _execute(Pm3Commands.lfT55xxInfo());
          }),
          _actionCard('转储', '转储所有 T55xx 块', Icons.download, () {
            _execute(Pm3Commands.lfT55xxDump());
          }),
          const Divider(),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('块操作', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  for (var block = 0; block < 8; block++)
                    ListTile(
                      dense: true,
                      title: Text('块 $block', style: const TextStyle(fontFamily: 'monospace')),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.visibility, size: 20),
                            onPressed: () => _execute(Pm3Commands.lfT55xxReadBlock(block)),
                            tooltip: '读取',
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionCard(String title, String subtitle, IconData icon, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[400])),
        trailing: const Icon(Icons.play_arrow),
        onTap: onTap,
      ),
    );
  }
}
