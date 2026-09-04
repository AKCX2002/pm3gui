/// Encodes desktop client arguments for the settings editor.
///
/// Each non-empty line is one argument. No shell-style tokenization or
/// unescaping is performed, so spaces, quotes and backslashes remain literal.
String encodePm3Arguments(Iterable<String> arguments) => arguments.join('\n');

List<String> decodePm3Arguments(String value) {
  if (value.isEmpty) return const [];
  final lines = value.split(RegExp(r'\r\n|\n|\r'));
  if (lines.isNotEmpty && lines.last.isEmpty) lines.removeLast();
  return List<String>.unmodifiable(lines.where((line) => line.isNotEmpty));
}
