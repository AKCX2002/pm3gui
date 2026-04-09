/// LF Hitag operations page.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pm3gui/state/app_state.dart';
import 'package:pm3gui/services/pm3_commands.dart';
import 'package:pm3gui/ui/components/components.dart';

class LfHitagPage extends StatefulWidget {
  const LfHitagPage({super.key});

  @override
  State<LfHitagPage> createState() => _LfHitagPageState();
}

class _LfHitagPageState extends State<LfHitagPage> {
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
                      subtitle: '读取 Hitag 卡片',
                      icon: Icons.nfc,
                      onTap: () => _execute(LfHitagCmd.reader())),
                  ActionCard(
                      title: '信息',
                      subtitle: '获取标签详情',
                      icon: Icons.info_outline,
                      onTap: () => _execute(LfHitagCmd.info())),
                  ActionCard(
                      title: '转储',
                      subtitle: '转储全部数据',
                      icon: Icons.download,
                      onTap: () => _execute(LfHitagCmd.dump())),
                  ActionCard(
                      title: '嗅探',
                      subtitle: '捕获通信数据',
                      icon: Icons.hearing,
                      onTap: () => _execute(LfHitagCmd.sniff())),
                  ActionCard(
                      title: '检查密钥',
                      subtitle: '检查常用密钥',
                      icon: Icons.security,
                      onTap: () => _execute(LfHitagCmd.chk())),
                  ActionCard(
                      title: '破解',
                      subtitle: '密钥恢复攻击',
                      icon: Icons.bolt,
                      onTap: () => _execute(LfHitagCmd.crack())),
                  ActionCard(
                      title: '模拟',
                      subtitle: '模拟 Hitag 标签',
                      icon: Icons.play_arrow,
                      onTap: () => _execute(LfHitagCmd.sim())),
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
