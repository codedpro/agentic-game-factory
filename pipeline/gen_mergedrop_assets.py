#!/usr/bin/env python3
"""Generate procedural audio + icon assets for MergeDrop."""
import numpy as np, wave, os
from PIL import Image, ImageDraw, ImageFont

GAME = "/home/claude/godot/games/mergedrop"
SR = 44100

def save_wav(path, data):
    data = np.clip(data, -1, 1)
    with wave.open(path, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((data * 32767).astype(np.int16).tobytes())

def env(n, attack=0.005, decay=None):
    t = np.arange(n) / SR
    a = int(attack * SR)
    e = np.ones(n)
    e[:a] = np.linspace(0, 1, a)
    d = decay or (n / SR)
    e *= np.exp(-t / (d * 0.3))
    return e

def tone(freq, dur, shape="sine"):
    t = np.arange(int(dur * SR)) / SR
    if shape == "sine": s = np.sin(2 * np.pi * freq * t)
    elif shape == "tri": s = 2 * np.abs(2 * ((freq * t) % 1) - 1) - 1
    else: s = np.sign(np.sin(2 * np.pi * freq * t))
    return s

sfx = os.path.join(GAME, "assets/sfx")

# drop: short soft thump
n = int(0.12 * SR); t = np.arange(n) / SR
drop = np.sin(2 * np.pi * (180 - 120 * t / 0.12) * t) * env(n, decay=0.1)
save_wav(f"{sfx}/drop.wav", drop * 0.7)

# merge: bright pop (played with rising pitch per chain in-game)
n = int(0.18 * SR); t = np.arange(n) / SR
merge = (np.sin(2 * np.pi * 620 * t * (1 + 1.8 * t)) * 0.7 +
         np.sin(2 * np.pi * 1240 * t * (1 + 1.8 * t)) * 0.3) * env(n, decay=0.15)
save_wav(f"{sfx}/merge.wav", merge * 0.8)

# ui tick
n = int(0.05 * SR)
save_wav(f"{sfx}/ui.wav", tone(900, 0.05, "tri") * env(n, decay=0.04) * 0.5)

# game over: gentle descending triad
parts = []
for f in (523, 415, 349, 262):
    n = int(0.28 * SR)
    parts.append(tone(f, 0.28) * env(n, decay=0.35) * 0.6)
save_wav(f"{sfx}/gameover.wav", np.concatenate(parts))

# big merge (256+): reward chord
n = int(0.5 * SR); t = np.arange(n) / SR
chord = sum(np.sin(2 * np.pi * f * t) for f in (523, 659, 784, 1047)) / 4
save_wav(f"{sfx}/bigmerge.wav", chord * env(n, decay=0.5) * 0.85)

# ---- Icon 512 + 192: two merging tiles ----
def make_icon(size):
    img = Image.new("RGBA", (size, size), (28, 32, 46, 255))
    d = ImageDraw.Draw(img)
    s = size / 512.0
    def rr(box, r, fill): d.rounded_rectangle(box, radius=r, fill=fill)
    # back tile (orange, "4") peeking behind
    rr((150*s, 90*s, 420*s, 360*s), 48*s, (240, 150, 60, 255))
    # front tile (blue, "2")
    rr((80*s, 170*s, 360*s, 450*s), 48*s, (80, 140, 240, 255))
    font_big = ImageFont.truetype(f"{GAME}/assets/fonts/Vazirmatn-Bold.ttf", int(150*s))
    font_sm = ImageFont.truetype(f"{GAME}/assets/fonts/Vazirmatn-Bold.ttf", int(110*s))
    d.text((285*s, 155*s), "4", font=font_sm, fill=(255, 250, 240, 255), anchor="mm")
    d.text((220*s, 305*s), "2", font=font_big, fill=(255, 255, 255, 255), anchor="mm")
    return img

make_icon(512).save(f"{GAME}/icon.png")
make_icon(192).save(f"{GAME}/icon_192.png")
print("assets generated:", os.listdir(sfx), "+ icon.png icon_192.png")
