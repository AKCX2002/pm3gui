<template>
  <div class="settings-page">
    <el-card shadow="hover">
      <template #header>
        <div class="card-header">
          <el-icon><Setting /></el-icon>
          <span>设置</span>
        </div>
      </template>

      <el-form label-width="120px">
        <el-form-item label="暗色模式">
          <el-switch v-model="isDark" @change="toggleDark" />
        </el-form-item>

        <el-form-item label="PM3 默认目录">
          <el-input v-model="pm3Dir" placeholder="默认 Proxmark3 client 目录">
            <template #append>
              <el-button @click="pickDir">
                <el-icon><FolderOpened /></el-icon>
              </el-button>
            </template>
          </el-input>
        </el-form-item>

        <el-form-item label="终端字体大小">
          <el-input-number v-model="fontSize" :min="10" :max="24" />
        </el-form-item>

        <el-form-item>
          <el-button type="primary" @click="save">保存设置</el-button>
        </el-form-item>
      </el-form>
    </el-card>

    <el-card shadow="hover" style="margin-top: 16px">
      <template #header>关于</template>
      <p><strong>PM3 GUI</strong> — Proxmark3 图形界面</p>
      <p>版本：0.1.0</p>
      <p>基于 Tauri 2 + Vue 3 + Element Plus</p>
    </el-card>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from "vue";
import { open } from "@tauri-apps/plugin-dialog";
import { ElMessage } from "element-plus";

const isDark = ref(false);
const pm3Dir = ref("");
const fontSize = ref(14);

onMounted(() => {
  // Load saved settings
  const saved = localStorage.getItem("pm3gui-settings");
  if (saved) {
    try {
      const s = JSON.parse(saved);
      isDark.value = s.isDark ?? false;
      pm3Dir.value = s.pm3Dir ?? "";
      fontSize.value = s.fontSize ?? 14;
      if (isDark.value) document.documentElement.classList.add("dark");
    } catch {}
  }
});

function toggleDark() {
  document.documentElement.classList.toggle("dark", isDark.value);
}

async function pickDir() {
  const selected = await open({
    directory: true,
    title: "选择默认 PM3 目录",
  });
  if (selected) pm3Dir.value = selected;
}

function save() {
  localStorage.setItem("pm3gui-settings", JSON.stringify({
    isDark: isDark.value,
    pm3Dir: pm3Dir.value,
    fontSize: fontSize.value,
  }));
  ElMessage.success("设置已保存");
}
</script>

<style scoped>
.settings-page { max-width: 600px; }
.card-header { display: flex; align-items: center; gap: 8px; font-weight: 600; }
</style>
