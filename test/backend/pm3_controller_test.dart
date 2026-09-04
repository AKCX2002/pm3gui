import 'package:flutter_test/flutter_test.dart';
import 'package:pm3gui/backend/mock/mock_pm3_backend.dart';
import 'package:pm3gui/core/pm3/pm3_command.dart';
import 'package:pm3gui/core/pm3/pm3_connection.dart';
import 'package:pm3gui/core/pm3/pm3_controller.dart';

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
}
