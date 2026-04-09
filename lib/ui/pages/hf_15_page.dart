/// ISO 15693 operations page.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pm3gui/state/app_state.dart';
import 'package:pm3gui/services/pm3_commands.dart';
import 'package:pm3gui/ui/components/components.dart';

class Hf15Page extends StatefulWidget {
  const Hf15Page({super.key});

  @override
  State<Hf15Page> createState() => _Hf15PageState();
}

class _Hf15PageState extends State<Hf15Page>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  int _blockNumber = 0;
  String _blockData = '';
  String _uid = '';

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
              subtitle: '自动读取 ISO15693',
              icon: Icons.nfc,
              onTap: () => _execute(Hf15Cmd.reader())),
          ActionCard(
              title: '标签信息',
              subtitle: '读取标签基本信息',
              icon: Icons.info_outline,
              onTap: () => _execute(Hf15Cmd.info())),
          ActionCard(
              title: '转储卡片',
              subtitle: '读取全部数据',
              icon: Icons.download,
              onTap: () => _execute(Hf15Cmd.dump())),
          ActionCard(
              title: '擦除卡片',
              subtitle: '清空卡片数据',
              icon: Icons.delete_forever,
              onTap: () =>
                  _confirmThenExecute('确认擦除', '此操作不可恢复！', Hf15Cmd.wipe())),
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
                          onPressed: () => _execute(Hf15Cmd.rdbl(_blockNumber)),
                          icon: const Icon(Icons.visibility, size: 18),
                          label: const Text('读取块')),
                    ]),
                    const SizedBox(height: 12),
                    HexInputField(
                        label: '写入数据 (4 字节 hex)',
                        byteLength: 4,
                        onChanged: (v) => _blockData = v),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                        onPressed: _blockData.length == 8
                            ? () =>
                                _execute(Hf15Cmd.wrbl(_blockNumber, _blockData))
                            : null,
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('写入块')),
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
            title: '查找 AFI',
            subtitle: '扫描应用族标识符',
            icon: Icons.search,
            onTap: () => _execute(Hf15Cmd.findafi())),
        ActionCard(
            title: '模拟卡片',
            subtitle: '模拟 ISO15693 标签',
            icon: Icons.play_arrow,
            onTap: () => _execute(Hf15Cmd.sim())),
        ActionCard(
            title: '嗅探通信',
            subtitle: '捕获读卡器通信',
            icon: Icons.hearing,
            onTap: () => _execute(Hf15Cmd.sniff())),
        const Divider(),
        Card(
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('设置 UID',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    HexInputField(
                        label: 'UID (8 字节 hex)',
                        byteLength: 8,
                        onChanged: (v) => _uid = v,
                        prefixIcon: Icons.credit_card),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                        onPressed: _uid.length == 16
                            ? () => _execute(Hf15Cmd.csetuid(_uid))
                            : null,
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('设置 UID')),
                  ],
                ))),
      ]),
    );
  }

  void _confirmThenExecute(String title, String msg, String cmd) {
    showDialog(
        context: context,
        builder: (_) => AlertDialog(
              title: Text(title),
              content: Text(msg),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消')),
                TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _execute(cmd);
                    },
                    child: const Text('确认')),
              ],
            ));
  }
}
