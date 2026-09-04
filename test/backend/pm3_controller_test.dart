import 'package:flutter_test/flutter_test.dart';
import 'package:pm3gui/backend/mock/mock_pm3_backend.dart';
import 'package:pm3gui/core/pm3/pm3_backend.dart';
import 'package:pm3gui/core/pm3/pm3_command.dart';
import 'package:pm3gui/core/pm3/pm3_connection.dart';
import 'package:pm3gui/core/pm3/pm3_controller.dart';
import 'package:pm3gui/core/pm3/pm3_event.dart';
import 'package:pm3gui/core/pm3/pm3_result.dart';

void main() {
  test('controller connects and returns a structured command result', () async {
    final backend = MockPm3Backend(responses: const {
      'hw.version': '[+] client: mock-v1',
    });
    final controller = Pm3Controller(backend);
    addTearDown(controller.dispose);

    final output = <String>[];
    final subscription = controller.outputLines.listen(output.add);
    addTearDown(subscription.cancel);

    final connected = await controller.connect(const Pm3ConnectionConfig(
      executable: 'proxmark3',
      port: 'mock',
    ));
    final result = await controller.execute(const Pm3Command(
      id: 'hw.version',
      executable: 'hw version',
    ));

    expect(connected, isTrue);
    expect(controller.state, Pm3ConnectionState.connected);
    expect(result.output, '[+] client: mock-v1');
    expect(output, ['[+] client: mock-v1']);
  });

  test('controller rejects commands while disconnected', () async {
    final controller = Pm3Controller(MockPm3Backend());
    addTearDown(controller.dispose);

    expect(
      controller.execute(const Pm3Command(
        id: 'hf.14a.reader',
        executable: 'hf 14a reader',
      )),
      throwsStateError,
    );
  });

  test('controller publishes command before backend execution', () async {
    var observed = false;
    final backend = _ObservingBackend(() => observed);
    final controller = Pm3Controller(backend);
    addTearDown(controller.dispose);

    final subscription = controller.commands.listen((_) => observed = true);
    addTearDown(subscription.cancel);

    await controller.execute(const Pm3Command(
      id: 'hw.version',
      executable: 'hw version',
    ));

    expect(backend.commandWasObservedAtExecution, isTrue);
  });
}

final class _ObservingBackend implements Pm3Backend {
  _ObservingBackend(this._wasCommandObserved);

  final bool Function() _wasCommandObserved;
  bool commandWasObservedAtExecution = false;

  @override
  Stream<Pm3Event> get events => const Stream.empty();

  @override
  Pm3ConnectionState get state => Pm3ConnectionState.connected;

  @override
  String get version => '';

  @override
  String get lastError => '';

  @override
  Future<void> connect(Pm3ConnectionConfig config) async {}

  @override
  Future<Pm3Result> execute(Pm3Command command, {Duration? timeout}) async {
    commandWasObservedAtExecution = _wasCommandObserved();
    return Pm3Result(
      command: command,
      output: '',
      startedAt: DateTime.now(),
      finishedAt: DateTime.now(),
    );
  }

  @override
  Future<void> cancel() async {}

  @override
  Future<void> disconnect() async {}

  @override
  void dispose() {}
}
