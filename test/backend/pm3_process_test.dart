import 'dart:async';
import 'dart:convert';
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

  test('disconnect invalidates a connect that is still starting', () async {
    final started = Completer<Pm3ProcessHandle>();
    final process = Pm3Process(
      connectCooldown: Duration.zero,
      gracefulExitTimeout: const Duration(milliseconds: 20),
      killExitTimeout: const Duration(milliseconds: 20),
      processStarter: (_, __, {workingDirectory}) => started.future,
    );
    addTearDown(process.dispose);

    final connecting = process.connect(_dartExecutable, 'COM7');
    await process.disconnect().timeout(const Duration(seconds: 2));

    final child = _FakeProcess();
    started.complete(child);

    expect(await connecting.timeout(const Duration(seconds: 2)), isFalse);
    expect(child.killCount, 1);
    expect(process.state, Pm3ProcessState.disconnected);
  });

  test('stderr fatal error fails connection without waiting for timeout',
      () async {
    final child = _FakeProcess();
    final process = Pm3Process(
      connectCooldown: Duration.zero,
      processStarter: (_, __, {workingDirectory}) async => child,
    );
    addTearDown(process.dispose);

    final connecting = process.connect(_dartExecutable, 'COM7');
    await Future<void>.delayed(Duration.zero);
    child.stderrController.add(utf8.encode('error serial port unavailable\n'));

    expect(await connecting.timeout(const Duration(seconds: 2)), isFalse);
    expect(process.lastError, contains('串口连接错误'));
  });

  test('output stream closing before prompt fails connection immediately',
      () async {
    final child = _FakeProcess();
    final process = Pm3Process(
      connectCooldown: Duration.zero,
      processStarter: (_, __, {workingDirectory}) async => child,
    );
    addTearDown(process.dispose);

    final connecting = process.connect(_dartExecutable, 'COM7');
    await Future<void>.delayed(Duration.zero);
    await child.stdoutController.close();

    expect(await connecting.timeout(const Duration(seconds: 2)), isFalse);
    expect(process.lastError, contains('stdout 流已关闭'));
  });

  test('kill failure and exit failure do not leave disconnect pending',
      () async {
    final child = _FakeProcess(killResult: false);
    final process = Pm3Process(
      connectCooldown: Duration.zero,
      gracefulExitTimeout: const Duration(milliseconds: 20),
      killExitTimeout: const Duration(milliseconds: 20),
      processStarter: (_, __, {workingDirectory}) async => child,
    );
    addTearDown(process.dispose);

    final connecting = process.connect(_dartExecutable, 'COM7');
    await Future<void>.delayed(Duration.zero);
    child.stdoutController.add(utf8.encode('pm3 -->\n'));
    expect(await connecting.timeout(const Duration(seconds: 2)), isTrue);

    await process.disconnect().timeout(const Duration(seconds: 2));

    expect(process.state, Pm3ProcessState.disconnected);
    expect(process.lastError, contains('终止'));
  });

  test('exitCode error closes a connected process without a zone error',
      () async {
    final child = _FakeProcess();
    final process = Pm3Process(
      connectCooldown: Duration.zero,
      processStarter: (_, __, {workingDirectory}) async => child,
    );
    addTearDown(process.dispose);

    final connecting = process.connect(_dartExecutable, 'COM7');
    await Future<void>.delayed(Duration.zero);
    child.stdoutController.add(utf8.encode('pm3 -->\n'));
    expect(await connecting.timeout(const Duration(seconds: 2)), isTrue);

    child.failExit(StateError('exitCode failed'));
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(process.state, Pm3ProcessState.disconnected);
    expect(process.lastError, contains('退出状态错误'));
  });

  test('dispose consumes subscription cancellation errors', () async {
    final child = _FakeProcess(cancelFails: true);
    final process = Pm3Process(
      connectCooldown: Duration.zero,
      processStarter: (_, __, {workingDirectory}) async => child,
    );

    final connecting = process.connect(_dartExecutable, 'COM7');
    await Future<void>.delayed(Duration.zero);
    process.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(await connecting.timeout(const Duration(seconds: 2)), isFalse);
  });
}

final class _FakeProcess implements Pm3ProcessHandle {
  _FakeProcess({this.killResult = true, bool cancelFails = false})
      : stdoutController = StreamController<List<int>>(
          onCancel: cancelFails
              ? () => Future<void>.error(StateError('stdout cancel failed'))
              : null,
        ),
        stderrController = StreamController<List<int>>(
          onCancel: cancelFails
              ? () => Future<void>.error(StateError('stderr cancel failed'))
              : null,
        );

  final bool killResult;
  final StreamController<List<int>> stdoutController;
  final StreamController<List<int>> stderrController;
  final Completer<int> _exitCode = Completer<int>();
  int killCount = 0;

  @override
  Stream<List<int>> get stdout => stdoutController.stream;

  @override
  Stream<List<int>> get stderr => stderrController.stream;

  @override
  Future<int> get exitCode => _exitCode.future;

  @override
  bool kill() {
    killCount++;
    if (killResult && !_exitCode.isCompleted) _exitCode.complete(-9);
    return killResult;
  }

  void failExit(Object error) {
    if (!_exitCode.isCompleted) _exitCode.completeError(error);
  }

  @override
  Future<void> writeLine(String line) async {}
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
