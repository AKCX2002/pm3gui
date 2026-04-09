/// SEOS operations page.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pm3gui/state/app_state.dart';
import 'package:pm3gui/services/pm3_commands.dart';
import 'package:pm3gui/ui/components/components.dart';

class HfSeosPage extends StatefulWidget {
  const HfSeosPage({super.key});

  @override
  State<HfSeosPage> createState() => _HfSeosPageState();
}

class _HfSeosPageState extends State<HfSeosPage> {
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
          width: 220,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ActionCard(
                      title: '信息',
                      subtitle: '读取 SEOS 信息',
                      icon: Icons.info_outline,
                      onTap: () => _execute(HfSeosCmd.info())),
                  ActionCard(
                      title: 'PACS',
                      subtitle: '读取 PACS 数据',
                      icon: Icons.badge,
                      onTap: () => _execute(HfSeosCmd.pacs())),
                  ActionCard(
                      title: '模拟',
                      subtitle: '模拟 SEOS 卡片',
                      icon: Icons.play_arrow,
                      onTap: () => _execute(HfSeosCmd.sim())),
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
