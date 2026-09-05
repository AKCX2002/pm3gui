// Refresh terminal command suggestions from an installed client's help tree.
// Usage: dart run tools/sync_command_catalog.dart <pm3.bat|proxmark3> [port]
import 'dart:convert';
import 'dart:io';

import 'package:pm3gui/backend/desktop_cli/pm3_process.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty || args.length > 2) {
    stderr.writeln('Usage: dart run tools/sync_command_catalog.dart <client> [port]');
    exitCode = 2;
    return;
  }
  final process = Pm3Process();
  var currentGroup = 'connection';
  try {
    if (!await process.connect(args.first, args.length == 2 ? args[1] : '')) {
      throw StateError(process.lastError);
    }
    final version = await process.sendCommandAndWait('hw version',
        timeout: const Duration(seconds: 20));
    final groups = <String>[''];
    final visited = <String>{};
    final commands = <String, String>{};
    final row = RegExp(r'^([a-z0-9][a-z0-9_]*)\s{2,}(.+)$');
    for (var i = 0; i < groups.length; i++) {
      final group = groups[i];
      currentGroup = group;
      if (!visited.add(group)) continue;
      final output = await process.sendCommandAndWait(
        group.isEmpty ? 'help' : '$group help',
        timeout: const Duration(seconds: 20),
      );
      var found = 0;
      for (final line in const LineSplitter().convert(output)) {
        final match = row.firstMatch(line.trimRight());
        if (match == null) continue;
        found++;
        final name = [if (group.isNotEmpty) group, match[1]!].join(' ');
        final description = match[2]!;
        commands[name] = description;
        if (description.startsWith('{')) groups.add(name);
      }
      // Some brace-labelled entries (e.g. reveng) take flags rather than subcommands.
      // Keep that entry itself; only table rows establish additional command paths.
      if (found == 0 && group.isEmpty) {
        throw StateError('No top-level help entries; snapshot unchanged');
      }
    }
    final ordered = commands.keys.toList()..sort();
    final snapshot = {
      'source': 'Installed Proxmark3 client help; available commands for the connected device',
      'clientVersion': version.split('\n').map((s) => s.trim()).where(
          (s) => s.startsWith('Iceman/') || s.startsWith('RRG/')).firstOrNull ?? 'unknown',
      'commands': [for (final command in ordered)
        {'command': command, 'description': commands[command]}],
    };
    final destination = File('docs/pm3_commands_client.json');
    final temporary = File('${destination.path}.tmp');
    await temporary.writeAsString('${const JsonEncoder.withIndent('  ').convert(snapshot)}\n');
    await temporary.rename(destination.path);
    stdout.writeln('Synced ${commands.length} commands from ${visited.length} help groups.');
  } catch (error) {
    stderr.writeln('Help group "$currentGroup": $error; ${process.lastError}');
    exitCode = 1;
  } finally {
    await process.shutdown();
  }
}
