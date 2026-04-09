/// Data processing utilities page.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pm3gui/state/app_state.dart';
import 'package:pm3gui/services/pm3_commands.dart';
import 'package:pm3gui/ui/components/components.dart';

class DataPage extends StatefulWidget {
  const DataPage({super.key});

  @override
  State<DataPage> createState() => _DataPageState();
}

class _DataPageState extends State<DataPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _file = '';
  String _sampleCount = '20000';
  String _hexData = '';
  String _fileA = '';
  String _fileB = '';

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
        Tab(text: '基础'),
        Tab(text: '分析'),
        Tab(text: '比较'),
      ]),
      Expanded(
          child: TabBarView(controller: _tabController, children: [
        _buildBasicTab(),
        _buildAnalyzeTab(),
        _buildDiffTab(),
      ])),
    ]);
  }

  Widget _buildBasicTab() {
    return SplitPageLayout(
      side: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ActionCard(
              title: '绘图',
              subtitle: '显示数据图表',
              icon: Icons.show_chart,
              onTap: () => _execute(DataCmd.plot())),
          ActionCard(
              title: '清除',
              subtitle: '清除绘图缓冲区',
              icon: Icons.clear_all,
              onTap: () => _execute(DataCmd.clear())),
          ActionCard(
              title: '检测时钟',
              subtitle: '自动检测时钟速率',
              icon: Icons.timer,
              onTap: () => _execute(DataCmd.detectclock())),
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('采样',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      TextFormField(
                        decoration: const InputDecoration(
                            labelText: '采样数', isDense: true),
                        initialValue: _sampleCount,
                        onChanged: (v) => _sampleCount = v,
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                          onPressed: () => _execute(DataCmd.samples(
                              count: int.tryParse(_sampleCount) ?? 20000)),
                          icon: const Icon(Icons.memory, size: 18),
                          label: const Text('读取采样')),
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

  Widget _buildAnalyzeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Card(
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('文件操作',
                        style: TextStyle(fontWeight: FontWeight.bold)),
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
                              ? () => _execute(DataCmd.save(_file))
                              : null,
                          icon: const Icon(Icons.save, size: 18),
                          label: const Text('保存')),
                      OutlinedButton.icon(
                          onPressed: _file.isNotEmpty
                              ? () => _execute(DataCmd.load(_file))
                              : null,
                          icon: const Icon(Icons.upload, size: 18),
                          label: const Text('加载')),
                    ]),
                  ],
                ))),
        const SizedBox(height: 12),
        Card(
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ASN.1 解码',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    HexInputField(
                        label: 'Hex 数据', onChanged: (v) => _hexData = v),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                        onPressed: _hexData.isNotEmpty
                            ? () => _execute(DataCmd.asn1(_hexData))
                            : null,
                        icon: const Icon(Icons.code, size: 18),
                        label: const Text('解码')),
                  ],
                ))),
      ]),
    );
  }

  Widget _buildDiffTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
          child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('文件比较',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextFormField(
                    decoration:
                        const InputDecoration(labelText: '文件 A', isDense: true),
                    onChanged: (v) => _fileA = v,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    decoration:
                        const InputDecoration(labelText: '文件 B', isDense: true),
                    onChanged: (v) => _fileB = v,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                      onPressed: _fileA.isNotEmpty && _fileB.isNotEmpty
                          ? () => _execute(DataCmd.diff(_fileA, _fileB))
                          : null,
                      icon: const Icon(Icons.compare, size: 18),
                      label: const Text('比较')),
                ],
              ))),
    );
  }
}
