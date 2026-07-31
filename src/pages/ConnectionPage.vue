<template>
  <div class="connection-page">
    <el-card shadow="hover">
      <template #header>
        <div class="card-header">
          <el-icon><Link /></el-icon>
          <span>设备连接</span>
          <el-tag :type="statusType" size="small" class="status-tag">
            {{ statusText }}
          </el-tag>
        </div>
      </template>

      <el-form label-width="100px" @submit.prevent>
        <el-form-item label="PM3 目录">
          <el-input
            v-model="store.pm3Dir"
            placeholder="Proxmark3 client 目录路径"
            clearable
          >
            <template #append>
              <el-button @click="pickDir">
                <el-icon><FolderOpened /></el-icon>
              </el-button>
            </template>
          </el-input>
          <div class="form-tip">包含 proxmark3.exe 和 pm3 脚本的目录</div>
        </el-form-item>

        <el-form-item label="串口">
          <el-select
            v-model="store.port"
            placeholder="选择串口"
            style="flex: 1"
            :loading="scanning"
          >
            <el-option
              v-for="p in store.ports"
              :key="p.name"
              :label="`${p.name} — ${p.description}`"
              :value="p.name"
            />
          </el-select>
          <el-button :loading="scanning" @click="scanPorts" style="margin-left: 8px">
            刷新
          </el-button>
        </el-form-item>

        <el-form-item>
          <el-button
            v-if="store.state !== 'Connected'"
            type="primary"
            :loading="store.state === 'Connecting'"
            :disabled="!store.pm3Dir || !store.port"
            @click="store.connect()"
          >
            {{ store.state === "Connecting" ? "连接中..." : "连接" }}
          </el-button>
          <el-button
            v-else
            type="danger"
            @click="store.disconnect()"
          >
            断开
          </el-button>
        </el-form-item>
      </el-form>

      <el-alert
        v-if="store.error"
        type="error"
        :title="store.error"
        show-icon
        closable
        @close="store.error = ''"
      />
    </el-card>

    <el-card shadow="hover" style="margin-top: 16px">
      <template #header>连接说明</template>
      <ul class="help-list">
        <li>PM3 目录应包含 <code>proxmark3.exe</code>（Windows）或 <code>pm3</code> 脚本（Linux/macOS）</li>
        <li>Windows 用户：确保 PM3 已通过 USB 连接，串口通常为 <code>COM3</code></li>
        <li>Linux 用户：可能需要 <code>sudo chmod 666 /dev/ttyACM0</code> 或加入 <code>dialout</code> 组</li>
      </ul>
    </el-card>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from "vue";
import { open } from "@tauri-apps/plugin-dialog";
import { useConnectionStore } from "../stores/connection";

const store = useConnectionStore();
const scanning = ref(false);

const statusType = computed(() => {
  switch (store.state) {
    case "Connected": return "success";
    case "Connecting": return "warning";
    default: return "info";
  }
});

const statusText = computed(() => {
  switch (store.state) {
    case "Connected": return "已连接";
    case "Connecting": return "连接中...";
    default: return "未连接";
  }
});

async function scanPorts() {
  scanning.value = true;
  try {
    await store.scanPorts();
  } finally {
    scanning.value = false;
  }
}

async function pickDir() {
  const selected = await open({
    directory: true,
    title: "选择 Proxmark3 client 目录",
  });
  if (selected) {
    store.pm3Dir = selected;
  }
}
</script>

<style scoped>
.connection-page {
  max-width: 700px;
}
.card-header {
  display: flex;
  align-items: center;
  gap: 8px;
  font-weight: 600;
}
.status-tag {
  margin-left: auto;
}
.form-tip {
  font-size: 12px;
  color: var(--el-text-color-secondary);
  margin-top: 4px;
}
.help-list {
  margin: 0;
  padding-left: 20px;
  font-size: 13px;
  color: var(--el-text-color-secondary);
  line-height: 1.8;
}
.help-list code {
  background: var(--el-fill-color-light);
  padding: 1px 4px;
  border-radius: 3px;
  font-size: 12px;
}
</style>
