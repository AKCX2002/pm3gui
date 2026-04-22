/// 自动收集和分类 PM3 生成的 dump/key 文件
///
/// PM3 命令行在其工作目录中创建具有以下命名模式的文件：
///   hf-mf-{UID}-dump[-NNN].{bin|json|eml}
///   hf-mf-{UID}-key[-NNN].bin
///   lf-{type}-{ID}[-dump].bin
///   hf-iclass-{...}.bin
///   hf-mfdes-{...}.bin
///
/// 此服务扫描此类文件，按 UID/卡片分组，并可选地将它们移动到结构化文件夹树中。
library;

import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:pm3gui/services/file_cache.dart';

// ─── Data Models ─────────────────────────────────────────────────────────

enum CardFileType { dump, key, unknown }

enum FreqBand { hf, lf, unknown }

class CollectedFile {
  final String path; // 文件路径
  final String fileName; // 文件名
  final FreqBand band; // 频段 (HF/LF)
  final String cardType; // 卡片类型，例如 "mf", "iclass", "mfdes", "em"
  final String uid; // 卡片UID
  final CardFileType fileType; // 文件类型 (dump/key)
  final String format; // 文件格式，例如 "bin", "json", "eml"
  final int? sequence; // 编号后缀，如 -003
  final DateTime modified; // 修改时间
  final int sizeBytes; // 文件大小（字节）

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

  /// 人类可读的标签："HF Mifare A991A280 dump.bin"
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

  /// 建议的子文件夹："hf-mf/A991A280/"
  String get suggestedSubdir => '${band.name}-$cardType/${uid.toUpperCase()}/';

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
  final String uid; // 卡片UID
  final String cardType; // 卡片类型
  final FreqBand band; // 频段 (HF/LF)
  final List<CollectedFile> files; // 该卡片的文件列表

  CardGroup({
    required this.uid,
    required this.cardType,
    required this.band,
    List<CollectedFile>? files,
  }) : files = files ?? [];

  /// 获取dump文件数量
  int get dumpCount =>
      files.where((f) => f.fileType == CardFileType.dump).length;

  /// 获取key文件数量
  int get keyCount => files.where((f) => f.fileType == CardFileType.key).length;

  /// 卡片组标签
  String get label => '${band == FreqBand.hf ? 'HF' : 'LF'} '
      '${CollectedFile._cardTypeName(cardType)} '
      '${uid.toUpperCase()}';
}

// ─── Regex Patterns ─────────────────────────────────────────────────────

/// 匹配 PM3 输出文件：
///   hf-mf-A991A280-dump-001.bin
///   hf-mf-A991A280-key.bin
///   lf-em-12345678-dump.bin
/// 说明：pattern 将 UID 约束为十六进制，以避免误将普通日志/临时文件识别为 dump。
final _pm3FilePattern = RegExp(
  r'^(hf|lf)-([a-z0-9]+)-([0-9A-Fa-f]+)-(dump|key)(?:-(\d{3}))?\.(\w+)$',
  caseSensitive: false,
);

/// 也匹配简单的 UID_UID.dump / .dump.bin 模式（如在 dump/ 文件夹中）：
///   3BA66BB9_27A11580.dump
///   3BA66BB9_2C82A249.dump.bin
final _legacyDumpPattern = RegExp(
  r'^([0-9A-Fa-f]{8})_([0-9A-Fa-f]{8})\.(dump|dump\.bin|eml|json|bin)$',
  caseSensitive: false,
);

// ─── Core Scanner ───────────────────────────────────────────────────────

class FileCollector {
  // 使用常量集合避免在扫描循环内重复分配 List。
  static const Set<String> _supportedExtensions = {
    '.bin',
    '.json',
    '.eml',
    '.dump',
    '.dic',
    '.keys.txt',
  };

  /// 扫描目录列表以查找PM3生成的文件
  ///
  /// [directories] - 要扫描的目录列表
  /// [recursive] - 是否递归扫描子目录（用于已组织的基础目录）
  /// [return] - 收集的文件列表，按修改时间降序排序
  static Future<List<CollectedFile>> scan(
    List<String> directories, {
    bool recursive = false,
  }) async {
    final results = <CollectedFile>[];
    final tasks = <Future<void>>[];

    for (final dirPath in directories) {
      tasks.add(_scanDirectory(dirPath, recursive, results));
    }

    await Future.wait(tasks);

    // 按修改时间降序排序：最新的文件在前
    results.sort((a, b) => b.modified.compareTo(a.modified));
    return results;
  }

  /// 扫描单个目录
  static Future<void> _scanDirectory(
      String dirPath, bool recursive, List<CollectedFile> results) async {
    // 检查缓存
    final cachedFiles = FileCache.getCachedFiles(dirPath, recursive);
    if (cachedFiles != null) {
      results.addAll(cachedFiles);
      return;
    }

    final dir = Directory(dirPath);
    if (!await dir.exists()) return;

    final directoryFiles = <CollectedFile>[];

    try {
      await for (final entity
          in dir.list(recursive: recursive, followLinks: false)) {
        if (entity is! File) continue;

        final file = entity;
        final name = p.basename(file.path);

        // 快速过滤：只处理常见的文件扩展名
        final ext = p.extension(name).toLowerCase();
        if (!_supportedExtensions.contains(ext)) {
          continue;
        }

        final parsed = _parseFileName(name);
        if (parsed == null) continue;

        final stat = await file.stat();
        final collectedFile = CollectedFile(
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
        );

        directoryFiles.add(collectedFile);
        results.add(collectedFile);
      }
    } catch (e) {
      // 忽略目录访问错误
    }

    // 缓存结果
    if (directoryFiles.isNotEmpty) {
      FileCache.cacheFiles(dirPath, recursive, directoryFiles);
    }
  }

  /// 按UID对收集的文件进行分组
  ///
  /// [files] - 要分组的文件列表
  /// [return] - 按文件数量降序排序的卡片组列表
  static List<CardGroup> groupByCard(List<CollectedFile> files) {
    final map = <String, CardGroup>{};

    for (final f in files) {
      // 使用频段、卡片类型和UID作为唯一键
      final key = '${f.band.name}-${f.cardType}-${f.uid}';

      // 如果键不存在，创建新的卡片组
      final group = map.putIfAbsent(
        key,
        () => CardGroup(
          uid: f.uid,
          cardType: f.cardType,
          band: f.band,
        ),
      );

      // 将文件添加到对应的卡片组
      group.files.add(f);
    }

    // 按文件数量降序排序：文件数最多的组在前
    final groups = map.values.toList();
    groups.sort((a, b) => b.files.length.compareTo(a.files.length));
    return groups;
  }

  /// 将文件移动到结构化文件夹：
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
      if (destPath == f.path) continue; // 已经在正确位置
      if (await File(destPath).exists()) continue; // 不覆盖已存在的文件

      try {
        await File(f.path).rename(destPath);
        moved++;
      } catch (_) {
        // 跨设备：复制 + 删除
        try {
          await File(f.path).copy(destPath);
          await File(f.path).delete();
          moved++;
        } catch (_) {
          // 静默跳过
        }
      }
    }
    return moved;
  }

  /// 获取典型的PM3工作目录以进行扫描
  static List<String> defaultScanDirs(String pm3Path) {
    final dirs = <String>{};
    // 1. PM3可执行文件的父文件夹
    final pm3Dir = File(pm3Path).parent.path;
    dirs.add(pm3Dir);
    // 2. 主目录（PM3有时会在这里输出）
    // Windows runner 一般使用 USERPROFILE；Linux/macOS 使用 HOME。
    final home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home != null && home.isNotEmpty) {
      dirs.add(home);
    }
    // 3. 当前工作目录
    dirs.add(Directory.current.path);

    return dirs.toList();
  }
}

// ─── Internal Parser ────────────────────────────────────────────────────

class _ParsedName {
  final FreqBand band; // 频段
  final String cardType; // 卡片类型
  final String uid; // UID
  final CardFileType fileType; // 文件类型
  final String format; // 文件格式
  final int? sequence; // 序列编号

  _ParsedName({
    required this.band,
    required this.cardType,
    required this.uid,
    required this.fileType,
    required this.format,
    this.sequence,
  });
}

/// 解析文件名，提取频段、卡片类型、UID等信息
_ParsedName? _parseFileName(String name) {
  // 首先尝试标准 PM3 模式
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

  // 尝试旧模式：UID_UID.dump
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
