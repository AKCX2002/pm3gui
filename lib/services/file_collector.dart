/// Auto-collect & categorize PM3-generated dump/key files.
///
/// PM3 CLI creates files in its working directory with naming patterns:
///   hf-mf-{UID}-dump[-NNN].{bin|json|eml}
///   hf-mf-{UID}-key[-NNN].bin
///   lf-{type}-{ID}[-dump].bin
///   hf-iclass-{...}.bin
///   hf-mfdes-{...}.bin
///
/// This service scans for such files, groups them by UID/card, and
/// optionally moves them into a structured folder tree.
library;

import 'dart:io';
import 'package:path/path.dart' as p;

// ─── Data Models ─────────────────────────────────────────────────────────

enum CardFileType { dump, key, unknown }

enum FreqBand { hf, lf, unknown }

class CollectedFile {
  final String path;
  final String fileName;
  final FreqBand band;
  final String cardType; // e.g. "mf", "iclass", "mfdes", "em"
  final String uid;
  final CardFileType fileType;
  final String format; // e.g. "bin", "json", "eml"
  final int? sequence; // numbered suffix like -003
  final DateTime modified;
  final int sizeBytes;

  CollectedFile({
    required this.path,
    required this.fileName,
    required this.band,
    required this.cardType,
    required this.uid,
    required this.fileType,
    required this.format,
    this.sequence,
    required this.modified,
    required this.sizeBytes,
  });

  /// Human-readable label:  "HF Mifare A991A280 dump.bin"
  String get label {
    final bandStr = band == FreqBand.hf ? 'HF' : 'LF';
    final typeStr = _cardTypeName(cardType);
    final ftStr = fileType == CardFileType.dump
        ? 'dump'
        : fileType == CardFileType.key
            ? 'key'
            : '';
    final seq = sequence != null ? ' #$sequence' : '';
    return '$bandStr $typeStr $uid $ftStr.$format$seq';
  }

  /// Suggested subfolder: "hf-mf/A991A280/"
  String get suggestedSubdir => '$band-$cardType/${uid.toUpperCase()}/';

  static String _cardTypeName(String ct) {
    switch (ct) {
      case 'mf':
        return 'Mifare';
      case 'iclass':
        return 'iClass';
      case 'mfdes':
        return 'DESFire';
      case 'mfu':
        return 'Ultralight';
      case 'em':
        return 'EM4x';
      case 't55xx':
        return 'T55xx';
      default:
        return ct.toUpperCase();
    }
  }
}

class CardGroup {
  final String uid;
  final String cardType;
  final FreqBand band;
  final List<CollectedFile> files;

  CardGroup({
    required this.uid,
    required this.cardType,
    required this.band,
    List<CollectedFile>? files,
  }) : files = files ?? [];

  int get dumpCount =>
      files.where((f) => f.fileType == CardFileType.dump).length;
  int get keyCount => files.where((f) => f.fileType == CardFileType.key).length;
  String get label => '${band == FreqBand.hf ? 'HF' : 'LF'} '
      '${CollectedFile._cardTypeName(cardType)} '
      '${uid.toUpperCase()}';
}

// ─── Regex Patterns ─────────────────────────────────────────────────────

/// Matches PM3 output files:
///   hf-mf-A991A280-dump-001.bin
///   hf-mf-A991A280-key.bin
///   lf-em-12345678-dump.bin
final _pm3FilePattern = RegExp(
  r'^(hf|lf)-([a-z0-9]+)-([0-9A-Fa-f]+)-(dump|key)(?:-(\d{3}))?\.(\w+)$',
  caseSensitive: false,
);

/// Also match simple UID_UID.dump / .dump.bin patterns (like in the dump/ folder):
///   3BA66BB9_27A11580.dump
///   3BA66BB9_2C82A249.dump.bin
final _legacyDumpPattern = RegExp(
  r'^([0-9A-Fa-f]{8})_([0-9A-Fa-f]{8})\.(dump|dump\.bin|eml|json|bin)$',
  caseSensitive: false,
);

// ─── Core Scanner ───────────────────────────────────────────────────────

class FileCollector {
  /// Scan a list of directories for PM3-generated files.
  /// Returns all collected files, unsorted.
  static Future<List<CollectedFile>> scan(List<String> directories) async {
    final results = <CollectedFile>[];

    for (final dirPath in directories) {
      final dir = Directory(dirPath);
      if (!await dir.exists()) continue;

      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) continue;
        final file = entity;
        final name = p.basename(file.path);
        final parsed = _parseFileName(name);
        if (parsed == null) continue;

        final stat = await file.stat();
        results.add(CollectedFile(
          path: file.path,
          fileName: name,
          band: parsed.band,
          cardType: parsed.cardType,
          uid: parsed.uid.toUpperCase(),
          fileType: parsed.fileType,
          format: parsed.format,
          sequence: parsed.sequence,
          modified: stat.modified,
          sizeBytes: stat.size,
        ));
      }
    }

    // Sort: newest first
    results.sort((a, b) => b.modified.compareTo(a.modified));
    return results;
  }

  /// Group collected files by UID.
  static List<CardGroup> groupByCard(List<CollectedFile> files) {
    final map = <String, CardGroup>{};
    for (final f in files) {
      final key = '${f.band.name}-${f.cardType}-${f.uid}';
      map.putIfAbsent(
          key,
          () => CardGroup(
                uid: f.uid,
                cardType: f.cardType,
                band: f.band,
              ));
      map[key]!.files.add(f);
    }
    // Sort groups: most files first
    final groups = map.values.toList();
    groups.sort((a, b) => b.files.length.compareTo(a.files.length));
    return groups;
  }

  /// Move files into a structured folder:
  ///   baseDir/hf-mf/A991A280/hf-mf-A991A280-dump-001.bin
  static Future<int> organizeFiles(
    List<CollectedFile> files,
    String baseDir,
  ) async {
    int moved = 0;
    for (final f in files) {
      final destDir = Directory(p.join(baseDir, f.suggestedSubdir));
      if (!await destDir.exists()) {
        await destDir.create(recursive: true);
      }
      final destPath = p.join(destDir.path, f.fileName);
      if (destPath == f.path) continue; // already in place
      if (await File(destPath).exists()) continue; // don't overwrite

      try {
        await File(f.path).rename(destPath);
        moved++;
      } catch (_) {
        // Cross-device: copy + delete
        try {
          await File(f.path).copy(destPath);
          await File(f.path).delete();
          moved++;
        } catch (_) {
          // skip silently
        }
      }
    }
    return moved;
  }

  /// Get the typical PM3 working directories to scan.
  static List<String> defaultScanDirs(String pm3Path) {
    final dirs = <String>{};
    // 1. PM3 executable's parent folder
    final pm3Dir = File(pm3Path).parent.path;
    dirs.add(pm3Dir);
    // 2. Home directory (PM3 sometimes outputs here)
    final home = Platform.environment['HOME'] ?? '/root';
    dirs.add(home);
    // 3. Current working directory
    dirs.add(Directory.current.path);

    return dirs.toList();
  }
}

// ─── Internal Parser ────────────────────────────────────────────────────

class _ParsedName {
  final FreqBand band;
  final String cardType;
  final String uid;
  final CardFileType fileType;
  final String format;
  final int? sequence;

  _ParsedName({
    required this.band,
    required this.cardType,
    required this.uid,
    required this.fileType,
    required this.format,
    this.sequence,
  });
}

_ParsedName? _parseFileName(String name) {
  // Try standard PM3 pattern first
  final m = _pm3FilePattern.firstMatch(name);
  if (m != null) {
    return _ParsedName(
      band: m.group(1)!.toLowerCase() == 'hf' ? FreqBand.hf : FreqBand.lf,
      cardType: m.group(2)!.toLowerCase(),
      uid: m.group(3)!,
      fileType: m.group(4)!.toLowerCase() == 'dump'
          ? CardFileType.dump
          : CardFileType.key,
      format: m.group(6)!.toLowerCase(),
      sequence: m.group(5) != null ? int.tryParse(m.group(5)!) : null,
    );
  }

  // Try legacy pattern: UID_UID.dump
  final legacy = _legacyDumpPattern.firstMatch(name);
  if (legacy != null) {
    return _ParsedName(
      band: FreqBand.hf,
      cardType: 'mf',
      uid: legacy.group(2)!,
      fileType: CardFileType.dump,
      format: legacy.group(3)!.replaceAll('.', ''),
    );
  }

  return null;
}
