<template>
  <div class="protocol-panel">
    <h3>{{ protocol.label }}</h3>
    <div v-for="group in protocol.commands" :key="group.group" class="cmd-group">
      <h4 class="group-title">{{ group.group }}</h4>
      <div class="cmd-grid">
        <el-card
          v-for="cmd in group.items"
          :key="cmd.label"
          shadow="hover"
          class="cmd-card"
          @click="handleExecute(cmd)"
        >
          <strong>{{ cmd.label }}</strong>
          <p v-if="cmd.description" class="cmd-desc">{{ cmd.description }}</p>
        </el-card>
      </div>
    </div>

    <!-- Parameter dialog -->
    <el-dialog v-model="showParams" title="参数" width="400px">
      <el-form v-if="activeCmd" label-width="80px">
        <el-form-item v-for="p in activeCmd.params" :key="p.name" :label="p.label">
          <el-select v-if="p.type === 'select'" v-model="params[p.name]">
            <el-option v-for="opt in p.options" :key="opt" :label="opt" :value="opt" />
          </el-select>
          <el-input v-else v-model="params[p.name]" :placeholder="p.type === 'hex' ? 'FF FF FF FF' : ''" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="showParams = false">取消</el-button>
        <el-button type="primary" @click="executeWithParams">执行</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive } from "vue";
import type { ProtocolDef, CommandDef } from "../config/protocols";

defineProps<{ protocol: ProtocolDef }>();
const emit = defineEmits<{ (e: "execute", cmd: string): void }>();

const showParams = ref(false);
const activeCmd = ref<CommandDef | null>(null);
const params = reactive<Record<string, string>>({});

function handleExecute(cmd: CommandDef) {
  if (cmd.params && cmd.params.length > 0) {
    activeCmd.value = cmd;
    // Initialize params with defaults
    for (const p of cmd.params) {
      params[p.name] = p.default || "";
    }
    showParams.value = true;
  } else {
    const cmdStr = typeof cmd.cmd === "function" ? cmd.cmd({}) : cmd.cmd;
    emit("execute", cmdStr);
  }
}

function executeWithParams() {
  if (!activeCmd.value) return;
  const cmdStr = typeof activeCmd.value.cmd === "function"
    ? activeCmd.value.cmd({ ...params })
    : activeCmd.value.cmd;
  emit("execute", cmdStr);
  showParams.value = false;
}
</script>

<style scoped>
.protocol-panel { padding: 8px; }
.cmd-group { margin-bottom: 20px; }
.group-title { color: var(--el-text-color-secondary); font-size: 13px; margin-bottom: 8px; }
.cmd-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(160px, 1fr)); gap: 12px; }
.cmd-card { cursor: pointer; text-align: center; }
.cmd-card:hover { border-color: var(--el-color-primary); }
.cmd-desc { font-size: 12px; color: var(--el-text-color-secondary); margin: 4px 0 0; }
</style>
