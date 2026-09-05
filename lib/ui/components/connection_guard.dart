/// Connection-guard wrapper.
///
/// Checks whether the device can accept a command without dispatching it.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pm3gui/state/app_state.dart';

/// 只检查连接与忙状态；调用方先订阅输出，再发送一次命令。
bool ensurePm3Ready(BuildContext context) {
  final appState = context.read<AppState>();
  if (!appState.isConnected) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('未连接 PM3')),
    );
    return false;
  }
  if (appState.connectionState.controller.isExecuting) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PM3 命令仍在执行，请等待完成或断开连接')),
    );
    return false;
  }
  return true;
}
