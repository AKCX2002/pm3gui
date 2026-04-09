/// Dump viewer page — open/view/edit/export Mifare dump files.
///
/// This is the core offline feature — works without PM3 hardware.
/// Includes dump viewing, deep analysis, format conversion, and write-back.
library;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart' as fs;
import 'package:provider/provider.dart';
import 'package:pm3gui/models/mifare_card.dart';
import 'package:pm3gui/models/access_bits.dart';
import 'package:pm3gui/parsers/dump_parser.dart';
import 'package:pm3gui/parsers/eml_parser.dart';
import 'package:pm3gui/parsers/bin_parser.dart';
import 'package:pm3gui/parsers/json_dump_parser.dart';
import 'package:pm3gui/parsers/key_parser.dart';
import 'package:pm3gui/services/dump_converter.dart';
import 'package:pm3gui/services/file_dialog_service.dart';
import 'package:pm3gui/services/pm3_commands.dart';
import 'package:pm3gui/state/app_state.dart';

enum _KeyOverride { preserve, overwrite }

enum _QuickWriteMode {
  auto,
  uid,
  cuid,
  fuid,
  gen1a,
  gen3,
  gen4,
}

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

  // Editable block data controllers (per-sector)
  final Map<int, TextEditingController> _blockControllers = {};
  // Editable key controllers
  final Map<int, TextEditingController> _keyAControllers = {};
  final Map<int, TextEditingController> _keyBControllers = {};

  // Write-back state
  String _writeKeyType = 'B'; // default use Key B for auth
  bool _skipBlock0 = true;
  bool _writeTrailers = true;
  bool _processingExternalOpenRequest = false;
  _QuickWriteMode _quickWriteMode = _QuickWriteMode.auto;
  String _gen4Pwd = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (final c in _blockControllers.values) {
      c.dispose();
    }
    for (final c in _keyAControllers.values) {
      c.dispose();
    }
    for (final c in _keyBControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _openFile() async {
    try {
      final path = await FileDialogService.pickSingleFilePath(
        desktopTypeGroups: const [
          fs.XTypeGroup(
            label: 'PM3 dump/key',
            extensions: ['eml', 'bin', 'json', 'dump', 'dic', 'txt'],
          ),
        ],
      );
      if (path == null) return;

      // ── Detect if it's a key-only file ──
      final isKey = await _isKeyFile(path);

      if (isKey) {
        // KEY file → only merge keys, never touch blocks
        await _loadKeyFileOnly(path);
      } else {
        // DUMP file → optionally preserve existing keys
        await _loadDumpFile(path);
      }
    } catch (e) {
      setState(() => _error = 'Error: $e');
    }
  }

  Future<void> _openPath(String path) async {
    try {
      final isKey = await _isKeyFile(path);
      if (isKey) {
        await _loadKeyFileOnly(path);
      } else {
        await _loadDumpFile(path);
      }
    } catch (e) {
      setState(() => _error = 'Error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('打开失败: $e')),
      );
    }
  }

  void _consumePendingOpenRequest(AppState appState) {
    if (_processingExternalOpenRequest) return;
    final pending = appState.pendingIntent;
    if (pending == null || pending.page != AppPage.dumpViewer) return;

    _processingExternalOpenRequest = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final intent = appState.takePendingIntentFor(AppPage.dumpViewer);
      if (intent != null && intent.action == 'open_file') {
        final path = intent.params['path'];
        if (path != null && path.trim().isNotEmpty) {
          await _openPath(path);
        }
      }
      _processingExternalOpenRequest = false;
    });
  }

  /// Detect if a file is a key-only file (.dic text, or .bin with key-file size).
  Future<bool> _isKeyFile(String path) async {
    final ext = path.split('.').last.toLowerCase();

    // .dic / .txt are always key files
    if (ext == 'dic') return true;

    // Check filename pattern: *-key*.bin
    final name = path.split('/').last.split('\\').last.toLowerCase();
    if (name.contains('-key')) return true;

    // For .bin files, check if the size matches a key file layout
    if (ext == 'bin' || ext == 'dump') {
      final file = File(path);
      if (await file.exists()) {
        final size = await file.length();
        // Key file sizes: sectorCount × 12
        const keySizes = {
          5 * 12, // MINI: 60
          16 * 12, // 1K: 192
          32 * 12, // 2K: 384
          40 * 12, // 4K: 480
        };
        if (keySizes.contains(size)) return true;
      }
    }

    return false;
  }

  /// Load a key-only file: merge keys into existing card without overwriting blocks.
  Future<void> _loadKeyFileOnly(String path) async {
    final ext = path.split('.').last.toLowerCase();
    List<SectorKey> newKeys;

    if (ext == 'dic') {
      // Text dictionary — extract unique keys (no sector mapping)
      final text = await File(path).readAsString();
      final keyList = parseDicString(text);
      // Show info only
      setState(() {
        _extractedKeys = null;
        _keySummary = '字典文件: ${keyList.length} 个唯一密钥';
        _error = null;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载字典: ${keyList.length} 个密钥')),
      );
      return;
    }

    // Binary key file
    final bytes = await File(path).readAsBytes();
    newKeys = parseKeyBinBytes(Uint8List.fromList(bytes));

    if (_card != null) {
      // Merge keys into existing card WITHOUT touching block data
      _mergeKeys(newKeys);
      setState(() {
        _error = null;
        _initEditControllers();
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已合并 ${newKeys.length} 个扇区的密钥（块数据保持不变）'),
          backgroundColor: Colors.green.withValues(alpha: 0.8),
        ),
      );
    } else {
      // No card loaded yet — create keys-only card
      final dumpResult = await parseDumpFile(path);
      setState(() {
        _dumpResult = dumpResult;
        _card = dumpResult.card;
        _filePath = path;
        _format = 'key';
        _error = null;
        _selectedSector = 0;
        _initEditControllers();
      });
      if (!mounted) return;
      context.read<AppState>().updateCard(_card!);
    }
  }

  /// Load a dump file, optionally preserving existing keys.
  Future<void> _loadDumpFile(String path) async {
    final dumpResult = await parseDumpFile(path);

    if (_card != null && _card!.sectorKeys.isNotEmpty) {
      // Already have a card with keys — ask user what to do
      if (!mounted) return;
      final choice = await _showKeyOverrideDialog();
      if (choice == null) return; // cancelled

      final oldKeys = _card!.sectorKeys
          .map((k) => SectorKey(keyA: k.keyA, keyB: k.keyB))
          .toList();

      setState(() {
        _dumpResult = dumpResult;
        _card = dumpResult.card;
        _filePath = path;
        _format = dumpResult.format;
        _error = dumpResult.error;
        _selectedSector = 0;
      });

      if (choice == _KeyOverride.preserve) {
        // Restore previously held keys
        _mergeKeys(oldKeys);
      }
      // else: choice == overwrite → use dump's own keys (already set)

      setState(() => _initEditControllers());
      if (!mounted) return;
      context.read<AppState>()
        ..updateCard(_card!)
        ..setPreferredMfDumpFile(path);
    } else {
      // No previous card — just load normally
      setState(() {
        _dumpResult = dumpResult;
        _card = dumpResult.card;
        _filePath = path;
        _format = dumpResult.format;
        _error = dumpResult.error;
        _selectedSector = 0;
        _initEditControllers();
      });
      if (!mounted) return;
      context.read<AppState>()
        ..updateCard(_card!)
        ..setPreferredMfDumpFile(path);
    }
  }

  /// Merge keys from [newKeys] into the current card's sectorKeys.
  void _mergeKeys(List<SectorKey> newKeys) {
    if (_card == null) return;
    final limit = _card!.sectorKeys.length < newKeys.length
        ? _card!.sectorKeys.length
        : newKeys.length;
    for (var s = 0; s < limit; s++) {
      _card!.sectorKeys[s].keyA = newKeys[s].keyA;
      _card!.sectorKeys[s].keyB = newKeys[s].keyB;
    }
  }

  /// Show dialog asking whether to overwrite keys when loading a dump file.
  Future<_KeyOverride?> _showKeyOverrideDialog() async {
    return showDialog<_KeyOverride>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.vpn_key, size: 20),
          SizedBox(width: 8),
          Text('密钥处理'),
        ]),
        content: const SizedBox(
          width: 360,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
              '当前已有密钥数据。加载新的转储文件时，如何处理密钥？',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 16),
            Row(children: [
              Icon(Icons.info_outline, size: 16, color: Colors.grey),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '转储文件的密钥区通常为 FF，而实际密钥可能来自单独的 key 文件',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ]),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(ctx, _KeyOverride.preserve),
            icon: const Icon(Icons.shield, size: 16),
            label: const Text('保留当前密钥'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, _KeyOverride.overwrite),
            icon: const Icon(Icons.sync, size: 16),
            label: const Text('用转储覆盖'),
          ),
        ],
      ),
    );
  }

  Future<void> _setAsPreferredKeyFile() async {
    if (_card == null) return;
    _applyEdits();
    final appState = context.read<AppState>();
    final tmp = File('${Directory.systemTemp.path}/pm3gui-current-keys.bin');
    await tmp.writeAsBytes(exportKeysToBin(_card!.sectorKeys), flush: true);
    appState.setPreferredMfKeyFile(tmp.path);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已设为默认密钥文件: ${tmp.path}')),
      );
    }
  }

  Future<void> _setAsPreferredDumpFile() async {
    if (_card == null) return;
    _applyEdits();
    final appState = context.read<AppState>();
    final tmp = File('${Directory.systemTemp.path}/pm3gui-current-dump.bin');
    await tmp.writeAsBytes(exportToBin(_card!), flush: true);
    appState.setPreferredMfDumpFile(tmp.path);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已设为默认转储文件: ${tmp.path}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    _consumePendingOpenRequest(appState);

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
                child: Text(
                  '$_filePath (format: $_format)',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
          ),
        const Divider(height: 1),
        TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).colorScheme.primary,
          tabs: const [
            Tab(text: '扇区视图', icon: Icon(Icons.grid_view, size: 18)),
            Tab(text: '密钥/编辑', icon: Icon(Icons.edit, size: 18)),
            Tab(text: '深度分析', icon: Icon(Icons.analytics, size: 18)),
            Tab(text: '回写/清空', icon: Icon(Icons.upload, size: 18)),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _card != null
                  ? Row(children: [
                      SizedBox(width: 80, child: _buildSectorList()),
                      const VerticalDivider(width: 1),
                      Expanded(child: _buildSectorView()),
                    ])
                  : _buildEmptyHint('打开转储文件查看扇区数据', Icons.grid_view),
              _card != null
                  ? _buildKeyEditorView()
                  : _buildEmptyHint('打开转储文件或密钥文件以编辑', Icons.edit),
              _card != null
                  ? _buildAnalysisView()
                  : _buildEmptyHint('打开转储文件后可查看深度分析', Icons.analytics),
              _buildWriteBackView(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyHint(String message, IconData icon) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 56, color: Colors.grey.withValues(alpha: 0.3)),
        const SizedBox(height: 16),
        Text(message, style: TextStyle(color: Colors.grey[500], fontSize: 15)),
        const SizedBox(height: 8),
        Text('支持 .eml / .bin / .json / .dump / .dic',
            style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _openFile,
          icon: const Icon(Icons.file_open, size: 16),
          label: const Text('打开文件'),
        ),
      ]),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Row(children: [
        ElevatedButton.icon(
          onPressed: _openFile,
          icon: const Icon(Icons.file_open, size: 18),
          label: const Text('打开文件'),
        ),
        const SizedBox(width: 8),
        if (_card != null) ...[
          OutlinedButton.icon(
            onPressed: _setAsPreferredKeyFile,
            icon: const Icon(Icons.vpn_key, size: 16),
            label: const Text('设为默认密钥'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _setAsPreferredDumpFile,
            icon: const Icon(Icons.save, size: 16),
            label: const Text('设为默认转储'),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            onSelected: _exportAs,
            child: const Chip(
              avatar: Icon(Icons.save_alt, size: 18),
              label: Text('导出为'),
            ),
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
            label: Text(
              '${_card!.cardType.label} | UID: ${_card!.uid}',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ],
      ]),
    );
  }

  Future<void> _exportAs(String format) async {
    if (_card == null) return;

    _applyEdits();
    final appState = context.read<AppState>();

    final autoPath = _buildCategorizedExportPath(format, appState);
    try {
      await _writeExportToPath(autoPath, format);
      _afterExportSuccess(autoPath, format, appState, autoSaved: true);
      return;
    } catch (_) {
      // fallback to manual save
    }

    final savePath = await FileDialogService.pickSaveFilePath(
      suggestedName: _suggestedExportFileName(format),
    );
    if (savePath == null) return;

    try {
      await _writeExportToPath(savePath, format);
      _afterExportSuccess(savePath, format, appState, autoSaved: false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('导出失败: $e')));
      }
    }
  }

  String _suggestedExportFileName(String format) {
    final uid = _card!.uid.toUpperCase().replaceAll(RegExp(r'[^0-9A-F]'), '');
    return switch (format) {
      'eml' => 'hf-mf-$uid-dump.eml',
      'bin' => 'hf-mf-$uid-dump.bin',
      'json' => 'hf-mf-$uid-dump.json',
      'key.bin' => 'hf-mf-$uid-key.bin',
      'dic' => 'hf-mf-$uid-key.dic',
      'keys.txt' => 'hf-mf-$uid-keys.txt',
      _ => 'hf-mf-$uid-export.dat',
    };
  }

  String _buildCategorizedExportPath(String format, AppState appState) {
    final uid = _card!.uid.toUpperCase().replaceAll(RegExp(r'[^0-9A-F]'), '');
    final baseDir = (appState.collectBaseDir != null &&
            appState.collectBaseDir!.trim().isNotEmpty)
        ? appState.collectBaseDir!.trim()
        : '${Directory.current.path}/pm3_files';
    return '$baseDir/hf-mf/$uid/${_suggestedExportFileName(format)}';
  }

  Future<void> _writeExportToPath(String path, String format) async {
    await File(path).parent.create(recursive: true);
    switch (format) {
      case 'eml':
        await File(path).writeAsString(exportToEml(_card!));
      case 'bin':
        await File(path).writeAsBytes(exportToBin(_card!));
      case 'json':
        await File(path).writeAsString(exportToJson(_card!));
      case 'key.bin':
        await File(path).writeAsBytes(exportKeysToBin(_card!.sectorKeys));
      case 'dic':
        await File(path).writeAsString(
          exportToDic(_card!.sectorKeys, header: 'UID: ${_card!.uid}'),
        );
      case 'keys.txt':
        await File(path).writeAsString(exportKeysAsText(_card!.sectorKeys));
    }
  }

  void _afterExportSuccess(
    String savePath,
    String format,
    AppState appState, {
    required bool autoSaved,
  }) {
    const baseMarker = '/hf-mf/';
    if (savePath.contains(baseMarker)) {
      final baseDir = savePath.substring(0, savePath.indexOf(baseMarker));
      appState.setCollectBaseDir(baseDir);
    }

    if (format == 'key.bin') {
      appState.setPreferredMfKeyFile(savePath);
    }
    if (format == 'bin') {
      appState.setPreferredMfDumpFile(savePath);
    }
    appState.scanForFiles();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            autoSaved ? '已自动归类导出: $savePath' : '已导出: $savePath',
          ),
        ),
      );
    }
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
    if (data.length < 32) {
      return Text(_fmtHex(data),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13));
    }
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
    final path = await FileDialogService.pickSingleFilePath(
      desktopTypeGroups: const [
        fs.XTypeGroup(
          label: 'PM3 dump/key',
          extensions: ['eml', 'bin', 'json', 'dump', 'dic', 'txt'],
        ),
      ],
    );
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

      final savePath = await FileDialogService.pickSaveFilePath(
        dialogTitle: '保存转换文件',
        suggestedName: defaultName,
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

  // ======================================================================
  //  初始化编辑控制器
  // ======================================================================
  void _initEditControllers() {
    // Clean up old controllers
    for (final c in _blockControllers.values) {
      c.dispose();
    }
    for (final c in _keyAControllers.values) {
      c.dispose();
    }
    for (final c in _keyBControllers.values) {
      c.dispose();
    }
    _blockControllers.clear();
    _keyAControllers.clear();
    _keyBControllers.clear();

    if (_card == null) return;

    // Create block data controllers
    for (var i = 0; i < _card!.blocks.length; i++) {
      _blockControllers[i] = TextEditingController(text: _card!.blocks[i]);
    }

    // Create key controllers
    for (var s = 0; s < _card!.sectorKeys.length; s++) {
      _keyAControllers[s] =
          TextEditingController(text: _card!.sectorKeys[s].keyA.toUpperCase());
      _keyBControllers[s] =
          TextEditingController(text: _card!.sectorKeys[s].keyB.toUpperCase());
    }
  }

  /// 应用编辑：将控制器中的值写回 _card 模型
  void _applyEdits() {
    if (_card == null) return;
    for (var i = 0; i < _card!.blocks.length; i++) {
      if (_blockControllers.containsKey(i)) {
        _card!.blocks[i] = _blockControllers[i]!.text.toUpperCase();
      }
    }
    for (var s = 0; s < _card!.sectorKeys.length; s++) {
      if (_keyAControllers.containsKey(s)) {
        _card!.sectorKeys[s].keyA = _keyAControllers[s]!.text.toUpperCase();
      }
      if (_keyBControllers.containsKey(s)) {
        _card!.sectorKeys[s].keyB = _keyBControllers[s]!.text.toUpperCase();
      }
    }
    setState(() {});
    context.read<AppState>().updateCard(_card!);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('修改已应用到内存')));
    }
  }

  // ======================================================================
  //  密钥编辑视图
  // ======================================================================
  Widget _buildKeyEditorView() {
    if (_card == null) return const Center(child: Text('无数据'));

    return Row(
      children: [
        // 左侧：密钥编辑表
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 操作栏
                Row(children: [
                  const Text('🔑 密钥编辑',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: _applyEdits,
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('应用修改'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      // 全部设为默认密钥
                      for (var s = 0; s < _card!.sectorKeys.length; s++) {
                        _keyAControllers[s]?.text = 'FFFFFFFFFFFF';
                        _keyBControllers[s]?.text = 'FFFFFFFFFFFF';
                      }
                    },
                    icon: const Icon(Icons.restore, size: 16),
                    label: const Text('全部默认'),
                  ),
                ]),
                const SizedBox(height: 12),

                // 密钥编辑表格
                Table(
                  border: TableBorder.all(
                      color: Colors.grey.withValues(alpha: 0.3)),
                  columnWidths: const {
                    0: FixedColumnWidth(55),
                    1: FlexColumnWidth(),
                    2: FlexColumnWidth(),
                  },
                  children: [
                    const TableRow(
                        decoration: BoxDecoration(color: Color(0xFF2A2A3C)),
                        children: [
                          Padding(
                              padding: EdgeInsets.all(8),
                              child: Text('扇区',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12))),
                          Padding(
                              padding: EdgeInsets.all(8),
                              child: Text('Key A',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12))),
                          Padding(
                              padding: EdgeInsets.all(8),
                              child: Text('Key B',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12))),
                        ]),
                    for (var s = 0; s < _card!.sectorKeys.length; s++)
                      TableRow(children: [
                        Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text('$s',
                                style: const TextStyle(
                                    fontFamily: 'monospace', fontSize: 12))),
                        Padding(
                          padding: const EdgeInsets.all(4),
                          child: SizedBox(
                            height: 30,
                            child: TextField(
                              controller: _keyAControllers[s],
                              style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  color: Colors.greenAccent),
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                isDense: true,
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9a-fA-F]')),
                                LengthLimitingTextInputFormatter(12),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(4),
                          child: SizedBox(
                            height: 30,
                            child: TextField(
                              controller: _keyBControllers[s],
                              style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  color: Colors.cyanAccent),
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                isDense: true,
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9a-fA-F]')),
                                LengthLimitingTextInputFormatter(12),
                              ],
                            ),
                          ),
                        ),
                      ]),
                  ],
                ),
              ],
            ),
          ),
        ),
        const VerticalDivider(width: 1),
        // 右侧：块数据编辑
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  const Text('📝 块数据编辑',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text('扇区 $_selectedSector',
                      style: TextStyle(fontSize: 13, color: Colors.grey[400])),
                ]),
              ),
              // 扇区选择器
              SizedBox(
                height: 36,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _card!.cardType.sectorCount,
                  itemBuilder: (context, index) {
                    final sel = index == _selectedSector;
                    return Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: ChoiceChip(
                        label: Text('$index',
                            style: const TextStyle(fontSize: 11)),
                        selected: sel,
                        onSelected: (_) =>
                            setState(() => _selectedSector = index),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                    );
                  },
                ),
              ),
              const Divider(height: 8),
              // 块编辑器
              Expanded(
                child: _buildBlockEditor(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBlockEditor() {
    if (_card == null) return const SizedBox();
    final ct = _card!.cardType;
    final sector = _selectedSector;
    final firstBlock = ct.sectorFirstBlock[sector];
    final blockCount = ct.blocksPerSector[sector];
    final trailerIdx = ct.trailerBlock(sector);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: blockCount,
      itemBuilder: (context, i) {
        final block = firstBlock + i;
        final isTrailer = block == trailerIdx;
        final isBlock0 = block == 0 && sector == 0;

        String label = '数据';
        Color labelColor = Colors.grey;
        if (isBlock0) {
          label = '制造商';
          labelColor = Colors.blue;
        } else if (isTrailer) {
          label = '尾块';
          labelColor = Colors.orange;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isTrailer
                ? Colors.orange.withValues(alpha: 0.05)
                : isBlock0
                    ? Colors.blue.withValues(alpha: 0.05)
                    : Colors.transparent,
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 55,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('B$block',
                        style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                    Text(label,
                        style: TextStyle(fontSize: 10, color: labelColor)),
                  ],
                ),
              ),
              Expanded(
                child: SizedBox(
                  height: 30,
                  child: TextField(
                    controller: _blockControllers[block],
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: isTrailer
                          ? Colors.orangeAccent
                          : isBlock0
                              ? Colors.lightBlueAccent
                              : null,
                    ),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      isDense: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F]')),
                      LengthLimitingTextInputFormatter(32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ======================================================================
  //  回写/清空 (CUID) 视图
  // ======================================================================
  Widget _buildWriteBackView() {
    if (_card == null) return const Center(child: Text('请先打开转储文件'));
    final appState = context.watch<AppState>();
    final isConnected = appState.isConnected;
    final progress = appState.writeProgress;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ---- 说明卡片 ----
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              const Row(children: [
                Icon(Icons.info_outline, color: Colors.blue),
                SizedBox(width: 8),
                Expanded(
                  child: Text('CUID 卡回写 & 清空',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ]),
              const SizedBox(height: 8),
              const Text(
                'CUID（Gen2）卡没有后门命令，必须使用已知密钥认证后逐块写入。\n'
                '• 整卡清空：使用卡片当前密钥认证，将数据块写为全 0\n'
                '• 整卡回写：使用目标卡密钥认证，将 Dump 数据逐块写入\n'
                '• 回写扇区：仅写入当前选中的单个扇区\n'
                '• Gen1A 后门恢复：使用 hf mf restore 后门命令整卡恢复（仅 Gen1A 卡）\n\n'
                '⚠️ CUID 卡写入块 0 会自动加 --force 参数',
                style: TextStyle(fontSize: 13),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 16),

        // ---- 连接状态 ----
        if (!isConnected)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(children: [
              Icon(Icons.warning, color: Colors.redAccent),
              SizedBox(width: 8),
              Text('请先连接 PM3 设备',
                  style: TextStyle(color: Colors.redAccent, fontSize: 14)),
            ]),
          ),
        if (!isConnected) const SizedBox(height: 16),

        // ---- 写入选项 ----
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('⚙️ 写入选项',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                Row(children: [
                  const Text('认证密钥类型：'),
                  const SizedBox(width: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'A', label: Text('Key A')),
                      ButtonSegment(value: 'B', label: Text('Key B')),
                    ],
                    selected: {_writeKeyType},
                    onSelectionChanged: (v) =>
                        setState(() => _writeKeyType = v.first),
                  ),
                ]),
                const SizedBox(height: 8),
                CheckboxListTile(
                  title: const Text('跳过块 0 (制造商块)',
                      style: TextStyle(fontSize: 13)),
                  subtitle: const Text('除非是魔术卡，否则块 0 无法写入',
                      style: TextStyle(fontSize: 11)),
                  value: _skipBlock0,
                  onChanged: (v) => setState(() => _skipBlock0 = v ?? true),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  title: const Text('写入尾块 (密钥+访问控制)',
                      style: TextStyle(fontSize: 13)),
                  subtitle: const Text('将 Dump 中的尾块数据写入目标卡',
                      style: TextStyle(fontSize: 11)),
                  value: _writeTrailers,
                  onChanged: (v) => setState(() => _writeTrailers = v ?? true),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ---- 密钥概览 (来自 Dump) ----
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🔑 Dump 密钥 (用于认证)',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 200,
                  child: SingleChildScrollView(
                    child: _buildCompactKeyTable(),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ---- 操作按钮 ----
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🚀 一键智能回写',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                const Text(
                  '按目标卡类型选择最佳回写路径（可用于 UID/CUID/FUID/Gen1A/Gen3/Gen4）。',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<_QuickWriteMode>(
                  initialValue: _quickWriteMode,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: '目标卡类型/模式',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: _QuickWriteMode.auto,
                        child:
                            Text('AUTO (默认)', style: TextStyle(fontSize: 13))),
                    DropdownMenuItem(
                        value: _QuickWriteMode.uid,
                        child: Text('UID 普通卡', style: TextStyle(fontSize: 13))),
                    DropdownMenuItem(
                        value: _QuickWriteMode.cuid,
                        child: Text('CUID / Gen2',
                            style: TextStyle(fontSize: 13))),
                    DropdownMenuItem(
                        value: _QuickWriteMode.fuid,
                        child: Text('FUID（一次性 UID 可改）',
                            style: TextStyle(fontSize: 13))),
                    DropdownMenuItem(
                        value: _QuickWriteMode.gen1a,
                        child:
                            Text('Gen1A 后门卡', style: TextStyle(fontSize: 13))),
                    DropdownMenuItem(
                        value: _QuickWriteMode.gen3,
                        child:
                            Text('Gen3 魔术卡', style: TextStyle(fontSize: 13))),
                    DropdownMenuItem(
                        value: _QuickWriteMode.gen4,
                        child:
                            Text('Gen4 GTU', style: TextStyle(fontSize: 13))),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _quickWriteMode = v);
                  },
                ),
                if (_quickWriteMode == _QuickWriteMode.gen4) ...[
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: _gen4Pwd,
                    decoration: const InputDecoration(
                      labelText: 'Gen4 密码（可选）',
                      hintText: '8 hex，例如 00000000',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                    onChanged: (v) => _gen4Pwd = v.trim(),
                    style:
                        const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  ),
                ],
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isConnected
                        ? () => _executeQuickWriteBack(appState)
                        : null,
                    icon: const Icon(Icons.flash_on, size: 18),
                    label:
                        const Text('⚡ 一键智能回写', style: TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        Row(children: [
          // CUID 逐块清空
          Expanded(
            child: Tooltip(
              message: '使用 Dump 中的密钥认证，将所有数据块写为全 0\n'
                  '尾块恢复为默认密钥和访问控制位\n'
                  '适用于 CUID / Gen2 卡（无后门）',
              child: ElevatedButton.icon(
                onPressed:
                    isConnected ? () => _showCuidClearDialog(appState) : null,
                icon: const Icon(Icons.delete_sweep),
                label: const Text('CUID 整卡清空'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // CUID 逐块回写
          Expanded(
            child: Tooltip(
              message: '使用目标卡密钥认证，将 Dump 数据逐块写入\n'
                  '适用于 CUID / Gen2 卡（无后门）\n'
                  '需要已知目标卡的密钥才能写入',
              child: ElevatedButton.icon(
                onPressed:
                    isConnected ? () => _showCuidWriteDialog(appState) : null,
                icon: const Icon(Icons.upload),
                label: const Text('CUID 整卡回写'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 12),

        // 单扇区回写 + Gen1A restore
        Row(children: [
          Expanded(
            child: Tooltip(
              message: '仅回写当前选中的扇区 $_selectedSector\n'
                  '使用 Dump 密钥认证，逐块写入该扇区\n'
                  '适合修改单个扇区后的局部更新',
              child: OutlinedButton.icon(
                onPressed:
                    isConnected ? () => _showSectorWriteDialog(appState) : null,
                icon: const Icon(Icons.edit_note),
                label: Text('回写扇区 $_selectedSector'),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // hf mf restore (Gen1A 后门回写)
          Expanded(
            child: Tooltip(
              message: '使用 PM3 的 hf mf restore 命令整卡恢复\n'
                  '仅适用于 Gen1A 后门卡，无需密钥\n'
                  '通过 0x40/0x43 后门指令直接写入所有块',
              child: OutlinedButton.icon(
                onPressed: isConnected
                    ? () {
                        final sz =
                            Pm3Commands.cardSizeFlag(_card!.cardType.label);
                        appState.sendCommand(Pm3Commands.hfMfRestore(sz));
                      }
                    : null,
                icon: const Icon(Icons.restore),
                label: const Text('Gen1A 后门恢复'),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 16),

        // ---- 进度显示 ----
        if (progress != null && progress.total > 0) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Text('📊 写入进度',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    const Spacer(),
                    if (progress.isRunning)
                      TextButton.icon(
                        onPressed: () => appState.cancelWriteSequence(),
                        icon: const Icon(Icons.cancel, size: 16),
                        label: const Text('取消'),
                        style: TextButton.styleFrom(
                            foregroundColor: Colors.redAccent),
                      ),
                  ]),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: progress.progress,
                    backgroundColor: Colors.grey.withValues(alpha: 0.2),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${progress.completed} / ${progress.total}  '
                    '(✅ ${progress.succeeded}  ❌ ${progress.failed})',
                    style:
                        const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  ),
                  Text(progress.currentStatus,
                      style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                  const SizedBox(height: 8),
                  // 逐块结果列表
                  SizedBox(
                    height: 200,
                    child: ListView.builder(
                      itemCount: progress.results.length,
                      itemBuilder: (context, index) {
                        final r = progress.results[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Row(children: [
                            Icon(
                              r.success ? Icons.check_circle : Icons.cancel,
                              size: 14,
                              color: r.success
                                  ? Colors.greenAccent
                                  : Colors.redAccent,
                            ),
                            const SizedBox(width: 6),
                            Text('块 ${r.block.toString().padLeft(3)}',
                                style: const TextStyle(
                                    fontFamily: 'monospace', fontSize: 12)),
                            const SizedBox(width: 8),
                            Text(r.message,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: r.success
                                        ? Colors.greenAccent
                                        : Colors.redAccent)),
                          ]),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        const SizedBox(height: 16),
        // ---- 格式转换 (折叠到这里) ----
        ExpansionTile(
          title: const Text('📦 格式转换 & 密钥提取',
              style: TextStyle(fontWeight: FontWeight.bold)),
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: _buildConverterView(),
            ),
          ],
        ),
      ]),
    );
  }

  Future<String> _prepareTempDumpBin(AppState appState) async {
    _applyEdits();
    final file = File(
      '${Directory.systemTemp.path}/pm3gui-quick-write-${DateTime.now().millisecondsSinceEpoch}.bin',
    );
    await file.writeAsBytes(exportToBin(_card!), flush: true);
    appState.setPreferredMfDumpFile(file.path);
    return file.path;
  }

  Future<void> _executeQuickWriteBack(AppState appState) async {
    if (_card == null) return;

    switch (_quickWriteMode) {
      case _QuickWriteMode.auto:
      case _QuickWriteMode.cuid:
        await _executeCuidWrite(appState);
        return;

      case _QuickWriteMode.uid:
        final old = _skipBlock0;
        setState(() => _skipBlock0 = true);
        try {
          await _executeCuidWrite(appState);
        } finally {
          if (mounted) setState(() => _skipBlock0 = old);
        }
        return;

      case _QuickWriteMode.fuid:
      case _QuickWriteMode.gen3:
        final uid =
            _card!.uid.toUpperCase().replaceAll(RegExp(r'[^0-9A-F]'), '');
        if (uid.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('未找到有效 UID，无法执行 UID 写入')));
          }
          return;
        }
        await appState.sendCommand(HfMfCmd.gen3uid(uid));
        final old = _skipBlock0;
        setState(() => _skipBlock0 = true);
        try {
          await _executeCuidWrite(appState);
        } finally {
          if (mounted) setState(() => _skipBlock0 = old);
        }
        return;

      case _QuickWriteMode.gen1a:
        final sz = Pm3Commands.cardSizeFlag(_card!.cardType.label);
        final dumpPath = await _prepareTempDumpBin(appState);
        await appState.sendCommand(
          Pm3Commands.hfMfRestore(
            sz,
            keyFile: appState.preferredMfKeyFile,
            dumpFile: dumpPath,
          ),
        );
        return;

      case _QuickWriteMode.gen4:
        final dumpPath = await _prepareTempDumpBin(appState);
        await appState.sendCommand(
          HfMfCmd.gload(
            dumpPath,
            pwd: _gen4Pwd.isNotEmpty ? _gen4Pwd : null,
          ),
        );
        return;
    }
  }

  // 简洁的密钥显示表
  Widget _buildCompactKeyTable() {
    if (_card == null) return const SizedBox();
    final keys = _card!.sectorKeys;
    return Table(
      border: TableBorder.all(color: Colors.grey.withValues(alpha: 0.3)),
      columnWidths: const {
        0: FixedColumnWidth(40),
        1: FlexColumnWidth(),
        2: FlexColumnWidth(),
      },
      children: [
        const TableRow(
            decoration: BoxDecoration(color: Color(0xFF2A2A3C)),
            children: [
              Padding(
                  padding: EdgeInsets.all(4),
                  child: Text('S',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 11))),
              Padding(
                  padding: EdgeInsets.all(4),
                  child: Text('Key A',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 11))),
              Padding(
                  padding: EdgeInsets.all(4),
                  child: Text('Key B',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 11))),
            ]),
        for (var i = 0; i < keys.length; i++)
          TableRow(children: [
            Padding(
                padding: const EdgeInsets.all(4),
                child: Text('$i',
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 11))),
            Padding(
                padding: const EdgeInsets.all(4),
                child: Text(keys[i].keyA.toUpperCase(),
                    style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: _isKnownDefault(keys[i].keyA)
                            ? Colors.orangeAccent
                            : Colors.greenAccent))),
            Padding(
                padding: const EdgeInsets.all(4),
                child: Text(keys[i].keyB.toUpperCase(),
                    style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: _isKnownDefault(keys[i].keyB)
                            ? Colors.orangeAccent
                            : Colors.cyanAccent))),
          ]),
      ],
    );
  }

  // ======================================================================
  //  CUID 清空对话框
  // ======================================================================
  void _showCuidClearDialog(AppState appState) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('CUID 逐块清空'),
        content: SizedBox(
          width: 400,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text(
              '将使用 Dump 中的密钥对目标卡进行认证，\n'
              '然后将每个数据块写为全 0。\n\n'
              '尾块将被重置为默认值:\n'
              'Key A = FFFFFFFFFFFF\n'
              '访问控制 = FF078069\n'
              'Key B = FFFFFFFFFFFF\n\n'
              '⚠️ 此操作不可逆！',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            Text(
              '将清空 ${_card!.cardType.blockCount} 块 '
              '(${_skipBlock0 ? "跳过块0" : "含块0"})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _executeCuidClear(appState);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('开始清空', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ======================================================================
  //  CUID 回写对话框
  // ======================================================================
  void _showCuidWriteDialog(AppState appState) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('CUID 逐块回写'),
        content: SizedBox(
          width: 400,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text(
              '将使用 Dump 中的密钥对目标卡进行认证，\n'
              '然后将 Dump 数据逐块写入目标卡。\n\n'
              '✅ 数据块: 写入 Dump 中的原始数据\n'
              '✅ 尾块: 写入 Dump 中的完整尾块数据\n'
              '    (包含 Key A + 访问控制 + Key B)\n\n'
              '💡 使用场景: CUID/普通卡的密钥已知,\n'
              '   需要覆盖写入新数据。',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            Text(
              '将写入 ${_card!.cardType.blockCount} 块 '
              '(${_skipBlock0 ? "跳过块0" : "含块0"}, '
              '${_writeTrailers ? "含尾块" : "跳过尾块"})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _executeCuidWrite(appState);
            },
            child: const Text('开始回写'),
          ),
        ],
      ),
    );
  }

  // ======================================================================
  //  单扇区回写对话框
  // ======================================================================
  void _showSectorWriteDialog(AppState appState) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('回写扇区 $_selectedSector'),
        content: Text(
          '将使用 Dump 中的密钥认证，\n'
          '回写扇区 $_selectedSector 的所有块到目标卡。\n\n'
          '${_writeTrailers ? "包含尾块" : "不含尾块"}  '
          '认证密钥: Key $_writeKeyType',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _executeSectorWrite(appState, _selectedSector);
            },
            child: const Text('开始回写'),
          ),
        ],
      ),
    );
  }

  // ======================================================================
  //  执行 CUID 逐块清空
  // ======================================================================
  Future<void> _executeCuidClear(AppState appState) async {
    if (_card == null) return;
    _applyEdits(); // 确保最新的密钥

    final commands = <(int, String)>[];
    final ct = _card!.cardType;
    final defaultTrailer = Pm3Commands.defaultTrailerData();

    for (var block = 0; block < ct.blockCount; block++) {
      if (_skipBlock0 && block == 0) continue;

      final sector = _card!.blockToSector(block);
      final key = _writeKeyType == 'A'
          ? _card!.sectorKeys[sector].keyA
          : _card!.sectorKeys[sector].keyB;

      if (_card!.isTrailerBlock(block)) {
        // 尾块写入默认值
        commands.add((
          block,
          Pm3Commands.hfMfCuidWriteBlock(
              block, _writeKeyType, key, defaultTrailer)
        ));
      } else {
        // 数据块写入全 0
        commands.add(
            (block, Pm3Commands.hfMfCuidClearBlock(block, _writeKeyType, key)));
      }
    }

    await appState.sendCommandSequence(commands);
  }

  // ======================================================================
  //  执行 CUID 逐块回写
  // ======================================================================
  Future<void> _executeCuidWrite(AppState appState) async {
    if (_card == null) return;
    _applyEdits(); // 确保最新数据

    final commands = <(int, String)>[];
    final ct = _card!.cardType;

    for (var block = 0; block < ct.blockCount; block++) {
      if (_skipBlock0 && block == 0) continue;

      final isTrailer = _card!.isTrailerBlock(block);
      if (isTrailer && !_writeTrailers) continue;

      final sector = _card!.blockToSector(block);
      final key = _writeKeyType == 'A'
          ? _card!.sectorKeys[sector].keyA
          : _card!.sectorKeys[sector].keyB;
      final data = _card!.blocks[block];

      commands.add((
        block,
        Pm3Commands.hfMfCuidWriteBlock(block, _writeKeyType, key, data)
      ));
    }

    await appState.sendCommandSequence(commands);
  }

  // ======================================================================
  //  执行单扇区回写
  // ======================================================================
  Future<void> _executeSectorWrite(AppState appState, int sector) async {
    if (_card == null) return;
    _applyEdits();

    final commands = <(int, String)>[];
    final ct = _card!.cardType;
    final firstBlock = ct.sectorFirstBlock[sector];
    final blockCount = ct.blocksPerSector[sector];

    for (var i = 0; i < blockCount; i++) {
      final block = firstBlock + i;
      if (_skipBlock0 && block == 0) continue;

      final isTrailer = _card!.isTrailerBlock(block);
      if (isTrailer && !_writeTrailers) continue;

      final key = _writeKeyType == 'A'
          ? _card!.sectorKeys[sector].keyA
          : _card!.sectorKeys[sector].keyB;
      final data = _card!.blocks[block];

      commands.add((
        block,
        Pm3Commands.hfMfCuidWriteBlock(block, _writeKeyType, key, data)
      ));
    }

    await appState.sendCommandSequence(commands);
  }
}
