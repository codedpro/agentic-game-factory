#!/usr/bin/env python3
"""Audio for مثلستان: two-stem dynamic music with a Persian flavour + word-game SFX.
Same filenames as the factory's standard set, so sfx.gd/music.gd and the loop-enabled
.import files carry over unchanged.

Music: 92 BPM, D Shur-flavoured scale (D Eb F G A Bb C), santur-like double-strike
plucks over a drone — calm stem for the journey, driving stem for the race.
"""
import numpy as np, wave

SR = 44100
OUT = "/home/claude/godot/games/masalestan/assets/sfx"

def save(name, data, peak=0.85):
    m = np.max(np.abs(data))
    if m > 0:
        data = data / m * peak
    with wave.open(f"{OUT}/{name}.wav", "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((np.clip(data, -1, 1) * 32767).astype(np.int16).tobytes())
    print(name, round(len(data)/SR, 2), "s")

def sil(dur): return np.zeros(int(dur * SR))

def sine(f, dur):
    t = np.arange(int(dur * SR)) / SR
    return np.sin(2 * np.pi * f * t)

def adsr(n, a=0.01, d=0.1, s=0.6, r=0.2):
    a_n, d_n, r_n = int(a*SR), int(d*SR), int(r*SR)
    s_n = max(0, n - a_n - d_n - r_n)
    env = np.concatenate([
        np.linspace(0, 1, max(a_n, 1)),
        np.linspace(1, s, max(d_n, 1)),
        np.full(s_n, s),
        np.linspace(s, 0, max(r_n, 1))])
    return env[:n] if len(env) >= n else np.pad(env, (0, n - len(env)))

def santur(f, dur, bright=1.0):
    """Hammered-string voice: two quick strikes a few ms apart, rich partials."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    def strike(det):
        s = (np.sin(2*np.pi*f*det*t) + 0.5*bright*np.sin(2*np.pi*2.01*f*det*t)
             + 0.25*bright*np.sin(2*np.pi*2.99*f*det*t)
             + 0.12*bright*np.sin(2*np.pi*4.02*f*det*t))
        return s * np.exp(-t * 6.5)
    out = strike(1.0)
    d2 = np.zeros(n)
    off = int(0.018 * SR)
    d2[off:] = strike(1.004)[:n-off]
    return out * 0.6 + d2 * 0.45

def noise(dur): return np.random.RandomState(7).uniform(-1, 1, int(dur * SR))

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

# ============ MUSIC: 92 BPM, 16 bars, D "Shur-ish": D Eb F G A Bb C ============
BEAT = 60.0 / 92.0
BARS = 16
TOTAL = BARS * 4 * BEAT
N = int(TOTAL * SR)

D3, Eb3, F3, G3, A3, Bb3, C4 = 146.83, 155.56, 174.61, 196.00, 220.00, 233.08, 261.63
D4, Eb4, F4, G4, A4, Bb4, C5 = 293.66, 311.13, 349.23, 392.00, 440.00, 466.16, 523.25
D5, F5, G5, A5 = 587.33, 698.46, 783.99, 880.00
D2 = 73.42

# calm: drone + slow santur phrases (the journey / menu)
calm = np.zeros(N)
t_all = np.arange(N) / SR
drone = (np.sin(2*np.pi*D2*t_all) * 0.30
         + np.sin(2*np.pi*D3*t_all) * 0.18
         + np.sin(2*np.pi*(A3)*t_all) * 0.08)
drone *= 0.75 + 0.25 * np.sin(2*np.pi*t_all / TOTAL * 4)   # slow breath, loop-safe
calm += drone * 0.5

PHRASE = [D4, Eb4, F4, G4, F4, Eb4, D4, C4,
          D4, F4, G4, A4, G4, F4, Eb4, D4]
for rep in range(2):
    for k, f in enumerate(PHRASE):
        at = (rep * len(PHRASE) + k) * 2 * BEAT
        if at >= TOTAL:
            break
        place(calm, santur(f, 1.6, 0.7) * 0.28, at)
        if k % 4 == 0:      # soft octave echo
            place(calm, santur(f * 2, 1.2, 0.5) * 0.10, at + BEAT * 0.5)

# energy: daf-like pulse + faster santur runs (the race)
energy = np.zeros(N)
rs = np.random.RandomState(14050507)
SCALE = [D4, Eb4, F4, G4, A4, Bb4, C5, D5]
run = [rs.choice(len(SCALE)) for _ in range(32)]
for bar in range(BARS):
    at0 = bar * 4 * BEAT
    for beat in range(4):
        at = at0 + beat * BEAT
        # daf: low skin hit on the beat
        n = int(0.14 * SR); t = np.arange(n) / SR
        daf = np.sin(2*np.pi*(85 - 260*t)*t) * np.exp(-t*24)
        place(energy, daf * 0.9, at)
        # rim/jingle on the off-beat
        h = hp(noise(0.04)) * np.exp(-np.arange(int(0.04*SR))/SR*80)
        place(energy, h * 0.28, at + BEAT/2)
        if beat == 3:   # pickup roll into the next bar
            for r3 in range(3):
                place(energy, daf * 0.35, at + BEAT * (0.55 + 0.15 * r3))
    for k in range(8):   # santur run, one note per half-beat, occasional rest
        if (bar + k) % 7 == 6:
            continue
        f = SCALE[run[(bar * 8 + k) % 32]]
        place(energy, santur(f, 0.5, 1.2) * 0.26, at0 + k * BEAT/2)

save("music_calm", calm, 0.8)
save("music_energy", energy, 0.8)

# ================= SFX (same names the code already plays) =================
# drop/drop2/drop3 → letter-tile ticks (wheel selection variants)
for i, base in enumerate([720, 810, 650]):
    n = int(0.06 * SR); t = np.arange(n) / SR
    d = np.sin(2*np.pi*base*t) * np.exp(-t*55)
    click = hp(noise(0.01)) * 0.2
    d[:len(click)] += click
    save("drop" if i == 0 else f"drop{i+1}", d, 0.5)

# merge tiers → word-solved chimes (santur strike + fifth), higher per tier
for tier in (1, 2, 3):
    root = 440 * (1.19 ** (tier - 1))
    buf = sil(0.5)
    place(buf, santur(root, 0.45, 1.1) * 0.7, 0)
    place(buf, santur(root * 1.5, 0.4, 0.9) * 0.4, 0.05)
    save(f"merge{'' if tier == 1 else tier}", buf, 0.7)

# bigmerge → proverb completed: ascending santur flourish over the scale
buf = sil(1.0)
for k, f in enumerate([D4, F4, G4, A4, C5, D5, F5, A5]):
    place(buf, santur(f, 0.5, 1.2) * 0.5, k * 0.07)
shimmer = hp(noise(0.7)) * np.exp(-np.arange(int(0.7*SR))/SR*7) * 0.10
place(buf, shimmer, 0.25)
save("bigmerge", buf, 0.8)

# stone → wrong word: muted dud
n = int(0.16 * SR); t = np.arange(n) / SR
dud = lp(noise(0.16), 0.3) * np.exp(-t*30)
dud += np.sin(2*np.pi*(110 - 150*t)*t) * np.exp(-t*28) * 0.6
save("stone", dud, 0.6)

# levelup → new wheel round: quick riser + bright strike
buf = sil(0.8)
n = int(0.35 * SR); t = np.arange(n) / SR
riser = np.sin(2*np.pi*(294 + 580*t/0.35)*t) * np.linspace(0.05, 0.5, n)
place(buf, riser, 0)
place(buf, santur(D5, 0.5, 1.2) * 0.6, 0.35)
place(buf, santur(A4, 0.5, 1.0) * 0.35, 0.37)
save("levelup", buf, 0.8)

# coin: bright double ding (kept close to the factory sound — it reads as "money")
buf = sil(0.35)
place(buf, sine(1318.5, 0.18) * np.exp(-np.arange(int(0.18*SR))/SR*18), 0)
place(buf, sine(1760, 0.22) * np.exp(-np.arange(int(0.22*SR))/SR*14), 0.07)
save("coin", buf, 0.6)

# gameover: slow descending shur phrase
buf = sil(1.6)
for k, f in enumerate([A4, G4, F4, Eb4, D4]):
    place(buf, santur(f, 0.7, 0.7) * 0.5, k * 0.26)
save("gameover", buf, 0.7)

# ui tick
n = int(0.045 * SR); t = np.arange(n) / SR
save("ui", np.sin(2*np.pi*950*t) * np.exp(-t*60), 0.45)
