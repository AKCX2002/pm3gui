import { defineStore } from "pinia";
import { ref } from "vue";
import { invoke } from "@tauri-apps/api/core";

export type Pm3State = "Disconnected" | "Connecting" | "Connected";

export const useConnectionStore = defineStore("connection", () => {
  const state = ref<Pm3State>("Disconnected");
  const pm3Dir = ref("");
  const port = ref("");
  const ports = ref<{ name: string; description: string }[]>([]);
  const error = ref("");

  async function scanPorts() {
    ports.value = await invoke("get_ports");
  }

  async function connect() {
    error.value = "";
    state.value = "Connecting";
    try {
      const result: { success: boolean; error: string | null } = await invoke("connect", {
        pm3Dir: pm3Dir.value,
        port: port.value,
      });
      if (!result.success) {
        error.value = result.error || "连接失败";
        state.value = "Disconnected";
      }
    } catch (e: any) {
      error.value = String(e);
      state.value = "Disconnected";
    }
  }

  async function disconnect() {
    await invoke("disconnect");
    state.value = "Disconnected";
  }

  return { state, pm3Dir, port, ports, error, scanPorts, connect, disconnect };
});
