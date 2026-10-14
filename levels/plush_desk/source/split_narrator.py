"""Cuts the narrator recordings (one file per part of the chapter, see
narrator_elevenlabs.md) into one .ogg per line, named after the line keys,
into audio/narrator/.

  python3 levels/plush_desk/source/split_narrator.py <folder with 01_guestbook.mp3 … 08_finale.mp3>

Each block is cut at its longest pauses (as many cuts as it has lines, less one),
trimmed, given 0.08 s of air at both ends and evened out in loudness.
(needs numpy, soundfile and ffmpeg)
"""
import os, sys, glob, subprocess, tempfile
import numpy as np
import soundfile as sf

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import narrator_lines as NL

OUT = os.path.join(HERE, '..', 'audio', 'narrator')
BLOCKS = [('01', 'sec_arrival'), ('02', 'sec_meadow'), ('03', 'sec_clouds'), ('04', 'sec_patches'),
          ('05', 'sec_machine'), ('06', 'sec_choice'), ('07', 'sec_tower'), ('08', 'sec_finale')]
SR = 44100


def load(path):
    tmp = tempfile.mktemp(suffix='.wav')
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', path, '-ac', '1', '-ar', str(SR), tmp], check=True)
    x, _ = sf.read(tmp)
    os.remove(tmp)
    return x


def cut(x, n):
    """the n-1 longest quiet stretches between speech"""
    hop = int(0.01 * SR)
    env = np.array([np.sqrt((x[i:i + hop] ** 2).mean()) for i in range(0, len(x) - hop, hop)])
    thr = max(env.max() * 0.03, 10 ** (-48 / 20))
    quiet = env < thr
    runs, i = [], 0
    while i < len(quiet):
        if quiet[i]:
            j = i
            while j < len(quiet) and quiet[j]:
                j += 1
            if i > 0 and j < len(quiet):
                runs.append((j - i, i, j))
            i = j
        else:
            i += 1
    runs = sorted(sorted(runs, reverse=True)[:n - 1], key=lambda r: r[1])
    if len(runs) < n - 1:
        raise SystemExit('only %d pauses found, need %d' % (len(runs), n - 1))
    bounds = [0] + [((a + b) // 2) * hop for _, a, b in runs] + [len(x)]
    parts = []
    for a, b in zip(bounds[:-1], bounds[1:]):
        p = x[a:b]
        e = np.abs(p) > thr
        idx = np.where(e)[0]
        p = p[max(idx[0] - int(0.03 * SR), 0): idx[-1] + int(0.06 * SR)]
        pad = np.zeros(int(0.08 * SR))
        parts.append(np.concatenate([pad, p, pad]))
    return parts


def main(folder):
    os.makedirs(OUT, exist_ok=True)
    lines = NL.lines()
    for num, sec in BLOCKS:
        keys = [k for s, k, _ in lines if s == sec]
        src = sorted(glob.glob(os.path.join(folder, num + '_*')))
        if not src:
            print('missing block', num)
            continue
        parts = cut(load(src[0]), len(keys))
        for k, p in zip(keys, parts):
            p = p / (np.sqrt((p ** 2).mean()) + 1e-9) * 0.08     # even loudness
            p = np.clip(p, -0.95, 0.95)
            wav = tempfile.mktemp(suffix='.wav')
            sf.write(wav, p.astype(np.float32), SR)
            subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', wav, '-c:a', 'libvorbis', '-q:a', '5',
                            os.path.join(OUT, k + '.ogg')], check=True)
            os.remove(wav)
            print('%-45s %.1f s' % (k, len(p) / SR))


if __name__ == '__main__':
    main(sys.argv[1])
