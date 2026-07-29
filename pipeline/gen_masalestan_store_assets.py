#!/usr/bin/env python3
"""Header (720×288 PNG 5:2) and promo (1152×648 JPG 16:9) for the مثلستان listing.
Art comes from the generated hero/mascot; Persian text is stamped with Vazirmatn (L8)."""
import os
from PIL import Image, ImageDraw, ImageFilter, ImageFont

GAME = "/home/claude/godot/games/masalestan"
OUT = "/home/claude/godot/releases/masalestan/screenshots"
F_BOLD = f"{GAME}/assets/fonts/Vazirmatn-Bold.ttf"
F_REG = f"{GAME}/assets/fonts/Vazirmatn-Regular.ttf"


def band(w, h, ss=2):
    """A wide slice of the hero art, blurred slightly and darkened for text."""
    hero = Image.open(f"{GAME}/assets/art/hero_bg.png").convert("RGB")
    scale = (w * ss) / hero.width
    hero = hero.resize((w * ss, int(hero.height * scale)), Image.LANCZOS)
    top = int(hero.height * 0.28)
    im = hero.crop((0, top, w * ss, top + h * ss)).filter(ImageFilter.GaussianBlur(2))
    ov = Image.new("RGBA", im.size, (16, 18, 34, 120))
    return Image.alpha_composite(im.convert("RGBA"), ov), ss


def rtl(d, xy, txt, f, fill, anchor="mm"):
    d.text(xy, txt, font=f, fill=fill, anchor=anchor, direction="rtl", language="fa",
           stroke_width=max(2, f.size // 22), stroke_fill=(10, 10, 20))


def mascot(h):
    m = Image.open(f"{GAME}/assets/art/mascot_cheer.png").convert("RGBA")
    r = h / m.height
    return m.resize((int(m.width * r), h), Image.LANCZOS)


def header():
    w, h = 720, 288
    im, ss = band(w, h)
    d = ImageDraw.Draw(im)
    mc = mascot(int(h * ss * 0.8))
    im.paste(mc, (int(w * ss * 0.06), int(h * ss * 0.12)), mc)
    rtl(d, (int(w * ss * 0.62), int(h * ss * 0.38)), "مثلستان",
        ImageFont.truetype(F_BOLD, int(h * ss * 0.34)), "white")
    rtl(d, (int(w * ss * 0.62), int(h * ss * 0.72)), "سرزمین ضرب‌المثل‌های فارسی",
        ImageFont.truetype(F_REG, int(h * ss * 0.115)), (242, 194, 48))
    im = im.convert("RGB").resize((w, h), Image.LANCZOS)
    p = f"{OUT}/header_720x288.png"
    im.save(p)
    print(p, os.path.getsize(p) // 1024, "KB")


def promo():
    w, h = 1152, 648
    im, ss = band(w, h)
    d = ImageDraw.Draw(im)
    mc = mascot(int(h * ss * 0.74))
    im.paste(mc, (int(w * ss * 0.05), int(h * ss * 0.2)), mc)
    rtl(d, (int(w * ss * 0.60), int(h * ss * 0.30)), "مثلستان",
        ImageFont.truetype(F_BOLD, int(h * ss * 0.24)), "white")
    rtl(d, (int(w * ss * 0.60), int(h * ss * 0.52)), "واژه‌ها را پیدا کن، مَثَل را آشکار کن",
        ImageFont.truetype(F_REG, int(h * ss * 0.085)), (242, 194, 48))
    rtl(d, (int(w * ss * 0.60), int(h * ss * 0.68)), "هر روز یک مثل تازه برای همهٔ ایران",
        ImageFont.truetype(F_REG, int(h * ss * 0.07)), "white")
    im = im.convert("RGB").resize((w, h), Image.LANCZOS)
    p = f"{OUT}/promo_1152x648.jpg"
    im.save(p, quality=90)
    print(p, os.path.getsize(p) // 1024, "KB")


header()
promo()
