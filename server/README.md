# Scoreboard server

One tiny, dependency-free Python server for every game the factory makes. Offline-first by
design: the games treat it as optional and stay fully playable when it is unreachable.

## Run

```bash
cd <repo>/server
PORT=3000 python3 scoreboard.py          # listens on 0.0.0.0:3000, SQLite at ./scores.db
```

Point a subdomain at this port, e.g. `mergedrop.1xai.ir` → `<this machine>:3000`.
Routes are namespaced per game, so the same server also serves future games:

| Route | Purpose |
|---|---|
| `POST /api/<game>/nickname` | claim a globally unique nickname (`{device_id, nickname}`) |
| `POST /api/<game>/score` | submit a score (`{device_id, score, mode}`), best-kept-wins |
| `GET /api/<game>/board?mode=&limit=&device_id=` | top scores + your own rank |
| `GET /api/<game>/me?device_id=` | your nickname and bests |
| `GET /healthz` | liveness |

## Behaviour that matters

- **Unique nicknames**, case-insensitive per game; a second device claiming a taken name gets 409.
- **Best-kept-wins**: a later, worse run can never lower a standing rank.
- **No accounts, no personal data** — just a random per-install `device_id` the client generates.
- Rate limited to 60 writes/minute per IP; scores above 100,000,000 are rejected.
- Persian nicknames are supported and validated (2–18 characters).

## Client side

`games/<slug>/scripts/online.gd` queues scores locally when offline and flushes them on the next
successful contact. Override the server per install by writing a URL into `user://server.txt`
(used for local testing against `http://127.0.0.1:3000`).
