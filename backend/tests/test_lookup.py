import pytest
from fastapi.testclient import TestClient

from backend.app.agents import Evidence, QuickCheckResult
from backend.app.api import security_deps
from backend.app.api.claim_cache import ClaimCache, cache
from backend.app.api.main import app
from backend.app.api.routes import quick_check as qc
from backend.app.core.fingerprint import compute_fingerprint

client = TestClient(app)
BASE = "/api/v1"
TEXT = "Drinking hot water cures dengue fever"

CHECKABLE = QuickCheckResult(
    checkable=True,
    claim="Hot water does not cure dengue.",
    likely_answer="Most likely false.",
    confidence_low=0.7,
    confidence_high=0.9,
    evidence=[Evidence(title="WHO", url="https://who.int/x", publisher="WHO",
                       stance="contradicting", quality=0.9, snippet="No cure.")],
)
OPINION = QuickCheckResult(checkable=False, claim="This is the worst.", reason_unchecked="opinion")


class FakeAgent:
    def __init__(self, result):
        self.result = result
        self.calls = 0

    async def __call__(self, text, lang):
        self.calls += 1
        return self.result


@pytest.fixture(autouse=True)
def _clean(monkeypatch):
    monkeypatch.setenv("RATE_LIMIT_PER_HOUR", "20")
    monkeypatch.setenv("LOOKUP_RATE_LIMIT_PER_HOUR", "200")
    monkeypatch.setattr(qc, "AGENTS_READY", True)
    security_deps.reset_state()
    cache.clear()
    yield
    cache.clear()


def use_agent(monkeypatch, result):
    agent = FakeAgent(result)
    monkeypatch.setattr(qc, "run_quick_check", agent, raising=False)
    return agent


def token():
    return client.post(f"{BASE}/auth/install", json={}).json()["install_token"]


def auth(t):
    return {"Authorization": f"Bearer {t}"}


def check(t, text=TEXT):
    return client.post(f"{BASE}/quick-check", json={"text": text, "lang": "auto", "source": "web"}, headers=auth(t))


def test_lookup_requires_token():
    r = client.get(f"{BASE}/lookup/a3f1")
    assert r.status_code == 401 and r.json()["error"]["code"] == "invalid_token"


def test_empty_bucket():
    r = client.get(f"{BASE}/lookup/a3f1", headers=auth(token()))
    assert r.status_code == 200 and r.json() == {"prefix": "a3f1", "entries": []}


@pytest.mark.parametrize("prefix", ["abc", "abcde", "12g4", "zzzz"])
def test_invalid_prefix_400(prefix):
    r = client.get(f"{BASE}/lookup/{prefix}", headers=auth(token()))
    assert r.status_code == 400 and r.json()["error"]["code"] == "invalid_input"


def test_prefix_is_case_insensitive():
    r = client.get(f"{BASE}/lookup/A3F1", headers=auth(token()))
    assert r.status_code == 200 and r.json()["prefix"] == "a3f1"


def test_checked_claim_appears_in_lookup(monkeypatch):
    use_agent(monkeypatch, CHECKABLE)
    t = token()
    assert check(t).status_code == 200
    fp = compute_fingerprint(TEXT)
    d = client.get(f"{BASE}/lookup/{fp[:4]}", headers=auth(t)).json()
    assert len(d["entries"]) == 1
    e = d["entries"][0]
    assert e["fingerprint"] == fp
    assert e["claim"] == "Hot water does not cure dengue."
    assert e["evidence"][0]["publisher"] == "WHO"
    assert e["checked_at"].endswith("Z")
    assert "text" not in e  # the user's own words are never stored


def test_second_check_is_served_from_cache(monkeypatch):
    agent = use_agent(monkeypatch, CHECKABLE)
    t = token()
    first, second = check(t).json(), check(t).json()
    assert first["cached"] is False and second["cached"] is True
    assert agent.calls == 1
    assert second["claim"] == first["claim"] and second["fingerprint"] == first["fingerprint"]


def test_obfuscated_variant_hits_same_cache_entry(monkeypatch):
    agent = use_agent(monkeypatch, CHECKABLE)
    t = token()
    check(t)
    variant = "Drinking h\u043et w\u0430ter cures d\u0435ngue fever \U0001f525"
    d = check(t, variant).json()
    assert d["cached"] is True and agent.calls == 1


def test_unchecked_result_is_not_stored(monkeypatch):
    use_agent(monkeypatch, OPINION)
    t = token()
    assert check(t).json()["checkable"] is False
    fp = compute_fingerprint(TEXT)
    assert client.get(f"{BASE}/lookup/{fp[:4]}", headers=auth(t)).json()["entries"] == []


def test_failed_check_is_not_stored(monkeypatch):
    async def boom(text, lang):
        raise qc.VerifiError("x", code="upstream_failed")
    monkeypatch.setattr(qc, "run_quick_check", boom, raising=False)
    t = token()
    assert check(t).status_code == 502
    assert len(cache) == 0


def test_lookup_has_its_own_rate_limit(monkeypatch):
    monkeypatch.setenv("LOOKUP_RATE_LIMIT_PER_HOUR", "2")
    t = token()
    codes = [client.get(f"{BASE}/lookup/a3f1", headers=auth(t)).status_code for _ in range(3)]
    assert codes == [200, 200, 429]
    assert "retry-after" in client.get(f"{BASE}/lookup/a3f1", headers=auth(t)).headers
    # quick-check budget is untouched by lookups
    use_agent(monkeypatch, CHECKABLE)
    assert check(t).status_code == 200


# ---- ClaimCache unit tests ----

def _res(claim):
    return {"checkable": True, "claim": claim}


def test_cache_groups_by_prefix_sorted():
    c = ClaimCache()
    c.put("a3f1ffff00000000", _res("b"))
    c.put("a3f10000ffffffff", _res("a"))
    c.put("9999000000000000", _res("other"))
    assert [e["claim"] for e in c.bucket("a3f1")] == ["a", "b"]
    assert [e["claim"] for e in c.bucket("9999")] == ["other"]
    assert c.bucket("0000") == []


def test_cache_evicts_oldest_and_cleans_bucket():
    c = ClaimCache(max_entries=2)
    c.put("aaaa000000000001", _res("1"))
    c.put("bbbb000000000002", _res("2"))
    c.put("cccc000000000003", _res("3"))
    assert len(c) == 2
    assert c.get("aaaa000000000001") is None and c.bucket("aaaa") == []
    assert c.get("cccc000000000003") is not None


def test_cache_put_same_fingerprint_replaces():
    c = ClaimCache()
    c.put("aaaa000000000001", _res("old"))
    c.put("aaaa000000000001", _res("new"))
    assert len(c) == 1 and c.get("aaaa000000000001")["claim"] == "new"
