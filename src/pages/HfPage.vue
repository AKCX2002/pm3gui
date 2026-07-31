<template>
  <el-container style="height: calc(100vh - 40px)">
    <el-aside width="200px" style="border-right: 1px solid var(--el-border-color-light)">
      <el-menu :default-active="activeProto" @select="handleSelect">
        <el-menu-item v-for="p in hfProtocols" :key="p.id" :index="p.id">
          {{ p.label }}
        </el-menu-item>
      </el-menu>
    </el-aside>
    <el-main>
      <ProtocolPanel
        v-if="activeProtocol"
        :protocol="activeProtocol"
        @execute="runCmd"
      />
    </el-main>
  </el-container>
</template>

<script setup lang="ts">
import { ref, computed } from "vue";
import { hfProtocols } from "../config/protocols";
import { useTerminalStore } from "../stores/terminal";
import ProtocolPanel from "../components/ProtocolPanel.vue";

const store = useTerminalStore();
const activeProto = ref(hfProtocols[0]?.id ?? "");
const activeProtocol = computed(() => hfProtocols.find(p => p.id === activeProto.value));

function handleSelect(id: string) { activeProto.value = id; }
function runCmd(cmd: string) { store.sendCommand(cmd); }
</script>
