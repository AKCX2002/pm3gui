import { invoke } from "@tauri-apps/api/core";
import { listen, type UnlistenFn } from "@tauri-apps/api/event";
import type {
  OperationRequest,
  OutputEntry,
  OutputSnapshot,
  Pm3Error,
  PortInfo,
  PreparedOperation,
  SessionSnapshot,
} from "../types/pm3";

export function errorText(error: unknown): string {
  const value = error as Partial<Pm3Error> | null;
  if (!value || typeof value !== "object") return String(error);
  const labels: Record<string, string> = {
    invalid_client_directory: "PM3 Client 目录无效",
    port_unavailable: "串口不可用",
    launch_failed: "PM3 Client 启动失败",
    handshake_timeout: "连接握手超时",
    device_disconnected: "设备未连接",
    process_exited: "PM3 Client 已退出",
    busy: "当前会话正忙",
    invalid_operation: "操作参数无效",
    confirmation_required: "确认信息无效或缺失",
    cancelled: "操作已取消或已过期",
    io: "输入输出失败",
  };
  const message = value.code ? labels[value.code] ?? value.code : "未知错误";
  return value.detail ? `${message}：${value.detail}` : message;
}

export const pm3Client = {
  ports: () => invoke<PortInfo[]>("get_ports"),
  snapshot: () => invoke<SessionSnapshot>("get_pm3_state"),
  connect: (pm3Dir: string, port: string) =>
    invoke<SessionSnapshot>("connect", { request: { pm3Dir, port } }),
  disconnect: () => invoke<SessionSnapshot>("disconnect"),
  send: (command: string) => invoke<void>("send_command", { command }),
  outputSnapshot: () => invoke<OutputSnapshot>("get_output_snapshot"),
  prepare: (request: OperationRequest) =>
    invoke<PreparedOperation>("prepare_operation", { request }),
  execute: (operation: PreparedOperation) =>
    invoke<void>("execute_operation", {
      confirmed: {
        operationId: operation.operationId,
        confirmationToken: operation.confirmationToken,
      },
    }),
  onState: (handler: (value: SessionSnapshot) => void): Promise<UnlistenFn> =>
    listen<SessionSnapshot>("pm3://state", ({ payload }) => handler(payload)),
  onOutput: (handler: (value: OutputEntry) => void): Promise<UnlistenFn> =>
    listen<OutputEntry>("pm3://output", ({ payload }) => handler(payload)),
};
