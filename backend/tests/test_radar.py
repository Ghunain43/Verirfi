from datetime import timedelta

import pytest
from fastapi.testclient import TestClient

from backend.app.api import security_deps
from backend.app.api.main import app
from backend.app.api.radar_store import RadarStore, _utcnow, network_key
from backend.app.api.radar_store import radar_store
from backend.app.api import web_radar
from backend.app.api.routes import quick_check as qc
from backend.app.api.routes import radar as radar_route

client = TestClient(app)
BASE = "/api/v1"


@pytest.fixture(autouse=True)
def _clean(monkeypatch):
    monkeypatch.setenv("MOCK_MODE", "true")
    monkeypatch.setenv("RATE_LIMIT_PER_HOUR", "20")
    monkeypatch.setenv("RADAR_TRUST_FORWARDED", "true")
    monkeypatch.setenv("RADAR_WEB_ENABLED", "false")  # tests never hit Tavily/Groq
    monkeypatch.setattr(qc, "AGENTS_READY", False)
    security_deps.reset_state()
    radar_store.clear()
    web_radar.reset_state()


def token():
    return client.post(f"{BASE}/auth/install", json={}).json()["install_token"]


def check(t, ip, text="Drinking hot water cures dengue fever."):
    return client.post(
        f"{BASE}/quick-check",
        json={"text": text, "lang": "auto", "source": "web"},
        headers={"Authorization": f"Bearer {t}", "X-Forwarded-For": ip},
    )


def radar(t):
    return client.get(f"{BASE}/radar", headers={"Authorization": f"Bearer {t}"})


def test_network_key_groups_by_subnet():
    assert network_key("203.0.113.5") == network_key("203.0.113.200")
    assert network_key("203.0.113.5") != network_key("203.0.114.5")
    assert network_key("garbage") == "unknown"


def test_requires_token():
    assert client.get(f"{BASE}/radar").status_code == 401


def test_empty_radar():
    r = radar(token())
    assert r.status_code == 200 and r.json() == {"items": []}


def test_needs_both_installs_and_networks():
    s = RadarStore()
    now = _utcnow()
    for i in range(12):  # 12 installs, all on one network
        s.record("aaaa", "claim", f"t{i}", "1.1.1.1", now=now)
    assert s.trending(10, 3, 168, now=now) == []
    for i in range(3):   # add two more networks
        s.record("aaaa", "claim", f"t{i}", f"2.2.{i}.1", now=now)
    out = s.trending(10, 3, 168, now=now)
    assert len(out) == 1 and out[0]["reports"] == 12


def test_same_install_counts_once():
    s = RadarStore()
    for _ in range(50):
        s.record("aaaa", "claim", "one-token", "1.1.1.1")
    assert s.trending(1, 1, 168)[0]["reports"] == 1


def test_old_claims_drop_off():
    s = RadarStore()
    old = _utcnow() - timedelta(days=30)
    for i in range(12):
        s.record("aaaa", "claim", f"t{i}", f"9.{i}.0.1", now=old)
    assert s.trending(10, 3, 168) == []


def test_nothing_sensitive_is_stored():
    s = RadarStore()
    s.record("aaaa", "claim", "secret-token", "198.51.100.7")
    blob = repr(s._entries)
    assert "secret-token" not in blob and "198.51.100.7" not in blob


def test_end_to_end_through_quick_check():
    for i in range(10):
        assert check(token(), f"198.51.{i % 4}.9").status_code == 200
    items = radar(token()).json()["items"]
    assert len(items) == 1
    assert items[0]["reports"] == 10
    assert items[0]["claim"] == "Drinking hot water cures dengue fever."
    assert items[0]["origin"] == "community" and items[0]["source_url"] is None


def test_opinions_are_not_reported():
    for i in range(12):
        check(token(), f"198.51.{i % 4}.9", text="This party is the worst")
    assert radar(token()).json()["items"] == []


# ---- web-found false claims ----

def _web(n, claim=None):
    claim = claim or f"Viral false claim number {n} about something"
    return {"fingerprint": f"{n:016x}", "claim": claim, "reports": 0, "first_seen": "2026-10-17T00:00:00Z",
            "last_seen": "2026-10-17T00:00:00Z", "origin": "web", "source_url": f"https://factcheck.example/{n}",
            "publisher": "factcheck.example"}


def test_empty_radar_is_filled_with_five_web_claims(monkeypatch):
    async def fake(limit):
        return [_web(i) for i in range(1, 8)]
    monkeypatch.setattr(radar_route, "top_false_claims", fake)
    items = radar(token()).json()["items"]
    assert len(items) == 5 and all(i["origin"] == "web" and i["reports"] == 0 for i in items)
    assert items[0]["source_url"].startswith("https://")


def test_community_claims_come_first_and_web_fills_the_rest(monkeypatch):
    async def fake(limit):
        return [_web(i) for i in range(1, 8)]
    monkeypatch.setattr(radar_route, "top_false_claims", fake)
    for i in range(10):
        check(token(), f"198.51.{i % 4}.9")
    items = radar(token()).json()["items"]
    assert len(items) == 5
    assert items[0]["origin"] == "community" and [i["origin"] for i in items[1:]] == ["web"] * 4


def test_no_web_claims_when_community_list_is_full(monkeypatch):
    called = []

    async def fake(limit):
        called.append(1)
        return [_web(1)]
    monkeypatch.setattr(radar_route, "top_false_claims", fake)
    monkeypatch.setenv("RADAR_FILL_TO", "1")
    for i in range(10):
        check(token(), f"198.51.{i % 4}.9")
    items = radar(token()).json()["items"]
    assert [i["origin"] for i in items] == ["community"] and not called


class _FakeTavily:
    configured = True

    async def search(self, query, max_results=5, search_depth="basic"):
        return [{"url": "https://snopes.example/a", "title": "Hot water", "content": "False: hot water does not cure dengue.", "score": 0.9},
                {"url": "https://afp.example/b", "title": "Laptops", "content": "False: no free laptops.", "score": 0.8}]


class _FakeLLM:
    configured = True

    async def generate_json(self, prompt, system=None, temperature=0.1):
        return {"claims": [
            {"claim": "Drinking hot water cures dengue fever.", "url": "https://snopes.example/a"},
            {"claim": "Free laptops are given to all students.", "url": "https://afp.example/b"},
            {"claim": "An invented claim with a made-up link here.", "url": "https://evil.example/x"},  # dropped
            {"claim": "short", "url": "https://afp.example/b"},                                          # dropped
        ]}


@pytest.mark.asyncio
async def test_web_radar_extracts_and_drops_invented_urls(monkeypatch):
    monkeypatch.setenv("RADAR_WEB_ENABLED", "true")
    monkeypatch.setattr(web_radar, "TavilyClient", _FakeTavily)
    monkeypatch.setattr(web_radar, "LLMClient", _FakeLLM)
    items = await web_radar.top_false_claims(5)
    assert [i["publisher"] for i in items] == ["snopes.example", "afp.example"]
    assert all(i["origin"] == "web" and i["reports"] == 0 for i in items)


@pytest.mark.asyncio
async def test_web_radar_is_cached_and_survives_failure(monkeypatch):
    monkeypatch.setenv("RADAR_WEB_ENABLED", "true")
    calls = []

    class Counting(_FakeTavily):
        async def search(self, *a, **k):
            calls.append(1)
            return await super().search(*a, **k)
    monkeypatch.setattr(web_radar, "TavilyClient", Counting)
    monkeypatch.setattr(web_radar, "LLMClient", _FakeLLM)
    await web_radar.top_false_claims(5)
    n = len(calls)
    await web_radar.top_false_claims(5)
    assert len(calls) == n  # second call served from cache

    class Broken(_FakeLLM):
        async def generate_json(self, *a, **k):
            raise RuntimeError("boom")
    web_radar.reset_state()
    monkeypatch.setattr(web_radar, "LLMClient", Broken)
    assert await web_radar.top_false_claims(5) == []  # never raises


def test_spoofed_forwarded_header_cannot_fake_networks():
    # a client prepends fake addresses; the proxy appends the real one last
    for i in range(12):
        check(token(), f"6.6.{i}.1, 198.51.100.9")
    assert radar(token()).json()["items"] == []  # all 12 installs share one real network


def test_tokens_are_signed_and_tamper_proof(monkeypatch):
    t = token()
    assert radar(t).status_code == 200
    assert radar(t[:-1] + ("0" if t[-1] != "0" else "1")).status_code == 401   # bad signature
    assert radar("12345.abc.def").status_code == 401
    monkeypatch.setenv("TOKEN_SECRET", "another-secret")
    assert radar(t).status_code == 401   # signed with a different secret
