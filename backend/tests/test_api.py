import pytest
from fastapi.testclient import TestClient

from backend.app.agents import QuickCheckResult
from backend.app.api import security_deps
from backend.app.api.main import app
from backend.app.api.routes import quick_check as qc

client = TestClient(app)
BASE = "/api/v1"


@pytest.fixture(autouse=True)
def _clean(monkeypatch):
    monkeypatch.setenv("MOCK_MODE", "true")
    monkeypatch.setenv("RATE_LIMIT_PER_HOUR", "20")
    # use the API's own mock so these tests never call the real agents
    monkeypatch.setattr(qc, "AGENTS_READY", False)
    security_deps.reset_state()


def token():
    return client.post(f"{BASE}/auth/install", json={}).json()["install_token"]


def auth(t):
    return {"Authorization": f"Bearer {t}"}


def body(text="Drinking hot water cures dengue fever."):
    return {"text": text, "lang": "auto", "source": "extension"}


def test_health():
    assert client.get(f"{BASE}/health").json()["status"] == "ok"


def test_install_shape():
    r = client.post(f"{BASE}/auth/install", json={})
    assert r.status_code == 201 and r.json()["expires_in"] == 2592000


def test_checkable_mock():
    r = client.post(f"{BASE}/quick-check", json=body(), headers=auth(token()))
    assert r.status_code == 200
    d = r.json()
    assert d["checkable"] is True and d["fingerprint"] == "a3f19c2b7d4e8a01"
    assert d["evidence"][0]["publisher"] == "WHO"


def test_opinion_mock():
    r = client.post(f"{BASE}/quick-check", json=body("This party is the worst"), headers=auth(token()))
    d = r.json()
    assert d["checkable"] is False and d["reason_unchecked"] == "opinion" and d["evidence"] == []


def test_missing_token_401():
    r = client.post(f"{BASE}/quick-check", json=body())
    assert r.status_code == 401 and r.json()["error"]["code"] == "invalid_token"


@pytest.mark.parametrize("payload", [
    {"text": "", "lang": "auto", "source": "web"},
    {"text": "x" * 2001, "lang": "auto", "source": "web"},
    {"text": "hi", "lang": "fr", "source": "web"},
])
def test_invalid_input_400(payload):
    r = client.post(f"{BASE}/quick-check", json=payload, headers=auth(token()))
    assert r.status_code == 400 and r.json()["error"]["code"] == "invalid_input"


def test_rate_limit_429(monkeypatch):
    monkeypatch.setenv("RATE_LIMIT_PER_HOUR", "3")
    t = token()
    codes = [client.post(f"{BASE}/quick-check", json=body(), headers=auth(t)).status_code for _ in range(4)]
    assert codes == [200, 200, 200, 429]
    r = client.post(f"{BASE}/quick-check", json=body(), headers=auth(t))
    assert "retry-after" in r.headers


# ---- real agent path: error mapping and server-added fields ----

def _agent_raising(code):
    async def fake(text, lang):
        raise qc.VerifiError("boom", code=code)
    return fake


@pytest.mark.parametrize("code,status,expected", [
    ("invalid_input", 400, "invalid_input"),
    ("timeout", 504, "timeout"),
    ("upstream_failed", 502, "upstream_failed"),
    ("llm_bad_json", 502, "upstream_failed"),
])
def test_agent_error_mapping(monkeypatch, code, status, expected):
    monkeypatch.setattr(qc, "AGENTS_READY", True)
    monkeypatch.setattr(qc, "run_quick_check", _agent_raising(code), raising=False)
    r = client.post(f"{BASE}/quick-check", json=body(), headers=auth(token()))
    assert r.status_code == status and r.json()["error"]["code"] == expected


def test_agent_result_gets_server_fields(monkeypatch):
    async def fake(text, lang):
        return QuickCheckResult(checkable=True, claim="Water is wet.", likely_answer="True.")
    monkeypatch.setattr(qc, "AGENTS_READY", True)
    monkeypatch.setattr(qc, "run_quick_check", fake, raising=False)
    d = client.post(f"{BASE}/quick-check", json=body(), headers=auth(token())).json()
    assert len(d["fingerprint"]) == 16 and d["cached"] is False and isinstance(d["took_ms"], int)