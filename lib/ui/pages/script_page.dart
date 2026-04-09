/// Script management page.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pm3gui/state/app_state.dart';
import 'package:pm3gui/services/pm3_commands.dart';
import 'package:pm3gui/ui/components/components.dart';

class ScriptPage extends StatefulWidget {
  const ScriptPage({super.key});

  @override
  State<ScriptPage> createState() => _ScriptPageState();
}

class _ScriptPageState extends State<ScriptPage> {
  String _scriptName = '';
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
    Future.delayed(const Duration(seconds: 10), () {
      _sub?.cancel();
      if (mounted) setState(() => _isLoading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      SizedBox(
          width: 260,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ActionCard(
                      title: '列表',
                      subtitle: '列出可用脚本',
                      icon: Icons.list,
                      onTap: () => _execute(ScriptCmd.list())),
                  const SizedBox(height: 8),
                  Card(
                      child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('运行脚本',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                              const SizedBox(height: 8),
                              TextFormField(
                                decoration: const InputDecoration(
                                  labelText: '脚本名称',
                                  hintText: '例如: hf_mf_autopwn',
                                  isDense: true,
                                ),
                                onChanged: (v) => _scriptName = v,
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                  onPressed: _scriptName.isNotEmpty
                                      ? () =>
                                          _execute(ScriptCmd.run(_scriptName))
                                      : null,
                                  icon: const Icon(Icons.play_arrow, size: 18),
                                  label: const Text('运行')),
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
