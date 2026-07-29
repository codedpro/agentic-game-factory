#!/usr/bin/env python3
"""Picture-guess levels: pick the ~20% most literally-depictable proverbs, generate a
funny literal illustration for each (no text — L8), save as small JPGs the game shows
above the letter slots.

Output: games/masalestan/assets/masal/img/<id>.jpg (512², ~50 KB each)
"""
import base64, json, os, re, sys, time, urllib.request

KEY = os.environ["IMAGE_API_KEY"]
CHAT = "https://1xai.ir/v1/chat/completions"
IMG = "https://1xai.ir/v1/images/generations"
BASE = "/home/claude/godot/games/masalestan/assets/masal"
OUT = f"{BASE}/img"
TARGET_FRACTION = 0.20

STYLE = ("flat vector illustration with a Persian miniature flavour, rich lapis blue "
         "and gold and turquoise palette, warm and funny, single clear scene, "
         "no people's faces in closeup, absolutely no text, no letters, no words")


def call_chat(prompt, retries=3):
    body = json.dumps({"model": "gpt-4.1", "temperature": 0.2,
                       "messages": [{"role": "user", "content": prompt}]}).encode()
    for a in range(retries):
        try:
            req = urllib.request.Request(CHAT, data=body, headers={
                "Authorization": f"Bearer {KEY}", "Content-Type": "application/json",
                "User-Agent": "curl/8.5.0"})
            with urllib.request.urlopen(req, timeout=240) as r:
                return json.load(r)["choices"][0]["message"]["content"]
        except Exception as e:
            print(f"  chat failed: {str(e)[:80]}", flush=True)
            time.sleep(5 * (a + 1))
    return ""


def gen_image(prompt, retries=3):
    body = json.dumps({"model": "gpt-image-1", "prompt": prompt,
                       "size": "1024x1024", "n": 1}).encode()
    err = None
    for a in range(retries):
        try:
            req = urllib.request.Request(IMG, data=body, headers={
                "Authorization": f"Bearer {KEY}", "Content-Type": "application/json",
                "User-Agent": "curl/8.5.0"})
            with urllib.request.urlopen(req, timeout=600) as r:
                data = json.load(r)["data"][0]
                if "b64_json" in data:
                    return base64.b64decode(data["b64_json"])
                with urllib.request.urlopen(urllib.request.Request(
                        data["url"], headers={"User-Agent": "curl/8.5.0"}), timeout=300) as ir:
                    return ir.read()
        except Exception as e:
            err = e
            time.sleep(10 * (a + 1))
    raise RuntimeError(f"image failed: {err}")


def pick_ids(levels, count):
    lines = "\n".join(f'{l["id"]}: {l["text"]}' for l in levels)
    prompt = f"""از فهرست ضرب‌المثل‌های زیر، {count} مورد را انتخاب کن که بهترین تصویرسازیِ تحت‌اللفظی و بامزه را دارند (صحنهٔ عینی و قابل کشیدن: حیوان، شیء، عمل مشخص). مثل‌های کاملاً انتزاعی را انتخاب نکن.
فقط JSON خالص: ["m001", ...]

{lines}"""
    raw = call_chat(prompt)
    m = re.search(r"\[.*\]", raw, re.S)
    ids = json.loads(m.group(0)) if m else []
    valid = {l["id"] for l in levels}
    return [i for i in ids if i in valid][:count]


def scene_prompt(level):
    prompt = f"""برای این ضرب‌المثل فارسی یک توصیف صحنهٔ یک‌خطی انگلیسی بنویس که آن را تحت‌اللفظی و بامزه نشان بدهد (بدون متن داخل تصویر):
«{level['text']}»
فقط همان یک خط انگلیسی را برگردان."""
    line = call_chat(prompt).strip().strip('"')
    return f"{line}. {STYLE}"


def main():
    from PIL import Image
    levels = json.load(open(f"{BASE}/masal.json"))["levels"]
    os.makedirs(OUT, exist_ok=True)
    have = {f[:-4] for f in os.listdir(OUT) if f.endswith(".jpg")}
    count = int(len(levels) * TARGET_FRACTION)
    ids = pick_ids(levels, count)
    print(f"picked {len(ids)} of {len(levels)} for pictures", flush=True)
    by_id = {l["id"]: l for l in levels}
    done = 0
    for lid in ids:
        if lid in have:
            done += 1
            continue
        lvl = by_id[lid]
        try:
            p = scene_prompt(lvl)
            raw = gen_image(p)
            tmp = f"{OUT}/{lid}.tmp"
            open(tmp, "wb").write(raw)
            im = Image.open(tmp).convert("RGB").resize((512, 512), Image.LANCZOS)
            im.save(f"{OUT}/{lid}.jpg", quality=82)
            os.remove(tmp)
            done += 1
            print(f"  [{done}/{len(ids)}] {lid} «{lvl['text'][:30]}»", flush=True)
        except Exception as e:
            print(f"  {lid} FAILED: {str(e)[:90]}", flush=True)
    total_kb = sum(os.path.getsize(f"{OUT}/{f}") for f in os.listdir(OUT)
                   if f.endswith(".jpg")) // 1024
    print(f"images: {done} generated, {total_kb} KB total", flush=True)


if __name__ == "__main__":
    main()
