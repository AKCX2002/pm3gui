export interface DumpDiffRange {
  start: number;
  end: number;
}

export interface DumpDiffSummary {
  leftSize: number;
  rightSize: number;
  differingBytes: number;
  ranges: DumpDiffRange[];
}

export function calculateDumpDiff(left: Uint8Array, right: Uint8Array): DumpDiffSummary {
  const length = Math.max(left.length, right.length);
  const ranges: DumpDiffRange[] = [];
  let differingBytes = 0;
  let rangeStart = -1;
  for (let index = 0; index < length; index += 1) {
    const differs = left[index] !== right[index] || index >= left.length || index >= right.length;
    if (differs) {
      differingBytes += 1;
      if (rangeStart < 0) rangeStart = index;
    } else if (rangeStart >= 0) {
      ranges.push({ start: rangeStart, end: index - 1 });
      rangeStart = -1;
    }
  }
  if (rangeStart >= 0) ranges.push({ start: rangeStart, end: length - 1 });
  return { leftSize: left.length, rightSize: right.length, differingBytes, ranges };
}

export function rawPreview(data: Uint8Array, limit = 64 * 1024): string {
  const preview = data.subarray(0, Math.max(0, limit));
  const text = new TextDecoder("utf-8", { fatal: false }).decode(preview);
  return data.length > preview.length ? `${text}\n\n…已截断 ${data.length - preview.length} 字节` : text;
}
