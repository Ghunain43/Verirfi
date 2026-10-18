// Ed25519 verification of fact-checker responses (backend/app/api/signing.py), via WebCrypto.
function b64ToBytes(b64: string): Uint8Array<ArrayBuffer> {
  const bin = atob(b64);
  const out = new Uint8Array(new ArrayBuffer(bin.length));
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

export async function verifySignature(publicKeyB64: string, payload: string, signatureB64: string): Promise<boolean> {
  try {
    const key = await crypto.subtle.importKey("raw", b64ToBytes(publicKeyB64), { name: "Ed25519" }, false, ["verify"]);
    return await crypto.subtle.verify("Ed25519", key, b64ToBytes(signatureB64), new TextEncoder().encode(payload));
  } catch {
    return false; // includes browsers without Ed25519 support: unverifiable means not shown
  }
}
