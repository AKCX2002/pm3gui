// ignore_for_file: avoid_print

import 'dart:io';

void main() {
  final file = File('lib/services/pm3_commands.dart');
  if (!file.existsSync()) {
    stderr.writeln('pm3_commands.dart not found');
    exit(2);
  }
  final text = file.readAsStringSync();
  final classRegex = RegExp(r'class\s+(\w+)\s*\{', multiLine: true);
  final methodRegex = RegExp(r'static\s+String\s+(\w+)\s*\(', multiLine: true);

  final lines = <String>[];
  lines.add('Class,MethodCount,Methods');

  final classMatches = classRegex.allMatches(text).toList();
  for (var i = 0; i < classMatches.length; i++) {
    final className = classMatches[i].group(1)!;
    final start = classMatches[i].end;
    final end =
        (i + 1 < classMatches.length) ? classMatches[i + 1].start : text.length;
    final body = text.substring(start, end);
    final methods = methodRegex
        .allMatches(body)
        .map((m) => m.group(1))
        .where((s) => s != null)
        .cast<String>()
        .toList();
    final methodList = methods.join('|');
    lines.add('"$className",${methods.length},"$methodList"');
  }

  final outFile = File('docs/pm3_commands.csv');
  outFile.createSync(recursive: true);
  outFile.writeAsStringSync(lines.join('\n'));
  print('Wrote ${outFile.path} (${lines.length - 1} classes)');
}
