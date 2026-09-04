import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:pm3gui/models/mifare_card.dart';
import 'package:pm3gui/services/file_collector.dart';
import 'package:pm3gui/core/pm3/pm3_connection.dart';
import 'package:pm3gui/services/pm3_session_recorder.dart';
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
  final Pm3SessionRecorder _sessionRecorder;
  late final StreamSubscription<String> _outputSubscription;
  late final StreamSubscription _commandSubscription;
  late final StreamSubscription<Pm3ConnectionState> _stateSubscription;
  StreamSubscription<String>? _hwVersionOutputSubscription;
  Timer? _hwVersionTimer;
  Future<void> _sessionClose = Future.value();
  Future<void>? _shutdownFuture;
  bool _disconnectInProgress = false;
  bool _resourcesReleased = false;
  bool _notifierDisposed = false;
  String? _sessionLogError;

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
  String? get sessionLogError => _sessionLogError;

  String get pm3Path => connectionState.pm3Path;
  set pm3Path(String value) => connectionState.setPm3Path(value);

  String get portName => connectionState.portName;
  set portName(String value) => connectionState.setPort(value);

  List<String> get pm3Arguments => connectionState.pm3Arguments;
  String? get pm3WorkingDirectory => connectionState.pm3WorkingDirectory;

  List<String> get availablePorts => connectionState.availablePorts;
  set availablePorts(List<String> value) =>
      connectionState.setAvailablePorts(value);

  List<String> get terminalOutput => terminalState.terminalOutput;
  List<String> get terminalOutputStripped =>
      terminalState.terminalOutputStripped;
  List<String> get terminalOutputRaw => terminalState.terminalOutputRaw;
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

  Stream<String> get pm3Output => connectionState.controller.outputLines;

  AppState({
    ConnectionState? connectionState,
    Pm3SessionRecorder? sessionRecorder,
  }) : _sessionRecorder = sessionRecorder ?? Pm3SessionRecorder() {
    this.connectionState = connectionState ?? ConnectionState();
    terminalState = TerminalState();
    fileState = FileState();
    hardwareState = HardwareState();

    this.connectionState.addListener(_onConnectionChanged);
    unawaited(initialize());

    // Propagate terminal state changes so widgets depending on AppState
    // (via context.select on outputRevision / terminalOutput) will rebuild
    // in real-time when TerminalState notifies.
    terminalState.addListener(_onTerminalChanged);
    _outputSubscription =
        this.connectionState.controller.outputLines.listen((line) {
      terminalState.addOutput(line);
      _recordSession(_sessionRecorder.recordOutput(line));

      if (line.toLowerCase().contains('saved') ||
          line.toLowerCase().contains('saved to')) {
        Future.delayed(const Duration(seconds: 1), () => scanForFiles());
      }
    });

    _commandSubscription =
        this.connectionState.controller.commands.listen((command) {
      _recordSession(_sessionRecorder.recordCommand(command.executable));
    });

    _stateSubscription =
        this.connectionState.controller.stateChanges.listen((state) {
      if (state == Pm3ConnectionState.connected) {
        _recordSession(_sessionRecorder.start(
          devicePort: this.connectionState.portName,
          executable: this.connectionState.pm3Path,
        ));
        scanForFiles();
        _queryHwVersion();
      } else if (state == Pm3ConnectionState.disconnected) {
        if (!_disconnectInProgress) {
          _sessionClose = _recordSession(_sessionRecorder.close());
        }
        hardwareState.resetHwInfo();
      }
      _notifyListenersIfActive();
    });
  }

  void _onTerminalChanged() {
    // Forward terminal state changes to AppState listeners.
    _notifyListenersIfActive();
  }

  void _onConnectionChanged() {
    _notifyListenersIfActive();
  }

  Future<void> initialize() => connectionState.initialize();

  Future<bool> connect() async {
    hardwareState.resetHwInfo();
    final result = await connectionState.connect();
    notifyListeners();
    return result;
  }

  Future<void> disconnect() async {
    await _disconnectAndCloseSession();
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

  Future<void> setPort(String port) {
    return connectionState.setPort(port);
  }

  Future<void> setPm3Path(String path) {
    return connectionState.setPm3Path(path);
  }

  Future<void> setPm3Arguments(List<String> arguments) {
    return connectionState.setPm3Arguments(arguments);
  }

  Future<void> setPm3WorkingDirectory(String? workingDirectory) {
    return connectionState.setPm3WorkingDirectory(workingDirectory);
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
    unawaited(_hwVersionOutputSubscription?.cancel() ?? Future.value());
    _hwVersionTimer?.cancel();
    final subscription = connectionState.controller.outputLines.listen((line) {
      buffer.writeln(line);
    });
    _hwVersionOutputSubscription = subscription;

    connectionState.controller.send('hw version');

    _hwVersionTimer = Timer(const Duration(seconds: 3), () {
      unawaited(subscription.cancel());
      if (identical(_hwVersionOutputSubscription, subscription)) {
        _hwVersionOutputSubscription = null;
      }
      hardwareState.parseHwVersion(buffer.toString());
      _notifyListenersIfActive();
    });
  }

  /// Completes only after the PM3 backend, Session queue and subscriptions
  /// have been released in that order.
  Future<void> shutdown() => _shutdownFuture ??= _shutdown();

  Future<void> _shutdown() async {
    try {
      await _disconnectAndCloseSession();
    } finally {
      await _releaseResources();
    }
  }

  Future<void> _disconnectAndCloseSession() async {
    _disconnectInProgress = true;
    try {
      await connectionState.disconnect();
    } finally {
      _disconnectInProgress = false;
      _sessionClose = _recordSession(_sessionRecorder.close());
      await _sessionClose;
    }
  }

  Future<void> _releaseResources() async {
    if (_resourcesReleased) return;
    _resourcesReleased = true;
    _hwVersionTimer?.cancel();
    _hwVersionTimer = null;
    final hwVersionOutputSubscription = _hwVersionOutputSubscription;
    _hwVersionOutputSubscription = null;
    try {
      terminalState.removeListener(_onTerminalChanged);
    } catch (_) {}
    connectionState.removeListener(_onConnectionChanged);
    await Future.wait([
      _outputSubscription.cancel(),
      _commandSubscription.cancel(),
      _stateSubscription.cancel(),
      if (hwVersionOutputSubscription != null)
        hwVersionOutputSubscription.cancel(),
    ]);
    connectionState.dispose();
    _disposeNotifier();
  }

  Future<void> _recordSession(Future<void> operation) {
    return operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace _) {
        _sessionLogError = error.toString();
        _notifyListenersIfActive();
      },
    );
  }

  void _notifyListenersIfActive() {
    if (!_notifierDisposed) notifyListeners();
  }

  void _disposeNotifier() {
    if (_notifierDisposed) return;
    _notifierDisposed = true;
    super.dispose();
  }

  Future<void> refreshHwInfo() async {
    if (!isConnected) return;
    _queryHwVersion();
  }

  @override
  void dispose() {
    if (_notifierDisposed) return;
    _notifierDisposed = true;
    super.dispose();
    unawaited(shutdown());
  }
}
