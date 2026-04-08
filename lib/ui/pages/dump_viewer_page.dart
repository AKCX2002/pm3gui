/// Dump viewer page — open/view/edit/export Mifare dump files.
///
/// This is the core offline feature — works without PM3 hardware.
/// Includes dump viewing, deep analysis, and format conversion.
library;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pm3gui/models/mifare_card.dart';
import 'package:pm3gui/models/access_bits.dart';
import 'package:pm3gui/parsers/dump_parser.dart';
import 'package:pm3gui/parsers/eml_parser.dart';
import 'package:pm3gui/parsers/bin_parser.dart';
import 'package:pm3gui/parsers/json_dump_parser.dart';
import 'package:pm3gui/parsers/key_parser.dart';
import 'package:pm3gui/services/dump_converter.dart';

class DumpViewerPage extends StatefulWidget {
  const DumpViewerPage({super.key});

  @override
  State<DumpViewerPage> createState() => _DumpViewerPageState();
}

class _DumpViewerPageState extends State<DumpViewerPage>
    with SingleTickerProviderStateMixin {
  MifareCard? _card;
  DumpResult? _dumpResult;
  String? _filePath;
  String? _error;
  String _format = '';
  int _selectedSector = 0;
  late TabController _tabController;

  // Converter state
  String? _convertInput;
  String? _convertInputFormat;
  DumpFormat? _convertTarget;
  String? _convertStatus;
  bool _converting = false;
  List<SectorKey>? _extractedKeys;
  String? _keySummary;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
      dialogTitle: '导出文件',
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
        case 'key.bin':
          await File(savePath).writeAsBytes(exportKeysToBin(_card!.sectorKeys));
        case 'dic':
          await File(savePath).writeAsString(
              exportToDic(_card!.sectorKeys, header: 'UID: ${_card!.uid}'));
        case 'keys.txt':
          await File(savePath)
              .writeAsString(exportKeysAsText(_card!.sectorKeys));
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('已导出到 $savePath')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('导出失败: $e')));
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
            child:
                Text(_error!, style: const TextStyle(color: Colors.redAccent)),
          ),
        if (_filePath != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(children: [
              Icon(Icons.insert_drive_file, size: 14, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Expanded(
                  child: Text('$_filePath (format: $_format)',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      overflow: TextOverflow.ellipsis)),
            ]),
          ),
        const Divider(height: 1),
        if (_card != null)
          TabBar(
              controller: _tabController,
              labelColor: Theme.of(context).colorScheme.primary,
              tabs: const [
                Tab(text: '扇区视图', icon: Icon(Icons.grid_view, size: 18)),
                Tab(text: '深度分析', icon: Icon(Icons.analytics, size: 18)),
                Tab(text: '格式转换', icon: Icon(Icons.swap_horiz, size: 18)),
              ]),
        if (_card != null)
          Expanded(
              child: TabBarView(controller: _tabController, children: [
            // Tab 0: 扇区视图
            Row(children: [
              SizedBox(width: 80, child: _buildSectorList()),
              const VerticalDivider(width: 1),
              Expanded(child: _buildSectorView()),
            ]),
            // Tab 1: 深度分析
            _buildAnalysisView(),
            // Tab 2: 格式转换 & 密钥提取
            _buildConverterView(),
          ]))
        else
          const Expanded(
              child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.file_open, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('打开转储文件 (.eml, .bin, .json, .dump)',
                style: TextStyle(color: Colors.grey, fontSize: 16)),
            SizedBox(height: 8),
            Text('支持 Mifare Classic Mini / 1K / 2K / 4K',
                style: TextStyle(color: Colors.grey)),
          ]))),
      ],
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Row(children: [
        ElevatedButton.icon(
            onPressed: _openFile,
            icon: const Icon(Icons.file_open, size: 18),
            label: const Text('打开文件')),
        const SizedBox(width: 8),
        if (_card != null) ...[
          PopupMenuButton<String>(
            onSelected: _exportAs,
            child: const Chip(
                avatar: Icon(Icons.save_alt, size: 18), label: Text('导出为')),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'eml', child: Text('.eml (文本转储)')),
              const PopupMenuItem(value: 'bin', child: Text('.bin (二进制转储)')),
              const PopupMenuItem(value: 'json', child: Text('.json (PM3 格式)')),
              const PopupMenuDivider(),
              const PopupMenuItem(
                  value: 'key.bin', child: Text('.key.bin (二进制密钥)')),
              const PopupMenuItem(value: 'dic', child: Text('.dic (密钥字典)')),
              const PopupMenuItem(
                  value: 'keys.txt', child: Text('.keys.txt (密钥列表)')),
            ],
          ),
          const Spacer(),
          Chip(
            avatar: const Icon(Icons.nfc, size: 18),
            label: Text('${_card!.cardType.label} | UID: ${_card!.uid}',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
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
          selectedTileColor:
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
          title: Text('Sec $index',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : null)),
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
        Text('扩区 $sector  (块 $firstBlock\u2013$trailerBlockIdx)',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Row(children: [
          _keyChip('Key A', sectorKey.keyA),
          const SizedBox(width: 8),
          _keyChip('Key B', sectorKey.keyB)
        ]),
        const SizedBox(height: 12),
        for (var i = 0; i < blockCount; i++)
          _buildBlockRow(
              firstBlock + i, firstBlock + i == trailerBlockIdx, accessInfo, i),
        if (accessInfo != null) ...[
          const SizedBox(height: 16),
          const Divider(),
          const Text('访问控制条件',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildAccessTable(accessInfo),
        ],
      ]),
    );
  }

  Widget _buildBlockRow(int block, bool isTrailer, SectorAccessInfo? accessInfo,
      int blockInSector) {
    final data =
        (block < _card!.blocks.length) ? _card!.blocks[block] : '??' * 16;
    Color bgColor = Colors.transparent;
    String label = 'Data';
    if (block == 0 && _selectedSector == 0) {
      label = '制造商块';
      bgColor = Colors.blue.withValues(alpha: 0.1);
    } else if (isTrailer) {
      label = '尾块';
      bgColor = Colors.orange.withValues(alpha: 0.1);
    }

    int? cValue;
    if (accessInfo != null) {
      if (isTrailer) {
        cValue = accessInfo.trailerBits;
      } else if (blockInSector < accessInfo.dataBlockBits.length) {
        cValue = accessInfo.dataBlockBits[blockInSector];
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration:
          BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(4)),
      child: Row(children: [
        SizedBox(
            width: 50,
            child: Text('B$block',
                style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    fontSize: 13))),
        SizedBox(
            width: 70,
            child: Text(label,
                style: TextStyle(fontSize: 11, color: Colors.grey[400]))),
        Expanded(
            child: isTrailer
                ? _buildTrailerRow(data)
                : Text(_fmtHex(data),
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 13))),
        if (cValue != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4)),
            child: Text('C$cValue',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
          ),
      ]),
    );
  }

  Widget _buildTrailerRow(String data) {
    if (data.length < 32)
      return Text(_fmtHex(data),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13));
    final keyA = data.substring(0, 12);
    final access = data.substring(12, 20);
    final keyB = data.substring(20, 32);
    return Row(children: [
      Text(_fmtHex(keyA),
          style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              color: Colors.greenAccent)),
      const Text(' '),
      Text(_fmtHex(access),
          style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              color: Colors.orangeAccent)),
      const Text(' '),
      Text(_fmtHex(keyB),
          style: const TextStyle(
              fontFamily: 'monospace', fontSize: 13, color: Colors.cyanAccent)),
    ]);
  }

  Widget _buildAccessTable(SectorAccessInfo info) {
    final allBits = [...info.dataBlockBits, info.trailerBits];
    return Table(
      border: TableBorder.all(color: Colors.grey.withValues(alpha: 0.3)),
      columnWidths: const {
        0: FixedColumnWidth(60),
        1: FixedColumnWidth(40),
        2: FlexColumnWidth()
      },
      children: [
        const TableRow(
            decoration: BoxDecoration(color: Color(0xFF2A2A3C)),
            children: [
              Padding(
                  padding: EdgeInsets.all(6),
                  child: Text('块',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12))),
              Padding(
                  padding: EdgeInsets.all(6),
                  child: Text('C',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12))),
              Padding(
                  padding: EdgeInsets.all(6),
                  child: Text('说明',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12))),
            ]),
        for (var i = 0; i < allBits.length; i++)
          TableRow(children: [
            Padding(
                padding: const EdgeInsets.all(6),
                child: Text(i == allBits.length - 1 ? '尾块' : '数据 $i',
                    style: const TextStyle(fontSize: 12))),
            Padding(
                padding: const EdgeInsets.all(6),
                child: Text('${allBits[i]}',
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 12))),
            Padding(
                padding: const EdgeInsets.all(6),
                child: Text(
                    _accessDesc(allBits[i], isTrailer: i == allBits.length - 1),
                    style: const TextStyle(fontSize: 12))),
          ]),
      ],
    );
  }

  String _accessDesc(int c, {bool isTrailer = false}) {
    if (isTrailer) {
      const d = {
        0: 'KeyA: 写 KeyA|访控|KeyB',
        1: 'KeyA: 写 KeyA|访控; KeyB: 读写',
        2: '仅可读访控',
        3: 'KeyA: 写访控; KeyB: 读写',
        4: 'KeyA: 写 KeyA|访控; KeyB: 读写',
        5: 'KeyB: 写全部',
        6: '已锁定',
        7: '已锁定'
      };
      return d[c] ?? '未知';
    }
    const d = {
      0: '读写 Key A 或 B',
      1: '可读 A/B，不可写',
      2: '可读 A/B，不可写',
      3: '读写仅 Key B',
      4: '读: A/B，写: B，减: A/B (值块)',
      5: '仅 Key B 可读',
      6: '读: A/B，写/加: B，减: A/B (值块)',
      7: '已锁定'
    };
    return d[c] ?? '未知';
  }

  Widget _keyChip(String label, String key) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$label: ',
            style: TextStyle(fontSize: 12, color: Colors.grey[400])),
        Text(key.isEmpty ? '------' : key,
            style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: key.isEmpty ? Colors.grey : Colors.white)),
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
            _kvRow('BCC',
                '${a.manufacturerInfo!.bcc} ${a.manufacturerInfo!.bccValid ? "✅" : "❌"}'),
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
          _kvRow('已知 Key A',
              '${a.keyAnalysis.foundKeyA} / ${a.keyAnalysis.totalSectors}'),
          _kvRow('已知 Key B',
              '${a.keyAnalysis.foundKeyB} / ${a.keyAnalysis.totalSectors}'),
          _kvRow('所有密钥相同', a.keyAnalysis.allKeysIdentical ? '是' : '否'),
          _kvRow('存在空白密钥', a.keyAnalysis.hasBlankKeys ? '是 ⚠️' : '否'),
          if (a.keyAnalysis.keyAGroups.isNotEmpty) ...[
            const Divider(),
            const Text('Key A 分组:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            for (final e in a.keyAnalysis.keyAGroups.entries)
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 2),
                child: Text('${e.key} → 扇区 ${e.value.join(", ")}',
                    style:
                        const TextStyle(fontFamily: 'monospace', fontSize: 12)),
              ),
          ],
          if (a.keyAnalysis.keyBGroups.isNotEmpty) ...[
            const Divider(),
            const Text('Key B 分组:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            for (final e in a.keyAnalysis.keyBGroups.entries)
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 2),
                child: Text('${e.key} → 扇区 ${e.value.join(", ")}',
                    style:
                        const TextStyle(fontFamily: 'monospace', fontSize: 12)),
              ),
          ],
          if (a.keyAnalysis.defaultMatches.isNotEmpty) ...[
            const Divider(),
            const Text('⚠️ 默认密钥匹配:',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.orangeAccent)),
            for (final m in a.keyAnalysis.defaultMatches)
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 2),
                child: Text(
                    '扇区 ${m.sector} Key${m.keyType}: ${m.keyHex} (${m.keyName})',
                    style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Colors.orangeAccent)),
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
                  SizedBox(
                      width: 60,
                      child: Text('扇区 ${e.sector}',
                          style: const TextStyle(fontSize: 12))),
                  SizedBox(
                      width: 80,
                      child: Text(
                          '0x${e.aid.toRadixString(16).padLeft(4, '0')}',
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 12))),
                  Expanded(
                      child: Text(e.description,
                          style: const TextStyle(fontSize: 12))),
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
                  SizedBox(
                      width: 80,
                      child: Text('块 ${v.blockNumber}',
                          style: const TextStyle(fontSize: 12))),
                  SizedBox(
                      width: 100,
                      child: Text('扇区 ${v.sectorNumber}',
                          style: const TextStyle(fontSize: 12))),
                  Expanded(
                      child: Text('值: ${v.value}  地址: ${v.address}',
                          style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              fontWeight: FontWeight.bold))),
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
                SizedBox(
                    width: 50,
                    child: Text('S${s.sectorNumber}',
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 12))),
                SizedBox(
                    width: 110,
                    child: Text('A:${s.keyA}',
                        style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: s.isKeyADefault
                                ? Colors.orangeAccent
                                : Colors.greenAccent))),
                SizedBox(
                    width: 110,
                    child: Text('B:${s.keyB}',
                        style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: s.isKeyBDefault
                                ? Colors.orangeAccent
                                : Colors.cyanAccent))),
                if (s.accessInfo != null)
                  Text(s.accessInfo!.isValid ? '✅ 访控有效' : '❌ 访控无效',
                      style: const TextStyle(fontSize: 11))
                else
                  const Text('- 无访控',
                      style: TextStyle(fontSize: 11, color: Colors.grey)),
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
                  SizedBox(
                      width: 50,
                      child: Text('B${b.blockNumber}',
                          style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: Colors.grey))),
                  Expanded(
                      child: Text(b.ascii,
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 12))),
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
          Text(title,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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
        SizedBox(
            width: 120,
            child: Text(key,
                style: TextStyle(fontSize: 12, color: Colors.grey[400]))),
        Expanded(
            child: SelectableText(value,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
      ]),
    );
  }

  // ======================================================================
  //  格式转换 & 密钥提取视图
  // ======================================================================
  Widget _buildConverterView() {
    if (_card == null) return const Center(child: Text('无数据'));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ---- 一键导出全部格式 ----
        _analysisCard('📦 一键导出全部格式', [
          const Text('从当前打开的转储文件导出为所有支持的格式:', style: TextStyle(fontSize: 13)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _exportButton('导出 .eml', Icons.text_snippet, 'eml'),
            _exportButton('导出 .bin', Icons.memory, 'bin'),
            _exportButton('导出 .json', Icons.data_object, 'json'),
            _exportButton('导出 .key.bin', Icons.key, 'key.bin'),
            _exportButton('导出 .dic', Icons.list_alt, 'dic'),
            _exportButton('导出 .keys.txt', Icons.text_fields, 'keys.txt'),
          ]),
        ]),
        const SizedBox(height: 16),

        // ---- 密钥提取 ----
        _analysisCard('🔑 密钥提取', [
          const Text('从当前转储中提取的所有密钥:', style: TextStyle(fontSize: 13)),
          const SizedBox(height: 8),
          _buildKeyTable(),
          const SizedBox(height: 12),
          Row(children: [
            OutlinedButton.icon(
              onPressed: () => _copyKeysToClipboard(),
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('复制全部密钥'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => _copyKeysToClipboard(keyAOnly: true),
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('仅 Key A'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => _copyKeysToClipboard(keyBOnly: true),
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('仅 Key B'),
            ),
          ]),
        ]),
        const SizedBox(height: 16),

        // ---- 独立格式转换 ----
        _analysisCard('🔄 文件格式转换', [
          const Text('选择任意dump/密钥文件, 转换为其他格式:', style: TextStyle(fontSize: 13)),
          const SizedBox(height: 12),

          // Source file
          Row(children: [
            ElevatedButton.icon(
              onPressed: _pickConvertSource,
              icon: const Icon(Icons.file_open, size: 16),
              label: const Text('选择源文件'),
            ),
            const SizedBox(width: 8),
            if (_convertInput != null)
              Expanded(
                child: Text(
                  _convertInput!.split('/').last,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ]),
          const SizedBox(height: 8),

          // Target format
          if (_convertInput != null) ...[
            const Text('目标格式:', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final fmt in _getAvailableTargets())
                ChoiceChip(
                  label: Text(fmt.label, style: const TextStyle(fontSize: 12)),
                  selected: _convertTarget == fmt,
                  onSelected: (sel) {
                    if (sel) setState(() => _convertTarget = fmt);
                  },
                ),
            ]),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed:
                  _convertTarget != null && !_converting ? _doConvert : null,
              icon: _converting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.swap_horiz, size: 16),
              label: Text(_converting ? '转换中...' : '开始转换'),
            ),
          ],

          // Status
          if (_convertStatus != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _convertStatus!.startsWith('✅')
                    ? Colors.green.withValues(alpha: 0.15)
                    : Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(_convertStatus!,
                  style:
                      const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            ),
          ],
        ]),
        const SizedBox(height: 16),

        // ---- 密钥比对 -----
        if (_extractedKeys != null)
          _analysisCard('📋 外部密钥文件', [
            const Text('已加载的外部密钥:', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            _buildExternalKeyTable(),
            const SizedBox(height: 8),
            if (_keySummary != null)
              Text(_keySummary!,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ]),

        // ---- 格式说明 ----
        const SizedBox(height: 16),
        _analysisCard('ℹ️ 格式说明', [
          _fmtDesc('.bin', '原始二进制转储 (16字节/块), PM3默认dump格式'),
          _fmtDesc('.eml', '文本转储 (每行32位十六进制), 用于模拟器加载'),
          _fmtDesc('.json', 'PM3 JSON格式, 含卡片元数据和密钥'),
          _fmtDesc('.key.bin', '二进制密钥文件 (6字节KeyA + 6字节KeyB) × 扇区数'),
          _fmtDesc('.dic', '密钥字典 (每行一个密钥), 用于暴力破解'),
          _fmtDesc('.keys.txt', '可读密钥表 (扇区号 + KeyA + KeyB)'),
        ]),
      ]),
    );
  }

  Widget _exportButton(String label, IconData icon, String format) {
    return OutlinedButton.icon(
      onPressed: () => _exportAs(format),
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _fmtDesc(String ext, String desc) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
            width: 80,
            child: Text(ext,
                style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.bold))),
        Expanded(child: Text(desc, style: const TextStyle(fontSize: 12))),
      ]),
    );
  }

  // ---- Key table for current dump ----
  Widget _buildKeyTable() {
    if (_card == null) return const SizedBox();
    final keys = _card!.sectorKeys;
    return Table(
      border: TableBorder.all(color: Colors.grey.withValues(alpha: 0.3)),
      columnWidths: const {
        0: FixedColumnWidth(60),
        1: FlexColumnWidth(),
        2: FlexColumnWidth(),
      },
      children: [
        const TableRow(
            decoration: BoxDecoration(color: Color(0xFF2A2A3C)),
            children: [
              Padding(
                  padding: EdgeInsets.all(6),
                  child: Text('扇区',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12))),
              Padding(
                  padding: EdgeInsets.all(6),
                  child: Text('Key A',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12))),
              Padding(
                  padding: EdgeInsets.all(6),
                  child: Text('Key B',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12))),
            ]),
        for (var i = 0; i < keys.length; i++)
          TableRow(children: [
            Padding(
                padding: const EdgeInsets.all(6),
                child: Text('$i',
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 12))),
            Padding(
                padding: const EdgeInsets.all(6),
                child: SelectableText(keys[i].keyA.toUpperCase(),
                    style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: _isKnownDefault(keys[i].keyA)
                            ? Colors.orangeAccent
                            : Colors.greenAccent))),
            Padding(
                padding: const EdgeInsets.all(6),
                child: SelectableText(keys[i].keyB.toUpperCase(),
                    style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: _isKnownDefault(keys[i].keyB)
                            ? Colors.orangeAccent
                            : Colors.cyanAccent))),
          ]),
      ],
    );
  }

  Widget _buildExternalKeyTable() {
    if (_extractedKeys == null) return const SizedBox();
    final keys = _extractedKeys!;
    return Table(
      border: TableBorder.all(color: Colors.grey.withValues(alpha: 0.3)),
      columnWidths: const {
        0: FixedColumnWidth(60),
        1: FlexColumnWidth(),
        2: FlexColumnWidth(),
      },
      children: [
        const TableRow(
            decoration: BoxDecoration(color: Color(0xFF2A2A3C)),
            children: [
              Padding(
                  padding: EdgeInsets.all(6),
                  child: Text('扇区',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12))),
              Padding(
                  padding: EdgeInsets.all(6),
                  child: Text('Key A',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12))),
              Padding(
                  padding: EdgeInsets.all(6),
                  child: Text('Key B',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12))),
            ]),
        for (var i = 0; i < keys.length; i++)
          TableRow(children: [
            Padding(
                padding: const EdgeInsets.all(6),
                child: Text('$i',
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 12))),
            Padding(
                padding: const EdgeInsets.all(6),
                child: Text(keys[i].keyA.toUpperCase(),
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 12))),
            Padding(
                padding: const EdgeInsets.all(6),
                child: Text(keys[i].keyB.toUpperCase(),
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 12))),
          ]),
      ],
    );
  }

  bool _isKnownDefault(String key) {
    const defaults = {
      'FFFFFFFFFFFF',
      '000000000000',
      'A0A1A2A3A4A5',
      'B0B1B2B3B4B5',
      'D3F7D3F7D3F7',
      'AABBCCDDEEFF',
    };
    return defaults.contains(key.toUpperCase());
  }

  void _copyKeysToClipboard({bool keyAOnly = false, bool keyBOnly = false}) {
    if (_card == null) return;
    final buf = StringBuffer();
    for (var i = 0; i < _card!.sectorKeys.length; i++) {
      final k = _card!.sectorKeys[i];
      if (keyAOnly) {
        buf.writeln(k.keyA.toUpperCase());
      } else if (keyBOnly) {
        buf.writeln(k.keyB.toUpperCase());
      } else {
        buf.writeln(
            '扇区 ${i.toString().padLeft(2)}  A:${k.keyA.toUpperCase()}  B:${k.keyB.toUpperCase()}');
      }
    }
    Clipboard.setData(ClipboardData(text: buf.toString()));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已复制到剪贴板')));
    }
  }

  // ---- Convert file flow ----

  List<DumpFormat> _getAvailableTargets() {
    if (_convertInput == null || _convertInputFormat == null) return [];
    return allowedTargets(_convertInputFormat!);
  }

  Future<void> _pickConvertSource() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;
    setState(() {
      _convertInput = path;
      _convertInputFormat = path.split('.').last.toLowerCase();
      _convertTarget = null;
      _convertStatus = null;
    });

    // Also try to extract keys for display
    try {
      final (keys, summary) = await extractKeysFromFile(path);
      setState(() {
        _extractedKeys = keys;
        _keySummary = summary;
      });
    } catch (_) {
      // Not a valid key source — that's fine
    }
  }

  Future<void> _doConvert() async {
    if (_convertInput == null || _convertTarget == null) return;
    setState(() {
      _converting = true;
      _convertStatus = null;
    });

    try {
      // Suggest output filename
      final baseName =
          _convertInput!.split('/').last.replaceAll(RegExp(r'\.[^.]+$'), '');
      final defaultName = '$baseName.${_convertTarget!.ext}';

      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: '保存转换文件',
        fileName: defaultName,
      );
      if (savePath == null) {
        setState(() => _converting = false);
        return;
      }

      final result = await convertDumpFile(
        inputPath: _convertInput!,
        outputPath: savePath,
        targetFormat: _convertTarget!,
      );

      setState(() {
        _converting = false;
        if (result.success) {
          _convertStatus = '✅ 转换成功!\n'
              '输出: ${result.outputPath}\n'
              '${result.keySummary ?? ''}';
        } else {
          _convertStatus = '❌ ${result.error}';
        }
      });
    } catch (e) {
      setState(() {
        _converting = false;
        _convertStatus = '❌ 转换异常: $e';
      });
    }
  }
}
