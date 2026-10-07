"""Takes Claude's head straight from the film (pixel-exact): samples two film
frames back onto the 5 px art grid and cuts the head out. Writes
tools/robot_src/head_normal.png and head_happy.png, which tools/pixel_robot.py
builds the attic sprite from. Needs the original video and ffmpeg:

  python3 tools/robot_src/extract_head.py "<original video file>"

The two PNGs are committed, so this only has to run again if the cut changes.
"""
import os
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
# film time, and the crop (1080p screen px, a multiple of 5) where Claude stands
SHOTS = {'normal': 76.7, 'happy': 77.3}
CROP = (450, 640, 240, 300)          # x, y, w, h
# the head inside the sampled crop (art px): rows 9..31, [left, right] per row
SPANS = {9: (17, 33), 10: (15, 35), 11: (14, 37), 12: (13, 38), 13: (12, 40), 14: (12, 41),
         15: (12, 42), 16: (12, 43), 17: (12, 43), 18: (12, 43), 19: (12, 43), 20: (12, 43),
         21: (12, 43), 22: (12, 43), 23: (12, 43), 24: (12, 43), 25: (12, 43), 26: (13, 43),
         27: (14, 43), 28: (15, 43), 29: (17, 42), 30: (19, 41), 31: (22, 40)}
X0, Y0 = 10, 7                        # top-left of the saved head image in the crop
W, H = 36, 26


def frame(video, t):
    with tempfile.TemporaryDirectory() as d:
        out = os.path.join(d, 'f.png')
        x, y, w, h = CROP
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-ss', str(t), '-i', video, '-frames:v', '1',
                        '-vf', f'crop={w}:{h}:{x}:{y}', out], check=True)
        return np.asarray(Image.open(out).convert('RGB'))


def sample(a):
    ny, nx = a.shape[0] // 5, a.shape[1] // 5
    out = np.zeros((ny, nx, 3), np.uint8)
    for j in range(ny):
        for i in range(nx):
            out[j, i] = np.median(a[j * 5 + 1:j * 5 + 4, i * 5 + 1:i * 5 + 4].reshape(-1, 3), axis=0)
    return out


def cut(s):
    img = np.zeros((H, W, 4), np.uint8)
    for y, (l, r) in SPANS.items():
        for x in range(l, r + 1):
            img[y - Y0, x - X0, :3] = s[y, x]
            img[y - Y0, x - X0, 3] = 255
    return img


if __name__ == '__main__':
    video = sys.argv[1]
    for name, t in SHOTS.items():
        img = cut(sample(frame(video, t)))
        Image.fromarray(img).save(os.path.join(HERE, f'head_{name}.png'))
        print('wrote head_%s.png' % name)
