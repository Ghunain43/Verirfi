import { describe, expect, it } from "vitest";
import type { LookupEntry } from "../src/lib/api";
import { withNoise } from "../src/lib/api";
import { bestMatch } from "../src/lib/match";
import { splitSentences } from "../src/lib/text";

const entry = (fingerprint: string): LookupEntry => ({
  fingerprint, claim: "c", likely_answer: null, confidence_low: 0, confidence_high: 0,
  evidence: [], checked_at: "", factchecks: [],
});

describe("splitSentences", () => {
  it("keeps offsets into the original text", () => {
    const text = "First claim here.  Second one follows! Third?";
    const spans = splitSentences(text);
    expect(spans.map((s) => s.text)).toEqual(["First claim here.", "Second one follows!", "Third?"]);
    for (const s of spans) expect(text.slice(s.start, s.end)).toBe(s.text);
  });
  it("splits on Urdu punctuation", () => {
    expect(splitSentences("یہ پہلا جملہ ہے۔ کیا یہ دوسرا ہے؟").length).toBe(2);
  });
});

describe("bestMatch", () => {
  it("returns the closest entry within the distance", () => {
    const entries = [entry("0000000000000fff"), entry("0000000000000001")];
    expect(bestMatch(entries, "0000000000000000", 3)?.fingerprint).toBe("0000000000000001");
  });
  it("returns null when everything is too far", () => {
    expect(bestMatch([entry("ffffffffffffffff")], "0000000000000000", 3)).toBeNull();
  });
});

describe("withNoise (randomized response)", () => {
  const fp = "a3f19c2b7d4e8a01";
  it("keeps the real fingerprint 75% of the time", () => expect(withNoise(fp, () => 0.5)).toBe(fp));
  it("swaps in a random 16-hex fingerprint 25% of the time", () => {
    const noisy = withNoise(fp, () => 0.1);
    expect(noisy).toMatch(/^[0-9a-f]{16}$/);
    expect(noisy).not.toBe(fp);
  });
});
