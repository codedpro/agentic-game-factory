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

## Running it so it stays running

Two supported ways. Both keep the database and the secrets **outside** the deployed
artifact, which is what makes a redeploy safe.

### Docker (preferred where Docker exists)

```bash
cd server && docker compose up -d
```

* `restart: unless-stopped` brings the container back after a crash **and** after a host
  reboot.
* The database lives in the named volume `gamefactory-scoreboard-data`, so
  `docker compose down` and image rebuilds lose nothing.
* Secrets are bind-mounted from the host, never baked into an image. The mount is
  writable because the one-time Bazaar OAuth consent writes a refresh token back.
* Published on `127.0.0.1:3000` only — nginx terminates TLS in front of it. Binding
  `0.0.0.0` would expose plaintext HTTP and let anyone bypass TLS with passwords in the
  clear.
* Runs as uid 10001 with a read-only root filesystem and all capabilities dropped.

### systemd (what this host uses — Docker is not installed here)

```bash
cp server/systemd/*.service server/systemd/*.timer ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now gamefactory-scoreboard.service
loginctl enable-linger "$USER"     # REQUIRED, or the service dies at logout
```

`enable-linger` is the step people miss: without it a user service does not start at
boot and stops when the session ends.

Verify it actually recovers rather than trusting the config:

```bash
kill -9 $(systemctl --user show -p MainPID --value gamefactory-scoreboard.service)
sleep 5 && curl -s https://mergedrop.1xai.ir/healthz   # expect {"ok": true}
```

## Backups

The database holds player accounts and **paid receipts**, so losing it costs real money.
`gamefactory-backup.timer` runs daily and keeps the last 14 copies:

```bash
python3 server/backup_db.py --keep 14      # manual run
systemctl --user list-timers gamefactory-backup.timer
```

It uses sqlite3's online backup API, not `cp` — copying a live database can capture a
half-written transaction, and that corruption only surfaces on the day you need it. Each
backup is re-opened and checked for its tables before older copies are pruned.

**Always back up before a deploy.** Restarting the process is a few seconds of downtime;
the client queues scores and receipts through it, but a bad migration is not recoverable
without a copy.
