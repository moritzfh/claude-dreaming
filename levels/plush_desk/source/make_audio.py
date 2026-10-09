"""The Plush Desk – original music and sound effects, made with the project's
tiny numpy synth (tools/audio/synth.py).

Music: a slow music-box waltz in D major (celesta melody, felt piano
oom-pah-pah, plucked bass, a soft pad; glockenspiel joins the second time).
Sounds: fabric squish, music-box twinkle, cardboard creak, the USB click,
the plug-in thunk, whooshes, a pop and a cardboard rustle.

Run from the repo root:  python3 levels/plush_desk/source/make_audio.py
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
R = np.random.default_rng(11)


def ogg(name, x, q=5):
    wav = os.path.join(TMP, name + '.wav')
    save(wav, x)
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', wav, '-c:a', 'libvorbis', '-q:a', str(q),
                    os.path.join(OUT, name + '.ogg')], check=True)
    print('wrote', name)


def mono(x):
    return np.stack([x, x], axis=1)


def norm(x, peak=0.8):
    return x / (np.abs(x).max() + 1e-9) * peak


# ------------------------------------------------------------------ music
BPM = 96.0
BEAT = 60.0 / BPM
BAR = BEAT * 3
CH = {
    'D': ['D3', 'F#3', 'A3'], 'Bm': ['B2', 'D3', 'F#3'], 'G': ['G2', 'B2', 'D3'], 'A': ['A2', 'C#3', 'E3'],
    'F#m': ['F#2', 'A2', 'C#3'], 'A7': ['A2', 'C#3', 'G3'], 'D/F#': ['F#2', 'A2', 'D3'], 'Em': ['E2', 'G2', 'B2'],
}
PROG = ['D', 'Bm', 'G', 'A', 'D', 'F#m', 'G', 'A7', 'Bm', 'G', 'D/F#', 'Em', 'G', 'A', 'D', 'D']
MEL = [
    [('F#5', 0, 1), ('A5', 1, 1), ('D6', 2, 1)],
    [('C#6', 0, 2), ('B5', 2, 1)],
    [('B5', 0, 1), ('A5', 1, 1), ('G5', 2, 1)],
    [('E5', 0, 3)],
    [('F#5', 0, 1), ('A5', 1, 1), ('F#6', 2, 1)],
    [('E6', 0, 1.5), ('C#6', 1.5, .5), ('A5', 2, 1)],
    [('B5', 0, 1), ('D6', 1, 1), ('G6', 2, 1)],
    [('F#6', 0, 2), ('E6', 2, 1)],
    [('D6', 0, 1), ('B5', 1, 1), ('F#5', 2, 1)],
    [('G5', 0, 1), ('B5', 1, 1), ('D6', 2, 1)],
    [('A5', 0, 1.5), ('F#5', 1.5, .5), ('A5', 2, 1)],
    [('G5', 0, 1), ('E5', 1, 1), ('B5', 2, 1)],
    [('D6', 0, 1), ('B5', 1, 1), ('G5', 2, 1)],
    [('A5', 0, 1), ('C#6', 1, 1), ('E6', 2, 1)],
    [('D6', 0, 3)],
    [('A5', 2, 1)],
]


def music():
    bars = len(PROG) * 2
    length = bars * BAR
    tr = Track(length)
    for rep in range(2):
        for b, chord in enumerate(PROG):
            t0 = (rep * len(PROG) + b) * BAR
            notes = CH[chord]
            # plucked bass on 1, felt piano chord on 2 and 3
            tr.add(t0, pluck(notes[0], 1.2, 0.55, 0.994), -0.1, 0.9)
            for k in (1, 2):
                for i, n in enumerate(notes[1:] + [midi(notes[0]) + 12]):
                    tr.add(t0 + k * BEAT + i * 0.012, piano(midi(n) + 12, BEAT * 0.8, 0.3, 0.3), 0.15, 0.32)
            if b % 4 == 0:
                tr.add(t0, pad([midi(n) + 12 for n in notes], BAR * 4, att=1.5, rel=2.5, cutoff=1500, vol=0.05), 0.0, 1.0)
            for n, st, du in MEL[b]:
                v = 0.55 if rep == 0 else 0.6
                tr.add(t0 + st * BEAT, celesta(n, du * BEAT, v), -0.2, 1.0)
                if rep == 1:
                    tr.add(t0 + st * BEAT, glock(midi(n) + 12, 0.22), 0.35, 1.0)
    x = make_loop(tr, length, wet=0.35, seconds=3.5)
    ogg('lullaby', master(x, 0.09), 4)


# ------------------------------------------------------------------ sfx
def squish():
    t = t_arr(0.22)
    n = R.standard_normal(len(t))
    x = lp(n, 900) * np.exp(-t / 0.05) * 0.8 + lp(n, 2500) * np.exp(-t / 0.02) * 0.3
    thump = np.sin(2 * np.pi * (90 - 40 * t) * t) * np.exp(-t / 0.04) * 0.6
    ogg('squish', mono(norm(x + thump, 0.7)))


def twinkle():
    a, b = celesta('C6', 0.6, 0.8), glock('C7', 0.2)
    n = min(len(a), len(b), int(1.6 * SR))
    ogg('twinkle', mono(norm(a[:n] + b[:n], 0.7)))


def creak():
    t = t_arr(0.45)
    out = np.zeros_like(t)
    pos = 0.0
    while pos < 0.4:
        i = int(pos * SR)
        k = np.zeros(400); k[0] = 1
        out[i:i + 400] += k * R.uniform(0.3, 1.0)
        pos += R.uniform(0.004, 0.02) * (1 + pos * 3)
    out = bp(out, 500, 3000) * 3 + bp(out, 1200, 1500) * 4
    out *= np.minimum(1, t / 0.03) * np.exp(-t / 0.25)
    ogg('creak', mono(norm(out, 0.6)))


def click():
    t = t_arr(0.3)
    x = hp(R.standard_normal(len(t)), 2500) * np.exp(-t / 0.004)
    x += np.sin(2 * np.pi * 3200 * t) * np.exp(-t / 0.03) * 0.25 + np.sin(2 * np.pi * 5100 * t) * np.exp(-t / 0.02) * 0.15
    x2 = np.zeros_like(x); d = int(0.035 * SR)
    x2[d:] = x[:-d] * 0.6
    ogg('click', mono(norm(x + x2, 0.7)))


def thunk():
    t = t_arr(0.6)
    body = np.sin(2 * np.pi * (70 + 60 * np.exp(-t / 0.03)) * t) * np.exp(-t / 0.12)
    fabric = lp(R.standard_normal(len(t)), 700) * np.exp(-t / 0.06) * 0.9
    snap = hp(R.standard_normal(len(t)), 3000) * np.exp(-t / 0.003) * 0.5
    ring = np.sin(2 * np.pi * 1850 * t) * np.exp(-t / 0.08) * 0.08
    ogg('thunk', mono(norm(body + fabric + snap + ring, 0.85)))


def whoosh(name, dur, f0, f1, vol=0.6):
    t = t_arr(dur)
    n = R.standard_normal(len(t))
    out = np.zeros_like(t)
    seg = 512
    for i in range(0, len(t), seg):
        k = i / len(t)
        fc = f0 + (f1 - f0) * k
        out[i:i + seg] = bp(n[max(0, i - 2048):i + seg], fc * 0.7, fc * 1.4)[-len(out[i:i + seg]):]
    env = np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 1.5
    ogg(name, mono(norm(out * env, vol)))


def pop():
    t = t_arr(0.35)
    x = np.sin(2 * np.pi * (300 + 900 * np.exp(-t / 0.02)) * t) * np.exp(-t / 0.05)
    x += hp(R.standard_normal(len(t)), 1500) * np.exp(-t / 0.01) * 0.4
    ogg('pop', mono(norm(x, 0.7)))


def rustle():
    t = t_arr(0.5)
    out = np.zeros_like(t)
    for _ in range(60):
        i = int(R.uniform(0, 0.38) * SR)
        L = int(R.uniform(0.005, 0.03) * SR)
        out[i:i + L] += R.standard_normal(L) * np.hanning(L) * R.uniform(0.2, 1.0)
    out = bp(out, 1500, 7000) + lp(out, 600) * 0.5
    thud = np.sin(2 * np.pi * 85 * t) * np.exp(-t / 0.06) * 0.5
    ogg('rustle', mono(norm(out * np.exp(-t / 0.3) + thud, 0.7)))


def wiggle():
    t = t_arr(0.5)
    out = np.zeros_like(t)
    for k in range(4):
        i = int(k * 0.11 * SR)
        L = int(0.07 * SR)
        out[i:i + L] += bp(R.standard_normal(L), 800 + k * 150, 3500) * np.hanning(L)
    ogg('wiggle', mono(norm(out, 0.5)))


def murmur():
    """the narrator's placeholder voice: one soft hummed syllable"""
    t = t_arr(0.16)
    f0 = 165.0
    ph = np.cumsum(f0 * (1.0 + 0.06 * np.sin(2 * np.pi * 7 * t))) / SR
    src = 2 * ((ph % 1.0) < 0.35) - 1.0
    v = bp(src, 300, 900) * 0.8 + bp(src, 1000, 1500) * 0.35 + bp(src, 2300, 2800) * 0.08
    env = np.sin(np.pi * np.clip(t / 0.16, 0, 1)) ** 1.5
    ogg('murmur', mono(norm(lp(v, 3000) * env, 0.5)))


def hum():
    """the sewing machine's motor and needle, a seamless 2 s loop"""
    dur = 2.0
    t = t_arr(dur)
    motor = np.zeros_like(t)
    for k, a in [(1, 1.0), (2, 0.5), (3, 0.35), (4, 0.2), (6, 0.1)]:
        motor += np.sin(2 * np.pi * 92.0 * k * t) * a
    motor *= 0.75 + 0.25 * np.sin(2 * np.pi * 4.0 * t)
    needle = np.zeros_like(t)
    for i in range(24):                 # 12 stitches per second
        j = int(i / 12.0 * SR)
        L = int(0.02 * SR)
        needle[j:j + L] += hp(R.standard_normal(L), 2500) * np.exp(-np.arange(L) / (0.003 * SR))
        L2 = int(0.05 * SR)
        k2 = np.arange(L2) / SR
        needle[j:j + L2] += np.sin(2 * np.pi * 180 * k2) * np.exp(-k2 / 0.012) * 0.5
    x = lp(motor, 1200) * 0.5 + needle * 0.6
    # cross-fade the end into the start so the loop is seamless
    f = int(0.05 * SR)
    x[:f] = x[:f] * np.linspace(0, 1, f) + x[-f:] * np.linspace(1, 0, f)
    ogg('hum', mono(norm(x[:-f], 0.6)))


def chime():
    tr = Track(3.0)
    for i, n in enumerate(['D6', 'F#6', 'A6', 'D7']):
        tr.add(i * 0.09, celesta(n, 0.8, 0.6), -0.3 + i * 0.2)
        tr.add(i * 0.09, glock(n, 0.25), 0.3 - i * 0.2)
    x = apply_reverb(tr.buf[: int(3.0 * SR)], 0.4, 2.5)
    ogg('chime', norm(x, 0.7))


if __name__ == '__main__':
    only = sys.argv[1:]
    if only:
        for n in only:
            globals()[n]()
        sys.exit(0)
    squish(); twinkle(); creak(); click(); thunk(); pop(); rustle(); wiggle(); chime(); murmur(); hum()
    whoosh('whoosh', 0.55, 400, 2200, 0.55)
    whoosh('swish', 0.35, 1800, 900, 0.35)
    whoosh('dive', 1.4, 300, 3500, 0.6)
    music()
