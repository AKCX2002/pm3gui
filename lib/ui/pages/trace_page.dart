/// Trace capture and analysis page.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pm3gui/state/app_state.dart';
import 'package:pm3gui/services/pm3_commands.dart';
import 'package:pm3gui/ui/components/components.dart';

class TracePage extends StatefulWidget {
  const TracePage({super.key});

  @override
  State<TracePage> createState() => _TracePageState();
}

class _TracePageState extends State<TracePage> {
  String _file = '';
  String _protocol = 'raw';

  String _lastCmd = '';
  String _result = '';
  bool _isLoading = false;
  StreamSubscription<String>? _sub;

  static const _protocols = [
    'raw',
    '14a',
    '14b',
    'felica',
    'iclass',
    'legic',
    'mf',
    'hitag1',
    'hitag2',
    'hitags',
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
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('列表/解码',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _protocol,
                        decoration: const InputDecoration(
                            labelText: '协议类型', isDense: true),
                        items: _protocols
                            .map((p) =>
                                DropdownMenuItem(value: p, child: Text(p)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _protocol = v ?? 'raw'),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                          onPressed: () =>
                              _execute(TraceCmd.list(type: _protocol)),
                          icon: const Icon(Icons.list_alt, size: 18),
                          label: const Text('解码列表')),
                    ],
                  ))),
          ActionCard(
              title: '提取',
              subtitle: '提取 Trace 数据',
              icon: Icons.filter_alt,
              onTap: () => _execute(TraceCmd.extract())),
          const SizedBox(height: 8),
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('文件操作',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      TextFormField(
                        decoration: const InputDecoration(
                            labelText: '文件路径', isDense: true),
                        onChanged: (v) => _file = v,
                      ),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        ElevatedButton.icon(
                            onPressed: _file.isNotEmpty
                                ? () => _execute(TraceCmd.save(_file))
                                : null,
                            icon: const Icon(Icons.save, size: 18),
                            label: const Text('保存')),
                        OutlinedButton.icon(
                            onPressed: _file.isNotEmpty
                                ? () => _execute(TraceCmd.load(_file))
                                : null,
                            icon: const Icon(Icons.upload, size: 18),
                            label: const Text('加载')),
                      ]),
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
