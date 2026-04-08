/// Global app state using Provider/ChangeNotifier.
library;

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pm3gui/models/mifare_card.dart';
import 'package:pm3gui/services/pm3_process.dart';

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
      notifyListeners();
    });

    pm3.stateStream.listen((_) {
      notifyListeners();
    });
  }

  Future<bool> connect() async {
    if (portName.isEmpty) return false;
    final result = await pm3.connect(pm3Path, portName);
    notifyListeners();
    return result;
  }

  Future<void> disconnect() async {
    await pm3.disconnect();
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

  void updateCard(MifareCard card) {
    currentCard = card;
    notifyListeners();
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
