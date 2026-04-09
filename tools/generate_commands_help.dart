// ignore_for_file: avoid_print

import 'dart:io';

void main(List<String> args) {
  // Support running from workspace root or pm3gui folder
  var csv = File('docs/pm3_commands.csv');
  if (!csv.existsSync()) {
    csv = File('pm3gui/docs/pm3_commands.csv');
  }
  if (!csv.existsSync()) {
    stderr.writeln(
        'docs/pm3_commands.csv not found. Run generate_commands_csv.dart first.');
    exit(2);
  }

  final lines = csv.readAsLinesSync();
  if (lines.isEmpty) {
    stderr.writeln('csv empty');
    exit(2);
  }

  final out = <String>[];
  out.add('classes:');

  for (var i = 1; i < lines.length; i++) {
    final line = lines[i];
    // CSV format: "Class",count,"method1|method2|..."
    final parts = _splitCsvLine(line);
    if (parts.length < 3) continue;
    final className = parts[0].replaceAll('"', '').trim();
    final methodCount = parts[1].trim();
    final methodsRaw = parts[2].replaceAll('"', '');
    final methods = methodsRaw.isEmpty ? <String>[] : methodsRaw.split('|');

    out.add('  - class: $className');
    out.add('    count: $methodCount');
    out.add('    methods:');
    for (final m in methods) {
      final method = m.trim();
      if (method.isEmpty) continue;
      out.add('      - name: $method');
      out.add('        description: ""');
      out.add('        params: []');
    }
  }

  final outFile = File('docs/pm3_commands_help.yaml');
  outFile.createSync(recursive: true);
  outFile.writeAsStringSync(out.join('\n'));
  print('Wrote ${outFile.path}');
}

List<String> _splitCsvLine(String line) {
  final parts = <String>[];
  var cur = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    if (c == '"') {
      inQuotes = !inQuotes;
      cur.write(c);
    } else if (c == ',' && !inQuotes) {
      parts.add(cur.toString());
      cur = StringBuffer();
    } else {
      cur.write(c);
    }
  }
  parts.add(cur.toString());
  return parts;
}
