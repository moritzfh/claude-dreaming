"""Cuts the narrator recordings (one file per part of the chapter, see
narrator_elevenlabs.md) into one .ogg per line, named after the line keys,
into audio/narrator/.

  python3 levels/plush_desk/source/split_narrator.py <folder with 01_guestbook.mp3 … 08_finale.mp3>

Speech recognition (pocketsphinx, pip install pocketsphinx – it brings its own
English model) finds where each line of the script starts; the cut goes into
the quietest spot between two lines. Each line is trimmed, given 0.08 s of air
at both ends and evened out in loudness. (needs numpy, soundfile and ffmpeg)
"""
import os, re, sys, glob, difflib, subprocess, tempfile
import numpy as np
import soundfile as sf

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import narrator_lines as NL

OUT = os.path.join(HERE, '..', 'audio', 'narrator')
BLOCKS = [('01', 'sec_arrival'), ('02', 'sec_meadow'), ('03', 'sec_clouds'), ('04', 'sec_patches'),
          ('05', 'sec_machine'), ('06', 'sec_choice'), ('07', 'sec_tower'), ('08', 'sec_finale')]
SR = 44100
# hand-placed cuts where the recogniser mishears a line's first words
# (block number: {index of the line that starts there: time in s}) – for the
# recordings of 2026-10-14; delete them for new ones
OVERRIDES = {'02': {1: 5.75, 2: 12.45, 3: 17.5}, '07': {1: 6.55}, '08': {3: 11.45, 4: 17.55, 5: 21.0, 6: 25.8}}


def load(path):
    tmp = tempfile.mktemp(suffix='.wav')
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', path, '-ac', '1', '-ar', str(SR), tmp], check=True)
    x, _ = sf.read(tmp)
    os.remove(tmp)
    return x


def words(t):
    return re.findall(r"[a-z']+", t.lower().replace('-', ' '))


def recognise(x):
    from pocketsphinx import Decoder
    pcm = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    # 16 kHz for the recogniser
    idx = np.arange(0, len(pcm), SR / 16000.0).astype(int)
    d = Decoder(samprate=16000, loglevel='FATAL')
    d.start_utt()
    d.process_raw(pcm[idx].tobytes(), full_utt=True)
    d.end_utt()
    out = []
    for sg in d.seg():
        w = sg.word.split('(')[0]
        if w.startswith('<') or w.startswith('[') or w in ('<s>', '</s>'):
            continue
        out.append((w, sg.start_frame / 100.0, sg.end_frame / 100.0))
    return out


def cut(x, texts, fixed=None):
    """split a block at the line boundaries the recogniser hears"""
    n = len(texts)
    rec = recognise(x)
    exp, owner = [], []
    for i, t in enumerate(texts):
        for w in words(t):
            exp.append(w)
            owner.append(i)
    sm = difflib.SequenceMatcher(None, exp, [r[0] for r in rec], autojunk=False)
    match = {}
    for a, b, size in sm.get_matching_blocks():
        for k in range(size):
            match[a + k] = b + k
    # loudness envelope for finding the quietest spot
    hop = int(0.01 * SR)
    env = np.array([np.sqrt((x[i:i + hop] ** 2).mean()) for i in range(0, len(x) - hop, hop)])
    bounds = [0.0]
    for i in range(1, n):
        if fixed and i in fixed:
            bounds.append(fixed[i])
            continue
        last = [match[j] for j in range(len(exp)) if owner[j] == i - 1 and j in match]
        first = [match[j] for j in range(len(exp)) if owner[j] == i and j in match]
        lo = rec[max(last)][2] if last else bounds[-1]
        hi = rec[min(first)][1] if first else None
        if hi is None or hi <= lo:
            hi = lo + 1.5
        lo = max(lo, bounds[-1] + 0.3)
        a, b = int(lo * 100), max(int(hi * 100), int(lo * 100) + 1)
        seg = env[a:b] if b <= len(env) else env[a:]
        # the longest quiet stretch in between (the pause between two lines is
        # longer than the little pauses inside a line)
        q = a
        if len(seg):
            sm_env = np.convolve(seg, np.ones(5) / 5, 'same')
            quiet = sm_env < max(sm_env.min() * 2.5, env.max() * 0.025)
            best, k = (0, None), 0
            while k < len(quiet):
                if quiet[k]:
                    m = k
                    while m < len(quiet) and quiet[m]:
                        m += 1
                    if m - k >= best[0]:
                        best = (m - k, (k + m) // 2)
                    k = m
                else:
                    k += 1
            q = a + (best[1] if best[1] is not None else int(np.argmin(sm_env)))
        bounds.append(q / 100.0)
    bounds.append(len(x) / SR)
    thr = max(env.max() * 0.03, 10 ** (-48 / 20))
    parts = []
    for a, b in zip(bounds[:-1], bounds[1:]):
        p = x[int(a * SR):int(b * SR)]
        idx = np.where(np.abs(p) > thr)[0]
        if len(idx):
            p = p[max(idx[0] - int(0.03 * SR), 0): idx[-1] + int(0.06 * SR)]
        pad = np.zeros(int(0.08 * SR))
        parts.append(np.concatenate([pad, p, pad]))
    return parts


def main(folder):
    os.makedirs(OUT, exist_ok=True)
    lines = NL.lines()
    for num, sec in BLOCKS:
        keys = [k for s, k, _ in lines if s == sec]
        texts = [NL.spoken(t) for s, _, t in lines if s == sec]
        src = sorted(glob.glob(os.path.join(folder, num + '_*')))
        if not src:
            print('missing block', num)
            continue
        parts = cut(load(src[0]), texts, OVERRIDES.get(num))
        for k, p in zip(keys, parts):
            p = p / (np.sqrt((p ** 2).mean()) + 1e-9) * 0.1      # even loudness
            p = np.clip(p, -0.95, 0.95)
            wav = tempfile.mktemp(suffix='.wav')
            sf.write(wav, p.astype(np.float32), SR)
            subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', wav, '-c:a', 'libvorbis', '-q:a', '5',
                            os.path.join(OUT, k + '.ogg')], check=True)
            os.remove(wav)
            print('%-45s %.1f s' % (k, len(p) / SR))


if __name__ == '__main__':
    main(sys.argv[1])
