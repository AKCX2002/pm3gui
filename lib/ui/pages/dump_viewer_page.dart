/// Dump viewer page — open/view/edit/export Mifare dump files.
///
/// This is the core offline feature — works without PM3 hardware.
library;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pm3gui/models/mifare_card.dart';
import 'package:pm3gui/models/access_bits.dart';
import 'package:pm3gui/parsers/dump_parser.dart';
import 'package:pm3gui/parsers/eml_parser.dart';
import 'package:pm3gui/parsers/bin_parser.dart';
import 'package:pm3gui/parsers/json_dump_parser.dart';

class DumpViewerPage extends StatefulWidget {
  const DumpViewerPage({super.key});

  @override
  State<DumpViewerPage> createState() => _DumpViewerPageState();
}

class _DumpViewerPageState extends State<DumpViewerPage> with SingleTickerProviderStateMixin {
  MifareCard? _card;
  DumpResult? _dumpResult;
  String? _filePath;
  String? _error;
  String _format = '';
  int _selectedSector = 0;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;
      final path = result.files.single.path;
      if (path == null) return;
      final dumpResult = await parseDumpFile(path);
      setState(() {
        _dumpResult = dumpResult;
        _card = dumpResult.card;
        _filePath = path;
        _format = dumpResult.format;
        _error = dumpResult.error;
        _selectedSector = 0;
      });
    } catch (e) {
      setState(() => _error = 'Error: $e');
    }
  }

  Future<void> _exportAs(String format) async {
    if (_card == null) return;
    String? savePath = await FilePicker.platform.saveFile(
      dialogTitle: '导出转储文件',
      fileName: 'dump.$format',
    );
    if (savePath == null) return;
    try {
      switch (format) {
        case 'eml':
          await File(savePath).writeAsString(exportToEml(_card!));
        case 'bin':
          await File(savePath).writeAsBytes(exportToBin(_card!));
        case 'json':
          await File(savePath).writeAsString(exportToJson(_card!));
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已导出到 $savePath')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导出失败: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildToolbar(),
        if (_error != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            color: Colors.red.withValues(alpha: 0.1),
            child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
          ),
        if (_filePath != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(children: [
              Icon(Icons.insert_drive_file, size: 14, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Expanded(child: Text('$_filePath (format: $_format)', style: TextStyle(fontSize: 12, color: Colors.grey[500]), overflow: TextOverflow.ellipsis)),
            ]),
          ),
        const Divider(height: 1),
        if (_card != null)
          TabBar(controller: _tabController, labelColor: Theme.of(context).colorScheme.primary, tabs: const [
            Tab(text: '扇区视图', icon: Icon(Icons.grid_view, size: 18)),
            Tab(text: '深度分析', icon: Icon(Icons.analytics, size: 18)),
          ]),
        if (_card != null)
          Expanded(child: TabBarView(controller: _tabController, children: [
            // Tab 0: 扇区视图
            Row(children: [
              SizedBox(width: 80, child: _buildSectorList()),
              const VerticalDivider(width: 1),
              Expanded(child: _buildSectorView()),
            ]),
            // Tab 1: 深度分析
            _buildAnalysisView(),
          ]))
        else
          const Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.file_open, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('打开转储文件 (.eml, .bin, .json, .dump)', style: TextStyle(color: Colors.grey, fontSize: 16)),
            SizedBox(height: 8),
            Text('支持 Mifare Classic Mini / 1K / 2K / 4K', style: TextStyle(color: Colors.grey)),
          ]))),
      ],
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Row(children: [
        ElevatedButton.icon(onPressed: _openFile, icon: const Icon(Icons.file_open, size: 18), label: const Text('打开文件')),
        const SizedBox(width: 8),
        if (_card != null) ...[
          PopupMenuButton<String>(
            onSelected: _exportAs,
            child: const Chip(avatar: Icon(Icons.save_alt, size: 18), label: Text('导出为')),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'eml', child: Text('.eml (文本)')),
              const PopupMenuItem(value: 'bin', child: Text('.bin (二进制)')),
              const PopupMenuItem(value: 'json', child: Text('.json (PM3 格式)')),
            ],
          ),
          const Spacer(),
          Chip(
            avatar: const Icon(Icons.nfc, size: 18),
            label: Text('${_card!.cardType.label} | UID: ${_card!.uid}', style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          ),
        ],
      ]),
    );
  }

  Widget _buildSectorList() {
    return ListView.builder(
      itemCount: _card!.cardType.sectorCount,
      itemBuilder: (context, index) {
        final isSelected = index == _selectedSector;
        return ListTile(
          dense: true,
          selected: isSelected,
          selectedTileColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
          title: Text('Sec $index', style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.bold : null)),
          onTap: () => setState(() => _selectedSector = index),
        );
      },
    );
  }

  Widget _buildSectorView() {
    if (_card == null) return const Center(child: Text('无卡片数据'));
    final ct = _card!.cardType;
    final sector = _selectedSector;
    final firstBlock = ct.sectorFirstBlock[sector];
    final blockCount = ct.blocksPerSector[sector];
    final trailerBlockIdx = ct.trailerBlock(sector);

    SectorAccessInfo? accessInfo;
    try {
      accessInfo = decodeSectorAccess(_card!, sector);
      if (!accessInfo.isValid) accessInfo = null;
    } catch (_) {}

    final sectorKey = _card!.sectorKeys[sector];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('扩区 $sector  (块 $firstBlock\u2013$trailerBlockIdx)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Row(children: [_keyChip('Key A', sectorKey.keyA), const SizedBox(width: 8), _keyChip('Key B', sectorKey.keyB)]),
        const SizedBox(height: 12),
        for (var i = 0; i < blockCount; i++)
          _buildBlockRow(firstBlock + i, firstBlock + i == trailerBlockIdx, accessInfo, i),
        if (accessInfo != null) ...[
          const SizedBox(height: 16),
          const Divider(),
          const Text('访问控制条件', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildAccessTable(accessInfo),
        ],
      ]),
    );
  }

  Widget _buildBlockRow(int block, bool isTrailer, SectorAccessInfo? accessInfo, int blockInSector) {
    final data = (block < _card!.blocks.length) ? _card!.blocks[block] : '??' * 16;
    Color bgColor = Colors.transparent;
    String label = 'Data';
    if (block == 0 && _selectedSector == 0) { label = '制造商块'; bgColor = Colors.blue.withValues(alpha: 0.1); }
    else if (isTrailer) { label = '尾块'; bgColor = Colors.orange.withValues(alpha: 0.1); }

    int? cValue;
    if (accessInfo != null) {
      if (isTrailer) { cValue = accessInfo.trailerBits; }
      else if (blockInSector < accessInfo.dataBlockBits.length) { cValue = accessInfo.dataBlockBits[blockInSector]; }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(4)),
      child: Row(children: [
        SizedBox(width: 50, child: Text('B$block', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13))),
        SizedBox(width: 70, child: Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[400]))),
        Expanded(child: isTrailer ? _buildTrailerRow(data) : Text(_fmtHex(data), style: const TextStyle(fontFamily: 'monospace', fontSize: 13))),
        if (cValue != null) Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
          child: Text('C$cValue', style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
        ),
      ]),
    );
  }

  Widget _buildTrailerRow(String data) {
    if (data.length < 32) return Text(_fmtHex(data), style: const TextStyle(fontFamily: 'monospace', fontSize: 13));
    final keyA = data.substring(0, 12);
    final access = data.substring(12, 20);
    final keyB = data.substring(20, 32);
    return Row(children: [
      Text(_fmtHex(keyA), style: const TextStyle(fontFamily: 'monospace', fontSize: 13, color: Colors.greenAccent)),
      const Text(' '),
      Text(_fmtHex(access), style: const TextStyle(fontFamily: 'monospace', fontSize: 13, color: Colors.orangeAccent)),
      const Text(' '),
      Text(_fmtHex(keyB), style: const TextStyle(fontFamily: 'monospace', fontSize: 13, color: Colors.cyanAccent)),
    ]);
  }

  Widget _buildAccessTable(SectorAccessInfo info) {
    final allBits = [...info.dataBlockBits, info.trailerBits];
    return Table(
      border: TableBorder.all(color: Colors.grey.withValues(alpha: 0.3)),
      columnWidths: const {0: FixedColumnWidth(60), 1: FixedColumnWidth(40), 2: FlexColumnWidth()},
      children: [
        const TableRow(decoration: BoxDecoration(color: Color(0xFF2A2A3C)), children: [
          Padding(padding: EdgeInsets.all(6), child: Text('块', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          Padding(padding: EdgeInsets.all(6), child: Text('C', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          Padding(padding: EdgeInsets.all(6), child: Text('说明', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
        ]),
        for (var i = 0; i < allBits.length; i++)
          TableRow(children: [
            Padding(padding: const EdgeInsets.all(6), child: Text(i == allBits.length - 1 ? '尾块' : '数据 $i', style: const TextStyle(fontSize: 12))),
            Padding(padding: const EdgeInsets.all(6), child: Text('${allBits[i]}', style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
            Padding(padding: const EdgeInsets.all(6), child: Text(_accessDesc(allBits[i], isTrailer: i == allBits.length - 1), style: const TextStyle(fontSize: 12))),
          ]),
      ],
    );
  }

  String _accessDesc(int c, {bool isTrailer = false}) {
    if (isTrailer) {
      const d = {0:'KeyA: 写 KeyA|访控|KeyB', 1:'KeyA: 写 KeyA|访控; KeyB: 读写', 2:'仅可读访控', 3:'KeyA: 写访控; KeyB: 读写', 4:'KeyA: 写 KeyA|访控; KeyB: 读写', 5:'KeyB: 写全部', 6:'已锁定', 7:'已锁定'};
      return d[c] ?? '未知';
    }
    const d = {0:'读写 Key A 或 B', 1:'可读 A/B，不可写', 2:'可读 A/B，不可写', 3:'读写仅 Key B', 4:'读: A/B，写: B，减: A/B (值块)', 5:'仅 Key B 可读', 6:'读: A/B，写/加: B，减: A/B (值块)', 7:'已锁定'};
    return d[c] ?? '未知';
  }

  Widget _keyChip(String label, String key) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$label: ', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
        Text(key.isEmpty ? '------' : key, style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: key.isEmpty ? Colors.grey : Colors.white)),
      ]),
    );
  }

  String _fmtHex(String hex) {
    final buf = StringBuffer();
    for (var i = 0; i < hex.length; i += 2) {
      if (i > 0) buf.write(' ');
      buf.write(hex.substring(i, (i + 2).clamp(0, hex.length)));
    }
    return buf.toString();
  }

  // ======================================================================
  //  深度分析视图
  // ======================================================================
  Widget _buildAnalysisView() {
    if (_dumpResult == null || _card == null) {
      return const Center(child: Text('无数据'));
    }
    final a = _dumpResult!.analysis;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // --- 概览卡片
        _analysisCard('📋 概览', [
          _kvRow('卡片类型', _card!.cardType.label),
          _kvRow('UID', _card!.uid.isNotEmpty ? _card!.uid : '未知'),
          _kvRow('总块数', '${a.totalBlocks}'),
          _kvRow('空白数据块', '${a.emptyBlockCount}'),
          _kvRow('数据使用率', '${a.usagePercent.toStringAsFixed(1)}%'),
          _kvRow('值块数', '${a.valueBlocks.length}'),
        ]),
        const SizedBox(height: 12),

        // --- 制造商信息
        if (a.manufacturerInfo != null)
          _analysisCard('🏭 制造商块 (Block 0)', [
            _kvRow('UID', a.manufacturerInfo!.uid),
            _kvRow('BCC', '${a.manufacturerInfo!.bcc} ${a.manufacturerInfo!.bccValid ? "✅" : "❌"}'),
            _kvRow('SAK', a.manufacturerInfo!.sak),
            _kvRow('ATQA', a.manufacturerInfo!.atqa),
            _kvRow('芯片类型', a.manufacturerInfo!.chipType),
            _kvRow('制造商', a.manufacturerInfo!.manufacturer),
            _kvRow('原始数据', _fmtHex(a.manufacturerInfo!.rawHex)),
          ]),
        if (a.manufacturerInfo != null) const SizedBox(height: 12),

        // --- 密钥分析
        _analysisCard('🔑 密钥分析', [
          _kvRow('扇区总数', '${a.keyAnalysis.totalSectors}'),
          _kvRow('已知 Key A', '${a.keyAnalysis.foundKeyA} / ${a.keyAnalysis.totalSectors}'),
          _kvRow('已知 Key B', '${a.keyAnalysis.foundKeyB} / ${a.keyAnalysis.totalSectors}'),
          _kvRow('所有密钥相同', a.keyAnalysis.allKeysIdentical ? '是' : '否'),
          _kvRow('存在空白密钥', a.keyAnalysis.hasBlankKeys ? '是 ⚠️' : '否'),
          if (a.keyAnalysis.keyAGroups.isNotEmpty) ...[
            const Divider(),
            const Text('Key A 分组:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            for (final e in a.keyAnalysis.keyAGroups.entries)
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 2),
                child: Text('${e.key} → 扇区 ${e.value.join(", ")}',
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
              ),
          ],
          if (a.keyAnalysis.keyBGroups.isNotEmpty) ...[
            const Divider(),
            const Text('Key B 分组:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            for (final e in a.keyAnalysis.keyBGroups.entries)
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 2),
                child: Text('${e.key} → 扇区 ${e.value.join(", ")}',
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
              ),
          ],
          if (a.keyAnalysis.defaultMatches.isNotEmpty) ...[
            const Divider(),
            const Text('⚠️ 默认密钥匹配:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.orangeAccent)),
            for (final m in a.keyAnalysis.defaultMatches)
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 2),
                child: Text('扇区 ${m.sector} Key${m.keyType}: ${m.keyHex} (${m.keyName})',
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.orangeAccent)),
              ),
          ],
        ]),
        const SizedBox(height: 12),

        // --- MAD
        if (a.madInfo != null)
          _analysisCard('📂 MAD 应用目录 (v${a.madInfo!.version})', [
            _kvRow('CRC', a.madInfo!.crc),
            _kvRow('Info', a.madInfo!.infoBytes),
            const Divider(),
            for (final e in a.madInfo!.entries)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(children: [
                  SizedBox(width: 60, child: Text('扇区 ${e.sector}', style: const TextStyle(fontSize: 12))),
                  SizedBox(width: 80, child: Text('0x${e.aid.toRadixString(16).padLeft(4, '0')}',
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
                  Expanded(child: Text(e.description, style: const TextStyle(fontSize: 12))),
                ]),
              ),
          ]),
        if (a.madInfo != null) const SizedBox(height: 12),

        // --- 值块
        if (a.valueBlocks.isNotEmpty)
          _analysisCard('💰 值块', [
            for (final v in a.valueBlocks)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(children: [
                  SizedBox(width: 80, child: Text('块 ${v.blockNumber}', style: const TextStyle(fontSize: 12))),
                  SizedBox(width: 100, child: Text('扇区 ${v.sectorNumber}', style: const TextStyle(fontSize: 12))),
                  Expanded(child: Text('值: ${v.value}  地址: ${v.address}',
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.bold))),
                ]),
              ),
          ]),
        if (a.valueBlocks.isNotEmpty) const SizedBox(height: 12),

        // --- 扇区概览表
        _analysisCard('📊 扇区概览', [
          for (final s in a.sectors)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(children: [
                SizedBox(width: 50, child: Text('S${s.sectorNumber}', style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
                SizedBox(width: 110, child: Text('A:${s.keyA}', style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: s.isKeyADefault ? Colors.orangeAccent : Colors.greenAccent))),
                SizedBox(width: 110, child: Text('B:${s.keyB}', style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: s.isKeyBDefault ? Colors.orangeAccent : Colors.cyanAccent))),
                if (s.accessInfo != null)
                  Text(s.accessInfo!.isValid ? '✅ 访控有效' : '❌ 访控无效', style: const TextStyle(fontSize: 11))
                else
                  const Text('- 无访控', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ]),
            ),
        ]),
        const SizedBox(height: 12),

        // --- 数据块 ASCII
        _analysisCard('📝 数据块 ASCII 视图', [
          for (final s in a.sectors)
            for (final b in s.blocks.where((x) => !x.isTrailer && !x.isEmpty))
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Row(children: [
                  SizedBox(width: 50, child: Text('B${b.blockNumber}', style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.grey))),
                  Expanded(child: Text(b.ascii, style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
                ]),
              ),
        ]),
      ]),
    );
  }

  Widget _analysisCard(String title, List<Widget> children) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...children,
        ]),
      ),
    );
  }

  Widget _kvRow(String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(children: [
        SizedBox(width: 120, child: Text(key, style: TextStyle(fontSize: 12, color: Colors.grey[400]))),
        Expanded(child: SelectableText(value, style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
      ]),
    );
  }
}
