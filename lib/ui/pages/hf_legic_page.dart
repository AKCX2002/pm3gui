/// Legic operations page.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pm3gui/state/app_state.dart';
import 'package:pm3gui/services/pm3_commands.dart';
import 'package:pm3gui/ui/components/components.dart';

class HfLegicPage extends StatefulWidget {
  const HfLegicPage({super.key});

  @override
  State<HfLegicPage> createState() => _HfLegicPageState();
}

class _HfLegicPageState extends State<HfLegicPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _offset = 0;
  int _length = 16;
  String _writeData = '';

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
              title: '标签信息',
              subtitle: '读取 Legic 标签',
              icon: Icons.info_outline,
              onTap: () => _execute(HfLegicCmd.info())),
          ActionCard(
              title: '转储',
              subtitle: '转储全部数据',
              icon: Icons.download,
              onTap: () => _execute(HfLegicCmd.dump())),
          ActionCard(
              title: '擦除',
              subtitle: '清空卡片数据',
              icon: Icons.delete_forever,
              onTap: () =>
                  _confirmThenExecute('确认擦除', '此操作不可恢复！', HfLegicCmd.wipe())),
          ActionCard(
              title: '模拟',
              subtitle: '模拟 Legic 标签',
              icon: Icons.play_arrow,
              onTap: () => _execute(HfLegicCmd.sim())),
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
                    const Text('读写操作',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(children: [
                      SizedBox(
                          width: 100,
                          child: TextFormField(
                            decoration: const InputDecoration(labelText: '偏移'),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            onChanged: (v) => _offset = int.tryParse(v) ?? 0,
                          )),
                      const SizedBox(width: 8),
                      SizedBox(
                          width: 100,
                          child: TextFormField(
                            decoration: const InputDecoration(labelText: '长度'),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            initialValue: '16',
                            onChanged: (v) => _length = int.tryParse(v) ?? 16,
                          )),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                          onPressed: () =>
                              _execute(HfLegicCmd.rdbl(_offset, _length)),
                          icon: const Icon(Icons.visibility, size: 18),
                          label: const Text('读取')),
                    ]),
                    const SizedBox(height: 12),
                    HexInputField(
                        label: '写入数据 (hex)', onChanged: (v) => _writeData = v),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                        onPressed: _writeData.isNotEmpty
                            ? () =>
                                _execute(HfLegicCmd.wrbl(_offset, _writeData))
                            : null,
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('写入')),
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
