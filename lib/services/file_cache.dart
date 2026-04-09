/// 文件扫描缓存机制
library;

import 'dart:io';
import 'package:pm3gui/services/file_collector.dart';

class FileCache {
  static final Map<String, _CacheEntry> _cache = {};
  static const Duration _cacheDuration = Duration(minutes: 5);

  /// 获取缓存的文件列表
  /// [directory] - 目录路径
  /// [recursive] - 是否递归扫描
  /// [return] - 缓存的文件列表，如果缓存过期或不存在则返回 null
  static List<CollectedFile>? getCachedFiles(String directory, bool recursive) {
    final key = _getCacheKey(directory, recursive);
    final entry = _cache[key];

    if (entry == null) return null;

    if (DateTime.now().difference(entry.timestamp) > _cacheDuration) {
      _cache.remove(key);
      return null;
    }

    // 检查目录是否被修改
    final dir = Directory(directory);
    if (!dir.existsSync()) {
      _cache.remove(key);
      return null;
    }

    final stat = dir.statSync();
    final snapshot = _buildDirectorySnapshot(dir, recursive);
    if (stat.modified.isAfter(entry.directoryModified) ||
        snapshot != entry.directorySnapshot) {
      _cache.remove(key);
      return null;
    }

    return entry.files;
  }

  /// 缓存文件列表
  /// [directory] - 目录路径
  /// [recursive] - 是否递归扫描
  /// [files] - 要缓存的文件列表
  static void cacheFiles(
      String directory, bool recursive, List<CollectedFile> files) {
    final key = _getCacheKey(directory, recursive);
    final dir = Directory(directory);
    final stat = dir.statSync();
    final snapshot = _buildDirectorySnapshot(dir, recursive);

    _cache[key] = _CacheEntry(
      files: files,
      timestamp: DateTime.now(),
      directoryModified: stat.modified,
      directorySnapshot: snapshot,
    );

    // 清理过期缓存
    _cleanExpiredCache();
  }

  /// 清除所有缓存
  static void clearCache() {
    _cache.clear();
  }

  /// 清理过期缓存
  static void _cleanExpiredCache() {
    final now = DateTime.now();
    _cache.removeWhere((key, entry) {
      return now.difference(entry.timestamp) > _cacheDuration;
    });
  }

  /// 获取缓存键
  static String _getCacheKey(String directory, bool recursive) {
    return '$directory|$recursive';
  }

  /// 构建目录快照签名，用于检测目录内容变更。
  ///
  /// 注意：
  /// - 非递归模式：对当前目录下一层文件/文件夹做签名。
  /// - 递归模式：额外包含下一层子目录元信息，避免深层变更完全漏检。
  static String _buildDirectorySnapshot(Directory dir, bool recursive) {
    final entries = <String>[];
    try {
      for (final entity in dir.listSync(recursive: false, followLinks: false)) {
        final stat = entity.statSync();
        final name = entity.uri.pathSegments.isNotEmpty
            ? entity.uri.pathSegments.last
            : entity.path;

        if (entity is File) {
          entries.add(
              'F|$name|${stat.modified.millisecondsSinceEpoch}|${stat.size}');
        } else if (entity is Directory) {
          entries.add('D|$name|${stat.modified.millisecondsSinceEpoch}');

          if (recursive) {
            // 递归扫描时补充下一层子目录摘要，控制成本且提升变更感知。
            try {
              for (final child
                  in entity.listSync(recursive: false, followLinks: false)) {
                final cStat = child.statSync();
                final childName = child.uri.pathSegments.isNotEmpty
                    ? child.uri.pathSegments.last
                    : child.path;
                final prefix = child is File
                    ? 'CF'
                    : child is Directory
                        ? 'CD'
                        : 'CO';
                entries.add(
                    '$prefix|$name/$childName|${cStat.modified.millisecondsSinceEpoch}|${cStat.size}');
              }
            } catch (_) {
              // 忽略权限或竞争访问错误
            }
          }
        }
      }
    } catch (_) {
      // 若读取失败，返回目录 mtime 兜底签名
      final stat = dir.statSync();
      return 'fallback:${stat.modified.millisecondsSinceEpoch}';
    }

    entries.sort();
    return entries.join('||');
  }
}

class _CacheEntry {
  final List<CollectedFile> files;
  final DateTime timestamp;
  final DateTime directoryModified;
  final String directorySnapshot;

  _CacheEntry({
    required this.files,
    required this.timestamp,
    required this.directoryModified,
    required this.directorySnapshot,
  });
}
