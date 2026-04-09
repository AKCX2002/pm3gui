/// Connection-guard wrapper.
///
/// Calls [onExecute] only when the device is connected;
/// otherwise shows a SnackBar warning.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pm3gui/state/app_state.dart';

/// Execute [cmd] via AppState only if PM3 is connected.
/// Returns `true` when the command was dispatched.
bool executeIfConnected(BuildContext context, String cmd) {
  final appState = context.read<AppState>();
  if (!appState.isConnected) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('未连接 PM3')),
    );
    return false;
  }
  appState.sendCommand(cmd);
  return true;
}
