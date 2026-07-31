<script setup lang="ts">
import { ref, onMounted } from "vue";
import { invoke } from "@tauri-apps/api/core";

const greetMsg = ref("");
const name = ref("");

async function greet() {
  greetMsg.value = await invoke<string>("greet", { name: name.value });
}

onMounted(async () => {
  // Check for connected Proxmark3 devices
  try {
    const result = await invoke<string>("check_pm3_devices");
    console.log("PM3 devices:", result);
  } catch (e) {
    console.warn("Could not check PM3 devices:", e);
  }
});
</script>

<template>
  <div class="home">
    <el-card class="welcome-card">
      <template #header>
        <div class="card-header">
          <span>Welcome to PM3 GUI</span>
        </div>
      </template>
      <p>A modern Tauri + Vue 3 frontend for Proxmark3.</p>
      <el-divider />
      <el-space>
        <el-input v-model="name" placeholder="Enter your name" style="width: 240px" />
        <el-button type="primary" @click="greet">Greet</el-button>
      </el-space>
      <p v-if="greetMsg" class="greet-msg">{{ greetMsg }}</p>
    </el-card>

    <el-row :gutter="20" class="feature-cards">
      <el-col :span="8">
        <el-card shadow="hover">
          <template #header>Device Status</template>
          <p>Connect and manage Proxmark3 devices.</p>
        </el-card>
      </el-col>
      <el-col :span="8">
        <el-card shadow="hover">
          <template #header>Card Operations</template>
          <p>Read, write, and clone RFID cards.</p>
        </el-card>
      </el-col>
      <el-col :span="8">
        <el-card shadow="hover">
          <template #header>Terminal</template>
          <p>Direct pm3 client command interface.</p>
        </el-card>
      </el-col>
    </el-row>
  </div>
</template>

<style scoped>
.home {
  max-width: 900px;
  margin: 0 auto;
}

.welcome-card {
  margin-bottom: 24px;
}

.card-header {
  font-size: 18px;
  font-weight: 600;
}

.greet-msg {
  margin-top: 12px;
  color: var(--el-color-success);
}

.feature-cards {
  margin-top: 20px;
}
</style>
