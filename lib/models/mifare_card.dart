/// Mifare Classic card data model.
///
/// Mirrors the card type definitions from Proxmark3GUI/src/module/mifare.h:
/// card_mini (5 sectors, 20 blocks), card_1k (16/64), card_2k (32/128), card_4k (40/256).
library;

import 'dart:typed_data';

// ---------------------------------------------------------------------------
// Card type definitions
// ---------------------------------------------------------------------------

enum MifareSize { mini, s1k, s2k, s4k }

class CardType {
  final MifareSize size;
  final int sectorCount;
  final int blockCount;

  /// Number of blocks per sector (4 for standard, 16 for 4K upper sectors).
  final List<int> blocksPerSector;

  /// First block index of each sector.
  final List<int> sectorFirstBlock;

  final String label;

  const CardType({
    required this.size,
    required this.sectorCount,
    required this.blockCount,
    required this.blocksPerSector,
    required this.sectorFirstBlock,
    required this.label,
  });

  /// The trailer (last) block index for a given sector.
  int trailerBlock(int sector) =>
      sectorFirstBlock[sector] + blocksPerSector[sector] - 1;

  /// Detect card type from total byte length of a dump.
  static CardType? fromDumpLength(int bytes) {
    final blocks = bytes ~/ 16;
    if (blocks == 20) return cardMini;
    if (blocks == 64) return card1K;
    if (blocks == 128) return card2K;
    if (blocks == 256) return card4K;
    return null;
  }

  static CardType? fromBlockCount(int blocks) {
    if (blocks == 20) return cardMini;
    if (blocks == 64) return card1K;
    if (blocks == 128) return card2K;
    if (blocks == 256) return card4K;
    return null;
  }
}

// Matches Proxmark3GUI mifare.cpp card definitions exactly
const CardType cardMini = CardType(
  size: MifareSize.mini,
  sectorCount: 5,
  blockCount: 20,
  blocksPerSector: [4, 4, 4, 4, 4],
  sectorFirstBlock: [0, 4, 8, 12, 16],
  label: 'MINI',
);

const CardType card1K = CardType(
  size: MifareSize.s1k,
  sectorCount: 16,
  blockCount: 64,
  blocksPerSector: [4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4],
  sectorFirstBlock: [
    0, 4, 8, 12, 16, 20, 24, 28,
    32, 36, 40, 44, 48, 52, 56, 60
  ],
  label: '1K',
);

const CardType card2K = CardType(
  size: MifareSize.s2k,
  sectorCount: 32,
  blockCount: 128,
  blocksPerSector: [
    4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4,
    4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4,
  ],
  sectorFirstBlock: [
    0, 4, 8, 12, 16, 20, 24, 28,
    32, 36, 40, 44, 48, 52, 56, 60,
    64, 68, 72, 76, 80, 84, 88, 92,
    96, 100, 104, 108, 112, 116, 120, 124,
  ],
  label: '2K',
);

const CardType card4K = CardType(
  size: MifareSize.s4k,
  sectorCount: 40,
  blockCount: 256,
  blocksPerSector: [
    4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4,
    4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4,
    16, 16, 16, 16, 16, 16, 16, 16,
  ],
  sectorFirstBlock: [
    0, 4, 8, 12, 16, 20, 24, 28,
    32, 36, 40, 44, 48, 52, 56, 60,
    64, 68, 72, 76, 80, 84, 88, 92,
    96, 100, 104, 108, 112, 116, 120, 124,
    128, 144, 160, 176, 192, 208, 224, 240,
  ],
  label: '4K',
);

// ---------------------------------------------------------------------------
// Access conditions (from mifare.cpp dataCondition / trailerCondition tables)
// ---------------------------------------------------------------------------

enum AccessType { never, keyA, keyB, keyAB }

/// Data block access conditions indexed by C1C2C3 value (0-7).
/// Columns: [read, write, increment, decrement/transfer/restore]
const List<List<AccessType>> dataAccessConditions = [
  [AccessType.keyAB, AccessType.keyAB, AccessType.keyAB, AccessType.keyAB], // 0
  [AccessType.keyAB, AccessType.keyB, AccessType.never, AccessType.never], // 1
  [AccessType.keyAB, AccessType.never, AccessType.never, AccessType.never], // 2
  [AccessType.keyAB, AccessType.keyB, AccessType.keyB, AccessType.keyAB], // 3
  [AccessType.keyAB, AccessType.never, AccessType.never, AccessType.keyAB], // 4
  [AccessType.keyB, AccessType.never, AccessType.never, AccessType.never], // 5
  [AccessType.keyB, AccessType.keyB, AccessType.never, AccessType.never], // 6
  [AccessType.never, AccessType.never, AccessType.never, AccessType.never], // 7
];

/// Trailer block *read* conditions indexed by C1C2C3 value (0-7).
/// Columns: [KeyA, AccessBits, KeyB]
const List<List<AccessType>> trailerReadConditions = [
  [AccessType.never, AccessType.keyA, AccessType.keyA], // 0
  [AccessType.never, AccessType.keyAB, AccessType.never], // 1
  [AccessType.never, AccessType.keyA, AccessType.keyA], // 2
  [AccessType.never, AccessType.keyAB, AccessType.never], // 3
  [AccessType.never, AccessType.keyA, AccessType.keyA], // 4
  [AccessType.never, AccessType.keyAB, AccessType.never], // 5
  [AccessType.never, AccessType.keyAB, AccessType.never], // 6
  [AccessType.never, AccessType.keyAB, AccessType.never], // 7
];

/// Trailer block *write* conditions indexed by C1C2C3 value (0-7).
/// Columns: [KeyA, AccessBits, KeyB]
const List<List<AccessType>> trailerWriteConditions = [
  [AccessType.keyA, AccessType.never, AccessType.keyA], // 0
  [AccessType.keyB, AccessType.never, AccessType.keyB], // 1
  [AccessType.never, AccessType.never, AccessType.never], // 2
  [AccessType.never, AccessType.never, AccessType.never], // 3
  [AccessType.keyA, AccessType.keyA, AccessType.keyA], // 4
  [AccessType.never, AccessType.keyB, AccessType.never], // 5
  [AccessType.keyB, AccessType.keyB, AccessType.keyB], // 6
  [AccessType.never, AccessType.never, AccessType.never], // 7
];

// ---------------------------------------------------------------------------
// Block & Sector key types
// ---------------------------------------------------------------------------

class SectorKey {
  String keyA; // 12 hex chars (6 bytes)
  String keyB; // 12 hex chars (6 bytes)
  SectorKey({this.keyA = 'FFFFFFFFFFFF', this.keyB = 'FFFFFFFFFFFF'});
}

// ---------------------------------------------------------------------------
// MifareCard - the full card data model
// ---------------------------------------------------------------------------

class MifareCard {
  CardType cardType;
  String uid;
  String atqa;
  String sak;

  /// Raw block data as hex strings (32 hex chars = 16 bytes each).
  List<String> blocks;

  /// Per-sector keys (extracted from trailer blocks or key files).
  List<SectorKey> sectorKeys;

  MifareCard({
    this.cardType = card1K,
    this.uid = '',
    this.atqa = '',
    this.sak = '',
    List<String>? blocks,
    List<SectorKey>? sectorKeys,
  })  : blocks = blocks ??
            List.filled(card1K.blockCount, '0' * 32),
        sectorKeys = sectorKeys ??
            List.generate(card1K.sectorCount, (_) => SectorKey());

  /// Reinitialize for a different card type.
  void setCardType(CardType type) {
    cardType = type;
    blocks = List.filled(type.blockCount, '0' * 32);
    sectorKeys = List.generate(type.sectorCount, (_) => SectorKey());
  }

  /// Get the raw bytes for a specific block.
  Uint8List blockBytes(int blockIndex) {
    final hex = blocks[blockIndex];
    final bytes = Uint8List(16);
    for (var i = 0; i < 16; i++) {
      bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return bytes;
  }

  /// Which sector does a block belong to?
  int blockToSector(int blockIndex) {
    for (var s = cardType.sectorCount - 1; s >= 0; s--) {
      if (blockIndex >= cardType.sectorFirstBlock[s]) return s;
    }
    return 0;
  }

  /// Is this block a trailer (last block of its sector)?
  bool isTrailerBlock(int blockIndex) {
    final sector = blockToSector(blockIndex);
    return blockIndex == cardType.trailerBlock(sector);
  }

  /// Is this block 0 (manufacturer data)?
  bool isManufacturerBlock(int blockIndex) => blockIndex == 0;

  /// Extract keys from trailer blocks into sectorKeys.
  void extractKeysFromBlocks() {
    for (var s = 0; s < cardType.sectorCount; s++) {
      final tb = cardType.trailerBlock(s);
      if (tb < blocks.length && blocks[tb].length == 32) {
        sectorKeys[s].keyA = blocks[tb].substring(0, 12).toUpperCase();
        sectorKeys[s].keyB = blocks[tb].substring(20, 32).toUpperCase();
      }
    }
  }

  /// Get the 3 access-condition bytes from a trailer block.
  /// Returns bytes 6,7,8 of the trailer block (after KeyA).
  Uint8List accessBytes(int sector) {
    final tb = cardType.trailerBlock(sector);
    final raw = blockBytes(tb);
    return Uint8List.fromList([raw[6], raw[7], raw[8]]);
  }
}
