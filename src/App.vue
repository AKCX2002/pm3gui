<template>
  <div class="app-layout">
    <AppSidebar />
    <main class="app-main"><router-view /></main>
  </div>
</template>

<script setup lang="ts">
import AppSidebar from "./components/AppSidebar.vue";
</script>

<style>
body { margin: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }
.app-layout { display: flex; height: 100vh; }
.app-main { flex: 1; overflow: auto; padding: 20px; background: var(--el-bg-color-page); }
</style>
