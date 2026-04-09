/// Output parser for PM3 CLI stdout.
///
/// Regex patterns mirror Proxmark3GUI/config/config_rrgv4.16717.json
/// for extracting UID, ATQA, SAK, keys, block data from command output.
library;

/// Client type detection (Official vs Iceman fork).
enum Pm3ClientType { unknown, official, iceman }

Pm3ClientType detectClientType(String output) {
  if (output.contains('[=]') ||
      output.contains('[+]') ||
      output.contains('[-]')) {
    return Pm3ClientType.iceman;
  }
  return Pm3ClientType.official;
}

/// Extract UID from `hf 14a info` / `hf 14a search` output.
String? extractUid(String output) {
  // Iceman format: "UID: XX XX XX XX" or "UID: XX XX XX XX XX XX XX"
  final match = RegExp(
    r'UID\s*[:：]\s*([0-9a-fA-F]{2}[\s]*)+',
    caseSensitive: false,
  ).firstMatch(output);
  if (match != null) {
    return match
        .group(0)!
        .replaceFirst(RegExp(r'UID\s*[:：]\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'[^0-9a-fA-F]'), '')
        .toUpperCase();
  }
  return null;
}

/// Extract ATQA from output.
String? extractAtqa(String output) {
  final match = RegExp(
    r'ATQA\s*[:：]\s*([0-9a-fA-F]{2}\s*){2}',
    caseSensitive: false,
  ).firstMatch(output);
  if (match != null) {
    return match
        .group(0)!
        .replaceFirst(RegExp(r'ATQA\s*[:：]\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'[^0-9a-fA-F]'), '')
        .toUpperCase();
  }
  return null;
}

/// Extract SAK from output.
String? extractSak(String output) {
  final match = RegExp(
    r'SAK\s*[:：]\s*([0-9a-fA-F]{2})',
    caseSensitive: false,
  ).firstMatch(output);
  if (match != null) {
    return match
        .group(0)!
        .replaceFirst(RegExp(r'SAK\s*[:：]\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'[^0-9a-fA-F]'), '')
        .toUpperCase();
  }
  return null;
}

/// Extract block data from output.
/// Matches: 16 hex bytes separated by spaces, e.g. "AA BB CC DD ..."
/// Returns list of 32-char hex strings.
List<String> extractBlockData(String output) {
  final pattern = RegExp(r'([0-9a-fA-F]{2}\s){15}[0-9a-fA-F]{2}');
  final matches = pattern.allMatches(output);
  return matches
      .map((m) => m.group(0)!.replaceAll(' ', '').toUpperCase())
      .toList();
}

/// Extract keys from nested/check/hardnested attack output.
///
/// Pattern from config: `\s*\d{3}\s*\|\s*\d{3}\s*\|\s*.+?\s*\|\s*.+?\s*\|\s*.+?\s*\|\s*.+?\s*$`
/// Columns: Sec | Blk | key A | res | key B | res
class ExtractedKey {
  final int sector;
  final String keyA;
  final String keyB;
  final bool keyAFound;
  final bool keyBFound;

  ExtractedKey({
    required this.sector,
    required this.keyA,
    required this.keyB,
    required this.keyAFound,
    required this.keyBFound,
  });
}

List<ExtractedKey> extractKeys(String output,
    {int keyAIndex = 2, int keyBIndex = 4}) {
  final pattern = RegExp(
      r'\s*(\d{3})\s*\|\s*(\d{3})\s*\|\s*(.+?)\s*\|\s*(.+?)\s*\|\s*(.+?)\s*\|\s*(.+?)\s*$',
      multiLine: true);

  final results = <ExtractedKey>[];
  for (final match in pattern.allMatches(output)) {
    final sector = int.tryParse(match.group(1)!) ?? 0;
    final cells = [
      match.group(1)!.trim(),
      match.group(2)!.trim(),
      match.group(3)!.trim(),
      match.group(4)!.trim(),
      match.group(5)!.trim(),
      match.group(6)!.trim(),
    ];

    final keyA = cells[keyAIndex].replaceAll('-', '').toUpperCase();
    final keyB = cells[keyBIndex].replaceAll('-', '').toUpperCase();
    final keyAFound = cells[keyAIndex + 1].trim() == '1';
    final keyBFound = cells[keyBIndex + 1].trim() == '1';

    results.add(ExtractedKey(
      sector: sector,
      keyA: keyA.length == 12 ? keyA : '',
      keyB: keyB.length == 12 ? keyB : '',
      keyAFound: keyAFound,
      keyBFound: keyBFound,
    ));
  }
  return results;
}

/// Check if output indicates a failure.
bool isCommandFailed(String output) {
  const failFlags = [
    'failed',
    'error',
    '[-]',
    'timeout',
    'no data',
    'can\'t select',
  ];
  final lower = output.toLowerCase();
  return failFlags.any((f) => lower.contains(f));
}

/// Check if output indicates success.
bool isCommandSuccess(String output) {
  const successFlags = ['[+]', 'done', 'saved'];
  final lower = output.toLowerCase();
  return successFlags.any((f) => lower.contains(f));
}

/// Strip ANSI color codes from pm3 output.
String stripAnsi(String text) {
  return text.replaceAll(RegExp(r'\x1B\[[0-9;]*[a-zA-Z]'), '');
}

/// Extract tag type from `hf 14a search` output.
String? extractTagType(String output) {
  // Look for "TYPE:" or card type descriptions
  final match = RegExp(
    r'TYPE\s*[:：]\s*(.+?)$',
    caseSensitive: false,
    multiLine: true,
  ).firstMatch(output);
  if (match != null && match.group(1) != null) {
    return match.group(1)!.trim();
  }
  return null;
}
