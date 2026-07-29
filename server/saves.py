"""Cloud saves — an account backs up progress, it never gates it (LESSONS L72).

One JSON blob per (game, account). The client owns merge semantics; the server only
stores bytes, capped so nobody can use us as free file hosting.
"""
import json
import sqlite3
import time

import accounts

MAX_BLOB = 24_000  # bytes of encoded JSON


def init_db(conn: sqlite3.Connection) -> None:
    conn.executescript(
        """
        CREATE TABLE IF NOT EXISTS saves (
            game TEXT NOT NULL,
            account TEXT NOT NULL,
            blob TEXT NOT NULL,
            updated REAL NOT NULL,
            PRIMARY KEY (game, account)
        );
        """
    )


def get_save(conn: sqlite3.Connection, game: str, token: str):
    owner = accounts.session_owner(conn, game, token)
    if owner is None:
        return 401, {"error": "not_logged_in"}
    row = conn.execute(
        "SELECT blob, updated FROM saves WHERE game=? AND account=?",
        (game, owner)).fetchone()
    if row is None:
        return 404, {"error": "no_save"}
    try:
        blob = json.loads(row["blob"])
    except Exception:
        return 404, {"error": "no_save"}
    return 200, {"save": blob, "updated": row["updated"]}


def put_save(conn: sqlite3.Connection, game: str, token: str, blob):
    if not isinstance(blob, dict):
        return 400, {"error": "invalid"}
    encoded = json.dumps(blob, ensure_ascii=False)
    if len(encoded.encode()) > MAX_BLOB:
        return 413, {"error": "too_large"}
    owner = accounts.session_owner(conn, game, token)
    if owner is None:
        return 401, {"error": "not_logged_in"}
    conn.execute(
        "INSERT INTO saves(game, account, blob, updated) VALUES(?,?,?,?) "
        "ON CONFLICT(game, account) DO UPDATE SET blob=excluded.blob, "
        "updated=excluded.updated",
        (game, owner, encoded, time.time()))
    return 200, {"ok": True}
