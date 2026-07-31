import { ref, watch } from "vue";
import { defineStore } from "pinia";

interface StoredSettings {
  dark: boolean;
  terminalFontSize: number;
}

const defaults: StoredSettings = { dark: false, terminalFontSize: 14 };

export const useSettingsStore = defineStore("settings", () => {
  let saved = defaults;
  try {
    saved = { ...defaults, ...JSON.parse(localStorage.getItem("pm3gui-settings") ?? "{}") };
  } catch {
    saved = defaults;
  }
  const dark = ref(saved.dark);
  const terminalFontSize = ref(saved.terminalFontSize);

  function apply() {
    document.documentElement.classList.toggle("dark", dark.value);
  }

  watch(
    [dark, terminalFontSize],
    () => {
      localStorage.setItem(
        "pm3gui-settings",
        JSON.stringify({ dark: dark.value, terminalFontSize: terminalFontSize.value }),
      );
      apply();
    },
    { immediate: true },
  );

  return { dark, terminalFontSize, apply };
});
