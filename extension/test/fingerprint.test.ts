import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { computeFingerprint, prefixOf } from "../src/lib/fingerprint";
import { normalize, squeeze } from "../src/lib/normalize";
import { hamming, shingles, simhashHex } from "../src/lib/simhash";

interface Vector {
  name: string;
  input: string;
  normalized: string;
  fingerprint: string;
}
const file = JSON.parse(readFileSync(new URL("../../shared/fingerprint_vectors.json", import.meta.url), "utf-8"));
const vectors: Vector[] = file.vectors;

describe("shared fingerprint vectors (must match the Python backend exactly)", () => {
  it("has vectors", () => expect(vectors.length).toBeGreaterThanOrEqual(15));
  for (const v of vectors) {
    it(`normalize: ${v.name}`, () => expect(normalize(v.input)).toBe(v.normalized));
    it(`fingerprint: ${v.name}`, () => expect(computeFingerprint(v.input)).toBe(v.fingerprint));
  }
});

describe("simhash helpers", () => {
  it("empty text is 16 zeros", () => expect(simhashHex("")).toBe("0".repeat(16)));
  it("short inputs use one shingle", () => expect(shingles("hot water")).toEqual(["hot water"]));
  it("3-grams", () => expect(shingles("a b c d")).toEqual(["a b c", "b c d"]));
  it("hamming distance", () => {
    expect(hamming("0000000000000000", "ffffffffffffffff")).toBe(64);
    expect(hamming("a3f19c2b7d4e8a01", "a3f19c2b7d4e8a01")).toBe(0);
    expect(hamming("0000000000000003", "0000000000000000")).toBe(2);
  });
  it("prefix is the first 4 hex characters", () => expect(prefixOf("a3f19c2b7d4e8a01")).toBe("a3f1"));
  it("squeeze keeps digits", () => {
    expect(squeeze("coool")).toBe("cool");
    expect(squeeze("1000000")).toBe("1000000");
  });
});
