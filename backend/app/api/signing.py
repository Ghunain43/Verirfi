"""Ed25519 signing of fact-checker responses.

A response is published as {id, payload, signature, key_id}. `payload` is a JSON STRING and
`signature` covers its exact UTF-8 bytes, so clients never need to canonicalize JSON:
verify the signature over the string, then JSON-parse it. Clients fetch the public key from
GET /factcheck/public-key (or pin it) and compare key_id.
"""
import base64
import hashlib
import logging
from typing import Optional

from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey

from backend.app.api import settings

log = logging.getLogger("verifi.signing")
_RAW = dict(encoding=serialization.Encoding.Raw, format=serialization.PublicFormat.Raw)


class Signer:
    def __init__(self, seed_b64: Optional[str] = None) -> None:
        if seed_b64:
            self._private = Ed25519PrivateKey.from_private_bytes(base64.b64decode(seed_b64))
            self.ephemeral = False
        else:
            self._private = Ed25519PrivateKey.generate()
            self.ephemeral = True
            log.warning("FACTCHECK_SIGNING_KEY not set: using a temporary signing key. "
                        "Signatures stop verifying after a restart.")
        public_raw = self._private.public_key().public_bytes(**_RAW)
        self.public_key = base64.b64encode(public_raw).decode()
        self.key_id = hashlib.sha256(public_raw).hexdigest()[:16]

    def sign(self, payload: str) -> str:
        return base64.b64encode(self._private.sign(payload.encode("utf-8"))).decode()

    def verify(self, payload: str, signature_b64: str) -> bool:
        try:
            self._private.public_key().verify(base64.b64decode(signature_b64), payload.encode("utf-8"))
            return True
        except (InvalidSignature, ValueError):
            return False


_signers: dict = {}


def get_signer() -> Signer:
    seed = settings.factcheck_signing_key()
    if seed not in _signers:
        _signers[seed] = Signer(seed)
    return _signers[seed]


def reset() -> None:  # for tests
    _signers.clear()
