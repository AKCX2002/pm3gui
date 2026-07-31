<template>
  <div class="terminal-page">
    <div class="terminal-toolbar">
      <el-button size="small" @click="clearTerminal"><el-icon><Delete /></el-icon> 清屏</el-button>
      <el-tag :type="connection.connected ? 'success' : 'info'" size="small">
        {{ connection.connected ? "已连接" : "未连接" }}
      </el-tag>
      <span v-if="terminal.droppedCount" class="drop-note">
        已丢弃 {{ terminal.droppedCount }} 条较早输出
      </span>
    </div>
    <div ref="termRef" class="terminal-container"></div>
  </div>
</template>

<script setup lang="ts">
import { nextTick, onMounted, onUnmounted, ref, watch } from "vue";
import { ElMessage } from "element-plus";
import { Terminal } from "@xterm/xterm";
import { FitAddon } from "@xterm/addon-fit";
import "@xterm/xterm/css/xterm.css";
import { useTerminalStore } from "../stores/terminal";
import { useConnectionStore } from "../stores/connection";
import { useSettingsStore } from "../stores/settings";
import { errorText } from "../api/pm3Client";

const termRef = ref<HTMLDivElement>();
const terminal = useTerminalStore();
const connection = useConnectionStore();
const settings = useSettingsStore();
const term = new Terminal({
  cursorBlink: true,
  convertEol: true,
  fontSize: settings.terminalFontSize,
  fontFamily: "'Cascadia Mono', Consolas, monospace",
  theme: { background: "#101318", foreground: "#dbe4ee", cursor: "#62d4a3" },
});
const fit = new FitAddon();
term.loadAddon(fit);
let currentLine = "";
let historyIndex = 0;
let renderedSequence = 0;
let resizeObserver: ResizeObserver | null = null;

function replaceInput(value: string) {
  while (currentLine.length) {
    term.write("\b \b");
    currentLine = currentLine.slice(0, -1);
  }
  currentLine = value;
  term.write(value);
}

onMounted(async () => {
  await terminal.initialize();
  term.open(termRef.value!);
  resizeObserver = new ResizeObserver(() => fit.fit());
  resizeObserver.observe(termRef.value!);
  await nextTick();
  fit.fit();
  for (const entry of terminal.entries) {
    term.write(entry.text);
    renderedSequence = Math.max(renderedSequence, entry.sequence);
  }
  historyIndex = terminal.history.length;
  term.onKey(async ({ key, domEvent }) => {
    if (domEvent.key === "Enter") {
      term.write("\r\n");
      const submitted = currentLine;
      currentLine = "";
      historyIndex = terminal.history.length + 1;
      try {
        await terminal.sendCommand(submitted);
      } catch (reason) {
        ElMessage.error(errorText(reason));
      }
    } else if (domEvent.key === "Backspace" && currentLine.length) {
      currentLine = currentLine.slice(0, -1);
      term.write("\b \b");
    } else if (domEvent.key === "ArrowUp") {
      if (terminal.history.length) {
        historyIndex = Math.max(0, historyIndex - 1);
        replaceInput(terminal.history[historyIndex] ?? "");
      }
    } else if (domEvent.key === "ArrowDown") {
      historyIndex = Math.min(terminal.history.length, historyIndex + 1);
      replaceInput(terminal.history[historyIndex] ?? "");
    } else if (key.length === 1 && !domEvent.ctrlKey && !domEvent.altKey) {
      currentLine += key;
      term.write(key);
    }
  });
});

watch(
  () => terminal.entries.length,
  () => {
    for (const entry of terminal.entries) {
      if (entry.sequence > renderedSequence) {
        term.write(entry.text);
        renderedSequence = entry.sequence;
      }
    }
  },
);

watch(
  () => settings.terminalFontSize,
  (fontSize) => {
    term.options.fontSize = fontSize;
    fit.fit();
  },
);

onUnmounted(() => {
  resizeObserver?.disconnect();
  term.dispose();
});

function clearTerminal() {
  terminal.clear();
  term.clear();
}
</script>

<style scoped>
.terminal-page { display: flex; flex-direction: column; height: calc(100vh - 40px); }
.terminal-toolbar { display: flex; align-items: center; gap: 12px; padding-bottom: 10px; }
.terminal-container { flex: 1; min-height: 0; border-radius: 10px; overflow: hidden; background: #101318; }
.terminal-container :deep(.xterm) { padding: 12px; }
.drop-note { margin-left: auto; color: var(--el-text-color-secondary); font-size: 12px; }
</style>
