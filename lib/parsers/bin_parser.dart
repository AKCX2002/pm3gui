/// Parser for .bin/.dump binary dump files.
///
/// Binary format: raw 16 bytes per block, no delimiters.
/// Matches Proxmark3GUI/src/module/mifare.cpp binary file load logic.
library;

import 'dart:io';
import 'dart:typed_data';
import 'package:pm3gui/models/mifare_card.dart';

/// Parse a binary dump file from disk.
Future<MifareCard> parseBinFile(File file) async {
  final bytes = await file.readAsBytes();
  return parseBinBytes(Uint8List.fromList(bytes));
}

/// Parse binary dump from raw bytes.
MifareCard parseBinBytes(Uint8List data) {
  if (data.length < 16) {
    throw FormatException('File too small for a card dump: ${data.length} bytes');
  }

  // Check if this is a key file (sector_count * 12 bytes for KeyA + KeyB)
  // or a full dump (block_count * 16 bytes)
  final isKeyFile = _isKeyFile(data.length);

  if (isKeyFile != null) {
    return _parseKeyFile(data, isKeyFile);
  }

  // Full dump: detect card type by total size
  final cardType = CardType.fromDumpLength(data.length);
  if (cardType == null) {
    // Try to use closest match
    final blocks = data.length ~/ 16;
    throw FormatException(
        'Unexpected dump size: ${data.length} bytes ($blocks blocks). '
        'Expected 320/1024/2048/4096 bytes.');
  }

  final card = MifareCard(cardType: cardType);
  card.blocks = List.generate(cardType.blockCount, (i) {
    return _bytesToHex(data, i * 16, 16);
  });

  // Extract UID from block 0
  if (card.blocks.isNotEmpty) {
    card.uid = card.blocks[0].substring(0, 8);
  }

  // Extract keys from trailer blocks
  card.sectorKeys = List.generate(cardType.sectorCount, (_) => SectorKey());
  card.extractKeysFromBlocks();

  return card;
}

/// Export MifareCard to binary format.
Uint8List exportToBin(MifareCard card) {
  final bytes = Uint8List(card.cardType.blockCount * 16);
  for (var i = 0; i < card.blocks.length; i++) {
    final hex = card.blocks[i];
    for (var j = 0; j < 16; j++) {
      bytes[i * 16 + j] =
          int.parse(hex.substring(j * 2, j * 2 + 2), radix: 16);
    }
  }
  return bytes;
}

/// Check if the data length matches a key-only file.
/// Key files: sectorCount * 12 bytes (6 for KeyA + 6 for KeyB) or
///            sectorCount * 14 bytes (6 KeyA + 2 separator + 6 KeyB)
CardType? _isKeyFile(int length) {
  // Check for sectorCount * 12
  for (final ct in [cardMini, card1K, card2K, card4K]) {
    if (length == ct.sectorCount * 12) return ct;
  }
  return null;
}

MifareCard _parseKeyFile(Uint8List data, CardType cardType) {
  final card = MifareCard(cardType: cardType);
  card.sectorKeys = List.generate(cardType.sectorCount, (s) {
    final offset = s * 12;
    return SectorKey(
      keyA: _bytesToHex(data, offset, 6),
      keyB: _bytesToHex(data, offset + 6, 6),
    );
  });
  return card;
}

String _bytesToHex(Uint8List data, int offset, int length) {
  final buf = StringBuffer();
  for (var i = 0; i < length && (offset + i) < data.length; i++) {
    buf.write(data[offset + i].toRadixString(16).padLeft(2, '0').toUpperCase());
  }
  return buf.toString();
}
