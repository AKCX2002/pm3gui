import { describe, expect, it } from "vitest";
import { calculateDumpDiff, rawPreview } from "./dump";

describe("dump tools", () => {
  it("summarizes differing ranges and length changes", () => {
    const result = calculateDumpDiff(
      new Uint8Array([1, 2, 3, 4]),
      new Uint8Array([1, 9, 8, 4, 5]),
    );
    expect(result.differingBytes).toBe(3);
    expect(result.ranges).toEqual([{ start: 1, end: 2 }, { start: 4, end: 4 }]);
  });

  it("bounds raw text previews", () => {
    const data = new TextEncoder().encode("0123456789");
    expect(rawPreview(data, 4)).toContain("已截断 6 字节");
  });

  it("handles a four MiB comparison without expanding strings", () => {
    const left = new Uint8Array(4 * 1024 * 1024);
    const right = left.slice();
    right[right.length - 1] = 1;
    expect(calculateDumpDiff(left, right).ranges).toEqual([
      { start: right.length - 1, end: right.length - 1 },
    ]);
  });
});
