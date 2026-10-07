"""Tiny numpy synthesizer used to compose the game's music and sound effects."""
import numpy as np
from scipy.signal import fftconvolve, butter, sosfilt

SR = 44100
rng = np.random.default_rng(7)

NOTE = {'C':0,'C#':1,'Db':1,'D':2,'D#':3,'Eb':3,'E':4,'F':5,'F#':6,'Gb':6,'G':7,'G#':8,'Ab':8,'A':9,'A#':10,'Bb':10,'B':11}
def midi(n):
    if isinstance(n, (int, float, np.integer, np.floating)): return float(n)
    name, octv = n[:-1], int(n[-1])
    return 12 * (octv + 1) + NOTE[name]
def hz(n): return 440.0 * 2 ** ((midi(n) - 69) / 12)

def t_arr(dur): return np.arange(int(dur * SR)) / SR

def lp(x, fc, order=2):
    sos = butter(order, min(fc, SR * 0.45), 'low', fs=SR, output='sos')
    return sosfilt(sos, x, axis=0)
def hp(x, fc, order=2):
    sos = butter(order, fc, 'high', fs=SR, output='sos')
    return sosfilt(sos, x, axis=0)
def bp(x, lo, hi, order=2):
    sos = butter(order, [lo, min(hi, SR * 0.45)], 'band', fs=SR, output='sos')
    return sosfilt(sos, x, axis=0)

def env_adsr(n, a, d, s, r, sus_len=None):
    a_n, d_n, r_n = int(a * SR), int(d * SR), int(r * SR)
    e = np.ones(n) * s
    a_n = min(a_n, n); e[:a_n] = np.linspace(0, 1, a_n, endpoint=False)
    d_end = min(n, a_n + d_n); e[a_n:d_end] = np.linspace(1, s, d_end - a_n, endpoint=False)
    if r_n > 0 and n > r_n:
        e[-r_n:] *= np.linspace(1, 0, r_n)
    return e

def pan(x, p):  # p in [-1,1]
    l = np.cos((p + 1) * np.pi / 4); r = np.sin((p + 1) * np.pi / 4)
    return np.stack([x * l, x * r], axis=1)

# ---------------------------------------------------------------- instruments
def piano(n, dur, vel=0.7, bright=0.5):
    f = hz(n); L = dur + 2.5
    t = t_arr(L)
    out = np.zeros_like(t)
    B = 0.00018
    for k in range(1, 11):
        fk = f * k * np.sqrt(1 + B * k * k)
        if fk > SR * 0.45: break
        amp = (1.0 / k ** (1.6 - bright * 0.6)) * (1 if k % 7 else 0.3)
        dec = 1.8 / (1 + 0.45 * k) * (440 / max(f, 80)) ** 0.35
        out += amp * np.sin(2 * np.pi * fk * t + rng.random() * 6.28) * np.exp(-t / dec)
    # felt hammer thump
    click = lp(rng.standard_normal(len(t)) * np.exp(-t / 0.006), 2500) * 0.15
    out += click
    # damper release
    rel = np.ones_like(t); r0 = int(dur * SR)
    rel[r0:] = np.exp(-(t[r0:] - dur) / 0.25)
    out *= rel * vel
    out[: int(0.003 * SR)] *= np.linspace(0, 1, int(0.003 * SR))
    out = lp(out, 2500 + 3500 * bright * vel)
    return out

def pad(notes, dur, att=1.2, rel=2.0, cutoff=1400, detune=0.12, voices=5, vol=0.12):
    L = dur + rel
    t = t_arr(L)
    out = np.zeros_like(t)
    for n in notes:
        f = hz(n)
        for v in range(voices):
            d = (v - (voices - 1) / 2) / ((voices - 1) / 2 + 1e-9) * detune
            fv = f * 2 ** (d / 12)
            ph = rng.random()
            saw = 2 * ((fv * t + ph) % 1.0) - 1
            out += saw
    out /= (len(notes) * voices) ** 0.5
    lfo = 1 + 0.25 * np.sin(2 * np.pi * 0.13 * t)
    out = lp(out, cutoff, 2) * 0.6 + lp(out, cutoff * 1.8, 2) * 0.4 * lfo
    out *= env_adsr(len(t), att, 0.5, 0.85, rel)
    return out * vol

def celesta(n, dur=1.2, vel=0.6):
    f = hz(n); L = dur + 2.0
    t = t_arr(L)
    parts = [(1, 1.0, 1.4), (2.0, 0.35, 0.6), (3.0, 0.12, 0.35), (4.16, 0.08, 0.2), (5.43, 0.05, 0.15)]
    out = np.zeros_like(t)
    for r, a, d in parts:
        out += a * np.sin(2 * np.pi * f * r * t) * np.exp(-t / d)
    out *= env_adsr(len(t), 0.002, 0.0, 1.0, 0.05)
    return out * vel * 0.5

def glock(n, vel=0.5):
    f = hz(n); t = t_arr(3.0)
    out = np.zeros_like(t)
    for r, a, d in [(1, 1, 1.6), (2.756, 0.45, 0.5), (5.404, 0.25, 0.25), (8.933, 0.1, 0.12)]:
        out += a * np.sin(2 * np.pi * f * r * t) * np.exp(-t / d)
    return out * vel * 0.35

def strings(n, dur, vel=0.5, att=0.6, rel=1.2, cutoff=2600):
    f = hz(n); L = dur + rel
    t = t_arr(L)
    vib = 1 + 0.004 * np.sin(2 * np.pi * 5.2 * t) * np.clip((t - 0.4) * 2, 0, 1)
    out = np.zeros_like(t)
    for d in (-0.07, 0.0, 0.08):
        ph = np.cumsum(f * 2 ** (d / 12) * vib) / SR
        out += 2 * ((ph + rng.random()) % 1.0) - 1
    out = lp(out, cutoff, 2)
    out = hp(out, 120)
    out *= env_adsr(len(t), att, 0.3, 0.9, rel)
    return out * vel * 0.18

def choir(notes, dur, vol=0.1, att=1.5, rel=2.5):
    base = pad(notes, dur, att, rel, cutoff=4000, detune=0.15, voices=4, vol=1.0)
    out = bp(base, 650, 950) * 1.0 + bp(base, 1050, 1300) * 0.7 + bp(base, 2600, 3100) * 0.25
    return out * vol * 2.2

def pluck(n, dur=1.5, vel=0.5, damp=0.996):
    f = hz(n); N = int(SR / f)
    L = int((dur + 0.5) * SR)
    buf = rng.uniform(-1, 1, N)
    out = np.zeros(L)
    # vectorised-ish Karplus-Strong by blocks
    y = np.concatenate([buf, np.zeros(L)])
    for i in range(N, L + N):
        y[i] = damp * 0.5 * (y[i - N] + y[i - N + 1]) if i - N + 1 < len(y) else 0
    out = y[N:N + L]
    out = lp(out, 3500)
    return out * vel * 0.6

def square(n, dur, duty=0.5, vel=0.3, rel=0.05):
    f = hz(n); t = t_arr(dur + rel)
    out = np.where(((f * t) % 1.0) < duty, 1.0, -1.0)
    out *= env_adsr(len(t), 0.003, 0.05, 0.75, rel)
    return lp(out, 6000, 1) * vel * 0.25

def triangle(n, dur, vel=0.5, rel=0.04):
    f = hz(n); t = t_arr(dur + rel)
    out = 2 * np.abs(2 * ((f * t) % 1.0) - 1) - 1
    out *= env_adsr(len(t), 0.003, 0.02, 0.95, rel)
    return out * vel * 0.4

def noise_hit(dur=0.06, fc=7000, vel=0.3):
    t = t_arr(dur)
    return hp(rng.standard_normal(len(t)), fc) * np.exp(-t / (dur / 4)) * vel

# ---------------------------------------------------------------- mixing
class Track:
    def __init__(self, length):
        self.n = int(length * SR)
        self.buf = np.zeros((self.n + SR * 8, 2))
    def add(self, t0, sig, p=0.0, gain=1.0):
        if sig.ndim == 1: sig = pan(sig, p)
        i = int(t0 * SR)
        j = min(i + len(sig), len(self.buf))
        self.buf[i:j] += sig[: j - i] * gain

def reverb_ir(seconds=3.2, damp=0.6, pre=0.02, seed=3):
    r = np.random.default_rng(seed)
    t = t_arr(seconds)
    ir = np.zeros((len(t), 2))
    for c in range(2):
        nse = r.standard_normal(len(t))
        e = np.exp(-t / (seconds / 6.9))
        x = nse * e
        # darker tail
        x = lp(x, 9000) * 0.5 + lp(x, 2500) * 0.5
        ir[:, c] = x
    ir[: int(pre * SR)] = 0
    ir /= np.abs(ir).sum(axis=0) ** 0.5 * 4
    return ir

def apply_reverb(x, wet=0.3, seconds=3.2):
    ir = reverb_ir(seconds)
    w = np.stack([fftconvolve(x[:, c], ir[:, c])[: len(x)] for c in range(2)], axis=1)
    return x * (1 - wet * 0.5) + w * wet

def make_loop(track, length, wet=0.3, seconds=3.2):
    """Render with reverb, then fold the tail back onto the start => seamless loop."""
    x = apply_reverb(track.buf, wet, seconds)
    n = int(length * SR)
    loop = x[:n].copy()
    tail = x[n:]
    k = min(len(tail), n)
    loop[:k] += tail[:k]
    return loop

def master(x, target_rms=0.11, ceiling=0.95):
    x = x - x.mean(axis=0)
    rms = np.sqrt((x ** 2).mean()) + 1e-9
    x = x / rms * target_rms
    # gentle soft clip only on peaks
    return np.tanh(x / ceiling) * ceiling

def save(path, x):
    import soundfile as sf
    sf.write(path, x.astype(np.float32), SR)


def air(dur, vol=0.03, lo=3500, hi=12000):
    """airy shimmer bed (filtered noise with slow swells)"""
    t = t_arr(dur)
    n = bp(rng.standard_normal((len(t), 2)), lo, hi)
    sw = 0.6 + 0.4 * np.sin(2 * np.pi * 0.07 * t + 1.3)[:, None]
    return n * sw * vol
