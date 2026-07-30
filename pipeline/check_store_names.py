#!/usr/bin/env python3
"""Fail a store build that names a COMPETING store anywhere a player could see it.

Why this exists: Myket rejected release 5.4 because the phrase «پرداخت از طریق
کافه‌بازار انجام می‌شود» was hard-coded in `i18n.gd` and therefore shipped inside the
*Myket* APK as well as Bazaar's. Stores treat a reference to a rival as grounds for
rejection, and no amount of care in review catches a string that reads fine in the
source file you are looking at.

The strings live in Godot's exported script bytecode (`.gdc`), which is a small header
followed by a **zstd-compressed** token buffer — so a plain grep over the APK finds
nothing and gives a false all-clear. This decompresses before searching.

    python3 check_store_names.py <apk> <store>     # store: bazaar | myket

Exit 0 = clean, 1 = a rival's name was found (or the APK could not be inspected).
"""
import subprocess
import sys
import zipfile

# Names as a player would see them, per store. Latin and Persian spellings both, since
# either could be hard-coded.
STORE_NAMES = {
    "bazaar": ["کافه‌بازار", "کافه بازار", "کافه‌بازار", "Cafe Bazaar", "CafeBazaar"],
    "myket": ["مایکت", "Myket"],
}

# Package/permission identifiers are NOT player-visible and are required for billing to
# work at all, so they must not trip the guard.
ALLOWED_SUBSTRINGS = [
    "com.farsitel.bazaar", "ir.mservices.market", "poolakey",
    "PAY_THROUGH_BAZAAR", "mservices",
    # Godot singleton / plugin class names. Both stores' addon SCRIPTS ship in every
    # build (only the native library is gated), and these identifiers never reach a
    # player's screen.
    "GodotMyketBilling", "GodotPoolakey", "MyketBilling", "GF_STORE",
]

# Files that are pure plumbing for a store integration: their own store's name inside
# them is unavoidable and invisible to players.
ALLOWED_ENTRIES = ["addons/myket/", "addons/poolakey/"]


def _decompress_gdc(blob: bytes) -> bytes:
    """Godot 4 exports scripts as 'GDSC' + version + size + a zstd frame."""
    if not blob.startswith(b"GDSC") or len(blob) < 16:
        return blob
    try:
        return subprocess.run(["zstd", "-d", "-q", "-c"], input=blob[12:],
                              capture_output=True, timeout=30).stdout or blob
    except (OSError, subprocess.SubprocessError):
        return blob


def scan(apk_path: str, store: str) -> int:
    rivals = [n for other, names in STORE_NAMES.items() if other != store
              for n in names]
    if not rivals:
        print(f"check_store_names: unknown store '{store}'", file=sys.stderr)
        return 1
    try:
        zf = zipfile.ZipFile(apk_path)
    except (OSError, zipfile.BadZipFile) as exc:
        print(f"check_store_names: cannot open {apk_path}: {exc}", file=sys.stderr)
        return 1

    hits = []
    with zf:
        for entry in zf.namelist():
            # Only inspect what can carry UI text; native libs and images cannot.
            if not entry.endswith((".gdc", ".gd", ".json", ".txt", ".xml", ".po",
                                   ".csv", ".tres", ".scn", ".res")):
                continue
            if any(a in entry for a in ALLOWED_ENTRIES):
                continue
            try:
                blob = _decompress_gdc(zf.read(entry))
            except (OSError, RuntimeError):
                continue
            for enc in ("utf-8", "utf-16-le"):
                try:
                    text = blob.decode(enc, "ignore")
                except (LookupError, ValueError):
                    continue
                for name in rivals:
                    idx = text.find(name)
                    while idx != -1:
                        window = text[max(0, idx - 60):idx + 60]
                        if not any(a in window for a in ALLOWED_SUBSTRINGS):
                            hits.append((entry, name, window.strip()[:90]))
                            break
                        idx = text.find(name, idx + 1)
                    else:
                        continue
                    break

    if hits:
        print(f"RIVAL STORE NAMED in the {store} build:")
        for entry, name, window in hits[:8]:
            print(f"   {entry}: '{name}'  …{window}…")
        print("   A store rejects an APK that advertises a competitor. Use "
              "IAP.store_name() instead of a literal.")
        return 1
    print(f"   store-name check ok ({store}: no rival named)")
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(__doc__)
        raise SystemExit(2)
    raise SystemExit(scan(sys.argv[1], sys.argv[2]))
