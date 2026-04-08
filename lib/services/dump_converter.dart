/// Dump format converter — convert between bin/eml/json/key formats.
///
/// Supports:
///   .bin (full dump) ↔ .eml ↔ .json ↔ .bin (key only)
///   .dic (key dictionary) ← any dump or key file
///   Key extraction from any dump format
///   Key injection into any dump format
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:pm3gui/models/mifare_card.dart';
import 'package:pm3gui/parsers/dump_parser.dart';
import 'package:pm3gui/parsers/bin_parser.dart';
import 'package:pm3gui/parsers/eml_parser.dart';
import 'package:pm3gui/parsers/json_dump_parser.dart';
import 'package:pm3gui/parsers/key_parser.dart';

/// Supported file formats for conversion.
enum DumpFormat {
  bin('bin', '二进制转储 (.bin)', true),
  eml('eml', '文本转储 (.eml)', true),
  json('json', 'PM3 JSON (.json)', true),
  keyBin('key.bin', '二进制密钥 (.key.bin)', false),
  dic('dic', '密钥字典 (.dic)', false),
  keyTxt('keys.txt', '密钥列表 (.keys.txt)', false);

  final String ext;
  final String label;
  final bool isFullDump; // true = contains block data, false = keys only

  const DumpFormat(this.ext, this.label, this.isFullDump);
}

/// Result of a conversion operation.
class ConvertResult {
  final bool success;
  final String? error;

  /// Output file path (null if not written to disk).
  final String? outputPath;

  /// Key summary extracted during conversion.
  final String? keySummary;

  ConvertResult({
    required this.success,
    this.error,
    this.outputPath,
    this.keySummary,
  });
}

/// Convert a dump file from one format to another.
///
/// [inputPath] — path to source file
/// [outputPath] — where to write the converted output
/// [targetFormat] — desired output format
Future<ConvertResult> convertDumpFile({
  required String inputPath,
  required String outputPath,
  required DumpFormat targetFormat,
}) async {
  try {
    // ---- Parse input ----
    final inputFile = File(inputPath);
    if (!await inputFile.exists()) {
      return ConvertResult(success: false, error: '文件不存在: $inputPath');
    }

    final ext = inputPath.split('.').last.toLowerCase();
    MifareCard? card;
    List<SectorKey>? keysOnly;

    // Check if input is a key-only binary file
    if (ext == 'bin' || ext == 'dump') {
      final bytes = await inputFile.readAsBytes();
      final data = Uint8List.fromList(bytes);
      // Detect key-only vs full dump
      if (_isKeyBinSize(data.length)) {
        keysOnly = parseKeyBinBytes(data);
      } else {
        final result = await parseDumpFile(inputPath);
        if (!result.isSuccess) {
          return ConvertResult(success: false, error: result.error);
        }
        card = result.card;
      }
    } else if (ext == 'dic' || ext == 'txt') {
      // Text key dictionary
      final text = await inputFile.readAsString();
      final dictKeys = parseDicString(text);
      // Build keys-only structure (all sectors same key list)
      keysOnly = _dictKeysToSectorKeys(dictKeys);
    } else {
      // EML / JSON / other — full dump parse
      final result = await parseDumpFile(inputPath);
      if (!result.isSuccess) {
        return ConvertResult(success: false, error: result.error);
      }
      card = result.card;
    }

    // ---- Generate output ----
    final outFile = File(outputPath);

    switch (targetFormat) {
      case DumpFormat.bin:
        if (card == null) {
          return ConvertResult(success: false, error: '密钥文件无法转换为完整dump（缺少数据块）');
        }
        await outFile.writeAsBytes(exportToBin(card));

      case DumpFormat.eml:
        if (card == null) {
          return ConvertResult(success: false, error: '密钥文件无法转换为EML（缺少数据块）');
        }
        await outFile.writeAsString(exportToEml(card));

      case DumpFormat.json:
        if (card == null) {
          return ConvertResult(success: false, error: '密钥文件无法转换为JSON（缺少数据块）');
        }
        await outFile.writeAsString(exportToJson(card));

      case DumpFormat.keyBin:
        final keys = card?.sectorKeys ?? keysOnly;
        if (keys == null || keys.isEmpty) {
          return ConvertResult(success: false, error: '无密钥数据');
        }
        await outFile.writeAsBytes(exportKeysToBin(keys));

      case DumpFormat.dic:
        final keys = card?.sectorKeys ?? keysOnly;
        if (keys == null || keys.isEmpty) {
          return ConvertResult(success: false, error: '无密钥数据');
        }
        await outFile.writeAsString(exportToDic(keys));

      case DumpFormat.keyTxt:
        final keys = card?.sectorKeys ?? keysOnly;
        if (keys == null || keys.isEmpty) {
          return ConvertResult(success: false, error: '无密钥数据');
        }
        await outFile.writeAsString(exportKeysAsText(keys));
    }

    // Build key summary
    final keys = card?.sectorKeys ?? keysOnly;
    final summary = keys != null ? _buildKeySummary(keys) : null;

    return ConvertResult(
      success: true,
      outputPath: outputPath,
      keySummary: summary,
    );
  } catch (e) {
    return ConvertResult(success: false, error: '转换失败: $e');
  }
}

/// Extract keys from any supported dump file.
///
/// Returns (sectorKeys, keySummaryText) or throws on error.
Future<(List<SectorKey>, String)> extractKeysFromFile(String path) async {
  final file = File(path);
  if (!await file.exists()) throw Exception('文件不存在: $path');

  final ext = path.split('.').last.toLowerCase();

  // Try key-only binary first
  if (ext == 'bin' || ext == 'dump') {
    final bytes = await file.readAsBytes();
    final data = Uint8List.fromList(bytes);
    if (_isKeyBinSize(data.length)) {
      final keys = parseKeyBinBytes(data);
      return (keys, _buildKeySummary(keys));
    }
  }

  // Try text dictionary
  if (ext == 'dic' || ext == 'txt') {
    final text = await file.readAsString();
    final dictKeys = parseDicString(text);
    final keys = _dictKeysToSectorKeys(dictKeys);
    return (keys, '${dictKeys.length} 个唯一密钥');
  }

  // Full dump — parse and extract
  final result = await parseDumpFile(path);
  if (!result.isSuccess) throw Exception(result.error);
  final keys = result.card.sectorKeys;
  return (keys, _buildKeySummary(keys));
}

/// Write keys to a file in the requested format.
Future<void> saveKeysToFile(
    List<SectorKey> keys, String path, DumpFormat fmt) async {
  switch (fmt) {
    case DumpFormat.keyBin:
      await File(path).writeAsBytes(exportKeysToBin(keys));
    case DumpFormat.dic:
      await File(path).writeAsString(exportToDic(keys));
    case DumpFormat.keyTxt:
      await File(path).writeAsString(exportKeysAsText(keys));
    default:
      throw ArgumentError('不支持的密钥导出格式: ${fmt.label}');
  }
}

// ---------------------------------------------------------------------------
//  Allowed conversion matrix
// ---------------------------------------------------------------------------

/// Return a list of formats the source format can convert to.
List<DumpFormat> allowedTargets(String sourceExt) {
  final e = sourceExt.toLowerCase();
  // Full dump formats can convert to anything
  if (['eml', 'json'].contains(e)) {
    return DumpFormat.values.toList();
  }
  // Bin could be full dump or keys — allow all targets
  if (['bin', 'dump'].contains(e)) {
    return DumpFormat.values.toList();
  }
  // Key-only formats can only produce other key formats
  if (['dic', 'txt'].contains(e)) {
    return [DumpFormat.keyBin, DumpFormat.dic, DumpFormat.keyTxt];
  }
  return DumpFormat.values.toList();
}

// ---------------------------------------------------------------------------
//  Helpers
// ---------------------------------------------------------------------------

bool _isKeyBinSize(int bytes) {
  for (final c in [cardMini, card1K, card2K, card4K]) {
    if (bytes == c.sectorCount * 12) return true;
  }
  return false;
}

List<SectorKey> _dictKeysToSectorKeys(List<String> dictKeys) {
  // Default: fill 16 sectors (1K) with first available key
  final kA = dictKeys.isNotEmpty ? dictKeys[0] : 'FFFFFFFFFFFF';
  final kB = dictKeys.length > 1 ? dictKeys[1] : kA;
  return List.generate(16, (_) => SectorKey(keyA: kA, keyB: kB));
}

String _buildKeySummary(List<SectorKey> keys) {
  final uniqueA = keys.map((k) => k.keyA.toUpperCase()).toSet();
  final uniqueB = keys.map((k) => k.keyB.toUpperCase()).toSet();
  final allKeys = {...uniqueA, ...uniqueB};
  return '${keys.length} 扇区, '
      '${uniqueA.length} 种 KeyA, '
      '${uniqueB.length} 种 KeyB, '
      '共 ${allKeys.length} 种唯一密钥';
}
