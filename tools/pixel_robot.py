"""Pixel-art Claude robot for the 2D attic, at the film's native resolution
(1 art pixel = 5 screen pixels at 1080p). Faces right; the game flips it for
left. Writes assets/hub/robot_sheet.png (frames side by side) and
assets/hub/robot_portraits.png (dialog face close-ups).

The head is the film's own (tools/robot_src/head_*.png, taken pixel-exact
from film frames by tools/robot_src/extract_head.py); the faces, the antenna
and the body (with the walk cycle) are drawn here in the film's colours and
proportions: a big white box head with a dark screen, a small round
terracotta body with a white badge, thin arms with round white hands and two
short legs.

Run: python3 tools/pixel_robot.py
"""
import os

import numpy as np
from PIL import Image

FW, FH = 38, 54          # frame size (the game expects this, feet at (19, 50))
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, '..', 'assets', 'hub')
SRC = os.path.join(HERE, 'robot_src')
HEAD_AT = (2, 6)         # where the head image sits in a frame


def hexc(h, a=255):
    h = h.lstrip('#')
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


# colours sampled from the film
P = {
    # body (terracotta), lit from the left
    'b0': hexc('ffc0a0'), 'b1': hexc('fc9a78'), 'b2': hexc('e8825f'), 'b3': hexc('dd7252'),
    'b4': hexc('bc5839'), 'b5': hexc('8c4031'), 'bo': hexc('5c2416'), 'bs': hexc('591f10'),
    # badge
    'd1': hexc('f6efe0'), 'd2': hexc('e6d2ad'), 'd3': hexc('b7a890'), 'd4': hexc('dd715f'),
    # hands
    'h1': hexc('fffbf1'), 'h2': hexc('e5ceb5'), 'h3': hexc('b9a48e'), 'ho': hexc('645a43'),
    # feet
    'f1': hexc('ffc5a4'), 'f2': hexc('f49b80'), 'f3': hexc('d97356'), 'f4': hexc('b55b30'),
    # status light
    'p1': hexc('7e57cf'), 'p2': hexc('aa8cee'),
    # screen and faces
    'sc': hexc('181720'), 'e1': hexc('ffeed4'), 'e2': hexc('fbcaa6'), 'e3': hexc('fff8ec'),
    'eh': hexc('3e2a24'), 'eh2': hexc('5a3d36'), 'bl': hexc('964a61'),
    'st1': hexc('ffe27a'), 'st2': hexc('ffb935'), 'st3': hexc('fffbe8'), 'sg': hexc('4a3020'),
    # antenna
    'a1': hexc('f2c35a'), 'a2': hexc('c98b2f'), 'k1': hexc('fff3dc'), 'k2': hexc('ffa07a'), 'k3': hexc('f06a5a'),
}


class Canvas:
    def __init__(self, w=FW, h=FH):
        self.a = np.zeros((h, w, 4), np.uint8)
        self.w, self.h = w, h

    def px(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.a[y, x] = P[c] if isinstance(c, str) else c

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.px(x, y, c)

    def rows(self, x0, y0, art, pal):
        """draw ASCII art: one char per pixel, '.' = transparent"""
        for j, row in enumerate(art):
            for i, ch in enumerate(row):
                if ch != '.':
                    self.px(x0 + i, y0 + j, pal[ch])

    def mask(self):
        return self.a[..., 3] > 0


def outline(layer, color):
    m = layer.mask()
    o = np.zeros_like(m)
    o[1:, :] |= m[:-1, :]
    o[:-1, :] |= m[1:, :]
    o[:, 1:] |= m[:, :-1]
    o[:, :-1] |= m[:, 1:]
    o &= ~m
    layer.a[o] = P[color]


def comp(dst, src, dx=0, dy=0):
    m = src.a[..., 3] > 0
    ys, xs = np.nonzero(m)
    for y, x in zip(ys, xs):
        if 0 <= x + dx < dst.w and 0 <= y + dy < dst.h:
            dst.a[y + dy, x + dx] = src.a[y, x]


# ------------------------------------------------------------------ head
def load_head(name):
    a = np.asarray(Image.open(os.path.join(SRC, 'head_%s.png' % name)).convert('RGBA')).copy()
    a[12, 22] = P['sc']          # a stray sparkle from the film on the screen
    return a


# the screen (in head-image coordinates) and the eyes' places in it
SCR = (12, 11, 29, 20)           # inside of the screen, x0 y0 x1 y1
EYES = (17, 25)                  # left x of each eye (4 wide), rows 13..18


def blank_screen(h):
    x0, y0, x1, y1 = SCR
    h[y0:y1 + 1, x0:x1 + 1] = P['sc']
    return h


def put(h, x, y, c):
    h[y, x] = P[c]


def face(eyes):
    if eyes == 'normal':
        return load_head('normal')
    if eyes == 'happy':
        return load_head('happy')
    h = blank_screen(load_head('normal'))
    for ex in EYES:
        if eyes == 'blink':
            for x in range(ex, ex + 4):
                put(h, x, 16, 'eh'); put(h, x, 18, 'eh')
                put(h, x, 17, 'e1')
            put(h, ex - 1, 17, 'eh'); put(h, ex + 4, 17, 'eh')
            put(h, ex + 1, 18, 'e2'); put(h, ex + 2, 18, 'e2')
        elif eyes == 'sparkle':
            # a four-pointed star in each eye, like when Claude learns to dream
            star = ['...o...',
                    '..oYo..',
                    '.oYWYo.',
                    'oYWWWYo',
                    '.oYWYo.',
                    '..oYo..',
                    '...o...']
            for j, row in enumerate(star):
                for i, ch in enumerate(row):
                    if ch != '.':
                        put(h, ex - 1 + i, 12 + j, {'o': 'st2', 'Y': 'st1', 'W': 'st3'}[ch])
        elif eyes == 'wide':
            # round "O" eyes (surprised), like in the film's second part
            for (x, y) in [(1, 0), (2, 0), (0, 1), (3, 1), (0, 2), (3, 2), (0, 3), (3, 3), (0, 4), (3, 4), (1, 5), (2, 5)]:
                put(h, ex + x, 13 + y, 'e1')
            for (x, y) in [(1, -1), (2, -1), (-1, 1), (4, 1), (-1, 4), (4, 4), (1, 6), (2, 6)]:
                put(h, ex + x, 13 + y, 'eh')
            put(h, ex + 1, 13 + 4, 'e2'); put(h, ex + 2, 13 + 4, 'e2')
    return h


def antenna(c, dy):
    x = HEAD_AT[0] + 18
    for y in range(4, 8):
        c.px(x, y + dy, 'a1')
    c.px(x + 1, 6 + dy, 'a2'); c.px(x + 1, 7 + dy, 'a2')
    ty = 2 + dy
    c.px(x, ty, 'k1')
    for (ox, oy) in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
        c.px(x + ox, ty + oy, 'k2')
    for (ox, oy) in [(-2, 0), (2, 0), (0, -2), (-1, -1), (1, -1), (-1, 1), (1, 1)]:
        c.px(x + ox, ty + oy, 'k3')


# ------------------------------------------------------------------ body
TORSO = [
    # frame x 10..27, rows 31..40: a small round body lit from the left, the
    # white badge on the right half, a dark band in the head's shadow
    '.11ssssssssssss45.',
    '01122222DDDD22345.',
    '0112222DDDDDD2345.',
    '011222DDDDDDDD345.',
    '011222DDDXDDDD345.',
    '011233DDXXXDDd345.',
    '.11333dDDXDDdd345.',
    '.113333dddddd3445.',
    '..13333333dd3445..',
    '...4444455544455..',
]
TORSO_PAL = {'0': 'b0', '1': 'b1', '2': 'b2', '3': 'b3', '4': 'b4', '5': 'b5', 's': 'bs', 'o': 'bo',
             'D': 'd1', 'd': 'd3', 'X': 'd4'}
HAND = [
    '.LLLo.',
    'L1112o',
    'L1122o',
    'o1223o',
    '.oooo.',
]
HAND_PAL = {'L': 'h3', 'o': 'ho', '1': 'h1', '2': 'h2', '3': 'h3'}


def leg(c, x, top, bot, far):
    """a short round leg (4 wide) from top to bot, with its foot"""
    lo, mid, hi = ('b5', 'b4', 'b3') if far else ('b4', 'b3', 'b1')
    for y in range(top, bot - 2):
        c.px(x, y, hi); c.px(x + 1, y, mid); c.px(x + 2, y, mid); c.px(x + 3, y, lo)
    # foot, a little wider, pointing to the right
    fy = bot - 2
    f1, f2, f3 = ('f2', 'f3', 'f4') if far else ('f1', 'f2', 'f3')
    rows = ['.AAAAA.', 'ABBBBBB', '.CCCCCC']
    c.rows(x - 1, fy, rows, {'A': f1, 'B': f2, 'C': f3})


def arm(c, path, by, cols):
    """a 2 px thick arm: path = [(left x, row below the shoulder), ...]"""
    for (x, r) in path:
        c.px(x, by + r, cols[0]); c.px(x + 1, by + r, cols[1])
    outline(c, 'bo')


def body(phase=None, dy=0, arms='down'):
    far = Canvas(); legs = Canvas(); torso = Canvas(); near = Canvas()
    by = 31 + dy
    # walk cycle: [left foot dx, right foot dx], [left lift, right lift]
    step = {None: (0, 0), 0: (-2, 2), 1: (0, 0), 2: (2, -2), 3: (0, 0)}[phase]
    lift = {None: (0, 0), 0: (0, 0), 1: (1, 0), 2: (0, 0), 3: (0, 1)}[phase]
    swing = {None: 0, 0: 1, 1: 0, 2: -1, 3: 0}[phase]
    # the far leg (right in the picture) first, then the near one
    leg(legs, 22 + step[1], by + 10, 50 - lift[1], True)
    leg(legs, 13 + step[0], by + 10, 50 - lift[0], False)
    outline(legs, 'bo')
    torso.rows(10, by, TORSO, TORSO_PAL)
    outline(torso, 'bo')
    torso.px(16, by + 8, 'p1'); torso.px(17, by + 8, 'p2')        # the little status light
    # short arms from the shoulders, down and out to round white hands
    if arms == 'down':
        arm(far, [(27, 1), (28, 2), (28, 3), (29 - swing, 4), (29 - swing, 5)], by, ('b4', 'b5'))
        far.rows(28 - swing, by + 5, HAND, HAND_PAL)
        arm(near, [(9, 1), (8, 2), (8, 3), (7 + swing, 4), (7 + swing, 5)], by, ('b0', 'b2'))
        near.rows(3 + swing, by + 6, HAND, HAND_PAL)
    # (cheering: the hands are drawn next to the head, see frame())
    out = Canvas()
    for l in (legs, far, torso, near):
        comp(out, l)
    return out


def frame(eyes='normal', phase=None, bob=0, arms='down'):
    c = Canvas()
    comp(c, body(phase, bob, arms))
    h = Canvas(36, 26)
    h.a = face(eyes)
    comp(c, h, HEAD_AT[0], HEAD_AT[1] + bob)
    antenna(c, bob)
    if arms == 'up':   # cheering: both hands up beside the face
        c.rows(0, 17 + bob, HAND, HAND_PAL)
        c.rows(32, 16 + bob, HAND, HAND_PAL)
    return c


FRAMES = [
    ('idle0', dict()),
    ('idle1', dict(bob=1)),
    ('blink', dict(eyes='blink')),
    ('happy', dict(eyes='happy')),
    ('sparkle', dict(eyes='sparkle')),
    ('walk0', dict(phase=0)),
    ('walk1', dict(phase=1, bob=1)),
    ('walk2', dict(phase=2)),
    ('walk3', dict(phase=3, bob=1)),
    ('wide', dict(eyes='wide')),
    ('cheer', dict(eyes='happy', arms='up', bob=-1)),
]


def build():
    sheet = np.zeros((FH, FW * len(FRAMES), 4), np.uint8)
    for i, (name, kw) in enumerate(FRAMES):
        sheet[:, i * FW:(i + 1) * FW] = frame(**kw).a
    Image.fromarray(sheet).save(os.path.join(ROOT, 'robot_sheet.png'))
    # dialog portraits: the screen face, cropped from the head
    ports = [face(e)[8:23, 8:33] for e in ('normal', 'happy', 'sparkle', 'wide')]
    Image.fromarray(np.concatenate(ports, 1)).save(os.path.join(ROOT, 'robot_portraits.png'))
    print('frames:', [n for n, _ in FRAMES])


if __name__ == '__main__':
    build()
