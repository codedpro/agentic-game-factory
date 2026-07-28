#!/usr/bin/env python3
"""Back up the scoreboard database, keeping the most recent N copies.

Uses sqlite3's own online backup API rather than copying the file: `cp` on a live
database can capture a half-written transaction, and the corruption only shows up on
the day you actually need the backup.

The database holds real player accounts and paid receipts, so backups are written
mode 600 alongside the other secrets.

    python3 backup_db.py [--keep 14]
"""
import argparse
import glob
import os
import sqlite3
import sys
import time

DEFAULT_DB = os.environ.get(
    "SCOREBOARD_DB", "/home/claude/godot/server/scores.db")
DEFAULT_DIR = os.environ.get(
    "BACKUP_DIR", "/home/claude/tools/secrets")
PREFIX = "scores-backup-"


def backup(db_path: str, out_dir: str, keep: int) -> str:
    if not os.path.exists(db_path):
        raise SystemExit(f"no database at {db_path}")
    os.makedirs(out_dir, exist_ok=True)
    dst = os.path.join(out_dir, PREFIX + time.strftime("%Y%m%d-%H%M%S") + ".db")
    src = sqlite3.connect(db_path)
    try:
        target = sqlite3.connect(dst)
        try:
            src.backup(target)          # consistent snapshot of a live database
        finally:
            target.close()
    finally:
        src.close()
    os.chmod(dst, 0o600)

    # Verify the copy opens and has the tables we expect, so a silently broken backup
    # is caught now rather than during a restore.
    check = sqlite3.connect(dst)
    try:
        names = {r[0] for r in check.execute(
            "SELECT name FROM sqlite_master WHERE type='table'")}
    finally:
        check.close()
    missing = {"players", "scores"} - names
    if missing:
        os.remove(dst)
        raise SystemExit(f"backup verification failed, missing tables: {missing}")

    pruned = 0
    existing = sorted(glob.glob(os.path.join(out_dir, PREFIX + "*.db")))
    for old in existing[:-keep] if keep > 0 else []:
        os.remove(old)
        pruned += 1
    print(f"backed up to {dst} ({os.path.getsize(dst)} bytes), "
          f"kept {min(len(existing), keep)}, pruned {pruned}")
    return dst


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--db", default=DEFAULT_DB)
    ap.add_argument("--out", default=DEFAULT_DIR)
    ap.add_argument("--keep", type=int, default=14)
    args = ap.parse_args()
    backup(args.db, args.out, args.keep)
    return 0


if __name__ == "__main__":
    sys.exit(main())
