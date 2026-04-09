/// FeliCa operations page.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pm3gui/state/app_state.dart';
import 'package:pm3gui/services/pm3_commands.dart';
import 'package:pm3gui/ui/components/components.dart';

class HfFelicaPage extends StatefulWidget {
  const HfFelicaPage({super.key});

  @override
  State<HfFelicaPage> createState() => _HfFelicaPageState();
}

class _HfFelicaPageState extends State<HfFelicaPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _sc = '';
  String _bl = '';
  String _blockData = '';
  String _rawHex = '';

  String _lastCmd = '';
  String _result = '';
  bool _isLoading = false;
  StreamSubscription<String>? _sub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
      ]),
      Expanded(
          child: TabBarView(controller: _tabController, children: [
        _buildInfoTab(),
        _buildReadWriteTab(),
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
              subtitle: '读取 FeliCa 卡片',
              icon: Icons.nfc,
              onTap: () => _execute(HfFelicaCmd.reader())),
          ActionCard(
              title: '标签信息',
              subtitle: '获取 FeliCa 详情',
              icon: Icons.info_outline,
              onTap: () => _execute(HfFelicaCmd.info())),
          ActionCard(
              title: '转储',
              subtitle: '转储卡片数据',
              icon: Icons.download,
              onTap: () => _execute(HfFelicaCmd.dump())),
          ActionCard(
              title: 'Lite 转储',
              subtitle: '转储 FeliCa Lite',
              icon: Icons.download_for_offline,
              onTap: () => _execute(HfFelicaCmd.litedump())),
          ActionCard(
              title: '嗅探',
              subtitle: '捕获 FeliCa 通信',
              icon: Icons.hearing,
              onTap: () => _execute(HfFelicaCmd.sniff())),
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
                      Expanded(
                          child: HexInputField(
                              label: 'SC (服务代码)', onChanged: (v) => _sc = v)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: HexInputField(
                              label: 'BL (块号)', onChanged: (v) => _bl = v)),
                    ]),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                        onPressed: _sc.isNotEmpty && _bl.isNotEmpty
                            ? () => _execute(HfFelicaCmd.rdbl(_sc, _bl))
                            : null,
                        icon: const Icon(Icons.visibility, size: 18),
                        label: const Text('读取块')),
                    const SizedBox(height: 12),
                    HexInputField(
                        label: '写入数据 (hex)', onChanged: (v) => _blockData = v),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                        onPressed: _blockData.isNotEmpty &&
                                _sc.isNotEmpty &&
                                _bl.isNotEmpty
                            ? () =>
                                _execute(HfFelicaCmd.wrbl(_sc, _bl, _blockData))
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
                            ? () => _execute(HfFelicaCmd.raw(_rawHex))
                            : null,
                        icon: const Icon(Icons.send, size: 18),
                        label: const Text('发送')),
                  ],
                ))),
      ]),
    );
  }
}
