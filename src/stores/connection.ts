import { computed, ref } from "vue";
import { defineStore } from "pinia";
import type { UnlistenFn } from "@tauri-apps/api/event";
import { errorText, pm3Client } from "../api/pm3Client";
import type { PortInfo, SessionSnapshot } from "../types/pm3";

const disconnected: SessionSnapshot = {
  sessionId: null,
  state: "disconnected",
  clientVersion: null,
  firmwareVersion: null,
  lastError: null,
};

export const useConnectionStore = defineStore("connection", () => {
  const snapshot = ref<SessionSnapshot>(disconnected);
  const pm3Dir = ref(localStorage.getItem("pm3gui-client-dir") ?? "");
  const port = ref("");
  const ports = ref<PortInfo[]>([]);
  const error = ref("");
  const initialized = ref(false);
  let unlisten: UnlistenFn | null = null;

  const state = computed(() => snapshot.value.state);
  const connected = computed(() => state.value === "connected");
  const connecting = computed(() =>
    ["validating", "starting", "handshaking"].includes(state.value),
  );

  async function initialize() {
    if (initialized.value) return;
    initialized.value = true;
    snapshot.value = await pm3Client.snapshot();
    unlisten = await pm3Client.onState((next) => {
      snapshot.value = next;
      if (next.lastError) error.value = errorText(next.lastError);
    });
  }

  async function scanPorts() {
    error.value = "";
    try {
      ports.value = await pm3Client.ports();
      if (!ports.value.some((item) => item.name === port.value)) {
        port.value = ports.value[0]?.name ?? "";
      }
    } catch (reason) {
      error.value = errorText(reason);
    }
  }

  async function connect() {
    error.value = "";
    try {
      localStorage.setItem("pm3gui-client-dir", pm3Dir.value);
      snapshot.value = await pm3Client.connect(pm3Dir.value, port.value);
    } catch (reason) {
      error.value = errorText(reason);
    }
  }

  async function disconnect() {
    error.value = "";
    try {
      snapshot.value = await pm3Client.disconnect();
    } catch (reason) {
      error.value = errorText(reason);
    }
  }

  function dispose() {
    unlisten?.();
    unlisten = null;
    initialized.value = false;
  }

  return {
    snapshot,
    state,
    connected,
    connecting,
    pm3Dir,
    port,
    ports,
    error,
    initialize,
    scanPorts,
    connect,
    disconnect,
    dispose,
  };
});
