<script setup lang="ts">
import { ref, onMounted, onBeforeUnmount, nextTick } from "vue";
import { Terminal } from "@xterm/xterm";
import { FitAddon } from "@xterm/addon-fit";
import { WebLinksAddon } from "@xterm/addon-web-links";
import "@xterm/xterm/css/xterm.css";

const terminalContainer = ref<HTMLDivElement | null>(null);
let terminal: Terminal | null = null;
let fitAddon: FitAddon | null = null;

function initTerminal() {
  if (!terminalContainer.value) return;

  terminal = new Terminal({
    cursorBlink: true,
    fontSize: 14,
    fontFamily: '"Cascadia Code", "Fira Code", "Consolas", monospace',
    theme: {
      background: "#1e1e1e",
      foreground: "#d4d4d4",
      cursor: "#d4d4d4",
      selectionBackground: "#264f78",
      black: "#1e1e1e",
      red: "#f44747",
      green: "#6a9955",
      yellow: "#d7ba7d",
      blue: "#569cd6",
      magenta: "#c586c0",
      cyan: "#4ec9b0",
      white: "#d4d4d4",
    },
  });

  fitAddon = new FitAddon();
  terminal.loadAddon(fitAddon);
  terminal.loadAddon(new WebLinksAddon());

  terminal.open(terminalContainer.value);
  fitAddon.fit();

  terminal.writeln("\x1b[1;36mPM3 GUI Terminal\x1b[0m");
  terminal.writeln("Type commands to interact with Proxmark3.\n");
  terminal.write("\x1b[1;32m> \x1b[0m");
}

function handleResize() {
  fitAddon?.fit();
}

onMounted(async () => {
  await nextTick();
  initTerminal();
  window.addEventListener("resize", handleResize);
});

onBeforeUnmount(() => {
  window.removeEventListener("resize", handleResize);
  terminal?.dispose();
});
</script>

<template>
  <div class="terminal-view">
    <el-card class="terminal-card">
      <template #header>
        <div class="card-header">
          <span>Proxmark3 Terminal</span>
          <el-tag type="success" size="small">Ready</el-tag>
        </div>
      </template>
      <div ref="terminalContainer" class="terminal-container" />
    </el-card>
  </div>
</template>

<style scoped>
.terminal-view {
  height: 100%;
  display: flex;
  flex-direction: column;
}

.terminal-card {
  flex: 1;
  display: flex;
  flex-direction: column;
}

.terminal-card :deep(.el-card__body) {
  flex: 1;
  padding: 0;
  overflow: hidden;
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.terminal-container {
  width: 100%;
  height: 100%;
  min-height: 400px;
}
</style>
