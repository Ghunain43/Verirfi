"""PLACEHOLDER fingerprint. Replace with the real SimHash (API.md section 4) later.
Keeps the same output shape: 16 hex characters."""
import hashlib


def compute_fingerprint(text: str) -> str:
    return hashlib.sha256(text.strip().lower().encode("utf-8")).hexdigest()[:16]
