import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { verifySignature } from "../src/lib/crypto";

// Produced by the real Python signer (backend/app/api/signing.py) with a fixed key.
const v = JSON.parse(readFileSync(new URL("./factcheck_vector.json", import.meta.url), "utf-8"));

describe("fact-check signatures (Python signs, the extension verifies)", () => {
  it("accepts a genuine signature", async () => {
    expect(await verifySignature(v.public_key, v.payload, v.signature)).toBe(true);
  });
  it("rejects a tampered payload", async () => {
    expect(await verifySignature(v.public_key, v.payload.replace('"false"', '"true"'), v.signature)).toBe(false);
  });
  it("rejects a signature from another key", async () => {
    const other = "11qYAYKxCrfVS/7TyWQHOg7hcvPapiMlrwIaaPcHURo="; // not the signing key
    expect(await verifySignature(other, v.payload, v.signature)).toBe(false);
  });
  it("rejects garbage without throwing", async () => {
    expect(await verifySignature("not-base64!!", v.payload, "also bad")).toBe(false);
  });
});
