import { defineStore } from "pinia";
import { ref } from "vue";
import { invoke } from "@tauri-apps/api/core";

export const useTerminalStore = defineStore("terminal", () => {
  const history = ref<string[]>([]);
  const historyIndex = ref(-1);

  async function sendCommand(cmd: string) {
    history.value.push(cmd);
    historyIndex.value = history.value.length;
    await invoke("send_command", { command: cmd });
  }

  return { history, historyIndex, sendCommand };
});
