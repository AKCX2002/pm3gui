import { ref } from "vue";
import { ElMessage, ElMessageBox } from "element-plus";
import { errorText, pm3Client } from "../api/pm3Client";
import type { OperationRequest } from "../types/pm3";

export function useOperation() {
  const running = ref(false);

  async function run(request: OperationRequest) {
    if (running.value) return;
    running.value = true;
    try {
      const operation = await pm3Client.prepare(request);
      if (operation.risk === "dangerous") {
        await ElMessageBox.confirm(
          `${operation.summary}。该操作会修改卡片或启动模拟，是否继续？`,
          "确认危险操作",
          { type: "warning", confirmButtonText: "继续执行", cancelButtonText: "取消" },
        );
      } else if (operation.risk === "critical") {
        await ElMessageBox.prompt(
          `${operation.summary}。可能造成卡片不可恢复，请输入 EXECUTE 确认。`,
          "确认高风险操作",
          {
            type: "error",
            inputPattern: /^EXECUTE$/,
            inputErrorMessage: "请输入 EXECUTE",
            confirmButtonText: "执行",
            cancelButtonText: "取消",
          },
        );
      }
      await pm3Client.execute(operation);
      ElMessage.success(`${operation.summary} 已提交，可在终端查看结果`);
    } catch (reason) {
      if (reason === "cancel" || reason === "close") return;
      ElMessage.error(errorText(reason));
    } finally {
      running.value = false;
    }
  }

  return { running, run };
}
