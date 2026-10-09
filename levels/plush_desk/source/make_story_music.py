"""Music for "First Stitches", the world inside the STORY planet – all
original, composed note by note here and rendered with the project's tiny
numpy synth (tools/audio/synth.py).

  story.ogg    the theme: a strummed ukulele, glockenspiel and a whistled
               second half, claps and a shaker (G major, 116 BPM)
  chase.ogg    the sewing machine chase: staccato strings, woodblock
               tick-tock, pizzicato bass (E minor, 150 BPM)
  tower.ogg    the yarn tower: rising celesta arpeggios, strings (D major)
  finale.ogg   the little theatre: a music-box waltz (C major, 3/4)
  quilt.ogg    the quilt: slow piano and music box (F major, 68 BPM)
  fanfare.ogg  curtains up: a snare roll and a bright chord (one shot)

Run from the repo root:  python3 levels/plush_desk/source/make_story_music.py [name …]
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
R = np.random.default_rng(23)


def ogg(name, x, q=4):
    wav = os.path.join(TMP, name + '.wav')
    save(wav, x)
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', wav, '-c:a', 'libvorbis', '-q:a', str(q),
                    os.path.join(OUT, name + '.ogg')], check=True)
    print('wrote', name, '%.1f s' % (len(x) / SR))


# ------------------------------------------------------------------ drums
def kick(vel=0.8):
    t = t_arr(0.35)
    f = 45 + 80 * np.exp(-t / 0.03)
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.12)
    x += lp(R.standard_normal(len(t)), 1800) * np.exp(-t / 0.004) * 0.3
    return x * vel


def clap(vel=0.5):
    t = t_arr(0.3)
    x = np.zeros_like(t)
    for k, d in enumerate([0.0, 0.011, 0.022]):
        i = int(d * SR)
        n = R.standard_normal(len(t) - i)
        x[i:] += n * np.exp(-np.arange(len(t) - i) / SR / (0.008 if k < 2 else 0.07))
    x = bp(x, 900, 5000)
    return x * vel * 0.6


def snare(vel=0.5):
    t = t_arr(0.25)
    x = bp(R.standard_normal(len(t)), 1500, 7000) * np.exp(-t / 0.07)
    x += np.sin(2 * np.pi * 190 * t) * np.exp(-t / 0.04) * 0.6
    return x * vel * 0.6


def shaker(vel=0.25):
    t = t_arr(0.08)
    x = hp(R.standard_normal(len(t)), 6000) * np.minimum(1, t / 0.012) * np.exp(-t / 0.025)
    return x * vel


def woodblock(f=820.0, vel=0.4):
    t = t_arr(0.12)
    x = np.sin(2 * np.pi * f * t) * np.exp(-t / 0.03) + 0.4 * np.sin(2 * np.pi * f * 2.71 * t) * np.exp(-t / 0.012)
    return x * vel


def crash(vel=0.3, dur=2.2):
    t = t_arr(dur)
    x = hp(R.standard_normal(len(t)), 4500) * np.exp(-t / (dur / 4.5))
    return x * vel


def whistle(n, dur, vel=0.5):
    """a whistled note: a pure tone with breath and a little vibrato"""
    f = hz(n)
    L = dur + 0.12
    t = t_arr(L)
    vib = 1 + 0.006 * np.sin(2 * np.pi * 5.6 * t) * np.clip((t - 0.12) * 4, 0, 1)
    ph = np.cumsum(f * vib) / SR
    x = np.sin(2 * np.pi * ph) + 0.06 * np.sin(4 * np.pi * ph)
    x += bp(R.standard_normal(len(t)), f * 0.8, f * 1.3) * 0.12
    x *= env_adsr(len(t), 0.035, 0.05, 0.85, 0.1)
    return x * vel * 0.32


def strum(tr, t0, notes, down=True, vel=0.32, dur=0.5, p=0.0, damp=0.992):
    seq = notes if down else list(reversed(notes))
    for i, n in enumerate(seq):
        v = vel * (1.0 if down else 0.65) * (0.85 + 0.3 * R.random())
        tr.add(t0 + i * 0.011, pluck(n, dur, v, damp), p + (i - 1.5) * 0.08, 1.0)


def mel(tr, t0, beat, notes, inst, p=0.0, gain=1.0, transpose=0):
    for n, st, du in notes:
        tr.add(t0 + st * beat, inst(midi(n) + transpose, du * beat), p, gain)


# ------------------------------------------------------------------ story theme
UKE = {'G': ['G4', 'B4', 'D5', 'G5'], 'D': ['F#4', 'A4', 'D5', 'F#5'], 'Em': ['G4', 'B4', 'E5', 'G5'],
       'C': ['G4', 'C5', 'E5', 'G5'], 'Am': ['A4', 'C5', 'E5', 'A5'], 'A7': ['G4', 'C#5', 'E5', 'A5'],
       'D/F#': ['F#4', 'A4', 'D5', 'F#5']}
BASS = {'G': ('G2', 'D3'), 'D': ('D2', 'A2'), 'Em': ('E2', 'B2'), 'C': ('C3', 'G2'), 'Am': ('A2', 'E3'),
        'A7': ('A2', 'E3'), 'D/F#': ('F#2', 'A2')}

MEL_A = [
    [('D5', 0, .5), ('G5', .5, .5), ('A5', 1, .5), ('B5', 1.5, 1), ('A5', 2.5, .5), ('G5', 3, 1)],
    [('F#5', 0, .5), ('A5', .5, .5), ('D6', 1, 1), ('C#6', 2, .5), ('A5', 2.5, .5), ('F#5', 3, 1)],
    [('G5', 0, .5), ('B5', .5, .5), ('E6', 1, 1.5), ('D6', 2.5, .5), ('B5', 3, 1)],
    [('C6', 0, 1), ('B5', 1, .5), ('A5', 1.5, .5), ('G5', 2, 1), ('E5', 3, 1)],
    [('D5', 0, .5), ('G5', .5, .5), ('A5', 1, .5), ('B5', 1.5, 1), ('D6', 2.5, .5), ('B5', 3, 1)],
    [('A5', 0, .5), ('F#5', .5, .5), ('A5', 1, .5), ('D6', 1.5, 1), ('E6', 2.5, .5), ('F#6', 3, 1)],
    [('G6', 0, 1), ('E6', 1, .5), ('C6', 1.5, .5), ('E6', 2, 1), ('D6', 3, .5), ('C6', 3.5, .5)],
    [('B5', 0, 1), ('A5', 1, 1), ('F#5', 2, .5), ('G5', 2.5, .5), ('A5', 3, 1)],
]
MEL_B = [
    [('E5', 0, 1.5), ('G5', 1.5, .5), ('C6', 2, 1), ('B5', 3, 1)],
    [('B5', 0, 1), ('A5', 1, .5), ('G5', 1.5, .5), ('D5', 2, 2)],
    [('E5', 0, 1), ('A5', 1, 1), ('C6', 2, 1), ('B5', 3, .5), ('A5', 3.5, .5)],
    [('B5', 0, 2), ('G5', 2, 1), ('E5', 3, 1)],
    [('E5', 0, 1.5), ('G5', 1.5, .5), ('C6', 2, 1), ('E6', 3, 1)],
    [('D6', 0, 1), ('B5', 1, .5), ('G5', 1.5, .5), ('D6', 2, 2)],
    [('C#6', 0, 1), ('E6', 1, 1), ('G6', 2, 1), ('E6', 3, 1)],
    [('F#6', 0, 2), ('E6', 2, .5), ('D6', 2.5, .5), ('C#6', 3, .5), ('A5', 3.5, .5)],
]


def story():
    bpm = 116.0
    b = 60.0 / bpm
    bar = 4 * b
    A = ['G', 'D', 'Em', 'C', 'G', 'D', 'C', 'D']
    B = ['C', 'G', 'Am', 'Em', 'C', 'G', 'A7', 'D']
    BR = ['Em', 'C', 'G', 'D']
    form = [('A', A, MEL_A), ('B', B, MEL_B), ('A2', A, MEL_A), ('BR', BR, None)]
    bars = sum(len(f[1]) for f in form)
    length = bars * bar
    tr = Track(length)
    k = 0
    for sec, chords, melody in form:
        for i, ch in enumerate(chords):
            t0 = k * bar
            # ukulele: D . D U . U D U
            for st, down in [(0, True), (1, True), (1.5, False), (2.5, False), (3, True), (3.5, False)]:
                strum(tr, t0 + st * b + R.uniform(0, 0.006), UKE[ch], down, 0.3 if st in (0, 3) else 0.24, 0.42, 0.25)
            # plucked bass: root, fifth, a walk into the next bar
            r, f = BASS[ch]
            tr.add(t0, pluck(r, b * 1.6, 0.75, 0.995), -0.05, 1.0)
            tr.add(t0 + 2 * b, pluck(f, b * 1.2, 0.6, 0.995), -0.05, 1.0)
            if i % 2 == 1:
                tr.add(t0 + 3.5 * b, pluck(midi(r) + 2, b * 0.5, 0.45, 0.99), -0.05, 1.0)
            # drums
            for bt in range(4):
                if bt in (0, 2):
                    tr.add(t0 + bt * b, kick(0.75 if bt == 0 else 0.6), 0.0, 1.0)
                if bt in (1, 3) and sec != 'BR':
                    tr.add(t0 + bt * b, clap(0.5), 0.1, 1.0)
            if sec != 'BR' and i % 4 == 3:
                tr.add(t0 + 3.5 * b, kick(0.45), 0.0, 1.0)
            for s16 in range(8):
                tr.add(t0 + s16 * b * 0.5, shaker(0.2 if s16 % 2 else 0.12), 0.45, 1.0)
                if sec == 'B' and s16 % 2 == 1:
                    tr.add(t0 + s16 * b * 0.5, noise_hit(0.08, 8000, 0.12), -0.4, 1.0)
            # melodies
            if melody is not None:
                notes = melody[i]
                if sec == 'A':
                    mel(tr, t0, b, notes, lambda n, d: glock(n, 0.55), -0.15)
                elif sec == 'B':
                    mel(tr, t0, b, notes, lambda n, d: whistle(n, d * 0.95, 0.6), 0.15)
                    tr.add(t0, strings(midi(BASS[ch][0]) + 24, bar * 0.95, 0.35, 0.3, 0.6), -0.3, 1.0)
                    tr.add(t0, strings(midi(BASS[ch][1]) + 24, bar * 0.95, 0.3, 0.3, 0.6), 0.3, 1.0)
                else:
                    mel(tr, t0, b, notes, lambda n, d: glock(n, 0.5), -0.2)
                    mel(tr, t0, b, notes, lambda n, d: celesta(n, d, 0.55), 0.2, 1.0)
                    # a little answer on the piano at the end of each phrase
                    if i % 2 == 1:
                        for j, n in enumerate(UKE[ch][1:]):
                            tr.add(t0 + 3.5 * b + j * 0.01, piano(midi(n) + 12, b * 0.4, 0.3, 0.6), 0.3, 0.5)
            else:
                # the breakdown: glockenspiel arpeggios over the strums
                tones = UKE[ch]
                for s8 in range(8):
                    n = midi(tones[[1, 2, 3, 2, 1, 2, 3, 2][s8]]) + 12
                    tr.add(t0 + s8 * b * 0.5, glock(n, 0.32 if s8 % 2 == 0 else 0.22), (-0.3 if s8 % 2 else 0.3), 1.0)
                if i == 3:
                    tr.add(t0 + 2 * b, snare(0.25), 0.0, 1.0)
                    tr.add(t0 + 2.5 * b, snare(0.32), 0.0, 1.0)
                    tr.add(t0 + 3 * b, snare(0.4), 0.0, 1.0)
                    tr.add(t0 + 3.5 * b, snare(0.5), 0.0, 1.0)
            k += 1
    x = make_loop(tr, length, wet=0.22, seconds=2.2)
    ogg('story', master(x, 0.1))


# ------------------------------------------------------------------ the chase
def chase():
    bpm = 150.0
    b = 60.0 / bpm
    bar = 4 * b
    prog = ['Em', 'C', 'D', 'B7', 'Em', 'C', 'D', 'B7', 'Am', 'C', 'D', 'B7', 'Am', 'C', 'B7', 'B7']
    tones = {'Em': ['E3', 'G3', 'B3'], 'C': ['C3', 'E3', 'G3'], 'D': ['D3', 'F#3', 'A3'], 'B7': ['B2', 'D#3', 'F#3', 'A3'],
             'Am': ['A2', 'C3', 'E3']}
    motif = [('B5', 0, .5), ('E6', .5, .5), ('G6', 1, .5), ('F#6', 1.5, .5), ('E6', 2, .5), ('D#6', 2.5, .5), ('E6', 3, 1)]
    motif2 = [('C6', 0, .5), ('E6', .5, .5), ('A6', 1, .5), ('G6', 1.5, .5), ('F#6', 2, .5), ('E6', 2.5, .5), ('D#6', 3, 1)]
    length = len(prog) * bar
    tr = Track(length)
    for i, ch in enumerate(prog):
        t0 = i * bar
        ts = tones[ch]
        root = midi(ts[0])
        # staccato strings: an eighth-note ostinato
        pat = [0, 0, 1, 0, 2, 0, 1, 0]
        for s8, idx in enumerate(pat):
            n = midi(ts[idx % len(ts)]) + 12
            tr.add(t0 + s8 * b * 0.5, strings(n, b * 0.32, 0.55, 0.01, 0.08, 3200), -0.25, 1.0)
            tr.add(t0 + s8 * b * 0.5, strings(n + 12, b * 0.28, 0.25, 0.01, 0.06, 3800), 0.25, 1.0)
        # pizzicato bass, octave jumps
        for bt in range(4):
            tr.add(t0 + bt * b, pluck(root - 12 + (12 if bt % 2 else 0), b * 0.6, 0.7, 0.99), 0.0, 1.0)
        # tick-tock (the machine's needle)
        for s8 in range(8):
            tr.add(t0 + s8 * b * 0.5, woodblock(900 if s8 % 2 == 0 else 640, 0.22), 0.5 if s8 % 2 else -0.5, 1.0)
        for s16 in range(16):
            tr.add(t0 + s16 * b * 0.25, noise_hit(0.02, 9000, 0.05), 0.2, 1.0)
        # drums
        for bt in range(4):
            tr.add(t0 + bt * b, kick(0.7), 0.0, 1.0)
            if bt in (1, 3):
                tr.add(t0 + bt * b, snare(0.45), 0.05, 1.0)
        if i % 4 == 3:
            for k in range(4):
                tr.add(t0 + 3 * b + k * b * 0.25, snare(0.2 + k * 0.08), 0.0, 1.0)
        # piano stabs
        for st in (1.5, 3.0):
            for j, n in enumerate(ts):
                tr.add(t0 + st * b + j * 0.006, piano(midi(n) + 12, b * 0.25, 0.45, 0.7), 0.15, 0.7)
        # the glockenspiel motif in the second half
        if i >= 8 and i % 2 == 0:
            mel(tr, t0, b, motif if i % 4 == 0 else motif2, lambda n, d: glock(n, 0.45), -0.1)
        if i < 8 and i % 4 == 2:
            mel(tr, t0, b, [('E6', 0, .5), ('D#6', .5, .5), ('E6', 1, .5), ('B5', 1.5, .5)], lambda n, d: celesta(n, d, 0.4), 0.2)
    x = make_loop(tr, length, wet=0.15, seconds=1.6)
    ogg('chase', master(x, 0.11))


# ------------------------------------------------------------------ the tower
def tower():
    bpm = 100.0
    b = 60.0 / bpm
    bar = 4 * b
    prog = ['D', 'A/C#', 'Bm', 'G', 'D', 'A', 'G', 'A', 'Bm', 'G', 'D', 'A', 'G', 'A', 'D', 'Dsus']
    ch = {'D': ['D3', 'F#3', 'A3'], 'A/C#': ['C#3', 'E3', 'A3'], 'Bm': ['B2', 'D3', 'F#3'], 'G': ['G2', 'B2', 'D3'],
          'A': ['A2', 'C#3', 'E3'], 'Dsus': ['D3', 'G3', 'A3']}
    lead = [
        [('F#5', 0, 2), ('A5', 2, 2)], [('E5', 0, 3), ('C#5', 3, 1)], [('D5', 0, 2), ('F#5', 2, 2)], [('G5', 0, 3), ('B4', 3, 1)],
        [('A5', 0, 2), ('D6', 2, 2)], [('C#6', 0, 2), ('E6', 2, 2)], [('D6', 0, 1), ('B5', 1, 1), ('G5', 2, 2)], [('A5', 0, 4)],
        [('B5', 0, 2), ('D6', 2, 2)], [('B5', 0, 3), ('G5', 3, 1)], [('A5', 0, 2), ('F#5', 2, 1), ('A5', 3, 1)], [('E6', 0, 4)],
        [('D6', 0, 1), ('E6', 1, 1), ('F#6', 2, 2)], [('G6', 0, 2), ('E6', 2, 2)], [('F#6', 0, 4)], [('A6', 0, 2), ('G6', 2, 2)],
    ]
    length = len(prog) * bar
    tr = Track(length)
    for i, c in enumerate(prog):
        t0 = i * bar
        ts = ch[c]
        # rising arpeggios, sixteenths, climbing an octave each bar
        arp = [midi(ts[0]) + 12, midi(ts[1]) + 12, midi(ts[2]) + 12, midi(ts[0]) + 24]
        for s16 in range(16):
            n = arp[s16 % 4] + 12 * (s16 // 8)
            tr.add(t0 + s16 * b * 0.25, celesta(n, b * 0.5, 0.38 if s16 % 4 == 0 else 0.26), (-0.4 + 0.8 * (s16 % 4) / 3), 1.0)
        tr.add(t0, pluck(ts[0], bar * 0.5, 0.7, 0.996), 0.0, 1.0)
        tr.add(t0 + 2 * b, pluck(midi(ts[0]) + 7, bar * 0.4, 0.55, 0.996), 0.0, 1.0)
        tr.add(t0 + 3.5 * b, pluck(midi(ts[0]) + 12, b * 0.4, 0.4, 0.99), 0.0, 1.0)
        if i % 4 == 0:
            tr.add(t0, pad([midi(n) + 12 for n in ts], bar * 4, att=1.2, rel=2.0, cutoff=1600, vol=0.05), 0.0, 1.0)
        tr.add(t0, kick(0.6), 0.0, 1.0)
        tr.add(t0 + 2 * b, kick(0.5), 0.0, 1.0)
        for bt in (1, 3):
            tr.add(t0 + bt * b, woodblock(1300, 0.18), 0.2, 1.0)
        for s8 in range(8):
            tr.add(t0 + s8 * b * 0.5, shaker(0.14 if s8 % 2 else 0.08), -0.4, 1.0)
        if i >= 4:
            mel(tr, t0, b, lead[i], lambda n, d: strings(n, d * 0.95, 0.5, 0.15, 0.5, 2400), 0.1)
            mel(tr, t0, b, lead[i], lambda n, d: glock(n, 0.3), -0.2)
    x = make_loop(tr, length, wet=0.3, seconds=2.6)
    ogg('tower', master(x, 0.1))


# ------------------------------------------------------------------ the theatre (waltz)
def finale():
    bpm = 112.0
    b = 60.0 / bpm
    bar = 3 * b
    prog = ['C', 'G/B', 'Am', 'F', 'C', 'G', 'F', 'G', 'C', 'E7', 'Am', 'F', 'C', 'G', 'C', 'C']
    ch = {'C': ['C3', 'E3', 'G3'], 'G/B': ['B2', 'D3', 'G3'], 'Am': ['A2', 'C3', 'E3'], 'F': ['F2', 'A2', 'C3'],
          'G': ['G2', 'B2', 'D3'], 'E7': ['E2', 'G#2', 'D3']}
    melody = [
        [('E6', 0, 1), ('G6', 1, 1), ('C7', 2, 1)], [('B6', 0, 2), ('G6', 2, 1)], [('A6', 0, 1), ('C7', 1, 1), ('E7', 2, 1)],
        [('D7', 0, 2), ('C7', 2, 1)], [('G6', 0, 1.5), ('E6', 1.5, .5), ('C6', 2, 1)], [('D6', 0, 1), ('G6', 1, 1), ('B6', 2, 1)],
        [('A6', 0, 1), ('F6', 1, 1), ('A6', 2, 1)], [('G6', 0, 3)],
        [('E6', 0, 1), ('G6', 1, 1), ('C7', 2, 1)], [('B6', 0, 1.5), ('G#6', 1.5, .5), ('E6', 2, 1)], [('A6', 0, 1), ('C7', 1, 1), ('E7', 2, 1)],
        [('F7', 0, 2), ('E7', 2, 1)], [('E7', 0, 1), ('D7', 1, 1), ('C7', 2, 1)], [('D7', 0, 1.5), ('B6', 1.5, .5), ('G6', 2, 1)],
        [('C7', 0, 3)], [('G6', 2, 1)],
    ]
    length = len(prog) * bar
    tr = Track(length)
    for i, c in enumerate(prog):
        t0 = i * bar
        ts = ch[c]
        tr.add(t0, pluck(ts[0], b * 1.4, 0.7, 0.995), -0.05, 1.0)
        for k in (1, 2):
            for j, n in enumerate(ts[1:] + [midi(ts[0]) + 12]):
                tr.add(t0 + k * b + j * 0.01, piano(midi(n) + 12, b * 0.6, 0.28, 0.4), 0.2, 0.4)
        if i % 4 == 0:
            tr.add(t0, pad([midi(n) + 12 for n in ts], bar * 4, att=1.0, rel=2.2, cutoff=1500, vol=0.045), 0.0, 1.0)
            tr.add(t0, strings(midi(ts[0]) + 24, bar * 3.8, 0.28, 0.8, 1.2), -0.3, 1.0)
        mel(tr, t0, b, melody[i], lambda n, d: celesta(midi(n) - 12, d, 0.6), -0.15)
        if i >= 8:
            mel(tr, t0, b, melody[i], lambda n, d: glock(midi(n) - 12, 0.25), 0.25)
        tr.add(t0, shaker(0.08), 0.4, 1.0)
    x = make_loop(tr, length, wet=0.35, seconds=3.0)
    ogg('finale', master(x, 0.085))


# ------------------------------------------------------------------ the quilt
def quilt():
    bpm = 68.0
    b = 60.0 / bpm
    bar = 4 * b
    prog = ['F', 'Am', 'Dm', 'Bb', 'F', 'C', 'Bb', 'C', 'Dm', 'Am', 'Bb', 'F', 'Gm', 'C', 'F', 'F']
    ch = {'F': ['F2', 'C3', 'A3'], 'Am': ['A2', 'E3', 'C4'], 'Dm': ['D2', 'A2', 'F3'], 'Bb': ['Bb1', 'F2', 'D3'],
          'C': ['C2', 'G2', 'E3'], 'Gm': ['G2', 'D3', 'Bb3']}
    melody = [
        [('C6', 0, 2), ('A5', 2, 1), ('F5', 3, 1)], [('E5', 0, 3), ('C5', 3, 1)], [('D5', 0, 2), ('F5', 2, 1), ('A5', 3, 1)],
        [('Bb5', 0, 3), ('A5', 3, 1)], [('A5', 0, 2), ('C6', 2, 2)], [('G5', 0, 3), ('E5', 3, 1)],
        [('F5', 0, 1), ('D5', 1, 1), ('F5', 2, 1), ('Bb5', 3, 1)], [('A5', 0, 2), ('G5', 2, 2)],
        [('F5', 0, 2), ('A5', 2, 1), ('D6', 3, 1)], [('C6', 0, 3), ('E5', 3, 1)], [('F5', 0, 1), ('G5', 1, 1), ('A5', 2, 1), ('D6', 3, 1)],
        [('C6', 0, 4)], [('Bb5', 0, 2), ('D6', 2, 1), ('G5', 3, 1)], [('E5', 0, 2), ('G5', 2, 1), ('Bb5', 3, 1)],
        [('A5', 0, 4)], [],
    ]
    length = len(prog) * bar
    tr = Track(length)
    for i, c in enumerate(prog):
        t0 = i * bar
        ts = ch[c]
        # broken chords on the piano, soft
        pat = [0, 1, 2, 1, 2 + 12, 1, 2, 1]
        for s8, idx in enumerate(pat):
            base = midi(ts[idx % 3]) + (12 if idx >= 12 else 0) + 12
            tr.add(t0 + s8 * b * 0.5 + R.uniform(0, 0.01), piano(base, b * 0.9, 0.26 if s8 % 4 == 0 else 0.18, 0.25), 0.1 - 0.2 * (s8 % 2), 1.0)
        tr.add(t0, piano(ts[0], bar * 0.95, 0.35, 0.2), -0.1, 1.0)
        if i % 2 == 0:
            tr.add(t0, strings(midi(ts[1]) + 12, bar * 1.9, 0.22, 1.2, 1.8, 1800), -0.35, 1.0)
            tr.add(t0, strings(midi(ts[2]) + 12, bar * 1.9, 0.2, 1.2, 1.8, 1800), 0.35, 1.0)
        mel(tr, t0, b, melody[i], lambda n, d: celesta(n, d, 0.42), 0.0)
        if i >= 8:
            mel(tr, t0, b, melody[i], lambda n, d: glock(midi(n) + 12, 0.12), 0.3)
    x = make_loop(tr, length, wet=0.45, seconds=4.0)
    ogg('quilt', master(x, 0.075))


# ------------------------------------------------------------------ curtains up
def fanfare():
    tr = Track(5.0)
    for k in range(24):
        t = k * 0.035
        tr.add(t, snare(0.12 + 0.3 * k / 24), 0.0, 1.0)
    t1 = 0.86
    tr.add(t1, kick(0.9), 0.0, 1.0)
    tr.add(t1, crash(0.35, 3.0), 0.2, 1.0)
    for i, n in enumerate(['G5', 'B5', 'D6', 'G6', 'B6', 'D7']):
        tr.add(t1 + i * 0.06, glock(n, 0.5), -0.4 + i * 0.16, 1.0)
        tr.add(t1 + i * 0.06, celesta(n, 1.4, 0.5), 0.4 - i * 0.16, 1.0)
    for n in ['G3', 'B3', 'D4', 'G4']:
        tr.add(t1, strings(n, 1.8, 0.45, 0.02, 1.4), 0.0, 1.0)
        tr.add(t1, piano(n, 1.5, 0.5, 0.7), 0.0, 0.6)
    strum(tr, t1, UKE['G'], True, 0.4, 1.5, 0.2, 0.996)
    tr.add(t1, pluck('G2', 2.0, 0.8, 0.997), 0.0, 1.0)
    x = apply_reverb(tr.buf[: int(4.6 * SR)], 0.3, 2.4)
    ogg('fanfare', master(x, 0.12))


if __name__ == '__main__':
    names = sys.argv[1:] or ['story', 'chase', 'tower', 'finale', 'quilt', 'fanfare']
    for n in names:
        globals()[n]()
