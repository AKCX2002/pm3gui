/// LF FDX-B animal tag operations page.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pm3gui/state/app_state.dart';
import 'package:pm3gui/services/pm3_commands.dart';
import 'package:pm3gui/ui/components/components.dart';

class LfFdxbPage extends StatefulWidget {
  const LfFdxbPage({super.key});

  @override
  State<LfFdxbPage> createState() => _LfFdxbPageState();
}

class _LfFdxbPageState extends State<LfFdxbPage> {
  String _rawData = '';
  String _lastCmd = '';
  String _result = '';
  bool _isLoading = false;
  StreamSubscription<String>? _sub;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _execute(String cmd) {
    if (!executeIfConnected(context, cmd)) return;
    setState(() {
      _lastCmd = cmd;
      _isLoading = true;
      _result = '';
    });
    final buf = StringBuffer();
    _sub?.cancel();
    _sub = context.read<AppState>().pm3.outputStream.listen((line) {
      if (!line.startsWith('[pm3]')) {
        buf.writeln(line);
        if (mounted) setState(() => _result = buf.toString());
      }
    });
    context.read<AppState>().sendCommand(cmd);
    Future.delayed(const Duration(seconds: 5), () {
      _sub?.cancel();
      if (mounted) setState(() => _isLoading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SplitPageLayout(
      side: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ActionCard(
              title: '读取',
              subtitle: '读取 FDX-B 标签',
              icon: Icons.pets,
              onTap: () => _execute(LfFdxbCmd.reader())),
          const SizedBox(height: 8),
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('克隆',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      HexInputField(
                          label: 'RAW 数据',
                          onChanged: (v) => setState(() => _rawData = v)),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                          onPressed: _rawData.isNotEmpty
                              ? () => _execute(LfFdxbCmd.clone(_rawData))
                              : null,
                          icon: const Icon(Icons.copy, size: 18),
                          label: const Text('克隆到 T55xx')),
                    ],
                  ))),
        ],
      ),
      main: ResultDisplay(
          command: _lastCmd,
          result: _result,
          isLoading: _isLoading,
          onClear: () => setState(() {
                _result = '';
                _lastCmd = '';
              })),
    );
  }
}
