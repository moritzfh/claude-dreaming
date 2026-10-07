"""Moritz' Sternwarte – a starry observatory room in the attic, in the
spirit of a certain galaxy-hopping plumber's observatory: night-blue walls
with little gold stars, a big round window full of planets, a brass
telescope, a gramophone, a window seat and a round rug with a star.

Native pixel art like the rest of the attic: 216 px high, one art pixel =
5 screen pixels at 1080p, same floor and wall lines as the corridor (wall
down to y 145, baseboard 145-152, floor from 153). Things that move (the
planet mobile, twinkling stars, the comet) are added by ../room.gd.

Run from the repo root:  python3 rooms/moritz/source/make_room.py
Writes rooms/moritz/room.png
"""
import os
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', 'room.png')
W, H = 320, 216
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]], np.float32) / 16.0 + 1 / 32.0


def hexc(h):
    h = h.lstrip('#')
    return np.array([int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)], np.uint8)


def ramp(*hs):
    return np.stack([hexc(h) for h in hs])


def dith(rmp, level, x, y):
    lv = np.clip(level, 0, len(rmp) - 1.001)
    i = np.floor(lv).astype(int)
    f = lv - i
    t = BAYER[np.asarray(y) % 4, np.asarray(x) % 4]
    return rmp[np.where(f > t, np.minimum(i + 1, len(rmp) - 1), i)]


NIGHT = ramp('#0a0922', '#111033', '#181845', '#1f2157', '#282b6a', '#31377d', '#3c4590', '#4a55a4', '#5b68b8')
CEIL = ramp('#07061a', '#0d0c28', '#141336', '#1b1b45')
FLOOR = ramp('#120b1d', '#1a1027', '#231632', '#2d1c3d', '#372248', '#422953', '#4e315f', '#5b3a6b', '#694476', '#784f80')
WOOD = ramp('#24101a', '#3a1a24', '#5a2a2e', '#7c3c36', '#a2553f', '#c87a52')
GOLD = ramp('#3d2410', '#6e4518', '#a8742a', '#d4a24a', '#f2d27a', '#fff0b8')
BRASS = ramp('#3a2408', '#6a4612', '#9c6c1e', '#c99a36', '#e9c45e', '#fff0a8')
SPACE = ramp('#05041a', '#0b0a2c', '#14113f', '#211654', '#30196a', '#45207c', '#5c2a88')
VELVET = ramp('#2a0f3a', '#3f1752', '#58206b', '#732a84', '#903a9c', '#ad52b2')
RUGC = {'edge': hexc('#0f0e30'), 'blue': hexc('#1f2466'), 'blue2': hexc('#2a3282'), 'trim': hexc('#d4a24a'),
        'star': hexc('#f2d27a'), 'star2': hexc('#fff0b8'), 'dots': hexc('#5b68b8')}

FONT = {
    'A': ['010', '101', '111', '101', '101'], 'E': ['111', '100', '110', '100', '111'], 'I': ['111', '010', '010', '010', '111'],
    'M': ['101', '111', '111', '101', '101'], 'N': ['101', '111', '111', '111', '101'], 'O': ['010', '101', '101', '101', '010'],
    'R': ['110', '101', '110', '101', '101'], 'S': ['011', '100', '010', '001', '110'], 'T': ['111', '010', '010', '010', '010'],
    'W': ['101', '101', '111', '111', '101'], 'Z': ['111', '001', '010', '100', '111'], "'": ['010', '010', '000', '000', '000'],
    ' ': ['000', '000', '000', '000', '000'],
}

STAR5 = ['....#....', '....#....', '...###...', '#########', '.#######.', '..#####..', '..##.##..', '.##...##.', '.#.....#.']


def star_points(cx, cy, r_out, r_in, rot=-np.pi / 2):
    pts = []
    for i in range(10):
        a = rot + i * np.pi / 5
        r = r_out if i % 2 == 0 else r_in
        pts.append((cx + np.cos(a) * r, cy + np.sin(a) * r))
    return pts


def in_poly(x, y, pts):
    inside = False
    n = len(pts)
    for i in range(n):
        x1, y1 = pts[i]; x2, y2 = pts[(i + 1) % n]
        if (y1 > y) != (y2 > y) and x < (x2 - x1) * (y - y1) / (y2 - y1 + 1e-9) + x1:
            inside = not inside
    return inside


def build():
    img = np.zeros((H, W, 3), np.uint8)
    yy, xx = np.mgrid[0:H, 0:W]
    rng = np.random.default_rng(42)

    # ------------------------------------------------ light: window (cool), lamps (warm)
    WIN = (88, 82, 34)                                   # round window: centre, radius
    LAMPS = [(30, 50, 0.55), (218, 52, 0.5), (280, 52, 0.5)]   # star lamp, two picture lamps
    cool = np.exp(-(((xx - WIN[0]) / 60.0) ** 2 + ((yy - WIN[1]) / 70.0) ** 2)) * 0.55
    warm = np.zeros((H, W), np.float32)
    for lx, ly, s in LAMPS:
        warm += s * np.exp(-(((xx - lx) / 30.0) ** 2 + ((yy - (ly + 18)) / 36.0) ** 2)) * (yy > ly - 4)
    base = 0.30 + 0.12 * (yy / H)

    # ------------------------------------------------ wall: night blue, a wallpaper of little gold stars
    wl = (base + cool * 0.9 + warm * 0.6) * (len(NIGHT) - 1) * 0.95
    img[:] = dith(NIGHT, wl, xx, yy)
    for gy in range(34, 140, 14):
        for gx in range(6 + (gy // 14 % 2) * 9, W, 18):
            lvl = wl[gy, min(gx, W - 1)]
            c = GOLD[2] if lvl < 4 else GOLD[3]
            for dx, dy in [(0, 0), (-1, 0), (1, 0), (0, -1), (0, 1)]:
                x, y = gx + dx, gy + dy
                if 0 <= x < W and (dx == 0 and dy == 0 or (x + y) % 2 == 0):
                    img[y, x] = c if (dx, dy) == (0, 0) else (img[y, x].astype(np.int32) * 0.4 + c * 0.6).astype(np.uint8)
    # a gold rail along the wall (chair rail)
    for x in range(W):
        img[122, x] = GOLD[1]; img[123, x] = GOLD[3] if x % 9 else GOLD[4]; img[124, x] = GOLD[1]
    # lower wall a bit darker, with vertical panels
    for y in range(125, 145):
        for x in range(W):
            lv = wl[y, x] - 1.1 - (0.6 if x % 32 in (0, 1) else 0)
            img[y, x] = dith(NIGHT, np.array(lv), np.array(x), np.array(y))
            if x % 32 == 0: img[y, x] = NIGHT[0]

    # ------------------------------------------------ ceiling: dark boards with painted stars, a beam with gold trim
    for y in range(0, 17):
        plank = y // 4
        for x in range(W):
            seam = y % 4 == 3 or (x + plank * 37) % 53 == 0
            lv = 1.6 + ((plank * 7 + (x + plank * 37) // 53 * 3) % 4) * 0.35
            img[y, x] = CEIL[0] if seam else dith(CEIL, np.array(lv), np.array(x), np.array(y))
    for _ in range(46):
        x, y = rng.integers(2, W - 2), rng.integers(1, 15)
        img[y, x] = GOLD[4] if rng.random() < 0.5 else hexc('#c8d0ff')
    for rx in range(4, W, 44):                           # rafters
        for y in range(0, 17):
            for x in range(rx, min(W, rx + 4)):
                img[y, x] = WOOD[[1, 3, 2, 1][x - rx]]
    prof = [0, 2, 4, 4, 3, 3, 2, 1, 0]
    for k, y in enumerate(range(16, 25)):
        for x in range(W):
            img[y, x] = WOOD[prof[k]]
    for x in range(W):
        img[19, x] = GOLD[3] if x % 6 else GOLD[4]; img[22, x] = GOLD[1]

    # ------------------------------------------------ baseboard (dark wood, gold line)
    for x in range(W):
        img[145, x] = GOLD[1]
        for y in range(146, 152):
            img[y, x] = dith(WOOD, np.array(1.4 + (cool[150, x] + warm[150, x]) * 2.2 - (y - 146) * 0.15), np.array(x), np.array(y))
        img[152, x] = WOOD[0]

    # ------------------------------------------------ floor: boards in perspective, night-tinted
    vy, KL, LU = 104.0, 523.0, 1.7
    vxw = W / 2.0
    for y in range(153, H):
        d = y - vy
        k = KL / d
        row = int(np.floor(k))
        seam = int(np.floor(KL / (d + 1))) != row
        off = np.random.default_rng(row * 977 + 11).random() * LU
        for x in range(W):
            u = (x - vxw) / d + off
            seg = int(np.floor(u / LU))
            joint = int(np.floor(((x + 1 - vxw) / d + off) / LU)) != seg
            tone = 4.2 + (((row * 31 + seg * 17) * 2654435761) % 1000) / 1000.0 * 1.8 - 0.9
            gh = ((row * 7919 + seg * 104729 + int(round((k - row) * 6)) * 31 + (x // 5) * 3) * 2654435761) % 1000 / 1000.0
            tone += (gh - 0.5) * 0.8
            # moonlight pool under the window, warm pools under the lamps
            pool = np.exp(-(((x - WIN[0] - (y - 153) * 0.45) / 30.0) ** 2)) * np.exp(-((y - 175) / 30.0) ** 2) * 2.2
            lamp = sum(1.2 * s * np.exp(-(((x - lx) / 24.0) ** 2 + ((y - 158) / 8.0) ** 2)) for lx, _, s in LAMPS)
            lv = tone - 1.6 + pool + lamp
            if seam: c = FLOOR[max(0, int(lv) - 3)]
            elif joint: c = FLOOR[max(0, int(lv) - 2)]
            else: c = dith(FLOOR, np.array(lv), np.array(x), np.array(y))
            img[y, x] = c

    # ------------------------------------------------ round rug with a big star
    rcx, rcy, rrx, rry = 152, 188, 70, 17
    stp = star_points(rcx, rcy, 15, 6.5)
    stp = [(px, rcy + (py - rcy) * 0.32) for px, py in stp]      # squashed by perspective
    for y in range(rcy - rry - 1, rcy + rry + 2):
        for x in range(rcx - rrx - 1, rcx + rrx + 2):
            q = ((x - rcx) / rrx) ** 2 + ((y - rcy) / rry) ** 2
            if q > 1.0: continue
            if q > 0.86: c = RUGC['edge']
            elif q > 0.74: c = RUGC['trim'] if (x // 2) % 2 else GOLD[2]
            elif q > 0.66: c = RUGC['blue']
            else:
                c = RUGC['blue2'] if (x + y) % 2 else RUGC['blue']
                h = (x * 73856093 ^ y * 19349663) % 61
                if h == 0: c = RUGC['dots']
                if h == 1: c = RUGC['star2']
            if in_poly(x + 0.5, y + 0.5, stp):
                c = RUGC['star2'] if y < rcy - 1 else RUGC['star']
            pool = np.exp(-(((x - WIN[0] - (y - 153) * 0.45) / 30.0) ** 2)) * np.exp(-((y - 175) / 30.0) ** 2)
            if BAYER[y % 4, x % 4] > 0.55 + pool * 0.6:
                c = (c.astype(np.float32) * 0.8).astype(np.uint8)
            img[y, x] = c

    # ------------------------------------------------ the big round window
    cx, cy, R = WIN
    planets = [(-12, 14, 11, 'ring'), (17, -15, 6, 'green'), (22, 13, 3, 'pink')]
    for y in range(cy - R - 5, cy + R + 6):
        for x in range(cx - R - 5, cx + R + 6):
            d = np.hypot(x - cx, y - cy)
            if d <= R:
                t = (y - (cy - R)) / (2 * R)
                neb = np.sin(x * 0.11 + y * 0.07) * 0.5 + np.sin(x * 0.05 - y * 0.13) * 0.5
                c = dith(SPACE, np.array(1.0 + t * 2.2 + neb * 1.3 + max(0, 1 - d / R) * 0.6), np.array(x), np.array(y))
                h = (x * 73856093 ^ y * 19349663) % 1000
                if h < 12: c = hexc('#fff6d8') if h < 5 else hexc('#b9c8ff')
                for (px, py, pr, kind) in planets:
                    pd = np.hypot(x - cx - px, y - cy - py)
                    if pd <= pr:
                        sh = ((x - cx - px) + (y - cy - py)) / pr      # light from the top left
                        if kind == 'ring':
                            band = int((y - cy - py + pr) * 0.9) % 3
                            P = ramp('#5a2410', '#8e3a1c', '#c8622a', '#ee9a4a', '#ffd08a')
                            c = P[int(np.clip(3.4 - sh * 1.4 - band * 0.6, 0, 4))]
                        elif kind == 'green':
                            P = ramp('#123a2a', '#1f6a3a', '#3fa04a', '#86d86a', '#cfffa0')
                            c = P[int(np.clip(3.0 - sh * 1.5 - ((x * 7 + y * 3) % 5 == 0), 0, 4))]
                        else:
                            P = ramp('#5a1a4a', '#9a3a7a', '#e070a8', '#ffb8d8')
                            c = P[int(np.clip(2.4 - sh * 1.2, 0, 3))]
                # the ring planet's ring
                rx, ry = x - cx - planets[0][0], y - cy - planets[0][1]
                rr = ((rx * 0.96 + ry * 0.28) / 19.0) ** 2 + ((-rx * 0.28 + ry * 0.96) / 4.2) ** 2
                if 0.62 < rr < 1.0 and not (np.hypot(rx, ry) <= planets[0][2] and (-rx * 0.28 + ry * 0.96) < 0):
                    c = hexc('#f2d27a') if rr < 0.8 else hexc('#c99a36')
                # a comet streak
                u = (x - cx + 20) * 0.8 - (y - cy + 22) * 0.6
                v = (x - cx + 20) * 0.6 + (y - cy + 22) * 0.8
                if -18 < u < 0 and abs(v) < 0.6 + (u + 18) * 0.04:
                    k = (u + 18) / 18.0
                    c = (c.astype(np.float32) * (1 - k * 0.8) + hexc('#bfe8ff') * k * 0.8).astype(np.uint8)
                if np.hypot(x - cx + 20, y - cy + 22) < 1.2: c = hexc('#ffffff')
                img[y, x] = c
            elif d <= R + 5:
                ring = int(d - R)
                lit = (x - cx) + (y - cy) < 0
                c = BRASS[[5, 4, 3, 2, 1, 0][min(5, ring + (0 if lit else 1))]] if ring < 5 else BRASS[0]
                # rivets
                a = np.arctan2(y - cy, x - cx)
                if ring == 2 and int((a + np.pi) / (2 * np.pi) * 24 + 0.5) % 2 == 0 and abs(((a + np.pi) / (2 * np.pi) * 24) % 1 - 0.5) > 0.42:
                    c = BRASS[5]
                img[y, x] = c
    # thin brass cross in the window
    for k in range(-R + 1, R):
        for (x, y) in ((cx + k, cy), (cx, cy + k)):
            if np.hypot(x - cx, y - cy) < R: img[y, x] = BRASS[2] if (x + y) % 2 else BRASS[3]

    # ------------------------------------------------ window seat with a velvet cushion
    sx0, sx1 = 58, 118
    for y in range(126, 152):
        for x in range(sx0, sx1 + 1):
            if y < 131:                                   # cushion
                e = min(x - sx0, sx1 - x)
                c = dith(VELVET, np.array(3.2 - (y - 126) * 0.4 + (0.6 if e < 2 else 0) + (x % 12 == 0) * -0.8), np.array(x), np.array(y))
                if y == 126 or e == 0: c = VELVET[0]
            elif y < 133:
                c = GOLD[3] if y == 131 else GOLD[1]
            else:                                         # wooden box with panels
                pan = (x - sx0) % 20
                c = WOOD[2] if 2 < pan < 18 and 135 < y < 149 else WOOD[3]
                if pan in (0, 1) or y in (133, 151): c = WOOD[1]
            img[y, x] = c
    for x in (64, 86, 108):                               # little star cushions
        for dy, row in enumerate(['.#.', '###', '#.#']):
            for dx, ch in enumerate(row):
                if ch == '#': img[123 + dy, x + dx] = GOLD[4] if dy == 0 else GOLD[3]

    # ------------------------------------------------ brass telescope on a wooden tripod, aimed at the window
    mx, my = 148, 112                                     # mount
    for (fx, fy) in ((134, 155), (148, 157), (162, 155)):
        for t in np.linspace(0, 1, 60):
            x = int(round(mx + (fx - mx) * t)); y = int(round(my + 2 + (fy - my - 2) * t))
            img[y, x] = WOOD[3]; img[y, x + 1] = WOOD[1]
    for x in range(144, 153):
        img[my + 1, x] = BRASS[2]; img[my + 2, x] = BRASS[1]
    tx0, ty0, tx1, ty1 = 160, 116, 124, 92               # eyepiece end -> objective end
    L = np.hypot(tx1 - tx0, ty1 - ty0)
    ux, uy = (tx1 - tx0) / L, (ty1 - ty0) / L
    nx, ny = -uy, ux
    for y in range(80, 124):
        for x in range(116, 168):
            px, py = x - tx0, y - ty0
            s = px * ux + py * uy
            r = px * nx + py * ny
            if 0 <= s <= L:
                rad = 2.2 + s / L * 1.8                   # tube widens towards the objective
                if s > L - 4: rad += 0.9                   # dew cap
                if abs(r) <= rad:
                    k = (r / rad + 1) / 2                  # 0..1 across the tube
                    lv = 4.6 - abs(k - 0.3) * 5.0
                    if abs(s - L * 0.45) < 1.2 or abs(s - (L - 4)) < 0.8: lv -= 1.6   # bands
                    img[y, x] = BRASS[int(np.clip(lv, 0, 5))]
    # eyepiece and the glass
    img[117:119, 160:163] = BRASS[1]
    img[90:93, 121] = hexc('#bfe8ff'); img[91, 122] = hexc('#ffffff')

    # ------------------------------------------------ gramophone on a little round table (left)
    gx = 30
    for x in range(gx - 12, gx + 13):                     # table top
        img[128, x] = WOOD[0]; img[129, x] = WOOD[4] if x % 5 else WOOD[5]; img[130, x] = WOOD[2]; img[131, x] = WOOD[0]
    for y in range(132, 156):                             # pedestal
        for x in range(gx - 1, gx + 2):
            img[y, x] = WOOD[[1, 3, 2][x - gx + 1]]
    for x in range(gx - 6, gx + 7):
        img[155, x] = WOOD[1]; img[156, x] = WOOD[0]
    for y in range(120, 128):                             # wooden box
        for x in range(gx - 8, gx + 9):
            img[y, x] = WOOD[3] if y > 120 else WOOD[5]
            if x in (gx - 8, gx + 8) or y == 127: img[y, x] = WOOD[1]
    img[118:120, gx - 6:gx + 4] = hexc('#1a1020')        # record
    img[118, gx - 1] = GOLD[4]
    # the horn: a short neck up from the box, then a big bell opening up and to the right
    for y in range(108, 118):                             # neck
        img[y, gx + 3] = BRASS[2]; img[y, gx + 4] = BRASS[4]; img[y, gx + 5] = BRASS[2]
    bcx, bcy, ang = gx + 12, 98, np.radians(-35)          # bell opening: centre, tilt
    ca, sa = np.cos(ang), np.sin(ang)
    for y in range(86, 112):
        for x in range(gx, gx + 26):
            # position along the horn axis (0 at the neck, 1 at the opening) and across it
            ax, ay = bcx - (gx + 4), bcy - 108
            al = np.hypot(ax, ay)
            px, py = x - (gx + 4), y - 108
            s_ = (px * ax + py * ay) / al / al
            r_ = abs(px * -ay + py * ax) / al
            if 0 <= s_ <= 1 and r_ <= 1.2 + 7.5 * s_ ** 2.2:
                k = r_ / (1.2 + 7.5 * s_ ** 2.2)
                img[y, x] = BRASS[int(np.clip(4.6 - k * 2.6 - (1 - s_) * 0.8, 0, 5))]
    for t in np.linspace(0, 2 * np.pi, 80):               # the opening: rim and dark inside
        for rr, col in ((8.8, BRASS[5]), (7.6, BRASS[3]), (6.2, BRASS[0]), (4.5, hexc('#2a1a08')), (2.5, hexc('#1a1004'))):
            ex, ey = np.cos(t) * rr * 0.42, np.sin(t) * rr
            x = int(round(bcx + ex * ca - ey * sa)); y = int(round(bcy + ex * sa + ey * ca))
            img[y, x] = col
    for rr in np.linspace(0, 6.0, 12):
        for t in np.linspace(0, 2 * np.pi, 40):
            ex, ey = np.cos(t) * rr * 0.42, np.sin(t) * rr
            x = int(round(bcx + ex * ca - ey * sa)); y = int(round(bcy + ex * sa + ey * ca))
            if rr < 6.0: img[y, x] = hexc('#2a1a08') if rr > 3 else hexc('#1a1004')

    # ------------------------------------------------ star lamp on the wall above the gramophone
    for y, row in enumerate(STAR5):
        for x, ch in enumerate(row):
            if ch == '#': img[46 + y, 26 + x] = hexc('#fff0b8') if y < 5 else hexc('#f2d27a')

    # ------------------------------------------------ brass lamps above the two picture frames
    for fx in (218, 280):
        for x in range(fx - 9, fx + 10):
            img[53, x] = GOLD[2]; img[54, x] = GOLD[4] if abs(x - fx) < 7 else GOLD[3]; img[55, x] = GOLD[1]
        for y in range(49, 53): img[y, fx] = GOLD[1]
        img[48, fx - 1:fx + 2] = GOLD[0]
        img[56, fx - 6:fx + 7] = hexc('#fff3c8')
    # frame shadows (the frames themselves are put up by the game)
    for (fx0, fy0) in ((190, 58), (252, 58)):
        for y in range(fy0 + 2, fy0 + 38):
            for x in range(fx0 + 56, fx0 + 58):
                img[y, x] = (img[y, x].astype(np.int32) * 0.65).astype(np.uint8)
        for x in range(fx0 + 2, fx0 + 58):
            for y in range(fy0 + 35, fy0 + 37):
                img[y, x] = (img[y, x].astype(np.int32) * 0.65).astype(np.uint8)

    # ------------------------------------------------ low bookshelf under the paintings
    bx0, bx1 = 186, 312
    for y in range(104, 152):
        for x in range(bx0, bx1 + 1):
            if y < 107: c = WOOD[4] if y == 104 else WOOD[3]
            elif x in (bx0, bx0 + 1, bx1 - 1, bx1) or y in (126, 127, 150, 151): c = WOOD[2]
            else: c = WOOD[0] if (x + y) % 5 else WOOD[1]
            img[y, x] = c
    BOOKS = [hexc(h) for h in ('#e8574a', '#4aa3e8', '#f2c64a', '#7ad07a', '#c87ae8', '#f08a3a', '#5b68b8', '#e070a8')]
    for shelf_y in (108, 128):
        x = bx0 + 3
        while x < bx1 - 5:
            bw = int(rng.integers(3, 6)); bh = int(rng.integers(13, 18))
            col = BOOKS[int(rng.integers(0, len(BOOKS)))]
            if rng.random() < 0.12:                       # a gap or a leaning book
                x += bw + 2
                continue
            for yy3 in range(shelf_y + 18 - bh, shelf_y + 18):
                for xx3 in range(x, min(x + bw, bx1 - 2)):
                    k = xx3 - x
                    c = col if 0 < k < bw - 1 else (col.astype(np.int32) * 0.65).astype(np.uint8)
                    if yy3 in (shelf_y + 18 - bh + 2, shelf_y + 18 - 4) and 0 < k < bw - 1:
                        c = GOLD[4]
                    img[yy3, xx3] = c
            x += bw
    # a toy rocket on top of the shelf
    rx0 = 200
    rocket = ['..#..', '.###.', '.#o#.', '.###.', '.###.', '##.##', '#...#']
    for y, row in enumerate(rocket):
        for x, ch in enumerate(row):
            if ch == '#': img[96 + y, rx0 + x] = hexc('#f4efe4') if y < 5 else hexc('#e8574a')
            if ch == 'o': img[96 + y, rx0 + x] = hexc('#4aa3e8')
    img[95, rx0 + 2] = hexc('#e8574a')
    # a jar of star bits on the shelf (it glows – room.gd adds the shimmer)
    jx0 = 296
    for y in range(90, 104):
        for x in range(jx0, jx0 + 11):
            e = min(x - jx0, jx0 + 10 - x)
            if y < 92: c = GOLD[2] if y == 90 else GOLD[3]
            elif e == 0: c = hexc('#9ab0d8')
            else:
                c = hexc('#2a3060')
                if y > 95:
                    gems = [hexc('#ffd84a'), hexc('#ff6aa8'), hexc('#6ac0ff'), hexc('#8af08a'), hexc('#c88aff'), hexc('#ff9a4a')]
                    c = gems[((x * 7 + y * 13) // 3) % len(gems)] if (x + y) % 3 else (gems[(x + y) % 6].astype(np.int32) * 0.6).astype(np.uint8)
                if x == jx0 + 2 and 93 < y < 102: c = hexc('#e8f0ff')
            img[y, x] = c

    # ------------------------------------------------ name plate hanging from the beam
    text = "MORITZ' STERNWARTE"
    tw = len(text) * 4 - 1
    sw = tw + 8
    sx = 88 - sw // 2
    for x in (sx + 3, sx + sw - 4):
        for y in range(25, 30): img[y, x] = hexc('#1a1020')
    for y in range(30, 41):
        for x in range(sx, sx + sw):
            e = min(x - sx, sx + sw - 1 - x, y - 30, 40 - y)
            img[y, x] = GOLD[0] if e == 0 else (GOLD[4] if y == 31 else (GOLD[3] if e == 1 else NIGHT[2]))
    for i, ch in enumerate(text):
        g = FONT[ch]
        for gy in range(5):
            for gx2 in range(3):
                if g[gy][gx2] == '1': img[33 + gy, sx + 4 + i * 4 + gx2] = hexc('#fff0b8')

    # ------------------------------------------------ the post at the room's left edge (the corridor continues)
    for y in range(0, 153):
        for x in range(0, 8):
            lv = [1, 3, 4, 4, 3, 3, 2, 1][x] + (0.6 if y > 100 else 0)
            img[y, x] = dith(WOOD, np.array(lv - 0.6), np.array(x), np.array(y))
        img[y, 8] = WOOD[0]
    for x in range(0, 10):
        for y in range(147, 154): img[y, x] = WOOD[2 if y < 149 else 1]
        img[146, x] = WOOD[0]
    for y in range(153, H):
        img[y, 0] = WOOD[0]; img[y, 1] = WOOD[3]; img[y, 2] = WOOD[2]; img[y, 3] = WOOD[0]

    Image.fromarray(img).save(OUT)
    print('wrote', OUT, img.shape)


if __name__ == '__main__':
    build()
