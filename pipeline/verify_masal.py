#!/usr/bin/env python3
"""Verify the مثلستان proverb seed with a 2-of-3 model consensus (LESSONS L19), then
compute the playable level data (target words, letter wheel, difficulty order).

Input : games/masalestan/assets/masal/masal_seed.json
Output: games/masalestan/assets/masal/masal.json      (verified, playable levels)
        games/masalestan/assets/masal/verify_report.json  (per-entry verdicts)
"""
import json, os, re, sys, time, urllib.request
from collections import Counter
from concurrent.futures import ThreadPoolExecutor

KEY = os.environ.get("IMAGE_API_KEY", "")
URL = "https://1xai.ir/v1/chat/completions"
BASE = "/home/claude/godot/games/masalestan/assets/masal"
JUDGES = ["gpt-4o", "gpt-4.1", "gemini-2.5-flash"]

ZWNJ = "‌"
LETTERS = set("ابپتثجچحخدذرزژسشصضطظعغفقکگلمنوهیآ")
STOP = {"که", "از", "به", "را", "و", "در", "با", "بر", "تا", "هر", "چه", "اگر",
        "ولی", "اما", "یا", "هم", "نه", "ای", "است", "بود", "شد", "می", "نمی",
        "خود", "او", "آن", "این", "ما", "تو", "من", "چون", "کی", "بی", "پس",
        "ز", "بهر", "وای", "گر", "چو", "نیست", "باش", "باشی", "باشد", "شود",
        "کند", "کنی", "کرد", "است؟", "تویِ", "توی", "یک", "دو", "صد"}
MAX_TILES = 8          # per-round wheel capacity
MAX_ROUND_TARGETS = 4  # words per round
MAX_WORD_LEN = 6
MIN_TARGETS = 2        # a proverb needs at least this many playable words in total


def call(model, prompt, retries=3, timeout=180):
    body = json.dumps({"model": model, "temperature": 0.0,
                       "messages": [{"role": "user", "content": prompt}]}).encode()
    err = None
    for a in range(retries):
        try:
            req = urllib.request.Request(URL, data=body, headers={
                "Authorization": f"Bearer {KEY}", "Content-Type": "application/json",
                "User-Agent": "curl/8.5.0"})  # gateway 403s the default python UA (L18)
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return json.load(r)["choices"][0]["message"]["content"]
        except Exception as e:
            err = e
            time.sleep(3 * (a + 1))
    print(f"  [{model}] failed: {str(err)[:80]}", flush=True)
    return ""


def judge_batch(model, batch):
    lines = "\n".join(f'- id={e["id"]} | مثل: «{e["text"]}» | معنی: «{e["meaning"]}»'
                      for e in batch)
    prompt = f"""تو کارشناس ادبیات عامیانه و ضرب‌المثل‌های فارسی هستی. برای هر مورد زیر دو سؤال را جدا جدا پاسخ بده:
1. wording_ok: آیا این یک ضرب‌المثل یا اصطلاح رایج و اصیل فارسی است و همین صورتِ نوشته‌شده، یکی از صورت‌های رایج آن است؟ (تغییرات جزئی رسم‌الخط یا حذف/اضافهٔ یک حرف ربط مهم نیست؛ اما اگر مثل ساختگی است یا صورت آن اشتباه رایج است، false بده.)
2. meaning_ok: آیا معنیِ داده‌شده برداشتِ درست و متعارف از این مثل است؟

فقط JSON خالص برگردان، بدون توضیح، با این قالب:
[{{"id": "...", "wording_ok": true, "meaning_ok": true, "note": "اختیاری، فقط اگر false"}}]

موارد:
{lines}"""
    raw = call(model, prompt)
    m = re.search(r"\[.*\]", raw, re.S)
    if not m:
        return {}
    try:
        rows = json.loads(m.group(0))
        return {r["id"]: (bool(r.get("wording_ok")), bool(r.get("meaning_ok")),
                          str(r.get("note", ""))) for r in rows if "id" in r}
    except Exception as e:
        print(f"  [{model}] bad JSON: {e}", flush=True)
        return {}


def tokenize(text):
    clean = re.sub(r"[،؟!.:؛«»()]", " ", text)
    return [t for t in re.split(rf"[\s{ZWNJ}]+", clean) if t]


def targets_for(text):
    seen, out = set(), []
    for tok in tokenize(text):
        if tok in STOP or tok in seen:
            continue
        if not (2 <= len(tok) <= MAX_WORD_LEN):
            continue
        if not set(tok) <= LETTERS:
            continue
        seen.add(tok)
        out.append(tok)
    return out


def wheel_for(targets):
    need = Counter()
    for w in targets:
        c = Counter(w)
        for ch, n in c.items():
            need[ch] = max(need[ch], n)
    return need


def tiles(group):
    return sum(wheel_for(group).values())


def pack_rounds(targets):
    """Agglomerative packing: merge target groups that share letters until no merge
    keeps the wheel within MAX_TILES and MAX_ROUND_TARGETS. Singletons whose word
    alone exceeds MAX_TILES cannot exist (words are ≤6 letters), so this terminates
    with every target placed."""
    groups = [[t] for t in targets]
    while True:
        best, best_gain = None, -1
        for i in range(len(groups)):
            for j in range(i + 1, len(groups)):
                merged = groups[i] + groups[j]
                if len(merged) > MAX_ROUND_TARGETS or tiles(merged) > MAX_TILES:
                    continue
                gain = tiles(groups[i]) + tiles(groups[j]) - tiles(merged)
                if gain > best_gain:
                    best, best_gain = (i, j), gain
        if best is None:
            break
        i, j = best
        groups[i] = groups[i] + groups[j]
        del groups[j]
    # order rounds roughly left-to-right through the proverb
    order = {t: k for k, t in enumerate(targets)}
    groups.sort(key=lambda g: sum(order[t] for t in g) / len(g))
    return groups


def run_judges(seed):
    batches = [seed[i:i + 10] for i in range(0, len(seed), 10)]
    verdicts = {e["id"]: [] for e in seed}
    with ThreadPoolExecutor(max_workers=3) as pool:
        futs = {}
        for model in JUDGES:
            for b in batches:
                futs[pool.submit(judge_batch, model, b)] = (model, b)
        for fut in futs:
            model, b = futs[fut]
            res = fut.result()
            for e in b:
                if e["id"] in res:
                    verdicts[e["id"]].append((model,) + res[e["id"]])
    report = {}
    for e in seed:
        vs = verdicts[e["id"]]
        w_ok = sum(1 for v in vs if v[1])
        m_ok = sum(1 for v in vs if v[2])
        report[e["id"]] = {"votes": [{"model": v[0], "wording": v[1], "meaning": v[2],
                                      "note": v[3]} for v in vs],
                           "kept": len(vs) >= 2 and w_ok >= 2 and m_ok >= 2}
    return report


def main():
    seed = json.load(open(f"{BASE}/masal_seed.json"))["entries"]
    recompute = "--recompute" in sys.argv
    if recompute:
        report = json.load(open(f"{BASE}/verify_report.json"))
        for r in report.values():  # re-derive 'kept' from stored votes only
            w_ok = sum(1 for v in r["votes"] if v["wording"])
            m_ok = sum(1 for v in r["votes"] if v["meaning"])
            r["kept"] = len(r["votes"]) >= 2 and w_ok >= 2 and m_ok >= 2
            r.pop("drop_reason", None)
        print(f"{len(seed)} seed proverbs; reusing stored verdicts", flush=True)
    else:
        print(f"{len(seed)} seed proverbs; judging with {JUDGES}", flush=True)
        report = run_judges(seed)
    kept = [e for e in seed if report.get(e["id"], {}).get("kept")]
    print(f"consensus kept {len(kept)}/{len(seed)}", flush=True)

    levels, dropped_fit = [], []
    for e in kept:
        ts = targets_for(e["text"])
        if len(ts) < MIN_TARGETS:
            dropped_fit.append(e["id"])
            report[e["id"]]["kept"] = False
            report[e["id"]]["drop_reason"] = f"only {len(ts)} playable targets"
            continue
        rounds = pack_rounds(ts)
        rounds_out = []
        for g in rounds:
            wheel = []
            for ch, n in sorted(wheel_for(g).items()):
                wheel += [ch] * n
            rounds_out.append({"targets": g, "wheel": wheel})
        diff = len(ts) * 10 + len(rounds) * 5 + sum(len(t) for t in ts)
        levels.append({"id": e["id"], "text": e["text"], "meaning": e["meaning"],
                       "rounds": rounds_out, "difficulty": diff})
    levels.sort(key=lambda l: (l["difficulty"], l["id"]))
    print(f"dropped for playability: {len(dropped_fit)} {dropped_fit}", flush=True)
    print(f"final pool: {len(levels)} levels", flush=True)

    json.dump({"generated": "verify_masal.py", "count": len(levels), "levels": levels},
              open(f"{BASE}/masal.json", "w"), ensure_ascii=False, indent=1)
    json.dump(report, open(f"{BASE}/verify_report.json", "w"), ensure_ascii=False, indent=1)
    rc = Counter(len(l["rounds"]) for l in levels)
    tc = Counter(sum(len(r["targets"]) for r in l["rounds"]) for l in levels)
    print(f"rounds histogram: {dict(sorted(rc.items()))}", flush=True)
    print(f"total-targets histogram: {dict(sorted(tc.items()))}", flush=True)


if __name__ == "__main__":
    main()
