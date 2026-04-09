/// Mifare DESFire operations page.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pm3gui/state/app_state.dart';
import 'package:pm3gui/services/pm3_commands.dart';
import 'package:pm3gui/ui/components/components.dart';

class HfMfdesPage extends StatefulWidget {
  const HfMfdesPage({super.key});

  @override
  State<HfMfdesPage> createState() => _HfMfdesPageState();
}

class _HfMfdesPageState extends State<HfMfdesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String _aid = '';
  String _fid = '';
  String _key = '';
  int _keyNumber = 0;
  String _algorithm = 'aes';
  String _writeData = '';

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
    return Column(children: [
      TabBar(controller: _tabController, tabs: const [
        Tab(text: '信息'),
        Tab(text: '应用'),
        Tab(text: '文件'),
        Tab(text: '管理'),
      ]),
      Expanded(
          child: TabBarView(controller: _tabController, children: [
        _buildInfoTab(),
        _buildAppTab(),
        _buildFileTab(),
        _buildManageTab(),
      ])),
    ]);
  }

  Widget _buildInfoTab() {
    return Row(children: [
      SizedBox(
          width: 220,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ActionCard(
                      title: '检测',
                      subtitle: '检测 DESFire 卡片',
                      icon: Icons.search,
                      onTap: () => _execute(HfMfdesCmd.detect())),
                  ActionCard(
                      title: '信息',
                      subtitle: '读取卡片基本信息',
                      icon: Icons.info_outline,
                      onTap: () => _execute(HfMfdesCmd.info())),
                  ActionCard(
                      title: '获取 UID',
                      subtitle: '获取卡片 UID',
                      icon: Icons.credit_card,
                      onTap: () => _execute(HfMfdesCmd.getuid())),
                  ActionCard(
                      title: '空闲内存',
                      subtitle: '查看可用内存',
                      icon: Icons.storage,
                      onTap: () => _execute(HfMfdesCmd.freemem())),
                  ActionCard(
                      title: '检查密钥',
                      subtitle: '检查默认密钥',
                      icon: Icons.security,
                      onTap: () => _execute(HfMfdesCmd.chk())),
                  ActionCard(
                      title: 'MAD',
                      subtitle: '查看应用目录',
                      icon: Icons.list_alt,
                      onTap: () => _execute(HfMfdesCmd.mad())),
                ]),
          )),
      Expanded(
          child: Padding(
        padding: const EdgeInsets.all(8),
        child: ResultDisplay(
            command: _lastCmd,
            result: _result,
            isLoading: _isLoading,
            onClear: () => setState(() {
                  _result = '';
                  _lastCmd = '';
                })),
      )),
    ]);
  }

  Widget _buildAppTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          ElevatedButton.icon(
              onPressed: () => _execute(HfMfdesCmd.getaids()),
              icon: const Icon(Icons.list, size: 18),
              label: const Text('列出 AID')),
          ElevatedButton.icon(
              onPressed: () => _execute(HfMfdesCmd.lsapp()),
              icon: const Icon(Icons.apps, size: 18),
              label: const Text('列出应用')),
        ]),
        const SizedBox(height: 16),
        Card(
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('选择应用',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    HexInputField(
                        label: 'AID (3 字节 hex)',
                        byteLength: 3,
                        onChanged: (v) => _aid = v,
                        prefixIcon: Icons.apps),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                        onPressed: _aid.length == 6
                            ? () => _execute(HfMfdesCmd.selectapp(_aid))
                            : null,
                        icon: const Icon(Icons.check_circle, size: 18),
                        label: const Text('选择')),
                  ],
                ))),
      ]),
    );
  }

  Widget _buildFileTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          ElevatedButton.icon(
              onPressed: () => _execute(HfMfdesCmd.getfileids()),
              icon: const Icon(Icons.folder_open, size: 18),
              label: const Text('列出文件')),
          ElevatedButton.icon(
              onPressed: () => _execute(HfMfdesCmd.lsfiles()),
              icon: const Icon(Icons.description, size: 18),
              label: const Text('文件详情')),
          ElevatedButton.icon(
              onPressed: () =>
                  _execute(HfMfdesCmd.dump(aid: _aid.isEmpty ? null : _aid)),
              icon: const Icon(Icons.download, size: 18),
              label: const Text('转储应用')),
        ]),
        const SizedBox(height: 16),
        Card(
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('文件读写',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    HexInputField(
                        label: 'FID',
                        byteLength: 1,
                        onChanged: (v) => _fid = v,
                        prefixIcon: Icons.tag),
                    const SizedBox(height: 8),
                    Row(children: [
                      ElevatedButton.icon(
                          onPressed: _fid.isNotEmpty
                              ? () => _execute(HfMfdesCmd.read(
                                  aid: _aid.isEmpty ? null : _aid, fid: _fid))
                              : null,
                          icon: const Icon(Icons.visibility, size: 18),
                          label: const Text('读取')),
                      const SizedBox(width: 8),
                    ]),
                    const SizedBox(height: 8),
                    HexInputField(
                        label: '写入数据 (hex)', onChanged: (v) => _writeData = v),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                        onPressed: _writeData.isNotEmpty && _fid.isNotEmpty
                            ? () => _execute(HfMfdesCmd.write(_writeData,
                                aid: _aid.isEmpty ? null : _aid, fid: _fid))
                            : null,
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('写入')),
                  ],
                ))),
      ]),
    );
  }

  Widget _buildManageTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Card(
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('认证',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(children: [
                      SizedBox(
                          width: 100,
                          child: TextFormField(
                            decoration: const InputDecoration(labelText: '密钥号'),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            onChanged: (v) => _keyNumber = int.tryParse(v) ?? 0,
                          )),
                      const SizedBox(width: 12),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'aes', label: Text('AES')),
                          ButtonSegment(value: 'des', label: Text('DES')),
                          ButtonSegment(value: '3des', label: Text('3DES')),
                        ],
                        selected: {_algorithm},
                        onSelectionChanged: (v) =>
                            setState(() => _algorithm = v.first),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    HexInputField(
                        label: '密钥 (hex)',
                        byteLength: 16,
                        onChanged: (v) => _key = v,
                        prefixIcon: Icons.vpn_key),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                        onPressed: _key.isNotEmpty
                            ? () => _execute(HfMfdesCmd.auth(
                                _keyNumber.toString(), _key,
                                algo: _algorithm))
                            : null,
                        icon: const Icon(Icons.lock_open, size: 18),
                        label: const Text('认证')),
                  ],
                ))),
        const SizedBox(height: 12),
        ActionCard(
            title: '密钥设置',
            subtitle: '获取密钥设置信息',
            icon: Icons.settings,
            onTap: () => _execute(HfMfdesCmd.getkeysettings())),
        ActionCard(
            title: '格式化 PICC',
            subtitle: '删除所有应用和数据',
            icon: Icons.delete_forever,
            onTap: () => _confirmThenExecute(
                '确认格式化', '此操作将删除所有应用和数据，不可恢复！', HfMfdesCmd.formatpicc())),
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
