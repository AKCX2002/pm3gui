import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pm3gui/backend/mock/mock_pm3_backend.dart';
import 'package:pm3gui/core/pm3/pm3_client_settings.dart';
import 'package:pm3gui/core/pm3/pm3_controller.dart';
import 'package:pm3gui/services/pm3_settings_store.dart';
import 'package:pm3gui/services/pm3_session_recorder.dart';
import 'package:pm3gui/state/app_state.dart';
import 'package:pm3gui/state/connection_state.dart' as connection;
import 'package:pm3gui/ui/widgets/command_card_editor.dart';

void main() {
  testWidgets(
      'raw command feeds editor, edit validates, navigation retains data',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late AppState app;
    late Directory temp;
    await tester.runAsync(() async {
      temp = await Directory.systemTemp.createTemp('command-editor-');
      final responses = <String, String>{};
      final conn = connection.ConnectionState(
        controller: Pm3Controller(MockPm3Backend(responses: responses)),
        settingsStore: _Settings(),
      )
        ..pm3Path = 'mock-client'
        ..portName = 'test-port';
      app = AppState(
          connectionState: conn,
          sessionRecorder:
              Pm3SessionRecorder(rootDirectoryProvider: () async => temp));
      expect(await app.connect(), isTrue);
      // Only the user command should receive the key table, not startup hw version.
      responses['terminal.raw'] =
          '[+] 000 | 003 | A0A1A2A3A4A5 | 1 | ------------ | 0';
    });
    addTearDown(() => tester.runAsync(() async {
          await app.shutdown();
          await temp.delete(recursive: true);
        }));
    Widget editor() => ChangeNotifierProvider.value(
        value: app,
        child: const MaterialApp(home: Scaffold(body: CommandCardEditor())));
    await tester.pumpWidget(editor());
    await tester.enterText(find.byType(TextField), 'hf mf chk --1k');
    await tester.tap(find.text('执行'));
    await tester.pumpAndSettle();
    expect(find.text('A0A1A2A3A4A5'), findsOneWidget);
    expect(app.terminalOutput.any((line) => line.contains('A0A1A2A3A4A5')),
        isTrue);
    await tester.tap(find.text('Key A'));
    await tester.pumpAndSettle();
    final field = find.descendant(
        of: find.byType(AlertDialog), matching: find.byType(TextField));
    await tester.enterText(field, 'BAD');
    await tester.tap(find.text('应用'));
    await tester.pump();
    expect(app.commandCard.keysA[0], 'A0A1A2A3A4A5');
    await tester.enterText(field, 'FF FF FF FF FF FF');
    await tester.tap(find.text('应用'));
    await tester.pumpAndSettle();
    expect(app.commandCard.keysA[0], 'FFFFFFFFFFFF');
    await tester.pumpWidget(const SizedBox());
    app.navigateTo(AppPage.terminal);
    await tester.pumpWidget(editor());
    expect(find.text('FFFFFFFFFFFF'), findsOneWidget);
    await tester.tap(find.text('导出 BIN'));
    await tester.pumpAndSettle();
    expect(find.textContaining('块 0 尚未完整'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}

class _Settings implements Pm3SettingsRepository {
  @override
  Future<Pm3ClientSettings?> load() async => null;
  @override
  Future<void> save(Pm3ClientSettings settings) async {}
}
