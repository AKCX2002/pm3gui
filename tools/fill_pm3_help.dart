import 'dart:convert';
import 'dart:io';

void main(List<String> args) async {
  final pm3Path = args.isNotEmpty ? args.first : '/root/dev/proxmark3/pm3';

  final commandsFile = _resolveExisting([
    'lib/services/pm3_commands.dart',
    'pm3gui/lib/services/pm3_commands.dart',
  ]);
  final outputFile = _resolvePreferred([
    'docs/pm3_commands_help.yaml',
    'pm3gui/docs/pm3_commands_help.yaml',
  ]);

  if (commandsFile == null) {
    stderr.writeln('Cannot find pm3_commands.dart');
    exit(2);
  }
  if (!File(pm3Path).existsSync()) {
    stderr.writeln('pm3 executable not found: $pm3Path');
    exit(2);
  }

  final source = File(commandsFile).readAsStringSync();
  final classMethods = _extractClassMethods(source);

  final pathCache = <String, HelpInfo>{};
  final out = StringBuffer();
  out.writeln('classes:');

  var totalMethods = 0;
  var foundMethods = 0;

  for (final entry in classMethods.entries) {
    final className = entry.key;
    final methods = entry.value;
    out.writeln('  - class: ${_yaml(className)}');
    out.writeln('    count: ${methods.length}');
    out.writeln('    methods:');

    for (final m in methods) {
      totalMethods++;
      final cmdPath = _commandPath(m.commandTemplate);
      HelpInfo info;
      if (cmdPath.isEmpty) {
        info = HelpInfo.empty('No command template extracted');
      } else {
        info = pathCache[cmdPath] ?? await _queryHelp(pm3Path, cmdPath);
        pathCache[cmdPath] = info;
      }

      if (info.description.isNotEmpty) foundMethods++;

      out.writeln('      - name: ${_yaml(m.name)}');
      out.writeln('        command: ${_yaml(cmdPath)}');
      out.writeln('        description: ${_yaml(info.description)}');
      out.writeln('        params:');
      if (info.params.isEmpty) {
        out.writeln('          []');
      } else {
        for (final p in info.params) {
          out.writeln('          - ${_yaml(p)}');
        }
      }
      if (info.source.isNotEmpty) {
        out.writeln('        help_source: ${_yaml(info.source)}');
      }
    }
  }

  File(outputFile).createSync(recursive: true);
  File(outputFile).writeAsStringSync(out.toString());

  stdout.writeln('Wrote: $outputFile');
  stdout.writeln('Methods: $totalMethods, with description: $foundMethods');
  stdout.writeln('Unique command paths queried: ${pathCache.length}');
}

String? _resolveExisting(List<String> candidates) {
  for (final c in candidates) {
    if (File(c).existsSync()) return c;
  }
  return null;
}

String _resolvePreferred(List<String> candidates) {
  for (final c in candidates) {
    final parent = File(c).parent;
    if (parent.existsSync()) return c;
  }
  return candidates.first;
}

class MethodEntry {
  final String name;
  final String commandTemplate;
  MethodEntry(this.name, this.commandTemplate);
}

Map<String, List<MethodEntry>> _extractClassMethods(String source) {
  final classes = <String, List<MethodEntry>>{};
  final classRegex = RegExp(r'class\s+(\w+)\s*\{', multiLine: true);
  final matches = classRegex.allMatches(source).toList();

  for (var i = 0; i < matches.length; i++) {
    final className = matches[i].group(1)!;
    final start = matches[i].end;
    final end = i + 1 < matches.length ? matches[i + 1].start : source.length;
    final body = source.substring(start, end);

    final list = <MethodEntry>[];

    // Arrow functions: static String x(...) => 'cmd ...';
    final arrow = RegExp(r"static\s+String\s+(\w+)\s*\([^)]*\)\s*=>\s*'([^']*)';", multiLine: true);
    for (final m in arrow.allMatches(body)) {
      list.add(MethodEntry(m.group(1)!, m.group(2)!));
    }

    // Block functions: try to capture StringBuffer('...') first, otherwise return '...';
    final block = RegExp(r'static\s+String\s+(\w+)\s*\([^)]*\)\s*\{([\s\S]*?)\n\s*\}', multiLine: true);
    for (final bm in block.allMatches(body)) {
      final methodName = bm.group(1)!;
      final methodBody = bm.group(2)!;
      if (list.any((e) => e.name == methodName)) continue;

      final sb = RegExp(r"StringBuffer\('([^']*)'\)").firstMatch(methodBody);
      if (sb != null) {
        list.add(MethodEntry(methodName, sb.group(1)!));
        continue;
      }
      final ret = RegExp(r"return\s+'([^']*)';").firstMatch(methodBody);
      if (ret != null) {
        list.add(MethodEntry(methodName, ret.group(1)!));
      } else {
        list.add(MethodEntry(methodName, ''));
      }
    }

    classes[className] = list;
  }

  return classes;
}

String _commandPath(String template) {
  if (template.trim().isEmpty) return '';
  final tokens = template.trim().split(RegExp(r'\s+'));
  final out = <String>[];
  for (final t in tokens) {
    if (t.startsWith('-')) break;
    if (t.contains(r'$') || t.contains('{') || t.contains('}')) break;
    out.add(t);
  }
  return out.join(' ');
}

class HelpInfo {
  final String description;
  final List<String> params;
  final String source;

  HelpInfo(this.description, this.params, this.source);
  factory HelpInfo.empty(String source) => HelpInfo('', const [], source);
}

Future<HelpInfo> _queryHelp(String pm3Path, String cmdPath) async {
  final attempts = <List<String>>[
    ['-o', '-c', '$cmdPath -h'],
    ['-o', '-c', '$cmdPath --help'],
    ['-o', '-c', '$cmdPath help'],
  ];

  for (final a in attempts) {
    final res = await Process.run(pm3Path, a);
    final output = '${res.stdout}\n${res.stderr}';
    final parsed = _parseHelpOutput(output, cmdPath);
    if (parsed != null) {
      return HelpInfo(parsed.$1, parsed.$2, a.join(' '));
    }
  }

  // fallback: parent help list lookup
  final tokens = cmdPath.split(' ');
  if (tokens.length > 1) {
    final parent = tokens.sublist(0, tokens.length - 1).join(' ');
    final leaf = tokens.last;
    final res = await Process.run(pm3Path, ['-o', '-c', '$parent help']);
    final output = '${res.stdout}\n${res.stderr}';
    final line = _findSubcommandLine(output, leaf);
    if (line != null) {
      final desc = line.replaceFirst(RegExp('^$leaf\\s+'), '').trim();
      return HelpInfo(desc, const [], '-o -c "$parent help"');
    }
  }

  return HelpInfo.empty('not found');
}

(String, List<String>)? _parseHelpOutput(String raw, String cmdPath) {
  final clean = _clean(raw);
  if (clean.isEmpty) return null;

  final lines = const LineSplitter().convert(clean);
  if (lines.any((l) => l.contains('command not found') || l.contains('Unknown command'))) {
    return null;
  }

  String desc = '';
  final usageLine = lines.firstWhere(
    (l) => l.toLowerCase().trimLeft().startsWith('usage:'),
    orElse: () => '',
  );
  if (usageLine.isNotEmpty) {
    desc = usageLine.trim();
  } else {
    final candidate = lines.firstWhere(
      (l) {
        final t = l.trim();
        if (t.isEmpty) return false;
        if (t.startsWith('[')) return false;
        if (t.startsWith('help')) return false;
        if (t.startsWith('--------')) return false;
        if (t.toLowerCase().startsWith('samples:')) return false;
        return true;
      },
      orElse: () => '',
    );
    desc = candidate.trim();
  }

  final params = <String>[];
  final optRegex = RegExp(r'^\s*(-{1,2}[\w][^\n]*)$');
  for (final l in lines) {
    final m = optRegex.firstMatch(l);
    if (m != null) {
      final v = m.group(1)!.trim();
      if (!params.contains(v)) params.add(v);
    }
  }

  if (desc.isEmpty && params.isEmpty) {
    // sometimes help list format with cmd + description
    final leaf = cmdPath.split(' ').last;
    final line = _findSubcommandLine(clean, leaf);
    if (line != null) {
      desc = line.replaceFirst(RegExp('^$leaf\\s+'), '').trim();
    }
  }

  if (desc.isEmpty && params.isEmpty) return null;
  return (desc, params);
}

String? _findSubcommandLine(String output, String leaf) {
  final lines = const LineSplitter().convert(_clean(output));
  for (final l in lines) {
    final t = l.trim();
    if (t.startsWith('$leaf ') || t == leaf) {
      return t;
    }
  }
  return null;
}

String _clean(String s) {
  final ansi = RegExp(r'\x1B\[[0-9;]*m');
  return s
      .replaceAll(ansi, '')
      .replaceAll('\r', '')
      .split('\n')
      .where((l) => !l.contains('Session log') && !l.contains('loaded `') && !l.contains('OFFLINE mode') && !l.contains('execute command from commandline:') && !l.contains('pm3 -->'))
      .join('\n')
      .trim();
}

String _yaml(String s) {
  final escaped = s.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
  return '"$escaped"';
}
