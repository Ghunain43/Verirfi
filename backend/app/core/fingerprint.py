from backend.app.core.normalize import normalize
from backend.app.core.simhash import simhash_hex


def compute_fingerprint(text: str) -> str:
    """Fingerprint of the text exactly as the user selected it (clients compute the same)."""
    return simhash_hex(normalize(text))
