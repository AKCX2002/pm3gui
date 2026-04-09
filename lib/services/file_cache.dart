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
    if (stat.modified.isAfter(entry.directoryModified)) {
      _cache.remove(key);
      return null;
    }
    
    return entry.files;
  }
  
  /// 缓存文件列表
  /// [directory] - 目录路径
  /// [recursive] - 是否递归扫描
  /// [files] - 要缓存的文件列表
  static void cacheFiles(String directory, bool recursive, List<CollectedFile> files) {
    final key = _getCacheKey(directory, recursive);
    final dir = Directory(directory);
    final stat = dir.statSync();
    
    _cache[key] = _CacheEntry(
      files: files,
      timestamp: DateTime.now(),
      directoryModified: stat.modified,
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
}

class _CacheEntry {
  final List<CollectedFile> files;
  final DateTime timestamp;
  final DateTime directoryModified;
  
  _CacheEntry({
    required this.files,
    required this.timestamp,
    required this.directoryModified,
  });
}
