/// Complete PM3 CLI command mapping.
///
/// Covers all major protocol families in the Iceman/RRG PM3 fork.
/// Organized by top-level command groups: hf, lf, hw, data, mem, trace, nfc.
library;

// ==========================================================================
//  HF 14443-A  (General ISO14443-A)
// ==========================================================================
class Hf14aCmd {
  static String search() => 'hf 14a reader';
  static String info() => 'hf 14a info';
  static String raw(String hex, {bool append = false, bool select = true}) {
    final sb = StringBuffer('hf 14a raw');
    if (select) sb.write(' -s');
    if (append) sb.write(' -c');
    sb.write(' -d $hex');
    return sb.toString();
  }

  static String sniff() => 'hf 14a sniff';
  static String sim({String? uid, String type = '1'}) {
    final sb = StringBuffer('hf 14a sim -t $type');
    if (uid != null) sb.write(' -u $uid');
    return sb.toString();
  }

  static String apdu(String hex) => 'hf 14a apdu -d $hex';
  static String config() => 'hf 14a config';
  static String cuids({int count = 10}) => 'hf 14a cuids -n $count';
  static String ndefRead() => 'hf 14a ndefread';
}

// ==========================================================================
//  HF 14443-B
// ==========================================================================
class Hf14bCmd {
  static String reader() => 'hf 14b reader';
  static String info() => 'hf 14b info';
  static String sniff() => 'hf 14b sniff';
  static String dump() => 'hf 14b dump';
  static String rdbl(int block) => 'hf 14b rdbl -b $block';
  static String wrbl(int block, String data) =>
      'hf 14b wrbl -b $block -d $data';
  static String raw(String hex) => 'hf 14b raw -d $hex';
  static String sim() => 'hf 14b sim';
  static String ndefRead() => 'hf 14b ndefread';
}

// ==========================================================================
//  HF MIFARE Classic  (84+ subcommands)
// ==========================================================================
class HfMfCmd {
  // --- Detection & Info ---
  static String info() => 'hf mf info';
  static String search() => 'hf 14a reader';
  static String mad() => 'hf mf mad';
  static String acl() => 'hf mf acl';
  static String isen() => 'hf mf isen';

  // --- Key recovery ---
  static String autopwn(String sz) => 'hf mf autopwn --$sz';
  static String chk(String sz) => 'hf mf chk --$sz';
  static String fchk(String sz) => 'hf mf fchk --$sz';
  static String darkside() => 'hf mf darkside';
  static String nested(String sz, int blk, String kt, String key) =>
      'hf mf nested --$sz --blk $blk -${kt.toLowerCase()} -k $key';
  static String staticNested(String sz, int blk, String kt, String key) =>
      'hf mf staticnested --$sz --blk $blk -${kt.toLowerCase()} -k $key';
  static String hardnested(
          int blkK, String ktK, String key, int blkT, String ktT) =>
      'hf mf hardnested --blk $blkK -${ktK.toLowerCase()} -k $key --tblk $blkT --t${ktT.toLowerCase()}';
  static String nack() => 'hf mf nack';
  static String brute(int blk, String kt) =>
      'hf mf brute --blk $blk -${kt.toLowerCase()}';
  static String decrypt() => 'hf mf decrypt';
  static String supercard() => 'hf mf supercard';
  static String keygen({String? uid}) {
    if (uid != null) return 'hf mf keygen --uid $uid';
    return 'hf mf keygen';
  }

  // --- Read / Write ---
  static String rdbl(int blk, String kt, String key) =>
      'hf mf rdbl --blk $blk -${kt.toLowerCase()} -k $key';
  static String rdsc(int sec, String kt, String key) =>
      'hf mf rdsc --sec $sec -${kt.toLowerCase()} -k $key';
  static String wrbl(int blk, String kt, String key, String data) =>
      'hf mf wrbl --blk $blk -${kt.toLowerCase()} -k $key -d $data${blk == 0 ? ' --force' : ''}';
  static String dump(String sz, {String? file}) {
    final sb = StringBuffer('hf mf dump --$sz');
    if (file != null) sb.write(' -f $file');
    return sb.toString();
  }

  static String restore(String sz, {String? file}) {
    final sb = StringBuffer('hf mf restore --$sz');
    if (file != null) sb.write(' -f $file');
    return sb.toString();
  }

  static String view(String file) => 'hf mf view -f $file';
  static String wipe() => 'hf mf wipe';
  static String value(int blk, String kt, String key) =>
      'hf mf value --blk $blk -${kt.toLowerCase()} -k $key';

  // --- Simulation / Emulator ---
  static String sim({String? uid}) {
    if (uid != null) return 'hf mf sim --uid $uid';
    return 'hf mf sim';
  }

  static String eload(String file) => 'hf mf eload -f $file';
  static String esave({String? file}) {
    if (file != null) return 'hf mf esave -f $file';
    return 'hf mf esave';
  }

  static String eclr() => 'hf mf eclr';
  static String egetblk(int blk) => 'hf mf egetblk --blk $blk';
  static String esetblk(int blk, String data) =>
      'hf mf esetblk --blk $blk -d $data';
  static String eview(String sz) => 'hf mf eview --$sz';
  static String ecfill(String kt, String key) =>
      'hf mf ecfill -${kt.toLowerCase()} -k $key';
  static String ekeyprn() => 'hf mf ekeyprn';

  // --- Magic Gen1A ---
  static String cgetblk(int blk) => 'hf mf cgetblk --blk $blk';
  static String cgetsc(int sec) => 'hf mf cgetsc --sec $sec';
  static String csetblk(int blk, String data) =>
      'hf mf csetblk --blk $blk -d $data';
  static String csetuid(String uid, {String? atqa, String? sak}) {
    final sb = StringBuffer('hf mf csetuid --uid $uid');
    if (atqa != null) sb.write(' --atqa $atqa');
    if (sak != null) sb.write(' --sak $sak');
    return sb.toString();
  }

  static String cload(String file) => 'hf mf cload -f $file';
  static String csave({String? file}) {
    if (file != null) return 'hf mf csave -f $file';
    return 'hf mf csave';
  }

  static String cview(String sz) => 'hf mf cview --$sz';
  static String cwipe() => 'hf mf cwipe';

  // --- Magic Gen3 ---
  static String gen3uid(String uid) => 'hf mf gen3uid --uid $uid';
  static String gen3blk(String data) => 'hf mf gen3blk -d $data';
  static String gen3freeze() => 'hf mf gen3freeze';

  // --- Magic Gen4 GTU ---
  static String ginfo({String? pwd}) {
    if (pwd != null) return 'hf mf ginfo --pwd $pwd';
    return 'hf mf ginfo';
  }

  static String ggetblk(int blk, {String? pwd}) {
    final sb = StringBuffer('hf mf ggetblk --blk $blk');
    if (pwd != null) sb.write(' --pwd $pwd');
    return sb.toString();
  }

  static String gsetblk(int blk, String data, {String? pwd}) {
    final sb = StringBuffer('hf mf gsetblk --blk $blk -d $data');
    if (pwd != null) sb.write(' --pwd $pwd');
    return sb.toString();
  }

  static String gload(String file, {String? pwd}) {
    final sb = StringBuffer('hf mf gload -f $file');
    if (pwd != null) sb.write(' --pwd $pwd');
    return sb.toString();
  }

  static String gsave({String? file, String? pwd}) {
    final sb = StringBuffer('hf mf gsave');
    if (file != null) sb.write(' -f $file');
    if (pwd != null) sb.write(' --pwd $pwd');
    return sb.toString();
  }

  static String gview(String sz, {String? pwd}) {
    final sb = StringBuffer('hf mf gview --$sz');
    if (pwd != null) sb.write(' --pwd $pwd');
    return sb.toString();
  }

  static String gchpwd(String oldPwd, String newPwd) =>
      'hf mf gchpwd --pwd $oldPwd --newpwd $newPwd';

  // --- NDEF ---
  static String ndefRead() => 'hf mf ndefread';
  static String ndefWrite(String data) => 'hf mf ndefwrite -d $data';
  static String ndefFormat() => 'hf mf ndefformat';

  // --- Sniff & Trace ---
  static String sniff() => 'hf 14a sniff';
  static String traceList() => 'trace list -t mf';
}

// ==========================================================================
//  HF MIFARE Ultralight / NTAG
// ==========================================================================
class HfMfuCmd {
  static String info() => 'hf mfu info';
  static String dump({String? file}) {
    if (file != null) return 'hf mfu dump -f $file';
    return 'hf mfu dump';
  }

  static String rdbl(int blk) => 'hf mfu rdbl -b $blk';
  static String wrbl(int blk, String data) => 'hf mfu wrbl -b $blk -d $data';
  static String restore(String file) => 'hf mfu restore -f $file';
  static String view(String file) => 'hf mfu view -f $file';
  static String wipe() => 'hf mfu wipe';
  static String ndefRead() => 'hf mfu ndefread';
  static String keygen() => 'hf mfu keygen';
  static String pwdgen({String? uid}) {
    if (uid != null) return 'hf mfu pwdgen -r $uid';
    return 'hf mfu pwdgen';
  }

  static String cauth(String key) => 'hf mfu cauth -k $key';
  static String cchk() => 'hf mfu cchk';
  static String sim() => 'hf mfu sim';
  static String eload(String file) => 'hf mfu eload -f $file';
  static String esave({String? file}) {
    if (file != null) return 'hf mfu esave -f $file';
    return 'hf mfu esave';
  }

  static String eview() => 'hf mfu eview';
  static String setuid(String uid) => 'hf mfu setuid --uid $uid';
}

// ==========================================================================
//  HF MIFARE DESFire
// ==========================================================================
class HfMfdesCmd {
  static String info() => 'hf mfdes info';
  static String detect() => 'hf mfdes detect';
  static String getuid() => 'hf mfdes getuid';
  static String freemem() => 'hf mfdes freemem';
  static String mad() => 'hf mfdes mad';
  static String chk() => 'hf mfdes chk';
  static String auth(String keyNo, String key, {String algo = 'aes'}) =>
      'hf mfdes auth -n $keyNo -k $key -t $algo';
  static String formatpicc() => 'hf mfdes formatpicc';
  static String getaids() => 'hf mfdes getaids';
  static String lsapp() => 'hf mfdes lsapp';
  static String selectapp(String aid) => 'hf mfdes selectapp --aid $aid';
  static String createapp(String aid, String settings) =>
      'hf mfdes createapp --aid $aid --ks1 $settings';
  static String deleteapp(String aid) => 'hf mfdes deleteapp --aid $aid';
  static String getfileids() => 'hf mfdes getfileids';
  static String lsfiles() => 'hf mfdes lsfiles';
  static String read({String? aid, String? fid}) {
    final sb = StringBuffer('hf mfdes read');
    if (aid != null) sb.write(' --aid $aid');
    if (fid != null) sb.write(' --fid $fid');
    return sb.toString();
  }

  static String write(String data, {String? aid, String? fid}) {
    final sb = StringBuffer('hf mfdes write -d $data');
    if (aid != null) sb.write(' --aid $aid');
    if (fid != null) sb.write(' --fid $fid');
    return sb.toString();
  }

  static String dump({String? aid}) {
    if (aid != null) return 'hf mfdes dump --aid $aid';
    return 'hf mfdes dump';
  }

  static String changekey(String keyNo, String newKey,
      {String? oldKey, String algo = 'aes'}) {
    final sb =
        StringBuffer('hf mfdes changekey -n $keyNo --newkey $newKey -t $algo');
    if (oldKey != null) sb.write(' --oldkey $oldKey');
    return sb.toString();
  }

  static String getkeysettings() => 'hf mfdes getkeysettings';
}

// ==========================================================================
//  HF ISO 15693
// ==========================================================================
class Hf15Cmd {
  static String reader() => 'hf 15 reader';
  static String info() => 'hf 15 info';
  static String dump({String? file}) {
    if (file != null) return 'hf 15 dump -f $file';
    return 'hf 15 dump';
  }

  static String restore(String file) => 'hf 15 restore -f $file';
  static String rdbl(int blk) => 'hf 15 rdbl -b $blk';
  static String wrbl(int blk, String data) => 'hf 15 wrbl -b $blk -d $data';
  static String view(String file) => 'hf 15 view -f $file';
  static String wipe() => 'hf 15 wipe';
  static String sniff() => 'hf 15 sniff';
  static String raw(String hex) => 'hf 15 raw -d $hex';
  static String sim() => 'hf 15 sim';
  static String findafi() => 'hf 15 findafi';
  static String csetuid(String uid) => 'hf 15 csetuid -u $uid';
}

// ==========================================================================
//  HF iCLASS
// ==========================================================================
class HfIclassCmd {
  static String info() => 'hf iclass info';
  static String reader() => 'hf iclass reader';
  static String dump({String? key, String? file}) {
    final sb = StringBuffer('hf iclass dump');
    if (key != null) sb.write(' -k $key');
    if (file != null) sb.write(' -f $file');
    return sb.toString();
  }

  static String rdbl(int blk, {String? key}) {
    final sb = StringBuffer('hf iclass rdbl -b $blk');
    if (key != null) sb.write(' -k $key');
    return sb.toString();
  }

  static String wrbl(int blk, String data, {String? key}) {
    final sb = StringBuffer('hf iclass wrbl -b $blk -d $data');
    if (key != null) sb.write(' -k $key');
    return sb.toString();
  }

  static String restore(String file) => 'hf iclass restore -f $file';
  static String view(String file) => 'hf iclass view -f $file';
  static String sniff() => 'hf iclass sniff';
  static String chk() => 'hf iclass chk';
  static String loclass() => 'hf iclass loclass';
  static String sim() => 'hf iclass sim';
  static String eload(String file) => 'hf iclass eload -f $file';
  static String eview() => 'hf iclass eview';
}

// ==========================================================================
//  HF FeliCa
// ==========================================================================
class HfFelicaCmd {
  static String reader() => 'hf felica reader';
  static String info() => 'hf felica info';
  static String sniff() => 'hf felica sniff';
  static String dump() => 'hf felica dump';
  static String rdbl(String sc, String bl) =>
      'hf felica rdbl --sc $sc --bl $bl';
  static String wrbl(String sc, String bl, String data) =>
      'hf felica wrbl --sc $sc --bl $bl -d $data';
  static String raw(String hex) => 'hf felica raw -d $hex';
  static String litedump() => 'hf felica litedump';
}

// ==========================================================================
//  HF Legic / SEOS / EMV / FIDO
// ==========================================================================
class HfLegicCmd {
  static String info() => 'hf legic info';
  static String dump({String? file}) {
    if (file != null) return 'hf legic dump -f $file';
    return 'hf legic dump';
  }

  static String restore(String file) => 'hf legic restore -f $file';
  static String rdbl(int off, int len) => 'hf legic rdbl -o $off -l $len';
  static String wrbl(int off, String data) => 'hf legic wrbl -o $off -d $data';
  static String wipe() => 'hf legic wipe';
  static String sim() => 'hf legic sim';
}

class HfSeosCmd {
  static String info() => 'hf seos info';
  static String pacs() => 'hf seos pacs';
  static String sim() => 'hf seos sim';
}

class HfEmvCmd {
  static String search() => 'emv search';
  static String ppse() => 'emv ppse';
  static String exec() => 'emv exec';
  static String test() => 'emv test';
}

class HfFidoCmd {
  static String info() => 'hf fido info';
  static String reg() => 'hf fido reg';
  static String auth() => 'hf fido auth';
}

// ==========================================================================
//  HF General
// ==========================================================================
class HfCmd {
  static String search() => 'hf search';
  static String tune() => 'hf tune';
  static String sniff() => 'hf sniff';
  static String list(String protocol) => 'hf list -t $protocol';
}

// ==========================================================================
//  LF General
// ==========================================================================
class LfCmd {
  static String search() => 'lf search';
  static String read() => 'lf read';
  static String sniff() => 'lf sniff';
  static String tune() => 'lf tune';
  static String sim() => 'lf sim';
  static String config() => 'lf config';
}

// ==========================================================================
//  LF EM 410x / 4x05 / 4x50 / 4x70
// ==========================================================================
class LfEmCmd {
  static String em410xReader() => 'lf em 410x reader';
  static String em410xClone(String id) => 'lf em 410x clone --id $id';
  static String em410xSim(String id) => 'lf em 410x sim --id $id';
  static String em410xBrute(String id) => 'lf em 410x brute --id $id';
  static String em410xWatch() => 'lf em 410x watch';
  static String em4x05Dump() => 'lf em 4x05 dump';
  static String em4x05Info() => 'lf em 4x05 info';
  static String em4x05Read(int addr) => 'lf em 4x05 read --addr $addr';
  static String em4x05Write(int addr, String data, {String? pwd}) {
    final sb = StringBuffer('lf em 4x05 write --addr $addr --data $data');
    if (pwd != null) sb.write(' --pwd $pwd');
    return sb.toString();
  }

  static String em4x05Unlock(String pwd) => 'lf em 4x05 unlock --pwd $pwd';
  static String em4x05Wipe({String? pwd}) {
    if (pwd != null) return 'lf em 4x05 wipe --pwd $pwd';
    return 'lf em 4x05 wipe';
  }

  static String em4x50Info() => 'lf em 4x50 info';
  static String em4x50Dump() => 'lf em 4x50 dump';
  static String em4x70Info() => 'lf em 4x70 info';
  static String em4x70Auth(String key) => 'lf em 4x70 auth --key $key';
}

// ==========================================================================
//  LF T55xx
// ==========================================================================
class LfT55xxCmd {
  static String detect({String? pwd}) {
    if (pwd != null) return 'lf t55xx detect -p $pwd';
    return 'lf t55xx detect';
  }

  static String info({String? pwd}) {
    if (pwd != null) return 'lf t55xx info -p $pwd';
    return 'lf t55xx info';
  }

  static String dump({String? pwd, String? file}) {
    final sb = StringBuffer('lf t55xx dump');
    if (pwd != null) sb.write(' -p $pwd');
    if (file != null) sb.write(' -f $file');
    return sb.toString();
  }

  static String read(int blk, {String? pwd, int page = 0}) {
    final sb = StringBuffer('lf t55xx read -b $blk --pg $page');
    if (pwd != null) sb.write(' -p $pwd');
    return sb.toString();
  }

  static String write(int blk, String data, {String? pwd, int page = 0}) {
    final sb = StringBuffer('lf t55xx write -b $blk -d $data --pg $page');
    if (pwd != null) sb.write(' -p $pwd');
    return sb.toString();
  }

  static String bruteforce() => 'lf t55xx bruteforce';
  static String chk() => 'lf t55xx chk';
  static String wipe({String? pwd}) {
    if (pwd != null) return 'lf t55xx wipe -p $pwd';
    return 'lf t55xx wipe';
  }

  static String trace() => 'lf t55xx trace';
  static String sniff() => 'lf t55xx sniff';
  static String recoverpw() => 'lf t55xx recoverpw';
  static String protect({String? pwd, String? newPwd}) {
    final sb = StringBuffer('lf t55xx protect');
    if (pwd != null) sb.write(' -p $pwd');
    if (newPwd != null) sb.write(' --new $newPwd');
    return sb.toString();
  }
}

// ==========================================================================
//  LF HID / AWID / Indala / Hitag / IO / etc.
// ==========================================================================
class LfHidCmd {
  static String reader() => 'lf hid reader';
  static String demod() => 'lf hid demod';
  static String clone(String data) => 'lf hid clone -w $data';
  static String sim(String data) => 'lf hid sim -w $data';
  static String brute({String? fc}) {
    if (fc != null) return 'lf hid brute --fc $fc';
    return 'lf hid brute';
  }
}

class LfAwidCmd {
  static String reader() => 'lf awid reader';
  static String clone(String fc, String cn) =>
      'lf awid clone --fc $fc --cn $cn';
  static String sim(String fc, String cn) => 'lf awid sim --fc $fc --cn $cn';
}

class LfIndalaCmd {
  static String reader() => 'lf indala reader';
  static String clone(String data) => 'lf indala clone --raw $data';
  static String sim(String data) => 'lf indala sim --raw $data';
}

class LfHitagCmd {
  static String reader() => 'lf hitag reader';
  static String info() => 'lf hitag info';
  static String dump() => 'lf hitag dump';
  static String sniff() => 'lf hitag sniff';
  static String sim() => 'lf hitag sim';
  static String chk() => 'lf hitag chk';
  static String crack() => 'lf hitag crack';
}

class LfIoCmd {
  static String reader() => 'lf io reader';
  static String clone(String data) => 'lf io clone --raw $data';
  static String sim(String data) => 'lf io sim --raw $data';
}

class LfPyramidCmd {
  static String reader() => 'lf pyramid reader';
  static String clone(String fc, String cn) =>
      'lf pyramid clone --fc $fc --cn $cn';
}

class LfKeriCmd {
  static String reader() => 'lf keri reader';
  static String clone(String data) => 'lf keri clone --raw $data';
}

class LfFdxbCmd {
  static String reader() => 'lf fdxb reader';
  static String clone(String data) => 'lf fdxb clone --raw $data';
}

// ==========================================================================
//  Hardware / Memory / Data / Trace / NFC / Script
// ==========================================================================
class HwCmd {
  static String version() => 'hw version';
  static String status() => 'hw status';
  static String tune() => 'hw tune';
  static String ping() => 'hw ping';
  static String dbg(int level) => 'hw dbg -$level';
  static String fpgaoff() => 'hw fpgaoff';
  static String reset() => 'hw reset';
  static String bootloader() => 'hw bootloader';
  static String connect() => 'hw connect';
  static String setlfdivisor(int div) => 'hw setlfdivisor -d $div';
  static String tia() => 'hw tia';
  static String tearoff({int delay = 0}) => 'hw tearoff --delay $delay --on';
  static String standalone({String? mode}) {
    if (mode != null) return 'hw standalone -m $mode';
    return 'hw standalone';
  }

  static String detectreader({String freq = 'h'}) => 'hw detectreader -$freq';
}

class MemCmd {
  static String info() => 'mem info';
  static String dump({String? file}) {
    if (file != null) return 'mem dump -f $file';
    return 'mem dump';
  }

  static String load(String file) => 'mem load -f $file';
  static String wipe() => 'mem wipe';
}

class DataCmd {
  static String plot() => 'data plot';
  static String save(String file) => 'data save -f $file';
  static String load(String file) => 'data load -f $file';
  static String clear() => 'data clear';
  static String samples({int count = 20000}) => 'data samples -n $count';
  static String detectclock() => 'data detectclock';
  static String asn1(String hex) => 'data asn1 -d $hex';
  static String diff(String a, String b) => 'data diff -a $a -b $b';
}

class TraceCmd {
  static String list({String type = 'raw'}) => 'trace list -t $type';
  static String save(String file) => 'trace save -f $file';
  static String load(String file) => 'trace load -f $file';
  static String extract() => 'trace extract';
}

class NfcCmd {
  static String decode(String data) => 'nfc decode -d $data';
  static String type1() => 'nfc type1';
  static String type2() => 'nfc type2';
  static String type4a() => 'nfc type4a';
  static String barcode() => 'nfc barcode';
}

class ScriptCmd {
  static String run(String name) => 'script run $name';
  static String list() => 'script list';
}

class MiscCmd {
  static String auto() => 'auto';
  static String clear() => 'clear';
  static String quit() => 'quit';
}

// ==========================================================================
//  Backward-compatible wrapper (old Pm3Commands API)
// ==========================================================================
class Pm3Commands {
  // ---- HF Mifare Classic ----

  static String hf14aSearch() => 'hf 14a reader';
  static String hf14aInfo() => 'hf 14a info';

  static String hfMfInfo() => 'hf mf info';

  static String hfMfDump(
    String cardSize, {
    String? keyFile,
    String? dumpFile,
  }) {
    final parts = <String>['hf mf dump', '--$cardSize'];
    if (keyFile != null && keyFile.trim().isNotEmpty) {
      parts.add('--keys ${_quotePath(keyFile)}');
    }
    if (dumpFile != null && dumpFile.trim().isNotEmpty) {
      parts.add('--file ${_quotePath(dumpFile)}');
    }
    return parts.join(' ');
  }

  static String hfMfRestore(
    String cardSize, {
    String? keyFile,
    String? dumpFile,
  }) {
    final parts = <String>['hf mf restore', '--$cardSize', '--force'];
    if (keyFile != null && keyFile.trim().isNotEmpty) {
      parts.add('--keys ${_quotePath(keyFile)}');
    }
    if (dumpFile != null && dumpFile.trim().isNotEmpty) {
      parts.add('--file ${_quotePath(dumpFile)}');
    }
    return parts.join(' ');
  }

  static String hfMfReadBlock(int block, String keyType, String key) =>
      'hf mf rdbl --blk $block -${keyType.toLowerCase()} -k $key';

  static String hfMfWriteBlock(
          int block, String keyType, String key, String data) =>
      'hf mf wrbl --blk $block -${keyType.toLowerCase()} -k $key -d $data${block == 0 ? ' --force' : ''}';

  static String hfMfNested(
          String cardSize, int block, String keyType, String key) =>
      'hf mf nested --$cardSize --blk $block -${keyType.toLowerCase()} -k $key';

  static String hfMfStaticNested(
          String cardSize, int block, String keyType, String key) =>
      'hf mf staticnested --$cardSize --blk $block -${keyType.toLowerCase()} -k $key';

  static String hfMfHardnested(int blockKnown, String keyTypeKnown,
          String keyKnown, int blockTarget, String keyTypeTarget) =>
      'hf mf hardnested --blk $blockKnown -${keyTypeKnown.toLowerCase()} -k $keyKnown --tblk $blockTarget --t${keyTypeTarget.toLowerCase()}';

  static String hfMfDarkside() => 'hf mf darkside';

  static String hfMfCheck(String cardSize) => 'hf mf chk --$cardSize';

  static String hfMfAutopwn(String cardSize) => 'hf mf autopwn --$cardSize';

  static String hfMfView(String filePath) => 'hf mf view -f $filePath';

  // Emulator
  static String hfMfEmulatorClear() => 'hf mf eclr';
  static String hfMfEmulatorGetBlock(int block) => 'hf mf egetblk --blk $block';
  static String hfMfEmulatorSetBlock(int block, String data) =>
      'hf mf esetblk --blk $block -d $data';
  static String hfMfEmulatorSim(String uid) => 'hf mf sim --uid $uid';

  // Magic card
  static String hfMfMagicGetBlock(int block) => 'hf mf cgetblk --blk $block';
  static String hfMfMagicSetBlock(int block, String data) =>
      'hf mf csetblk --blk $block -d $data';
  static String hfMfMagicWipe() => 'hf mf cwipe';

  /// CUID 卡逐块清空：使用已知密钥认证后写入全 0 数据
  /// [block] — 块号
  /// [keyType] — 'A' 或 'B'
  /// [key] — 12位 hex 密钥
  static String hfMfCuidClearBlock(int block, String keyType, String key) =>
      'hf mf wrbl --blk $block -${keyType.toLowerCase()} -k $key -d 00000000000000000000000000000000${block == 0 ? ' --force' : ''}';

  /// CUID 卡逐块回写：使用目标卡密钥认证后写入指定数据
  /// [block] — 块号
  /// [keyType] — 'A' 或 'B'
  /// [key] — 12位 hex 密钥
  /// [data] — 32位 hex 数据
  static String hfMfCuidWriteBlock(
          int block, String keyType, String key, String data) =>
      'hf mf wrbl --blk $block -${keyType.toLowerCase()} -k $key -d $data${block == 0 ? ' --force' : ''}';

  /// 尾块回写 (Key A + 访问控制 + Key B)
  static String hfMfWriteTrailer(
          int block, String keyType, String key, String trailerData) =>
      'hf mf wrbl --blk $block -${keyType.toLowerCase()} -k $key -d $trailerData${block == 0 ? ' --force' : ''}';

  /// 生成 1K 卡默认尾块数据
  static String defaultTrailerData(
          {String keyA = 'FFFFFFFFFFFF',
          String accessBits = 'FF078069',
          String keyB = 'FFFFFFFFFFFF'}) =>
      '$keyA$accessBits$keyB';

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
  static String lfEm410xClone(String id) => 'lf em 410x clone --id $id';

  static String lfT55xxDetect() => 'lf t55xx detect';
  static String lfT55xxInfo() => 'lf t55xx info';
  static String lfT55xxDump() => 'lf t55xx dump';
  static String lfT55xxReadBlock(int block) => 'lf t55xx read -b $block';
  static String lfT55xxWriteBlock(int block, String data) =>
      'lf t55xx write -b $block -d $data';

  // ---- Device ----
  static String hwVersion() => 'hw version';
  static String hwStatus() => 'hw status';
  static String hwTune() => 'hw tune';

  static String _quotePath(String path) {
    final escaped = path.replaceAll('"', '\\"');
    return '"$escaped"';
  }

  // Card size label to CLI flag
  static String cardSizeFlag(String label) {
    switch (label.toUpperCase()) {
      case 'MINI':
        return 'mini';
      case '1K':
        return '1k';
      case '2K':
        return '2k';
      case '4K':
        return '4k';
      default:
        return '1k';
    }
  }
}
