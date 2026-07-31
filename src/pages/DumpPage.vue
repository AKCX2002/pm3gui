<template>
  <div class="dump-page">
    <el-tabs v-model="activeTab">
      <el-tab-pane label="Dump 查看" name="viewer">
        <div class="toolbar">
          <el-button type="primary" @click="loadDump">
            <el-icon><FolderOpened /></el-icon> 打开 Dump 文件
          </el-button>
          <el-select v-if="dumpData" v-model="viewMode" style="width: 120px; margin-left: 12px">
            <el-option label="十六进制" value="hex" />
            <el-option label="原始" value="raw" />
          </el-select>
        </div>
        <div v-if="dumpData" class="hex-viewer">
          <div class="hex-header">
            <span class="offset-col">偏移</span>
            <span v-for="i in 16" :key="i" class="byte-col">{{ (i-1).toString(16).padStart(2, '0').toUpperCase() }}</span>
            <span class="ascii-col">ASCII</span>
          </div>
          <div v-for="(row, idx) in hexRows" :key="idx" class="hex-row">
            <span class="offset-col">{{ (idx * 16).toString(16).padStart(8, '0') }}</span>
            <span
              v-for="(byte, bi) in row"
              :key="bi"
              class="byte-col"
              :class="{ 'byte-zero': byte === '00', 'byte-ff': byte === 'FF' }"
            >{{ byte }}</span>
            <span class="ascii-col">{{ asciiRow(row) }}</span>
          </div>
        </div>
        <el-empty v-else description="打开一个 .bin/.json/.eml dump 文件查看" />
      </el-tab-pane>

      <el-tab-pane label="Dump 对比" name="compare">
        <div class="compare-toolbar">
          <el-button @click="loadLeft">加载左侧</el-button>
          <el-button @click="loadRight">加载右侧</el-button>
        </div>
        <el-row :gutter="20">
          <el-col :span="12">
            <h4>{{ leftPath || "未加载" }}</h4>
            <pre v-if="leftDump" class="dump-text">{{ leftDump }}</pre>
            <el-empty v-else description="加载左侧 dump" />
          </el-col>
          <el-col :span="12">
            <h4>{{ rightPath || "未加载" }}</h4>
            <pre v-if="rightDump" class="dump-text">{{ rightDump }}</pre>
            <el-empty v-else description="加载右侧 dump" />
          </el-col>
        </el-row>
      </el-tab-pane>
    </el-tabs>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from "vue";
import { open } from "@tauri-apps/plugin-dialog";
import { readFile } from "@tauri-apps/plugin-fs";

const activeTab = ref("viewer");
const viewMode = ref("hex");
const dumpData = ref<Uint8Array | null>(null);
const dumpPath = ref("");
const leftDump = ref("");
const rightDump = ref("");
const leftPath = ref("");
const rightPath = ref("");

const hexRows = computed(() => {
  if (!dumpData.value) return [];
  const rows: string[][] = [];
  for (let i = 0; i < dumpData.value.length; i += 16) {
    const row: string[] = [];
    for (let j = 0; j < 16 && i + j < dumpData.value.length; j++) {
      row.push(dumpData.value[i + j].toString(16).padStart(2, '0').toUpperCase());
    }
    rows.push(row);
  }
  return rows;
});

function asciiRow(row: string[]): string {
  return row.map(b => {
    const code = parseInt(b, 16);
    return code >= 32 && code < 127 ? String.fromCharCode(code) : '.';
  }).join('');
}

async function loadDumpFile(): Promise<{ data: Uint8Array; path: string } | null> {
  const selected = await open({
    multiple: false,
    filters: [{ name: "Dump 文件", extensions: ["bin", "json", "eml", "dump"] }],
  });
  if (!selected) return null;
  const data = await readFile(selected);
  return { data, path: selected };
}

async function loadDump() {
  const result = await loadDumpFile();
  if (result) {
    dumpData.value = result.data;
    dumpPath.value = result.path;
  }
}

async function loadLeft() {
  const result = await loadDumpFile();
  if (result) {
    leftDump.value = hexDump(result.data);
    leftPath.value = result.path;
  }
}

async function loadRight() {
  const result = await loadDumpFile();
  if (result) {
    rightDump.value = hexDump(result.data);
    rightPath.value = result.path;
  }
}

function hexDump(data: Uint8Array): string {
  const lines: string[] = [];
  for (let i = 0; i < data.length; i += 16) {
    const offset = i.toString(16).padStart(8, '0');
    const hex: string[] = [];
    const ascii: string[] = [];
    for (let j = 0; j < 16 && i + j < data.length; j++) {
      const byte = data[i + j];
      hex.push(byte.toString(16).padStart(2, '0').toUpperCase());
      ascii.push(byte >= 32 && byte < 127 ? String.fromCharCode(byte) : '.');
    }
    lines.push(`${offset}  ${hex.join(' ').padEnd(47)}  ${ascii.join('')}`);
  }
  return lines.join('\n');
}
</script>

<style scoped>
.dump-page { height: calc(100vh - 40px); overflow: auto; }
.toolbar { display: flex; align-items: center; margin-bottom: 16px; }
.compare-toolbar { display: flex; gap: 8px; margin-bottom: 16px; }
.hex-viewer { font-family: 'Cascadia Code', Consolas, monospace; font-size: 13px; background: #1e1e1e; color: #d4d4d4; padding: 12px; border-radius: 8px; overflow: auto; }
.hex-header, .hex-row { display: flex; gap: 4px; line-height: 1.6; }
.offset-col { width: 80px; color: #569cd6; flex-shrink: 0; }
.byte-col { width: 28px; text-align: center; flex-shrink: 0; }
.byte-zero { color: #666; }
.byte-ff { color: #d7ba7d; }
.ascii-col { margin-left: 12px; color: #6a9955; flex-shrink: 0; }
.dump-text { font-family: 'Cascadia Code', Consolas, monospace; font-size: 12px; background: #1e1e1e; color: #d4d4d4; padding: 12px; border-radius: 8px; overflow: auto; max-height: 400px; }
</style>
