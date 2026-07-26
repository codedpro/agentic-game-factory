#!/usr/bin/env python3
"""Global scoreboard for the game factory — offline-first, tiny, dependency-free.

Runs on port 3000; point a subdomain (e.g. mergedrop.1xai.ir) at it. Every route is
namespaced by game slug, so one server serves every game the factory makes:

    POST /api/<game>/nickname   {device_id, nickname}        -> claim a unique nickname
    POST /api/<game>/score      {device_id, score, mode}     -> submit a score
    GET  /api/<game>/board?mode=endless&limit=50&device_id=  -> top scores (+ your rank)
    GET  /api/<game>/me?device_id=                           -> your nickname + best
    GET  /healthz

Design rules:
  * The GAME must work with this server down — the client treats every call as optional.
  * A device_id is a random string the client generates; no accounts, no personal data.
  * Nicknames are unique, case-insensitively, and validated for length and characters.
  * Scores are append-only per device with a best-kept-wins rule, so replays can't lower a rank.
"""
import json
import os
import re
import sqlite3
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

DB_PATH = os.environ.get("SCOREBOARD_DB", os.path.join(os.path.dirname(__file__), "scores.db"))
PORT = int(os.environ.get("PORT", "3000"))
MAX_SCORE = 100_000_000
NICK_RE = re.compile(r"^[\w؀-ۿ][\w؀-ۿ ._-]{1,18}$", re.UNICODE)
RATE_WINDOW = 60
RATE_MAX = 60

_lock = threading.Lock()
_hits: dict[str, list[float]] = {}


def db():
    conn = sqlite3.connect(DB_PATH, timeout=10)
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    with db() as conn:
        conn.executescript(
            """
            CREATE TABLE IF NOT EXISTS players (
                game TEXT NOT NULL,
                device_id TEXT NOT NULL,
                nickname TEXT NOT NULL,
                nick_lower TEXT NOT NULL,
                created REAL NOT NULL,
                PRIMARY KEY (game, device_id)
            );
            CREATE UNIQUE INDEX IF NOT EXISTS players_nick
                ON players(game, nick_lower);
            CREATE TABLE IF NOT EXISTS scores (
                game TEXT NOT NULL,
                device_id TEXT NOT NULL,
                mode TEXT NOT NULL,
                score INTEGER NOT NULL,
                updated REAL NOT NULL,
                PRIMARY KEY (game, device_id, mode)
            );
            CREATE INDEX IF NOT EXISTS scores_board
                ON scores(game, mode, score DESC);
            """
        )


def rate_limited(ip: str) -> bool:
    now = time.time()
    with _lock:
        hits = [t for t in _hits.get(ip, []) if now - t < RATE_WINDOW]
        hits.append(now)
        _hits[ip] = hits
        return len(hits) > RATE_MAX


def valid_nick(n: str) -> bool:
    return bool(n) and bool(NICK_RE.match(n.strip()))


class Handler(BaseHTTPRequestHandler):
    server_version = "GameFactoryScoreboard/1.0"

    # ---------- plumbing ----------
    def log_message(self, fmt, *args):  # keep the console quiet
        pass

    def _send(self, code: int, payload: dict):
        body = json.dumps(payload, ensure_ascii=False).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()
        self.wfile.write(body)

    def _body(self) -> dict:
        try:
            n = int(self.headers.get("Content-Length", "0"))
            if n <= 0 or n > 8192:
                return {}
            return json.loads(self.rfile.read(n).decode("utf-8"))
        except Exception:
            return {}

    def _parts(self):
        u = urlparse(self.path)
        return [p for p in u.path.split("/") if p], parse_qs(u.query)

    def do_OPTIONS(self):
        self._send(204, {})

    # ---------- routes ----------
    def do_GET(self):
        parts, q = self._parts()
        if parts == ["healthz"]:
            return self._send(200, {"ok": True})
        if len(parts) == 3 and parts[0] == "api" and parts[2] == "board":
            return self.board(parts[1], q)
        if len(parts) == 3 and parts[0] == "api" and parts[2] == "me":
            return self.me(parts[1], q)
        self._send(404, {"error": "not_found"})

    def do_POST(self):
        if rate_limited(self.client_address[0]):
            return self._send(429, {"error": "slow_down"})
        parts, _ = self._parts()
        if len(parts) == 3 and parts[0] == "api" and parts[2] == "nickname":
            return self.claim_nickname(parts[1])
        if len(parts) == 3 and parts[0] == "api" and parts[2] == "score":
            return self.submit_score(parts[1])
        self._send(404, {"error": "not_found"})

    # ---------- handlers ----------
    def claim_nickname(self, game: str):
        d = self._body()
        device = str(d.get("device_id", "")).strip()
        nick = str(d.get("nickname", "")).strip()
        if not device or not valid_nick(nick):
            return self._send(400, {"error": "invalid"})
        with db() as conn:
            taken = conn.execute(
                "SELECT device_id FROM players WHERE game=? AND nick_lower=?",
                (game, nick.lower()),
            ).fetchone()
            if taken and taken["device_id"] != device:
                return self._send(409, {"error": "taken"})
            conn.execute(
                "INSERT INTO players(game, device_id, nickname, nick_lower, created)"
                " VALUES(?,?,?,?,?)"
                " ON CONFLICT(game, device_id) DO UPDATE SET nickname=?, nick_lower=?",
                (game, device, nick, nick.lower(), time.time(), nick, nick.lower()),
            )
        self._send(200, {"ok": True, "nickname": nick})

    def submit_score(self, game: str):
        d = self._body()
        device = str(d.get("device_id", "")).strip()
        mode = str(d.get("mode", "endless")).strip()[:16] or "endless"
        try:
            score = int(d.get("score", 0))
        except (TypeError, ValueError):
            return self._send(400, {"error": "invalid"})
        if not device or score < 0 or score > MAX_SCORE:
            return self._send(400, {"error": "invalid"})
        with db() as conn:
            player = conn.execute(
                "SELECT nickname FROM players WHERE game=? AND device_id=?", (game, device)
            ).fetchone()
            if not player:
                return self._send(403, {"error": "no_nickname"})
            # best-kept-wins: a later, worse run must never lower a standing rank
            conn.execute(
                "INSERT INTO scores(game, device_id, mode, score, updated) VALUES(?,?,?,?,?)"
                " ON CONFLICT(game, device_id, mode) DO UPDATE SET"
                " score=MAX(score, excluded.score), updated=excluded.updated",
                (game, device, mode, score, time.time()),
            )
            best = conn.execute(
                "SELECT score FROM scores WHERE game=? AND device_id=? AND mode=?",
                (game, device, mode),
            ).fetchone()["score"]
            rank = conn.execute(
                "SELECT COUNT(*)+1 AS r FROM scores WHERE game=? AND mode=? AND score>?",
                (game, mode, best),
            ).fetchone()["r"]
        self._send(200, {"ok": True, "best": best, "rank": rank})

    def board(self, game: str, q: dict):
        mode = (q.get("mode", ["endless"])[0])[:16] or "endless"
        try:
            limit = max(1, min(100, int(q.get("limit", ["50"])[0])))
        except ValueError:
            limit = 50
        device = q.get("device_id", [""])[0]
        with db() as conn:
            rows = conn.execute(
                "SELECT p.nickname, s.score FROM scores s JOIN players p"
                " ON p.game=s.game AND p.device_id=s.device_id"
                " WHERE s.game=? AND s.mode=? ORDER BY s.score DESC, s.updated ASC LIMIT ?",
                (game, mode, limit),
            ).fetchall()
            top = [{"rank": i + 1, "nickname": r["nickname"], "score": r["score"]}
                   for i, r in enumerate(rows)]
            you = None
            if device:
                mine = conn.execute(
                    "SELECT score FROM scores WHERE game=? AND device_id=? AND mode=?",
                    (game, device, mode),
                ).fetchone()
                if mine:
                    rank = conn.execute(
                        "SELECT COUNT(*)+1 AS r FROM scores WHERE game=? AND mode=? AND score>?",
                        (game, mode, mine["score"]),
                    ).fetchone()["r"]
                    you = {"rank": rank, "score": mine["score"]}
            total = conn.execute(
                "SELECT COUNT(*) AS c FROM scores WHERE game=? AND mode=?", (game, mode)
            ).fetchone()["c"]
        self._send(200, {"mode": mode, "total": total, "top": top, "you": you})

    def me(self, game: str, q: dict):
        device = q.get("device_id", [""])[0]
        if not device:
            return self._send(400, {"error": "invalid"})
        with db() as conn:
            p = conn.execute(
                "SELECT nickname FROM players WHERE game=? AND device_id=?", (game, device)
            ).fetchone()
            scores = conn.execute(
                "SELECT mode, score FROM scores WHERE game=? AND device_id=?", (game, device)
            ).fetchall()
        self._send(200, {
            "nickname": p["nickname"] if p else "",
            "scores": {r["mode"]: r["score"] for r in scores},
        })


def main():
    init_db()
    server = ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
    print(f"scoreboard listening on 0.0.0.0:{PORT} (db: {DB_PATH})", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
