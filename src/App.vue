<template>
  <div class="app-layout">
    <AppSidebar />
    <main class="app-main"><router-view /></main>
  </div>
</template>

<script setup lang="ts">
import { onBeforeUnmount, onMounted } from "vue";
import AppSidebar from "./components/AppSidebar.vue";
import { useConnectionStore } from "./stores/connection";
import { useTerminalStore } from "./stores/terminal";

const connection = useConnectionStore();
const terminal = useTerminalStore();

onMounted(async () => {
  await Promise.all([connection.initialize(), terminal.initialize()]);
});

onBeforeUnmount(() => {
  connection.dispose();
  terminal.dispose();
});
</script>

<style>
body { margin: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }
.app-layout { display: flex; height: 100vh; }
.app-main { flex: 1; min-width: 0; overflow: auto; padding: 20px; background: var(--el-bg-color-page); }
</style>
