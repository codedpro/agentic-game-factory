# Scoreboard, accounts and receipt validation

One dependency-free Python process (stdlib only) serving every game the factory makes.
Runs on port 3000; point a subdomain at it (`mergedrop.1xai.ir` today).

```bash
cd server && python3 scoreboard.py          # PORT and SCOREBOARD_DB override the defaults
python3 test_server.py                      # 30 tests, no network needed
```

## Routes

| Route | Purpose |
|---|---|
| `GET  /healthz` | liveness |
| `POST /api/<game>/nickname` | claim a unique leaderboard name |
| `POST /api/<game>/score` | submit a score (best-kept-wins) |
| `GET  /api/<game>/board` | top scores + your rank |
| `GET  /api/<game>/me` | your nickname and bests |
| `POST /api/<game>/register` \| `login` \| `logout` | email + password accounts |
| `GET  /api/<game>/account?token=` | who am I |
| `POST /api/<game>/verify_purchase` | server-side receipt validation |
| `GET  /api/<game>/purchases?token=` | your receipt history |

## The rules this server exists to enforce

* **The game must work with this process dead.** Every client call is optional; scores and
  receipts queue locally and reconcile later.
* **An account is needed only to buy.** Never to play, score, or collect the daily ritual.
* **Passwords**: scrypt (n=2^14, r=8, p=1), per-user 16-byte salt, constant-time compare.
  Sessions are random 32-byte tokens stored only as a SHA-256 hash.
* **Emails are not verified**, by product decision — so there is deliberately **no password
  reset**, because a reset link to an unproven address is an account-takeover primitive.
* **Receipt validation has three outcomes**: confirmed, denied, or *unknown*. Unknown
  (network down, our access key rejected) returns `503` so the client keeps the receipt and
  retries. Denying a paying customer on a timeout is the one unacceptable failure.

## Secrets

The Myket server-to-server access key is read from `MYKET_ACCESS_KEY` or
`MYKET_KEY_FILE` (default `<tools>/secrets/myket_access_key.txt`). It is **not** in this
repository and **not** in any APK — a grep over every built artifact confirms it.

Cafe Bazaar receipts are **not** server-verified: its developer API needs an OAuth client
id, secret and refresh token from the Pishkhan panel, which we do not have. Those receipts
are recorded with `verified: false` rather than pretending a check happened. Poolakey still
validates Bazaar's signature on the device.

## Backups

`scores.db` holds real player data. Back it up before any deploy:

```bash
cp server/scores.db <tools>/secrets/scores-backup-$(date +%Y%m%d-%H%M%S).db
```
