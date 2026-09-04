/// Connection lifecycle exposed by every PM3 backend.
enum Pm3ConnectionState { disconnected, connecting, connected }

/// Platform-neutral configuration for launching the PM3 client.
final class Pm3ConnectionConfig {
  const Pm3ConnectionConfig({
    required this.executable,
    required this.port,
    this.arguments = const [],
    this.workingDirectory,
  });

  final String executable;
  final String port;
  final List<String> arguments;
  final String? workingDirectory;
}
