import 'pm3_command.dart';
import 'pm3_connection.dart';
import 'pm3_event.dart';
import 'pm3_result.dart';

abstract interface class Pm3Backend {
  Stream<Pm3Event> get events;
  Pm3ConnectionState get state;
  String get version;
  String get lastError;

  Future<void> connect(Pm3ConnectionConfig config);
  Future<void> disconnect();
  Future<Pm3Result> execute(Pm3Command command, {Duration? timeout});
  Future<void> cancel();
  void dispose();
}
