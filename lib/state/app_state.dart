/// Global app state using Provider/ChangeNotifier.
library;

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pm3gui/models/mifare_card.dart';
import 'package:pm3gui/services/pm3_process.dart';
import 'package:pm3gui/services/file_collector.dart';

/// App shell page index mapping (must match HomePage sidebar order).
enum AppPage {
  connection,
  terminal,
  dumpViewer,
  dumpCompare,
  mifare,
  lf,
  settings,
}

/// Cross-page navigation intent with optional action and params.
class NavigationIntent {
  final AppPage page;
  final String action;
  final Map<String, String> params;
  final int timestamp;

  const NavigationIntent({
    required this.page,
    required this.action,
    this.params = const {},
    required this.timestamp,
  });
}

/// 逐块写入任务的进度状态
class WriteProgress {
  final int total;
  int completed;
  int succeeded;
  int failed;
  bool cancelled;
  String currentStatus;
  final List<WriteBlockResult> results;

  WriteProgress({
    required this.total,
    this.completed = 0,
    this.succeeded = 0,
    this.failed = 0,
    this.cancelled = false,
    this.currentStatus = '',
    List<WriteBlockResult>? results,
  }) : results = results ?? [];

  double get progress => total > 0 ? completed / total : 0;
  bool get isRunning => !cancelled && completed < total;
}

class WriteBlockResult {
  final int block;
  final bool success;
  final String message;
  const WriteBlockResult(
      {required this.block, required this.success, required this.message});
}

class AppState extends ChangeNotifier {
  final Pm3Process pm3 = Pm3Process();

  // Global page navigation state (HomePage sidebar index)
  int currentPageIndex = 0;

  // Cross-page generic intent bus.
  NavigationIntent? _pendingIntent;
  NavigationIntent? get pendingIntent => _pendingIntent;

  // Connection settings
  String pm3Path = '';
  String portName = '';
  List<String> availablePorts = [];

  // Current card data
  MifareCard currentCard = MifareCard();

  // Terminal history
  final List<String> terminalOutput = [];
  final List<String> commandHistory = [];
  int historyIndex = -1;

  // Theme
  bool isDarkMode = true;

  // 逐块写入进度
  WriteProgress? writeProgress;

  // PM3 文件自动收集
  List<CollectedFile> collectedFiles = [];
  List<CardGroup> cardGroups = [];
  bool isScanning = false;
  String? collectBaseDir; // 归类存放的根目录

  // Mifare dump/restore 可复用的默认文件
  String? preferredMfKeyFile;
  String? preferredMfDumpFile;

  // 硬件详细信息（从 hw version 解析）
  String hwModel = ''; // 硬件型号 (如 "PM3 RDV4")
  String hwFirmware = ''; // 固件版本
  String hwBootrom = ''; // Bootrom 版本
  String hwMcu = ''; // MCU 型号 (如 "AT91SAM7S512")
  String hwFlashSize = ''; // Flash 大小
  String hwSmartcard = ''; // 智能卡模块
  String hwFpga = ''; // FPGA 版本
  String hwUniqueId = ''; // 设备唯一 ID
  int hwFlashFree = 0; // Flash 空闲字节
  int hwFlashTotal = 0; // Flash 总字节
  bool hwInfoParsed = false; // 是否已解析硬件信息

  // Connection state passthrough
  Pm3State get connectionState => pm3.state;
  String get pm3Version => pm3.version;
  bool get isConnected => pm3.state == Pm3State.connected;
  String get lastError => pm3.lastError;

  AppState() {
    // Auto-detect PM3 path
    pm3Path = _detectPm3Path();
    // Forward pm3 output to terminal
    pm3.outputStream.listen((line) {
      terminalOutput.add(line);
      // Keep terminal buffer manageable
      if (terminalOutput.length > 5000) {
        terminalOutput.removeRange(0, 1000);
      }
      // Auto-scan for new files when PM3 saves something
      if (line.toLowerCase().contains('saved') ||
          line.toLowerCase().contains('saved to')) {
        // Delay slightly to let the file system flush
        Future.delayed(const Duration(seconds: 1), () => scanForFiles());
      }
      notifyListeners();
    });

    pm3.stateStream.listen((_) {
      notifyListeners();
    });
  }

  Future<bool> connect() async {
    if (portName.isEmpty) return false;
    // 重置硬件信息
    _resetHwInfo();
    final result = await pm3.connect(pm3Path, portName);
    // Auto scan files on connect
    if (result) {
      scanForFiles();
      // 自动查询硬件信息
      _queryHwVersion();
    }
    notifyListeners();
    return result;
  }

  Future<void> disconnect() async {
    await pm3.disconnect();
    _resetHwInfo();
    notifyListeners();
  }

  Future<void> sendCommand(String cmd) async {
    if (cmd.trim().isEmpty) return;
    commandHistory.add(cmd);
    historyIndex = commandHistory.length;
    await pm3.sendCommand(cmd);
  }

  /// 逐块发送命令序列（带进度追踪）
  /// [commands] — (块号, 命令) 的列表
  /// [delayBetween] — 每条命令之间的延迟
  Future<WriteProgress> sendCommandSequence(
    List<(int block, String cmd)> commands, {
    Duration delayBetween = const Duration(milliseconds: 800),
  }) async {
    final progress = WriteProgress(total: commands.length);
    writeProgress = progress;
    notifyListeners();

    for (final (block, cmd) in commands) {
      if (progress.cancelled) break;
      if (!isConnected) {
        progress.currentStatus = '连接断开，操作中止';
        progress.cancelled = true;
        notifyListeners();
        break;
      }

      progress.currentStatus = '正在写入 块 $block ...';
      notifyListeners();

      await sendCommand(cmd);
      // 等待命令返回
      await Future.delayed(delayBetween);

      // 检查最后一行输出判断成功/失败
      final lastLines = terminalOutput.length > 3
          ? terminalOutput.sublist(terminalOutput.length - 3)
          : terminalOutput;
      final fail = lastLines
          .any((l) => l.contains('( fail )') || l.contains('Auth error'));

      if (fail) {
        progress.failed++;
        progress.results.add(WriteBlockResult(
            block: block, success: false, message: '认证失败或写入失败'));
      } else {
        progress.succeeded++;
        progress.results.add(
            WriteBlockResult(block: block, success: true, message: '写入成功'));
      }
      progress.completed++;
      notifyListeners();
    }

    if (!progress.cancelled) {
      progress.currentStatus =
          '完成: ${progress.succeeded} 成功, ${progress.failed} 失败';
    }
    notifyListeners();
    return progress;
  }

  /// 取消当前写入任务
  void cancelWriteSequence() {
    if (writeProgress != null && writeProgress!.isRunning) {
      writeProgress!.cancelled = true;
      writeProgress!.currentStatus = '已取消';
      notifyListeners();
    }
  }

  void setPort(String port) {
    portName = port;
    notifyListeners();
  }

  void setPm3Path(String path) {
    pm3Path = path;
    notifyListeners();
  }

  void toggleTheme() {
    isDarkMode = !isDarkMode;
    notifyListeners();
  }

  void clearTerminal() {
    terminalOutput.clear();
    notifyListeners();
  }

  void setCurrentPage(int index) {
    if (index == currentPageIndex) return;
    currentPageIndex = index;
    notifyListeners();
  }

  void navigateTo(AppPage page) {
    setCurrentPage(page.index);
  }

  /// Send a cross-page intent (for page switch + in-page action/params).
  void requestNavigationIntent(
    AppPage page, {
    required String action,
    Map<String, String> params = const {},
  }) {
    currentPageIndex = page.index;
    _pendingIntent = NavigationIntent(
      page: page,
      action: action,
      params: params,
      timestamp: DateTime.now().microsecondsSinceEpoch,
    );
    notifyListeners();
  }

  /// Consume pending intent for [page]. Returns null if not targeting [page].
  NavigationIntent? takePendingIntentFor(AppPage page) {
    final intent = _pendingIntent;
    if (intent == null || intent.page != page) return null;
    _pendingIntent = null;
    return intent;
  }

  /// Request switching to Dump Viewer page and opening [path].
  void requestOpenDumpInViewer(String path) {
    final normalized = path.trim();
    if (normalized.isEmpty) return;

    preferredMfDumpFile = normalized;
    requestNavigationIntent(
      AppPage.dumpViewer,
      action: 'open_file',
      params: {'path': normalized},
    );
  }

  void updateCard(MifareCard card) {
    currentCard = card;
    notifyListeners();
  }

  void setPreferredMfKeyFile(String? path) {
    preferredMfKeyFile = (path != null && path.trim().isNotEmpty) ? path : null;
    notifyListeners();
  }

  void setPreferredMfDumpFile(String? path) {
    preferredMfDumpFile =
        (path != null && path.trim().isNotEmpty) ? path : null;
    notifyListeners();
  }

  void setCollectBaseDir(String? baseDir) {
    collectBaseDir =
        (baseDir != null && baseDir.trim().isNotEmpty) ? baseDir : null;
    notifyListeners();
  }

  // ──────────────────────────────────────────────────────────
  //  PM3 文件自动扫描 & 归类
  // ──────────────────────────────────────────────────────────

  /// 扫描 PM3 工作目录，收集 dump / key 文件
  Future<void> scanForFiles() async {
    if (isScanning) return;
    isScanning = true;
    notifyListeners();

    try {
      final dirs = FileCollector.defaultScanDirs(pm3Path);
      final files = await FileCollector.scan(dirs);

      // 同时递归扫描归类目标目录（存放已整理文件），避免归类后文件"消失"
      List<CollectedFile> organizedFiles = [];
      if (collectBaseDir != null) {
        organizedFiles = await FileCollector.scan(
          [collectBaseDir!],
          recursive: true,
        );
      }

      // 合并，去除重复路径
      final seen = <String>{};
      collectedFiles =
          [...files, ...organizedFiles].where((f) => seen.add(f.path)).toList();
      cardGroups = FileCollector.groupByCard(collectedFiles);
    } catch (e) {
      terminalOutput.add('[文件扫描错误] $e');
    }

    isScanning = false;
    notifyListeners();
  }

  /// 将已收集的文件整理归类到指定目录
  Future<int> organizeCollectedFiles(String baseDir) async {
    collectBaseDir = baseDir;
    final count = await FileCollector.organizeFiles(collectedFiles, baseDir);
    // 重新扫描以更新路径
    await scanForFiles();
    return count;
  }

  // ──────────────────────────────────────────────────────────
  //  硬件信息解析
  // ──────────────────────────────────────────────────────────

  void _resetHwInfo() {
    hwModel = '';
    hwFirmware = '';
    hwBootrom = '';
    hwMcu = '';
    hwFlashSize = '';
    hwSmartcard = '';
    hwFpga = '';
    hwUniqueId = '';
    hwFlashFree = 0;
    hwFlashTotal = 0;
    hwInfoParsed = false;
  }

  /// 连接后自动查询硬件版本，监听输出解析
  void _queryHwVersion() {
    final buffer = StringBuffer();
    StreamSubscription<String>? sub;

    sub = pm3.outputStream.listen((line) {
      buffer.writeln(line);
    });

    pm3.sendCommand('hw version');

    // 等待 3 秒后解析缓冲区
    Future.delayed(const Duration(seconds: 3), () {
      sub?.cancel();
      _parseHwVersion(buffer.toString());
      notifyListeners();
    });
  }

  /// 解析 `hw version` 的输出提取硬件信息
  void _parseHwVersion(String output) {
    hwInfoParsed = true;

    // 设备型号: [#]  [ Proxmark3 GENERIC ] / [#]  [ RDV4 ]
    final modelMatch = RegExp(
      r'\[\s*(Proxmark3[^\]]*|RDV[^\]]*|PM3[^\]]*)\s*\]',
      caseSensitive: false,
    ).firstMatch(output);
    if (modelMatch != null) {
      hwModel = modelMatch.group(1)!.trim();
    }

    // 固件版本: [=]  compiled with.............. GCC xxx
    //           [=] firmware................... Iceman/master/v4.xxxxx-xxx-xxxx 2024-xx-xx
    final fwMatch = RegExp(
      r'firmware[.\s]+([\w/\-. ]+)',
      caseSensitive: false,
    ).firstMatch(output);
    if (fwMatch != null) {
      hwFirmware = fwMatch.group(1)!.trim();
    }

    // Bootrom: [=] bootrom................... Iceman/master/...
    final bootMatch = RegExp(
      r'bootrom[.\s]+([\w/\-. ]+)',
      caseSensitive: false,
    ).firstMatch(output);
    if (bootMatch != null) {
      hwBootrom = bootMatch.group(1)!.trim();
    }

    // MCU: [=] uC: AT91SAM7S512 Rev ...
    final mcuMatch = RegExp(
      r'uC:\s*(AT\w+)',
      caseSensitive: false,
    ).firstMatch(output);
    if (mcuMatch != null) {
      hwMcu = mcuMatch.group(1)!.trim();
    }

    // Flash: [=]  256K (0x40000) or similar
    final flashMatch = RegExp(
      r'Embedded\s+Flash\s*[:.]?\s*(\d+\w?)',
      caseSensitive: false,
    ).firstMatch(output);
    if (flashMatch != null) {
      hwFlashSize = flashMatch.group(1)!.trim();
    }

    // FPGA: [=] FPGA fingerprint.......... xxx
    final fpgaMatch = RegExp(
      r'FPGA\s+fingerprint[.\s]+([\w.\- ]+)',
      caseSensitive: false,
    ).firstMatch(output);
    if (fpgaMatch != null) {
      hwFpga = fpgaMatch.group(1)!.trim();
    }

    // Unique ID: [=] PRNG............. xxx
    final uidMatch = RegExp(
      r'Unique\s+ID[.\s:]+([0-9A-Fa-f\s]+)',
      caseSensitive: false,
    ).firstMatch(output);
    if (uidMatch != null) {
      hwUniqueId = uidMatch.group(1)!.replaceAll(RegExp(r'\s+'), ' ').trim();
    }

    // Smart card module
    if (output.toLowerCase().contains('smartcard module (sim)')) {
      hwSmartcard = '已安装';
    }

    // Flash memory usage: [=] available flash mem for firmware and target ...  xxx / xxx
    final memMatch = RegExp(
      r'(\d+)\s*/\s*(\d+)\s*bytes',
      caseSensitive: false,
    ).firstMatch(output);
    if (memMatch != null) {
      hwFlashFree = int.tryParse(memMatch.group(1)!) ?? 0;
      hwFlashTotal = int.tryParse(memMatch.group(2)!) ?? 0;
    }
  }

  /// 手动刷新硬件信息
  Future<void> refreshHwInfo() async {
    if (!isConnected) return;
    _queryHwVersion();
  }

  @override
  void dispose() {
    pm3.dispose();
    super.dispose();
  }

  /// Auto-detect PM3 executable path.
  static String _detectPm3Path() {
    final candidates = [
      '/root/dev/proxmark3/pm3',
      '/usr/local/bin/proxmark3',
      '/usr/bin/proxmark3',
    ];
    for (final c in candidates) {
      if (File(c).existsSync()) return c;
    }
    // Try `which proxmark3`
    try {
      final r = Process.runSync('which', ['proxmark3']);
      if (r.exitCode == 0) {
        final p = (r.stdout as String).trim();
        if (p.isNotEmpty) return p;
      }
    } catch (_) {}
    // Fallback — user must configure manually
    return './pm3';
  }
}
