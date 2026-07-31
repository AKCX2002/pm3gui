import { ref } from "vue";
import { defineStore } from "pinia";
import type { UnlistenFn } from "@tauri-apps/api/event";
import { pm3Client } from "../api/pm3Client";
import type { OutputEntry } from "../types/pm3";

export const useTerminalStore = defineStore("terminal", () => {
  const entries = ref<OutputEntry[]>([]);
  const droppedCount = ref(0);
  const history = ref<string[]>([]);
  const initialized = ref(false);
  let unlisten: UnlistenFn | null = null;

  async function initialize() {
    if (initialized.value) return;
    initialized.value = true;
    const snapshot = await pm3Client.outputSnapshot();
    entries.value = snapshot.entries;
    droppedCount.value = snapshot.droppedCount;
    unlisten = await pm3Client.onOutput((entry) => {
      if (entries.value.some((item) => item.sequence === entry.sequence)) return;
      entries.value.push(entry);
      if (entries.value.length > 5_000) entries.value.splice(0, entries.value.length - 5_000);
    });
  }

  async function sendCommand(command: string) {
    const normalized = command.trim();
    if (!normalized) return;
    history.value.push(normalized);
    await pm3Client.send(normalized);
  }

  function clear() {
    entries.value = [];
    droppedCount.value = 0;
  }

  function dispose() {
    unlisten?.();
    unlisten = null;
    initialized.value = false;
  }

  return { entries, droppedCount, history, initialize, sendCommand, clear, dispose };
});
