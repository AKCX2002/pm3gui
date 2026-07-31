export interface ParamDef {
  name: string;
  label: string;
  type: "text" | "hex" | "select";
  options?: string[];
  default?: string;
}

export interface CommandDef {
  label: string;
  cmd: string | ((params: Record<string, string>) => string);
  params?: ParamDef[];
  description?: string;
}

export interface ProtocolDef {
  id: string;
  label: string;
  icon?: string;
  commands: { group: string; items: CommandDef[] }[];
}

export const hfProtocols: ProtocolDef[] = [
  {
    id: "mifare",
    label: "MIFARE Classic",
    commands: [
      {
        group: "读卡",
        items: [
          { label: "搜索卡片", cmd: "hf 14a reader" },
          { label: "卡片信息", cmd: "hf mf info" },
          { label: "Dump 1K", cmd: "hf mf dump --1k" },
          { label: "Dump 4K", cmd: "hf mf dump --4k" },
        ],
      },
      {
        group: "破解",
        items: [
          {
            label: "AutoPwn",
            cmd: (p) => `hf mf autopwn --${p.size}`,
            params: [
              { name: "size", label: "卡片大小", type: "select", options: ["1k", "2k", "4k"], default: "1k" },
            ],
          },
          { label: "Darkside", cmd: "hf mf darkside" },
        ],
      },
      {
        group: "读写",
        items: [
          {
            label: "读块",
            cmd: (p) => `hf mf rdbl --blk ${p.block} -${p.keyType} -k ${p.key}`,
            params: [
              { name: "block", label: "块号", type: "text" },
              { name: "keyType", label: "密钥类型", type: "select", options: ["a", "b"], default: "a" },
              { name: "key", label: "密钥", type: "hex" },
            ],
          },
          {
            label: "写块",
            cmd: (p) => `hf mf wrbl --blk ${p.block} -${p.keyType} -k ${p.key} -d ${p.data}`,
            params: [
              { name: "block", label: "块号", type: "text" },
              { name: "keyType", label: "密钥类型", type: "select", options: ["a", "b"], default: "a" },
              { name: "key", label: "密钥", type: "hex" },
              { name: "data", label: "数据", type: "hex" },
            ],
          },
        ],
      },
      {
        group: "恢复",
        items: [
          { label: "Restore", cmd: (p) => `hf mf restore --1k${p.file ? ` -f ${p.file}` : ""}`, params: [{ name: "file", label: "文件名", type: "text" }] },
        ],
      },
    ],
  },
  {
    id: "ultralight",
    label: "Ultralight/NTAG",
    commands: [
      { group: "读卡", items: [
        { label: "搜索", cmd: "hf 14a reader" },
        { label: "信息", cmd: "hf mfu info" },
        { label: "Dump", cmd: "hf mfu dump" },
      ]},
    ],
  },
  {
    id: "desfire",
    label: "DESFire",
    commands: [
      { group: "读卡", items: [
        { label: "搜索", cmd: "hf 14a reader" },
        { label: "信息", cmd: "hf mfdes info" },
      ]},
      { group: "操作", items: [
        { label: "枚举应用", cmd: "hf mfdes enum" },
      ]},
    ],
  },
  {
    id: "iclass",
    label: "iCLASS",
    commands: [
      { group: "读卡", items: [
        { label: "搜索", cmd: "hf iclass reader" },
        { label: "信息", cmd: "hf iclass info" },
      ]},
    ],
  },
  {
    id: "iso15693",
    label: "ISO 15693",
    commands: [
      { group: "读卡", items: [
        { label: "搜索", cmd: "hf 15 reader" },
        { label: "信息", cmd: "hf 15 info" },
      ]},
    ],
  },
  {
    id: "iso14443b",
    label: "ISO 14443-B",
    commands: [
      { group: "读卡", items: [
        { label: "搜索", cmd: "hf 14b reader" },
        { label: "信息", cmd: "hf 14b info" },
      ]},
    ],
  },
  {
    id: "felica",
    label: "FeliCa",
    commands: [
      { group: "读卡", items: [
        { label: "搜索", cmd: "hf felica reader" },
      ]},
    ],
  },
  {
    id: "legic",
    label: "Legic",
    commands: [
      { group: "读卡", items: [
        { label: "搜索", cmd: "hf legic reader" },
      ]},
    ],
  },
  {
    id: "emv",
    label: "EMV",
    commands: [
      { group: "读卡", items: [
        { label: "搜索", cmd: "hf search" },
        { label: "信息", cmd: "hf emv info" },
      ]},
    ],
  },
  {
    id: "seos",
    label: "SEOS",
    commands: [
      { group: "读卡", items: [
        { label: "搜索", cmd: "hf seos info" },
      ]},
    ],
  },
  {
    id: "fido",
    label: "FIDO",
    commands: [
      { group: "读卡", items: [
        { label: "信息", cmd: "hf fido info" },
      ]},
    ],
  },
  {
    id: "hf-sniff",
    label: "HF 嗅探/调谐",
    commands: [
      { group: "嗅探", items: [
        { label: "HF 嗅探", cmd: "hf sniff" },
        { label: "调谐", cmd: "hw tune" },
      ]},
    ],
  },
];

export const lfProtocols: ProtocolDef[] = [
  {
    id: "lf-em",
    label: "LF 通用/EM/T55",
    commands: [
      { group: "读卡", items: [
        { label: "搜索 LF", cmd: "lf search" },
        { label: "EM 读卡", cmd: "lf em 410x reader" },
      ]},
      { group: "T55xx", items: [
        { label: "T55xx 信息", cmd: "lf t55xx info" },
        { label: "T55xx 擦除", cmd: "lf t55xx wipe" },
      ]},
    ],
  },
  {
    id: "lf-hid",
    label: "HID Prox",
    commands: [
      { group: "读卡", items: [
        { label: "读取", cmd: "lf hid reader" },
      ]},
      { group: "模拟", items: [
        { label: "模拟", cmd: (p) => `lf hid sim -r ${p.cardId}`, params: [{ name: "cardId", label: "卡号", type: "text" }] },
      ]},
    ],
  },
  {
    id: "lf-hitag",
    label: "Hitag",
    commands: [
      { group: "读卡", items: [
        { label: "信息", cmd: "lf hitag info" },
      ]},
    ],
  },
  {
    id: "lf-awid",
    label: "AWID",
    commands: [
      { group: "读卡", items: [
        { label: "读取", cmd: "lf awid reader" },
      ]},
    ],
  },
  {
    id: "lf-indala",
    label: "Indala",
    commands: [
      { group: "读卡", items: [
        { label: "读取", cmd: "lf indala reader" },
      ]},
    ],
  },
  {
    id: "lf-ioprox",
    label: "ioProx",
    commands: [
      { group: "读卡", items: [
        { label: "读取", cmd: "lf io reader" },
      ]},
    ],
  },
  {
    id: "lf-pyramid",
    label: "Pyramid",
    commands: [
      { group: "读卡", items: [
        { label: "读取", cmd: "lf pyramid reader" },
      ]},
    ],
  },
  {
    id: "lf-keri",
    label: "Keri",
    commands: [
      { group: "读卡", items: [
        { label: "读取", cmd: "lf keri reader" },
      ]},
    ],
  },
  {
    id: "lf-fdxb",
    label: "FDX-B",
    commands: [
      { group: "读卡", items: [
        { label: "读取", cmd: "lf fdxb reader" },
      ]},
    ],
  },
];
