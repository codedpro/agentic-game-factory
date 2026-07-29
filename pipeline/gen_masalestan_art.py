#!/usr/bin/env python3
"""AI art for مثلستان via the 1xai OpenAI-compatible image endpoint.

Produces:
  assets/art/hero_bg.png           menu backdrop (portrait)
  assets/art/mascot.png            «شکرک» the parrot, background removed
  assets/art/mascot_cheer.png      cheering variant, background removed
  icon_ai.png                      1024 flat app icon (no text — L8)

Persian text is NEVER asked of the image model (L8); icons stay text-free.
"""
import base64, json, os, sys, time, urllib.request
from PIL import Image, ImageDraw

KEY = os.environ["IMAGE_API_KEY"]
URL = "https://1xai.ir/v1/images/generations"
GAME = "/home/claude/godot/games/masalestan"

STYLE = ("Persian miniature painting style, intricate ornamental detail, "
         "rich lapis blue and gold and turquoise palette, flat decorative shapes, "
         "no text, no letters, no calligraphy words")

JOBS = {
    "hero_bg": {
        "size": "1024x1536",
        "prompt": f"A serene Persian garden courtyard at dusk seen from above the rooftops, "
                  f"arched ivan doorway, cypress trees, unrolled blank paper scrolls on a carpet, "
                  f"floating glowing lanterns, {STYLE}, muted dark tones suitable as a "
                  f"mobile game menu background with UI drawn on top",
    },
    "mascot": {
        "size": "1024x1024",
        "prompt": "Die-cut sticker of a single cute cartoon green parrot with a golden "
                  "chest, wearing a tiny ornate blue Persian vest, holding a small rolled "
                  "paper scroll, full body centered, facing viewer, flat vector style with "
                  "Persian ornamental patterns on the vest only, "
                  "plain pure white background with NOTHING else — no border, no frame, "
                  "no background pattern, no shadow, no text",
        "cutout": True,
    },
    "mascot_cheer": {
        "size": "1024x1024",
        "prompt": "Die-cut sticker of a single cute cartoon green parrot with a golden "
                  "chest, wearing a tiny ornate blue Persian vest, wings spread wide "
                  "celebrating joyfully, happy open beak, full body centered, flat vector "
                  "style with Persian ornamental patterns on the vest only, "
                  "plain pure white background with NOTHING else — no border, no frame, "
                  "no background pattern, no shadow, no text",
        "cutout": True,
    },
    "icon_ai": {
        "size": "1024x1024",
        "prompt": f"Flat mobile game app icon: an open golden paper scroll with three blank "
                  f"square letter tiles resting on it and a small cute green parrot perched on "
                  f"top edge, bold simple shapes readable at small size, {STYLE}, "
                  f"deep indigo background filling the whole square, no border, no rounded corners",
    },
}


def gen(prompt, size, retries=4):
    body = json.dumps({"model": "gpt-image-1", "prompt": prompt, "size": size,
                       "n": 1}).encode()
    err = None
    for a in range(retries):
        try:
            req = urllib.request.Request(URL, data=body, headers={
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
            print(f"  attempt {a+1} failed: {str(err)[:100]}", flush=True)
            time.sleep(10 * (a + 1))
    raise RuntimeError(f"image generation failed: {err}")


def cutout(im: Image.Image, tol=34) -> Image.Image:
    """Remove the background by flood fill from every edge pixel, matched against the
    dominant EDGE colour (models often paint cream rather than pure white)."""
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()
    from collections import Counter, deque
    edge = Counter()
    for x in range(0, w, 4):
        edge[px[x, 0][:3]] += 1
        edge[px[x, h - 1][:3]] += 1
    for y in range(0, h, 4):
        edge[px[0, y][:3]] += 1
        edge[px[w - 1, y][:3]] += 1
    bg = edge.most_common(1)[0][0]
    seen = bytearray(w * h)
    q = deque()
    for x in range(w):
        q.append((x, 0)); q.append((x, h - 1))
    for y in range(h):
        q.append((0, y)); q.append((w - 1, y))
    while q:
        x, y = q.popleft()
        if x < 0 or y < 0 or x >= w or y >= h or seen[y * w + x]:
            continue
        seen[y * w + x] = 1
        r, g, b, a = px[x, y]
        if abs(r - bg[0]) <= tol and abs(g - bg[1]) <= tol and abs(b - bg[2]) <= tol:
            px[x, y] = (255, 255, 255, 0)
            q.extend(((x+1, y), (x-1, y), (x, y+1), (x, y-1)))
    return im


def main():
    only = sys.argv[1:]
    os.makedirs(f"{GAME}/assets/art", exist_ok=True)
    for name, job in JOBS.items():
        if only and name not in only:
            continue
        out = f"{GAME}/assets/art/{name}.png" if name != "icon_ai" else f"{GAME}/icon_ai.png"
        print(f"generating {name} …", flush=True)
        raw = gen(job["prompt"], job["size"])
        tmp = out + ".raw.png"
        open(tmp, "wb").write(raw)
        im = Image.open(tmp)
        if job.get("cutout"):
            im = cutout(im)
            bbox = im.getbbox()
            if bbox:
                im = im.crop(bbox)
        im.save(out)
        os.remove(tmp)
        print(f"  wrote {out} {im.size}", flush=True)


if __name__ == "__main__":
    main()
