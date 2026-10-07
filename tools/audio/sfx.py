"""Procedural sound effects."""
import numpy as np
from synth import *
OUT = '/home/claude/audio/sfx/'
import os; os.makedirs(OUT, exist_ok=True)

def norm(x, peak=0.8):
    return x / (np.abs(x).max() + 1e-9) * peak

def st(x): return np.stack([x, x], axis=1) if x.ndim == 1 else x

def loopify(x, fade=0.25):
    n = int(fade * SR)
    a = x[:n].copy(); b = x[-n:].copy()
    w = np.linspace(0, 1, n)[:, None] if x.ndim == 2 else np.linspace(0, 1, n)
    x = x[:-n].copy()
    x[:n] = a * w + b * (1 - w)
    return x

r = np.random.default_rng(11)

# footsteps on stone: soft tap + gritty scuff
for i in range(4):
    t = t_arr(0.18)
    thump = np.sin(2 * np.pi * (140 + 40 * i) * t) * np.exp(-t / 0.018)
    grit = bp(r.standard_normal(len(t)), 1800, 6000) * np.exp(-t / 0.02) * 0.5
    save(OUT + f'step_stone_{i}.wav', st(norm(thump + grit, 0.5)))
# footsteps on grass: rustle
for i in range(4):
    t = t_arr(0.22)
    e = np.exp(-t / 0.05) * np.clip(t / 0.008, 0, 1)
    x = bp(r.standard_normal(len(t)), 1200 + 300 * i, 7000) * e
    save(OUT + f'step_grass_{i}.wav', st(norm(x, 0.4)))
# wooden floor (hub)
for i in range(3):
    t = t_arr(0.15)
    x = np.sin(2 * np.pi * (220 + 30 * i) * t) * np.exp(-t / 0.03) + 0.4 * np.sin(2 * np.pi * (520 + 50 * i) * t) * np.exp(-t / 0.015)
    save(OUT + f'step_wood_{i}.wav', st(norm(x, 0.45)))

# jump: cute upward chirp
t = t_arr(0.22)
f = 320 + 900 * (t / 0.22) ** 0.6
x = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.09) * 0.7 + bp(r.standard_normal(len(t)), 2000, 8000) * np.exp(-t / 0.03) * 0.2
save(OUT + 'jump.wav', st(norm(x, 0.55)))
# land
t = t_arr(0.25)
x = np.sin(2 * np.pi * (90 + 60 * np.exp(-t / 0.03)) * t) * np.exp(-t / 0.06) + lp(r.standard_normal(len(t)), 900) * np.exp(-t / 0.04) * 0.6
save(OUT + 'land.wav', st(norm(x, 0.6)))

# glide / wind loop
t = t_arr(4.25)
n = r.standard_normal((len(t), 2))
mod = 0.6 + 0.4 * np.sin(2 * np.pi * 0.5 * t)[:, None]
x = (bp(n, 300, 1400) * 0.7 + bp(n, 2000, 5000) * 0.25) * mod
save(OUT + 'wind_loop.wav', norm(loopify(x), 0.5))

# orb collect: sparkling D-major arpeggio
tr = Track(2.5)
for k, n in enumerate(['D6', 'F#6', 'A6', 'D7', 'F#7']):
    tr.add(k * 0.055, glock(n, 0.6 - k * 0.06), -0.4 + 0.2 * k)
    tr.add(k * 0.055, celesta(n, 0.3, 0.4), 0.3 - 0.15 * k)
x = apply_reverb(tr.buf[: int(2.5 * SR)], 0.45, 2.2)
save(OUT + 'orb.wav', norm(x, 0.75))

# sparkle / magic (flower, beacon)
tr = Track(2.5)
for k in range(10):
    tr.add(k * 0.07 + r.uniform(0, 0.03), glock(midi('A6') + r.choice([0, 2, 4, 7, 9, 12]), 0.25), r.uniform(-0.7, 0.7))
x = apply_reverb(tr.buf[: int(2.5 * SR)], 0.55, 2.5)
save(OUT + 'sparkle.wav', norm(x, 0.6))

# prompt / ui blip
t = t_arr(0.12)
x = np.sin(2 * np.pi * 1320 * t) * np.exp(-t / 0.03) + 0.5 * np.sin(2 * np.pi * 1980 * t) * np.exp(-t / 0.02)
save(OUT + 'blip.wav', st(norm(x, 0.35)))
# dialog text blip (pixel)
t = t_arr(0.05)
x = np.where(((880 * t) % 1) < 0.5, 1.0, -1.0) * np.exp(-t / 0.02)
save(OUT + 'text.wav', st(norm(lp(x, 5000), 0.18)))
# robot mood beep-boop
x = np.concatenate([square('A5', 0.07, 0.5, 1.0), square('D6', 0.09, 0.5, 1.0)])
save(OUT + 'beep.wav', st(norm(x, 0.3)))

# rocket ignite: whoosh + boom
t = t_arr(2.0)
sweep = bp(r.standard_normal(len(t)), 200, 6000)
env = np.clip(t / 0.05, 0, 1) * np.exp(-t / 0.7)
boom = np.sin(2 * np.pi * (50 + 80 * np.exp(-t / 0.08)) * t) * np.exp(-t / 0.35)
x = lp(sweep, 4000) * env * 0.7 + boom
save(OUT + 'rocket_ignite.wav', st(norm(x, 0.85)))
# rocket loop: soft roar + crackle
t = t_arr(3.25)
n = r.standard_normal((len(t), 2))
roar = lp(n, 700) * 0.9 + bp(n, 1500, 4500) * 0.25
crack = (r.random((len(t), 2)) < 0.0015) * r.uniform(0.3, 1.0, (len(t), 2))
crack = bp(crack, 2000, 9000) * 2.0
x = (roar + crack) * (0.85 + 0.15 * np.sin(2 * np.pi * 7 * t))[:, None]
save(OUT + 'rocket_loop.wav', norm(loopify(x), 0.55))

# waterfall loop
t = t_arr(5.3)
n = r.standard_normal((len(t), 2))
x = lp(n, 1600) * 0.8 + bp(n, 2000, 7000) * 0.3
x *= (0.9 + 0.1 * np.sin(2 * np.pi * 0.31 * t))[:, None]
save(OUT + 'waterfall_loop.wav', norm(loopify(x, 0.4), 0.6))

# garden ambience: soft breeze + bird chirps
L = 24.0
t = t_arr(L)
n = r.standard_normal((len(t), 2))
breeze = bp(n, 250, 1800) * (0.5 + 0.5 * np.sin(2 * np.pi * 0.06 * t + 0.4))[:, None] * 0.25
tr = Track(L)
for k in range(14):
    t0 = r.uniform(0.5, L - 1.5)
    base = r.uniform(2600, 4200)
    for c in range(r.integers(2, 5)):
        tc = t_arr(0.09)
        f = base * (1 + 0.35 * np.sin(np.pi * tc / 0.09)) * r.uniform(0.95, 1.1)
        chirp = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * tc / 0.09) ** 2
        tr.add(t0 + c * r.uniform(0.11, 0.16), chirp * 0.12, r.uniform(-0.8, 0.8))
birds = apply_reverb(tr.buf, 0.35, 1.8)[: len(t)]
x = breeze + birds
save(OUT + 'garden_amb.wav', norm(loopify(x, 1.0), 0.35))

# splash
t = t_arr(1.2)
x = bp(r.standard_normal(len(t)), 400, 6000) * np.exp(-t / 0.18) * np.clip(t / 0.01, 0, 1) + np.sin(2 * np.pi * 110 * t) * np.exp(-t / 0.1) * 0.5
save(OUT + 'splash.wav', st(norm(x, 0.7)))

# whoosh (camera / transitions)
t = t_arr(1.4)
f_env = np.sin(np.pi * t / 1.4) ** 2
x = bp(r.standard_normal((len(t), 2)), 400, 3000) * f_env[:, None]
save(OUT + 'whoosh.wav', norm(x, 0.5))

# shimmer riser (into the painting / dream)
t = t_arr(3.0)
tr = Track(3.0)
for k in range(24):
    tr.add(k * 0.11, glock(midi('D6') + [0, 4, 7, 9, 12, 16][k % 6], 0.08 + k * 0.01), r.uniform(-0.8, 0.8))
x = tr.buf[: len(t)] + air(3.0, 0.08) * np.linspace(0, 1, len(t))[:, None]
x = apply_reverb(x, 0.6, 3.0)
save(OUT + 'riser.wav', norm(x, 0.6))
print('sfx done')
