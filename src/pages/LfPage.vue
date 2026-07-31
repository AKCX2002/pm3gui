<template>
  <div class="operations-page">
    <div class="page-heading">
      <div><h2>LF 低频</h2><p>稳定版提供识别、HID 模拟与 T55xx 擦除。</p></div>
      <el-tag :type="connection.connected ? 'success' : 'info'">{{ connection.connected ? "设备已连接" : "请先连接设备" }}</el-tag>
    </div>
    <el-card>
      <template #header>识别</template>
      <el-button type="primary" :disabled="!connection.connected" :loading="running" @click="run({ kind: 'search_lf' })">搜索 LF 卡</el-button>
    </el-card>
    <el-card>
      <template #header>HID 模拟</template>
      <div class="button-row">
        <el-input v-model="cardId" maxlength="32" placeholder="十六进制卡号" />
        <el-button type="warning" :disabled="!connection.connected || !cardId" :loading="running" @click="run({ kind: 'simulate_hid', card_id: cardId })">开始模拟</el-button>
      </div>
    </el-card>
    <el-card>
      <template #header>T55xx</template>
      <el-alert type="error" :closable="false" title="擦除会破坏卡片现有数据，执行前必须输入 EXECUTE。" />
      <el-button class="wipe-button" type="danger" :disabled="!connection.connected" :loading="running" @click="run({ kind: 'wipe_t55xx' })">擦除 T55xx</el-button>
    </el-card>
  </div>
</template>

<script setup lang="ts">
import { ref } from "vue";
import { useConnectionStore } from "../stores/connection";
import { useOperation } from "../composables/useOperation";
const connection = useConnectionStore();
const { running, run } = useOperation();
const cardId = ref("");
</script>

<style scoped>
.operations-page { display: grid; gap: 16px; max-width: 800px; }
.page-heading { display: flex; align-items: center; justify-content: space-between; }
.page-heading p { color: var(--el-text-color-secondary); margin-top: 5px; }
.button-row { display: flex; gap: 10px; }
.wipe-button { margin-top: 14px; }
</style>
