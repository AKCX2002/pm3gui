/// Parser for .json dump files (PM3 Jansson schema).
///
/// JSON schema follows the PM3 client fileutils.c JsonSave/prepareJSON format:
///   $.FileType  - "mfc" for Mifare Classic
///   $.Card.UID  - hex compact UID
///   $.Card.ATQA - 2-byte ATQA
///   $.Card.SAK  - 1-byte SAK
///   $.SectorKeys.N.KeyA  - sector N key A (hex)
///   $.SectorKeys.N.KeyB  - sector N key B (hex)
///   $.blocks.N  - block N data (hex compact)
library;

import 'dart:convert';
import 'dart:io';

import 'package:pm3gui/models/mifare_card.dart';

/// Parse a JSON dump file from disk.
Future<MifareCard> parseJsonDumpFile(File file) async {
  final text = await file.readAsString();
  return parseJsonDumpString(text);
}

/// Parse JSON dump from string content.
MifareCard parseJsonDumpString(String text) {
  final json = jsonDecode(text) as Map<String, dynamic>;

  // Detect card info
  final fileType = (json['FileType'] ?? '') as String;
  if (fileType.isNotEmpty && fileType != 'mfc') {
    // Could still parse but warn
  }

  // Read blocks
  final blocksMap = json['blocks'] as Map<String, dynamic>?;
  int blockCount = 0;
  final blockData = <int, String>{};

  if (blocksMap != null) {
    for (final entry in blocksMap.entries) {
      final idx = int.tryParse(entry.key);
      if (idx != null && entry.value is String) {
        blockData[idx] = (entry.value as String).toUpperCase();
        if (idx + 1 > blockCount) blockCount = idx + 1;
      }
    }
  }

  // Detect card type
  CardType cardType;
  final ct = CardType.fromBlockCount(blockCount);
  if (ct != null) {
    cardType = ct;
  } else {
    // Fallback: try Card.size or default to 1K
    cardType = card1K;
    blockCount = card1K.blockCount;
  }

  final card = MifareCard(cardType: cardType);

  // Fill blocks
  card.blocks = List.generate(cardType.blockCount, (i) {
    return blockData[i] ?? ('0' * 32);
  });

  // Card metadata
  final cardInfo = json['Card'] as Map<String, dynamic>?;
  if (cardInfo != null) {
    card.uid = ((cardInfo['UID'] ?? '') as String).toUpperCase();
    card.atqa = ((cardInfo['ATQA'] ?? '') as String).toUpperCase();
    card.sak = ((cardInfo['SAK'] ?? '') as String).toUpperCase();
  }

  // Sector keys
  final keysMap = json['SectorKeys'] as Map<String, dynamic>?;
  card.sectorKeys = List.generate(cardType.sectorCount, (_) => SectorKey());

  if (keysMap != null) {
    for (final entry in keysMap.entries) {
      final idx = int.tryParse(entry.key);
      if (idx != null && idx < cardType.sectorCount && entry.value is Map) {
        final keyMap = entry.value as Map<String, dynamic>;
        if (keyMap['KeyA'] is String) {
          card.sectorKeys[idx].keyA = (keyMap['KeyA'] as String).toUpperCase();
        }
        if (keyMap['KeyB'] is String) {
          card.sectorKeys[idx].keyB = (keyMap['KeyB'] as String).toUpperCase();
        }
      }
    }
  } else {
    // Extract keys from trailer blocks as fallback
    card.extractKeysFromBlocks();
  }

  return card;
}

/// Export MifareCard to JSON format string (PM3-compatible).
String exportToJson(MifareCard card) {
  final blocks = <String, String>{};
  for (var i = 0; i < card.blocks.length; i++) {
    blocks[i.toString()] = card.blocks[i].toUpperCase();
  }

  final sectorKeys = <String, Map<String, String>>{};
  for (var i = 0; i < card.sectorKeys.length; i++) {
    sectorKeys[i.toString()] = {
      'KeyA': card.sectorKeys[i].keyA.toUpperCase(),
      'KeyB': card.sectorKeys[i].keyB.toUpperCase(),
    };
  }

  final json = {
    'Created': 'PM3GUI Flutter',
    'FileType': 'mfc',
    'Card': {
      'UID': card.uid.toUpperCase(),
      'ATQA': card.atqa.toUpperCase(),
      'SAK': card.sak.toUpperCase(),
    },
    'blocks': blocks,
    'SectorKeys': sectorKeys,
  };

  return const JsonEncoder.withIndent('  ').convert(json);
}
