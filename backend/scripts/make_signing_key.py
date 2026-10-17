"""Create the fact-check signing key. Run once, put the SECRET line in your .env (never commit it)
and give the public key to the team so clients can pin it:
    python -m backend.scripts.make_signing_key
"""
import base64
import os

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey

seed = os.urandom(32)
public = Ed25519PrivateKey.from_private_bytes(seed).public_key().public_bytes(
    encoding=serialization.Encoding.Raw, format=serialization.PublicFormat.Raw)
print("# put this line in .env (secret, do not commit):")
print("FACTCHECK_SIGNING_KEY=" + base64.b64encode(seed).decode())
print("# public key (safe to share):")
print(base64.b64encode(public).decode())
