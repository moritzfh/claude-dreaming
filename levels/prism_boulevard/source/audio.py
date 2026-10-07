"""Prism Boulevard – original music and sound effects, made with the
project's tiny numpy synth (tools/audio/synth.py).

The race theme is an upbeat space-disco track in E major, 136 BPM: four on
the floor, octave bass, offbeat chord stabs, a sparkling 16th arpeggio, a
bright synth lead (A), soaring strings and choir (B), and the lead again with
a harmony on top (A'). The final lap plays the same piece faster and a
semitone higher. Plus jingles (start, countdown, lap, final lap, finish,
win) and the kart sounds (engine and drift loops, hops, boosts …).

Run from the repo root:  python3 levels/prism_boulevard/source/audio.py [music|sfx|all] [names…]
(needs numpy, scipy, soundfile and ffmpeg on the PATH)
"""
import os, sys, subprocess
import numpy as np
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', '..', '..', 'tools', 'audio'))
from synth import *

OUT = os.path.join(HERE, '..', 'audio')
TMP = os.path.join(HERE, '_build')
os.makedirs(TMP, exist_ok=True)
os.makedirs(OUT, exist_ok=True)

def up(n, k=12): return midi(n) + k

# ---------------------------------------------------------------- drums
def kick(vel=0.9):
    t = t_arr(0.42)
    f = 46 + 120 * np.exp(-t / 0.035)
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.16)
    x += lp(rng.standard_normal(len(t)) * np.exp(-t / 0.004), 3000) * 0.25
    return np.tanh(x * 1.6) * vel * 0.8

def snare(vel=0.6):
    t = t_arr(0.3)
    body = np.sin(2 * np.pi * 190 * t) * np.exp(-t / 0.05) * 0.5
    nz = bp(rng.standard_normal(len(t)), 1200, 8000) * np.exp(-t / 0.09)
    return (body + nz) * vel * 0.5

def clap(vel=0.5):
    out = np.zeros(int(0.35 * SR))
    for k, d in enumerate([0.0, 0.011, 0.022]):
        t = t_arr(0.3)
        x = bp(rng.standard_normal(len(t)), 900, 5000) * np.exp(-t / (0.012 if k < 2 else 0.11))
        i = int(d * SR)
        out[i:i + len(x)] += x[: len(out) - i]
    return out * vel * 0.55

def hat(vel=0.25, open_=False):
    t = t_arr(0.35 if open_ else 0.08)
    x = hp(rng.standard_normal(len(t)), 7500) * np.exp(-t / (0.11 if open_ else 0.018))
    return x * vel * 0.5

def tom(n, vel=0.5):
    t = t_arr(0.5)
    f = hz(n) * (1 + 0.5 * np.exp(-t / 0.04))
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.18) * vel * 0.6

def crash(vel=0.3):
    t = t_arr(2.2)
    return hp(rng.standard_normal(len(t)), 4500) * np.exp(-t / 0.7) * vel * 0.4

def riser(dur, vel=0.25):
    t = t_arr(dur)
    nz = rng.standard_normal(len(t))
    lo = bp(nz, 300, 2000); hi = bp(nz, 2000, 9000)
    k = (t / dur) ** 2
    return (lo * (1 - k) + hi * k) * k * vel

# ---------------------------------------------------------------- synths
def saw(f, t, ph=0.0):
    return 2 * ((f * t + ph) % 1.0) - 1

def bass(n, dur, vel=0.6):
    f = hz(n); t = t_arr(dur + 0.08)
    x = saw(f, t) * 0.6 + np.where(((f * t) % 1.0) < 0.5, 1.0, -1.0) * 0.4
    bright = lp(x, 1400) * np.exp(-t / 0.08) + lp(x, 380)
    sub = np.sin(2 * np.pi * f * t) * 0.6
    env = env_adsr(len(t), 0.004, 0.08, 0.75, 0.05)
    return (bright * 0.7 + sub) * env * vel * 0.45

def lead(n, dur, vel=0.5, bright=5200):
    f = hz(n); t = t_arr(dur + 0.25)
    vib = 1 + 0.006 * np.sin(2 * np.pi * 5.6 * t) * np.clip((t - 0.18) * 4, 0, 1)
    ph = np.cumsum(f * vib) / SR
    x = (2 * ((ph) % 1.0) - 1) * 0.5 + np.where((ph * 1.003 % 1.0) < 0.42, 1.0, -1.0) * 0.4 + np.sin(2 * np.pi * ph * 2) * 0.15
    x = lp(x, bright, 2)
    env = env_adsr(len(t), 0.01, 0.15, 0.8, 0.22)
    return x * env * vel * 0.32

def stab(notes, dur=0.18, vel=0.4):
    t = t_arr(dur + 0.15)
    x = np.zeros_like(t)
    for n in notes:
        f = hz(n)
        for d in (-0.08, 0.08):
            x += saw(f * 2 ** (d / 12), t, rng.random())
    x = lp(x, 3200) * np.exp(-t / 0.11) + lp(x, 900) * np.exp(-t / 0.05)
    return x / len(notes) * vel * 0.5

def brass(notes, dur, vel=0.4):
    out = None
    for n in notes:
        f = hz(n); t = t_arr(dur + 0.5)
        ph = np.cumsum(f * (1 + 0.003 * np.sin(2 * np.pi * 5 * t))) / SR
        s = 2 * ((ph + rng.random()) % 1.0) - 1
        env = env_adsr(len(t), 0.03, 0.2, 0.75, 0.35)
        s = lp(s, 2800) * env
        out = s if out is None else out + s
    return out * vel * 0.12

def sparkle_run(tr, t0, root, count, step, vel=0.25, p=0.0, down=False):
    steps = [0, 2, 4, 5, 7, 9, 11]
    r = midi(root)
    notes = [r + 12 * (i // 7) + steps[i % 7] for i in range(count)]
    if down: notes = notes[::-1]
    for i, n in enumerate(notes):
        tr.add(t0 + i * step, celesta(n, 0.5, vel), p + 0.6 * (i / max(1, count - 1) - 0.5))

# ---------------------------------------------------------------- the theme
CH = {
    'E': ['E3', 'G#3', 'B3'], 'C#m': ['C#3', 'E3', 'G#3'], 'A': ['A2', 'C#3', 'E3'], 'B': ['B2', 'D#3', 'F#3'],
    'G#m': ['G#2', 'B2', 'D#3'], 'F#m': ['F#2', 'A2', 'C#3'], 'B7': ['B2', 'D#3', 'A3'], 'E/G#': ['G#2', 'B2', 'E3'],
    'Asus': ['A2', 'B2', 'E3'],
}
A_PROG = ['E', 'C#m', 'A', 'B', 'E', 'G#m', 'A', 'B', 'C#m', 'A', 'E', 'B', 'A', 'B', 'E', 'E']
A_MEL = [
    [('E5', 0, 1.5), ('F#5', 1.5, .5), ('G#5', 2, 1), ('B5', 3, 1)],
    [('C#6', 0, 1.5), ('B5', 1.5, .5), ('G#5', 2, 2)],
    [('A5', 0, 1), ('G#5', 1, .5), ('F#5', 1.5, .5), ('E5', 2, 1), ('C#5', 3, 1)],
    [('D#5', 0, 2), ('F#5', 2, 1), ('B5', 3, 1)],
    [('E5', 0, 1.5), ('F#5', 1.5, .5), ('G#5', 2, 1), ('B5', 3, 1)],
    [('D#6', 0, 1.5), ('C#6', 1.5, .5), ('B5', 2, 2)],
    [('C#6', 0, 1), ('B5', 1, .5), ('A5', 1.5, .5), ('G#5', 2, 1), ('F#5', 3, 1)],
    [('F#5', 0, 3)],
    [('G#5', 0, 1), ('B5', 1, 1), ('C#6', 2, 1.5), ('E6', 3.5, .5)],
    [('E6', 0, 1), ('D#6', 1, .5), ('C#6', 1.5, .5), ('B5', 2, 2)],
    [('G#5', 0, 1), ('B5', 1, 1), ('E6', 2, 1), ('G#6', 3, 1)],
    [('F#6', 0, 2), ('D#6', 2, 1), ('B5', 3, 1)],
    [('C#6', 0, 1.5), ('B5', 1.5, .5), ('A5', 2, 1), ('C#6', 3, 1)],
    [('D#6', 0, 1.5), ('C#6', 1.5, .5), ('B5', 2, 1), ('D#6', 3, 1)],
    [('E6', 0, 3.5)],
    [],
]
B_PROG = ['A', 'B', 'G#m', 'C#m', 'A', 'B', 'G#m', 'C#m', 'F#m', 'B', 'E', 'C#m', 'A', 'B', 'B7', 'B7']
B_MEL = [
    [('C#6', 0, 3), ('B5', 3, 1)],
    [('D#6', 0, 3), ('C#6', 3, 1)],
    [('B5', 0, 2), ('G#5', 2, 2)],
    [('E6', 0, 3), ('D#6', 3, 1)],
    [('C#6', 0, 2), ('E6', 2, 2)],
    [('F#6', 0, 2), ('D#6', 2, 2)],
    [('G#6', 0, 3), ('F#6', 3, 1)],
    [('E6', 0, 4)],
    [('A5', 0, 1), ('C#6', 1, 1), ('F#6', 2, 2)],
    [('F#6', 0, 1), ('E6', 1, 1), ('D#6', 2, 2)],
    [('G#5', 0, 1), ('B5', 1, 1), ('E6', 2, 2)],
    [('G#6', 0, 2), ('E6', 2, 2)],
    [('F#6', 0, 2), ('E6', 2, 1), ('C#6', 3, 1)],
    [('D#6', 0, 2), ('B5', 2, 2)],
    [('B5', 0, .5), ('C#6', .5, .5), ('D#6', 1, .5), ('E6', 1.5, .5), ('F#6', 2, .5), ('G#6', 2.5, .5), ('A6', 3, 1)],
    [('B6', 0, 3.5)],
]
# a third below the A melody for the reprise (in E major)
SCALE = [midi(n) for n in ['E3', 'F#3', 'G#3', 'A3', 'B3', 'C#4', 'D#4']]
def third_below(n):
    m = midi(n)
    pcs = [s % 12 for s in SCALE]
    deg = pcs.index(int(m) % 12) if int(m) % 12 in pcs else 0
    lower = pcs[(deg - 2) % 7]
    d = (int(m) % 12 - lower) % 12
    return m - d

def theme(bpm=136.0, transpose=0):
    BEAT = 60.0 / bpm
    BAR = BEAT * 4
    tp = lambda n: midi(n) + transpose
    intro = 4
    sections = [('A', A_PROG, A_MEL, 0), ('B', B_PROG, B_MEL, 1), ('A2', A_PROG, A_MEL, 2)]
    bars = intro + sum(len(s[1]) for s in sections)
    length = bars * BAR
    tr = Track(length)
    # ---- intro: filtered pulse, arps and a riser
    for b in range(intro):
        t0 = b * BAR
        ch = CH['E' if b % 2 == 0 else 'A']
        for k in range(16):
            n = [ch[0], ch[1], ch[2], up(ch[1], 12)][k % 4]
            tr.add(t0 + k * BEAT / 4, celesta(tp(up(n, 24)), 0.25, 0.16 + 0.04 * (b / intro)), 0.4 if k % 2 else -0.4)
        tr.add(t0, pad([tp(n) for n in ch] + [tp(up(ch[0], 12))], BAR + 0.4, att=0.5, rel=1.0, cutoff=900 + 500 * b, vol=0.09), 0)
        for k in range(4):
            tr.add(t0 + k * BEAT, kick(0.5 if b < 2 else 0.75), 0)
            if b >= 2: tr.add(t0 + k * BEAT + BEAT / 2, hat(0.18, True), 0.2)
    tr.add((intro - 2) * BAR, riser(BAR * 2, 0.22), 0)
    for k, n in enumerate(['B3', 'B3', 'B3', 'B3', 'D#4', 'D#4', 'F#4', 'F#4']):
        tr.add((intro - 1) * BAR + k * BEAT / 2, tom(tp(up(n, -12)), 0.5 + 0.05 * k), 0.3 - 0.08 * k)
    bar = intro
    for name, prog, mel, sec in sections:
        for bi, ch_name in enumerate(prog):
            ch = CH[ch_name]
            t0 = bar * BAR
            root = tp(ch[0])
            last = bi == len(prog) - 1
            # drums: four on the floor, clap on 2 & 4, open hats on the off-beats, 16th shaker
            for k in range(4):
                tr.add(t0 + k * BEAT, kick(0.85), 0)
                tr.add(t0 + k * BEAT + BEAT / 2, hat(0.22, True), 0.25)
                for q in (1, 3):
                    tr.add(t0 + k * BEAT + q * BEAT / 4, hat(0.09), -0.3)
            for k in (1, 3):
                tr.add(t0 + k * BEAT, clap(0.55), 0)
                tr.add(t0 + k * BEAT, snare(0.25), 0)
            if bi == 0: tr.add(t0, crash(0.3), 0.3)
            if last:
                for k in range(8):
                    tr.add(t0 + 2 * BEAT + k * BEAT / 4, tom(tp(['E3', 'D#3', 'B2', 'A2', 'G#2', 'F#2', 'E2', 'E2'][k]), 0.45), -0.4 + 0.1 * k)
            # octave disco bass on eighths
            for k in range(8):
                n = root - 12 if k % 2 == 0 else root
                tr.add(t0 + k * BEAT / 2, bass(n, BEAT / 2 * 0.9, 0.65), 0)
            # off-beat chord stabs (+ sustained pad underneath)
            for k in range(4):
                tr.add(t0 + k * BEAT + BEAT / 2, stab([tp(up(n, 12)) for n in ch], 0.16, 0.42), -0.15)
            tr.add(t0, pad([tp(up(n, 12)) for n in ch], BAR, att=0.2, rel=0.6, cutoff=1600, vol=0.045), 0)
            # sparkling 16th arpeggio
            arp = [ch[0], ch[1], ch[2], up(ch[0], 12), up(ch[1], 12), up(ch[2], 12), up(ch[0], 12), ch[2]]
            for k in range(16):
                n = tp(up(arp[k % 8], 24))
                tr.add(t0 + k * BEAT / 4, celesta(n, 0.2, 0.12 + 0.05 * (k % 4 == 0)), 0.5 if k % 2 else -0.5)
            # melody
            for (n, b, d) in mel[bi]:
                tt = t0 + b * BEAT
                dur = d * BEAT
                if sec == 0:
                    tr.add(tt, lead(tp(n), dur, 0.62), -0.1)
                    tr.add(tt, glock(tp(up(n, 12)), 0.1), 0.35)
                elif sec == 1:
                    tr.add(tt, strings(tp(n), dur, 0.75, att=0.08, rel=0.5, cutoff=4500), -0.15)
                    tr.add(tt, strings(tp(up(n, -12)), dur, 0.45, att=0.1, rel=0.5, cutoff=3000), 0.15)
                    tr.add(tt, glock(tp(up(n, 12)), 0.14), 0.4)
                else:
                    tr.add(tt, lead(tp(n), dur, 0.66, bright=6500), -0.1)
                    tr.add(tt, lead(third_below(n) + transpose, dur, 0.38), 0.25)
                    tr.add(tt, strings(tp(n), dur, 0.35, att=0.05, rel=0.4, cutoff=5000), 0.0)
                    tr.add(tt, glock(tp(up(n, 12)), 0.12), 0.4)
            # colour
            if sec == 1:
                tr.add(t0, choir([tp(up(n, 12)) for n in ch[1:]], BAR, vol=0.05, att=0.4, rel=1.0), 0)
                if bi % 4 == 0: sparkle_run(tr, t0 + 2 * BEAT, tp(up(ch[0], 24)), 8, BEAT / 8, 0.16, 0.3)
            if sec == 2 and bi % 2 == 0:
                tr.add(t0, brass([tp(up(n, 12)) for n in ch[1:]], BEAT * 0.8, 0.5), 0)
            if last:
                tr.add(t0, riser(BAR, 0.18), 0)
                sparkle_run(tr, t0 + 2 * BEAT, tp('E6'), 14, BEAT / 7, 0.2, 0.0)
            bar += 1
    tr.buf[: int(length * SR)] += air(length, 0.006)
    return make_loop(tr, length, wet=0.22, seconds=2.0), length

# ---------------------------------------------------------------- jingles
def fanfare(chords, beat, tail_notes, big=False):
    tr = Track(8.0)
    t = 0.0
    for k, (notes, beats) in enumerate(chords):
        last = k == len(chords) - 1
        dur = beat * beats
        tr.add(t, brass(notes, dur if not last else dur + 1.0, 0.85), 0)
        tr.add(t, lead(notes[-1] if isinstance(notes[-1], str) else notes[-1], dur if not last else dur + 0.8, 0.55, 6500), -0.15)
        tr.add(t, kick(0.6), 0)
        if last:
            tr.add(t, crash(0.35), 0.2)
            tr.add(t, choir(notes, 2.0 if big else 1.2, vol=0.12, att=0.08, rel=1.4), 0)
            for i, n in enumerate(tail_notes):
                tr.add(t + 0.05 + i * 0.06, glock(n, 0.3), 0.4 - 0.15 * i)
        t += dur
    return tr.buf[: int((t + (3.0 if big else 2.0)) * SR)]

def jingles():
    out = {}
    b = 60 / 136
    out['fanfare_start'] = fanfare([(['B3', 'D#4', 'F#4'], 0.5), (['B3', 'D#4', 'F#4'], 0.5), (['C#4', 'E4', 'A4'], 1), (['E4', 'G#4', 'B4', 'E5'], 2)], b, ['E6', 'G#6', 'B6', 'E7'])
    # countdown beeps: soft, round
    t = t_arr(0.45)
    beep = (np.sin(2 * np.pi * 660 * t) + 0.3 * np.sin(2 * np.pi * 1320 * t)) * np.exp(-t / 0.18) * env_adsr(len(t), 0.004, 0, 1, 0.05)
    out['count'] = np.stack([beep, beep], 1) * 0.6
    t = t_arr(1.2)
    go = (np.sin(2 * np.pi * 1320 * t) + 0.35 * np.sin(2 * np.pi * 2640 * t)) * np.exp(-t / 0.5) * env_adsr(len(t), 0.004, 0, 1, 0.1)
    tr = Track(2.0)
    tr.add(0, go * 0.6, 0)
    tr.add(0, riser(0.6, 0.12)[::-1], 0)
    for k, n in enumerate(['E6', 'B6', 'E7']): tr.add(0.03 * k, glock(n, 0.3), 0.3 * k - 0.3)
    out['go'] = tr.buf[: int(1.5 * SR)]
    # lap: a quick bright run
    tr = Track(2.0)
    for k, n in enumerate(['E5', 'G#5', 'B5', 'E6']):
        tr.add(k * 0.07, lead(n, 0.12 if k < 3 else 0.5, 0.55, 6500), 0)
        tr.add(k * 0.07, glock(up(n, 12), 0.2), 0.3)
    out['lap'] = tr.buf[: int(1.6 * SR)]
    # final lap: urgent rising fanfare
    tr = Track(3.0)
    for k, n in enumerate(['B4', 'C#5', 'D#5', 'E5', 'F#5', 'G#5', 'A#5', 'B5']):
        tr.add(k * 0.09, lead(n, 0.1, 0.5, 6500), 0)
    tr.add(0.75, brass(['B3', 'D#4', 'F#4', 'B4'], 0.9, 0.9), 0)
    tr.add(0.75, crash(0.3), 0)
    for k in range(6): tr.add(k * 0.12, tom(['B2', 'B2', 'D#3', 'D#3', 'F#3', 'B3'][k], 0.5), 0)
    out['final_lap'] = tr.buf[: int(2.4 * SR)]
    out['finish'] = fanfare([(['E4', 'G#4', 'B4'], 0.5), (['F#4', 'A4', 'C#5'], 0.5), (['G#4', 'B4', 'D#5'], 0.5), (['E4', 'G#4', 'B4', 'E5'], 2.5)], b, ['B5', 'E6', 'G#6', 'B6'])
    win = fanfare([(['B3', 'D#4', 'F#4'], 0.5), (['C#4', 'E4', 'G#4'], 0.5), (['D#4', 'F#4', 'B4'], 0.5), (['E4', 'G#4', 'B4'], 1.0),
                   (['C#4', 'E4', 'A4'], 0.5), (['D#4', 'F#4', 'B4'], 0.5), (['E4', 'G#4', 'B4', 'E5'], 3.0)], b, ['E6', 'G#6', 'B6', 'E7', 'G#7'], big=True)
    tr = Track(9.0)
    tr.add(0, win, 0)
    sparkle_run(tr, 2.2, 'E5', 22, 0.035, 0.22, 0.0)
    out['win'] = tr.buf[: int(7.5 * SR)]
    return out

# ---------------------------------------------------------------- sound effects
def periodic_noise(seconds, lo, hi):
    n = rng.standard_normal(int(seconds * SR))
    x = np.tile(n, 3)
    x = bp(x, lo, hi)
    return x[len(n):2 * len(n)]

def sfx_all():
    out = {}
    # engine: a dreamy hover-engine hum, exactly one second, loops seamlessly
    L = 1.0
    t = t_arr(L)
    f0 = 72
    x = saw(f0, t) * 0.35 + np.sin(2 * np.pi * f0 * 2 * t) * 0.3 + np.sin(2 * np.pi * f0 * 1.5 * t) * 0.15
    x = x * (1 + 0.25 * np.sin(2 * np.pi * 24 * t))
    x3 = np.tile(x, 3)
    x3 = lp(x3, 1800)
    eng = x3[len(x):2 * len(x)] * 0.9 + periodic_noise(L, 200, 1500) * 0.12
    out['engine'] = np.stack([eng, eng], 1)
    # drift: tyre hiss with a wobbling whistle on top (loops)
    hiss = periodic_noise(L, 1800, 6500) * 0.7
    whistle = np.sin(2 * np.pi * 1100 * t + 3 * np.sin(2 * np.pi * 6 * t)) * 0.12
    dr = (hiss + whistle) * (0.85 + 0.15 * np.sin(2 * np.pi * 13 * t))
    out['drift'] = np.stack([dr, dr * 0.95], 1)
    # hop
    L = 0.25; t = t_arr(L)
    f = 380 + 500 * (t / L)
    hop = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.07) * 0.5
    out['hop'] = hop
    # landing thump
    t = t_arr(0.35)
    land = np.sin(2 * np.pi * np.cumsum(90 + 80 * np.exp(-t / 0.03)) / SR) * np.exp(-t / 0.08) + lp(rng.standard_normal(len(t)), 900) * np.exp(-t / 0.05) * 0.5
    out['land'] = land * 0.8
    # mini-turbo charge levels: rising pings
    for lvl, notes in [(1, ['B5', 'E6']), (2, ['C#6', 'G#6']), (3, ['E6', 'B6', 'E7'])]:
        tr = Track(1.2)
        for k, n in enumerate(notes):
            tr.add(k * 0.05, glock(n, 0.4), 0.2 * k - 0.2)
            tr.add(k * 0.05, celesta(up(n, -12), 0.2, 0.25), 0)
        out['mt_%d' % lvl] = tr.buf[: int(0.8 * SR)]
    # turbo: a whoosh with a bright burst
    L = 0.9; t = t_arr(L)
    w = bp(rng.standard_normal(len(t)), 600, 7000) * np.exp(-((t - 0.12) / 0.18) ** 2)
    f = 200 + 900 * np.exp(-t / 0.25)
    tone = saw(1, 0) if False else np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.3) * 0.4
    out['turbo'] = (w * 0.8 + tone) * 0.8
    # boost pad: a quick "zzhwip" upwards
    L = 0.7; t = t_arr(L)
    f = 300 + 1600 * (t / L) ** 0.7
    tone = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.25) * 0.35
    w = bp(rng.standard_normal(len(t)), 1500, 8000) * np.sin(np.pi * np.clip(t / 0.4, 0, 1)) ** 2 * 0.5
    tr = Track(1.2)
    tr.add(0, tone + w, 0)
    tr.add(0.08, glock('E7', 0.18), 0.3)
    out['pad'] = tr.buf[: int(0.9 * SR)]
    # ramp + glider
    L = 0.8; t = t_arr(L)
    out['ramp'] = bp(rng.standard_normal(len(t)), 400, 5000) * np.sin(np.pi * t / L) ** 2 * 0.7
    tr = Track(2.0)
    L = 1.2; t = t_arr(L)
    flap = bp(rng.standard_normal(len(t)), 300, 3000) * (np.exp(-t / 0.08) + 0.3 * np.exp(-((t - 0.15) / 0.1) ** 2)) * 0.8
    tr.add(0, flap, 0)
    sparkle_run(tr, 0.05, 'E6', 8, 0.035, 0.25, 0.0)
    out['glider'] = tr.buf[: int(1.4 * SR)]
    # trick: a sparkly "ta-da"
    tr = Track(1.5)
    for k, n in enumerate(['G#6', 'B6', 'E7']):
        tr.add(k * 0.06, celesta(n, 0.3, 0.45), 0.25 * k - 0.25)
    tr.add(0, bp(rng.standard_normal(int(0.3 * SR)), 2000, 8000) * np.exp(-t_arr(0.3) / 0.08) * 0.3, 0)
    out['trick'] = tr.buf[: int(1.1 * SR)]
    # bump
    t = t_arr(0.3)
    bump = lp(rng.standard_normal(len(t)), 1200) * np.exp(-t / 0.04) * 0.8 + np.sin(2 * np.pi * 120 * t) * np.exp(-t / 0.06) * 0.6
    out['bump'] = bump
    # falling + rescue
    L = 1.4; t = t_arr(L)
    f = 900 * np.exp(-t * 1.2) + 140
    env = np.minimum(1, t / 0.08) ** 2 * np.exp(-t / 0.8)
    out['fall'] = np.sin(2 * np.pi * np.cumsum(f) / SR) * env * 0.4
    tr = Track(1.8)
    tr.add(0, choir(['E5', 'G#5', 'B5'], 0.8, vol=0.09, att=0.12, rel=0.6), 0)
    sparkle_run(tr, 0.05, 'B5', 7, 0.05, 0.28, 0.0)
    out['rescue'] = tr.buf[: int(1.5 * SR)]
    # star bit + ring
    tr = Track(1.0)
    tr.add(0, glock('E6', 0.6), 0)
    tr.add(0.0, celesta('B6', 0.3, 0.3), 0.2)
    out['bit'] = tr.buf[: int(0.8 * SR)]
    tr = Track(2.0)
    for k, n in enumerate(['E6', 'G#6', 'B6', 'E7']):
        tr.add(k * 0.045, glock(n, 0.35), 0.25 * k - 0.4)
    tr.add(0, choir(['E5', 'B5', 'E6'], 0.6, vol=0.07, att=0.05, rel=0.6), 0)
    out['ring'] = tr.buf[: int(1.4 * SR)]
    # firework: pop + crackle
    tr = Track(2.5)
    t = t_arr(0.4)
    tr.add(0, lp(rng.standard_normal(len(t)), 700) * np.exp(-t / 0.06) * 0.9, 0)
    for k in range(18):
        tt = 0.25 + rng.random() * 1.2
        tr.add(tt, hp(rng.standard_normal(int(0.02 * SR)), 3000) * 0.25 * rng.random(), rng.uniform(-0.8, 0.8))
    out['firework'] = tr.buf[: int(1.8 * SR)]
    return out

def to_ogg(name, x, rev=0.12, rev_s=0.8, peak=0.85, loop=False):
    if x.ndim == 1: x = np.stack([x, x], 1)
    if rev > 0 and not loop: x = apply_reverb(np.vstack([x, np.zeros((int(rev_s * SR), 2))]), rev, rev_s)
    x = x / (np.abs(x).max() + 1e-9) * peak
    if not loop:
        env = np.abs(x).max(1)
        loud = np.where(env > 2e-3)[0]
        if len(loud): x = x[: min(len(x), loud[-1] + int(0.05 * SR))]
    wav = os.path.join(TMP, name + '.wav')
    save(wav, x)
    subprocess.run(['ffmpeg', '-loglevel', 'error', '-y', '-i', wav, '-c:a', 'libvorbis', '-q:a', '5', os.path.join(OUT, name + '.ogg')], check=True)

if __name__ == '__main__':
    which = sys.argv[1] if len(sys.argv) > 1 else 'all'
    only = sys.argv[2:]
    if which in ('all', 'sfx'):
        items = list(sfx_all().items()) + list(jingles().items())
        for k, v in items:
            if only and k not in only: continue
            lp_ = k in ('engine', 'drift')
            big = k in ('fanfare_start', 'finish', 'win', 'final_lap')
            to_ogg(k, v, rev=0.0 if lp_ else (0.25 if big else 0.1), rev_s=1.6 if big else 0.6,
                   peak={'engine': 0.5, 'drift': 0.45, 'fall': 0.5}.get(k, 0.85), loop=lp_)
            print('sfx', k)
    if which in ('all', 'music'):
        for name, bpm, tpz in [('race', 136.0, 0), ('race_fast', 150.0, 1)]:
            if only and name not in only: continue
            x, L = theme(bpm, tpz)
            x = master(x, 0.11)
            wav = os.path.join(TMP, name + '.wav')
            save(wav, x)
            subprocess.run(['ffmpeg', '-loglevel', 'error', '-y', '-i', wav, '-c:a', 'libvorbis', '-q:a', '5', os.path.join(OUT, name + '.ogg')], check=True)
            print('music', name, round(L, 2), 's')
