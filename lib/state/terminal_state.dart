/// 终端状态管理
library;

import 'package:flutter/foundation.dart';

class TerminalState extends ChangeNotifier {
  final List<String> terminalOutput = [];
  final List<String> commandHistory = [];
  int historyIndex = -1;

  void addOutput(String line) {
    terminalOutput.add(line);

    // 保持终端缓冲区大小合理
    if (terminalOutput.length > 5000) {
      terminalOutput.removeRange(0, 1000);
    }

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
    notifyListeners();
  }

  void setHistoryIndex(int index) {
    historyIndex = index;
    notifyListeners();
  }
}
