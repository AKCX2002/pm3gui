import { calculateDumpDiff } from "../utils/dump";

self.onmessage = (event: MessageEvent<{ left: ArrayBuffer; right: ArrayBuffer }>) => {
  self.postMessage(
    calculateDumpDiff(new Uint8Array(event.data.left), new Uint8Array(event.data.right)),
  );
};
