/// Terminal page — interactive pm3 console.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pm3gui/state/app_state.dart';
import 'package:pm3gui/parsers/output_parser.dart';

class TerminalPage extends StatefulWidget {
  const TerminalPage({super.key});

  @override
  State<TerminalPage> createState() => _TerminalPageState();
}

class _TerminalPageState extends State<TerminalPage> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submitCommand() {
    final cmd = _inputController.text.trim();
    if (cmd.isEmpty) return;
    context.read<AppState>().sendCommand(cmd);
    _inputController.clear();
    _focusNode.requestFocus();

    // Scroll to bottom after a short delay for output to arrive
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    // Auto-scroll when new output arrives
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Column(
      children: [
        // Quick command bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _quickBtn('高频搜索', 'hf search'),
                _quickBtn('低频搜索', 'lf search'),
                _quickBtn('14A 信息', 'hf 14a info'),
                _quickBtn('硬件版本', 'hw version'),
                _quickBtn('天线调谐', 'hw tune'),
                _quickBtn('低频读取', 'lf read'),
                _quickBtn('自动破解', 'hf mf autopwn'),
              ],
            ),
          ),
        ),
        const Divider(height: 1),

        // Terminal output
        Expanded(
          child: Container(
            color: const Color(0xFF0D0D1A),
            child: SelectableRegion(
              selectionControls: materialTextSelectionControls,
              focusNode: FocusNode(),
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(8),
                itemCount: appState.terminalOutput.length,
                itemBuilder: (context, index) {
                  final line = appState.terminalOutput[index];
                  return Text(
                    stripAnsi(line),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      height: 1.4,
                      color: _lineColor(line),
                    ),
                  );
                },
              ),
            ),
          ),
        ),

        // Input bar
        Container(
          color: const Color(0xFF1A1A2E),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              Text(
                'pm3 › ',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                  color: appState.isConnected
                      ? Colors.greenAccent
                      : Colors.grey,
                ),
              ),
              Expanded(
                child: KeyboardListener(
                  focusNode: FocusNode(),
                  onKeyEvent: (event) {
                    if (event is KeyDownEvent) {
                      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                        _navigateHistory(-1);
                      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                        _navigateHistory(1);
                      }
                    }
                  },
                  child: TextField(
                    controller: _inputController,
                    focusNode: _focusNode,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: '输入命令...',
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onSubmitted: (_) => _submitCommand(),
                    textInputAction: TextInputAction.send,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send, size: 20),
                onPressed: _submitCommand,
                tooltip: '发送',
              ),
              IconButton(
                icon: const Icon(Icons.delete_sweep, size: 20),
                onPressed: () {
                  context.read<AppState>().clearTerminal();
                },
                tooltip: '清屏',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _quickBtn(String label, String cmd) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        onPressed: () {
          context.read<AppState>().sendCommand(cmd);
        },
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Color _lineColor(String line) {
    if (line.startsWith('[pm3]')) return Colors.cyanAccent;
    if (line.startsWith('[ERR]') || line.contains('[-]')) return Colors.redAccent;
    if (line.contains('[+]')) return Colors.greenAccent;
    if (line.contains('[=]')) return Colors.white70;
    if (line.contains('[#]')) return Colors.yellow;
    return Colors.white54;
  }

  void _navigateHistory(int direction) {
    final appState = context.read<AppState>();
    final history = appState.commandHistory;
    if (history.isEmpty) return;

    appState.historyIndex += direction;
    if (appState.historyIndex < 0) appState.historyIndex = 0;
    if (appState.historyIndex >= history.length) {
      appState.historyIndex = history.length;
      _inputController.clear();
      return;
    }

    _inputController.text = history[appState.historyIndex];
    _inputController.selection = TextSelection.fromPosition(
      TextPosition(offset: _inputController.text.length),
    );
  }
}
