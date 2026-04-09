/// LF HID Prox operations page.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pm3gui/state/app_state.dart';
import 'package:pm3gui/services/pm3_commands.dart';
import 'package:pm3gui/ui/components/components.dart';

class LfHidPage extends StatefulWidget {
  const LfHidPage({super.key});

  @override
  State<LfHidPage> createState() => _LfHidPageState();
}

class _LfHidPageState extends State<LfHidPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String _cardData = '';
  String _fc = '';

  String _lastCmd = '';
  String _result = '';
  bool _isLoading = false;
  StreamSubscription<String>? _sub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
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
    return Column(children: [
      TabBar(controller: _tabController, tabs: const [
        Tab(text: '读取'),
        Tab(text: '克隆/模拟'),
        Tab(text: '破解'),
      ]),
      Expanded(
          child: TabBarView(controller: _tabController, children: [
        _buildReadTab(),
        _buildCloneSimTab(),
        _buildCrackTab(),
      ])),
    ]);
  }

  Widget _buildReadTab() {
    return Row(children: [
      SizedBox(
          width: 220,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ActionCard(
                      title: '读取 HID 卡',
                      subtitle: '读取 HID Prox 卡片',
                      icon: Icons.nfc,
                      onTap: () => _execute(LfHidCmd.reader())),
                  ActionCard(
                      title: '解调信号',
                      subtitle: '解调 HID 低频信号',
                      icon: Icons.radio,
                      onTap: () => _execute(LfHidCmd.demod())),
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

  Widget _buildCloneSimTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Card(
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('克隆 / 模拟',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Wiegand 数据',
                        hintText: '例如: 2006ec0c86',
                        prefixIcon: Icon(Icons.credit_card, size: 18),
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9a-fA-F]'))
                      ],
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 13),
                      onChanged: (v) => _cardData = v,
                    ),
                    const SizedBox(height: 12),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      ElevatedButton.icon(
                          onPressed: _cardData.isNotEmpty
                              ? () => _execute(LfHidCmd.clone(_cardData))
                              : null,
                          icon: const Icon(Icons.copy, size: 18),
                          label: const Text('克隆到 T55xx')),
                      OutlinedButton.icon(
                          onPressed: _cardData.isNotEmpty
                              ? () => _execute(LfHidCmd.sim(_cardData))
                              : null,
                          icon: const Icon(Icons.play_arrow, size: 18),
                          label: const Text('模拟')),
                    ]),
                  ],
                ))),
      ]),
    );
  }

  Widget _buildCrackTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Card(
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('暴力破解',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'FC（可选）',
                        hintText: '留空则遍历所有',
                        prefixIcon: Icon(Icons.numbers, size: 18),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (v) => _fc = v,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                        onPressed: () => _execute(
                            LfHidCmd.brute(fc: _fc.isEmpty ? null : _fc)),
                        icon: const Icon(Icons.bolt, size: 18),
                        label: const Text('开始破解')),
                  ],
                ))),
      ]),
    );
  }
}
