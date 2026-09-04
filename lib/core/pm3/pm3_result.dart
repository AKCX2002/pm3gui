import 'pm3_command.dart';

/// Completed output from a PM3 command.
final class Pm3Result {
  const Pm3Result({
    required this.command,
    required this.output,
    required this.startedAt,
    required this.finishedAt,
  });

  final Pm3Command command;
  final String output;
  final DateTime startedAt;
  final DateTime finishedAt;

  Duration get duration => finishedAt.difference(startedAt);
}
