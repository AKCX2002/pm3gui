<template>
  <div class="settings-page">
    <el-card>
      <template #header><div class="card-header"><el-icon><Setting /></el-icon><span>设置</span></div></template>
      <el-form label-width="130px">
        <el-form-item label="暗色模式"><el-switch v-model="settings.dark" /></el-form-item>
        <el-form-item label="PM3 Client 目录">
          <el-input v-model="connection.pm3Dir" readonly>
            <template #append><el-button @click="pickDir"><el-icon><FolderOpened /></el-icon></el-button></template>
          </el-input>
        </el-form-item>
        <el-form-item label="终端字体大小">
          <el-input-number v-model="settings.terminalFontSize" :min="10" :max="24" />
        </el-form-item>
      </el-form>
      <el-alert type="info" :closable="false" title="设置会自动保存在本机；不会修改所选 PM3 Client 目录。" />
    </el-card>
    <el-card>
      <template #header>关于与诊断</template>
      <el-descriptions :column="1" border>
        <el-descriptions-item label="版本">0.1.0 RC</el-descriptions-item>
        <el-descriptions-item label="平台">Windows 10 / 11 x64</el-descriptions-item>
        <el-descriptions-item label="会话模型">单设备、单 PM3 Client 进程</el-descriptions-item>
        <el-descriptions-item label="当前状态">{{ connection.state }}</el-descriptions-item>
        <el-descriptions-item label="会话 ID">{{ connection.snapshot.sessionId ?? "—" }}</el-descriptions-item>
      </el-descriptions>
      <el-button class="diagnostic-button" @click="exportDiagnostics">导出脱敏诊断 JSON</el-button>
      <p class="diagnostic-note">诊断不包含终端命令、密钥、Dump 内容、Client 路径或环境变量。</p>
    </el-card>
  </div>
</template>

<script setup lang="ts">
import { open, save } from "@tauri-apps/plugin-dialog";
import { writeTextFile } from "@tauri-apps/plugin-fs";
import { ElMessage } from "element-plus";
import { useConnectionStore } from "../stores/connection";
import { useSettingsStore } from "../stores/settings";
import { useTerminalStore } from "../stores/terminal";
const connection = useConnectionStore();
const settings = useSettingsStore();
const terminal = useTerminalStore();
async function pickDir() {
  const selected = await open({ directory: true, title: "选择 PM3 Client 目录" });
  if (selected) {
    connection.pm3Dir = selected;
    localStorage.setItem("pm3gui-client-dir", selected);
  }
}
async function exportDiagnostics() {
  const target = await save({ defaultPath: "pm3gui-diagnostics.json", filters: [{ name: "JSON", extensions: ["json"] }] });
  if (!target) return;
  const report = {
    schemaVersion: 1,
    generatedAt: new Date().toISOString(),
    guiVersion: "0.1.0-rc",
    platform: navigator.userAgent,
    session: {
      state: connection.snapshot.state,
      clientVersion: connection.snapshot.clientVersion,
      firmwareVersion: connection.snapshot.firmwareVersion,
      lastErrorCode: connection.snapshot.lastError?.code ?? null,
    },
    output: { droppedCount: terminal.droppedCount },
  };
  await writeTextFile(target, JSON.stringify(report, null, 2));
  ElMessage.success("诊断已导出");
}
</script>

<style scoped>
.settings-page { max-width: 760px; display: grid; gap: 16px; }
.card-header { display: flex; align-items: center; gap: 8px; font-weight: 600; }
.diagnostic-button { margin-top: 16px; }
.diagnostic-note { margin-top: 8px; font-size: 12px; color: var(--el-text-color-secondary); }
</style>
