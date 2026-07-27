#!/usr/bin/env python3
"""Server-side receipt validation — stdlib only.

Why this exists: the client cannot be trusted to say "the player paid". Poolakey checks
Cafe Bazaar's signature on the device, which stops a naive fake, but nothing stops a
patched APK from calling the grant path directly. Asking the store's own servers whether
a purchase token is real is the only answer that survives a modified client.

  POST /api/<game>/verify_purchase
       {token, store, product_id, purchase_token, device_id}
    -> 200 {ok:true, granted:true}         first time this receipt is seen
    -> 200 {ok:true, granted:false, already:true}   replay of a receipt already credited
    -> 402 {error:"invalid_receipt"}       the store says this purchase is not real
    -> 401 {error:"not_logged_in"}         no account behind the session token
    -> 503 {error:"store_unreachable"}     we could not ask; the CLIENT keeps the receipt

**Myket** is verified against its developer API. The exact contract below was confirmed
against the live service on 2026-07-27: authentication is the `X-Access-Token` header
(not a query parameter), a valid key with a bogus purchase token returns
`400 InvalidToken`, and a wrong or missing key returns `401 Unauthorized` — which is what
lets us tell "fake receipt" apart from "our credentials broke".

**Cafe Bazaar** validation is NOT implemented: its developer API needs an OAuth client id,
secret and refresh token from the Pishkhan panel, which we do not have. Bazaar receipts
are therefore accepted on the strength of Poolakey's on-device signature check and
recorded here for audit. This is stated in the response as `verified: false` rather than
quietly pretending the receipt was checked.
"""
import json
import os
import sqlite3
import time
import urllib.error
import urllib.request

MYKET_API = os.environ.get(
    "MYKET_API", "https://developer.myket.ir/api/applications")
# The access key is a SECRET. It is read from the environment or a file outside the
# repository, never from a committed constant.
MYKET_KEY_FILE = os.environ.get(
    "MYKET_KEY_FILE", "/home/claude/tools/secrets/myket_access_key.txt")
HTTP_TIMEOUT = 12

_myket_key_cache = None


def myket_access_key() -> str:
    """Read the key once. Comment lines (#) in the file are ignored."""
    global _myket_key_cache
    if _myket_key_cache is not None:
        return _myket_key_cache
    key = os.environ.get("MYKET_ACCESS_KEY", "").strip()
    if not key and os.path.exists(MYKET_KEY_FILE):
        with open(MYKET_KEY_FILE, encoding="utf-8") as fh:
            for line in fh:
                line = line.strip()
                if line and not line.startswith("#"):
                    key = line
                    break
    _myket_key_cache = key
    return key


def init_db(conn: sqlite3.Connection) -> None:
    conn.executescript(
        """
        CREATE TABLE IF NOT EXISTS purchases (
            game          TEXT NOT NULL,
            store         TEXT NOT NULL,
            purchase_token TEXT NOT NULL,
            product_id    TEXT NOT NULL,
            email_lower   TEXT NOT NULL,
            device_id     TEXT NOT NULL,
            verified      INTEGER NOT NULL,
            created       REAL NOT NULL,
            PRIMARY KEY (game, store, purchase_token)
        );
        CREATE INDEX IF NOT EXISTS purchases_owner
            ON purchases(game, email_lower);
        """
    )


class StoreUnreachable(Exception):
    """We could not get an answer. Never treat this as 'the receipt is fake'."""


def check_myket(package: str, product_id: str, purchase_token: str) -> bool:
    """True if Myket confirms the purchase, False if it denies it.

    Raises StoreUnreachable when the answer is unknown (network down, our key rejected,
    unexpected status). The caller must not deny a player on an unknown answer.
    """
    key = myket_access_key()
    if not key:
        raise StoreUnreachable("no access key configured")
    url = "%s/%s/purchases/products/%s/tokens/%s" % (
        MYKET_API, package, product_id, purchase_token)
    req = urllib.request.Request(url, headers={"X-Access-Token": key})
    try:
        with urllib.request.urlopen(req, timeout=HTTP_TIMEOUT) as resp:
            if resp.status != 200:
                raise StoreUnreachable("unexpected status %s" % resp.status)
            data = json.loads(resp.read().decode("utf-8") or "{}")
    except urllib.error.HTTPError as exc:
        body = ""
        try:
            body = exc.read().decode("utf-8", "replace")[:300]
        except Exception:
            pass
        if exc.code == 400 and "InvalidToken" in body:
            return False                      # the store positively denies this receipt
        if exc.code == 404:
            return False
        # 401/403 mean OUR credentials are wrong — that is our problem, not the player's.
        raise StoreUnreachable("http %s: %s" % (exc.code, body))
    except (urllib.error.URLError, TimeoutError, OSError, ValueError) as exc:
        raise StoreUnreachable(str(exc))
    # Myket mirrors Google Play's shape: purchaseState 0 == purchased.
    payload = data.get("data") if isinstance(data.get("data"), dict) else data
    state = payload.get("purchaseState", payload.get("consumptionState"))
    if state is None:
        return True                           # a 200 with no state still means "found"
    return int(state) == 0


def verify(conn: sqlite3.Connection, game: str, package: str, body: dict,
           email_lower: str):
    store = str(body.get("store", "")).strip().lower()[:16]
    product_id = str(body.get("product_id", "")).strip()[:64]
    purchase_token = str(body.get("purchase_token", "")).strip()[:512]
    device = str(body.get("device_id", "")).strip()[:64]
    if store not in ("myket", "bazaar") or not product_id or not purchase_token:
        return 400, {"error": "invalid"}

    seen = conn.execute(
        "SELECT email_lower, verified FROM purchases"
        " WHERE game=? AND store=? AND purchase_token=?",
        (game, store, purchase_token),
    ).fetchone()
    if seen:
        # Idempotent: the same receipt must never be credited twice, and one account's
        # receipt must never be redeemed by another.
        return 200, {"ok": True, "granted": False, "already": True,
                     "mine": seen["email_lower"] == email_lower}

    if store == "myket":
        try:
            real = check_myket(package, product_id, purchase_token)
        except StoreUnreachable as exc:
            return 503, {"error": "store_unreachable", "detail": str(exc)[:200]}
        if not real:
            return 402, {"error": "invalid_receipt"}
        verified = 1
    else:
        # Bazaar: recorded, but honestly flagged as not server-verified (see module docs).
        verified = 0

    conn.execute(
        "INSERT INTO purchases(game, store, purchase_token, product_id, email_lower,"
        " device_id, verified, created) VALUES(?,?,?,?,?,?,?,?)",
        (game, store, purchase_token, product_id, email_lower, device, verified,
         time.time()),
    )
    return 200, {"ok": True, "granted": True, "verified": bool(verified)}


def history(conn: sqlite3.Connection, game: str, email_lower: str):
    rows = conn.execute(
        "SELECT store, product_id, verified, created FROM purchases"
        " WHERE game=? AND email_lower=? ORDER BY created DESC LIMIT 100",
        (game, email_lower),
    ).fetchall()
    return 200, {"purchases": [
        {"store": r["store"], "product_id": r["product_id"],
         "verified": bool(r["verified"]), "at": r["created"]} for r in rows]}
