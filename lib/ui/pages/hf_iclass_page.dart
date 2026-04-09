/// iCLASS / Picopass operations page.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pm3gui/state/app_state.dart';
import 'package:pm3gui/services/pm3_commands.dart';
import 'package:pm3gui/ui/components/components.dart';

class HfIclassPage extends StatefulWidget {
  const HfIclassPage({super.key});

  @override
  State<HfIclassPage> createState() => _HfIclassPageState();
}

class _HfIclassPageState extends State<HfIclassPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  int _blockNumber = 0;
  String _key = '';
  String _blockData = '';
  String _emuFile = '';

  String _lastCmd = '';
  String _result = '';
  bool _isLoading = false;
  StreamSubscription<String>? _sub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
    return Column(
      children: [
        TabBar(controller: _tabController, tabs: const [
          Tab(text: '信息'),
          Tab(text: '读写'),
          Tab(text: '破解'),
          Tab(text: '模拟器'),
        ]),
        Expanded(
          child: TabBarView(controller: _tabController, children: [
            _buildInfoTab(),
            _buildReadWriteTab(),
            _buildCrackTab(),
            _buildEmulatorTab(),
          ]),
        ),
      ],
    );
  }

  Widget _buildInfoTab() {
    return SplitPageLayout(
      side: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ActionCard(
              title: '获取信息',
              subtitle: '读取 iCLASS 标签',
              icon: Icons.info_outline,
              onTap: () => _execute(HfIclassCmd.info())),
          ActionCard(
              title: '读取卡片',
              subtitle: 'reader 模式',
              icon: Icons.nfc,
              onTap: () => _execute(HfIclassCmd.reader())),
          ActionCard(
              title: '转储卡片',
              subtitle: '转储全部块到文件',
              icon: Icons.download,
              onTap: () =>
                  _execute(HfIclassCmd.dump(key: _key.isEmpty ? null : _key))),
        ],
      ),
      main: ResultDisplay(
        command: _lastCmd,
        result: _result,
        isLoading: _isLoading,
        onClear: () => setState(() {
          _result = '';
          _lastCmd = '';
        }),
      ),
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
                    HexInputField(
                        label: '密钥 (8 字节 hex)',
                        byteLength: 8,
                        onChanged: (v) => _key = v,
                        prefixIcon: Icons.vpn_key),
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
                        onPressed: () => _execute(HfIclassCmd.rdbl(_blockNumber,
                            key: _key.isEmpty ? null : _key)),
                        icon: const Icon(Icons.visibility, size: 18),
                        label: const Text('读取块'),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    HexInputField(
                        label: '写入数据 (8 字节 hex)',
                        byteLength: 8,
                        onChanged: (v) => _blockData = v),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _blockData.length == 16
                          ? () => _execute(HfIclassCmd.wrbl(
                              _blockNumber, _blockData,
                              key: _key.isEmpty ? null : _key))
                          : null,
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('写入块'),
                    ),
                  ],
                ))),
      ]),
    );
  }

  Widget _buildCrackTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ActionCard(
            title: '检查密钥',
            subtitle: '检查常用默认密钥',
            icon: Icons.security,
            onTap: () => _execute(HfIclassCmd.chk())),
        ActionCard(
            title: 'Loclass 攻击',
            subtitle: '离线破解 iCLASS 密钥',
            icon: Icons.bolt,
            onTap: () => _execute(HfIclassCmd.loclass())),
        ActionCard(
            title: '嗅探通信',
            subtitle: '捕获卡片与读卡器通信',
            icon: Icons.hearing,
            onTap: () => _execute(HfIclassCmd.sniff())),
      ]),
    );
  }

  Widget _buildEmulatorTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Card(
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('模拟器操作',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextFormField(
                      decoration: const InputDecoration(
                          labelText: '文件路径（可选）',
                          hintText: '留空使用默认',
                          prefixIcon: Icon(Icons.file_open, size: 18)),
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 12),
                      onChanged: (v) => _emuFile = v.trim(),
                    ),
                    const SizedBox(height: 12),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      ElevatedButton.icon(
                          onPressed: () => _execute(HfIclassCmd.eload(
                              _emuFile.isEmpty ? 'dump' : _emuFile)),
                          icon: const Icon(Icons.upload, size: 18),
                          label: const Text('加载到模拟器')),
                      OutlinedButton.icon(
                          onPressed: () => _execute(HfIclassCmd.eview()),
                          icon: const Icon(Icons.visibility, size: 18),
                          label: const Text('查看')),
                      ElevatedButton.icon(
                          onPressed: () => _execute(HfIclassCmd.sim()),
                          icon: const Icon(Icons.play_arrow, size: 18),
                          label: const Text('模拟')),
                    ]),
                  ],
                ))),
      ]),
    );
  }
}
