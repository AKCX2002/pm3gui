/// Mifare operations page — read/write/attack Mifare Classic cards.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pm3gui/state/app_state.dart';
import 'package:pm3gui/services/pm3_commands.dart';

class MifarePage extends StatefulWidget {
  const MifarePage({super.key});

  @override
  State<MifarePage> createState() => _MifarePageState();
}

class _MifarePageState extends State<MifarePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedCardSize = '1K';
  String _keyA = 'FFFFFFFFFFFF';
  int _selectedBlock = 0;
  String _selectedKeyType = 'A';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
        // Card size selector
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              const Text('卡片类型：', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'MINI', label: Text('Mini')),
                  ButtonSegment(value: '1K', label: Text('1K')),
                  ButtonSegment(value: '2K', label: Text('2K')),
                  ButtonSegment(value: '4K', label: Text('4K')),
                ],
                selected: {_selectedCardSize},
                onSelectionChanged: (v) => setState(() => _selectedCardSize = v.first),
              ),
            ],
          ),
        ),
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '快捷操作'),
            Tab(text: '密钥攻击'),
            Tab(text: '读写块'),
            Tab(text: '魔术卡'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildQuickActions(),
              _buildKeyAttack(),
              _buildReadWrite(),
              _buildMagicCard(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    final flag = Pm3Commands.cardSizeFlag(_selectedCardSize);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _actionCard('检测卡片', '扫描 HF 14A 标签', Icons.search, () {
            _execute(Pm3Commands.hf14aSearch());
          }),
          _actionCard('卡片信息', '获取详细卡片信息', Icons.info_outline, () {
            _execute(Pm3Commands.hfMfInfo());
          }),
          _actionCard('自动破解', '自动密钥恢复', Icons.bolt, () {
            _execute(Pm3Commands.hfMfAutopwn(flag));
          }),
          _actionCard('转储卡片', '读取所有扇区到文件', Icons.download, () {
            _execute(Pm3Commands.hfMfDump(flag));
          }),
          _actionCard('恢复卡片', '将转储写回卡片', Icons.upload, () {
            _execute(Pm3Commands.hfMfRestore(flag));
          }),
          _actionCard('喗探', '捕获卡片通信', Icons.hearing, () {
            _execute(Pm3Commands.hf14aSniff());
          }),
        ],
      ),
    );
  }

  Widget _buildKeyAttack() {
    final flag = Pm3Commands.cardSizeFlag(_selectedCardSize);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Known key input
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('已知密钥', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: _keyA,
                        decoration: const InputDecoration(labelText: '密钥 (hex)'),
                        onChanged: (v) => _keyA = v,
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'A', label: Text('A')),
                        ButtonSegment(value: 'B', label: Text('B')),
                      ],
                      selected: {_selectedKeyType},
                      onSelectionChanged: (v) => setState(() => _selectedKeyType = v.first),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: '0',
                        decoration: const InputDecoration(labelText: '块号'),
                        onChanged: (v) => _selectedBlock = int.tryParse(v) ?? 0,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _actionCard('检查密钥', '用默认密钥尝试所有扇区', Icons.vpn_key, () {
            _execute(Pm3Commands.hfMfCheck(flag));
          }),
          _actionCard('Nested 攻击', '用已知密钥查找其他密钥', Icons.account_tree, () {
            _execute(Pm3Commands.hfMfNested(flag, _selectedBlock, _selectedKeyType, _keyA));
          }),
          _actionCard('Static Nested', '适用于静态 nonce 卡片', Icons.repeat, () {
            _execute(Pm3Commands.hfMfStaticNested(flag, _selectedBlock, _selectedKeyType, _keyA));
          }),
          _actionCard('Hardnested', '高级密钥恢复', Icons.security, () {
            _execute(Pm3Commands.hfMfHardnested(_selectedBlock, _selectedKeyType, _keyA, 0, 'A'));
          }),
          _actionCard('Darkside', '无需已知密钥', Icons.dark_mode, () {
            _execute(Pm3Commands.hfMfDarkside());
          }),
        ],
      ),
    );
  }

  Widget _buildReadWrite() {
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
                  const Text('块操作', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: TextFormField(
                      initialValue: '0',
                      decoration: const InputDecoration(labelText: '块号'),
                      onChanged: (v) => _selectedBlock = int.tryParse(v) ?? 0,
                      keyboardType: TextInputType.number,
                    )),
                    const SizedBox(width: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'A', label: Text('Key A')),
                        ButtonSegment(value: 'B', label: Text('Key B')),
                      ],
                      selected: {_selectedKeyType},
                      onSelectionChanged: (v) => setState(() => _selectedKeyType = v.first),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: _keyA,
                    decoration: const InputDecoration(labelText: '密钥 (hex)'),
                    onChanged: (v) => _keyA = v,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _actionCard('读取块', '读取单个块数据', Icons.visibility, () {
            _execute(Pm3Commands.hfMfReadBlock(_selectedBlock, _selectedKeyType, _keyA));
          }),
          const SizedBox(height: 12),
          const Text('写入数据', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextFormField(
            decoration: const InputDecoration(
              labelText: '数据 (32位 hex)',
              hintText: '例如 00000000000000000000000000000000',
            ),
            style: const TextStyle(fontFamily: 'monospace'),
            onFieldSubmitted: (data) {
              _execute(Pm3Commands.hfMfWriteBlock(_selectedBlock, _selectedKeyType, _keyA, data));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMagicCard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange, size: 36),
                  SizedBox(height: 8),
                  Text(
                    '魔术卡操作',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '这些命令仅适用于 Gen1A/Gen2 (CUID) 魔术卡。\n'
                    '写入块 0 可能会损坏非魔术卡！',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.orange),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _actionCard('读取块 0', '读取制造商块', Icons.visibility, () {
            _execute(Pm3Commands.hfMfMagicGetBlock(0));
          }),
          _actionCard('擦除卡片', '恢复出厂状态', Icons.delete_forever, () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('擦除卡片？'),
                content: const Text('这将重置所有块。确定吗？'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _execute(Pm3Commands.hfMfMagicWipe());
                    },
                    child: const Text('擦除', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            );
          }),
          _actionCard('加载模拟器', '将转储加载到模拟器', Icons.memory, () {
            _execute(Pm3Commands.hfMfEmulatorClear());
          }),
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
