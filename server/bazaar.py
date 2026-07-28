#!/usr/bin/env python3
"""Cafe Bazaar developer API — OAuth consent, token refresh, receipt validation.

Bazaar's API is OAuth2 with a one-time human step: a person logs in, approves the
client, and Bazaar redirects to our `redirect_uri` with a `code`. That code is
exchanged ONCE for a refresh token, and the refresh token is what this module keeps
and uses forever after to mint short-lived access tokens.

    GET /oauth/bazaar?code=...    <- Bazaar redirects the browser here after approval
    GET /oauth/bazaar/start       <- prints the consent URL to visit

Everything secret (client id, client secret, refresh token) lives in a JSON file
outside the repository, mode 600. Nothing here is ever compiled into an APK.

Validation contract (mirrors Google Play's shape, as Bazaar's docs describe):

    GET https://pardakht.cafebazaar.ir/devapi/v2/api/validate/
        {package}/inapp/{product_id}/purchases/{purchase_token}/
        ?access_token={token}

A `200` with `purchaseState == 0` means a real, unrefunded purchase. A `404` means the
store does not know this receipt — a denial. Anything else (network failure, `401`
because our token expired and could not be refreshed) is UNKNOWN and must never be
reported as a denial: see LESSONS L65.
"""
import json
import os
import threading
import time
import urllib.error
import urllib.parse
import urllib.request

CONFIG_PATH = os.environ.get(
    "BAZAAR_OAUTH_FILE", "/home/claude/tools/secrets/bazaar_oauth.json")
AUTH_URL = "https://pardakht.cafebazaar.ir/auth/authorize/"
TOKEN_URL = "https://pardakht.cafebazaar.ir/auth/token/"
API_BASE = "https://pardakht.cafebazaar.ir/devapi/v2/api/validate"
HTTP_TIMEOUT = 12

_lock = threading.Lock()
_access_token = ""
_access_expires = 0.0


class Unknown(Exception):
    """We could not get an answer. Never treat this as 'the receipt is fake'."""


def _config() -> dict:
    if not os.path.exists(CONFIG_PATH):
        return {}
    try:
        with open(CONFIG_PATH, encoding="utf-8") as fh:
            return json.load(fh)
    except (OSError, ValueError):
        return {}


def _save_config(cfg: dict) -> None:
    tmp = CONFIG_PATH + ".tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump(cfg, fh, indent=2, ensure_ascii=False)
    os.chmod(tmp, 0o600)
    os.replace(tmp, CONFIG_PATH)


def configured() -> bool:
    cfg = _config()
    return bool(cfg.get("client_id") and cfg.get("client_secret"))


def linked() -> bool:
    """True once the one-time human consent step has produced a refresh token."""
    return bool(_config().get("refresh_token"))


def consent_url() -> str:
    cfg = _config()
    return AUTH_URL + "?" + urllib.parse.urlencode({
        "response_type": "code",
        "access_type": "offline",
        "redirect_uri": cfg.get("redirect_uri", ""),
        "client_id": cfg.get("client_id", ""),
    })


def _post_form(url: str, fields: dict) -> dict:
    data = urllib.parse.urlencode(fields).encode()
    req = urllib.request.Request(url, data=data, headers={
        "Content-Type": "application/x-www-form-urlencoded"})
    try:
        with urllib.request.urlopen(req, timeout=HTTP_TIMEOUT) as resp:
            return json.loads(resp.read().decode("utf-8") or "{}")
    except urllib.error.HTTPError as exc:
        body = ""
        try:
            body = exc.read().decode("utf-8", "replace")[:300]
        except Exception:
            pass
        raise Unknown("http %s: %s" % (exc.code, body))
    except (urllib.error.URLError, TimeoutError, OSError, ValueError) as exc:
        raise Unknown(str(exc))


def exchange_code(code: str) -> bool:
    """One-time: turn the consent `code` into a stored refresh token."""
    cfg = _config()
    if not cfg:
        raise Unknown("no client configured")
    data = _post_form(TOKEN_URL, {
        "grant_type": "authorization_code",
        "code": code,
        "client_id": cfg["client_id"],
        "client_secret": cfg["client_secret"],
        "redirect_uri": cfg.get("redirect_uri", ""),
    })
    refresh = data.get("refresh_token", "")
    if not refresh:
        raise Unknown("no refresh_token in response: %s" % json.dumps(data)[:200])
    cfg["refresh_token"] = refresh
    cfg["linked_at"] = time.time()
    _save_config(cfg)
    with _lock:
        global _access_token, _access_expires
        _access_token = data.get("access_token", "")
        _access_expires = time.time() + int(data.get("expires_in", 3600)) - 60
    return True


def _access() -> str:
    """A valid access token, refreshing when the cached one is close to expiry."""
    global _access_token, _access_expires
    with _lock:
        if _access_token and time.time() < _access_expires:
            return _access_token
    cfg = _config()
    refresh = cfg.get("refresh_token", "")
    if not refresh:
        raise Unknown("not linked: the one-time consent step has not been done")
    data = _post_form(TOKEN_URL, {
        "grant_type": "refresh_token",
        "refresh_token": refresh,
        "client_id": cfg["client_id"],
        "client_secret": cfg["client_secret"],
    })
    token = data.get("access_token", "")
    if not token:
        raise Unknown("no access_token in refresh response")
    with _lock:
        _access_token = token
        _access_expires = time.time() + int(data.get("expires_in", 3600)) - 60
        return _access_token


def check_purchase(package: str, product_id: str, purchase_token: str) -> bool:
    """True if Bazaar confirms the purchase, False if it denies it.

    Raises Unknown when the answer cannot be obtained — the caller must not deny a
    player on an unknown answer.
    """
    token = _access()
    url = "%s/%s/inapp/%s/purchases/%s/?%s" % (
        API_BASE, package, product_id, purchase_token,
        urllib.parse.urlencode({"access_token": token}))
    try:
        with urllib.request.urlopen(url, timeout=HTTP_TIMEOUT) as resp:
            if resp.status != 200:
                raise Unknown("unexpected status %s" % resp.status)
            data = json.loads(resp.read().decode("utf-8") or "{}")
    except urllib.error.HTTPError as exc:
        if exc.code == 404:
            return False              # the store positively does not know this receipt
        body = ""
        try:
            body = exc.read().decode("utf-8", "replace")[:300]
        except Exception:
            pass
        # 401 means OUR token broke. That is our problem, not the player's.
        raise Unknown("http %s: %s" % (exc.code, body))
    except (urllib.error.URLError, TimeoutError, OSError, ValueError) as exc:
        raise Unknown(str(exc))
    state = data.get("purchaseState", data.get("consumptionState"))
    if state is None:
        return True                   # a 200 with no state still means "found"
    return int(state) == 0


def reset_cache() -> None:
    """Test hook."""
    global _access_token, _access_expires
    with _lock:
        _access_token = ""
        _access_expires = 0.0
