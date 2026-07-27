#!/usr/bin/env python3
"""Store-screenshot composer for «بریز و بساز».

Renders the SAME layout constants/colors/fonts as ui_kit.gd at the game's logical
720x1280 viewport, using real board states dumped by tools/dump_states.gd, then
upscales to 1080x1920 and adds a Persian marketing caption band.
PIL has libraqm here, so Persian shaping/bidi is handled natively (direction="rtl").
"""
import json, os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

GAME = "/home/claude/godot/games/mergedrop"
OUT = "/home/claude/godot/releases/mergedrop/screenshots"
STATES = json.load(open("/home/claude/godot/reports/board_states.json"))
POEMS = json.load(open(f"{GAME}/assets/fal/fal.json"))
os.makedirs(OUT, exist_ok=True)

W, H = 720, 1280           # game logical viewport
SS = 2                      # supersample factor for crisp edges
FINAL = (1080, 1920)
F_REG = f"{GAME}/assets/fonts/Vazirmatn-Regular.ttf"
F_BOLD = f"{GAME}/assets/fonts/Vazirmatn-Bold.ttf"
F_EMOJI = f"{GAME}/assets/fonts/NotoEmoji-Regular.ttf"
FA_DIGITS = "۰۱۲۳۴۵۶۷۸۹"

def _jalali(gy, gm, gd):
    g_d_m = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334]
    if gy > 1600:
        jy = 979; gy -= 1600
    else:
        jy = 0; gy -= 621
    gy2 = gy + 1 if gm > 2 else gy
    days = (365 * gy) + (gy2 + 3) // 4 - (gy2 + 99) // 100 + (gy2 + 399) // 400 - 80 + gd + g_d_m[gm - 1]
    jy += 33 * (days // 12053); days %= 12053
    jy += 4 * (days // 1461); days %= 1461
    if days > 365:
        jy += (days - 1) // 365; days = (days - 1) % 365
    if days < 186:
        jm, jd = 1 + days // 31, 1 + days % 31
    else:
        jm, jd = 7 + (days - 186) // 30, 1 + (days - 186) % 30
    return jy, jm, jd

J_MONTHS = ["فروردین","اردیبهشت","خرداد","تیر","مرداد","شهریور","مهر","آبان","آذر","دی","بهمن","اسفند"]

THEME = {  # mirrors ui_kit.gd "classic"
    "bg": "#1c202e", "panel": "#272c3d", "accent": "#4f8cf0",
    "tiles": {2: "#4f8cf0", 4: "#f0964f", 8: "#ef5d7a", 16: "#9b59d0", 32: "#4fc06a",
              64: "#35b5b0", 128: "#d4a017", 256: "#d84fd0", 512: "#e2633a",
              1024: "#30a8d8", 2048: "#f2c230"},
}
HUGE, STONE_C, MUTED, GOLD = "#47506a", "#3a3f4d", "#8b93b0", "#f2c230"


# ---------- helpers ----------
def hx(c):
    c = c.lstrip("#")
    return tuple(int(c[i:i+2], 16) for i in (0, 2, 4))

def lighten(c, a):   # Godot Color.lightened
    r, g, b = hx(c) if isinstance(c, str) else c
    return tuple(int(v + (255 - v) * a) for v in (r, g, b))

def darken(c, a):    # Godot Color.darkened
    r, g, b = hx(c) if isinstance(c, str) else c
    return tuple(int(v * (1 - a)) for v in (r, g, b))

def digits(n):
    return "".join(FA_DIGITS[int(ch)] if ch.isdigit() else ch for ch in str(n))

_fcache = {}
def font(path, size):
    key = (path, int(size * SS))
    if key not in _fcache:
        _fcache[key] = ImageFont.truetype(path, int(size * SS))
    return _fcache[key]

def S(v):
    return v * SS

def _cmap(path):
    from fontTools.ttLib import TTFont
    if path not in _cmap_cache:
        f = TTFont(path, fontNumber=0)
        cps = set()
        for t in f["cmap"].tables:
            cps |= set(t.cmap.keys())
        _cmap_cache[path] = cps
    return _cmap_cache[path]
_cmap_cache = {}

def _runs(txt, main_path):
    """Split into (text, path, is_emoji) runs so glyphs missing from Vazirmatn
    fall back to Noto Emoji — mirroring the font fallback ui_kit.gd installs."""
    main = _cmap(main_path)
    out = []
    for ch in txt:
        emoji = ord(ch) not in main and ord(ch) in _cmap(F_EMOJI)
        if out and out[-1][2] == emoji:
            out[-1][0] += ch
        else:
            out.append([ch, F_EMOJI if emoji else main_path, emoji])
    return out

def _run_len(d, run, path, emoji, size):
    return d.textlength(run, font=font(path, size),
                        direction="ltr" if emoji else "rtl",
                        language=None if emoji else "fa")

def text_at(d, xy, txt, size, bold=True, fill="white", anchor="mm",
            stroke=0, stroke_fill=None, path=None):
    main = path or (F_BOLD if bold else F_REG)
    runs = _runs(txt, main)
    if len(runs) == 1 and not runs[0][2]:
        d.text((S(xy[0]), S(xy[1])), txt, font=font(main, size), fill=fill, anchor=anchor,
               direction="rtl", language="fa",
               stroke_width=int(S(stroke)), stroke_fill=stroke_fill)
        return
    # mixed emoji/Persian: lay runs out right-to-left (first logical run sits rightmost)
    widths = [_run_len(d, r, p, e, size) for r, p, e in runs]
    total = sum(widths)
    x = S(xy[0]) + (total / 2 if anchor[0] == "m" else (total if anchor[0] == "r" else 0))
    for (r, p, e), w in zip(runs, widths):
        d.text((x, S(xy[1])), r, font=font(p, size), fill=fill, anchor="r" + anchor[1],
               direction="ltr" if e else "rtl", language=None if e else "fa",
               stroke_width=int(S(stroke)), stroke_fill=stroke_fill)
        x -= w

def centered(d, box, txt, size, bold=True, fill="white", **kw):
    x, y, w, h = box
    text_at(d, (x + w / 2, y + h / 2), txt, size, bold, fill, "mm", **kw)

def rrect(d, box, radius, fill=None, outline=None, width=0):
    x, y, w, h = box
    d.rounded_rectangle([S(x), S(y), S(x + w), S(y + h)], radius=S(radius),
                        fill=fill, outline=outline, width=int(S(width)) if width else 0)

def wrap(txt, size, max_w, bold=True, path=None):
    f = font(path or (F_BOLD if bold else F_REG), size)
    probe = ImageDraw.Draw(Image.new("RGB", (10, 10)))
    lines, cur = [], ""
    for word in txt.split(" "):
        trial = (cur + " " + word).strip()
        if probe.textlength(trial, font=f, direction="rtl", language="fa") <= S(max_w):
            cur = trial
        else:
            if cur:
                lines.append(cur)
            cur = word
    if cur:
        lines.append(cur)
    return lines


# ---------- game widgets ----------
def metrics():
    gap = 8.0
    top_h = min(max(H * 0.155, 140), 215)
    bottom_h = min(max(H * 0.16, 150), 225)
    tile = float(int(min((W - 32 - gap * 4) / 5.0, (H - top_h - bottom_h - gap * 6) / 7.0)))
    bw = 5 * tile + 4 * gap
    return {"tile": tile, "gap": gap, "x0": (W - bw) / 2.0, "top": top_h,
            "w": bw, "h": 7 * tile + 6 * gap, "top_h": top_h, "bottom_h": bottom_h}

M = metrics()

def cell_pos(c, r):
    return (M["x0"] + c * (M["tile"] + M["gap"]),
            M["top"] + (6 - r) * (M["tile"] + M["gap"]))

def draw_tile(img, d, pos, value, size):
    x, y = pos
    stone = value == -1
    col = STONE_C if stone else THEME["tiles"].get(value, HUGE)
    if value >= 128 and not stone:     # glow
        glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
        gd = ImageDraw.Draw(glow)
        pad = size * 0.1
        gd.rounded_rectangle([S(x - pad), S(y - pad), S(x + size + pad), S(y + size + pad)],
                             radius=S(size * 0.145), fill=hx(col) + (150,))
        img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(S(size * 0.09))))
    rrect(d, (x, y, size, size), size * 0.145, fill=hx(col),
          outline=darken(col, 0.2) if stone else lighten(col, 0.22),
          width=max(2, int(size * 0.025)))
    if stone:
        text_at(d, (x + size / 2, y + size / 2), "✖", size * 0.4, fill=hx("#6b7183"),
                path=F_EMOJI)
    else:
        n = len(str(value))
        fs = 0.47 if n <= 2 else (0.36 if n == 3 else 0.28)
        text_at(d, (x + size / 2, y + size / 2), digits(value), size * fs,
                stroke=max(2, int(size * 0.03)) / SS, stroke_fill=darken(col, 0.45))

def draw_button(d, pos, txt, size, bg="#3a4160", minsize=None, fill="white"):
    f = font(F_BOLD, size)
    probe = ImageDraw.Draw(Image.new("RGB", (10, 10)))
    tw = probe.textlength(txt, font=f, direction="rtl", language="fa") / SS
    w = max(tw + 48, minsize[0] if minsize else 0)
    h = max(size * 1.35 + 20, minsize[1] if minsize else 0)
    rrect(d, (pos[0], pos[1], w, h), 16, fill=hx(bg), outline=lighten(bg, 0.18), width=2)
    centered(d, (pos[0], pos[1], w, h), txt, size, True, fill)
    return (w, h)

def bg_blobs(img, seedvals):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    for (bx, by, bs) in seedvals:
        ld.ellipse([S(bx), S(by), S(bx + bs), S(by + bs)], fill=hx(THEME["accent"]) + (16,))
    img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(S(40))))


# ---------- screens ----------
def render_board(state):
    img = Image.new("RGBA", (W * SS, H * SS), hx(THEME["bg"]) + (255,))
    bg_blobs(img, [(-60, 120, 320), (420, 700, 380), (80, 950, 300)])
    d = ImageDraw.Draw(img)
    daily = state["mode"] == "daily"

    centered(d, (W / 2 - 150, M["top_h"] * 0.08, 300, 30),
             "چالش روزانه" if daily else "امتیاز", 26, False, hx(MUTED))
    centered(d, (W / 2 - 150, M["top_h"] * 0.24, 300, M["top_h"] * 0.4),
             digits(state["score"]), 57)
    centered(d, (16, M["top_h"] * 0.08, 130, 26), "رکورد", 21, False, hx(MUTED))
    centered(d, (16, M["top_h"] * 0.3, 130, 36), digits(max(state["score"], 8420)), 33)
    centered(d, (W - 190, M["top_h"] * 0.08, 150, 34),
             ("حرکت: " + digits(state["moves_left"])) if daily else ("مرحله " + digits(state["level"])),
             28, True, hx(THEME["accent"]))
    draw_button(d, (W - 84, M["top_h"] * 0.4), "↩", 24)
    if not daily:
        centered(d, (W / 2 - 300, M["top_h"] * 0.72, 600, 30),
                 "هدف: ساخت کاشی " + digits(512), 24, False, hx(GOLD))

    rrect(d, (M["x0"] - 12, M["top"] - 12, M["w"] + 24, M["h"] + 24), 22, fill=hx(THEME["panel"]))
    # danger frame — same rule as game_screen._update_danger(): a tile in row ROWS-2
    if any(state["grid"][c][5] != 0 for c in range(5)):
        rrect(d, (M["x0"] - 12, M["top"] - 12, M["w"] + 24, M["h"] + 24), 22,
              outline=hx("#e0455a"), width=3)
    for c in range(5):
        for r in range(7):
            v = state["grid"][c][r]
            if v != 0:
                draw_tile(img, d, cell_pos(c, r), v, M["tile"])

    fy = M["top"] + M["h"] + 18
    centered(d, (W / 2 - 80, fy, 160, 26), "بعدی", 21, False, hx(MUTED))
    draw_tile(img, d, (W / 2 - M["tile"] * 0.36, M["top"] + M["h"] + 44),
              state["next"], M["tile"] * 0.72)
    if not daily:
        draw_button(d, (16, fy + 6), "⏪ برگرد (۳)", 24)
    return img


def _icon(img, name, x, y, size, color):
    ic = Image.open(f"{GAME}/assets/icons/{name}.png").convert("RGBA").resize(
        (int(size * SS), int(size * SS)), Image.LANCZOS)
    tint = Image.new("RGBA", ic.size, tuple(color) + (255,))
    tint.putalpha(ic.getchannel("A"))
    img.alpha_composite(tint, (int(x * SS), int(y * SS)))


def _rr(img, box, rad, fill=None, outline=None, width=0):
    x, y, w, h = box
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).rounded_rectangle(
        [x * SS, y * SS, (x + w) * SS, (y + h) * SS], radius=rad * SS,
        fill=fill, outline=outline, width=int(width * SS))
    img.alpha_composite(layer)


def _fit(txt, max_w, start, min_size=11):
    probe = ImageDraw.Draw(Image.new("RGB", (4, 4)))
    s = start
    while s > min_size and probe.textlength(
            txt, font=font(F_BOLD, s), direction="rtl", language="fa") > max_w * SS:
        s -= 1
    return s


def _title(img, d, name, txt, size, box, color=(255, 255, 255)):
    """Mirrors UI.title(): text plus a real icon on the trailing side, centred as a group."""
    x, y, w, h = box
    probe = ImageDraw.Draw(Image.new("RGB", (4, 4)))
    tw = probe.textlength(txt, font=font(F_BOLD, size), direction="rtl",
                          language="fa") / SS
    ic = size * 1.1
    gap = size * 0.4
    group = min(tw + gap + ic, w)
    left = x + (w - group) / 2
    text_at(d, (left + group - ic - gap, y + h / 2), txt, size, True, color, "rm")
    _icon(img, name, left + group - ic, y + (h - ic) / 2, ic, color)


def _icon_btn(img, d, x, y, w, h, name, label, accent, bg="#232a3d"):
    """Mirrors UI.icon_button(): dark chip, bright icon, auto-fitted label."""
    _rr(img, (x, y, w, h), min(h * 0.32, 20), fill=hx(bg) + (255,),
        outline=lighten(bg, 0.14) + (255,), width=2)
    pad = h * 0.16
    chip = h - pad * 2
    _rr(img, (x + w - chip - pad, y + pad, chip, chip), chip * 0.3, fill=(13, 18, 31, 140))
    _icon(img, name, x + w - chip - pad + chip * 0.19, y + pad + chip * 0.19, chip * 0.62, accent)
    tw = w - (chip + pad * 2.4) - pad
    text_at(d, (x + pad + tw / 2, y + h / 2), label, _fit(label, tw, int(h * 0.34)))


def render_menu():
    img = Image.open(f"{GAME}/assets/art/hero_bg.png").convert("RGBA").resize(
        (W * SS, H * SS), Image.LANCZOS)
    img.alpha_composite(Image.new("RGBA", img.size, hx(THEME["bg"]) + (140,)))
    d = ImageDraw.Draw(img)

    fs = 25
    h = fs * 2.2
    w = min(W * 0.27, 165)
    for (nm, val, col, x, cw) in [("coin", digits(1240), hx("#f2c230"), 14, w),
                                  ("streak", digits(7), hx("#ff9d5c"), 14 + w + 8, w * 0.76),
                                  ("rank", digits(12), hx("#7fd8ff"), W - w - 14, w)]:
        _rr(img, (x, 16, cw, h), 12, fill=hx("#161b28") + (235,))
        _icon(img, nm, x + cw - h * 0.78, 16 + h * 0.22, h * 0.56, col)
        text_at(d, (x + 6 + (cw - h * 0.9) / 2, 16 + h / 2), val, fs)
    y = 16 + h + 8

    text_at(d, (W / 2, y + 46), "بریز و بساز", 70, True, "white", stroke=2,
            stroke_fill=(0, 0, 0, 200))
    y += 92
    text_at(d, (W / 2, y + fs * 0.85), "رکورد: " + digits(8420), 28, True, hx(GOLD))
    y += fs * 2.0

    owl_h = 200
    owl_w = owl_h * 0.95
    owl = Image.open(f"{GAME}/assets/art/mascot.png").convert("RGBA")
    owl.thumbnail((int(owl_w * SS), int(owl_h * SS)), Image.LANCZOS)
    img.alpha_composite(owl, (int((W - owl_w - 10) * SS), int(y * SS)))
    bw = W - owl_w - 36
    _rr(img, (14, y + owl_h * 0.14, bw, owl_h * 0.66), 16, fill=hx("#2b3350") + (255,))
    text_at(d, (14 + bw / 2, y + owl_h * 0.14 + owl_h * 0.33),
            "۷ روز پیاپی! نذار امشب بشکنه", fs, False)
    y += owl_h + 8

    mp_w = min(W * 0.92, 552)
    mfs = 22
    head = mfs * 2.6
    row_h = mfs * 2.5
    _rr(img, (W / 2 - mp_w / 2, y, mp_w, head + row_h * 3 + mfs * 0.7), 18,
        fill=hx("#1a2030") + (250,))
    px = W / 2 - mp_w / 2
    hb_w = mp_w * 0.38
    _icon_btn(img, d, px + mfs * 0.7, y + mfs * 0.45, hb_w, mfs * 1.9,
              "history", "روزهای گذشته", hx("#7fd8ff"), "#232c42")
    _icon(img, "tasks", px + mp_w - mfs * 2.0, y + mfs * 0.6, mfs * 1.4, hx(THEME["accent"]))
    title_x = mfs * 0.7 + hb_w + mfs * 0.6
    tw = mp_w - title_x - mfs * 2.4
    text_at(d, (px + title_x + tw / 2, y + mfs * 0.5 + mfs * 0.95),
            "مأموریت‌های امروز", _fit("مأموریت‌های امروز", tw, mfs + 2))
    my = y + head
    for (t, prog, tot, pct, done, ic) in [
            ("در یک بازی ۲۵۰۰ امتیاز بگیر", 2500, 2500, 1.0, True, "records"),
            ("۵ سنگ بشکن", 3, 5, 0.6, False, "streak"),
            ("زنجیره ×۳ بساز", 1, 3, 0.33, False, "rank")]:
        tw2 = mp_w - mfs * 1.6
        th = row_h - mfs * 0.55
        _rr(img, (px + mfs * 0.8, my, tw2, th), 10, fill=hx("#0f131e") + (255,))
        if pct > 0:
            _rr(img, (px + mfs * 0.8, my, tw2 * pct, th), 10,
                fill=(hx("#2e7d5b") if done else hx(THEME["accent"])) + (255,))
        _icon(img, ic, px + mfs * 0.8 + tw2 - th * 0.82, my + th * 0.17, th * 0.66,
              hx("#9fe8c4") if done else (255, 255, 255))
        lab = "%s  (%s/%s)" % (t, digits(prog), digits(tot))
        text_at(d, (px + mfs * 0.8 + 10 + (tw2 - th * 1.25) / 2, my + th / 2), lab,
                _fit(lab, tw2 - th * 1.3, mfs), True, "white", stroke=1,
                stroke_fill=(0, 0, 0, 190))
        my += row_h
    y += head + row_h * 3 + mfs * 0.7 + 22

    bw2 = min(W * 0.7, 380)
    avail = max(220, H - y - 24)
    bh = min(max(avail * 0.2, 54), 96)
    _icon_btn(img, d, W / 2 - bw2 / 2, y, bw2, bh, "play", "بازی", (255, 255, 255),
              THEME["accent"])
    gw = (bw2 - 12) / 2
    gh = min(max((avail - bh - 24) / 3 - 10, 46), 84)
    yy = y + bh + 14
    for i, (nm, lb, ac) in enumerate([
            ("daily", "چالش روزانه", hx("#6fb3ff")), ("board", "جدول جهانی", hx("#7fd8ff")),
            ("fal", "فال و گنجینه", hx("#c39bf5")), ("shop", "شخصی‌سازی", hx("#ffc76f")),
            ("records", "رکوردها", hx("#9fe8c4")), ("settings", "تنظیمات", hx("#aab4cc"))]):
        _icon_btn(img, d, W / 2 - bw2 / 2 + (i % 2) * (gw + 12),
                  yy + (i // 2) * (gh + 10), gw, gh, nm, lb, ac)
    return img


def render_shop():
    """The «سکه» tab, mirroring shop_screen._build_coins() on its fs grid.

    Kept in step with the GDScript by hand; the geometry rules it draws (title clear of the
    tag badge, badge row below the amount, nothing past the card height) are the same ones
    tests/test_shop.gd asserts against the real scene.
    """
    img = Image.new("RGBA", (W * SS, H * SS), hx(THEME["bg"]) + (255,))
    bg_blobs(img, [(-60, 140, 340), (400, 820, 380)])
    d = ImageDraw.Draw(img)
    fs = max(15, min(int(H * 0.02), 25))
    cx = W / 2

    _title(img, d, "shop", "فروشگاه", 40, (cx - 300, H * 0.035, 600, 54))
    _title(img, d, "coin", digits(12450), fs + 4, (cx - 200, H * 0.035 + 56, 400, fs * 2),
           hx(GOLD))

    tabs = [("وسایل", False), ("ظاهر", False), ("سکه", True)]
    tw = min((W - 40) / 3 - 8, 190)
    tx = cx - (3 * (tw + 8) - 8) / 2
    ty = H * 0.035 + 56 + fs * 3.4
    for label, active in tabs:
        _rr(img, (tx, ty, tw, fs * 2.4), 12,
            fill=hx(THEME["accent"] if active else "#3a4160") + (255,))
        centered(d, (tx, ty, tw, fs * 2.4), label, fs - 1)
        tx += tw + 8

    w = W - 40
    y = ty + fs * 3.0
    packs = [
        ("بسته کوچک", 5000, 0, None),
        ("بسته متوسط", 15000, 10, None),
        ("بسته بزرگ", 40000, 25, ("پرفروش‌ترین", GOLD)),
        ("بسته ویژه", 100000, 40, ("بهترین ارزش", "#ffc76f")),
    ]
    prices = ["۱۹٬۰۰۰ تومان", "۴۹٬۰۰۰ تومان", "۹۹٬۰۰۰ تومان", "۱۹۹٬۰۰۰ تومان"]
    ch = fs * 6.4
    btn_w = min(w * 0.42, fs * 8.0)
    for (name, coins, bonus, tag), price in zip(packs, prices):
        if y + ch > H - fs * 3.4:
            break
        accent = hx(tag[1]) if tag else hx(GOLD)
        base = "#2b3350" if tag else "#232a3d"
        _rr(img, (20, y, w, ch), 16, fill=hx(base) + (255,),
            outline=lighten(base, 0.18) + (255,), width=2)
        if tag:
            _rr(img, (20 + fs * 0.8, y + fs * 0.6, btn_w, fs * 1.5), 10, fill=accent + (255,))
            centered(d, (20 + fs * 0.8, y + fs * 0.6, btn_w, fs * 1.5), tag[0], fs - 4,
                     True, hx("#161b28"))
        btn_y = y + (fs * 3.0 if tag else (ch - fs * 2.4) / 2)
        _icon_btn(img, d, 20 + fs * 0.8, btn_y, btn_w, fs * 2.4, "cart", price,
                  (255, 255, 255), "#2e7d5b")
        ic = fs * 2.2
        _icon(img, "coin", 20 + w - fs * 0.8 - ic, y + fs * 1.0, ic, accent)
        col_x = fs * 0.8 + btn_w + fs * 0.8
        col_w = w - col_x - fs * 0.8 - ic - fs * 0.4
        text_at(d, (20 + col_x + col_w, y + fs * 1.4), name, _fit(name, col_w, fs),
                True, "white", "rm")
        amt = "%s سکه" % digits(coins)
        text_at(d, (20 + col_x + col_w, y + fs * 3.4), amt, _fit(amt, col_w, fs + 4),
                True, accent, "rm")
        if bonus:
            bw = fs * 6.0
            _rr(img, (20 + w - fs * 0.8 - bw, y + fs * 4.6, bw, fs * 1.4), 10,
                fill=hx("#2e7d5b") + (255,))
            centered(d, (20 + w - fs * 0.8 - bw, y + fs * 4.6, bw, fs * 1.4),
                     "%s٪ بیشتر" % digits(bonus), fs - 4)
        y += ch + 10
    return img


def render_account():
    """The sign-up form, mirroring account_screen._build_form()."""
    img = Image.new("RGBA", (W * SS, H * SS), hx(THEME["bg"]) + (255,))
    bg_blobs(img, [(-50, 160, 340), (410, 830, 370)])
    d = ImageDraw.Draw(img)
    fs = max(15, min(int(H * 0.02), 25))
    cx = W / 2
    _title(img, d, "heart", "حساب کاربری", 40, (cx - 300, H * 0.04, 600, 54))

    w = W - 40
    y = H * 0.04 + 64

    def note(text, color, bg, h_mult=4.0):
        nonlocal y
        h = fs * h_mult
        _rr(img, (20, y, w, h), 14, fill=hx(bg) + (255,))
        lines = wrap(text, fs - 3, w - 36, bold=False)
        ly = y + (h - len(lines) * (fs - 3) * 1.5) / 2 + (fs - 3) * 0.75
        for ln in lines:
            text_at(d, (20 + w - 18, ly), ln, fs - 3, False, hx(color), "rm")
            ly += (fs - 3) * 1.5
        y += h + 12

    def field(label, hint):
        nonlocal y
        h = fs * 5.4
        _rr(img, (20, y, w, h), 14, fill=hx("#232a3d") + (255,))
        text_at(d, (20 + w - 14, y + fs * 1.25), label, fs - 2, True, hx(MUTED), "rm")
        _rr(img, (36, y + fs * 2.3, w - 32, fs * 2.6), 8, fill=hx("#151a28") + (255,),
            outline=hx("#3a4160") + (255,), width=1)
        text_at(d, (44, y + fs * 3.6), hint, fs, False, hx("#6d7794"), "lm",
                path=F_REG)
        y += h + 12

    note("حساب فقط برای خرید سکه لازم است. بازی، رکوردها و فال بدون حساب هم کامل کار می‌کنند.",
         "#9fe8c4", "#1e2a24")
    field("ایمیل", "you@example.com")
    field("رمز عبور", "••••••••")
    _icon_btn(img, d, 20, y, w, fs * 2.8, "heart", "ساخت حساب", (255, 255, 255), "#2e7d5b")
    y += fs * 2.8 + 12
    _rr(img, (20, y, w, fs * 2.4), 12, fill=hx("#3a4160") + (255,))
    centered(d, (20, y, w, fs * 2.4), "قبلاً حساب ساخته‌ام", fs - 3)
    y += fs * 2.4 + 12
    note("هیچ ایمیلی برای تو فرستاده نمی‌شود و ایمیلت تأیید نمی‌شود. رمزت را جایی امن نگه دار؛ "
         "امکان بازیابی رمز وجود ندارد.", "#ffc76f", "#2a2230", 4.6)
    return img


def render_fal(poem):
    img = Image.new("RGBA", (W * SS, H * SS), (10, 8, 23, 255))
    bg_blobs(img, [(-40, 200, 360), (380, 800, 380)])
    d = ImageDraw.Draw(img)
    fs = 29
    cw, ch = 560, 620
    cx, cy = (W - cw) / 2, (H - ch) / 2 - 20
    rrect(d, (cx, cy, cw, ch), 24, fill=hx("#241d38"))
    rrect(d, (cx, cy, cw, ch), 24, outline=hx(GOLD), width=3)
    rrect(d, (cx + 8, cy + 8, cw - 16, ch - 16), 16, outline=lighten("#241d38", 0.35), width=2)
    for ox, oy in [(26, 26), (cw - 26, 26), (26, ch - 26), (cw - 26, ch - 26)]:
        text_at(d, (cx + ox, cy + oy), "۞", fs * 1.1, fill=hx(GOLD))

    centered(d, (cx, cy + ch * 0.07, cw, fs * 2), "✨ فال حافظ تو", fs + 4, True, hx(GOLD))
    centered(d, (cx, cy + ch * 0.07 + fs * 1.9, cw, fs * 1.3), JALALI_TODAY, fs - 5, False,
             (200, 168, 60))
    vy = cy + ch * 0.235
    for line in poem["verse"].split("\n"):
        for wl in wrap(line, fs + 2, cw - 60):
            centered(d, (cx + 24, vy, cw - 48, fs * 1.7), wl, fs + 2)
            vy += fs * 1.7
    centered(d, (cx, cy + ch * 0.5, cw, fs * 1.6), "— " + poem["poet"], fs - 2, False, hx(MUTED))
    centered(d, (cx, cy + ch * 0.59, cw, fs * 1.6), "تعبیر", fs - 1, True, hx(THEME["accent"]))
    iy = cy + ch * 0.66
    for wl in wrap(poem["interp"], fs - 1, cw - 60, bold=False):
        centered(d, (cx + 24, iy, cw - 48, fs * 1.5), wl, fs - 1, False)
        iy += fs * 1.5
    by = cy + ch + 16
    draw_button(d, ((W - 340) / 2, by), "📤 کپی و ارسال فال", fs - 3, "#3a6a48", (340, fs * 2.4))
    draw_button(d, ((W - 180) / 2, by + fs * 2.4 + 12), "✖ بازگشت", fs - 3, "#3a4160",
                (180, fs * 2.4))
    return img


# ---------- compose store shot ----------
def compose(game_img, caption, sub=None, fname="shot.png"):
    canvas = Image.new("RGB", FINAL, hx(THEME["bg"]))
    d = ImageDraw.Draw(canvas)
    top = Image.new("RGBA", (FINAL[0], 460), hx(THEME["accent"]) + (26,))
    canvas.paste(Image.alpha_composite(
        canvas.crop((0, 0, FINAL[0], 460)).convert("RGBA"), top).convert("RGB"), (0, 0))

    cap_f = ImageFont.truetype(F_BOLD, 62)
    sub_f = ImageFont.truetype(F_REG, 38)
    lines, cur = [], ""
    for word in caption.split(" "):
        t = (cur + " " + word).strip()
        if d.textlength(t, font=cap_f, direction="rtl", language="fa") <= FINAL[0] - 120:
            cur = t
        else:
            lines.append(cur); cur = word
    lines.append(cur)
    y = 96 if len(lines) == 1 else 66
    for ln in lines:
        d.text((FINAL[0] / 2, y), ln, font=cap_f, fill="white", anchor="ma",
               direction="rtl", language="fa")
        y += 76
    if sub:
        d.text((FINAL[0] / 2, y + 8), sub, font=sub_f, fill=hx(GOLD), anchor="ma",
               direction="rtl", language="fa")

    gw = int(FINAL[0] * 0.90)
    gh = int(gw * H / W)
    game = game_img.convert("RGB").resize((gw, gh), Image.LANCZOS)
    mask = Image.new("L", (gw, gh), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, gw, gh], radius=34, fill=255)
    gx, gy = (FINAL[0] - gw) // 2, FINAL[1] - gh + 40
    shadow = Image.new("RGBA", FINAL, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        [gx - 6, gy - 10, gx + gw + 6, gy + gh], radius=40, fill=(0, 0, 0, 140))
    canvas.paste(Image.alpha_composite(canvas.convert("RGBA"),
                 shadow.filter(ImageFilter.GaussianBlur(18))).convert("RGB"), (0, 0))
    canvas.paste(game, (gx, gy), mask)
    path = f"{OUT}/{fname}"
    canvas.save(path, optimize=True)
    # Cafe Bazaar rejects screenshots over 1 MB. Quantise until it fits rather than
    # letting a submission fail on file size.
    colors = 256
    while os.path.getsize(path) > 1_000_000 and colors >= 32:
        canvas.convert("RGB").quantize(colors=colors, method=Image.MEDIANCUT)\
            .convert("RGB").save(path, optimize=True)
        colors //= 2
    size_kb = os.path.getsize(path) // 1024
    assert os.path.getsize(path) <= 1_000_000, f"{fname} is {size_kb} KB — over the 1 MB store cap"
    print(f"wrote {fname} ({size_kb} KB)")


import datetime
_t = datetime.date.today()
_j = _jalali(_t.year, _t.month, _t.day)
JALALI_TODAY = "%s %s %s" % (digits(_j[2]), J_MONTHS[_j[1]-1], digits(_j[0]))

hafez = next(p for p in POEMS if p["poet"] == "حافظ")
compose(render_fal(hafez), "هر روز یک فال حافظ واقعی",
        "تنها بازی‌ای که فال روزانه هدیه می‌دهد", "01_fal.png")
compose(render_board(STATES["early"]), "بنداز، ادغام کن، زنجیره بساز!",
        "یادگیری در چند ثانیه", "02_play.png")
compose(render_board(STATES["pressure"]), "هر مرحله سخت‌تر می‌شود",
        "ردیف‌های تازه و سنگ‌های سرسخت", "03_pressure.png")
compose(render_board(STATES["big"]), "زنجیره بزن، امتیازت را چند برابر کن",
        "تا کاشی ۲۰۴۸ و فراتر", "04_chain.png")
compose(render_board(STATES["daily"]), "چالش روزانه: ۶۰ حرکت",
        "یک چیدمان برای همه، هر روز", "05_daily.png")
compose(render_menu(), "مأموریت روزانه، سکه و شخصی‌سازی",
        "رکوردت را هر روز بشکن", "06_meta.png")
compose(render_shop(), "بسته‌های سکه، مستقیم از کافه‌بازار",
        "هر بسته بزرگ‌تر، ارزش بیشتر", "07_shop.png")
compose(render_account(), "حساب فقط برای خرید",
        "بازی و رکوردها بدون حساب کار می‌کنند", "08_account.png")


# ---------- Bazaar store assets ----------
def _hero_bg(size):
    img = Image.new("RGBA", size, hx(THEME["bg"]) + (255,))
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    ld.ellipse([-size[0] * 0.1, -size[1] * 0.5, size[0] * 0.5, size[1] * 0.9],
               fill=hx(THEME["accent"]) + (30,))
    ld.ellipse([size[0] * 0.55, size[1] * 0.2, size[0] * 1.1, size[1] * 1.6],
               fill=hx("#6b4f9e") + (34,))
    img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(size[1] // 8)))
    return img


def _hero_tiles(img, d, x, y, size, values):
    for i, v in enumerate(values):
        draw_tile(img, d, (x + i * (size + size * 0.12), y + (i % 2) * size * 0.12), v, size)


def make_header(path="header_720x288.png"):
    """تصویر سرصفحه — 720x288 (5:2), PNG, <=1MB."""
    global SS
    SS = 2
    W2, H2 = 720, 288
    img = _hero_bg((W2 * SS, H2 * SS))
    d = ImageDraw.Draw(img)
    text_at(d, (W2 * 0.62, H2 * 0.36), "بریز و بساز", 58, True, "white")
    text_at(d, (W2 * 0.62, H2 * 0.62), "هر روز یک فال حافظ واقعی", 27, False, hx(GOLD))
    _hero_tiles(img, d, W2 * 0.06, H2 * 0.26, 62, [2, 4, 8])
    img.convert("RGB").resize((W2, H2), Image.LANCZOS).save(f"{OUT}/{path}")
    print("wrote", path)


def make_promo(path="promo_1152x648.jpg"):
    """اسکرین‌شات پروموشن — 1152x648 (16:9), JPG, <=1MB."""
    global SS
    SS = 2
    W2, H2 = 1152, 648
    img = _hero_bg((W2 * SS, H2 * SS))
    d = ImageDraw.Draw(img)
    text_at(d, (W2 * 0.63, H2 * 0.30), "بریز و بساز", 78, True, "white")
    text_at(d, (W2 * 0.63, H2 * 0.47), "تنها بازی‌ای که هر روز", 34, False, hx(GOLD))
    text_at(d, (W2 * 0.63, H2 * 0.57), "یک فال حافظ به تو هدیه می‌دهد", 34, False, hx(GOLD))
    text_at(d, (W2 * 0.63, H2 * 0.74), "رایگان • بدون اینترنت • بدون تبلیغ", 26, False, hx(MUTED))
    _hero_tiles(img, d, W2 * 0.05, H2 * 0.30, 96, [2, 4, 8])
    text_at(d, (W2 * 0.20, H2 * 0.72), "۲۰۴۸", 54, True, hx(GOLD))
    img.convert("RGB").resize((W2, H2), Image.LANCZOS).save(f"{OUT}/{path}", quality=88)
    print("wrote", path)


make_header()
make_promo()
