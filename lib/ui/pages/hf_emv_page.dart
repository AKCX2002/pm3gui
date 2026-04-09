/// EMV contactless payment operations page.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pm3gui/state/app_state.dart';
import 'package:pm3gui/services/pm3_commands.dart';
import 'package:pm3gui/ui/components/components.dart';

class HfEmvPage extends StatefulWidget {
  const HfEmvPage({super.key});

  @override
  State<HfEmvPage> createState() => _HfEmvPageState();
}

class _HfEmvPageState extends State<HfEmvPage> {
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
    Future.delayed(const Duration(seconds: 8), () {
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
                      title: '搜索',
                      subtitle: '搜索 EMV 卡片',
                      icon: Icons.search,
                      onTap: () => _execute(HfEmvCmd.search())),
                  ActionCard(
                      title: 'PPSE',
                      subtitle: '选择 PPSE 应用',
                      icon: Icons.payment,
                      onTap: () => _execute(HfEmvCmd.ppse())),
                  ActionCard(
                      title: '执行交易',
                      subtitle: '模拟 EMV 交易流程',
                      icon: Icons.receipt_long,
                      onTap: () => _execute(HfEmvCmd.exec())),
                  ActionCard(
                      title: '测试',
                      subtitle: 'EMV 自检',
                      icon: Icons.check_circle,
                      onTap: () => _execute(HfEmvCmd.test())),
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
