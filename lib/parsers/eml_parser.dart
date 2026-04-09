/// Parser for .eml (emulator) dump files.
///
/// EML format: one block per line, 32 hex chars or space-separated hex bytes.
/// Matches Proxmark3GUI/src/module/mifare.cpp file load logic.
library;

import 'dart:io';
import 'package:pm3gui/models/mifare_card.dart';

/// Parse an .eml file from disk.
Future<MifareCard> parseEmlFile(File file) async {
  final text = await file.readAsString();
  return parseEmlString(text);
}

/// Parse EML content from a string.
MifareCard parseEmlString(String text) {
  final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();

  if (lines.isEmpty) {
    throw FormatException('Empty EML file');
  }

  final blocks = <String>[];
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trim();
    // Remove spaces to normalize
    final hex = line.replaceAll(' ', '').toUpperCase();
    if (hex.length != 32 || !RegExp(r'^[0-9A-F]{32}$').hasMatch(hex)) {
      // Skip invalid lines (could be comments)
      continue;
    }
    blocks.add(hex);
  }

  if (blocks.isEmpty) {
    throw FormatException('No valid blocks found in EML file');
  }

  // Detect card type from block count
  final cardType = CardType.fromBlockCount(blocks.length);
  if (cardType == null) {
    throw FormatException(
        'Unexpected block count: ${blocks.length} (expected 20/64/128/256)');
  }

  final card = MifareCard(cardType: cardType);
  card.blocks = blocks;

  // Extract UID from block 0 (first 4 bytes for single-size UID)
  if (blocks.isNotEmpty && blocks[0].length == 32) {
    // Standard 4-byte UID: bytes 0-3
    card.uid = blocks[0].substring(0, 8);
    // ATQA: bytes 2 of manufacturer area (varies by card)
    // SAK is elsewhere in the real card, but for dump we approximate
  }

  // Extract keys from trailer blocks
  card.sectorKeys = List.generate(cardType.sectorCount, (_) => SectorKey());
  card.extractKeysFromBlocks();

  return card;
}

/// Export a MifareCard to EML format string.
String exportToEml(MifareCard card, {bool withSpaces = false}) {
  final buf = StringBuffer();
  for (var i = 0; i < card.blocks.length; i++) {
    final hex = card.blocks[i].toUpperCase();
    if (withSpaces) {
      final spaced =
          List.generate(16, (j) => hex.substring(j * 2, j * 2 + 2)).join(' ');
      buf.writeln(spaced);
    } else {
      buf.writeln(hex);
    }
  }
  return buf.toString();
}
