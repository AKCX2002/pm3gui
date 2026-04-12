/// 终端状态管理
library;

import 'package:flutter/foundation.dart';
import 'package:pm3gui/parsers/output_parser.dart';

class TerminalState extends ChangeNotifier {
  final List<String> terminalOutput = [];
  final List<String> terminalOutputStripped = [];
  final List<String> commandHistory = [];
  int historyIndex = -1;
  int outputRevision = 0;

  void addOutput(String line) {
    terminalOutput.add(line);
    // Keep original behavior: only strip ANSI color codes for display.
    terminalOutputStripped.add(stripAnsi(line));

    // 保持终端缓冲区大小合理
    if (terminalOutput.length > 5000) {
      terminalOutput.removeRange(0, 1000);
      terminalOutputStripped.removeRange(0, 1000);
    }

    outputRevision++;

    notifyListeners();
  }

  void addCommand(String cmd) {
    if (cmd.trim().isEmpty) return;
    commandHistory.add(cmd);
    historyIndex = commandHistory.length;
    notifyListeners();
  }

  void clearTerminal() {
    terminalOutput.clear();
    terminalOutputStripped.clear();
    outputRevision++;
    notifyListeners();
  }

  void setHistoryIndex(int index) {
    historyIndex = index;
    notifyListeners();
  }
}
