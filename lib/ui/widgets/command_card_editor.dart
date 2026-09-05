import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pm3gui/models/mifare_card.dart';
import 'package:pm3gui/services/file_dialog_service.dart';
import 'package:pm3gui/state/app_state.dart';

/// 对命令采集草稿直接编辑；完整文件的分析/回写沿用转储查看器。
class CommandCardEditor extends StatefulWidget {
  const CommandCardEditor({super.key, this.openedCard});
  final MifareCard? openedCard;
  @override
  State<CommandCardEditor> createState() => _CommandCardEditorState();
}

class _CommandCardEditorState extends State<CommandCardEditor> {
  final _command = TextEditingController();
  int _sector = 0;
  String? _error;
  bool _running = false;

  @override
  void dispose() {
    _command.dispose();
    super.dispose();
  }

  Future<void> _edit(
      String title, String value, void Function(String) apply) async {
    final controller = TextEditingController(text: value);
    String? error;
    final route = DialogRoute<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(
              builder: (ctx, update) => AlertDialog(
                title: Text(title),
                content: SizedBox(
                    width: 540,
                    child: TextField(
                      controller: controller,
                      autofocus: true,
                      decoration: InputDecoration(
                          errorText: error, helperText: '允许空格；? 表示未知。清空移除该项。'),
                    )),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('取消')),
                  FilledButton(
                      onPressed: () {
                        try {
                          apply(controller.text);
                          Navigator.pop(ctx);
                        } catch (e) {
                          update(() => error = '$e');
                        }
                      },
                      child: const Text('应用')),
                ],
              ),
            ));
    await Navigator.of(context).push(route);
    await route.completed;
    controller.dispose();
    if (mounted) setState(() {});
  }

  Future<void> _save(String format) async {
    final app = context.read<AppState>();
    final card = app.commandCard;
    try {
      // Validate and snapshot before opening the dialog; output may continue arriving.
      final bytes = format == 'bin'
          ? card.exportBin()
          : format == 'key.bin'
              ? card.exportKeyBin()
              : null;
      final text = switch (format) {
        'json' => card.exportDraft(),
        'eml' => card.exportEml(),
        'dic' => card.exportDictionary(),
        _ => '',
      };
      final name = format == 'json'
          ? 'command-card.json'
          : 'hf-mf-${card.uid.isEmpty ? 'unknown' : card.uid}-${format == 'dic' || format == 'key.bin' ? 'key' : 'dump'}.${format == 'key.bin' ? 'bin' : format}';
      final path =
          await FileDialogService.pickSaveFilePath(suggestedName: name);
      if (path == null) return;
      if (bytes != null) {
        await File(path).writeAsBytes(bytes);
      } else {
        await File(path).writeAsString(text);
      }
      if (format == 'dic' || format == 'key.bin') {
        app.setPreferredMfKeyFile(path);
      }
      if (format == 'bin' || format == 'eml') app.setPreferredMfDumpFile(path);
      await app.scanForFiles();
      if (mounted) setState(() => _error = '已保存：$path');
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _load() async {
    final card = context.read<AppState>().commandCard;
    try {
      final path = await FileDialogService.pickSingleFilePath();
      if (path == null) return;
      card.importDraft(await File(path).readAsString());
      if (mounted) {
        setState(() {
          _sector = 0;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final card = app.commandCard;
    if (_sector >= card.type.sectorCount) _sector = 0;
    final first = card.type.sectorFirstBlock[_sector];
    return ListView(padding: const EdgeInsets.all(12), children: [
      const Text('命令结果自动采集到此处，点击密钥或块数据即可编辑。换卡前请选择“新卡”；? 表示未知。'),
      const SizedBox(height: 8),
      Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
                '${card.type.label} · UID ${card.uid.isEmpty ? '未识别' : card.uid} · ${card.blocks.length} 块 · ${card.keysA.length + card.keysB.length} 项密钥'),
            PopupMenuButton<CardType>(
              tooltip: '新卡 / 选择容量',
              onSelected: (type) => setState(() {
                card.clear(cardType: type);
                _sector = 0;
              }),
              itemBuilder: (_) => [
                for (final type in [cardMini, card1K, card2K, card4K])
                  PopupMenuItem(
                      value: type, child: Text('新卡 ${type.label}（清空当前草稿）'))
              ],
              child: const Chip(label: Text('新卡 / 容量')),
            ),
            OutlinedButton(onPressed: _load, child: const Text('打开草稿')),
            OutlinedButton(
                onPressed: () => _save('json'), child: const Text('保存草稿')),
            OutlinedButton(
                onPressed: () => _save('dic'), child: const Text('导出密钥字典')),
            OutlinedButton(
                onPressed: () => _save('key.bin'),
                child: const Text('导出密钥 BIN')),
            if (widget.openedCard != null)
              OutlinedButton(
                  onPressed: () {
                    try {
                      card.importCard(widget.openedCard!);
                      setState(() => _sector = 0);
                    } catch (e) {
                      setState(() => _error = '$e');
                    }
                  },
                  child: const Text('以已打开文件替换草稿')),
            OutlinedButton(
                onPressed: () => _save('eml'), child: const Text('导出 EML')),
            OutlinedButton(
                onPressed: () => _save('bin'), child: const Text('导出 BIN')),
          ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
            child: TextField(
                controller: _command,
                decoration: const InputDecoration(
                    labelText: '直接命令',
                    hintText: '例如 hf mf chk --1k',
                    border: OutlineInputBorder()))),
        const SizedBox(width: 8),
        FilledButton(
            onPressed: !app.isConnected || _running
                ? null
                : () async {
                    if (_command.text.trim().isEmpty) return;
                    setState(() => _running = true);
                    try {
                      await app.sendCommand(_command.text.trim());
                    } finally {
                      if (mounted) setState(() => _running = false);
                    }
                  },
            child: Text(_running ? '执行中' : '执行')),
      ]),
      if (_error != null)
        Padding(
            padding: const EdgeInsets.all(8), child: SelectableText(_error!)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, children: [
        DropdownButton<int>(
            value: _sector,
            items: [
              for (var s = 0; s < card.type.sectorCount; s++)
                DropdownMenuItem(value: s, child: Text('扇区 $s'))
            ],
            onChanged: (s) => setState(() => _sector = s!)),
        TextButton(
            onPressed: () => setState(card.keysToTrailers),
            child: const Text('密钥 → 尾块')),
        TextButton(
            onPressed: () => setState(card.trailersToKeys),
            child: const Text('尾块 → 密钥')),
      ]),
      for (final a in [true, false])
        ListTile(
          title: Text('Key ${a ? 'A' : 'B'}'),
          subtitle: Text((a ? card.keysA : card.keysB)[_sector] ?? '未读取',
              style: const TextStyle(fontFamily: 'monospace')),
          trailing: const Icon(Icons.edit),
          onTap: () => _edit(
              '扇区 $_sector · Key ${a ? 'A' : 'B'}',
              (a ? card.keysA : card.keysB)[_sector] ?? '',
              (v) => card.editKey(_sector, a, v)),
        ),
      for (var b = first; b < first + card.type.blocksPerSector[_sector]; b++)
        ListTile(
          title: Text(
              '块 $b${b == card.type.trailerBlock(_sector) ? ' · 尾块' : ''}'),
          subtitle: Text(card.blocks[b] ?? '未读取',
              style: const TextStyle(fontFamily: 'monospace')),
          trailing: const Icon(Icons.edit),
          onTap: () =>
              _edit('块 $b', card.blocks[b] ?? '', (v) => card.editBlock(b, v)),
        ),
    ]);
  }
}
