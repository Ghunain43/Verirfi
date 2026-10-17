import base64
import json
import logging

import pytest
from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PublicKey
from fastapi.testclient import TestClient

from backend.app.api import security_deps, settings, signing
from backend.app.api.claim_cache import cache
from backend.app.api.factcheck_store import store
from backend.app.api.main import app
from backend.app.api.privacy_logging import AccessLogPrivacy
from backend.app.api.report_store import store as report_store

client = TestClient(app)
BASE = "/api/v1"
FP = "a3f19c2b7d4e8a01"
KEYS = "Dawn Fact Desk:dawn-test-key-0123456789,AFP Urdu:afp-test-key-9876543210"
DAWN = {"X-API-Key": "dawn-test-key-0123456789"}
AFP = {"X-API-Key": "afp-test-key-9876543210"}


@pytest.fixture(autouse=True)
def _clean(monkeypatch):
    monkeypatch.setenv("FACTCHECK_API_KEYS", KEYS)
    monkeypatch.delenv("FACTCHECK_SIGNING_KEY", raising=False)
    monkeypatch.delenv("FACTCHECK_KEY_FAILURE_LIMIT", raising=False)
    monkeypatch.delenv("TRUST_PROXY", raising=False)
    signing.reset()
    security_deps.reset_state()
    store.clear()
    cache.clear()
    report_store.clear()
    yield
    store.clear()
    cache.clear()
    signing.reset()


def body(**over):
    b = {"fingerprint": FP, "claim": "Hot water cures dengue.", "rating": "false",
         "summary": "No. Dengue has no cure; treatment is supportive care.",
         "source_url": "https://example.org/factcheck/dengue"}
    b.update(over)
    return b


def publish(headers=DAWN, **over):
    return client.post(f"{BASE}/factcheck", json=body(**over), headers=headers)


def token():
    return client.post(f"{BASE}/auth/install", json={}).json()["install_token"]


def lookup(prefix=FP[:4]):
    return client.get(f"{BASE}/lookup/{prefix}", headers={"Authorization": f"Bearer {token()}"}).json()


def verify(public_b64, payload, sig_b64):
    pk = Ed25519PublicKey.from_public_bytes(base64.b64decode(public_b64))
    try:
        pk.verify(base64.b64decode(sig_b64), payload.encode("utf-8"))
        return True
    except InvalidSignature:
        return False


# ---------- authentication ----------

def test_publish_requires_api_key():
    r = client.post(f"{BASE}/factcheck", json=body())
    assert r.status_code == 401 and r.json()["error"]["code"] == "invalid_token"


def test_wrong_key_rejected():
    assert publish(headers={"X-API-Key": "wrong-key-wrong-key-wrong"}).status_code == 401


def test_install_token_is_not_an_api_key():
    r = client.post(f"{BASE}/factcheck", json=body(), headers={"Authorization": f"Bearer {token()}"})
    assert r.status_code == 401


def test_no_keys_configured_means_nobody_can_publish(monkeypatch):
    monkeypatch.setenv("FACTCHECK_API_KEYS", "")
    assert publish().status_code == 401


def test_short_keys_are_ignored(monkeypatch):
    monkeypatch.setenv("FACTCHECK_API_KEYS", "Weak:short,Strong:long-enough-key-12345")
    assert settings.factcheck_keys() == {"Strong": "long-enough-key-12345"}


def test_key_guessing_locks_out_the_network(monkeypatch):
    monkeypatch.setenv("FACTCHECK_KEY_FAILURE_LIMIT", "3")
    for _ in range(3):
        assert publish(headers={"X-API-Key": "nope-nope-nope-nope-nope"}).status_code == 401
    locked = publish()  # even the right key is refused from this network for now
    assert locked.status_code == 429 and "retry-after" in locked.headers


# ---------- publishing and signatures ----------

def test_publish_returns_signed_record():
    r = publish()
    assert r.status_code == 201
    d = r.json()
    assert set(d) == {"id", "payload", "signature", "key_id"}
    p = json.loads(d["payload"])
    assert p["publisher"] == "Dawn Fact Desk" and p["fingerprint"] == FP and p["rating"] == "false"
    assert p["id"] == d["id"] and p["published_at"].endswith("Z") and p["v"] == 1


def test_signature_verifies_with_published_public_key_and_detects_tampering():
    d = publish().json()
    pk = client.get(f"{BASE}/factcheck/public-key").json()   # no auth needed
    assert pk["algorithm"] == "ed25519" and pk["key_id"] == d["key_id"]
    assert verify(pk["public_key"], d["payload"], d["signature"]) is True
    tampered = d["payload"].replace('"false"', '"true"')
    assert tampered != d["payload"] and verify(pk["public_key"], tampered, d["signature"]) is False


def test_stable_signing_key_from_env(monkeypatch):
    seed = base64.b64encode(bytes(range(32))).decode()
    monkeypatch.setenv("FACTCHECK_SIGNING_KEY", seed)
    a = signing.Signer(seed)
    b = signing.Signer(seed)
    assert a.public_key == b.public_key and a.key_id == b.key_id and not a.ephemeral
    assert signing.get_signer().public_key == a.public_key


def test_ephemeral_key_when_unset():
    assert signing.get_signer().ephemeral is True


@pytest.mark.parametrize("over", [
    {"fingerprint": "abc"}, {"fingerprint": "g" * 16}, {"claim": "   "}, {"claim": "x" * 301},
    {"summary": ""}, {"summary": "y" * 801}, {"rating": "maybe"},
    {"source_url": "http://example.org/x"}, {"source_url": "javascript:alert(1)"}, {"source_url": "https://a b"},
])
def test_validation_400(over):
    r = publish(**over)
    assert r.status_code == 400 and r.json()["error"]["code"] == "invalid_input"


def test_urdu_text_round_trips_in_payload():
    r = publish(claim="گرم پانی پینے سے ڈینگی ٹھیک ہوتا ہے", summary="یہ درست نہیں ہے۔")
    p = json.loads(r.json()["payload"])
    assert p["claim"].startswith("گرم") and "درست" in p["summary"]


# ---------- how clients get responses: /lookup ----------

def test_factcheck_without_ai_result_gets_a_minimal_lookup_entry():
    d = publish().json()
    entries = lookup()["entries"]
    assert len(entries) == 1
    e = entries[0]
    assert e["fingerprint"] == FP and e["claim"] == "Hot water cures dengue." and e["likely_answer"] is None
    assert e["evidence"] == [] and e["factchecks"][0]["id"] == d["id"]


def test_factcheck_is_attached_to_existing_ai_entry():
    cache.put(FP, {"checkable": True, "claim": "Hot water does not cure dengue.", "likely_answer": "Most likely false."})
    d = publish().json()
    entries = lookup()["entries"]
    assert len(entries) == 1
    assert entries[0]["likely_answer"] == "Most likely false." and entries[0]["factchecks"][0]["id"] == d["id"]


def test_lookup_without_factchecks_has_empty_list():
    cache.put(FP, {"checkable": True, "claim": "x"})
    assert lookup()["entries"][0]["factchecks"] == []


def test_publishing_again_replaces_own_ruling_but_not_others():
    first = publish().json()
    second = publish(rating="mostly_false").json()
    other = publish(headers=AFP, rating="false").json()
    ids = {f["id"] for f in lookup()["entries"][0]["factchecks"]}
    assert ids == {second["id"], other["id"]} and first["id"] not in ids


def test_ai_quick_check_cache_is_not_polluted_by_factchecks():
    publish()
    assert cache.get(FP) is None   # /quick-check must never serve an empty "cached" answer


# ---------- list and retract ----------

def test_list_shows_only_own_responses():
    publish()
    publish(headers=AFP, fingerprint="0123456789abcdef")
    mine = client.get(f"{BASE}/factcheck", headers=DAWN).json()["items"]
    assert len(mine) == 1 and json.loads(mine[0]["payload"])["publisher"] == "Dawn Fact Desk"
    assert client.get(f"{BASE}/factcheck").status_code == 401


def test_retract_own_response():
    d = publish().json()
    assert client.delete(f"{BASE}/factcheck/{d['id']}", headers=DAWN).status_code == 204
    assert lookup()["entries"] == []


def test_cannot_retract_someone_elses_or_unknown():
    d = publish().json()
    assert client.delete(f"{BASE}/factcheck/{d['id']}", headers=AFP).status_code == 404
    assert client.delete(f"{BASE}/factcheck/{'0' * 32}", headers=DAWN).status_code == 404
    assert client.delete(f"{BASE}/factcheck/not-an-id", headers=DAWN).status_code == 404
    assert len(lookup()["entries"][0]["factchecks"]) == 1


def test_factcheck_has_its_own_rate_limit(monkeypatch):
    monkeypatch.setenv("LOOKUP_RATE_LIMIT_PER_HOUR", "2")
    assert [publish().status_code for _ in range(3)] == [201, 201, 429]


# ---------- browser access (Emaan's fact-checker page) ----------

def test_cors_preflight_allows_api_key_header_and_delete():
    r = client.options(f"{BASE}/factcheck", headers={
        "Origin": "http://localhost:3000", "Access-Control-Request-Method": "DELETE",
        "Access-Control-Request-Headers": "x-api-key"})
    assert r.status_code == 200
    assert "x-api-key" in r.headers["access-control-allow-headers"].lower()
    assert "DELETE" in r.headers["access-control-allow-methods"]


# ---------- access log privacy ----------

def _record(path, addr="203.0.113.7:5555"):
    return logging.LogRecord("uvicorn.access", logging.INFO, "x", 1, '%s - "%s %s HTTP/%s" %d',
                             (addr, "GET", path, "1.1", 200), None)


def test_access_log_drops_lookup_and_report_lines():
    f = AccessLogPrivacy()
    assert f.filter(_record("/api/v1/lookup/a3f1")) is False
    assert f.filter(_record("/api/v1/report")) is False


def test_access_log_hides_client_address_but_keeps_other_lines():
    f = AccessLogPrivacy()
    r = _record("/api/v1/health")
    assert f.filter(r) is True and "203.0.113" not in r.getMessage() and "/api/v1/health" in r.getMessage()
