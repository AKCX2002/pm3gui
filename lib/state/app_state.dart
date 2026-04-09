import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:pm3gui/models/mifare_card.dart';
import 'package:pm3gui/services/file_collector.dart';
import 'package:pm3gui/services/pm3_process.dart';
import 'package:pm3gui/state/connection_state.dart';
import 'package:pm3gui/state/terminal_state.dart';
import 'package:pm3gui/state/file_state.dart';
import 'package:pm3gui/state/hardware_state.dart';

enum AppPage {
  connection,
  terminal,
  dumpViewer,
  dumpCompare,
  mifare,
  mifareUltralight,
  desfire,
  iclass,
  iso15693,
  iso14443b,
  felica,
  legic,
  emv,
  seos,
  fido,
  hfSniff,
  lf,
  lfHid,
  lfHitag,
  lfAwid,
  lfIndala,
  lfIo,
  lfPyramid,
  lfKeri,
  lfFdxb,
  data,
  trace,
  nfc,
  script,
  settings,
}

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
  const WriteBlockResult({
    required this.block,
    required this.success,
    required this.message,
  });
}

class AppState extends ChangeNotifier {
  late final ConnectionState connectionState;
  late final TerminalState terminalState;
  late final FileState fileState;
  late final HardwareState hardwareState;

  int currentPageIndex = 0;
  NavigationIntent? _pendingIntent;
  NavigationIntent? get pendingIntent => _pendingIntent;

  MifareCard currentCard = MifareCard();

  WriteProgress? writeProgress;

  String? preferredMfKeyFile;
  String? preferredMfDumpFile;

  bool get isConnected => connectionState.isConnected;
  String get lastError => connectionState.lastError;
  String get pm3Version => connectionState.pm3Version;

  String get pm3Path => connectionState.pm3Path;
  set pm3Path(String value) => connectionState.setPm3Path(value);

  String get portName => connectionState.portName;
  set portName(String value) => connectionState.setPort(value);

  List<String> get availablePorts => connectionState.availablePorts;
  set availablePorts(List<String> value) =>
      connectionState.setAvailablePorts(value);

  List<String> get terminalOutput => terminalState.terminalOutput;
  List<String> get terminalOutputStripped =>
      terminalState.terminalOutputStripped;
  int get outputRevision => terminalState.outputRevision;
  List<String> get commandHistory => terminalState.commandHistory;
  int get historyIndex => terminalState.historyIndex;
  set historyIndex(int value) => terminalState.setHistoryIndex(value);

  List<CollectedFile> get collectedFiles => fileState.collectedFiles;
  List<CardGroup> get cardGroups => fileState.cardGroups;
  bool get isScanning => fileState.isScanning;
  String? get collectBaseDir => fileState.collectBaseDir;

  String get hwModel => hardwareState.hwModel;
  String get hwFirmware => hardwareState.hwFirmware;
  String get hwBootrom => hardwareState.hwBootrom;
  String get hwMcu => hardwareState.hwMcu;
  String get hwFlashSize => hardwareState.hwFlashSize;
  String get hwSmartcard => hardwareState.hwSmartcard;
  String get hwFpga => hardwareState.hwFpga;
  String get hwUniqueId => hardwareState.hwUniqueId;
  int get hwFlashFree => hardwareState.hwFlashFree;
  int get hwFlashTotal => hardwareState.hwFlashTotal;
  bool get hwInfoParsed => hardwareState.hwInfoParsed;

  Pm3Process get pm3 => connectionState.pm3;

  AppState() {
    connectionState = ConnectionState();
    terminalState = TerminalState();
    fileState = FileState();
    hardwareState = HardwareState();

    connectionState.pm3.outputStream.listen((line) {
      terminalState.addOutput(line);

      if (line.toLowerCase().contains('saved') ||
          line.toLowerCase().contains('saved to')) {
        Future.delayed(const Duration(seconds: 1), () => scanForFiles());
      }
    });

    connectionState.pm3.stateStream.listen((state) {
      if (state == Pm3State.connected) {
        scanForFiles();
        _queryHwVersion();
      } else if (state == Pm3State.disconnected) {
        hardwareState.resetHwInfo();
      }
      notifyListeners();
    });
  }

  Future<bool> connect() async {
    hardwareState.resetHwInfo();
    final result = await connectionState.connect();
    notifyListeners();
    return result;
  }

  Future<void> disconnect() async {
    await connectionState.disconnect();
    hardwareState.resetHwInfo();
    notifyListeners();
  }

  Future<void> sendCommand(String cmd) async {
    terminalState.addCommand(cmd);
    await connectionState.sendCommand(cmd);
  }

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
      await Future.delayed(delayBetween);

      final lastLines = terminalState.terminalOutput.length > 3
          ? terminalState.terminalOutput
              .sublist(terminalState.terminalOutput.length - 3)
          : terminalState.terminalOutput;
      final fail = lastLines
          .any((l) => l.contains('( fail )') || l.contains('Auth error'));

      if (fail) {
        progress.failed++;
        progress.results.add(WriteBlockResult(
          block: block,
          success: false,
          message: '认证失败或写入失败',
        ));
      } else {
        progress.succeeded++;
        progress.results.add(WriteBlockResult(
          block: block,
          success: true,
          message: '写入成功',
        ));
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

  void cancelWriteSequence() {
    if (writeProgress != null && writeProgress!.isRunning) {
      writeProgress!.cancelled = true;
      writeProgress!.currentStatus = '已取消';
      notifyListeners();
    }
  }

  void setPort(String port) {
    connectionState.setPort(port);
    notifyListeners();
  }

  void setPm3Path(String path) {
    connectionState.setPm3Path(path);
    notifyListeners();
  }

  void clearTerminal() {
    terminalState.clearTerminal();
  }

  void setCurrentPage(int index) {
    if (index == currentPageIndex) return;
    currentPageIndex = index;
    notifyListeners();
  }

  void navigateTo(AppPage page) {
    setCurrentPage(page.index);
  }

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

  NavigationIntent? takePendingIntentFor(AppPage page) {
    final intent = _pendingIntent;
    if (intent == null || intent.page != page) return null;
    _pendingIntent = null;
    return intent;
  }

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
    fileState.setCollectBaseDir(baseDir);
    notifyListeners();
  }

  Future<void> scanForFiles() async {
    await fileState.scanForFiles(connectionState.pm3Path);
    notifyListeners();
  }

  Future<int> organizeCollectedFiles(String baseDir) async {
    final count = await fileState.organizeCollectedFiles(baseDir);
    notifyListeners();
    return count;
  }

  void _queryHwVersion() {
    final buffer = StringBuffer();
    StreamSubscription<String>? sub;

    sub = connectionState.pm3.outputStream.listen((line) {
      buffer.writeln(line);
    });

    connectionState.pm3.sendCommand('hw version');

    Future.delayed(const Duration(seconds: 3), () {
      sub?.cancel();
      hardwareState.parseHwVersion(buffer.toString());
      notifyListeners();
    });
  }

  Future<void> refreshHwInfo() async {
    if (!isConnected) return;
    _queryHwVersion();
  }

  @override
  void dispose() {
    connectionState.dispose();
    super.dispose();
  }
}
