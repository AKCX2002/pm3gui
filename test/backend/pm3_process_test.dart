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

  test('Windows batch client starts through cmd call without PM3 arguments',
      () async {
    if (!Platform.isWindows) return;

    final batchPath =
        '${fixtureDirectory.path}${Platform.pathSeparator}pm3.bat';
    await File(batchPath).writeAsString('@echo off\r\n');
    final child = _FakeProcess();
    String? startedExecutable;
    List<String>? startedArguments;
    String? startedWorkingDirectory;
    final process = Pm3Process(
      connectCooldown: Duration.zero,
      processStarter: (executable, arguments, {workingDirectory}) async {
        startedExecutable = executable;
        startedArguments = arguments;
        startedWorkingDirectory = workingDirectory;
        return child;
      },
    );
    addTearDown(process.dispose);

    final connecting = process.connect(
      batchPath,
      'COM7',
      arguments: const ['--flush', '--custom'],
    );
    await Future<void>.delayed(Duration.zero);

    expect(startedExecutable, 'cmd.exe');
    expect(
        startedArguments, ['/d', '/c', 'call', File(batchPath).absolute.path]);
    expect(startedWorkingDirectory, File(batchPath).absolute.parent.path);

    child.stdoutController.add(utf8.encode('pm3 -->\n'));
    expect(await connecting.timeout(const Duration(seconds: 2)), isTrue);
  });

  test('Windows batch client keeps stdio and bounds trailing pause shutdown',
      () async {
    if (!Platform.isWindows) return;

    final bundleDirectory = Directory(
      '${fixtureDirectory.path}${Platform.pathSeparator}official client bundle',
    );
    await bundleDirectory.create();
    final batchFile = File(
      '${bundleDirectory.path}${Platform.pathSeparator}pm3.bat',
    );
    await batchFile.writeAsString(r'''@echo off
echo Communicating with PM3 over USB-CDC
echo pm3 --^>
set /p pm3_command=
if /i not "%pm3_command%"=="quit" exit /b 9
pause >nul
''');
    final process = Pm3Process(
      connectCooldown: Duration.zero,
      gracefulExitTimeout: const Duration(milliseconds: 100),
      killExitTimeout: const Duration(seconds: 1),
    );
    addTearDown(process.dispose);

    expect(
      await process.connect(batchFile.path, '',
          arguments: const ['--ignored']).timeout(const Duration(seconds: 2)),
      isTrue,
    );

    await process.disconnect().timeout(const Duration(seconds: 2));

    expect(process.state, Pm3ProcessState.disconnected);
  });

  test('Windows forced disconnect terminates the exact batch process tree',
      () async {
    if (!Platform.isWindows) return;

    final childScript = File(
      '${fixtureDirectory.path}${Platform.pathSeparator}tree_child.dart',
    );
    final childPidFile = File(
      '${fixtureDirectory.path}${Platform.pathSeparator}tree_child.pid',
    );
    await childScript.writeAsString(_treeChildFixtureSource);
    final batchFile = File(
      '${fixtureDirectory.path}${Platform.pathSeparator}tree_fixture.bat',
    );
    await batchFile.writeAsString('''@echo off
start "" /b "$_dartExecutable" "${childScript.path}" "${childPidFile.path}"
:wait_for_pid
if not exist "${childPidFile.path}" (
  ping 127.0.0.1 -n 2 >nul
  goto wait_for_pid
)
echo pm3 --^>
set /p pm3_command=
pause >nul
''');
    final process = Pm3Process(
      connectCooldown: Duration.zero,
      gracefulExitTimeout: const Duration(milliseconds: 100),
      killExitTimeout: const Duration(seconds: 1),
    );
    addTearDown(process.dispose);
    int? childPid;

    try {
      expect(
        await process.connect(batchFile.path, '').timeout(
              const Duration(seconds: 5),
            ),
        isTrue,
      );
      expect(
        await _waitUntil(() async => childPidFile.existsSync()),
        isTrue,
      );
      childPid = int.parse(await childPidFile.readAsString());
      expect(await _isWindowsPidRunning(childPid), isTrue);

      await process.disconnect().timeout(const Duration(seconds: 3));

      expect(
        await _waitUntil(() => _isWindowsPidRunning(childPid!),
            expected: false),
        isTrue,
      );
    } finally {
      if (childPid != null && await _isWindowsPidRunning(childPid)) {
        await Process.run(
          'taskkill',
          ['/PID', '$childPid', '/T', '/F'],
          runInShell: false,
        );
      }
    }
  });

  test('native client keeps configured arguments port and flush flag',
      () async {
    final child = _FakeProcess();
    String? startedExecutable;
    List<String>? startedArguments;
    final process = Pm3Process(
      connectCooldown: Duration.zero,
      processStarter: (executable, arguments, {workingDirectory}) async {
        startedExecutable = executable;
        startedArguments = arguments;
        return child;
      },
    );
    addTearDown(process.dispose);

    final connecting = process.connect(
      _dartExecutable,
      'COM7',
      arguments: const ['--custom'],
    );
    await Future<void>.delayed(Duration.zero);

    expect(startedExecutable, _dartExecutable);
    expect(startedArguments, ['--custom', '-p', 'COM7', '-f']);

    child.stdoutController.add(utf8.encode('pm3 -->\n'));
    expect(await connecting.timeout(const Duration(seconds: 2)), isTrue);
  });

  test('USB-CDC progress line does not connect before a real prompt', () async {
    final child = _FakeProcess();
    final process = Pm3Process(
      connectCooldown: Duration.zero,
      processStarter: (_, __, {workingDirectory}) async => child,
    );
    addTearDown(process.dispose);

    var completed = false;
    final connecting = process.connect(_dartExecutable, 'COM7')
      ..whenComplete(() => completed = true);
    await Future<void>.delayed(Duration.zero);

    child.stdoutController.add(
      utf8.encode('Communicating with PM3 over USB-CDC\n'),
    );
    await Future<void>.delayed(Duration.zero);

    expect(process.state, Pm3ProcessState.connecting);
    expect(completed, isFalse);
    expect(child.writtenLines, isEmpty);

    child.stdoutController.add(utf8.encode('[usb] pm3 -->\n'));
    expect(await connecting.timeout(const Duration(seconds: 2)), isTrue);
  });

  test('Windows batch handshake write failure ends connection with diagnosis',
      () async {
    if (!Platform.isWindows) return;

    final batchPath =
        '${fixtureDirectory.path}${Platform.pathSeparator}pm3.bat';
    await File(batchPath).writeAsString('@echo off\r\n');
    final child = _FakeProcess(writeError: StateError('stdin closed'));
    final process = Pm3Process(
      connectCooldown: Duration.zero,
      processStarter: (_, __, {workingDirectory}) async => child,
    );
    addTearDown(process.dispose);

    final connecting = process.connect(batchPath, '');
    await Future<void>.delayed(Duration.zero);
    child.stdoutController.add(
      utf8.encode('[+] Communicating with PM3 over USB-CDC\n'),
    );

    expect(
      await connecting.timeout(const Duration(seconds: 2)),
      isFalse,
    );
    expect(child.writtenLines, ['hw version']);
    expect(process.lastError, contains('只读握手写入失败'));
    await Future<void>.delayed(Duration.zero);
    expect(process.state, Pm3ProcessState.disconnected);
  });

  test('prompt split across chunks connects without a trailing newline',
      () async {
    final child = _FakeProcess();
    final process = Pm3Process(
      connectCooldown: Duration.zero,
      connectTimeout: const Duration(milliseconds: 300),
      processStarter: (_, __, {workingDirectory}) async => child,
    );
    addTearDown(process.dispose);

    var completed = false;
    final connecting = process.connect(_dartExecutable, 'COM7')
      ..whenComplete(() => completed = true);
    await Future<void>.delayed(Duration.zero);

    child.stdoutController.add(
      utf8.encode('[+] Communicating with PM3 over USB-CDC\n'),
    );
    await Future<void>.delayed(Duration.zero);
    expect(process.state, Pm3ProcessState.connecting);
    expect(completed, isFalse);

    child.stdoutController.add(utf8.encode('[usb] pm'));
    child.stdoutController.add(utf8.encode('3 -->'));

    expect(await connecting, isTrue);
    expect(process.state, Pm3ProcessState.connected);
  });

  test('Windows batch sends one read-only handshake before waiting for prompt',
      () async {
    if (!Platform.isWindows) return;

    final batchPath =
        '${fixtureDirectory.path}${Platform.pathSeparator}pm3.bat';
    await File(batchPath).writeAsString('@echo off\r\n');
    final child = _FakeProcess();
    final process = Pm3Process(
      connectCooldown: Duration.zero,
      processStarter: (_, __, {workingDirectory}) async => child,
    );
    addTearDown(process.dispose);

    var completed = false;
    final connecting = process.connect(batchPath, '')
      ..whenComplete(() => completed = true);
    await Future<void>.delayed(Duration.zero);

    child.stdoutController.add(
      utf8.encode('[+] Communicating with PM3 over USB-CDC\n'),
    );
    await Future<void>.delayed(Duration.zero);

    expect(child.writtenLines, ['hw version']);
    expect(process.state, Pm3ProcessState.connecting);
    expect(completed, isFalse);

    child.stdoutController.add(utf8.encode('os: RRG/Iceman v4.20469\n'));
    await Future<void>.delayed(Duration.zero);
    expect(process.state, Pm3ProcessState.connecting);
    expect(completed, isFalse);

    child.stdoutController.add(
      utf8.encode('[+] Communicating with PM3 over USB-CDC\n'),
    );
    await Future<void>.delayed(Duration.zero);
    expect(child.writtenLines, ['hw version']);

    child.stdoutController.add(
      utf8.encode('[usb|script] pm3 --> hw version'),
    );
    expect(await connecting.timeout(const Duration(seconds: 2)), isTrue);
  });

  test('disconnect completes an owned in-flight connection immediately',
      () async {
    final child = _FakeProcess();
    final process = Pm3Process(
      connectCooldown: Duration.zero,
      gracefulExitTimeout: const Duration(milliseconds: 300),
      processStarter: (_, __, {workingDirectory}) async => child,
    );
    addTearDown(process.dispose);

    final connecting = process.connect(_dartExecutable, 'COM7');
    await Future<void>.delayed(Duration.zero);

    final disconnecting = process.disconnect();
    expect(
      await connecting.timeout(const Duration(milliseconds: 100)),
      isFalse,
    );
    await disconnecting.timeout(const Duration(seconds: 2));
    expect(process.state, Pm3ProcessState.disconnected);
  });

  test('transport tag alone does not connect before the pm3 prompt', () async {
    final child = _FakeProcess();
    final process = Pm3Process(
      connectCooldown: Duration.zero,
      processStarter: (_, __, {workingDirectory}) async => child,
    );
    addTearDown(process.dispose);

    var completed = false;
    final connecting = process.connect(_dartExecutable, 'COM7')
      ..whenComplete(() => completed = true);
    await Future<void>.delayed(Duration.zero);

    child.stdoutController.add(utf8.encode('[usb] transport ready\n'));
    await Future<void>.delayed(Duration.zero);
    expect(process.state, Pm3ProcessState.connecting);
    expect(completed, isFalse);

    child.stdoutController.add(utf8.encode('[usb] pm3 -->'));
    expect(await connecting.timeout(const Duration(seconds: 2)), isTrue);
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

  test('termination escalates from TERM to KILL when TERM is ignored',
      () async {
    final child = _FakeProcess(ignoreGracefulTermination: true);
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

    expect(child.terminationForces, [false, true]);
    expect(process.state, Pm3ProcessState.disconnected);
  });

  test('disconnect waits for an invalidated start to be terminated', () async {
    final started = Completer<Pm3ProcessHandle>();
    final process = Pm3Process(
      connectCooldown: Duration.zero,
      gracefulExitTimeout: const Duration(milliseconds: 20),
      killExitTimeout: const Duration(milliseconds: 20),
      processStarter: (_, __, {workingDirectory}) => started.future,
    );
    addTearDown(process.dispose);

    final connecting = process.connect(_dartExecutable, 'COM7');
    final disconnecting = process.disconnect();
    expect(process.disconnect(), same(disconnecting));
    var disconnectCompleted = false;
    unawaited(disconnecting.then((_) => disconnectCompleted = true));

    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(disconnectCompleted, isFalse);
    expect(process.state, Pm3ProcessState.connecting);

    final child = _FakeProcess();
    started.complete(child);

    await disconnecting.timeout(const Duration(seconds: 2));
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

  test('shutdown waits until process termination is confirmed', () async {
    final terminationGate = Completer<void>();
    final child = _FakeProcess(terminationGate: terminationGate.future);
    final process = Pm3Process(
      connectCooldown: Duration.zero,
      processStarter: (_, __, {workingDirectory}) async => child,
    );
    final states = <Pm3ProcessState>[];
    final stateSubscription = process.stateStream.listen(states.add);
    addTearDown(stateSubscription.cancel);
    final connecting = process.connect(_dartExecutable, 'COM7');
    await Future<void>.delayed(Duration.zero);
    child.stdoutController.add(utf8.encode('pm3 -->\n'));
    expect(await connecting.timeout(const Duration(seconds: 2)), isTrue);
    var completed = false;

    final shuttingDown = process.shutdown()..then((_) => completed = true);
    await Future<void>.delayed(Duration.zero);

    expect(completed, isFalse);
    terminationGate.complete();
    await shuttingDown.timeout(const Duration(seconds: 2));
    expect(child.killCount, 1);
    expect(process.state, Pm3ProcessState.disconnected);
    expect(
      states.where((state) => state == Pm3ProcessState.disconnected),
      hasLength(1),
    );
  });

  test('dispose retries a failed kill with bounded background cleanup',
      () async {
    final child = _FakeProcess(killResults: [false, true]);
    final process = Pm3Process(
      connectCooldown: Duration.zero,
      killExitTimeout: const Duration(milliseconds: 20),
      processStarter: (_, __, {workingDirectory}) async => child,
    );

    final connecting = process.connect(_dartExecutable, 'COM7');
    await Future<void>.delayed(Duration.zero);
    child.stdoutController.add(utf8.encode('pm3 -->\n'));
    expect(await connecting.timeout(const Duration(seconds: 2)), isTrue);

    process.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(child.killCount, 2);
  });

  test('dispose consumes a thrown first kill and retries once', () async {
    final child = _FakeProcess(
      throwOnFirstKill: true,
      killResults: [true],
    );
    final process = Pm3Process(
      connectCooldown: Duration.zero,
      killExitTimeout: const Duration(milliseconds: 20),
      processStarter: (_, __, {workingDirectory}) async => child,
    );

    final connecting = process.connect(_dartExecutable, 'COM7');
    await Future<void>.delayed(Duration.zero);
    child.stdoutController.add(utf8.encode('pm3 -->\n'));
    expect(await connecting.timeout(const Duration(seconds: 2)), isTrue);

    process.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(child.killCount, 2);
  });
}

final class _FakeProcess implements Pm3ProcessHandle {
  _FakeProcess({
    this.killResult = true,
    List<bool>? killResults,
    this.throwOnFirstKill = false,
    this.ignoreGracefulTermination = false,
    this.writeError,
    this.terminationGate,
    bool cancelFails = false,
  })  : _killResults = killResults == null ? null : List<bool>.of(killResults),
        stdoutController = StreamController<List<int>>(
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
  final bool throwOnFirstKill;
  final bool ignoreGracefulTermination;
  final Object? writeError;
  final Future<void>? terminationGate;
  final List<bool>? _killResults;
  final StreamController<List<int>> stdoutController;
  final StreamController<List<int>> stderrController;
  final Completer<int> _exitCode = Completer<int>();
  final List<String> writtenLines = [];
  final List<bool> terminationForces = [];
  int killCount = 0;

  @override
  Stream<List<int>> get stdout => stdoutController.stream;

  @override
  Stream<List<int>> get stderr => stderrController.stream;

  @override
  Future<int> get exitCode => _exitCode.future;

  @override
  Future<bool> terminate({required bool force}) async {
    killCount++;
    terminationForces.add(force);
    await terminationGate;
    if (throwOnFirstKill && killCount == 1) {
      throw StateError('first kill failed');
    }
    final result = _killResults?.removeAt(0) ?? killResult;
    if (result &&
        (force || !ignoreGracefulTermination) &&
        !_exitCode.isCompleted) {
      _exitCode.complete(-9);
    }
    return result;
  }

  void failExit(Object error) {
    if (!_exitCode.isCompleted) _exitCode.completeError(error);
  }

  @override
  Future<void> writeLine(String line) async {
    writtenLines.add(line);
    if (writeError case final error?) throw error;
  }
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

const _treeChildFixtureSource = r'''
import 'dart:async';
import 'dart:io';

Future<void> main(List<String> arguments) async {
  await File(arguments.single).writeAsString('$pid');
  Timer.periodic(const Duration(hours: 1), (_) {});
}
''';

Future<bool> _isWindowsPidRunning(int processId) async {
  final result = await Process.run(
    'tasklist',
    ['/FI', 'PID eq $processId', '/FO', 'CSV', '/NH'],
    runInShell: false,
  );
  return result.exitCode == 0 &&
      (result.stdout as String).contains('","$processId","');
}

Future<bool> _waitUntil(
  Future<bool> Function() condition, {
  bool expected = true,
  Duration timeout = const Duration(seconds: 3),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (await condition() == expected) return true;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  return await condition() == expected;
}

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
