import 'pm3_connection.dart';

sealed class Pm3Event {
  const Pm3Event(this.timestamp);
  final DateTime timestamp;
}

final class Pm3OutputEvent extends Pm3Event {
  const Pm3OutputEvent(super.timestamp, this.line);
  final String line;
}

final class Pm3StateChangedEvent extends Pm3Event {
  const Pm3StateChangedEvent(super.timestamp, this.state);
  final Pm3ConnectionState state;
}
