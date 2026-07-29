#!/usr/bin/env python3
"""Build the مثلستان bonus-word dictionary: hand-curated common Persian words
(2–5 letters) ∪ every level target word. Hand words are pruned by a 2-model check
(a fake word accepted in-game embarrasses; a real word rejected merely annoys, so
we stay conservative and drop anything contested).

Output: games/masalestan/assets/masal/words_fa.json
"""
import json, os, re, sys, time, urllib.request
from concurrent.futures import ThreadPoolExecutor

KEY = os.environ.get("IMAGE_API_KEY", "")
URL = "https://1xai.ir/v1/chat/completions"
BASE = "/home/claude/godot/games/masalestan/assets/masal"
CHECKERS = ["gpt-4.1", "gemini-2.5-flash"]

HAND = """
آب آش بد بز پا تب تر تن جا جو خر خم در دم دو دل رخ رگ سر سگ شب شک صف غم فن قد
کف کم لب مه مو می نم نی یخ بو رو مس نو
آرد آهو ابر اسب اتو ادب اره باد بار باغ بام برف برگ بند بید پدر پسر پلو پول پیر
تاج تار تاس تخت ترش تلخ تند تیر تیز جام جان جگر چای چرب چشم چوب حرف خاک خال خام
خان خبر خرس خشک خون داغ درد درز دست دشت دود دور دیر دیو راه رنج رنگ روز ریگ زاغ
زبر زرد زهر سال سبد سبز سرد سفر سنگ سیب سیر شاخ شال شام شهر شیر صبح صدا طلا عسل
غاز فیل قند کاه کبک کوه کاج کار کاخ گاو گرد گرم گله گنج گوش لال لبو ماه مرغ مزد
مشک موش مهر میز نان نمک نرم نور هنر یار یاس ناز باز راز رود روده زانو دهان دندان
آسان آواز انار انبر بستر بلبل بهار پنیر پرده پلنگ تنور جارو جوجه چراغ حلوا خانه
خرما خروس خمیر خواب خیار دامن درخت دریا دفتر دنیا سایه ستون سرکه سفره سوزن شانه
قوری کاسه کباب کبود کتاب کلاغ کوزه گردو گلاب لانه مادر ماهی میوه نهال آینه ابرو
انگور باران بازار دیوار روباه زنبور صابون کبوتر برادر
گل بها ریش دام رام مار رمز مرز راست دار درس سرا سیم رسم اسم نما نام مان بنا نان
""".split()


def call(model, prompt, retries=3, timeout=180):
    body = json.dumps({"model": model, "temperature": 0.0,
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


def check(model, words):
    out = {}
    for i in range(0, len(words), 40):
        chunk = words[i:i + 40]
        prompt = ("برای هر واژهٔ زیر بگو آیا یک واژهٔ مستقل، رایج و درستِ فارسی است "
                  "(اسم، صفت، فعل ساده یا واژهٔ روزمره؛ نه حرف اضافه، نه پیشوند، نه واژهٔ ساختگی، "
                  "نه عامیانهٔ شکسته). فقط JSON خالص برگردان: "
                  '[{"w": "...", "ok": true}]\n\n' + " ".join(chunk))
        raw = call(model, prompt)
        m = re.search(r"\[.*\]", raw, re.S)
        if m:
            try:
                for r in json.loads(m.group(0)):
                    out[r["w"]] = bool(r.get("ok"))
            except Exception:
                pass
    return out


def main():
    levels = json.load(open(f"{BASE}/masal.json"))["levels"]
    targets = set()
    for l in levels:
        for r in l["rounds"]:
            targets.update(r["targets"])
    hand = sorted(set(HAND) - targets)
    print(f"{len(targets)} target words, {len(hand)} hand words to check", flush=True)

    if "--no-check" in sys.argv:
        kept = hand
    else:
        with ThreadPoolExecutor(max_workers=2) as pool:
            votes = list(pool.map(lambda m: check(m, hand), CHECKERS))
        kept, dropped = [], []
        for w in hand:
            oks = [v.get(w) for v in votes if w in v]
            (kept if oks and all(oks) else dropped).append(w)
        print(f"hand words kept {len(kept)}, dropped {len(dropped)}: {dropped}", flush=True)

    words = sorted(set(kept) | targets)
    json.dump({"count": len(words), "words": words},
              open(f"{BASE}/words_fa.json", "w"), ensure_ascii=False, indent=0)
    print(f"dictionary: {len(words)} words", flush=True)


if __name__ == "__main__":
    main()
