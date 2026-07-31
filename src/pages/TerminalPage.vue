<template>
  <div class="terminal-page">
    <div class="terminal-toolbar">
      <el-button size="small" @click="clearTerminal">
        <el-icon><Delete /></el-icon> 清屏
      </el-button>
      <el-tag v-if="connectionStore.state === 'Connected'" type="success" size="small">
        已连接
      </el-tag>
      <el-tag v-else type="info" size="small">未连接</el-tag>
    </div>
    <div ref="termRef" class="terminal-container"></div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, onUnmounted } from "vue";
import { Terminal } from "xterm";
import { FitAddon } from "xterm-addon-fit";
import { listen } from "@tauri-apps/api/event";
import "xterm/css/xterm.css";
import { useTerminalStore } from "../stores/terminal";
import { useConnectionStore } from "../stores/connection";

const termRef = ref<HTMLDivElement>();
const terminalStore = useTerminalStore();
const connectionStore = useConnectionStore();

const term = new Terminal({
  cursorBlink: true,
  fontSize: 14,
  fontFamily: "'Cascadia Code', Consolas, 'Courier New', monospace",
  theme: {
    background: "#1e1e1e",
    foreground: "#d4d4d4",
    cursor: "#d4d4d4",
    selectionBackground: "#264f78",
  },
  allowTransparency: true,
});

const fitAddon = new FitAddon();
term.loadAddon(fitAddon);

let currentLine = "";
let unlisten: (() => void) | null = null;

onMounted(async () => {
  if (termRef.value) {
    term.open(termRef.value);
    fitAddon.fit();
    term.focus();

    // Handle resize
    const resizeObserver = new ResizeObserver(() => fitAddon.fit());
    resizeObserver.observe(termRef.value);
  }

  // Prompt
  term.write("\x1b[36mpm3>\x1b[0m ");

  // Handle keyboard input
  term.onKey(({ key, domEvent }) => {
    const code = domEvent.keyCode;

    if (code === 13) {
      // Enter
      term.writeln("");
      if (currentLine.trim()) {
        terminalStore.sendCommand(currentLine.trim());
      }
      currentLine = "";
      term.write("\x1b[36mpm3>\x1b[0m ");
    } else if (code === 8) {
      // Backspace
      if (currentLine.length > 0) {
        currentLine = currentLine.slice(0, -1);
        term.write("\b \b");
      }
    } else if (key.length === 1 && !domEvent.ctrlKey) {
      currentLine += key;
      term.write(key);
    }
  });

  // Listen for PM3 output
  unlisten = await listen<string>("pm3-output", (event) => {
    // Remove ANSI escape codes if needed, or keep them for color
    term.writeln(event.payload);
  });
});

onUnmounted(() => {
  unlisten?.();
  term.dispose();
});

function clearTerminal() {
  term.clear();
  term.write("\x1b[36mpm3>\x1b[0m ");
}
</script>

<style scoped>
.terminal-page {
  display: flex;
  flex-direction: column;
  height: calc(100vh - 40px);
}
.terminal-toolbar {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 8px 0;
  border-bottom: 1px solid var(--el-border-color-light);
  margin-bottom: 8px;
}
.terminal-container {
  flex: 1;
  border-radius: 8px;
  overflow: hidden;
}
.terminal-container :deep(.xterm) {
  padding: 12px;
  border-radius: 8px;
}
</style>
