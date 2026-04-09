/// HF Sniff unified page.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pm3gui/state/app_state.dart';
import 'package:pm3gui/services/pm3_commands.dart';
import 'package:pm3gui/ui/components/components.dart';

class HfSniffPage extends StatefulWidget {
  const HfSniffPage({super.key});

  @override
  State<HfSniffPage> createState() => _HfSniffPageState();
}

class _HfSniffPageState extends State<HfSniffPage> {
  String _listProtocol = '14a';
  String _lastCmd = '';
  String _result = '';
  bool _isLoading = false;
  StreamSubscription<String>? _sub;

  static const _protocols = [
    '14a',
    '14b',
    'felica',
    'iclass',
    'legic',
    'mf',
    'topaz',
  ];

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
    return SplitPageLayout(
      side: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ActionCard(
              title: 'HF 搜索',
              subtitle: '搜索高频标签',
              icon: Icons.search,
              onTap: () => _execute(HfCmd.search())),
          ActionCard(
              title: 'HF 嗅探',
              subtitle: '捕获高频通信',
              icon: Icons.hearing,
              onTap: () => _execute(HfCmd.sniff())),
          ActionCard(
              title: 'HF 调谐',
              subtitle: '调谐高频天线',
              icon: Icons.tune,
              onTap: () => _execute(HfCmd.tune())),
          const SizedBox(height: 8),
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('协议列表',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _listProtocol,
                        decoration: const InputDecoration(
                            labelText: '协议', isDense: true),
                        items: _protocols
                            .map((p) =>
                                DropdownMenuItem(value: p, child: Text(p)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _listProtocol = v ?? '14a'),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                          onPressed: () => _execute(HfCmd.list(_listProtocol)),
                          icon: const Icon(Icons.list, size: 18),
                          label: const Text('列表解码')),
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
