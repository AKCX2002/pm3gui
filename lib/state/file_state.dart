/// 文件管理状态
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:pm3gui/services/file_collector.dart';

class FileState extends ChangeNotifier {
  List<CollectedFile> collectedFiles = [];
  List<CardGroup> cardGroups = [];
  bool isScanning = false;
  String? collectBaseDir;

  /// 扫描 PM3 工作目录，收集 dump / key 文件
  Future<void> scanForFiles(String pm3Path) async {
    if (isScanning) return;

    isScanning = true;
    notifyListeners();

    try {
      // 在 isolate 中执行文件扫描，避免阻塞主线程
      final result = await compute(_scanFilesInIsolate, {
        'pm3Path': pm3Path,
        'collectBaseDir': collectBaseDir,
      });

      collectedFiles = result['files'] as List<CollectedFile>;
      cardGroups = result['groups'] as List<CardGroup>;
    } catch (e) {
      // 记录扫描错误
    }

    isScanning = false;
    notifyListeners();
  }

  /// 在 isolate 中执行文件扫描
  static Future<Map<String, dynamic>> _scanFilesInIsolate(
      Map<String, dynamic> params) async {
    final pm3Path = params['pm3Path'] as String;
    final collectBaseDir = params['collectBaseDir'] as String?;

    final dirs = FileCollector.defaultScanDirs(pm3Path);
    final files = await FileCollector.scan(dirs);

    List<CollectedFile> organizedFiles = [];
    if (collectBaseDir != null) {
      organizedFiles = await FileCollector.scan(
        [collectBaseDir],
        recursive: true,
      );
    }

    final seen = <String>{};
    final allFiles =
        [...files, ...organizedFiles].where((f) => seen.add(f.path)).toList();
    final groups = FileCollector.groupByCard(allFiles);

    return {
      'files': allFiles,
      'groups': groups,
    };
  }

  /// 将已收集的文件整理归类到指定目录
  Future<int> organizeCollectedFiles(String baseDir) async {
    collectBaseDir = baseDir;
    final count = await FileCollector.organizeFiles(collectedFiles, baseDir);
    await scanForFiles('');
    return count;
  }

  void setCollectBaseDir(String? baseDir) {
    collectBaseDir =
        (baseDir != null && baseDir.trim().isNotEmpty) ? baseDir : null;
    notifyListeners();
  }
}
