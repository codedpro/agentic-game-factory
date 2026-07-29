#!/usr/bin/env python3
"""Expand the مثلستان proverb seed: draft candidates with several independent models,
dedupe against the existing seed, append as new entries. Nothing ships from here —
pipeline/verify_masal.py (2-of-3 consensus) is still the gate (L19).

Usage: expand_masal.py [target_total]   (default 260 seed entries)
"""
import json, os, re, sys, time, unicodedata, urllib.request
from concurrent.futures import ThreadPoolExecutor

KEY = os.environ["IMAGE_API_KEY"]
URL = "https://1xai.ir/v1/chat/completions"
BASE = "/home/claude/godot/games/masalestan/assets/masal"
DRAFTERS = ["gpt-4o", "gpt-4.1", "gemini-2.5-flash"]
TARGET = int(sys.argv[1]) if len(sys.argv) > 1 else 260


def call(model, prompt, retries=3, timeout=240):
    body = json.dumps({"model": model, "temperature": 0.7,
                       "messages": [{"role": "user", "content": prompt}]}).encode()
    err = None
    for a in range(retries):
        try:
            req = urllib.request.Request(URL, data=body, headers={
                "Authorization": f"Bearer {KEY}", "Content-Type": "application/json",
                "User-Agent": "curl/8.5.0"})
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return json.load(r)["choices"][0]["message"]["content"]
        except Exception as e:
            err = e
            time.sleep(3 * (a + 1))
    print(f"  [{model}] failed: {str(err)[:80]}", flush=True)
    return ""


def norm(s):
    s = unicodedata.normalize("NFKC", s)
    s = re.sub(r"[ً-ْ‌\s،؟!.:؛«»()]", "", s)
    return s.replace("ي", "ی").replace("ك", "ک").replace("ۀ", "ه").replace("آ", "ا")


def draft(model, avoid_sample):
    prompt = f"""تو گردآورندهٔ ضرب‌المثل‌های اصیل فارسی هستی. ۴۰ ضرب‌المثل یا اصطلاح مثلیِ کاملاً رایج و اصیل فارسی بنویس که در فهرست زیر نباشند. برای هر کدام صورتِ رایج و یک معنیِ یک‌جمله‌ای دقیق بده.

شرط‌ها:
- فقط مثل‌های واقعاً رایج و شناخته‌شده؛ هیچ مثل ساختگی یا کم‌کاربرد نیاور.
- صورت معیارِ نوشتاری با نیم‌فاصلهٔ درست.
- از مثل‌های حاوی توهین قومی، ناسزا یا مضمون قمار پرهیز کن.

فقط JSON خالص برگردان: [{{"text": "...", "meaning": "..."}}]

فهرست موجود (نیاور):
{avoid_sample}"""
    raw = call(model, prompt)
    m = re.search(r"\[.*\]", raw, re.S)
    if not m:
        return []
    try:
        rows = json.loads(m.group(0))
        return [r for r in rows if isinstance(r, dict) and r.get("text") and r.get("meaning")]
    except Exception:
        return []


def main():
    data = json.load(open(f"{BASE}/masal_seed.json"))
    entries = data["entries"]
    seen = {norm(e["text"]) for e in entries}
    next_id = max(int(e["id"][1:]) for e in entries) + 1
    rounds = 0
    while len(entries) < TARGET and rounds < 4:
        rounds += 1
        avoid = "، ".join(e["text"] for e in entries)
        with ThreadPoolExecutor(max_workers=3) as pool:
            batches = list(pool.map(lambda mdl: draft(mdl, avoid), DRAFTERS))
        added = 0
        for batch in batches:
            for r in batch:
                text = str(r["text"]).strip()
                key = norm(text)
                if not key or key in seen:
                    continue
                # skip candidates whose normalized form is a substring of an existing
                # one (or vice versa) — near-duplicate wordings of the same مثل
                if any(key in s or s in key for s in seen if len(s) > 8 and len(key) > 8):
                    continue
                seen.add(key)
                entries.append({"id": "m%03d" % next_id, "text": text,
                                "meaning": str(r["meaning"]).strip()})
                next_id += 1
                added += 1
                if len(entries) >= TARGET:
                    break
            if len(entries) >= TARGET:
                break
        print(f"round {rounds}: +{added} → {len(entries)}", flush=True)
        if added == 0:
            break
    json.dump(data, open(f"{BASE}/masal_seed.json", "w"), ensure_ascii=False, indent=1)
    print(f"seed now {len(entries)} entries", flush=True)


if __name__ == "__main__":
    main()
