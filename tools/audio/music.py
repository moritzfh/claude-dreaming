"""Original music for the game, written to sit next to the film's score:
D major, ~96 BPM, add9 / maj7 colours, E7 as the dreamy II7."""
import sys
import numpy as np
from synth import *

BPM = 96.0
BEAT = 60.0 / BPM
BAR = BEAT * 4

CH = {  # chord tones (pad/arpeggio), bass note
    'Dadd9': (['D4', 'F#4', 'A4', 'E5'], 'D2'),
    'Dmaj7': (['D4', 'F#4', 'A4', 'C#5'], 'D2'),
    'Gadd9': (['G3', 'B3', 'D4', 'A4'], 'G1'),
    'Gmaj7': (['G3', 'B3', 'D4', 'F#4'], 'G1'),
    'Gsus2': (['G3', 'A3', 'D4', 'G4'], 'G1'),
    'E7':    (['E4', 'G#4', 'B4', 'D5'], 'E2'),
    'E9':    (['E4', 'G#4', 'D5', 'F#5'], 'E2'),
    'Bm7':   (['B3', 'D4', 'F#4', 'A4'], 'B1'),
    'Asus4': (['A3', 'D4', 'E4', 'A4'], 'A1'),
    'A':     (['A3', 'C#4', 'E4', 'A4'], 'A1'),
    'Aadd9': (['A3', 'C#4', 'E4', 'B4'], 'A1'),
    'F#m7':  (['F#3', 'A3', 'C#4', 'E4'], 'F#1'),
    'Amaj7': (['A3', 'C#4', 'E4', 'G#4'], 'A1'),
    'F#m9':  (['F#3', 'A3', 'E4', 'G#4'], 'F#1'),
    'Dmaj9': (['D4', 'F#4', 'C#5', 'E5'], 'D2'),
    'E6/9':  (['E4', 'G#4', 'C#5', 'F#5'], 'E2'),
    'C#m7':  (['C#4', 'E4', 'G#4', 'B4'], 'C#2'),
}

def up(n, k=12):
    return midi(n) + k

# ------------------------------------------------------------------ garden
def garden():
    A = ['Dadd9', 'Gadd9', 'E7', 'Gmaj7', 'Dmaj7', 'Gadd9', 'Bm7', 'Asus4']
    B = ['Gmaj7', 'Aadd9', 'F#m7', 'Bm7', 'Gmaj7', 'E9', 'Gsus2', 'Asus4']
    prog = A + B + A
    length = len(prog) * BAR
    tr = Track(length)
    mel_a = [[('A5', 0, 1.5), ('F#5', 1.5, .5), ('E5', 2, 1), ('D5', 3, 1)],
             [('B4', 0, 1), ('D5', 1, 1), ('G5', 2, 2)],
             [('G#5', 0, 1.5), ('F#5', 1.5, .5), ('E5', 2, 1), ('D5', 3, 1)],
             [('F#5', 0, 3)],
             [('A5', 0, 1), ('C#6', 1, 1), ('A5', 2, 1), ('F#5', 3, 1)],
             [('G5', 0, 1.5), ('A5', 1.5, .5), ('B5', 2, 2)],
             [('A5', 0, 1), ('F#5', 1, 1), ('D5', 2, 1), ('B4', 3, 1)],
             [('D5', 0, 2), ('C#5', 2, 2)]]
    mel_b = [[('D5', 0, 2), ('B4', 2, 2)], [('C#5', 0, 2), ('E5', 2, 2)], [('F#5', 0, 3), ('E5', 3, 1)], [('D5', 0, 4)],
             [('B5', 0, 2), ('A5', 2, 1), ('G5', 3, 1)], [('G#5', 0, 2), ('B5', 2, 2)], [('A5', 0, 4)], [('E5', 0, 2)]]
    arp = [0, 1, 2, 3, 2, 1, 2, 3]  # 8th-note pattern over chord tones
    for bi, name in enumerate(prog):
        tones, bass = CH[name]
        t0 = bi * BAR
        sec = 0 if bi < 8 else (1 if bi < 16 else 2)
        # pad
        tr.add(t0, pad(tones, BAR + 0.3, att=0.9, rel=1.6, cutoff=1900 if sec != 1 else 2400, vol=0.085), 0.0)
        # sustained string bed (the film's garden cue is very legato and full)
        tr.add(t0, strings(tones[1], BAR + 0.4, 0.32, att=0.9, rel=1.4, cutoff=3200), -0.35)
        tr.add(t0, strings(up(tones[2], 12), BAR + 0.4, 0.22, att=1.0, rel=1.4, cutoff=4200), 0.35)
        tr.add(t0, strings(up(bass, 12), BAR + 0.4, 0.30, att=0.6, rel=1.2, cutoff=900), 0.0)
        # bass: piano low notes on 1 and the "and" of 3
        tr.add(t0, piano(bass, BEAT * 2.4, 0.55, 0.2), -0.1, 0.9)
        tr.add(t0 + BEAT * 2.5, piano(up(bass, 12), BEAT * 1.4, 0.35, 0.2), -0.1, 0.8)
        # flowing piano arpeggio
        for k in range(8):
            n = tones[arp[k]]
            if k >= 4: n = up(n, 12) if (sec == 2 and k % 2 == 1) else n
            v = 0.32 + 0.08 * (k % 2 == 0) + (0.05 if sec == 2 else 0)
            tr.add(t0 + k * BEAT * 0.5 + rng.uniform(0, 0.012), piano(up(n, 12) if k in (3, 7) else n, BEAT * 0.9, v, 0.7), 0.25 - 0.1 * (k % 3))
        # melodies
        if sec in (0, 2):
            for (n, b, d) in mel_a[bi % 8]:
                if sec == 0:
                    tr.add(t0 + b * BEAT, celesta(n, d * BEAT, 0.75), 0.35)
                    tr.add(t0 + b * BEAT, glock(up(n, 12), 0.08), -0.4)
                else:
                    tr.add(t0 + b * BEAT, piano(up(n, 0), d * BEAT, 0.5, 0.7), 0.1, 0.8)
                    tr.add(t0 + b * BEAT, glock(up(n, 12), 0.18), 0.4)
        if sec == 1:
            for (n, b, d) in mel_b[bi % 8]:
                tr.add(t0 + b * BEAT, strings(n, d * BEAT, 0.55, att=0.35, rel=0.9), -0.2)
                tr.add(t0 + b * BEAT, strings(up(n, -12), d * BEAT, 0.3, att=0.35, rel=0.9), 0.2)
        if sec == 2:
            tr.add(t0, choir(tones[1:], BAR, vol=0.05), 0.0)
        # soft brushed shaker on off-beats in the B section
        if sec == 1:
            for k in range(8):
                tr.add(t0 + k * BEAT * 0.5, noise_hit(0.05, 6000, 0.05 if k % 2 else 0.025), 0.3)
    tr.buf[: int(length * SR)] += air(length, 0.012)
    return make_loop(tr, length, wet=0.5, seconds=3.8), length

# ------------------------------------------------------------------ space
def space():
    prog = ['Amaj7', 'F#m9', 'Dmaj9', 'E6/9', 'Amaj7', 'C#m7', 'Dmaj9', 'E6/9']
    bar = 5.0
    length = len(prog) * bar
    tr = Track(length)
    stars = ['E6', 'C#6', 'G#5', 'B5', 'A5', 'F#6', 'E6', 'C#6']
    for bi, name in enumerate(prog):
        tones, bass = CH[name]
        t0 = bi * bar
        tr.add(t0, pad(tones, bar + 0.5, att=2.0, rel=3.0, cutoff=900, detune=0.18, vol=0.13), 0)
        tr.add(t0, choir([up(n, 12) for n in tones[1:3]], bar, vol=0.06, att=2.0, rel=3.0), 0)
        tr.add(t0, pad([bass, up(bass, 12)], bar, att=1.5, rel=2.5, cutoff=300, vol=0.12), 0)
        for k in range(5):
            if rng.random() < 0.75:
                n = up(rng.choice(tones), 24)
                tr.add(t0 + k * 1.0 + rng.uniform(0, 0.4), glock(n, 0.12 + rng.random() * 0.1), rng.uniform(-0.8, 0.8))
        tr.add(t0 + 2.5, celesta(stars[bi], 2.0, 0.3), 0.3)
    return make_loop(tr, length, wet=0.6, seconds=6.0), length

# ------------------------------------------------------------------ pixel hub
def hub():
    prog = ['Dadd9', 'Gadd9', 'E7', 'Asus4', 'Dmaj7', 'Gadd9', 'Bm7', 'A'] * 2
    length = len(prog) * BAR
    tr = Track(length)
    mel = [[('F#5', 0, .5), ('A5', .5, .5), ('B5', 1, 1), ('A5', 2, 1), ('F#5', 3, 1)],
           [('G5', 0, 1.5), ('F#5', 1.5, .5), ('D5', 2, 2)],
           [('E5', 0, .5), ('F#5', .5, .5), ('G#5', 1, 1), ('B5', 2, 2)],
           [('A5', 0, 3)],
           [('F#5', 0, .5), ('A5', .5, .5), ('D6', 1, 1), ('C#6', 2, 1), ('A5', 3, 1)],
           [('B5', 0, 1.5), ('A5', 1.5, .5), ('G5', 2, 2)],
           [('F#5', 0, 1), ('D5', 1, 1), ('B4', 2, 1), ('D5', 3, 1)],
           [('E5', 0, 2), ('C#5', 2, 2)]]
    for bi, name in enumerate(prog):
        tones, bass = CH[name]
        t0 = bi * BAR
        second = bi >= 8
        # triangle bass: root on 1, fifth-ish on 3
        tr.add(t0, triangle(up(bass, 12), BEAT * 1.6, 0.5), 0)
        tr.add(t0 + BEAT * 2, triangle(up(bass, 12), BEAT * 0.8, 0.4), 0)
        tr.add(t0 + BEAT * 3, triangle(up(bass, 19), BEAT * 0.8, 0.4), 0)
        # 25% pulse arpeggio in 16ths, quiet
        for k in range(16):
            n = tones[k % 4]
            tr.add(t0 + k * BEAT * 0.25, square(up(n, 12), BEAT * 0.2, 0.25, 0.10), 0.3 if k % 2 else -0.3)
        # lead
        if second or bi % 8 in (0, 1, 4, 5, 6):
            for (n, b, d) in mel[bi % 8]:
                tr.add(t0 + b * BEAT, square(n, d * BEAT * 0.92, 0.5, 0.28), 0.0)
                if second:
                    tr.add(t0 + b * BEAT + BEAT * 0.75, square(n, d * BEAT * 0.5, 0.5, 0.08), 0.5)  # echo
        # soft drums: kick-ish triangle drop + hats
        for k in range(4):
            tt = t0 + k * BEAT
            if k in (0, 2):
                tk = t_arr(0.12); kick = np.sin(2 * np.pi * (60 + 120 * np.exp(-tk / 0.02)) * tk) * np.exp(-tk / 0.05)
                tr.add(tt, kick * 0.35, 0)
            tr.add(tt + BEAT * 0.5, noise_hit(0.04, 8000, 0.06), 0.2)
            if k in (1, 3):
                tr.add(tt, noise_hit(0.09, 2500, 0.08), -0.1)
    return make_loop(tr, length, wet=0.18, seconds=1.6), length

if __name__ == "__main__":
    which = sys.argv[1]
    x, L = {'garden': garden, 'space': space, 'hub': hub}[which]()
    save(f'/home/claude/audio/{which}.wav', master(x, {'garden': 0.11, 'space': 0.09, 'hub': 0.10}[which]))
    print(which, 'len', L)
