/// Access bits decoder for Mifare Classic trailer blocks.
///
/// Mirrors logic from Proxmark3GUI/src/ui/mf_trailerdecoderdialog.cpp
/// and Proxmark3GUI/src/module/mifare.cpp data_getACBits().
library;

import 'dart:typed_data';
import 'package:pm3gui/models/mifare_card.dart';

/// Decoded access conditions for one sector.
class SectorAccessInfo {
  /// C1C2C3 value for each data block (0-2 for 4-block sectors, 0-14 for 16-block sectors)
  final List<int> dataBlockBits;

  /// C1C2C3 value for the trailer block itself
  final int trailerBits;

  /// Whether access bits are valid (parity check passes).
  final bool isValid;

  /// Whether KeyB is readable (and thus cannot be used for auth).
  bool get isKeyBReadable =>
      trailerBits == 0 || trailerBits == 2 || trailerBits == 4;

  const SectorAccessInfo({
    required this.dataBlockBits,
    required this.trailerBits,
    required this.isValid,
  });
}

/// Decode access condition bytes (3 bytes: byte6, byte7, byte8 of trailer block).
///
/// Returns null if input is invalid.
/// Otherwise returns [C1C2C3 for block0, block1, block2, trailer].
///
/// Byte layout (Mifare Classic spec):
///   Byte 6: ~C2_b1 ~C2_b0 ~C1_b1 ~C1_b0  ~C1_b3 ~C1_b2 ~C1_b1 ~C1_b0
///   (actually the NXP spec defines it as):
///   byte6 = /C2_3 /C2_2 /C2_1 /C2_0 /C1_3 /C1_2 /C1_1 /C1_0  (inverted)
///   byte7 =  C1_3  C1_2  C1_1  C1_0 /C3_3 /C3_2 /C3_1 /C3_0
///   byte8 =  C3_3  C3_2  C3_1  C3_0  C2_3  C2_2  C2_1  C2_0
List<int>? decodeAccessBits(Uint8List bytes) {
  if (bytes.length < 3) return null;

  final b6 = bytes[0];
  final b7 = bytes[1];
  final b8 = bytes[2];

  // Extract C1, C2, C3 for blocks 0..3 (3 = trailer)
  final c1 = List<int>.filled(4, 0);
  final c2 = List<int>.filled(4, 0);
  final c3 = List<int>.filled(4, 0);

  for (var i = 0; i < 4; i++) {
    c1[i] = (b7 >> (4 + i)) & 1;
    c2[i] = (b8 >> i) & 1;
    c3[i] = (b8 >> (4 + i)) & 1;
  }

  // Verify parity (inverted bits in byte6 and lower nibble of byte7)
  for (var i = 0; i < 4; i++) {
    final nc1 = (b6 >> i) & 1;
    final nc2 = (b6 >> (4 + i)) & 1;
    final nc3 = (b7 >> i) & 1;

    if (nc1 != (1 - c1[i]) || nc2 != (1 - c2[i]) || nc3 != (1 - c3[i])) {
      return null; // Parity error → invalid access bits
    }
  }

  // Combine into C1C2C3 values (0-7) per block
  return List.generate(4, (i) => (c3[i] << 2) | (c2[i] << 1) | c1[i]);
}

/// Decode access bits from hex string (6 or 8 hex chars, with or without spaces).
List<int>? decodeAccessBitsFromHex(String hex) {
  final clean = hex.replaceAll(' ', '').toUpperCase();
  if (clean.length < 6) return null;
  try {
    final bytes = Uint8List(3);
    for (var i = 0; i < 3; i++) {
      bytes[i] = int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return decodeAccessBits(bytes);
  } catch (_) {
    return null;
  }
}

/// Decode the full sector access info for a given MifareCard sector.
SectorAccessInfo decodeSectorAccess(MifareCard card, int sector) {
  final ab = card.accessBytes(sector);
  final bits = decodeAccessBits(ab);

  if (bits == null) {
    return SectorAccessInfo(
      dataBlockBits: List.filled(card.cardType.blocksPerSector[sector] - 1, 0),
      trailerBits: 0,
      isValid: false,
    );
  }

  // For 4-block sectors: bits[0..2] are data blocks, bits[3] is trailer
  // For 16-block sectors (4K upper): blocks 0-4 use bits[0], 5-9 use bits[1], 10-14 use bits[2]
  final dataCount = card.cardType.blocksPerSector[sector] - 1;
  final dataBlockBits = <int>[];

  if (dataCount <= 3) {
    for (var i = 0; i < dataCount; i++) {
      dataBlockBits.add(bits[i]);
    }
  } else {
    // 16-block sector: group blocks into 3 groups
    for (var i = 0; i < dataCount; i++) {
      if (i < 5) {
        dataBlockBits.add(bits[0]);
      } else if (i < 10) {
        dataBlockBits.add(bits[1]);
      } else {
        dataBlockBits.add(bits[2]);
      }
    }
  }

  return SectorAccessInfo(
    dataBlockBits: dataBlockBits,
    trailerBits: bits[3],
    isValid: true,
  );
}

/// Human-readable description of an access type.
String accessTypeLabel(AccessType type) {
  switch (type) {
    case AccessType.never:
      return '✗';
    case AccessType.keyA:
      return 'KeyA';
    case AccessType.keyB:
      return 'KeyB';
    case AccessType.keyAB:
      return 'KeyA/B';
  }
}

/// Encode C values (0-7 per block) back to 3 access bytes.
Uint8List encodeAccessBits(List<int> cValues) {
  assert(cValues.length == 4);

  final c1 = List<int>.filled(4, 0);
  final c2 = List<int>.filled(4, 0);
  final c3 = List<int>.filled(4, 0);

  for (var i = 0; i < 4; i++) {
    c1[i] = cValues[i] & 1;
    c2[i] = (cValues[i] >> 1) & 1;
    c3[i] = (cValues[i] >> 2) & 1;
  }

  var b6 = 0;
  var b7 = 0;
  var b8 = 0;

  for (var i = 0; i < 4; i++) {
    b6 |= ((1 - c1[i]) << i); // ~C1
    b6 |= ((1 - c2[i]) << (4 + i)); // ~C2
    b7 |= ((1 - c3[i]) << i); // ~C3
    b7 |= (c1[i] << (4 + i)); // C1
    b8 |= (c2[i] << i); // C2
    b8 |= (c3[i] << (4 + i)); // C3
  }

  return Uint8List.fromList([b6, b7, b8]);
}
