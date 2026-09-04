import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pm3gui/services/pm3_session_recorder.dart';

void main() {
  test('records metadata, terminal output and command history', () async {
    final directory = await Directory.systemTemp.createTemp('pm3-session-');
    addTearDown(() => directory.delete(recursive: true));
    final recorder = Pm3SessionRecorder(
      rootDirectoryProvider: () async => directory,
    );

    await recorder.start(devicePort: 'COM7', executable: 'proxmark3.exe');
    await recorder.recordCommand('hw version');
    await recorder.recordOutput('[+] client: v4');
    await recorder.close();

    final sessionPath = recorder.sessionPath;
    final metadata = jsonDecode(
      await File('$sessionPath${Platform.pathSeparator}session.json')
          .readAsString(),
    ) as Map<String, dynamic>;
    expect(metadata['devicePort'], 'COM7');
    expect(metadata['executable'], 'proxmark3.exe');
    expect(metadata['startedAt'], isA<String>());
    expect(
      await File('$sessionPath${Platform.pathSeparator}terminal.log')
          .readAsString(),
      contains('client: v4'),
    );
    expect(
      await File('$sessionPath${Platform.pathSeparator}commands.jsonl')
          .readAsString(),
      contains('hw version'),
    );
  });

  test('close writes endedAt after queued tail records', () async {
    final directory = await Directory.systemTemp.createTemp('pm3-session-');
    addTearDown(() => directory.delete(recursive: true));
    final recorder = Pm3SessionRecorder(
      rootDirectoryProvider: () async => directory,
    );

    await recorder.start(devicePort: 'COM7', executable: 'proxmark3.exe');
    final output = recorder.recordOutput('[+] final output');
    final command = recorder.recordCommand('hf 14a info');
    await recorder.close();
    await Future.wait([output, command]);

    final sessionPath = recorder.sessionPath;
    final metadata = jsonDecode(
      await File('$sessionPath${Platform.pathSeparator}session.json')
          .readAsString(),
    ) as Map<String, dynamic>;
    expect(metadata['endedAt'], isA<String>());
    expect(
      await File('$sessionPath${Platform.pathSeparator}terminal.log')
          .readAsString(),
      contains('final output'),
    );
    expect(
      await File('$sessionPath${Platform.pathSeparator}commands.jsonl')
          .readAsString(),
      contains('hf 14a info'),
    );
  });
}
