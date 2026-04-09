/// LF Indala operations page.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pm3gui/state/app_state.dart';
import 'package:pm3gui/services/pm3_commands.dart';
import 'package:pm3gui/ui/components/components.dart';

class LfIndalaPage extends StatefulWidget {
  const LfIndalaPage({super.key});

  @override
  State<LfIndalaPage> createState() => _LfIndalaPageState();
}

class _LfIndalaPageState extends State<LfIndalaPage> {
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
    return Row(children: [
      SizedBox(
          width: 240,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ActionCard(
                      title: '读取',
                      subtitle: '读取 Indala 卡片',
                      icon: Icons.nfc,
                      onTap: () => _execute(LfIndalaCmd.reader())),
                  const SizedBox(height: 8),
                  Card(
                      child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('克隆 / 模拟',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                              const SizedBox(height: 8),
                              HexInputField(
                                  label: 'RAW 数据',
                                  onChanged: (v) =>
                                      setState(() => _rawData = v)),
                              const SizedBox(height: 8),
                              Wrap(spacing: 8, runSpacing: 8, children: [
                                ElevatedButton.icon(
                                    onPressed: _rawData.isNotEmpty
                                        ? () => _execute(
                                            LfIndalaCmd.clone(_rawData))
                                        : null,
                                    icon: const Icon(Icons.copy, size: 18),
                                    label: const Text('克隆')),
                                OutlinedButton.icon(
                                    onPressed: _rawData.isNotEmpty
                                        ? () =>
                                            _execute(LfIndalaCmd.sim(_rawData))
                                        : null,
                                    icon:
                                        const Icon(Icons.play_arrow, size: 18),
                                    label: const Text('模拟')),
                              ]),
                            ],
                          ))),
                ]),
          )),
      Expanded(
          child: Padding(
        padding: const EdgeInsets.all(8),
        child: ResultDisplay(
            command: _lastCmd,
            result: _result,
            isLoading: _isLoading,
            onClear: () => setState(() {
                  _result = '';
                  _lastCmd = '';
                })),
      )),
    ]);
  }
}
