import time

import pytest
from fastapi.testclient import TestClient

from backend.app.agents import QuickCheckResult
from backend.app.api import security_deps
from backend.app.api.abuse import AbuseGuard, guard, network_of
from backend.app.api.claim_cache import cache
from backend.app.api.errors import ApiError
from backend.app.api.main import app
from backend.app.api.report_store import store
from backend.app.api.routes import quick_check as qc

client = TestClient(app)
BASE = "/api/v1"
BASE_FP = 0xA3F19C2B7D4E8A01


def fp_with_flips(*bits):
    v = BASE_FP
    for b in bits:
        v ^= 1 << b
    return f"{v:016x}"


@pytest.fixture(autouse=True)
def _clean(monkeypatch):
    for k in ("INSTALL_RATE_LIMIT_PER_HOUR", "ABUSE_STRIKE_LIMIT", "NEAR_DUP_LIMIT", "NEAR_DUP_DISTANCE",
              "TRUST_PROXY", "RATE_LIMIT_PER_HOUR"):
        monkeypatch.delenv(k, raising=False)
    monkeypatch.setattr(qc, "AGENTS_READY", False)
    security_deps.reset_state()
    store.clear()
    cache.clear()
    yield
    security_deps.reset_state()
    store.clear()
    cache.clear()


def install(ip=None):
    headers = {"X-Forwarded-For": ip} if ip else {}
    return client.post(f"{BASE}/auth/install", json={}, headers=headers)


def token():
    return install().json()["install_token"]


def auth(t):
    return {"Authorization": f"Bearer {t}"}


def check(t, text="hello world"):
    return client.post(f"{BASE}/quick-check", json={"text": text, "lang": "auto", "source": "web"}, headers=auth(t))


# ---------- rule 1: installs per network ----------

def test_install_limit_per_network(monkeypatch):
    monkeypatch.setenv("INSTALL_RATE_LIMIT_PER_HOUR", "3")
    codes = [install().status_code for _ in range(4)]
    assert codes == [201, 201, 201, 429]
    assert "retry-after" in install().headers


def test_network_helper_groups_ipv4_24_and_ipv6_48():
    assert network_of("1.2.3.4") == network_of("1.2.3.200") != network_of("1.2.4.4")
    assert network_of("2001:db8:1:1::1") == network_of("2001:db8:1:ffff::9")
    assert network_of("testclient") == "testclient"


def test_installs_counted_per_network_when_proxy_trusted(monkeypatch):
    monkeypatch.setenv("TRUST_PROXY", "true")
    monkeypatch.setenv("INSTALL_RATE_LIMIT_PER_HOUR", "2")
    assert [install("1.2.3.4").status_code, install("1.2.3.200").status_code] == [201, 201]
    assert install("1.2.3.99").status_code == 429       # same /24
    assert install("5.6.7.8").status_code == 201        # other network is unaffected


def test_forwarded_header_is_ignored_unless_proxy_is_trusted(monkeypatch):
    monkeypatch.setenv("INSTALL_RATE_LIMIT_PER_HOUR", "2")
    codes = [install(f"{i}.{i}.{i}.{i}").status_code for i in range(1, 4)]  # spoofed, all different
    assert codes == [201, 201, 429]


def test_spoofed_first_forwarded_entry_does_not_help(monkeypatch):
    monkeypatch.setenv("TRUST_PROXY", "true")
    monkeypatch.setenv("INSTALL_RATE_LIMIT_PER_HOUR", "1")
    assert install("8.8.8.8, 1.1.1.1").status_code == 201      # proxy appended 1.1.1.1
    assert install("9.9.9.9, 1.1.1.1").status_code == 429      # same real client, fake first entry


def test_guard_stores_no_raw_ip(monkeypatch):
    monkeypatch.setenv("TRUST_PROXY", "true")
    install("203.0.113.77")
    assert "203.0.113" not in repr(guard._installs)


# ---------- rule 2: strikes lead to a block ----------

def test_repeated_rate_limit_hits_block_the_token(monkeypatch):
    monkeypatch.setenv("RATE_LIMIT_PER_HOUR", "1")
    monkeypatch.setenv("ABUSE_STRIKE_LIMIT", "3")
    t, other = token(), token()
    assert check(t).status_code == 200
    assert [check(t).status_code for _ in range(3)] == [429, 429, 429]   # three strikes
    blocked = client.get(f"{BASE}/lookup/a3f1", headers=auth(t))          # now blocked on every endpoint
    assert blocked.status_code == 429 and "temporarily blocked" in blocked.json()["error"]["message"]
    assert int(blocked.headers["retry-after"]) > 3000
    assert client.get(f"{BASE}/lookup/a3f1", headers=auth(other)).status_code == 200


def test_block_expires(monkeypatch):
    monkeypatch.setenv("RATE_LIMIT_PER_HOUR", "1")
    monkeypatch.setenv("ABUSE_STRIKE_LIMIT", "2")
    t = token()
    check(t)
    check(t)
    check(t)
    assert client.get(f"{BASE}/lookup/a3f1", headers=auth(t)).status_code == 429
    guard._blocked[t] = time.time() - 1
    assert client.get(f"{BASE}/lookup/a3f1", headers=auth(t)).status_code == 200


def test_strikes_older_than_an_hour_are_forgotten(monkeypatch):
    monkeypatch.setenv("ABUSE_STRIKE_LIMIT", "3")
    g = AbuseGuard()
    g._strikes["t"].extend([time.time() - 4000, time.time() - 4000])
    g.strike("t", "rate_limit")
    assert "t" not in g._blocked


# ---------- rule 3: near-identical claim floods ----------

def test_near_duplicate_flood_is_rejected(monkeypatch):
    monkeypatch.setenv("NEAR_DUP_LIMIT", "5")
    g = AbuseGuard()
    variants = [fp_with_flips(i) for i in range(6)]  # six different fingerprints, each 1 bit from the base
    for v in variants[:5]:
        g.check_near_duplicates("t", v)          # first five are fine
    with pytest.raises(ApiError) as e:
        g.check_near_duplicates("t", variants[5])
    assert e.value.status == 429 and "Retry-After" in e.value.headers


def test_exact_repeats_do_not_count(monkeypatch):
    monkeypatch.setenv("NEAR_DUP_LIMIT", "2")
    g = AbuseGuard()
    for _ in range(20):
        g.check_near_duplicates("t", fp_with_flips(0))


def test_unrelated_claims_do_not_count(monkeypatch):
    monkeypatch.setenv("NEAR_DUP_LIMIT", "2")
    g = AbuseGuard()
    far = [0x0000000000000000, 0xFFFFFFFFFFFFFFFF, 0xAAAAAAAAAAAAAAAA, 0x5555555555555555, 0x0F0F0F0F0F0F0F0F]
    for f in far:
        g.check_near_duplicates("t", f"{f:016x}")


def test_near_duplicates_are_tracked_per_token(monkeypatch):
    monkeypatch.setenv("NEAR_DUP_LIMIT", "1")
    g = AbuseGuard()
    g.check_near_duplicates("a", fp_with_flips(0))
    g.check_near_duplicates("b", fp_with_flips(1))   # other token: no history


def test_near_duplicate_flood_over_http_adds_strikes_and_blocks(monkeypatch):
    monkeypatch.setenv("NEAR_DUP_LIMIT", "1")
    monkeypatch.setenv("ABUSE_STRIKE_LIMIT", "2")
    fps = {f"claim {i}": fp_with_flips(i) for i in range(5)}
    monkeypatch.setattr(qc, "AGENTS_READY", True)
    monkeypatch.setattr(qc, "compute_fingerprint", lambda text: fps[text])

    async def fake_agent(text, lang):
        return QuickCheckResult(checkable=True, claim=text)

    monkeypatch.setattr(qc, "run_quick_check", fake_agent, raising=False)
    t = token()
    assert check(t, "claim 0").status_code == 200
    assert check(t, "claim 1").status_code == 429          # strike 1 (one near duplicate already sent)
    assert check(t, "claim 2").status_code == 429          # strike 2 -> blocked
    r = check(t, "claim 3")
    assert r.status_code == 429 and "temporarily blocked" in r.json()["error"]["message"]
