/// A typed command understood by the official Proxmark3 client.
final class Pm3Command {
  const Pm3Command({required this.id, required this.executable});

  final String id;
  final String executable;
}
