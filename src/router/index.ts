import { createRouter, createWebHistory } from "vue-router";

const routes = [
  { path: "/", redirect: "/connection" },
  {
    path: "/connection",
    name: "connection",
    component: () => import("../pages/ConnectionPage.vue"),
  },
  {
    path: "/terminal",
    name: "terminal",
    component: () => import("../pages/TerminalPage.vue"),
  },
  {
    path: "/hf",
    name: "hf",
    component: () => import("../pages/HfPage.vue"),
  },
  {
    path: "/lf",
    name: "lf",
    component: () => import("../pages/LfPage.vue"),
  },
  {
    path: "/dump",
    name: "dump",
    component: () => import("../pages/DumpPage.vue"),
  },
  {
    path: "/settings",
    name: "settings",
    component: () => import("../pages/SettingsPage.vue"),
  },
];

export default createRouter({ history: createWebHistory(), routes });
