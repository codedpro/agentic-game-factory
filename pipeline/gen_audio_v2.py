#!/usr/bin/env python3
"""v2 audio for Beriz o Besaz: two-stem dynamic music + rich SFX set."""
import numpy as np, wave

SR = 44100
OUT = "/home/claude/godot/games/mergedrop/assets/sfx"

def save(name, data, peak=0.85):
    m = np.max(np.abs(data))
    if m > 0:
        data = data / m * peak
    with wave.open(f"{OUT}/{name}.wav", "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((np.clip(data, -1, 1) * 32767).astype(np.int16).tobytes())
    print(name, round(len(data)/SR, 2), "s")

def sil(dur): return np.zeros(int(dur * SR))

def sine(f, dur, ph=0.0):
    t = np.arange(int(dur * SR)) / SR
    return np.sin(2 * np.pi * f * t + ph)

def adsr(n, a=0.01, d=0.1, s=0.6, r=0.2):
    a_n, d_n, r_n = int(a*SR), int(d*SR), int(r*SR)
    s_n = max(0, n - a_n - d_n - r_n)
    env = np.concatenate([
        np.linspace(0, 1, max(a_n, 1)),
        np.linspace(1, s, max(d_n, 1)),
        np.full(s_n, s),
        np.linspace(s, 0, max(r_n, 1))])
    return env[:n] if len(env) >= n else np.pad(env, (0, n - len(env)))

def pluck(f, dur, bright=1.0):
    t = np.arange(int(dur * SR)) / SR
    s = np.sin(2*np.pi*f*t) + 0.45*bright*np.sin(2*np.pi*2*f*t) + 0.2*bright*np.sin(2*np.pi*3*f*t)
    return s * np.exp(-t * 5.5)

def noise(dur): return np.random.RandomState(3).uniform(-1, 1, int(dur * SR))

def hp(x, alpha=0.95):
    y = np.zeros_like(x)
    for i in range(1, len(x)):
        y[i] = alpha * (y[i-1] + x[i] - x[i-1])
    return y

def lp(x, alpha=0.15):
    y = np.zeros_like(x); acc = 0.0
    for i in range(len(x)):
        acc += alpha * (x[i] - acc); y[i] = acc
    return y

def place(buf, sig, at):
    s = int(at * SR)
    e = min(len(buf), s + len(sig))
    if s < len(buf):
        buf[s:e] += sig[:e-s]

# ================= MUSIC: 100 BPM, A minor, 16 bars (38.4 s), two synced stems =================
BEAT = 0.6
BARS = 16
TOTAL = BARS * 4 * BEAT
N = int(TOTAL * SR)
A2,C3,D3,E3,F3,G3,A3,B3,C4,D4,E4,F4,G4,A4,C5,D5,E5,G5,A5 = \
    110.0,130.81,146.83,164.81,174.61,196.0,220.0,246.94,261.63,293.66,329.63,349.23,392.0,440.0,523.25,587.33,659.26,783.99,880.0
PROG = [(A3,C4,E4,A2), (F3,A3,C4,F3/2), (C4,E4,G4,C3), (G3,B3,D4,G3/2)]  # chord + bass root

calm = np.zeros(N)
for rep in range(4):
    for bi, (n1, n2, n3, bass) in enumerate(PROG):
        at = (rep * 4 + bi) * 4 * BEAT
        dur = 4 * BEAT
        n = int(dur * SR); t = np.arange(n) / SR
        env = adsr(n, a=0.5, d=0.5, s=0.7, r=0.9)
        pad = sum(np.sin(2*np.pi*f*t) + 0.6*np.sin(2*np.pi*f*1.006*t) for f in (n1, n2, n3)) / 4.5
        place(calm, pad * env * 0.5, at)
        place(calm, sine(bass, dur) * adsr(n, a=0.02, d=0.8, s=0.4, r=0.8) * 0.5, at)
        # gentle arp 8ths
        arp = [n3, n2, n1, n2] * 2
        for k, f in enumerate(arp):
            place(calm, pluck(f * 2, 0.5, 0.5) * 0.16, at + k * BEAT / 2)

energy = np.zeros(N)
rs = np.random.RandomState(20260725)
PENT = [A4, C5, D5, E5, G5, A5]
phrase = [rs.choice(len(PENT)) for _ in range(16)]
for rep in range(4):
    for bar in range(4):
        at0 = (rep * 4 + bar) * 4 * BEAT
        for beat in range(4):
            at = at0 + beat * BEAT
            # kick
            n = int(0.16 * SR); t = np.arange(n) / SR
            kick = np.sin(2*np.pi*(95 - 320*t)*t) * np.exp(-t*22)
            place(energy, kick * 0.95, at)
            # hats on off-beats
            h = hp(noise(0.05)) * np.exp(-np.arange(int(0.05*SR))/SR*70)
            place(energy, h * 0.3, at + BEAT/2)
        # lead: one note per half-beat from fixed phrase, some rests
        for k in range(8):
            idx = (bar * 8 + k) % 16
            if (bar * 8 + k) % 5 == 4:
                continue
            f = PENT[phrase[idx]]
            place(energy, pluck(f, 0.42, 1.2) * 0.30, at0 + k * BEAT/2)

save("music_calm", calm, 0.8)
save("music_energy", energy, 0.8)

# ================= SFX =================
# drop variants: soft thock
for i, base in enumerate([150, 175, 130]):
    n = int(0.1 * SR); t = np.arange(n) / SR
    d = np.sin(2*np.pi*(base - 600*t)*t) * np.exp(-t*40)
    click = hp(noise(0.012)) * 0.4
    d[:len(click)] += click
    save("drop" if i == 0 else f"drop{i+1}", d, 0.6)

# merge tiers 1..3: bubbly pop chord, higher/richer per tier
for tier in (1, 2, 3):
    root = 392 * (1.18 ** (tier - 1))
    n = int(0.22 * SR); t = np.arange(n) / SR
    pop = np.sin(2*np.pi*root*t*(1 + 2.2*t)) * 0.6
    for h, g in ((1.25, 0.35), (1.5, 0.45), (2.0, 0.3)):
        pop += np.sin(2*np.pi*root*h*t*(1 + 2.2*t)) * g
    save(f"merge{'' if tier == 1 else tier}", pop * np.exp(-t*13), 0.7)

# bigmerge: ascending sparkle arpeggio
buf = sil(0.7)
for k, f in enumerate([C5, E5, G5, 2*C5, 2*E5]):
    place(buf, pluck(f, 0.3, 1.3) * 0.5, k * 0.055)
shimmer = hp(noise(0.6)) * np.exp(-np.arange(int(0.6*SR))/SR*8) * 0.12
place(buf, shimmer, 0.1)
save("bigmerge", buf, 0.8)

# stone break: crunchy burst
n = int(0.18 * SR); t = np.arange(n) / SR
crunch = lp(noise(0.18), 0.4) * np.exp(-t*26)
crunch += np.sin(2*np.pi*(90 - 200*t)*t) * np.exp(-t*30) * 0.7
save("stone", crunch, 0.7)

# level up: riser + chord hit
buf = sil(0.9)
n = int(0.45 * SR); t = np.arange(n) / SR
riser = np.sin(2*np.pi*(220 + 660*t/0.45)*t) * np.linspace(0.05, 0.5, n)
place(buf, riser, 0)
n2 = int(0.45 * SR); t2 = np.arange(n2) / SR
hit = sum(np.sin(2*np.pi*f*t2) for f in (A4, C5, E5, A5)) / 4 * np.exp(-t2*5)
place(buf, hit, 0.45)
save("levelup", buf, 0.8)

# coin: bright double ding
buf = sil(0.35)
place(buf, sine(1318.5, 0.18) * np.exp(-np.arange(int(0.18*SR))/SR*18), 0)
place(buf, sine(1760, 0.22) * np.exp(-np.arange(int(0.22*SR))/SR*14), 0.07)
save("coin", buf, 0.6)

# gameover: gentle descending minor phrase
buf = sil(1.4)
for k, f in enumerate([E4, C4, B3, A3]):
    place(buf, pluck(f, 0.6, 0.7) * 0.55, k * 0.28)
save("gameover", buf, 0.7)

# ui tick
n = int(0.045 * SR); t = np.arange(n) / SR
save("ui", np.sin(2*np.pi*950*t) * np.exp(-t*60), 0.45)
