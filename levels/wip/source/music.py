"""Work in Progress – music and sound effects, made with the project's tiny
numpy synth (tools/audio/synth.py).

The music is one cosy little tune (F major, 92 bpm, 16 bars) in five
versions of the same length, one per stage. The level cross-fades between
them at the same position, so the song "falls apart" as the level does:
  wip_0  finished: Rhodes, bass, brushed drums, celesta melody, a soft pad
  wip_1  missing textures: a chiptune melody with missing notes, a slightly
         detuned piano, and the snare replaced by a placeholder "boop"
  wip_2  grey-box: plain piano block chords, sine bass, a metronome, beeps
  wip_3  wireframe: the skeleton – bass, click and a few melody notes
  wip_4  sketch: somebody whistling the tune, a pencil scratching along

Run from the repo root:  python3 levels/wip/source/music.py [music|sfx]
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

BPM = 92.0
BEAT = 60.0 / BPM
BAR = BEAT * 4
BARS = 16
LENGTH = BAR * BARS
SWING = 0.58          # where the off-beat eighth lands inside the beat

CHORDS = {
    'Fmaj7': (['F3', 'A3', 'C4', 'E4'], 'F2'), 'Am7': (['G3', 'A3', 'C4', 'E4'], 'A2'),
    'Bbmaj7': (['F3', 'A3', 'Bb3', 'D4'], 'Bb1'), 'C7': (['E3', 'G3', 'Bb3', 'C4'], 'C2'),
    'Gm7': (['F3', 'G3', 'Bb3', 'D4'], 'G1'), 'Dm7': (['F3', 'A3', 'C4', 'D4'], 'D2'),
    'F/A': (['A3', 'C4', 'F4'], 'A1'), 'C7sus4': (['F3', 'G3', 'Bb3', 'C4'], 'C2'),
}
PROG = ['Fmaj7', 'Am7', 'Bbmaj7', 'C7', 'Fmaj7', 'Am7', 'Gm7', 'C7',
        'Dm7', 'Am7', 'Bbmaj7', 'F/A', 'Gm7', 'C7', 'Fmaj7', 'C7sus4']
MEL = [
    [('A4', 0, 1.5), ('G4', 1.5, .5), ('F4', 2, 1), ('C5', 3, 1)],
    [('E5', 0, 1.5), ('C5', 1.5, .5), ('A4', 2, 2)],
    [('D5', 0, 1), ('C5', 1, .5), ('Bb4', 1.5, .5), ('A4', 2, 1), ('F4', 3, 1)],
    [('G4', 0, 3)],
    [('A4', 0, 1.5), ('G4', 1.5, .5), ('F4', 2, 1), ('C5', 3, 1)],
    [('E5', 0, 1), ('G5', 1, 1), ('E5', 2, 1), ('C5', 3, 1)],
    [('D5', 0, 1.5), ('Bb4', 1.5, .5), ('G4', 2, 2)],
    [('C5', 0, 3)],
    [('F5', 0, 1.5), ('E5', 1.5, .5), ('D5', 2, 1), ('A4', 3, 1)],
    [('C5', 0, 1.5), ('A4', 1.5, .5), ('E4', 2, 2)],
    [('F4', 0, 1), ('G4', 1, 1), ('A4', 2, 1), ('D5', 3, 1)],
    [('C5', 0, 3)],
    [('Bb4', 0, 1), ('A4', 1, 1), ('G4', 2, 1), ('D5', 3, 1)],
    [('C5', 0, 1.5), ('Bb4', 1.5, .5), ('G4', 2, 1), ('E4', 3, 1)],
    [('F4', 0, 1), ('A4', 1, 1), ('C5', 2, 1), ('E5', 3, 1)],
    [('F5', 0, 2)],
]


def at(bar, beat):
    """time of a beat in a bar, with swung eighths"""
    whole = np.floor(beat)
    frac = beat - whole
    if abs(frac - 0.5) < 1e-6: frac = SWING
    return bar * BAR + (whole + frac) * BEAT


# ---------------------------------------------------------------- instruments
def rhodes(n, dur, vel=0.5, detune=0.0):
    f = hz(n) * 2 ** (detune / 1200); L = dur + 1.4; t = t_arr(L)
    mod = np.sin(2 * np.pi * f * t) * 1.1 * np.exp(-t / 0.22)
    out = np.sin(2 * np.pi * f * t + mod) + 0.22 * np.sin(4 * np.pi * f * t) * np.exp(-t / 0.5)
    out *= np.exp(-t / 2.4) * (1 + 0.07 * np.sin(2 * np.pi * 4.6 * t))
    r0 = int(dur * SR)
    out[r0:] *= np.exp(-(t[r0:] - dur) / 0.3)
    out[: int(0.004 * SR)] *= np.linspace(0, 1, int(0.004 * SR))
    return lp(out, 3200) * vel * 0.35

def sbass(n, dur, vel=0.6):
    f = hz(n); L = dur + 0.2; t = t_arr(L)
    out = np.sin(2 * np.pi * f * t) + 0.18 * np.sin(4 * np.pi * f * t)
    out = np.tanh(out * 1.4)
    out *= env_adsr(len(t), 0.006, 0.25, 0.7, 0.12)
    return lp(out, 900) * vel * 0.5

def kick(vel=0.6):
    t = t_arr(0.4)
    f = 45 + 80 * np.exp(-t / 0.035)
    out = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.18)
    return out * vel * 0.8

def rim(vel=0.4):
    t = t_arr(0.18)
    out = bp(rng.standard_normal(len(t)), 1500, 6000) * np.exp(-t / 0.03) * 0.6
    out += np.sin(2 * np.pi * 420 * t) * np.exp(-t / 0.02) * 0.5
    return out * vel * 0.6

def brush(vel=0.2):
    t = t_arr(0.12)
    return bp(rng.standard_normal(len(t)), 3000, 11000) * np.exp(-t / 0.035) * vel * 0.5

def boop(vel=0.4):
    """a placeholder sound where the snare should be"""
    t = t_arr(0.14)
    return np.sin(2 * np.pi * 660 * t) * env_adsr(len(t), 0.002, 0.02, 0.8, 0.03) * vel * 0.35

def click(vel=0.4, hi=False):
    t = t_arr(0.05)
    return np.sin(2 * np.pi * (1650 if hi else 1100) * t) * np.exp(-t / 0.008) * vel * 0.6

def sine_beep(n, dur, vel=0.4):
    f = hz(n); t = t_arr(dur)
    return np.sin(2 * np.pi * f * t) * env_adsr(len(t), 0.004, 0.02, 0.85, 0.03) * vel * 0.3

def whistle(n, dur, vel=0.5):
    f = hz(n); t = t_arr(dur + 0.25)
    vib = 1 + 0.009 * np.sin(2 * np.pi * 5.6 * t) * np.clip((t - 0.18) * 3, 0, 1)
    ph = np.cumsum(f * vib) / SR
    out = np.sin(2 * np.pi * ph) + 0.04 * np.sin(4 * np.pi * ph)
    out += bp(rng.standard_normal(len(t)), f * 0.9, f * 2.4) * 0.09
    out *= env_adsr(len(t), 0.05, 0.1, 0.85, 0.15)
    return out * vel * 0.32

def scratch(vel=0.3, dur=0.16):
    t = t_arr(dur)
    n = bp(rng.standard_normal(len(t)), 2200, 7000)
    grain = 0.6 + 0.4 * np.sign(np.sin(2 * np.pi * 38 * t))
    return n * np.sin(np.pi * t / dur) * grain * vel * 0.35


# ---------------------------------------------------------------- the five versions
def version(v):
    tr = Track(LENGTH)
    for b, name in enumerate(PROG):
        notes, root = CHORDS[name]
        # --- chords
        if v in (0, 1):
            for beat, d, vel in ((0, 1.4, 0.55), (2.5, 1.2, 0.42)):
                for k, nn in enumerate(notes):
                    dt = (k * 7 + b * 3) % 11 * 0.004
                    det = (25 if (b + k) % 3 == 0 else -15) if v == 1 else 0
                    tr.add(at(b, beat) + dt, rhodes(nn, d * BEAT, vel, det), -0.25 + k * 0.17)
        elif v == 2:
            for k, nn in enumerate(notes):
                tr.add(at(b, 0), piano(nn, BEAT * 1.8, 0.45, bright=0.2), -0.2 + k * 0.13)
        elif v == 4 and b % 2 == 0:
            for k, nn in enumerate(notes):
                tr.add(at(b, 0) + k * 0.05, rhodes(nn, BEAT * 3, 0.22), -0.3 + k * 0.2)
        if v == 0:
            tr.add(at(b, 0), pad(notes, BAR, att=0.8, rel=1.5, cutoff=1100, vol=0.05), 0)
        # --- bass
        if v in (0, 1, 2, 3):
            fifth = midi(root) + 7
            pattern = [(0, 1.6, root), (2, 0.9, root), (3, 0.8, fifth)] if v in (0, 1) else [(0, 1.8, root), (2, 1.8, root)]
            for beat, d, nn in pattern:
                tr.add(at(b, beat), sbass(nn, d * BEAT, 0.62 if v < 3 else 0.5), 0)
        # --- drums
        if v in (0, 1):
            for beat in (0, 2.5):
                tr.add(at(b, beat), kick(0.6), 0)
            for beat in (1, 3):
                tr.add(at(b, beat), rim(0.45) if v == 0 else boop(0.45), 0.1)
            for k in range(8):
                beat = k * 0.5
                tr.add(at(b, beat), brush(0.26 if k % 2 else 0.18), 0.35)
        elif v == 2:
            for beat in range(4):
                tr.add(at(b, beat), click(0.45, beat == 0), 0)
        elif v == 3:
            for beat in (0, 2):
                tr.add(at(b, beat), click(0.32, beat == 0), 0)
        elif v == 4:
            for k in range(8):
                if (k + b) % 3 != 1:
                    tr.add(at(b, k * 0.5), scratch(0.3 if k % 2 == 0 else 0.2, 0.12 + 0.05 * (k % 2)), 0.3)
        # --- melody
        for i, (nn, beat, d) in enumerate(MEL[b]):
            t0 = at(b, beat)
            dur = d * BEAT
            if v == 0:
                tr.add(t0, celesta(nn, dur, 0.5), 0.15)
                tr.add(t0, rhodes(nn, dur * 0.9, 0.22), -0.1)
            elif v == 1:
                if (b * 5 + i) % 6 == 4: continue           # missing notes
                tr.add(t0, square(nn, dur * 0.9, duty=0.25, vel=0.42), 0.1)
            elif v == 2:
                tr.add(t0, sine_beep(nn, min(dur, BEAT) * 0.8, 0.55), 0.1)
            elif v == 3:
                if i == 0: tr.add(t0, triangle(nn, dur * 0.9, 0.28), 0.0)
            elif v == 4:
                tr.add(t0, whistle(nn, dur * 0.95, 0.55), 0.05)
    wet = {0: 0.28, 1: 0.24, 2: 0.12, 3: 0.35, 4: 0.3}[v]
    x = make_loop(tr, LENGTH, wet=wet, seconds=2.4)
    return master(x, {0: 0.10, 1: 0.10, 2: 0.085, 3: 0.06, 4: 0.075}[v])


# ---------------------------------------------------------------- sound effects
def sfx_all():
    out = {}
    # put a piece down: a soft wooden tock
    t = t_arr(0.25)
    x = np.sin(2 * np.pi * 300 * t * (1 + 0.6 * np.exp(-t / 0.01))) * np.exp(-t / 0.05)
    x += bp(rng.standard_normal(len(t)), 800, 3000) * np.exp(-t / 0.008) * 0.5
    x += np.sin(2 * np.pi * 95 * t) * np.exp(-t / 0.06) * 0.6
    out['place'] = x * 0.7
    # pick up: a little upward tick
    t = t_arr(0.16)
    f = 700 + 900 * t / 0.16
    out['pick'] = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.04) * 0.5
    # not possible: two low buzzes
    tr = Track(0.4)
    for k in range(2):
        tr.add(k * 0.11, square('D3' if k == 0 else 'C#3', 0.07, duty=0.5, vel=0.8), 0)
    out['nope'] = tr.buf[: int(0.3 * SR)]
    # error dialog: the classic two-tone "dun-dun"
    tr = Track(0.9)
    for k, n in enumerate(['A4', 'E4']):
        tr.add(k * 0.17, sine_beep(n, 0.16, 1.0) * 1.4, 0)
        tr.add(k * 0.17, square(n, 0.16, duty=0.5, vel=0.25), 0)
    out['error'] = tr.buf[: int(0.6 * SR)]
    # spring
    L = 0.7; t = t_arr(L)
    f = 220 * (1 + 0.9 * np.exp(-t / 0.08)) * (1 + 0.15 * np.sin(2 * np.pi * 9 * t) * np.exp(-t / 0.3))
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.25)
    out['boing'] = x * 0.6
    # falling out of the world: a descending slide whistle
    L = 1.3; t = t_arr(L)
    f = 620 * np.exp(-t * 1.1) + 150
    env = np.minimum(1, t / 0.12) ** 2 * np.exp(-t / 0.7)
    out['fall'] = (np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.1 * np.sin(4 * np.pi * np.cumsum(f) / SR)) * env * 0.3
    # the goal: a happy little jingle
    tr = Track(3.5)
    for k, n in enumerate(['F5', 'A5', 'C6', 'F6']):
        tr.add(k * 0.09, celesta(n, 0.4, 0.55), -0.3 + 0.2 * k)
        tr.add(k * 0.09, rhodes(n, 0.3, 0.25), 0.2)
    for k, n in enumerate(['F4', 'A4', 'C5', 'E5']):
        tr.add(0.42, rhodes(n, 1.6, 0.4), -0.3 + 0.2 * k)
    tr.add(0.42, glock('A6', 0.3), 0.3)
    tr.add(0.5, glock('C7', 0.25), -0.3)
    tr.add(0.42, sbass('F2', 1.4, 0.6), 0)
    out['fanfare'] = tr.buf[: int(3.0 * SR)]
    return out


def to_ogg(name, x, rev=0.1, rev_s=0.6, peak=0.85):
    if x.ndim == 1: x = np.stack([x, x], 1)
    if rev > 0: x = apply_reverb(np.vstack([x, np.zeros((int(rev_s * SR), 2))]), rev, rev_s)
    x = x / (np.abs(x).max() + 1e-9) * peak
    env = np.abs(x).max(1)
    loud = np.where(env > 2e-3)[0]
    if len(loud): x = x[: min(len(x), loud[-1] + int(0.05 * SR))]
    wav = os.path.join(TMP, name + '.wav')
    save(wav, x)
    subprocess.run(['ffmpeg', '-loglevel', 'error', '-y', '-i', wav, '-c:a', 'libvorbis', '-q:a', '5', os.path.join(OUT, name + '.ogg')], check=True)


if __name__ == '__main__':
    which = sys.argv[1] if len(sys.argv) > 1 else 'all'
    if which in ('all', 'sfx'):
        for k, v in sfx_all().items():
            to_ogg(k, v, rev=0.2 if k == 'fanfare' else 0.08, rev_s=1.2 if k == 'fanfare' else 0.5, peak=0.5 if k == 'fall' else 0.85)
            print('sfx', k)
    if which in ('all', 'music'):
        for v in range(5):
            x = version(v)
            wav = os.path.join(TMP, 'wip_%d.wav' % v)
            save(wav, x)
            subprocess.run(['ffmpeg', '-loglevel', 'error', '-y', '-i', wav, '-c:a', 'libvorbis', '-q:a', '4', os.path.join(OUT, 'wip_%d.ogg' % v)], check=True)
            print('music', v, round(LENGTH, 2), 's')
