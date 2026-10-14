"""Picks the instrument samples for the story music out of the Versilian
Community Sample Library (VCSL, CC0 – https://github.com/sgossner/VCSL) and
stores them small: mono, 44.1 kHz, trimmed, faded, as .ogg in source/samples/.

  python3 levels/plush_desk/source/make_samples.py <path to a VCSL checkout>
"""
import os, re, sys, glob, subprocess, tempfile
import numpy as np
import soundfile as sf

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, 'samples')
SR = 44100

# name: (folder in VCSL, file pattern, note regex or None, longest length in s)
SETS = {
    'vibes':   ('Idiophones/Struck Idiophones/Vibraphone/Soft Mallets', 'Vibes_soft_*_v2_rr1_Main.wav', r'_([A-G]#?\d)_', 3.0),
    'glock':   ('Idiophones/Struck Idiophones/Glockenspiel', 'glock_soft_*.wav', r'_([A-G]#?\d)_', 2.5),
    'strum':   ('Chordophones/Composite Chordophones/Strumstick/Finger', '*_vl2_*.wav', r'_([A-G]#?\d)_vl', 2.0),
    'harp':    ('Chordophones/Composite Chordophones/Concert Harp', 'KSHarp_*_mf*.wav', r'_([A-G]#?\d)_', 2.5),
    'ocarina': ('Aerophones/Edge-blown Aerophones/Ocarina, Typical/Sustains/SusVib', 'StdOcarina_SusVib_*.wav', r'_([A-G]#?\d)\.wav', 3.0),
    'piano':   ('Chordophones/Zithers/Upright Piano, Yamaha/Sustains', 'Upright1_Sus_*_vl2_rr1.wav', r'_([A-G]#?\d)_vl', 3.0),
    'clap':    ('Idiophones/Struck Idiophones/Claps', 'Clap_rr*.wav', None, 0.5),
    'shaker':  ('Idiophones/Struck Idiophones/Shaker, Small', 'Mid_ShakerDouble_*.wav', None, 0.4),
    'kick':    ('Membranophones/Struck Membranophones/Bass Drum 1', 'BDrumNew_hit_v2_rr1_Sum.wav', None, 0.8),
    'wood':    ('Idiophones/Struck Idiophones/Woodblock', 'wood_click_mp.wav', None, 0.3),
    'snare':   ('Membranophones/Struck Membranophones/Snare Drum, Modern 1', 'Snare2_HitSN_v*_rr1_Mid.wav', None, 0.6),
}


def load(path):
    tmp = tempfile.mktemp(suffix='.wav')
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', path, '-ac', '1', '-ar', str(SR), tmp], check=True)
    x, _ = sf.read(tmp)
    os.remove(tmp)
    return x


def prep(x, longest):
    # start at the attack, keep at most `longest` seconds, fade the tail
    thr = np.abs(x).max() * 0.02
    i0 = max(int(np.argmax(np.abs(x) > thr)) - int(0.002 * SR), 0)
    x = x[i0:i0 + int(longest * SR)]
    f = min(int(0.25 * SR), len(x) // 3)
    x[-f:] *= np.linspace(1, 0, f) ** 2
    return x / (np.abs(x).max() + 1e-9) * 0.9


def main(vcsl):
    for name, (folder, pat, rx, longest) in SETS.items():
        files = sorted(glob.glob(os.path.join(vcsl, folder, pat)))
        d = os.path.join(OUT, name)
        os.makedirs(d, exist_ok=True)
        for k, f in enumerate(files):
            if rx:
                m = re.search(rx, os.path.basename(f))
                if not m:
                    continue
                key = m.group(1).replace('#', 's')
            else:
                key = '%02d' % k
            x = prep(load(f), longest)
            wav = tempfile.mktemp(suffix='.wav')
            sf.write(wav, x.astype(np.float32), SR)
            subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', wav, '-c:a', 'libvorbis', '-q:a', '5',
                            os.path.join(d, key + '.ogg')], check=True)
            os.remove(wav)
        print(name, len(os.listdir(d)))


if __name__ == '__main__':
    main(sys.argv[1])
