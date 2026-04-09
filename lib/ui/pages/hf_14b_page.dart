/// ISO 14443-B operations page.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pm3gui/state/app_state.dart';
import 'package:pm3gui/services/pm3_commands.dart';
import 'package:pm3gui/ui/components/components.dart';

class Hf14bPage extends StatefulWidget {
  const Hf14bPage({super.key});

  @override
  State<Hf14bPage> createState() => _Hf14bPageState();
}

class _Hf14bPageState extends State<Hf14bPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  int _blockNumber = 0;
  String _blockData = '';
  String _rawHex = '';

  String _lastCmd = '';
  String _result = '';
  bool _isLoading = false;
  StreamSubscription<String>? _sub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _sub?.cancel();
    super.dispose();
  }

  void _execute(String cmd) {
    if (!executeIfConnected(context, cmd)) return;
    setState(() {
      _lastCmd = cmd;
      _isLoading = true;
      _result = '';
    });
    final buf = StringBuffer();
    _sub?.cancel();
    _sub = context.read<AppState>().pm3.outputStream.listen((line) {
      if (!line.startsWith('[pm3]')) {
        buf.writeln(line);
        if (mounted) setState(() => _result = buf.toString());
      }
    });
    context.read<AppState>().sendCommand(cmd);
    Future.delayed(const Duration(seconds: 5), () {
      _sub?.cancel();
      if (mounted) setState(() => _isLoading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      TabBar(controller: _tabController, tabs: const [
        Tab(text: '信息'),
        Tab(text: '读写'),
        Tab(text: '工具'),
      ]),
      Expanded(
          child: TabBarView(controller: _tabController, children: [
        _buildInfoTab(),
        _buildReadWriteTab(),
        _buildToolsTab(),
      ])),
    ]);
  }

  Widget _buildInfoTab() {
    return SplitPageLayout(
      side: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ActionCard(
              title: '读取器',
              subtitle: '读取 14443-B 卡片',
              icon: Icons.nfc,
              onTap: () => _execute(Hf14bCmd.reader())),
          ActionCard(
              title: '标签信息',
              subtitle: '读取标签详情',
              icon: Icons.info_outline,
              onTap: () => _execute(Hf14bCmd.info())),
          ActionCard(
              title: '嗅探',
              subtitle: '捕获 14443-B 通信',
              icon: Icons.hearing,
              onTap: () => _execute(Hf14bCmd.sniff())),
          ActionCard(
              title: '转储',
              subtitle: '读取全部数据',
              icon: Icons.download,
              onTap: () => _execute(Hf14bCmd.dump())),
          ActionCard(
              title: 'NDEF',
              subtitle: '读取 NDEF 数据',
              icon: Icons.article,
              onTap: () => _execute(Hf14bCmd.ndefRead())),
        ],
      ),
      main: ResultDisplay(
          command: _lastCmd,
          result: _result,
          isLoading: _isLoading,
          onClear: () => setState(() {
                _result = '';
                _lastCmd = '';
              })),
    );
  }

  Widget _buildReadWriteTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Card(
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('块操作',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(children: [
                      SizedBox(
                          width: 100,
                          child: TextFormField(
                            decoration: const InputDecoration(labelText: '块号'),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            onChanged: (v) =>
                                _blockNumber = int.tryParse(v) ?? 0,
                          )),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                          onPressed: () =>
                              _execute(Hf14bCmd.rdbl(_blockNumber)),
                          icon: const Icon(Icons.visibility, size: 18),
                          label: const Text('读取块')),
                    ]),
                    const SizedBox(height: 12),
                    HexInputField(
                        label: '写入数据 (hex)',
                        byteLength: 4,
                        onChanged: (v) => _blockData = v),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                        onPressed: _blockData.length == 8
                            ? () => _execute(
                                Hf14bCmd.wrbl(_blockNumber, _blockData))
                            : null,
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('写入块')),
                  ],
                ))),
        const SizedBox(height: 12),
        Card(
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('裸命令',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    HexInputField(
                        label: '原始 hex 数据', onChanged: (v) => _rawHex = v),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                        onPressed: _rawHex.isNotEmpty
                            ? () => _execute(Hf14bCmd.raw(_rawHex))
                            : null,
                        icon: const Icon(Icons.send, size: 18),
                        label: const Text('发送')),
                  ],
                ))),
      ]),
    );
  }

  Widget _buildToolsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ActionCard(
            title: '模拟卡片',
            subtitle: '模拟 14443-B 标签',
            icon: Icons.play_arrow,
            onTap: () => _execute(Hf14bCmd.sim())),
      ]),
    );
  }
}
