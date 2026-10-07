"""Stardust Islands – original music and sound effects, made with the
project's tiny numpy synth (tools/audio/synth.py).

A sweeping 3/4 waltz in F major: harp arpeggios, oom-pah-pah strings,
a singing string melody doubled by glockenspiel, choir in the middle part,
a lift for the reprise. Plus the level's sound effects.

Run from the repo root:  python3 levels/stardust/source/music.py
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

BPM = 168.0
BEAT = 60.0 / BPM
BAR = BEAT * 3

CH = {
    'F': ['F3', 'A3', 'C4', 'F4'], 'Bb': ['Bb2', 'D3', 'F3', 'Bb3'], 'Dm': ['D3', 'F3', 'A3', 'D4'],
    'Gm7': ['G2', 'Bb2', 'D3', 'F3'], 'C7': ['C3', 'E3', 'G3', 'Bb3'], 'Am': ['A2', 'C3', 'E3', 'A3'],
    'Bbm': ['Bb2', 'Db3', 'F3', 'Bb3'], 'F/C': ['C3', 'F3', 'A3', 'C4'], 'D7': ['D3', 'F#3', 'A3', 'C4'],
    'C': ['C3', 'E3', 'G3', 'C4'], 'Gm': ['G2', 'Bb2', 'D3', 'G3'], 'F7': ['F3', 'A3', 'C4', 'Eb4'],
    'Gb': ['Gb2', 'Bb2', 'Db3', 'Gb3'], 'Db': ['Db3', 'F3', 'Ab3', 'Db4'], 'Ebm7': ['Eb3', 'Gb3', 'Bb3', 'Db4'],
    'Ab7': ['Ab2', 'C3', 'Eb3', 'Gb3'],
}
A_PROG = ['F', 'F', 'Bb', 'F', 'Dm', 'Dm', 'Gm7', 'C7', 'F', 'Am', 'Bb', 'Bbm', 'F/C', 'D7', 'C7', 'F']
A_MEL = [
    [('C5', 0, 1), ('F5', 1, 1), ('A5', 2, 1)],
    [('C6', 0, 2), ('A5', 2, 1)],
    [('Bb5', 0, 1.5), ('A5', 1.5, .5), ('G5', 2, 1)],
    [('A5', 0, 3)],
    [('D5', 0, 1), ('F5', 1, 1), ('A5', 2, 1)],
    [('D6', 0, 2), ('C6', 2, 1)],
    [('Bb5', 0, 1), ('A5', 1, 1), ('G5', 2, 1)],
    [('G5', 0, 2), ('E5', 2, 1)],
    [('F5', 0, 1), ('A5', 1, 1), ('C6', 2, 1)],
    [('E6', 0, 2), ('C6', 2, 1)],
    [('D6', 0, 1.5), ('C6', 1.5, .5), ('Bb5', 2, 1)],
    [('Db6', 0, 2), ('Bb5', 2, 1)],
    [('A5', 0, 1), ('C6', 1, 1), ('F6', 2, 1)],
    [('F#5', 0, 1), ('A5', 1, 1), ('D6', 2, 1)],
    [('G5', 0, 1), ('Bb5', 1, 1), ('E5', 2, 1)],
    [('F5', 0, 3)],
]
B_PROG = ['Bb', 'C', 'Am', 'Dm', 'Gm', 'C', 'F', 'F7', 'Bb', 'C', 'Am', 'D7', 'Gm', 'Bbm', 'F/C', 'C7']
B_MEL = [
    [('D6', 0, 2), ('C6', 2, 1)],
    [('Bb5', 0, 2), ('A5', 2, 1)],
    [('A5', 0, 1), ('G5', 1, 1), ('E5', 2, 1)],
    [('F5', 0, 3)],
    [('G5', 0, 1), ('Bb5', 1, 1), ('D6', 2, 1)],
    [('E6', 0, 2), ('D6', 2, 1)],
    [('C6', 0, 3)],
    [('A5', 0, 1), ('C6', 1, 1), ('Eb6', 2, 1)],
    [('D6', 0, 2), ('F6', 2, 1)],
    [('E6', 0, 2), ('C6', 2, 1)],
    [('C6', 0, 1), ('A5', 1, 1), ('E5', 2, 1)],
    [('F#5', 0, 1), ('A5', 1, 1), ('C6', 2, 1)],
    [('Bb5', 0, 2), ('D6', 2, 1)],
    [('Db6', 0, 2), ('F5', 2, 1)],
    [('A5', 0, 1.5), ('G5', 1.5, .5), ('F5', 2, 1)],
    [('G5', 0, 1), ('C6', 1, 1), ('E6', 2, 1)],
]

def up(n, k=12): return midi(n) + k

# ---------------------------------------------------------------- instruments
def harp(n, dur=1.6, vel=0.5):
    """bright plucked string (Karplus-Strong, less damping than synth.pluck)"""
    f = hz(n); N = max(2, int(SR / f))
    L = int((dur + 0.3) * SR)
    y = np.zeros(L + N)
    y[:N] = rng.uniform(-1, 1, N) * np.hanning(N)
    damp = 0.9985 if f < 600 else 0.997
    for i in range(N, L + N - 1):
        y[i] = damp * 0.5 * (y[i - N] + y[i - N + 1])
    out = y[N:N + L]
    out = lp(out, 6000) + hp(out, 2000) * 0.15
    out[: int(0.002 * SR)] *= np.linspace(0, 1, int(0.002 * SR))
    return out * vel * 0.55

def pizz(n, vel=0.5):
    f = hz(n); t = t_arr(0.6)
    out = np.zeros_like(t)
    for k, a in [(1, 1.0), (2, 0.45), (3, 0.2), (4, 0.1)]:
        out += a * np.sin(2 * np.pi * f * k * t) * np.exp(-t / (0.22 / k ** 0.5))
    out += lp(rng.standard_normal(len(t)) * np.exp(-t / 0.004), 1500) * 0.3
    return out * vel * 0.5

def flute(n, dur, vel=0.5):
    f = hz(n); t = t_arr(dur + 0.4)
    vib = 1 + 0.006 * np.sin(2 * np.pi * 5.5 * t) * np.clip((t - 0.25) * 3, 0, 1)
    ph = np.cumsum(f * vib) / SR
    out = np.sin(2 * np.pi * ph) + 0.18 * np.sin(4 * np.pi * ph) + 0.06 * np.sin(6 * np.pi * ph)
    out += bp(rng.standard_normal(len(t)), f * 0.8, f * 3.0) * 0.06
    out *= env_adsr(len(t), 0.06, 0.1, 0.85, 0.25)
    return out * vel * 0.35

def brass(notes, dur, vel=0.4):
    out = None
    for n in notes:
        f = hz(n); t = t_arr(dur + 0.5)
        ph = np.cumsum(f * (1 + 0.003 * np.sin(2 * np.pi * 5 * t))) / SR
        s = 2 * ((ph + rng.random()) % 1.0) - 1
        env = env_adsr(len(t), 0.04, 0.2, 0.75, 0.4)
        s = lp(s, 2600) * env
        out = s if out is None else out + s
    return out * vel * 0.12

def timp(n, vel=0.6, dur=1.2):
    f = hz(n); t = t_arr(dur)
    out = np.sin(2 * np.pi * f * t * (1 + 0.04 * np.exp(-t / 0.05))) * np.exp(-t / 0.5)
    out += np.sin(2 * np.pi * f * 1.5 * t) * np.exp(-t / 0.25) * 0.3
    out += lp(rng.standard_normal(len(t)) * np.exp(-t / 0.02), 600) * 0.4
    return out * vel * 0.6

def roll(n, dur, vel=0.5):
    tr = np.zeros(int((dur + 1.2) * SR))
    k = 0
    while k * 0.055 < dur:
        v = vel * (0.3 + 0.7 * (k * 0.055 / dur))
        s = timp(n, v, 0.8)
        i = int(k * 0.055 * SR)
        tr[i:i + len(s)] += s[: len(tr) - i]
        k += 1
    return tr

def tri(vel=0.3):
    t = t_arr(1.6)
    out = sum(np.sin(2 * np.pi * f * t) * np.exp(-t / d) for f, d in [(4200, 0.8), (6100, 0.5), (8300, 0.3)])
    return out * vel * 0.12

def swell(dur, vel=0.2):
    t = t_arr(dur)
    return hp(rng.standard_normal(len(t)), 4000) * (t / dur) ** 2 * vel

def gliss(t0, tr, notes, step=0.035, vel=0.4, p=0.0):
    for i, n in enumerate(notes):
        tr.add(t0 + i * step, harp(n, 1.2, vel), p + 0.6 * (i / max(1, len(notes) - 1) - 0.5))

def scale_up(root='F4', count=14):
    steps = [0, 2, 4, 5, 7, 9, 11]
    r = midi(root)
    return [r + 12 * (i // 7) + steps[i % 7] for i in range(count)]

# ---------------------------------------------------------------- the theme
def theme():
    intro = 4
    sections = [('A', A_PROG, A_MEL, 0), ('B', B_PROG, B_MEL, 1), ('A2', A_PROG, A_MEL, 2)]
    bars = intro + sum(len(s[1]) for s in sections)
    length = bars * BAR
    tr = Track(length)
    # intro: shimmering harp glissandi over a soft pad + choir
    for b in range(intro):
        t0 = b * BAR
        tr.add(t0, pad(CH['F'] if b % 2 == 0 else CH['Bb'], BAR + 0.5, att=0.8, rel=1.5, cutoff=1800, vol=0.08), 0)
        gliss(t0, tr, scale_up('F4' if b % 2 == 0 else 'Bb4', 12), 0.05, 0.28)
    tr.add(0, choir(['A4', 'C5', 'F5'], intro * BAR, vol=0.05, att=2.0), 0)
    tr.add((intro - 1) * BAR, roll('C2', BAR, 0.45), 0)
    tr.add((intro - 1) * BAR, swell(BAR, 0.08), 0)
    bar = intro
    for name, prog, mel, sec in sections:
        for bi, ch in enumerate(prog):
            tones = CH[ch]
            t0 = bar * BAR
            root = tones[0]
            # oom: pizz bass (+ timpani on strong bars in the reprise)
            tr.add(t0, pizz(up(root, -12) if midi(root) > 45 else root, 0.55), -0.1)
            tr.add(t0, pizz(root, 0.3), 0.1)
            if sec == 2 and bi % 4 == 0: tr.add(t0, timp(up(root, -12) if midi(root) > 45 else root, 0.5), 0)
            # pah-pah
            for k in (1, 2):
                for n in tones[1:]:
                    tr.add(t0 + k * BEAT, strings(up(n, 12), BEAT * 0.4, 0.22, att=0.015, rel=0.15, cutoff=3800), 0.3 if k == 1 else -0.3)
            # harp: six rising eighths through two octaves
            arp = [tones[0], tones[1], tones[2], up(tones[1], 12), up(tones[2], 12), up(tones[3], 12)]
            for k, n in enumerate(arp):
                tr.add(t0 + k * BEAT * 0.5, harp(up(n, 12), 1.0, 0.22 + 0.04 * (k == 0)), 0.45 - 0.15 * (k % 3))
            # melody
            for (n, b, d) in mel[bi]:
                tt = t0 + b * BEAT
                if sec == 0:
                    tr.add(tt, strings(n, d * BEAT, 0.62, att=0.06, rel=0.4, cutoff=4200), -0.15)
                    tr.add(tt, glock(up(n, 12), 0.16), 0.35)
                elif sec == 1:
                    tr.add(tt, flute(up(n, 0), d * BEAT, 0.6), 0.2)
                    tr.add(tt, strings(up(n, -12), d * BEAT, 0.35, att=0.1, rel=0.5, cutoff=3000), -0.2)
                else:
                    tr.add(tt, strings(n, d * BEAT, 0.7, att=0.05, rel=0.4, cutoff=4800), -0.15)
                    tr.add(tt, strings(up(n, -12), d * BEAT, 0.42, att=0.05, rel=0.4, cutoff=3000), 0.15)
                    tr.add(tt, glock(up(n, 12), 0.2), 0.4)
            # colour per section
            if sec == 1:
                tr.add(t0, choir(tones[1:], BAR, vol=0.045, att=0.5, rel=1.0), 0)
            if sec == 2:
                tr.add(t0, brass([up(tones[1], 12), up(tones[2], 12)], BEAT * 0.9, 0.5), 0)
                tr.add(t0, choir([up(n, 12) for n in tones[1:3]], BAR, vol=0.04, att=0.4, rel=1.0), 0)
                if bi % 2 == 0: tr.add(t0, tri(0.4), 0.6)
            if bi == len(prog) - 1:
                gliss(t0 + BEAT, tr, scale_up('C5' if sec != 1 else 'F4', 10), 0.04, 0.3)
                tr.add(t0, roll('C2', BAR * 0.95, 0.35), 0)
                tr.add(t0, swell(BAR, 0.06), 0)
            bar += 1
    tr.buf[: int(length * SR)] += air(length, 0.008)
    return make_loop(tr, length, wet=0.32, seconds=2.6), length

# ---------------------------------------------------------------- effects
def sfx_all():
    out = {}
    # star bit: a bright bell "ting" (the game shifts the pitch up for combos)
    tr = Track(1.0)
    tr.add(0, glock('C6', 0.7), 0)
    tr.add(0.0, celesta('G6', 0.3, 0.3), 0.2)
    t = t_arr(0.25); tr.add(0, hp(rng.standard_normal(len(t)), 7000) * np.exp(-t / 0.03) * 0.15, 0)
    out['bit'] = tr.buf[: int(0.9 * SR)]
    # star chips: one rising note each, the fifth one completes the arpeggio
    notes = ['C6', 'E6', 'G6', 'C7', 'E7']
    for i in range(5):
        tr = Track(2.0)
        for k in range(i + 1):
            tr.add(k * 0.07, celesta(notes[k], 0.8, 0.5 + 0.08 * (k == i)), -0.4 + 0.2 * k)
            tr.add(k * 0.07, glock(up(notes[k], 12), 0.15), 0.3)
        out[f'chip_{i + 1}'] = tr.buf[: int(1.8 * SR)]
    # a launch star forms
    tr = Track(3.0)
    gliss(0, tr, scale_up('F5', 15), 0.03, 0.45)
    tr.add(0.45, choir(['F5', 'A5', 'C6'], 1.4, vol=0.12, att=0.1, rel=1.0), 0)
    for k, n in enumerate(['F6', 'A6', 'C7', 'F7']): tr.add(0.5 + k * 0.06, glock(n, 0.4), 0.2 * k - 0.3)
    out['star_appear'] = tr.buf[: int(2.8 * SR)]
    # launch: whoosh + spiralling rise
    L = 2.6; t = t_arr(L)
    f = 300 + 1500 * (t / L) ** 1.3
    tone = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 1.2) * 0.25
    tone *= 0.6 + 0.4 * np.sin(2 * np.pi * 14 * t)
    whoosh = bp(rng.standard_normal(len(t)), 500, 5000) * np.exp(-((t - 0.7) / 0.5) ** 2) * 0.6
    tr = Track(3.0)
    tr.add(0, tone + whoosh, 0)
    gliss(0.05, tr, scale_up('C5', 14), 0.025, 0.3)
    out['launch'] = tr.buf[: int(2.8 * SR)]
    # spin: short airy twirl
    L = 0.45; t = t_arr(L)
    x = bp(rng.standard_normal(len(t)), 1200, 6000) * np.sin(np.pi * t / L) ** 2 * (0.6 + 0.4 * np.sin(2 * np.pi * 22 * t))
    tr = Track(1.0); tr.add(0, x * 0.5, 0); tr.add(0.05, glock('E7', 0.12), 0.3)
    out['spin'] = tr.buf[: int(0.8 * SR)]
    # boing (spring flower)
    L = 0.7; t = t_arr(L)
    f = 220 * (1 + 0.9 * np.exp(-t / 0.08)) * (1 + 0.15 * np.sin(2 * np.pi * 9 * t) * np.exp(-t / 0.3))
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.25)
    out['boing'] = np.stack([x, x], 1) * 0.6
    # fanfare: the Dream Star
    tr = Track(7.0)
    tr.add(0, roll('F2', 1.0, 0.5), 0)
    gliss(0.0, tr, scale_up('F4', 15), 0.045, 0.4)
    seq = [(0.95, ['F4', 'A4', 'C5']), (1.25, ['G4', 'Bb4', 'D5']), (1.55, ['A4', 'C5', 'E5']), (1.85, ['F4', 'A4', 'C5', 'F5'])]
    for tt, notes in seq:
        tr.add(tt, brass(notes, 0.28 if tt < 1.8 else 2.6, 0.8), 0)
        tr.add(tt, strings(notes[-1], 0.28 if tt < 1.8 else 2.6, 0.5, att=0.02, rel=0.6), 0.2)
    tr.add(1.85, choir(['F4', 'A4', 'C5', 'F5'], 3.0, vol=0.14, att=0.2, rel=1.8), 0)
    tr.add(1.85, timp('F2', 0.8), 0)
    tr.add(1.85, tri(0.6), 0.5)
    for k, n in enumerate(['C6', 'F6', 'A6', 'C7', 'F7']): tr.add(1.9 + k * 0.08, glock(n, 0.4), 0.3 - 0.15 * k)
    gliss(2.0, tr, scale_up('F5', 14), 0.03, 0.3)
    out['fanfare'] = tr.buf[: int(6.5 * SR)]
    # double jump: an airy upward "fwip" with a bright bell on top
    L = 0.5; t = t_arr(L)
    f = 500 + 1400 * (t / L) ** 0.6
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.12) * 0.25
    air = bp(rng.standard_normal(len(t)), 1500, 7000) * np.sin(np.pi * np.clip(t / 0.25, 0, 1)) ** 2 * 0.25
    tr = Track(1.2); tr.add(0, x + air, 0); tr.add(0.04, glock('A6', 0.3), 0.2); tr.add(0.09, glock('E7', 0.2), -0.2)
    out['jump2'] = tr.buf[: int(0.9 * SR)]
    # triple jump: a quick rising three-note flourish and a sparkle
    tr = Track(1.6)
    for k, n in enumerate(['F5', 'A5', 'C6', 'F6']):
        tr.add(k * 0.055, celesta(n, 0.35, 0.45), -0.3 + 0.2 * k)
        tr.add(k * 0.055, glock(up(n, 12), 0.15), 0.3 - 0.2 * k)
    gliss(0.22, tr, scale_up('C6', 8), 0.022, 0.22)
    out['jump3'] = tr.buf[: int(1.3 * SR)]
    # falling into the void: a soft descending slide whistle, nothing harsh
    L = 1.3; t = t_arr(L)
    f = 620 * np.exp(-t * 1.1) + 150
    f = f * (1 + 0.02 * np.sin(2 * np.pi * 5.5 * t))
    env = np.minimum(1, t / 0.12) ** 2 * np.exp(-t / 0.7)
    x = (np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.1 * np.sin(4 * np.pi * np.cumsum(f) / SR)) * env * 0.3
    tr = Track(1.6); tr.add(0, x, 0)
    for k, n in enumerate(['C7', 'A6', 'F6', 'C6']): tr.add(0.05 + k * 0.11, glock(n, 0.08), 0.3 - 0.2 * k)
    out['fall'] = tr.buf[: int(1.5 * SR)]
    # reappearing at the checkpoint: a gentle shimmer
    tr = Track(1.6)
    tr.add(0, choir(['F5', 'A5', 'C6'], 0.8, vol=0.08, att=0.15, rel=0.6), 0)
    for k, n in enumerate(['C6', 'F6', 'A6', 'C7']): tr.add(0.05 + k * 0.07, celesta(n, 0.3, 0.3), 0.2 * k - 0.3)
    out['respawn'] = tr.buf[: int(1.4 * SR)]
    return out

def to_ogg(name, x, rev=0.15, rev_s=1.6, peak=0.85):
    if x.ndim == 1: x = np.stack([x, x], 1)
    if rev > 0: x = apply_reverb(np.vstack([x, np.zeros((int(rev_s * SR), 2))]), rev, rev_s)
    x = x / (np.abs(x).max() + 1e-9) * peak
    # trim the silent tail (the sfx players are pooled, short files free them sooner)
    env = np.abs(x).max(1)
    loud = np.where(env > 2e-3)[0]
    if len(loud): x = x[: min(len(x), loud[-1] + int(0.05 * SR))]
    wav = os.path.join(TMP, name + '.wav')
    save(wav, x)
    subprocess.run(['ffmpeg', '-loglevel', 'error', '-y', '-i', wav, '-c:a', 'libvorbis', '-q:a', '6', os.path.join(OUT, name + '.ogg')], check=True)

if __name__ == '__main__':
    which = sys.argv[1] if len(sys.argv) > 1 else 'all'
    only = sys.argv[2:]          # e.g. `music.py sfx fall jump2` renders just those
    if which in ('all', 'sfx'):
        for k, v in sfx_all().items():
            if only and k not in only: continue
            big = k in ('fanfare', 'star_appear', 'launch')
            to_ogg(k, v, rev=0.25 if big else 0.1, rev_s=1.6 if big else 0.6, peak=0.5 if k == 'fall' else 0.85)
            print('sfx', k)
    if which in ('all', 'music'):
        x, L = theme()
        x = master(x, 0.10)
        wav = os.path.join(TMP, 'stardust_theme.wav')
        save(wav, x)
        subprocess.run(['ffmpeg', '-loglevel', 'error', '-y', '-i', wav, '-c:a', 'libvorbis', '-q:a', '6', os.path.join(OUT, 'stardust_theme.ogg')], check=True)
        print('theme', round(L, 2), 's')
