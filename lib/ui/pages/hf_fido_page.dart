/// FIDO / FIDO2 operations page.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pm3gui/state/app_state.dart';
import 'package:pm3gui/services/pm3_commands.dart';
import 'package:pm3gui/ui/components/components.dart';

class HfFidoPage extends StatefulWidget {
  const HfFidoPage({super.key});

  @override
  State<HfFidoPage> createState() => _HfFidoPageState();
}

class _HfFidoPageState extends State<HfFidoPage> {
  String _lastCmd = '';
  String _result = '';
  bool _isLoading = false;
  StreamSubscription<String>? _sub;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _execute(String cmd) async {
    if (!ensurePm3Ready(context)) return;
    setState(() {
      _lastCmd = cmd;
      _isLoading = true;
      _result = '';
    });
    final buf = StringBuffer();
    _sub?.cancel();
    _sub = context.read<AppState>().pm3PageOutput.listen((line) {
      if (!line.startsWith('[pm3]')) {
        buf.writeln(line);
        if (mounted) setState(() => _result = buf.toString());
      }
    });
    await context.read<AppState>().sendCommand(cmd);
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return SplitPageLayout(
      side: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ActionCard(
              title: '信息',
              subtitle: '读取 FIDO 信息',
              icon: Icons.fingerprint,
              onTap: () => _execute(HfFidoCmd.info())),
          ActionCard(
              title: '注册',
              subtitle: 'FIDO2 注册',
              icon: Icons.app_registration,
              onTap: () => _execute(HfFidoCmd.reg())),
          ActionCard(
              title: '认证',
              subtitle: 'FIDO2 认证',
              icon: Icons.verified_user,
              onTap: () => _execute(HfFidoCmd.auth())),
          ActionCard(
              title: '列表',
              subtitle: '列出 FIDO 通信',
              icon: Icons.list_alt,
              onTap: () => _execute('hf fido list')),
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
