<template>
  <div class="dump-page">
    <el-tabs v-model="activeTab">
      <el-tab-pane label="Dump 查看" name="viewer">
        <div class="toolbar">
          <el-button type="primary" @click="loadDump">打开 Dump 文件</el-button>
          <el-radio-group v-if="dumpData" v-model="viewMode">
            <el-radio-button value="hex">十六进制</el-radio-button>
            <el-radio-button value="raw">文本预览</el-radio-button>
          </el-radio-group>
          <el-tag v-if="dumpData" type="info">{{ dumpData.length.toLocaleString() }} 字节</el-tag>
        </div>
        <template v-if="dumpData">
          <div class="file-path">{{ dumpPath }}</div>
          <pre v-if="viewMode === 'raw'" class="raw-viewer">{{ preview }}</pre>
          <div v-else class="hex-viewer">
            <div v-for="row in visibleRows" :key="row.offset" class="hex-row">
              <span class="offset">{{ row.offset.toString(16).padStart(8, "0").toUpperCase() }}</span>
              <span class="hex">{{ row.hex }}</span><span class="ascii">{{ row.ascii }}</span>
            </div>
            <div v-if="totalRows > visibleRows.length" class="truncated">
              为保证界面流畅，仅显示前 {{ visibleRows.length }} 行；文件读取和大小统计保持完整。
            </div>
          </div>
        </template>
        <el-empty v-else description="打开只读 .bin/.dump/.eml 文件" />
      </el-tab-pane>
      <el-tab-pane label="Dump 对比" name="compare">
        <div class="toolbar">
          <el-button @click="loadSide('left')">加载左侧</el-button>
          <el-button @click="loadSide('right')">加载右侧</el-button>
        </div>
        <el-descriptions v-if="diff" :column="2" border>
          <el-descriptions-item label="左侧大小">{{ diff.leftSize.toLocaleString() }}</el-descriptions-item>
          <el-descriptions-item label="右侧大小">{{ diff.rightSize.toLocaleString() }}</el-descriptions-item>
          <el-descriptions-item label="差异字节">{{ diff.differingBytes.toLocaleString() }}</el-descriptions-item>
          <el-descriptions-item label="差异区间">{{ diff.ranges.length.toLocaleString() }}</el-descriptions-item>
        </el-descriptions>
        <div v-if="diff" class="range-list">
          <code v-for="range in diff.ranges.slice(0, 500)" :key="range.start">
            0x{{ range.start.toString(16).toUpperCase() }}–0x{{ range.end.toString(16).toUpperCase() }}
          </code>
          <p v-if="diff.ranges.length > 500">仅显示前 500 个差异区间。</p>
        </div>
        <el-empty v-else description="分别加载两个 Dump 后在后台线程计算差异" />
      </el-tab-pane>
    </el-tabs>
  </div>
</template>

<script setup lang="ts">
import { computed, onUnmounted, ref } from "vue";
import { ElMessage } from "element-plus";
import { open } from "@tauri-apps/plugin-dialog";
import { readFile } from "@tauri-apps/plugin-fs";
import { rawPreview, type DumpDiffSummary } from "../utils/dump";
import DiffWorker from "../workers/dumpCompare.worker?worker";

const activeTab = ref("viewer");
const viewMode = ref<"hex" | "raw">("hex");
const dumpData = ref<Uint8Array | null>(null);
const dumpPath = ref("");
const left = ref<Uint8Array | null>(null);
const right = ref<Uint8Array | null>(null);
const diff = ref<DumpDiffSummary | null>(null);
const worker = new DiffWorker();
worker.onmessage = (event: MessageEvent<DumpDiffSummary>) => (diff.value = event.data);
worker.onerror = () => ElMessage.error("Dump 对比线程执行失败");
onUnmounted(() => worker.terminate());

const preview = computed(() => (dumpData.value ? rawPreview(dumpData.value) : ""));
const totalRows = computed(() => Math.ceil((dumpData.value?.length ?? 0) / 16));
const visibleRows = computed(() => {
  const data = dumpData.value;
  if (!data) return [];
  const rows = [];
  for (let offset = 0; offset < Math.min(data.length, 16 * 4096); offset += 16) {
    const bytes = Array.from(data.subarray(offset, offset + 16));
    rows.push({
      offset,
      hex: bytes.map((byte) => byte.toString(16).padStart(2, "0").toUpperCase()).join(" "),
      ascii: bytes.map((byte) => (byte >= 32 && byte < 127 ? String.fromCharCode(byte) : ".")).join(""),
    });
  }
  return rows;
});

async function pick(): Promise<{ path: string; data: Uint8Array } | null> {
  try {
    const path = await open({ multiple: false, filters: [{ name: "Dump 文件", extensions: ["bin", "dump", "eml", "json"] }] });
    return path ? { path, data: await readFile(path) } : null;
  } catch (reason) {
    ElMessage.error(`读取 Dump 失败：${String(reason)}`);
    return null;
  }
}

async function loadDump() {
  const selected = await pick();
  if (selected) {
    dumpPath.value = selected.path;
    dumpData.value = selected.data;
  }
}

async function loadSide(side: "left" | "right") {
  const selected = await pick();
  if (!selected) return;
  if (side === "left") left.value = selected.data;
  else right.value = selected.data;
  if (left.value && right.value) {
    diff.value = null;
    worker.postMessage({ left: left.value.buffer.slice(0), right: right.value.buffer.slice(0) });
  }
}
</script>

<style scoped>
.dump-page { height: calc(100vh - 40px); overflow: auto; }
.toolbar { display: flex; align-items: center; gap: 12px; margin-bottom: 14px; }
.file-path { color: var(--el-text-color-secondary); margin-bottom: 10px; font-size: 12px; word-break: break-all; }
.hex-viewer, .raw-viewer { font: 13px/1.55 "Cascadia Mono", Consolas, monospace; background: #101318; color: #dbe4ee; padding: 14px; border-radius: 8px; overflow: auto; max-height: calc(100vh - 190px); white-space: pre-wrap; }
.hex-row { display: grid; grid-template-columns: 82px 390px 140px; }
.offset { color: #69a9ff; }.ascii { color: #70d6a8; }.truncated { margin-top: 12px; color: #f3c969; }
.range-list { display: flex; flex-wrap: wrap; gap: 8px; margin-top: 14px; }
.range-list code { padding: 5px 8px; background: var(--el-fill-color); border-radius: 5px; }
</style>
