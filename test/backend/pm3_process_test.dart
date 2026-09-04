import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pm3gui/backend/desktop_cli/pm3_process.dart';

void main() {
  late Directory fixtureDirectory;
  late String fixturePath;

  setUp(() async {
    fixtureDirectory = await Directory.systemTemp.createTemp('pm3-process-');
    fixturePath =
        '${fixtureDirectory.path}${Platform.pathSeparator}fixture.dart';
    await File(fixturePath).writeAsString(_fixtureSource);
  });

  tearDown(() async {
    await fixtureDirectory.delete(recursive: true);
  });

  test('disconnect waits for a graceful child exit', () async {
    final process = Pm3Process(
      connectCooldown: Duration.zero,
      gracefulExitTimeout: const Duration(seconds: 1),
    );
    addTearDown(process.dispose);

    expect(
      await process.connect(
        _dartExecutable,
        'COM7',
        arguments: [fixturePath, 'graceful'],
      ).timeout(const Duration(seconds: 2)),
      isTrue,
    );

    final stopwatch = Stopwatch()..start();
    await process.disconnect().timeout(const Duration(seconds: 2));

    expect(process.state, Pm3ProcessState.disconnected);
    expect(stopwatch.elapsed, lessThan(const Duration(milliseconds: 400)));
  });

  test('connect returns false when child exits before prompt', () async {
    final process = Pm3Process(connectCooldown: Duration.zero);
    addTearDown(process.dispose);

    expect(
      await process.connect(
        _dartExecutable,
        'COM7',
        arguments: [fixturePath, 'early-exit'],
      ).timeout(const Duration(seconds: 2)),
      isFalse,
    );
    expect(process.lastError, contains('退出'));
  });

  test('disconnect kills a child that ignores quit', () async {
    final process = Pm3Process(
      connectCooldown: Duration.zero,
      gracefulExitTimeout: const Duration(milliseconds: 100),
    );
    addTearDown(process.dispose);

    expect(
      await process.connect(
        _dartExecutable,
        'COM7',
        arguments: [fixturePath, 'ignore-quit'],
      ).timeout(const Duration(seconds: 2)),
      isTrue,
    );

    await process.disconnect().timeout(const Duration(seconds: 2));

    expect(process.state, Pm3ProcessState.disconnected);
  });
}

const _fixtureSource = r'''
import 'dart:convert';
import 'dart:io';

void main(List<String> arguments) {
  final scenario = arguments.first;
  if (scenario == 'early-exit') {
    exit(17);
  }

  stdout.writeln('pm3 -->');
  stdin.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
    if (scenario == 'graceful' && line == 'quit') {
      exit(0);
    }
  });
}
''';

String get _dartExecutable {
  final executable = File(Platform.resolvedExecutable);
  if (executable.uri.pathSegments.last.toLowerCase().startsWith('dart')) {
    return executable.path;
  }
  var directory = executable.parent;
  while (directory.parent.path != directory.path) {
    final candidate = File(
      '${directory.path}${Platform.pathSeparator}dart-sdk'
      '${Platform.pathSeparator}bin${Platform.pathSeparator}dart.exe',
    );
    if (candidate.existsSync()) return candidate.path;
    directory = directory.parent;
  }
  final lookup = Process.runSync(
    Platform.isWindows ? 'where' : 'which',
    [Platform.isWindows ? 'dart.bat' : 'dart'],
  );
  final path = (lookup.stdout as String).trim().split(RegExp(r'[\r\n]+')).first;
  if (lookup.exitCode != 0 || path.isEmpty) {
    throw StateError('找不到当前 Dart 可执行文件');
  }
  return path;
}
