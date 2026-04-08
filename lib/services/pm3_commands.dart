/// Command templates for PM3 Iceman fork.
///
/// Mirrors Proxmark3GUI/config/config_rrgv4.16717.json command definitions.
/// These templates use placeholder substitution for card-type-specific commands.
library;

class Pm3Commands {
  // ---- HF Mifare Classic ----
  
  static String hf14aSearch() => 'hf 14a search';
  static String hf14aInfo() => 'hf 14a info';

  static String hfMfInfo() => 'hf mf info';

  static String hfMfDump(String cardSize) =>
      'hf mf dump --$cardSize';

  static String hfMfRestore(String cardSize) =>
      'hf mf restore --$cardSize --force';

  static String hfMfReadBlock(int block, String keyType, String key) =>
      'hf mf rdbl --blk $block -${keyType.toLowerCase()} -k $key';

  static String hfMfWriteBlock(int block, String keyType, String key, String data) =>
      'hf mf wrbl --blk $block -${keyType.toLowerCase()} -k $key -d $data';

  static String hfMfNested(String cardSize, int block, String keyType, String key) =>
      'hf mf nested --$cardSize --blk $block -${keyType.toLowerCase()} -k $key';

  static String hfMfStaticNested(String cardSize, int block, String keyType, String key) =>
      'hf mf staticnested --$cardSize --blk $block -${keyType.toLowerCase()} -k $key';

  static String hfMfHardnested(int blockKnown, String keyTypeKnown, String keyKnown, int blockTarget, String keyTypeTarget) =>
      'hf mf hardnested --blk $blockKnown -${keyTypeKnown.toLowerCase()} -k $keyKnown --tblk $blockTarget --t${keyTypeTarget.toLowerCase()}';

  static String hfMfDarkside() => 'hf mf darkside';

  static String hfMfCheck(String cardSize) =>
      'hf mf chk --$cardSize';

  static String hfMfAutopwn(String cardSize) =>
      'hf mf autopwn --$cardSize';

  static String hfMfView(String filePath) =>
      'hf mf view -f $filePath';

  // Emulator
  static String hfMfEmulatorClear() => 'hf mf eclr';
  static String hfMfEmulatorGetBlock(int block) =>
      'hf mf egetblk --blk $block';
  static String hfMfEmulatorSetBlock(int block, String data) =>
      'hf mf esetblk --blk $block -d $data';
  static String hfMfEmulatorSim(String uid) =>
      'hf mf sim --uid $uid';

  // Magic card
  static String hfMfMagicGetBlock(int block) =>
      'hf mf cgetblk --blk $block';
  static String hfMfMagicSetBlock(int block, String data) =>
      'hf mf csetblk --blk $block -d $data';
  static String hfMfMagicWipe() => 'hf mf cwipe';

  // Sniff
  static String hfSniff() => 'hf sniff';
  static String hf14aSniff() => 'hf 14a sniff';
  static String traceList() => 'trace list -t mf';

  // ---- LF ----
  static String lfSearch() => 'lf search';
  static String lfRead() => 'lf read';
  static String lfSniff() => 'lf sniff';
  static String lfTune() => 'lf tune';
  
  static String lfEm410xRead() => 'lf em 410x reader';
  static String lfEm410xClone(String id) =>
      'lf em 410x clone --id $id';
  
  static String lfT55xxDetect() => 'lf t55xx detect';
  static String lfT55xxInfo() => 'lf t55xx info';
  static String lfT55xxDump() => 'lf t55xx dump';
  static String lfT55xxReadBlock(int block) =>
      'lf t55xx read -b $block';
  static String lfT55xxWriteBlock(int block, String data) =>
      'lf t55xx write -b $block -d $data';

  // ---- Device ----
  static String hwVersion() => 'hw version';
  static String hwStatus() => 'hw status';
  static String hwTune() => 'hw tune';

  // Card size label to CLI flag
  static String cardSizeFlag(String label) {
    switch (label.toUpperCase()) {
      case 'MINI': return 'mini';
      case '1K': return '1k';
      case '2K': return '2k';
      case '4K': return '4k';
      default: return '1k';
    }
  }
}
