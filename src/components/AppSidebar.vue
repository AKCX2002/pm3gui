<template>
  <el-menu :default-active="route.path" :collapse="collapsed" router class="app-sidebar">
    <div class="sidebar-header">
      <span class="logo-icon">📡</span>
      <span v-show="!collapsed" class="title">PM3 GUI</span>
    </div>
    <el-menu-item index="/connection"><el-icon><Link /></el-icon><span>连接</span></el-menu-item>
    <el-menu-item index="/terminal"><el-icon><Monitor /></el-icon><span>终端</span></el-menu-item>
    <el-sub-menu index="hf-group">
      <template #title><el-icon><Connection /></el-icon><span>📡 HF 高频</span></template>
      <el-menu-item index="/hf">全部协议</el-menu-item>
    </el-sub-menu>
    <el-sub-menu index="lf-group">
      <template #title><el-icon><Connection /></el-icon><span>📻 LF 低频</span></template>
      <el-menu-item index="/lf">全部协议</el-menu-item>
    </el-sub-menu>
    <el-menu-item index="/dump"><el-icon><FolderOpened /></el-icon><span>Dump</span></el-menu-item>
    <el-menu-item index="/data"><el-icon><DataAnalysis /></el-icon><span>数据</span></el-menu-item>
    <el-menu-item index="/trace"><el-icon><Timer /></el-icon><span>Trace</span></el-menu-item>
    <el-menu-item index="/nfc"><el-icon><Iphone /></el-icon><span>NFC</span></el-menu-item>
    <el-menu-item index="/script"><el-icon><Document /></el-icon><span>脚本</span></el-menu-item>
    <el-menu-item index="/settings"><el-icon><Setting /></el-icon><span>设置</span></el-menu-item>
    <div class="sidebar-footer" @click="collapsed = !collapsed">
      <el-icon><DArrowLeft v-if="!collapsed" /><DArrowRight v-else /></el-icon>
      <span v-show="!collapsed">收起菜单</span>
    </div>
  </el-menu>
</template>

<script setup lang="ts">
import { ref } from "vue";
import { useRoute } from "vue-router";
const route = useRoute();
const collapsed = ref(false);
</script>

<style scoped>
.app-sidebar { height: 100vh; border-right: 1px solid var(--el-border-color-light); }
.sidebar-header { display: flex; align-items: center; gap: 10px; padding: 16px; border-bottom: 1px solid var(--el-border-color-light); }
.logo-icon { font-size: 24px; }
.title { font-size: 16px; font-weight: bold; color: var(--el-color-primary); }
.sidebar-footer { display: flex; align-items: center; gap: 8px; padding: 12px 16px; border-top: 1px solid var(--el-border-color-light); cursor: pointer; color: var(--el-text-color-secondary); font-size: 13px; }
.sidebar-footer:hover { color: var(--el-color-primary); }
</style>
