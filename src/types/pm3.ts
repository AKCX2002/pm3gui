export type SessionState =
  | "disconnected"
  | "validating"
  | "starting"
  | "handshaking"
  | "connected"
  | "stopping"
  | "failed";

export interface Pm3Error {
  code: string;
  detail?: string;
  field?: string;
  port?: string;
  exit_code?: number | null;
}

export interface SessionSnapshot {
  sessionId: number | null;
  state: SessionState;
  clientVersion: string | null;
  firmwareVersion: string | null;
  lastError: Pm3Error | null;
}

export interface PortInfo {
  name: string;
  description: string;
}

export type StreamKind = "stdout" | "stderr" | "system";

export interface OutputEntry {
  sessionId: number;
  sequence: number;
  stream: StreamKind;
  text: string;
}

export interface OutputSnapshot {
  entries: OutputEntry[];
  droppedCount: number;
}

export type RiskLevel = "read_only" | "dangerous" | "critical";

export type OperationRequest =
  | { kind: "search_hf" }
  | { kind: "search_lf" }
  | { kind: "mifare_info" }
  | { kind: "mifare_dump"; size: "k1" | "k2" | "k4" }
  | { kind: "mifare_autopwn"; size: "k1" | "k2" | "k4" }
  | { kind: "read_mifare_block"; block: number; key_type: "a" | "b"; key: string }
  | {
      kind: "write_mifare_block";
      block: number;
      key_type: "a" | "b";
      key: string;
      data: string;
    }
  | { kind: "restore_mifare"; size: "k1" | "k2" | "k4"; file: string }
  | { kind: "wipe_t55xx" }
  | { kind: "simulate_hid"; card_id: string };

export interface PreparedOperation {
  operationId: number;
  risk: RiskLevel;
  summary: string;
  confirmationToken: string | null;
  expiresAtMs: number;
}
