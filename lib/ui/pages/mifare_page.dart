/// Mifare operations page — read/write/attack Mifare Classic cards.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_selector/file_selector.dart' as fs;
import 'package:pm3gui/state/app_state.dart';
import 'package:pm3gui/services/pm3_commands.dart';
import 'package:pm3gui/services/file_dialog_service.dart';

class MifarePage extends StatefulWidget {
  const MifarePage({super.key});

  @override
  State<MifarePage> createState() => _MifarePageState();
}

class _MifarePageState extends State<MifarePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedCardSize = '1K';
  String _keyA = 'FFFFFFFFFFFF';
  int _selectedBlock = 0;
  String _selectedKeyType = 'A';
  String _writeData = '';
  String _quickKeyFile = '';
  String _quickDumpFile = '';
  String _scriptName = '';

  // 命令结果
  String _lastResult = '';
  bool _isExecuting = false;
  StreamSubscription<String>? _outputSub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _outputSub?.cancel();
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

  /// 执行命令并捕获结果到 _lastResult
  void _executeWithResult(String cmd) {
    final appState = context.read<AppState>();
    if (!appState.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未连接 PM3')),
      );
      return;
    }

    setState(() {
      _isExecuting = true;
      _lastResult = '';
    });

    final buffer = StringBuffer();
    _outputSub?.cancel();
    _outputSub = appState.pm3.outputStream.listen((line) {
      // 过滤掉 [pm3] 自身发送的命令回显
      if (!line.startsWith('[pm3]')) {
        buffer.writeln(line);
        setState(() => _lastResult = buffer.toString());
      }
    });

    appState.sendCommand(cmd);

    // 设定超时自动停止监听
    Future.delayed(const Duration(seconds: 5), () {
      _outputSub?.cancel();
      _outputSub = null;
      if (mounted) setState(() => _isExecuting = false);
    });
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
              const Text('卡片类型：',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'MINI', label: Text('Mini')),
                  ButtonSegment(value: '1K', label: Text('1K')),
                  ButtonSegment(value: '2K', label: Text('2K')),
                  ButtonSegment(value: '4K', label: Text('4K')),
                ],
                selected: {_selectedCardSize},
                onSelectionChanged: (v) =>
                    setState(() => _selectedCardSize = v.first),
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
    final appState = context.watch<AppState>();
    final effectiveKey = _quickKeyFile.trim().isNotEmpty
        ? _quickKeyFile.trim()
        : (appState.preferredMfKeyFile ?? '');
    final effectiveDump = _quickDumpFile.trim().isNotEmpty
        ? _quickDumpFile.trim()
        : (appState.preferredMfDumpFile ?? '');
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
                  const Text('Dump/Restore 参数（可选）',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: _quickKeyFile,
                    decoration: InputDecoration(
                      labelText: '密钥文件 --keys (可选)',
                      hintText: appState.preferredMfKeyFile ?? '留空则使用 PM3 默认',
                      prefixIcon: const Icon(Icons.vpn_key, size: 18),
                    ),
                    onChanged: (v) => _quickKeyFile = v,
                    style:
                        const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: _quickDumpFile,
                    decoration: InputDecoration(
                      labelText: '转储文件 --file (可选)',
                      hintText: appState.preferredMfDumpFile ??
                          'dump:输出文件 / restore:输入文件',
                      prefixIcon: const Icon(Icons.file_open, size: 18),
                    ),
                    onChanged: (v) => _quickDumpFile = v,
                    style:
                        const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          final path =
                              await FileDialogService.pickSingleFilePath(
                            desktopTypeGroups: const [
                              fs.XTypeGroup(
                                  label: 'key',
                                  extensions: ['bin', 'dic', 'txt'])
                            ],
                          );
                          if (path != null) {
                            setState(() => _quickKeyFile = path);
                          }
                        },
                        icon: const Icon(Icons.vpn_key, size: 16),
                        label: const Text('选择密钥文件'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final path =
                              await FileDialogService.pickSingleFilePath(
                            desktopTypeGroups: const [
                              fs.XTypeGroup(
                                  label: 'dump',
                                  extensions: ['bin', 'eml', 'json', 'dump'])
                            ],
                          );
                          if (path != null) {
                            setState(() => _quickDumpFile = path);
                          }
                        },
                        icon: const Icon(Icons.file_open, size: 16),
                        label: const Text('选择转储文件'),
                      ),
                      TextButton.icon(
                        onPressed: () => setState(() {
                          _quickKeyFile = '';
                          _quickDumpFile = '';
                        }),
                        icon: const Icon(Icons.cleaning_services, size: 16),
                        label: const Text('清空自定义'),
                      ),
                    ],
                  ),
                  if (appState.preferredMfKeyFile != null ||
                      appState.preferredMfDumpFile != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      '默认来源：key=${appState.preferredMfKeyFile ?? '-'}; '
                      'dump=${appState.preferredMfDumpFile ?? '-'}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
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
            _execute(Pm3Commands.hfMfDump(
              flag,
              keyFile: effectiveKey.isEmpty ? null : effectiveKey,
              dumpFile: effectiveDump.isEmpty ? null : effectiveDump,
            ));
          }),
          _actionCard('恢复卡片', '将转储写回卡片', Icons.upload, () {
            _execute(Pm3Commands.hfMfRestore(
              flag,
              keyFile: effectiveKey.isEmpty ? null : effectiveKey,
              dumpFile: effectiveDump.isEmpty ? null : effectiveDump,
            ));
          }),
          _actionCard('喗探', '捕获卡片通信', Icons.hearing, () {
            _execute(Pm3Commands.hf14aSniff());
          }),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('更多卡型破解/诊断（参考命令文档）',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _execute(HfMfuCmd.cchk()),
                        icon: const Icon(Icons.security, size: 16),
                        label: const Text('MFU CCheck'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _execute(HfMfdesCmd.chk()),
                        icon: const Icon(Icons.lock_open, size: 16),
                        label: const Text('DESFire CHK'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _execute(Hf14bCmd.info()),
                        icon: const Icon(Icons.contactless, size: 16),
                        label: const Text('ISO14443-B INFO'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _execute(Hf14aCmd.cuids(count: 20)),
                        icon: const Icon(Icons.qr_code, size: 16),
                        label: const Text('采集 CUID'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    initialValue: _scriptName,
                    decoration: const InputDecoration(
                      labelText: 'PM3 脚本名 (script run <name>)',
                      hintText: '例如: mifare/mf_autopwn',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) => _scriptName = v.trim(),
                    style:
                        const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _execute(ScriptCmd.list()),
                        icon: const Icon(Icons.list, size: 16),
                        label: const Text('列出脚本'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _scriptName.isEmpty
                            ? null
                            : () => _execute(ScriptCmd.run(_scriptName)),
                        icon: const Icon(Icons.play_arrow, size: 16),
                        label: const Text('运行脚本'),
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
                  const Text('已知密钥',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: _keyA,
                        decoration:
                            const InputDecoration(labelText: '密钥 (hex)'),
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
                      onSelectionChanged: (v) =>
                          setState(() => _selectedKeyType = v.first),
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
            _execute(Pm3Commands.hfMfNested(
                flag, _selectedBlock, _selectedKeyType, _keyA));
          }),
          _actionCard('Static Nested', '适用于静态 nonce 卡片', Icons.repeat, () {
            _execute(Pm3Commands.hfMfStaticNested(
                flag, _selectedBlock, _selectedKeyType, _keyA));
          }),
          _actionCard('Hardnested', '高级密钥恢复', Icons.security, () {
            _execute(Pm3Commands.hfMfHardnested(
                _selectedBlock, _selectedKeyType, _keyA, 0, 'A'));
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
                  const Text('块操作',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                        child: TextFormField(
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
                      onSelectionChanged: (v) =>
                          setState(() => _selectedKeyType = v.first),
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

          // 读取块按钮
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Icon(Icons.visibility,
                  color: Theme.of(context).colorScheme.primary),
              title: const Text('读取块'),
              subtitle: Text('读取单个块数据',
                  style: TextStyle(fontSize: 12, color: Colors.grey[400])),
              trailing: _isExecuting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.play_arrow),
              onTap: () {
                _executeWithResult(Pm3Commands.hfMfReadBlock(
                    _selectedBlock, _selectedKeyType, _keyA));
              },
            ),
          ),
          const SizedBox(height: 8),

          // 写入数据
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('写入数据',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: '数据 (32位 hex)',
                      hintText: '例如 00000000000000000000000000000000',
                    ),
                    style: const TextStyle(fontFamily: 'monospace'),
                    onChanged: (v) => _writeData = v,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _writeData.length == 32
                          ? () {
                              _executeWithResult(Pm3Commands.hfMfWriteBlock(
                                  _selectedBlock,
                                  _selectedKeyType,
                                  _keyA,
                                  _writeData));
                            }
                          : null,
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('写入块'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ---- 命令结果框 ----
          if (_lastResult.isNotEmpty || _isExecuting)
            Card(
              color: Colors.grey[900],
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(
                        _isExecuting ? Icons.hourglass_top : Icons.terminal,
                        size: 16,
                        color: _isExecuting ? Colors.amber : Colors.green,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isExecuting ? '执行中...' : '命令结果',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const Spacer(),
                      if (_lastResult.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.copy, size: 16),
                          tooltip: '复制结果',
                          onPressed: () {
                            Clipboard.setData(
                                ClipboardData(text: _lastResult.trim()));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('已复制到剪贴板'),
                                  duration: Duration(seconds: 1)),
                            );
                          },
                          visualDensity: VisualDensity.compact,
                        ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        tooltip: '清除结果',
                        onPressed: () => setState(() {
                          _lastResult = '';
                          _isExecuting = false;
                        }),
                        visualDensity: VisualDensity.compact,
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxHeight: 300),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          _lastResult.trim().isEmpty
                              ? '等待结果...'
                              : _lastResult.trim(),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
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
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('取消')),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _execute(Pm3Commands.hfMfMagicWipe());
                    },
                    child:
                        const Text('擦除', style: TextStyle(color: Colors.red)),
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

  Widget _actionCard(
      String title, String subtitle, IconData icon, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        subtitle: Text(subtitle,
            style: TextStyle(fontSize: 12, color: Colors.grey[400])),
        trailing: const Icon(Icons.play_arrow),
        onTap: onTap,
      ),
    );
  }
}
