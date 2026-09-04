import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pm3gui/backend/desktop_cli/desktop_cli_backend.dart';

void main() {
  test('Windows default discovery prefers pm3.bat over proxmark3.exe',
      () async {
    if (!Platform.isWindows) return;

    final originalDirectory = Directory.current;
    final fixtureDirectory =
        await Directory.systemTemp.createTemp('pm3-client-discovery-');
    try {
      Directory.current = fixtureDirectory;
      await File('pm3.bat').writeAsString('@echo off\r\n');
      await File('proxmark3.exe').writeAsBytes(const []);

      expect(
        DesktopCliBackend.detectExecutable(),
        File('pm3.bat').absolute.path,
      );
    } finally {
      Directory.current = originalDirectory;
      await fixtureDirectory.delete(recursive: true);
    }
  });
}
