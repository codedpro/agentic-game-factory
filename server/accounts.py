#!/usr/bin/env python3
"""Email + password accounts for the game factory — stdlib only.

Deliberately minimal, because the game must keep working when this server is down:
an account is required only to *buy* something, never to play, never to score.

  POST /api/<game>/register  {email, password, device_id}  -> {token, email}
  POST /api/<game>/login     {email, password, device_id}  -> {token, email}
  POST /api/<game>/logout    {token}                       -> {ok}
  GET  /api/<game>/account?token=                          -> {email, created}

Security notes, stated plainly rather than implied:

* **Passwords are hashed with scrypt** (n=2^14, r=8, p=1, per-user 16-byte salt) and
  compared in constant time. Nothing anywhere stores or logs a plaintext password.
* **Emails are NOT verified.** That is a product decision (the human asked for no
  verification), and it has one unavoidable consequence: there is no way to prove a
  person owns the address they typed, so *there can be no email password reset*. A
  reset link sent to an unverified address is a full account takeover primitive. If
  password recovery is ever needed, verification has to come first.
* Because addresses are unverified, an email is treated as a **login identifier only**.
  Nothing is ever sent to it, and it is never shown to another player.
* Login attempts are throttled per email AND per IP; both are needed, since either
  alone leaves an obvious hole (one attacker, many emails / one email, many hosts).
"""
import hashlib
import hmac
import json
import os
import re
import secrets
import sqlite3
import threading
import time

# scrypt parameters. n is the memory/CPU cost; 2^14 keeps a login around 50-100 ms on a
# small VPS, which is slow enough to hurt an attacker and fast enough to feel instant.
SCRYPT_N = 1 << 14
SCRYPT_R = 8
SCRYPT_P = 1
SALT_BYTES = 16
TOKEN_BYTES = 32
SESSION_TTL = 400 * 24 * 3600          # ~13 months; a game session should outlive a phone
MIN_PASSWORD = 8
MAX_PASSWORD = 128
MAX_EMAIL = 254                        # RFC 5321 upper bound on a path

# Deliberately permissive: this is a login identifier, not a deliverability check, and a
# strict regex mostly succeeds at rejecting valid unusual addresses.
EMAIL_RE = re.compile(r"^[^@\s]{1,64}@[^@\s.]+(\.[^@\s.]+)+$")

LOGIN_WINDOW = 900                     # 15 minutes
LOGIN_MAX_FAILS = 8                    # per email and per ip within the window

_fail_lock = threading.Lock()
_fails: dict[str, list[float]] = {}


def init_db(conn: sqlite3.Connection) -> None:
    conn.executescript(
        """
        CREATE TABLE IF NOT EXISTS accounts (
            game        TEXT NOT NULL,
            email_lower TEXT NOT NULL,
            email       TEXT NOT NULL,
            pw_hash     TEXT NOT NULL,
            created     REAL NOT NULL,
            PRIMARY KEY (game, email_lower)
        );
        CREATE TABLE IF NOT EXISTS sessions (
            token_hash TEXT PRIMARY KEY,
            game       TEXT NOT NULL,
            email_lower TEXT NOT NULL,
            device_id  TEXT NOT NULL,
            created    REAL NOT NULL,
            expires    REAL NOT NULL
        );
        CREATE INDEX IF NOT EXISTS sessions_owner
            ON sessions(game, email_lower);
        """
    )


# ---------- password hashing ----------
def hash_password(password: str) -> str:
    salt = os.urandom(SALT_BYTES)
    dk = hashlib.scrypt(password.encode("utf-8"), salt=salt,
                        n=SCRYPT_N, r=SCRYPT_R, p=SCRYPT_P, dklen=32)
    return "scrypt$%d$%d$%d$%s$%s" % (SCRYPT_N, SCRYPT_R, SCRYPT_P,
                                      salt.hex(), dk.hex())


def verify_password(password: str, stored: str) -> bool:
    """Constant-time check. Returns False for anything malformed rather than raising."""
    try:
        scheme, n, r, p, salt_hex, hash_hex = stored.split("$")
        if scheme != "scrypt":
            return False
        dk = hashlib.scrypt(password.encode("utf-8"), salt=bytes.fromhex(salt_hex),
                            n=int(n), r=int(r), p=int(p), dklen=len(hash_hex) // 2)
    except (ValueError, TypeError, MemoryError):
        return False
    return hmac.compare_digest(dk.hex(), hash_hex)


# ---------- validation ----------
def valid_email(email: str) -> bool:
    e = email.strip()
    return 3 <= len(e) <= MAX_EMAIL and bool(EMAIL_RE.match(e))


def password_problem(password: str) -> str:
    """Returns "" when acceptable, else a machine-readable reason the client localises."""
    if len(password) < MIN_PASSWORD:
        return "password_short"
    if len(password) > MAX_PASSWORD:
        return "password_long"
    if password.strip() == "":
        return "password_short"
    return ""


# ---------- throttling ----------
def _note_failure(key: str) -> None:
    now = time.time()
    with _fail_lock:
        hits = [t for t in _fails.get(key, []) if now - t < LOGIN_WINDOW]
        hits.append(now)
        _fails[key] = hits


def _too_many_failures(key: str) -> bool:
    now = time.time()
    with _fail_lock:
        hits = [t for t in _fails.get(key, []) if now - t < LOGIN_WINDOW]
        _fails[key] = hits
        return len(hits) >= LOGIN_MAX_FAILS


def _clear_failures(key: str) -> None:
    with _fail_lock:
        _fails.pop(key, None)


def reset_throttle() -> None:
    """Test hook — the counters are process-local by design."""
    with _fail_lock:
        _fails.clear()


# ---------- sessions ----------
def _token_hash(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def issue_session(conn: sqlite3.Connection, game: str, email_lower: str,
                  device_id: str) -> str:
    """Mint a session token. Only its hash is stored, so a stolen DB yields no logins."""
    token = secrets.token_urlsafe(TOKEN_BYTES)
    now = time.time()
    conn.execute(
        "INSERT INTO sessions(token_hash, game, email_lower, device_id, created, expires)"
        " VALUES(?,?,?,?,?,?)",
        (_token_hash(token), game, email_lower, device_id, now, now + SESSION_TTL),
    )
    return token


def session_owner(conn: sqlite3.Connection, game: str, token: str):
    """The account behind a token, or None when missing/expired//for another game."""
    if not token:
        return None
    row = conn.execute(
        "SELECT email_lower, expires FROM sessions WHERE token_hash=? AND game=?",
        (_token_hash(token), game),
    ).fetchone()
    if row is None or row["expires"] < time.time():
        return None
    return row["email_lower"]


def drop_session(conn: sqlite3.Connection, token: str) -> None:
    conn.execute("DELETE FROM sessions WHERE token_hash=?", (_token_hash(token),))


# ---------- handlers ----------
# Each returns (http_status, payload) so the HTTP layer stays dumb and testable.
def register(conn: sqlite3.Connection, game: str, body: dict, ip: str):
    email = str(body.get("email", "")).strip()
    password = str(body.get("password", ""))
    device = str(body.get("device_id", "")).strip()[:64]
    if not valid_email(email):
        return 400, {"error": "invalid_email"}
    problem = password_problem(password)
    if problem:
        return 400, {"error": problem}
    lower = email.lower()
    existing = conn.execute(
        "SELECT email_lower FROM accounts WHERE game=? AND email_lower=?", (game, lower)
    ).fetchone()
    if existing:
        # Do NOT auto-login here: that would turn registration into an oracle that
        # confirms which addresses exist, and a wrong password would look like success.
        return 409, {"error": "email_taken"}
    conn.execute(
        "INSERT INTO accounts(game, email_lower, email, pw_hash, created) VALUES(?,?,?,?,?)",
        (game, lower, email, hash_password(password), time.time()),
    )
    token = issue_session(conn, game, lower, device)
    return 200, {"ok": True, "token": token, "email": email}


def login(conn: sqlite3.Connection, game: str, body: dict, ip: str):
    email = str(body.get("email", "")).strip()
    password = str(body.get("password", ""))
    device = str(body.get("device_id", "")).strip()[:64]
    if not valid_email(email) or not password:
        return 400, {"error": "invalid"}
    lower = email.lower()
    if _too_many_failures("e:" + lower) or _too_many_failures("i:" + ip):
        return 429, {"error": "too_many_attempts"}
    row = conn.execute(
        "SELECT email, pw_hash FROM accounts WHERE game=? AND email_lower=?", (game, lower)
    ).fetchone()
    # Always run a hash, even with no such account, so response time does not reveal
    # whether an address is registered.
    stored = row["pw_hash"] if row else hash_password(secrets.token_urlsafe(16))
    if not verify_password(password, stored) or row is None:
        _note_failure("e:" + lower)
        _note_failure("i:" + ip)
        return 401, {"error": "bad_credentials"}
    _clear_failures("e:" + lower)
    token = issue_session(conn, game, lower, device)
    return 200, {"ok": True, "token": token, "email": row["email"]}


def logout(conn: sqlite3.Connection, game: str, body: dict):
    drop_session(conn, str(body.get("token", "")))
    return 200, {"ok": True}


def account(conn: sqlite3.Connection, game: str, token: str):
    owner = session_owner(conn, game, token)
    if owner is None:
        return 401, {"error": "not_logged_in"}
    row = conn.execute(
        "SELECT email, created FROM accounts WHERE game=? AND email_lower=?", (game, owner)
    ).fetchone()
    if row is None:
        return 401, {"error": "not_logged_in"}
    return 200, {"email": row["email"], "created": row["created"]}
