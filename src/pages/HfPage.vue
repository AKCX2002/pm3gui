<template>
  <div class="operations-page">
    <div class="page-heading">
      <div><h2>HF 高频</h2><p>稳定版仅提供参数可验证的 MIFARE Classic 操作。</p></div>
      <el-tag :type="connection.connected ? 'success' : 'info'">
        {{ connection.connected ? "设备已连接" : "请先连接设备" }}
      </el-tag>
    </div>

    <el-card>
      <template #header>识别与读取</template>
      <div class="button-row">
        <el-button type="primary" :disabled="!connection.connected" :loading="running" @click="run({ kind: 'search_hf' })">搜索 HF 卡</el-button>
        <el-button :disabled="!connection.connected" :loading="running" @click="run({ kind: 'mifare_info' })">读取 MIFARE 信息</el-button>
        <el-select v-model="size" style="width: 110px">
          <el-option label="1K" value="k1" /><el-option label="2K" value="k2" /><el-option label="4K" value="k4" />
        </el-select>
        <el-button :disabled="!connection.connected" :loading="running" @click="run({ kind: 'mifare_dump', size })">读取 Dump</el-button>
        <el-button :disabled="!connection.connected" :loading="running" @click="run({ kind: 'mifare_autopwn', size })">AutoPwn</el-button>
      </div>
    </el-card>

    <el-card>
      <template #header>块读写</template>
      <el-form label-width="90px" class="operation-form">
        <el-form-item label="块号"><el-input-number v-model="block" :min="0" :max="255" /></el-form-item>
        <el-form-item label="密钥类型"><el-radio-group v-model="keyType"><el-radio-button value="a">Key A</el-radio-button><el-radio-button value="b">Key B</el-radio-button></el-radio-group></el-form-item>
        <el-form-item label="密钥"><el-input v-model="key" maxlength="12" placeholder="12 位十六进制" /></el-form-item>
        <el-form-item label="块数据"><el-input v-model="data" maxlength="32" placeholder="写入时需要 32 位十六进制" /></el-form-item>
        <el-form-item>
          <el-button :disabled="!connection.connected" :loading="running" @click="readBlock">读取块</el-button>
          <el-button type="danger" :disabled="!connection.connected" :loading="running" @click="writeBlock">写入块</el-button>
        </el-form-item>
      </el-form>
      <el-alert type="warning" :closable="false" title="写块会要求二次确认；块 0 和扇区尾块会要求输入 EXECUTE。" />
    </el-card>

    <el-card>
      <template #header>恢复 Dump</template>
      <div class="button-row">
        <el-input v-model="restoreFile" readonly placeholder="选择要恢复的 Dump 文件" />
        <el-button @click="pickRestore">选择文件</el-button>
        <el-button type="danger" :disabled="!connection.connected || !restoreFile" :loading="running" @click="run({ kind: 'restore_mifare', size, file: restoreFile })">恢复到卡片</el-button>
      </div>
    </el-card>
  </div>
</template>

<script setup lang="ts">
import { ref } from "vue";
import { open } from "@tauri-apps/plugin-dialog";
import { useConnectionStore } from "../stores/connection";
import { useOperation } from "../composables/useOperation";

const connection = useConnectionStore();
const { running, run } = useOperation();
const size = ref<"k1" | "k2" | "k4">("k1");
const block = ref(4);
const keyType = ref<"a" | "b">("a");
const key = ref("FFFFFFFFFFFF");
const data = ref("");
const restoreFile = ref("");

const readBlock = () => run({ kind: "read_mifare_block", block: block.value, key_type: keyType.value, key: key.value });
const writeBlock = () => run({ kind: "write_mifare_block", block: block.value, key_type: keyType.value, key: key.value, data: data.value });
async function pickRestore() {
  const selected = await open({ multiple: false, filters: [{ name: "PM3 Dump", extensions: ["bin", "dump", "eml"] }] });
  if (selected) restoreFile.value = selected;
}
</script>

<style scoped>
.operations-page { display: grid; gap: 16px; max-width: 900px; }
.page-heading { display: flex; align-items: center; justify-content: space-between; }
.page-heading p { color: var(--el-text-color-secondary); margin-top: 5px; }
.button-row { display: flex; flex-wrap: wrap; align-items: center; gap: 10px; }
.operation-form { max-width: 620px; }
</style>
