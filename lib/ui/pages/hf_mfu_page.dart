/// Mifare Ultralight / NTAG operations page.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pm3gui/state/app_state.dart';
import 'package:pm3gui/services/pm3_commands.dart';
import 'package:pm3gui/ui/components/components.dart';

class HfMfuPage extends StatefulWidget {
  const HfMfuPage({super.key});

  @override
  State<HfMfuPage> createState() => _HfMfuPageState();
}

class _HfMfuPageState extends State<HfMfuPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  int _blockNumber = 0;
  String _blockData = '';
  String _password = '';
  String _uid = '';
  String _emuFile = '';

  // Result state
  String _lastCmd = '';
  String _result = '';
  bool _isLoading = false;
  StreamSubscription<String>? _sub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
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
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '信息'),
            Tab(text: '读写'),
            Tab(text: 'NDEF'),
            Tab(text: '模拟器'),
            Tab(text: '工具'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildInfoTab(),
              _buildReadWriteTab(),
              _buildNdefTab(),
              _buildEmulatorTab(),
              _buildToolsTab(),
            ],
          ),
        ),
      ],
    );
  }

  // ── Info tab ──────────────────────────────────────────────
  Widget _buildInfoTab() {
    return Row(
      children: [
        SizedBox(
          width: 220,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ActionCard(
                    title: '获取信息',
                    subtitle: '读取 MFU/NTAG 标签',
                    icon: Icons.info_outline,
                    onTap: () => _execute(HfMfuCmd.info())),
                ActionCard(
                    title: '转储卡片',
                    subtitle: '读取全部数据到文件',
                    icon: Icons.download,
                    onTap: () => _execute(HfMfuCmd.dump())),
                ActionCard(
                    title: '擦除卡片',
                    subtitle: '清空卡片数据',
                    icon: Icons.delete_forever,
                    onTap: () => _confirmThenExecute(
                        '确认擦除', '此操作不可恢复！', HfMfuCmd.wipe())),
              ],
            ),
          ),
        ),
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
              }),
            ),
          ),
        ),
      ],
    );
  }

  // ── Read / Write tab ──────────────────────────────────────
  Widget _buildReadWriteTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('块操作',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      SizedBox(
                        width: 100,
                        child: TextFormField(
                          decoration: const InputDecoration(labelText: '块号'),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          onChanged: (v) => _blockNumber = int.tryParse(v) ?? 0,
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () => _execute(HfMfuCmd.rdbl(_blockNumber)),
                        icon: const Icon(Icons.visibility, size: 18),
                        label: const Text('读取块'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  HexInputField(
                    label: '写入数据 (hex)',
                    byteLength: 4,
                    onChanged: (v) => _blockData = v,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _blockData.length == 8
                        ? () =>
                            _execute(HfMfuCmd.wrbl(_blockNumber, _blockData))
                        : null,
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('写入块'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('密码认证',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  HexInputField(
                    label: '密码 (4 字节 hex)',
                    byteLength: 4,
                    onChanged: (v) => _password = v,
                    prefixIcon: Icons.vpn_key,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _password.length == 8
                        ? () => _execute(HfMfuCmd.cauth(_password))
                        : null,
                    icon: const Icon(Icons.lock_open, size: 18),
                    label: const Text('认证'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── NDEF tab ──────────────────────────────────────────────
  Widget _buildNdefTab() {
    return Row(
      children: [
        SizedBox(
          width: 220,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ActionCard(
                    title: '读取 NDEF',
                    subtitle: '读取 NFC 数据交换格式',
                    icon: Icons.article,
                    onTap: () => _execute(HfMfuCmd.ndefRead())),
              ],
            ),
          ),
        ),
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
              }),
            ),
          ),
        ),
      ],
    );
  }

  // ── Emulator tab ──────────────────────────────────────────
  Widget _buildEmulatorTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                      prefixIcon: Icon(Icons.file_open, size: 18),
                    ),
                    style:
                        const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    onChanged: (v) => _emuFile = v.trim(),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _execute(HfMfuCmd.eload(
                            _emuFile.isEmpty ? 'dump' : _emuFile)),
                        icon: const Icon(Icons.upload, size: 18),
                        label: const Text('加载到模拟器'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _execute(HfMfuCmd.esave(
                            file: _emuFile.isEmpty ? null : _emuFile)),
                        icon: const Icon(Icons.save, size: 18),
                        label: const Text('保存模拟器'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _execute(HfMfuCmd.eview()),
                        icon: const Icon(Icons.visibility, size: 18),
                        label: const Text('查看'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _execute(HfMfuCmd.sim()),
                        icon: const Icon(Icons.play_arrow, size: 18),
                        label: const Text('模拟'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tools tab ─────────────────────────────────────────────
  Widget _buildToolsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ActionCard(
              title: '生成密钥',
              subtitle: 'keygen — 根据 UID 推导密钥',
              icon: Icons.vpn_key,
              onTap: () => _execute(HfMfuCmd.keygen())),
          ActionCard(
              title: '密码推导',
              subtitle: 'pwdgen — 推导 NTAG 密码',
              icon: Icons.password,
              onTap: () => _execute(HfMfuCmd.pwdgen())),
          ActionCard(
              title: '密钥检查',
              subtitle: 'cchk — 检查常用密钥',
              icon: Icons.security,
              onTap: () => _execute(HfMfuCmd.cchk())),
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
                    label: 'UID (7 字节 hex)',
                    byteLength: 7,
                    onChanged: (v) => _uid = v,
                    prefixIcon: Icons.credit_card,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _uid.length == 14
                        ? () => _execute(HfMfuCmd.setuid(_uid))
                        : null,
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('设置 UID'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────
  void _confirmThenExecute(String title, String msg, String cmd) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
              onPressed: () {
                Navigator.pop(context);
                _execute(cmd);
              },
              child: const Text('确认')),
        ],
      ),
    );
  }
}
