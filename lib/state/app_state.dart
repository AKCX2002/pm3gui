/// Global app state using Provider/ChangeNotifier.
library;

import 'package:flutter/foundation.dart';
import 'package:pm3gui/models/mifare_card.dart';
import 'package:pm3gui/services/pm3_process.dart';

class AppState extends ChangeNotifier {
  final Pm3Process pm3 = Pm3Process();

  // Connection settings
  String pm3Path = './pm3';
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

  // Connection state passthrough
  Pm3State get connectionState => pm3.state;
  String get pm3Version => pm3.version;
  bool get isConnected => pm3.state == Pm3State.connected;

  AppState() {
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
}
