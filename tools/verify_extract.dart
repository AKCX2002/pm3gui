import 'dart:io';
import 'package:pm3gui/parsers/output_parser.dart';

void main() {
  final sample = r"""
[usb|script] pm3 --> hf mf autopwn --1k

[!] Known key failed. Can't authenticate to block   0 key type A
[!] No known key was supplied, key recovery might fail
[+] loaded 5 user keys
[+] loaded 61 hardcoded keys
[=] Running strategy 1
[=] Running strategy 2
[=] .
[+] Target sector   2 key type A -- found valid key [ FFFFFFFFFFFF ] (used for nested / hardnested attack)
[+] Target sector   2 key type B -- found valid key [ FFFFFFFFFFFF ]
[+] Target sector   3 key type A -- found valid key [ FFFFFFFFFFFF ]
[+] Target sector   3 key type B -- found valid key [ FFFFFFFFFFFF ]
[+] Target sector   4 key type A -- found valid key [ FFFFFFFFFFFF ]
[+] Target sector   4 key type B -- found valid key [ FFFFFFFFFFFF ]
[+] Target sector   5 key type A -- found valid key [ FFFFFFFFFFFF ]
[+] Target sector   5 key type B -- found valid key [ FFFFFFFFFFFF ]
[+] Target sector   6 key type A -- found valid key [ FFFFFFFFFFFF ]
[+] Target sector   6 key type B -- found valid key [ FFFFFFFFFFFF ]
[+] Target sector   7 key type A -- found valid key [ FFFFFFFFFFFF ]
[+] Target sector   7 key type B -- found valid key [ FFFFFFFFFFFF ]
[+] Target sector   8 key type A -- found valid key [ FFFFFFFFFFFF ]
[+] Target sector   8 key type B -- found valid key [ FFFFFFFFFFFF ]
[+] Target sector  10 key type A -- found valid key [ FFFFFFFFFFFF ]
[+] Target sector  10 key type B -- found valid key [ FFFFFFFFFFFF ]
[+] Target sector  11 key type A -- found valid key [ FFFFFFFFFFFF ]
[+] Target sector  11 key type B -- found valid key [ FFFFFFFFFFFF ]
[+] Target sector  12 key type A -- found valid key [ FFFFFFFFFFFF ]
[+] Target sector  12 key type B -- found valid key [ FFFFFFFFFFFF ]
[+] Target sector  13 key type A -- found valid key [ FFFFFFFFFFFF ]
[+] Target sector  13 key type B -- found valid key [ FFFFFFFFFFFF ]
[+] Target sector  14 key type A -- found valid key [ FFFFFFFFFFFF ]
[+] Target sector  14 key type B -- found valid key [ FFFFFFFFFFFF ]
[+] Target sector  15 key type A -- found valid key [ FFFFFFFFFFFF ]
[+] Target sector  15 key type B -- found valid key [ FFFFFFFFFFFF ]
""";

  // First try extractKeys (expects table rows). Also try stripAnsi then extract.
  final keys = extractKeys(sample);
  stdout.writeln('extractKeys returned ${keys.length} entries');
  for (final k in keys) {
    stdout.writeln(
        'Sector ${k.sector}: keyA=${k.keyA} found=${k.keyAFound} keyB=${k.keyB} found=${k.keyBFound}');
  }

  final stripped = stripAnsi(sample);
  final keys2 = extractKeys(stripped);
  stdout.writeln('\nAfter stripAnsi: ${keys2.length} entries');
  for (final k in keys2) {
    stdout.writeln(
        'Sector ${k.sector}: keyA=${k.keyA} found=${k.keyAFound} keyB=${k.keyB} found=${k.keyBFound}');
  }
}
