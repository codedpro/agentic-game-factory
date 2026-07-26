#!/usr/bin/env python3
"""Expand the fal treasury: draft candidate verses with several independent models,
then keep only those a 2-of-3 model consensus confirms as authentic.

Authenticity is the product here — getting حافظ wrong would destroy user trust,
so nothing ships on a single model's say-so (LESSONS L19).
"""
import json, os, re, sys, time, urllib.request, unicodedata
from concurrent.futures import ThreadPoolExecutor

KEY = os.environ["IMAGE_API_KEY"]
URL = "https://1xai.ir/v1/chat/completions"
FAL = "/home/claude/godot/games/mergedrop/assets/fal/fal.json"
DRAFTERS = ["gpt-4o", "gpt-4.1", "gemini-2.5-flash"]
JUDGES = ["gpt-4o", "gemini-2.5-flash", "gpt-4.1"]


def call(model, prompt, retries=3, timeout=180):
    body = json.dumps({"model": model, "temperature": 0.4,
                       "messages": [{"role": "user", "content": prompt}]}).encode()
    for a in range(retries):
        try:
            req = urllib.request.Request(URL, data=body, headers={
                "Authorization": f"Bearer {KEY}", "Content-Type": "application/json",
                "User-Agent": "curl/8.5.0"})   # gateway 403s the default python UA (L18)
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return json.load(r)["choices"][0]["message"]["content"]
        except Exception as e:
            err = e
            time.sleep(3 * (a + 1))
    print(f"  [{model}] failed: {str(err)[:70]}", flush=True)
    return ""


def norm(s):
    s = unicodedata.normalize("NFKC", s)
    s = re.sub(r"[ً-ْ‌\s]", "", s)      # diacritics, ZWNJ, spaces
    s = s.replace("ي", "ی").replace("ك", "ک").replace("ۀ", "ه").replace("آ", "ا")
    return s


DRAFT_PROMPT = """{n} بیت مشهور و کاملاً معتبر از شاعران کلاسیک فارسی ({who}) بنویس که برای «فال» مناسب باشند.
برای هر بیت یک «تعبیر» به سبک فال حافظ بنویس: مثبت و امیدوارکننده، خطاب به «تو»، یک یا دو جمله، بدون حکم شرعی.
فقط بیت‌هایی را بیاور که از صحت متن و انتساب آن‌ها کاملاً مطمئنی. هرگز بیت نسازد.
این بیت‌ها قبلاً استفاده شده‌اند، تکرارشان نکن:
{used}

خروجی فقط JSON معتبر، بدون توضیح اضافه:
{{"poems":[{{"poet":"حافظ","verse":"مصرع اول\\nمصرع دوم","interp":"تعبیر"}}]}}"""

JUDGE_PROMPT = """این بیت به {poet} نسبت داده شده است:
"{verse}"
آیا این بیت واقعاً از این شاعر است و متن آن (با اغماض در رسم‌الخط و فاصله‌گذاری) درست است؟
اگر بیت مشهور و متعلق به این شاعر است true بده. اگر مطمئن نیستی یا انتساب مشکوک است false بده.
فقط JSON: {{"authentic": true/false}}"""


def parse_json(txt):
    m = re.search(r"\{.*\}", txt, re.S)
    if not m:
        return None
    try:
        return json.loads(m.group(0))
    except Exception:
        return None


existing = json.load(open(FAL))
used_norm = {norm(p["verse"]) for p in existing}
used_list = "\n".join("- " + p["verse"].split("\n")[0] for p in existing)

# ---------- draft ----------
jobs = []
for m in DRAFTERS:
    jobs.append((m, DRAFT_PROMPT.format(n=22, who="حافظ", used=used_list)))
    jobs.append((m, DRAFT_PROMPT.format(n=14, who="سعدی، مولانا، خیام، فردوسی، نظامی، باباطاهر",
                                        used=used_list)))
print(f"drafting with {len(DRAFTERS)} models ({len(jobs)} requests)...", flush=True)
with ThreadPoolExecutor(max_workers=6) as ex:
    drafts = list(ex.map(lambda j: call(*j), jobs))

cands, seen = [], set(used_norm)
for txt in drafts:
    d = parse_json(txt) or {}
    for p in d.get("poems", []):
        v, poet, interp = p.get("verse", ""), p.get("poet", ""), p.get("interp", "")
        if not v or not poet or not interp or "\n" not in v:
            continue
        k = norm(v)
        if k in seen or len(k) < 25:
            continue
        seen.add(k)
        cands.append({"poet": poet.strip(), "verse": v.strip(), "interp": interp.strip()})
print(f"{len(cands)} unique candidates after dedupe", flush=True)

# ---------- verify (2-of-3 consensus) ----------
vjobs = [(m, c) for c in cands for m in JUDGES]
print(f"verifying ({len(vjobs)} requests)...", flush=True)
with ThreadPoolExecutor(max_workers=8) as ex:
    votes = list(ex.map(
        lambda j: (id(j[1]), parse_json(call(j[0], JUDGE_PROMPT.format(
            poet=j[1]["poet"], verse=j[1]["verse"]))) or {}), vjobs))

tally = {}
for cid, res in votes:
    tally.setdefault(cid, []).append(res.get("authentic"))

kept = []
for c in cands:
    v = tally.get(id(c), [])
    ok = v.count(True) >= 2
    print(f"  {'KEEP' if ok else 'drop'} [{c['poet']}] {c['verse'].split(chr(10))[0][:42]} {v}")
    if ok:
        kept.append(c)

# ---------- merge ----------
out = list(existing)
n = len(out)
for i, c in enumerate(kept):
    prefix = "h" if "حافظ" in c["poet"] else "x"
    c["id"] = f"{prefix}{n + i + 1:03d}"
    out.append(c)
json.dump(out, open(FAL, "w"), ensure_ascii=False, indent=1)
hafez = sum(1 for p in out if "حافظ" in p["poet"])
print(f"\nFAL POOL: {len(existing)} -> {len(out)} verses ({hafez} Hafez => "
      f"{hafez}-day repeat-free fal cycle), {len(kept)}/{len(cands)} candidates passed consensus")
