/// Metadata for one locally recorded PM3 connection session.
final class Pm3Session {
  const Pm3Session({
    required this.directoryPath,
    required this.devicePort,
    required this.executable,
    required this.startedAt,
    this.endedAt,
  });

  final String directoryPath;
  final String devicePort;
  final String executable;
  final DateTime startedAt;
  final DateTime? endedAt;

  Pm3Session close(DateTime time) => Pm3Session(
        directoryPath: directoryPath,
        devicePort: devicePort,
        executable: executable,
        startedAt: startedAt,
        endedAt: time,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'devicePort': devicePort,
        'executable': executable,
        'startedAt': startedAt.toUtc().toIso8601String(),
        'endedAt': endedAt?.toUtc().toIso8601String(),
      };
}
