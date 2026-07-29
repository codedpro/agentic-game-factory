#!/usr/bin/env python3
"""Store-screenshot composer for «مثلستان» — and the layout oracle (L23).

Renders the SAME layout constants/colours/fonts as ui_kit.gd + game_screen.gd at the
game's logical 720×1280 viewport, using real level data from masal.json, then
upscales to 1080×1920 and adds a Persian marketing caption band.
PIL has libraqm here, so Persian shaping/bidi is handled natively (direction="rtl").

Keep in sync with: UI.board_metrics(), game_screen._render_proverb/_render_wheel,
masal_screen and menu_screen proportions. A screenshot that looks wrong is a layout
bug in the game, not a drawing bug here.
"""
import json, math, os
from PIL import Image, ImageDraw, ImageFont

GAME = "/home/claude/godot/games/masalestan"
OUT = "/home/claude/godot/releases/masalestan/screenshots"
DATA = json.load(open(f"{GAME}/assets/masal/masal.json"))
LEVELS = {l["id"]: l for l in DATA["levels"]}
os.makedirs(OUT, exist_ok=True)

W, H = 720, 1280
SS = 2
FINAL = (1080, 1920)
F_REG = f"{GAME}/assets/fonts/Vazirmatn-Regular.ttf"
F_BOLD = f"{GAME}/assets/fonts/Vazirmatn-Bold.ttf"
FA_DIGITS = "۰۱۲۳۴۵۶۷۸۹"

# mirrors ui_kit.gd THEMES.classic
BG, PANEL, ACCENT = "#1c202e", "#272c3d", "#4f8cf0"
TILE_C, TILE_HOT, SLOT = "#3a4160", "#4f8cf0", "#222738"
MUTED, GOLD = "#8b93b0", "#f2c230"

STOP = {"که","از","به","را","و","در","با","بر","تا","هر","چه","اگر","ولی","اما","یا",
        "هم","نه","ای","است","بود","شد","می","نمی","خود","او","آن","این","ما","تو",
        "من","چون","کی","بی","پس","ز","بهر","وای","گر","چو","نیست","باش","باشی",
        "باشد","شود","کند","کنی","کرد","یک","دو","صد"}

_fc = {}
def font(path, size):
    key = (path, int(size * SS))
    if key not in _fc:
        _fc[key] = ImageFont.truetype(path, int(size * SS))
    return _fc[key]

def S(v):
    return int(v * SS)

def digits(n):
    return "".join(FA_DIGITS[int(c)] if c.isdigit() else c for c in str(n))

def lighten(hexc, a):
    r, g, b = (int(hexc[i:i+2], 16) for i in (1, 3, 5))
    return tuple(int(c + (255 - c) * a) for c in (r, g, b))

def rtl(d, xy, txt, f, fill, anchor="ra"):
    d.text(xy, txt, font=f, fill=fill, anchor=anchor, direction="rtl", language="fa")

def ctr(d, xy, txt, f, fill):
    d.text(xy, txt, font=f, fill=fill, anchor="mm", direction="rtl", language="fa")


# ---------- board_metrics() mirror ----------
def metrics():
    top_h = max(56, min(90, H * 0.085))
    wheel_d = min(W * 0.82, H * 0.36)
    wheel_cy = H - wheel_d / 2 - 18
    preview_h = max(44, min(64, H * 0.065))
    proverb_y = top_h + 10
    proverb_h = wheel_cy - wheel_d / 2 - preview_h - proverb_y - 24
    tile = max(40, min(76, wheel_d * 0.19))
    return dict(top_h=top_h, wheel_d=wheel_d, wheel_cx=W / 2, wheel_cy=wheel_cy,
                preview_h=preview_h, proverb_y=proverb_y, proverb_h=proverb_h,
                tile=tile, margin=16)


def rounded(d, box, radius, fill=None, outline=None, width=1):
    d.rounded_rectangle([S(box[0]), S(box[1]), S(box[2]), S(box[3])],
                        radius=S(radius), fill=fill, outline=outline, width=S(width))


def base():
    im = Image.new("RGB", (S(W), S(H)), BG)
    return im, ImageDraw.Draw(im)


def letter_tile(d, x, y, size, ch, hot=False):
    col = TILE_HOT if hot else TILE_C
    rounded(d, (x, y, x + size, y + size), size * 0.22, fill=col,
            outline=lighten(col, 0.22), width=max(2, size * 0.025))
    ctr(d, (S(x + size / 2), S(y + size / 2)), ch, font(F_BOLD, size * 0.52), "white")


def paste_icon(im, name, x, y, size, tint=(255, 255, 255)):
    """White silhouette icon from assets/icons, tinted, like UI.icon()."""
    p = f"{GAME}/assets/icons/{name}.png"
    if not os.path.exists(p):
        return
    ic = Image.open(p).convert("RGBA").resize((S(size), S(size)))
    solid = Image.new("RGBA", ic.size, tint + (255,))
    solid.putalpha(ic.getchannel("A"))
    im.paste(solid, (S(x), S(y)), solid)


# ---------- game screen mirror ----------
def sub_words(tok):
    clean = tok
    for p in "،؟!.:؛«»()":
        clean = clean.replace(p, " ")
    clean = clean.replace("‌", " ")
    return [s for s in clean.split(" ") if s]


def draw_game(level_id, solved, sel_word, mode="campaign", rush_pct=0.55,
              revealed=None):
    lvl = LEVELS[level_id]
    m = metrics()
    im, d = base()
    revealed = revealed or {}
    targets = [t for r in lvl["rounds"] for t in r["targets"]]
    cur_round = None
    for r in lvl["rounds"]:
        if any(t not in solved for t in r["targets"]):
            cur_round = r
            break
    cur_round = cur_round or lvl["rounds"][-1]

    # HUD
    fs = max(16, min(26, H * 0.021))
    title = {"campaign": "مثل " + digits(7), "daily": "مثلِ امروز", "rush": "مسابقه"}[mode]
    ctr(d, (S(W / 2), S(m["top_h"] * 0.33)), title, font(F_BOLD, fs), ACCENT)
    hud = digits(2470) if mode == "rush" else "🪙 " + digits(3150)
    hud = hud.replace("🪙 ", "")   # coin glyph drawn as a disc below
    d.text((S(14 + fs * 1.4), S(m["top_h"] * 0.14)), hud, font=font(F_BOLD, fs * 0.95),
           fill=GOLD, anchor="la", direction="rtl", language="fa")
    if mode != "rush":
        d.ellipse([S(14), S(m["top_h"] * 0.16), S(14 + fs * 1.1), S(m["top_h"] * 0.16 + fs * 1.1)],
                  fill=GOLD, outline=lighten(GOLD, 0.3), width=S(2))
    # back button (chevrons drawn — PIL has no emoji font here)
    bw, bh = m["top_h"] * 0.62, m["top_h"] * 0.52
    rounded(d, (W - bw - 12, m["top_h"] * 0.14, W - 12, m["top_h"] * 0.14 + bh), 16,
            fill="#3a4160")
    bcx, bcy = W - 12 - bw / 2, m["top_h"] * 0.14 + bh / 2
    for dx in (-5, 6):
        d.polygon([(S(bcx + dx + 6), S(bcy - 8)), (S(bcx + dx - 3), S(bcy)),
                   (S(bcx + dx + 6), S(bcy + 8))], fill="white")
    if mode == "rush":
        rounded(d, (14, m["top_h"] * 0.66, W - 14, m["top_h"] * 0.9), 8, fill="#0f131e")
        x0 = 14 + (W - 28) * (1 - rush_pct)
        rounded(d, (x0, m["top_h"] * 0.66, W - 14, m["top_h"] * 0.9), 8,
                fill=ACCENT if rush_pct > 0.25 else "#e0455a")
    else:
        done = sum(1 for t in targets if t in solved)
        ctr(d, (S(W / 2), S(m["top_h"] * 0.75)),
            "%s از %s واژه" % (digits(done), digits(len(targets))),
            font(F_REG, fs * 0.85), MUTED)

    # proverb panel — mirrors _render_proverb
    pfs = max(19, min(32, H * 0.026))
    box = max(26, min(40, W * 0.052))
    gap, margin, line_h = 4, m["margin"] + 6, box + 14
    rounded(d, (m["margin"] - 6, m["proverb_y"],
                W - m["margin"] + 6, m["proverb_y"] + m["proverb_h"]), 20, fill=PANEL)
    fb = font(F_BOLD, pfs)

    # dry-run wrap to centre the block vertically (mirrors _count_lines)
    def token_width(tok):
        subs = [s for s in sub_words(tok) if s in targets]
        w_total, rest = 10.0, tok
        while rest and subs:
            best_i, best_w = -1, ""
            for wrd in subs:
                i = rest.find(wrd)
                if i >= 0 and (best_i < 0 or i < best_i):
                    best_i, best_w = i, wrd
            if best_i < 0:
                break
            if best_i > 0:
                w_total += d.textlength(rest[:best_i], font=fb, direction="rtl") / SS + 4
            w_total += len(best_w) * (box + gap)
            rest = rest[best_i + len(best_w):]
        if rest:
            w_total += d.textlength(rest, font=fb, direction="rtl") / SS + 4
        return w_total

    x, nlines = W - margin, 1
    for tok in lvl["text"].split(" "):
        tw = token_width(tok)
        if x - tw < margin:
            x, nlines = W - margin, nlines + 1
        x -= tw
    x = W - margin
    y = m["proverb_y"] + max(16, (m["proverb_h"] - nlines * line_h) / 2)
    for tok in lvl["text"].split(" "):
        subs = [s for s in sub_words(tok) if s in targets]
        parts = []
        rest = tok
        while rest and subs:
            best_i, best_w = -1, ""
            for wrd in subs:
                i = rest.find(wrd)
                if i >= 0 and (best_i < 0 or i < best_i):
                    best_i, best_w = i, wrd
            if best_i < 0:
                break
            if best_i > 0:
                parts.append(("text", rest[:best_i]))
            parts.append(("word", best_w))
            rest = rest[best_i + len(best_w):]
        if rest:
            parts.append(("text", rest))
        if not parts:
            parts = [("text", tok)]
        widths = []
        for kind, s_ in parts:
            if kind == "text":
                wpx = d.textlength(s_, font=fb, direction="rtl", language="fa") / SS + 4
            else:
                wpx = len(s_) * (box + gap)
            widths.append(wpx)
        tok_w = sum(widths) + 10
        if x - tok_w < margin:
            x = W - margin
            y += line_h
        for (kind, s_), wpx in zip(parts, widths):
            x -= wpx
            if kind == "text":
                ctr(d, (S(x + wpx / 2), S(y + box / 2)), s_, fb, "white")
            else:
                is_solved = s_ in solved
                shown = revealed.get(s_, 0)
                for i2 in range(len(s_)):
                    bx = x + (len(s_) - 1 - i2) * (box + gap)
                    cell_col = "#3d5f9e" if is_solved else SLOT
                    rounded(d, (bx, y, bx + box, y + box), 8, fill=cell_col)
                    if is_solved or i2 < shown:
                        ctr(d, (S(bx + box / 2), S(y + box / 2)), s_[i2],
                            font(F_BOLD, box * 0.62), "white" if is_solved else GOLD)
        x -= 10

    # preview row — mirrors _render_preview
    if sel_word:
        ps = max(34, min(54, m["preview_h"] * 0.9))
        pgap = 5
        total = len(sel_word) * (ps + pgap)
        x0 = (W + total) / 2 - ps
        py = m["wheel_cy"] - m["wheel_d"] / 2 - m["preview_h"] - 8
        for i2, ch in enumerate(sel_word):
            letter_tile(d, x0 - i2 * (ps + pgap), py, ps, ch, hot=True)

    # wheel — mirrors _render_wheel
    cx, cy = m["wheel_cx"], m["wheel_cy"]
    r_disc = m["wheel_d"] / 2
    d.ellipse([S(cx - r_disc), S(cy - r_disc), S(cx + r_disc), S(cy + r_disc)],
              fill=PANEL)
    wheel = sorted(cur_round["wheel"])
    n = len(wheel)
    rr = m["wheel_d"] / 2 - m["tile"] * 0.62
    sel_set = set(sel_word)
    for i2, ch in enumerate(wheel):
        ang = -math.pi / 2 + 2 * math.pi * i2 / n
        tx = cx + math.cos(ang) * rr - m["tile"] / 2
        ty = cy + math.sin(ang) * rr - m["tile"] / 2
        letter_tile(d, tx, ty, m["tile"], ch, hot=ch in sel_set)
    # side buttons on the preview row, at the margins (mirrors _render_wheel)
    bs = max(16, min(26, H * 0.021))
    by = cy - m["wheel_d"] / 2 - m["preview_h"] - 8
    bh2 = m["preview_h"] * 0.9
    rounded(d, (m["margin"], by, m["margin"] + m["tile"] * 0.95, by + bh2), 16,
            fill="#3a4160")
    paste_icon(im, "dice", m["margin"] + m["tile"] * 0.95 / 2 - bs * 0.7,
               by + bh2 / 2 - bs * 0.7, bs * 1.4)
    if mode != "rush":
        hw = m["tile"] * 1.35
        rounded(d, (W - m["margin"] - hw, by, W - m["margin"], by + bh2), 16,
                fill="#3a4160")
        paste_icon(im, "bulb", W - m["margin"] - hw + 8, by + bh2 / 2 - bs * 0.7, bs * 1.4)
        d.text((S(W - m["margin"] - 14), S(by + bh2 / 2)), digits(4),
               font=font(F_BOLD, bs), fill="white", anchor="rm")
    return im


# ---------- proverb card mirror ----------
def draw_card(level_id):
    lvl = LEVELS[level_id]
    im, d = base()
    ov = Image.new("RGBA", im.size, (0, 0, 0, 184))
    im.paste(Image.alpha_composite(im.convert("RGBA"), ov).convert("RGB"), (0, 0))
    d = ImageDraw.Draw(im)
    fs = max(18, min(29, H * 0.023))
    pw = min(W - 40, 560)
    ph = max(380, min(560, H * 0.5))
    px, py = (W - pw) / 2, (H - ph) / 2 - 20
    rounded(d, (px, py, px + pw, py + ph), 24, fill="#241d38")
    rounded(d, (px, py, px + pw, py + ph), 24, outline=GOLD, width=3)
    rounded(d, (px + 8, py + 8, px + pw - 8, py + ph - 8), 16,
            outline=lighten("#f2c230", 0.0) + (100,), width=2)
    for cx_, cy_ in [(px + 26, py + 26), (px + pw - 26, py + 26),
                     (px + 26, py + ph - 26), (px + pw - 26, py + ph - 26)]:
        ctr(d, (S(cx_), S(cy_)), "۞", font(F_BOLD, fs * 1.1), GOLD)
    ctr(d, (S(W / 2), S(py + ph * 0.1)), "✨ مثلِ امروز", font(F_BOLD, fs + 4), GOLD)
    ctr(d, (S(W / 2), S(py + ph * 0.1 + fs * 2.1)), "سه‌شنبه ۷ مرداد ۱۴۰۵",
        font(F_REG, fs - 5), lighten("#f2c230", 0.2))
    # proverb text, wrapped
    words = lvl["text"].split(" ")
    lines, cur = [], ""
    fb = font(F_BOLD, fs + 2)
    for wd in words:
        t2 = (cur + " " + wd).strip()
        if d.textlength("«" + t2 + "»", font=fb, direction="rtl") / SS > pw - 60 and cur:
            lines.append(cur)
            cur = wd
        else:
            cur = t2
    lines.append(cur)
    ty = py + ph * 0.32
    for i3, ln in enumerate(lines):
        txt = ln
        if i3 == 0:
            txt = "«" + txt
        if i3 == len(lines) - 1:
            txt = txt + "»"
        ctr(d, (S(W / 2), S(ty)), txt, fb, "white")
        ty += (fs + 2) * 1.6
    ty += fs * 1.2
    ctr(d, (S(W / 2), S(ty)), "یعنی چه؟", font(F_BOLD, fs - 1), ACCENT)
    ty += fs * 1.8
    mlines, cur = [], ""
    fr = font(F_REG, fs - 1)
    for wd in lvl["meaning"].split(" "):
        t2 = (cur + " " + wd).strip()
        if d.textlength(t2, font=fr, direction="rtl") / SS > pw - 60 and cur:
            mlines.append(cur); cur = wd
        else:
            cur = t2
    mlines.append(cur)
    for ln in mlines:
        ctr(d, (S(W / 2), S(ty)), ln, fr, "#d8dcea")
        ty += (fs - 1) * 1.55
    # share button
    by = py + ph + 16
    bw2 = min(W - 80, 340)
    rounded(d, ((W - bw2) / 2, by, (W + bw2) / 2, by + fs * 2.4), 16, fill="#3a6a48")
    ctr(d, (S(W / 2), S(by + fs * 1.2)), "کپی و ارسال این مثل", font(F_BOLD, fs - 3), "white")
    return im


# ---------- menu mirror (proportions of menu_screen.gd) ----------
def draw_menu():
    im, d = base()
    hero = f"{GAME}/assets/art/hero_bg.png"
    if os.path.exists(hero):
        hb = Image.open(hero).convert("RGB")
        scale = max(S(W) / hb.width, S(H) / hb.height)
        hb = hb.resize((int(hb.width * scale), int(hb.height * scale)))
        im.paste(hb, ((S(W) - hb.width) // 2, (S(H) - hb.height) // 2))
        ov = Image.new("RGBA", im.size, (28, 32, 46, 140))
        im = Image.alpha_composite(im.convert("RGBA"), ov).convert("RGB")
        d = ImageDraw.Draw(im)
    fs = max(15, min(25, H * 0.02))
    # chips
    ch_h, ch_w = fs * 2.2, min(W * 0.27, 165)
    for x0, wdt, txt in [(14, ch_w, digits(3150)), (14 + ch_w + 8, ch_w * 0.76, digits(6))]:
        rounded(d, (x0, 16, x0 + wdt, 16 + ch_h), 12, fill="#161b28")
        ctr(d, (S(x0 + wdt / 2), S(16 + ch_h / 2)), txt, font(F_BOLD, fs), "white")
    y = 16 + ch_h + 8
    ctr(d, (S(W / 2), S(y + H * 0.036)), "مثلستان", font(F_BOLD, max(36, min(70, H * 0.05))), "white")
    y += max(52, min(90, H * 0.072))
    ctr(d, (S(W / 2), S(y + fs)), "رکورد: " + digits(38980), font(F_BOLD, max(16, min(28, H * 0.022))), GOLD)
    y += fs * 2.0
    # mascot + bubble
    owl_h = max(100, min(200, H * 0.14))
    mp = f"{GAME}/assets/art/mascot.png"
    owl_w = 0
    if os.path.exists(mp):
        mi = Image.open(mp).convert("RGBA")
        r = min(owl_h * 0.95 * SS / mi.width, owl_h * SS / mi.height)
        mi = mi.resize((int(mi.width * r), int(mi.height * r)))
        owl_w = mi.width / SS
        im.paste(mi, (S(W) - mi.width - S(10), S(y)), mi)
    bw2 = max(160, W - owl_w - 36)
    rounded(d, (14, y + owl_h * 0.14, 14 + bw2, y + owl_h * 0.14 + owl_h * 0.66), 16,
            fill="#2b3350")
    ctr(d, (S(14 + bw2 / 2), S(y + owl_h * 0.14 + owl_h * 0.33)),
        "سلام! من شِکَرَکم. بزن بریم!", font(F_REG, fs), "white")
    y += owl_h + 8
    # missions panel
    mp_w = max(300, min(552, W * 0.92))
    mfs = max(14, min(22, H * 0.018))
    head = mfs * 2.6
    row_h = mfs * 2.5
    mp_h = head + row_h * 3 + mfs * 0.7
    mx = (W - mp_w) / 2
    rounded(d, (mx, y, mx + mp_w, y + mp_h), 18, fill="#1a2030")
    rtl(d, (S(mx + mp_w - mfs * 2.6), S(y + mfs * 0.8)), "مأموریت‌های امروز",
        font(F_BOLD, mfs + 2), "white")
    rows = [("۸ واژه حل کن (۵/۸)", 0.62, False), ("مثلِ امروز را تمام کن (۰/۱)", 0.0, False),
            ("۲ واژهٔ پنهان پیدا کن (۲/۲)", 1.0, True)]
    my = y + head
    for txt, pct, done in rows:
        rounded(d, (mx + mfs * 0.8, my, mx + mp_w - mfs * 0.8, my + row_h - mfs * 0.55),
                10, fill="#0f131e")
        if pct > 0:
            fill_w = (mp_w - mfs * 1.6) * pct
            rounded(d, (mx + mfs * 0.8, my, mx + mfs * 0.8 + fill_w, my + row_h - mfs * 0.55),
                    10, fill="#2e7d5b" if done else ACCENT)
        rtl(d, (S(mx + mp_w - mfs * 1.6), S(my + mfs * 0.5)), txt, font(F_BOLD, mfs), "white")
        my += row_h
    y += mp_h + max(10, min(24, H * 0.018))
    # actions
    bw3 = max(250, min(380, W * 0.7))
    avail = max(220, H - y - 24)
    bh3 = max(54, min(96, avail * 0.2))
    rounded(d, ((W - bw3) / 2, y, (W + bw3) / 2, y + bh3), 16, fill=ACCENT)
    ctr(d, (S(W / 2), S(y + bh3 / 2)), "سفرِ مثل‌ها", font(F_BOLD, int(bh3 * 0.38)), "white")
    y += bh3 + 14
    gw = (bw3 - 12) / 2
    gh = max(42, min(84, (avail - bh3 - 24) / 4 - 10))
    labels = ["مثل امروز", "مسابقه", "گنجینهٔ مثل‌ها", "جدول جهانی",
              "فروشگاه", "رکوردها", "تنظیمات", "حساب کاربری"]
    for i2, lab in enumerate(labels):
        x0 = (W - bw3) / 2 + (i2 % 2) * (gw + 12)
        y0 = y + (i2 // 2) * (gh + 10)
        rounded(d, (x0, y0, x0 + gw, y0 + gh), 16, fill="#232a3d")
        ctr(d, (S(x0 + gw / 2), S(y0 + gh / 2)), lab, font(F_BOLD, int(min(gh * 0.34, 22))), "white")
    return im


# ---------- treasury mirror ----------
def draw_treasury():
    im, d = base()
    fs = max(15, min(25, H * 0.02))
    ctr(d, (S(W / 2), S(H * 0.055)), "گنجینهٔ مثل‌ها", font(F_BOLD, max(28, min(50, H * 0.038))), "white")
    card_w = max(300, min(540, W * 0.88))
    card_h = fs * 6.4
    cx0 = (W - card_w) / 2
    cy0 = H * 0.115
    rounded(d, (cx0, cy0, cx0 + card_w, cy0 + card_h), 20, fill="#2c2440")
    ctr(d, (S(W / 2), S(cy0 + fs * 1.2)), "✨ مثلِ امروز", font(F_BOLD, fs + 2), GOLD)
    ctr(d, (S(W / 2), S(cy0 + fs * 3.3)), "«هر گردی گردو نیست»", font(F_REG, fs), "white")
    rounded(d, (cx0 + card_w * 0.25, cy0 + fs * 4.5 - 6, cx0 + card_w * 0.75,
                cy0 + fs * 4.5 - 6 + fs * 2.4), 16, fill="#6b4f9e")
    ctr(d, (S(W / 2), S(cy0 + fs * 5.7 - 6)), "مثلِ امروز", font(F_BOLD, fs), "white")
    ty = cy0 + card_h + 14
    ctr(d, (S(W / 2), S(ty + fs)), "🏺 ۴۲ از ۱۱۳ جمع شده", font(F_BOLD, fs + 3), GOLD)
    ty += fs * 2.4
    samples = [("m031", True), ("m009", True), ("m044", True), ("m022", True),
               ("m057", True), (None, False), (None, False), (None, False)]
    for lid, got in samples:
        rh = fs * 2.6
        rounded(d, (20, ty, W - 20, ty + rh), 12, fill="#2c2440" if got else "#1f1c2b")
        txt = "📜 " + LEVELS[lid]["text"] if got else "🔒 ؟؟؟ — هر روز مثلِ امروز را حل کن"
        if d.textlength(txt, font=font(F_BOLD if got else F_REG, fs), direction="rtl") / SS > W - 60:
            txt = txt[:42] + "…"
        rtl(d, (S(W - 34), S(ty + rh * 0.28)), txt, font(F_BOLD if got else F_REG, fs),
            "white" if got else MUTED)
        ty += rh + 8
    return im


# ---------- finalize: upscale + caption band ----------
def caption(im, text):
    im = im.resize((S(W), S(H)), Image.LANCZOS)
    band_h = S(150)
    out = Image.new("RGB", (S(W), S(H) + band_h), "#12141d")
    out.paste(im, (0, band_h))
    d = ImageDraw.Draw(out)
    ctr(d, (S(W / 2), band_h // 2), text, font(F_BOLD, 30), "white")
    return out.resize(FINAL, Image.LANCZOS)


def save(im, name):
    path = f"{OUT}/{name}.jpg"
    im.convert("RGB").save(path, quality=88)
    kb = os.path.getsize(path) // 1024
    print(f"{name}.jpg  {kb} KB")
    assert kb < 1024, f"{name} exceeds the 1 MB store cap"


def main():
    # shot 1: campaign mid-solve (m049 has 3 rounds — shows the round system)
    lv = LEVELS["m049"]
    ts = [t for r in lv["rounds"] for t in r["targets"]]
    save(caption(draw_game("m049", solved=ts[:2], sel_word=ts[2][:2]),
         "واژه‌ها را پیدا کن، مَثَل کامل شود"), "01_game")
    # shot 2: the proverb card
    save(caption(draw_card("m030"), "هر مثل، معنی و حکایتش را بخوان"), "02_card")
    # shot 3: rush mode
    lv2 = LEVELS["m064"]
    ts2 = [t for r in lv2["rounds"] for t in r["targets"]]
    save(caption(draw_game("m064", solved=ts2[:1], sel_word="", mode="rush",
         rush_pct=0.4), "مسابقه با زمان — زنجیره بساز!"), "03_rush")
    # shot 4: menu with mascot
    save(caption(draw_menu(), "هر روز یک مثل تازه برای همهٔ ایران"), "04_menu")
    # shot 5: treasury
    save(caption(draw_treasury(), "گنجینهٔ ضرب‌المثل‌هایت را کامل کن"), "05_treasury")
    print("done →", OUT)


if __name__ == "__main__":
    main()
