import pytest
from fastapi.testclient import TestClient

from backend.app.api import security_deps
from backend.app.api.claim_cache import cache
from backend.app.api.main import app
from backend.app.api.report_store import ReportStore, store

client = TestClient(app)
BASE = "/api/v1"
FP = "a3f19c2b7d4e8a01"
FP2 = "0123456789abcdef"


@pytest.fixture(autouse=True)
def _clean(monkeypatch):
    monkeypatch.setenv("RADAR_MIN_REPORTS", "10")
    monkeypatch.setenv("REPORT_RATE_LIMIT_PER_HOUR", "30")
    monkeypatch.setenv("LOOKUP_RATE_LIMIT_PER_HOUR", "200")
    security_deps.reset_state()
    store.clear()
    cache.clear()
    yield
    store.clear()
    cache.clear()


def token():
    return client.post(f"{BASE}/auth/install", json={}).json()["install_token"]


def auth(t):
    return {"Authorization": f"Bearer {t}"}


def report(t, fp=FP, **extra):
    body = {"fingerprint": fp, "noisy": True, **extra}
    return client.post(f"{BASE}/report", json=body, headers=auth(t))


def radar(t):
    return client.get(f"{BASE}/radar", headers=auth(t))


def many_reports(n, fp=FP):
    last = None
    for _ in range(n):
        last = token()
        assert report(last, fp).status_code == 202
    return last


def test_endpoints_require_token():
    assert client.post(f"{BASE}/report", json={"fingerprint": FP, "noisy": True}).status_code == 401
    assert client.get(f"{BASE}/radar").status_code == 401


def test_report_returns_202_empty_object():
    r = report(token())
    assert r.status_code == 202 and r.json() == {}


def test_radar_hides_claim_below_threshold():
    t = many_reports(9)
    assert radar(t).json() == {"items": []}


def test_radar_shows_claim_at_threshold():
    t = many_reports(10)
    items = radar(t).json()["items"]
    assert len(items) == 1
    assert items[0]["fingerprint"] == FP and items[0]["reports"] == 10
    assert items[0]["first_seen"].endswith("Z") and items[0]["first_seen"] <= items[0]["last_seen"]


def test_same_install_counts_once():
    t = token()
    for _ in range(15):
        assert report(t).status_code == 202
    assert len(store._data[FP]["installs"]) == 1


def test_claim_text_comes_from_checked_cache_else_empty(monkeypatch):
    monkeypatch.setenv("RADAR_MIN_REPORTS", "2")
    cache.put(FP, {"checkable": True, "claim": "Hot water does not cure dengue."})
    t = many_reports(2, FP)
    many_reports(2, FP2)
    by_fp = {i["fingerprint"]: i["claim"] for i in radar(t).json()["items"]}
    assert by_fp[FP] == "Hot water does not cure dengue."
    assert by_fp[FP2] == ""


def test_sorted_by_report_count(monkeypatch):
    monkeypatch.setenv("RADAR_MIN_REPORTS", "2")
    many_reports(2, FP2)
    t = many_reports(4, FP)
    assert [i["fingerprint"] for i in radar(t).json()["items"]] == [FP, FP2]


@pytest.mark.parametrize("fp", ["abc", "g" * 16, "a" * 17, "", "a3f19c2b7d4e8a0"])
def test_bad_fingerprint_400(fp):
    r = report(token(), fp)
    assert r.status_code == 400 and r.json()["error"]["code"] == "invalid_input"


def test_uppercase_fingerprint_is_normalized():
    t = token()
    assert report(t, FP.upper()).status_code == 202
    assert FP in store._data


def test_noise_flag_is_required_and_must_be_true():
    t = token()
    assert report(t, noisy=False).status_code == 400
    r = client.post(f"{BASE}/report", json={"fingerprint": FP}, headers=auth(t))
    assert r.status_code == 400


@pytest.mark.parametrize("region,status", [("PK-SD", 202), ("PK", 202), ("x", 400), ("PK SD", 400), ("A" * 9, 400)])
def test_region_validation(region, status):
    assert report(token(), region=region).status_code == status


def test_region_is_not_stored():
    report(token(), region="PK-SD")
    assert "PK-SD" not in repr(store._data)


def test_store_never_holds_token_and_cannot_link_reports():
    t = token()
    report(t, FP)
    report(t, FP2)
    assert t not in repr(store._data)
    assert not (store._data[FP]["installs"] & store._data[FP2]["installs"])


def test_report_has_its_own_rate_limit(monkeypatch):
    monkeypatch.setenv("REPORT_RATE_LIMIT_PER_HOUR", "2")
    t = token()
    codes = [report(t, FP).status_code for _ in range(3)]
    assert codes == [202, 202, 429]
    assert "retry-after" in report(t, FP).headers


def test_store_evicts_least_recently_reported():
    s = ReportStore(max_fingerprints=2)
    s.add("t", "aaaaaaaaaaaaaaaa")
    s.add("t", "bbbbbbbbbbbbbbbb")
    s.add("t", "aaaaaaaaaaaaaaaa")   # refreshes a, so b is now the oldest
    s.add("t", "cccccccccccccccc")
    assert set(s._data) == {"aaaaaaaaaaaaaaaa", "cccccccccccccccc"}
