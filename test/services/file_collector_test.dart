import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pm3gui/services/file_collector.dart';

void main() {
  test('batch client preferences and optional dump suffix are collected',
      () async {
    final root = await Directory.systemTemp.createTemp('pm3-collector-');
    addTearDown(() => root.delete(recursive: true));
    final client = Directory(p.join(root.path, 'client'))..createSync();
    File(p.join(client.path, 'setup.bat')).writeAsStringSync('');
    final output = Directory(p.join(root.path, 'saved'))..createSync();
    final prefs = Directory(p.join(client.path, '.proxmark3'))..createSync();
    File(p.join(prefs.path, 'preferences.json'))
        .writeAsStringSync(jsonEncode({'file.default.dumppath': output.path}));
    for (final name in [
      'hf-mf-11223344-dump.bin',
      'hf-mfu-11223344556677.json',
      'hf-mf-11223344.keys.txt',
      'hf-mf-11223344-key-001.bin'
    ]) {
      File(p.join(output.path, name)).writeAsStringSync('test');
    }
    final dirs = FileCollector.defaultScanDirs(p.join(root.path, 'pm3.bat'));
    expect(dirs, contains(client.path));
    expect(dirs, contains(output.path));
    final files = await FileCollector.scan([output.path]);
    expect(files, hasLength(4));
    expect(files.where((f) => f.fileType == CardFileType.key), hasLength(2));
    File(p.join(prefs.path, 'preferences.json')).writeAsStringSync('{broken');
    final errors = <String>[];
    expect(
        FileCollector.defaultScanDirs(p.join(root.path, 'pm3.bat'),
            onError: errors.add),
        contains(client.path));
    expect(errors, hasLength(1));
  });
}
