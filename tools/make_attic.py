"""Builds the 2D attic for the hub as native pixel art (1 art pixel = 5 screen
pixels at 1080p).

The right part is the film's attic at sunset, reconstructed pixel by pixel
from frames where neither the robot nor the human is in the room
(tools/attic_src/room_native.png, 384x216). To the left, a hallway wing is
drawn procedurally in the same style: mirrored roof bay, dithered plaster
wall with brick dashes, perspective floor boards, fairy lights, a cork board
with photos of the first dream, a bench and a guestbook on a little table.
The friends' rooms (rooms/*) continue further left.

Writes assets/hub/attic_bg.png (EXT+384 x 216).
Run: python3 tools/make_attic.py
"""
import os
import cv2
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, '..')
EXT = 272                      # width of the gallery wing (native px)
H = 216
PHOTOS = os.path.join(ROOT, 'assets', 'hub', 'gallery_src')   # pictures of the first dream

BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]], np.float32) / 16.0 + 1 / 32.0


def hexc(h):
    h = h.lstrip('#')
    return np.array([int(h[4:6], 16), int(h[2:4], 16), int(h[0:2], 16)], np.uint8)   # BGR


def ramp(*hs):
    return np.stack([hexc(h) for h in hs])


WALL = ramp('#4c2f3b', '#5e3a45', '#704650', '#885454', '#9c6157', '#af6b5f', '#c07361', '#d37a60', '#e08369', '#ee8a6a', '#fa936b')
FLOOR = ramp('#1e0b05', '#2e1206', '#3e180a', '#4e200f', '#5c2816', '#693317', '#753b1f', '#864324', '#9a4b24', '#ae5729', '#c26133', '#d67141')
WOOD = ramp('#331309', '#4b1f10', '#75361e', '#9a4f2c', '#c26a40', '#e39473')
GOLD = ramp('#3d2410', '#6e4518', '#a8742a', '#d4a24a', '#f2d27a', '#fff0b8')
RUG = {'dark': hexc('#531e10'), 'red': hexc('#8a3124'), 'red2': hexc('#aa4926'), 'teal': hexc('#2f4c4d'),
       'green': hexc('#69986d'), 'cream': hexc('#e29970'), 'orange': hexc('#fc7635'), 'yellow': hexc('#fce059')}


def dith(rmp, level, x, y):
    """level: float index into the ramp, ordered-dithered between neighbours"""
    lv = np.clip(level, 0, len(rmp) - 1.001)
    i = np.floor(lv).astype(int)
    f = lv - i
    t = BAYER[y % 4, x % 4]
    return rmp[np.where(f > t, np.minimum(i + 1, len(rmp) - 1), i)]


def lum(c):
    return c.astype(np.float32) @ np.array([0.114, 0.587, 0.299], np.float32)


def draw_monstera(img, pcx=20):
    """monstera in a terracotta pot, pot centred at x = pcx"""
    POT = ramp('#5a2414', '#8e3a22', '#b8532f', '#d8754a', '#f09a6a')
    LEAF = ramp('#13301c', '#1f4a2a', '#2f6b38', '#4d8f45', '#7cb35a', '#a9d27a')
    for y in range(136, 157):
        hw = 9 if y < 140 else 8 - (y - 140) // 6
        for x in range(pcx - hw, pcx + hw + 1):
            k = (x - (pcx - hw)) / (2 * hw)
            lv = 3.2 - abs(k - 0.35) * 3.5
            if y < 140:
                lv += 0.6
            img[y, x] = dith(POT, np.array(lv), np.array(x), np.array(y))
        img[y, pcx - hw - 1] = POT[0]; img[y, pcx + hw + 1] = POT[0]
    img[135, pcx - 10:pcx + 11] = POT[0]
    img[157, pcx - 6:pcx + 7] = POT[0]
    leaves = [(20, 112, 13, 8, -0.5), (10, 100, 10, 7, -1.0), (30, 98, 11, 7, 0.8), (18, 88, 9, 6, 0.1), (6, 120, 9, 5, -1.3), (34, 118, 10, 6, 1.2)]
    for (cx, cy, rx, ry, ang) in leaves:
        cx += pcx - 20
        # stem
        for t in np.linspace(0, 1, 30):
            sx = int(round(pcx + (cx - pcx) * t)); sy = int(round(136 + (cy - 136) * t))
            img[sy, sx] = LEAF[1]
        ca, sa = np.cos(ang), np.sin(ang)
        for y in range(cy - ry - 2, cy + ry + 3):
            for x in range(cx - rx - 2, cx + rx + 3):
                u = ((x - cx) * ca + (y - cy) * sa) / rx
                v = (-(x - cx) * sa + (y - cy) * ca) / ry
                r = u * u + v * v
                if r <= 1.0:
                    slit = abs(v) > 0.25 and int((u + 1.2) * 4) % 2 == 0 and r > 0.35
                    if slit:
                        continue
                    lv = 3.0 - v * 1.2 + (0.4 if u < -0.2 else 0)
                    c = dith(LEAF, np.array(lv), np.array(x), np.array(y))
                    if r > 0.82:
                        c = LEAF[0]
                    if abs(v) < 0.08:
                        c = LEAF[1]
                    img[y, x] = c


def draw_post(img, x0, h=153):
    """a wooden roof post 8 px wide starting at x0"""
    for y in range(0, h):
        for x in range(x0, x0 + 8):
            k = x - x0
            lv = [1, 3, 4, 4, 3, 3, 2, 1][k] + (0.6 if y > 100 else 0)
            img[y, x] = dith(WOOD, np.array(lv), np.array(x), np.array(y))
    img[0:h, x0 + 8] = WOOD[0]
    for x in range(max(0, x0 - 2), x0 + 10):
        for y in range(147, 154):
            img[y, x] = WOOD[2 if y < 149 else 1]
        img[146, x] = WOOD[0]


def build():
    rng = np.random.default_rng(7)
    room = cv2.imread(os.path.join(HERE, 'attic_src', 'room_native.png'))
    W = EXT + room.shape[1]
    img = np.zeros((H, W, 3), np.uint8)
    img[:, EXT:] = room
    yy, xx = np.mgrid[0:H, 0:W]

    # ---------------- lighting of the wing (0 = dark, 1 = bright)
    LAMPS = [(78, 86), (166, 52)]                      # wall sconce over the guestbook, lamp over the cork board
    light = np.full((H, W), 0.37, np.float32)
    light += 0.10 * (yy / H)                           # a little brighter lower down
    seam = np.exp(-((EXT - xx) / 60.0) ** 2)
    light += 0.30 * seam * np.clip((yy - 70) / 50.0, 0, 1)     # the desk lamp's glow spills over
    for lx, ly in LAMPS:
        dx = (xx - lx) / 30.0
        dy = (yy - (ly + 18)) / 34.0
        light += 0.42 * np.exp(-(dx * dx + dy * dy) * 1.6) * (yy > ly - 2)
    wing = xx < EXT

    # ---------------- wall
    wall_level = (light - 0.18) / 0.62 * (len(WALL) - 1)
    wall = dith(WALL, wall_level, xx, yy)
    img[wing] = wall[wing]
    # brick dashes: short horizontal marks one tone darker / lighter
    for _ in range(420):
        x0 = rng.integers(0, EXT - 8); y0 = rng.integers(20, 144)
        ln = rng.integers(2, 9)
        dark = rng.random() < 0.75
        for x in range(x0, x0 + ln):
            lv = wall_level[y0, x] + (-1.4 if dark else 0.9)
            img[y0, x] = WALL[int(np.clip(round(lv), 0, len(WALL) - 1))]

    # ---------------- roof bay: the film's roof, mirrored (twin gable)
    rl = lum(room)
    for xw in range(EXT):
        ox = EXT - 1 - xw
        img[0:24, xw] = room[0:24, ox]
        y = 24
        if ox < 100:
            ylim = 64                                  # left roof slope near the seam
        elif ox >= 200:
            ylim = int((ox - 200) * 0.49) + 2          # right roof slope at the far left
        else:
            ylim = 0
        while y < ylim and rl[y, ox] < 100:
            img[y, xw] = room[y, ox]
            y += 1

    # ---------------- baseboard
    for xw in range(EXT):
        L = light[150, xw]
        img[145, xw] = WOOD[1]
        for y in range(146, 152):
            img[y, xw] = dith(WOOD, np.array(1.6 + L * 2.6 - (y - 146) * 0.18), np.array(xw), np.array(y))
        img[152, xw] = WOOD[0]

    # ---------------- floor: boards laid parallel to the wall in the wing,
    # spaced in perspective; joints run towards the wing's vanishing point
    vy = 104.0
    vxw = 150.0
    KL = 523.0                      # board thickness = (y - vy)^2 / KL
    LU = 1.7                        # board length in perspective units
    for y in range(153, H):
        d = y - vy
        k = KL / d                  # depth coordinate (rows of boards)
        row = int(np.floor(k))
        krow_next = KL / (d + 1)
        seam = int(np.floor(krow_next)) != row
        rr = np.random.default_rng(row * 977 + 11)
        off = rr.random() * LU
        for x in range(0, EXT):
            u = (x - vxw) / d + off
            seg = int(np.floor(u / LU))
            un = (x + 1 - vxw) / d + off
            joint = int(np.floor(un / LU)) != seg
            tone = 5.4 + (((row * 31 + seg * 17) * 2654435761) % 1000) / 1000.0 * 2.2 - 1.1
            # wood grain: streaks along the board, a little dithered noise
            ystep = int(round((k - row) * 6))
            gh = ((row * 7919 + seg * 104729 + ystep * 31 + (x // 5) * 3) * 2654435761) % 1000 / 1000.0
            tone += (gh - 0.5) * 0.9
            L = light[y, x]
            lv = tone - 1.9 + L * 4.0
            for lx, _ in LAMPS:
                lv += 1.0 * np.exp(-(((x - lx) / 26.0) ** 2 + ((y - 160) / 9.0) ** 2))
            lv += 1.2 * np.exp(-(((x - EXT) / 40.0) ** 2))      # lamp + sun spill near the post
            if seam:
                c = FLOOR[max(0, int(lv) - 3)]
            elif joint:
                c = FLOOR[max(0, int(lv) - 2)]
            else:
                c = dith(FLOOR, np.array(lv), np.array(x), np.array(y))
            img[y, x] = c
    # threshold strip where the two floors meet, under the post
    for y in range(153, H):
        img[y, EXT - 3] = WOOD[0]
        img[y, EXT - 2] = WOOD[3]
        img[y, EXT - 1] = WOOD[2]
        img[y, EXT] = WOOD[0]

    # ---------------- seam post (roof support between the two bays)
    for y in range(0, 153):
        for x in range(EXT - 8, EXT):
            k = x - (EXT - 8)
            lv = [1, 3, 4, 4, 3, 3, 2, 1][k] + (0.6 if y > 100 else 0)
            img[y, x] = dith(WOOD, np.array(lv), np.array(x), np.array(y))
    img[0:153, EXT - 9] = WOOD[0]
    for x in range(EXT - 10, EXT + 2):              # footing
        for y in range(147, 154):
            img[y, x] = WOOD[2 if y < 149 else 1]
        img[146, x] = WOOD[0]

    # ---------------- post at the left end of the wing (the corridor continues there)
    draw_post(img, 0)
    for y in range(153, H):
        img[y, 0] = WOOD[0]; img[y, 1] = WOOD[3]; img[y, 2] = WOOD[2]; img[y, 3] = WOOD[0]

    # ---------------- fairy lights along the beam
    nails = [6, 70, 134, 198, 258]
    bulbs = []
    for a, b in zip(nails[:-1], nails[1:]):
        for x in range(a, b + 1):
            t = (x - a) / (b - a)
            y = int(round(26 + 9 * 4 * t * (1 - t)))
            img[y, x] = hexc('#3a1e18')
            if (x - a) % 7 == 3:
                bulbs.append((x, y + 1))
    cols = [hexc('#ffd36b'), hexc('#ff9f7a'), hexc('#fff0b8'), hexc('#ffb0c8')]
    for i, (x, y) in enumerate(bulbs):
        c = cols[i % 4]
        for (dx, dy) in [(-1, 0), (1, 0), (0, -1), (0, 1), (-1, 1), (1, 1)]:
            if (x + dx + y + dy) % 2 == 0:
                img[y + dy, x + dx] = (img[y + dy, x + dx].astype(np.int32) * 0.45 + c * 0.55).astype(np.uint8)
        img[y, x] = c
        img[y + 1, x] = c

    # ---------------- paintings
    def pixelize(path, w, h, k=18, crop=None):
        src = cv2.imread(path)
        if crop:
            x0, y0, x1, y1 = crop
            src = src[y0:y1, x0:x1]
        sh, sw = src.shape[:2]
        tw = sh * w / h
        if tw <= sw:
            x0 = int((sw - tw) / 2); src = src[:, x0:x0 + int(tw)]
        sm = cv2.resize(src, (w, h), interpolation=cv2.INTER_AREA)
        px = np.float32(sm.reshape(-1, 3))
        _, lab, cen = cv2.kmeans(px, k, None, (cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 40, 0.5), 4, cv2.KMEANS_PP_CENTERS)
        q = cen[lab.ravel()].reshape(h, w, 3)
        hsv = cv2.cvtColor(np.clip(q, 0, 255).astype(np.uint8), cv2.COLOR_BGR2HSV).astype(np.float32)
        hsv[..., 1] = np.clip(hsv[..., 1] * 1.12, 0, 255)
        return cv2.cvtColor(hsv.astype(np.uint8), cv2.COLOR_HSV2BGR)

    def frame(cx, top, iw, ih, art=None, empty=False):
        x0 = cx - iw // 2 - 3; y0 = top
        x1 = x0 + iw + 5; y1 = y0 + ih + 5
        # shadow on the wall
        for y in range(y0 + 2, y1 + 3):
            for x in range(x0 + 2, x1 + 3):
                if wing[y, x]:
                    img[y, x] = (img[y, x].astype(np.int32) * 0.72).astype(np.uint8)
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                edge = min(x - x0, x1 - x, y - y0, y1 - y)
                if edge == 0:
                    img[y, x] = GOLD[0]
                elif edge == 1:
                    lit = (x - x0) + (y1 - y) > (x1 - x) + (y - y0)
                    img[y, x] = GOLD[4] if (y == y0 + 1 or x == x0 + 1) else (GOLD[2] if lit else GOLD[1])
                elif edge == 2:
                    img[y, x] = GOLD[3] if (y == y0 + 2 or x == x0 + 2) else GOLD[2]
                elif edge == 3:
                    img[y, x] = GOLD[0]
        ix, iy = x0 + 4, y0 + 4
        iw2, ih2 = x1 - x0 - 7, y1 - y0 - 7
        if empty:
            for y in range(iy, iy + ih2):
                for x in range(ix, ix + iw2):
                    c = hexc('#e9dcc0') if (x + y) % 2 else hexc('#ded0b2')
                    if (x * 7 + y * 13) % 23 == 0:
                        c = hexc('#c9b693')
                    img[y, x] = c
        elif art is not None:
            img[iy:iy + ih2, ix:ix + iw2] = art[:ih2, :iw2]
        # brass picture lamp
        lx = cx
        for x in range(lx - 9, lx + 10):
            img[y0 - 5, x] = GOLD[2]
            img[y0 - 4, x] = GOLD[4] if abs(x - lx) < 7 else GOLD[3]
            img[y0 - 3, x] = GOLD[1]
        for y in range(y0 - 9, y0 - 5):
            img[y, lx] = GOLD[1]
        img[y0 - 10, lx - 1:lx + 2] = GOLD[0]
        img[y0 - 2, lx - 6:lx + 7] = hexc('#fff3c8')
        return (x0, y0, x1, y1)

    # ---------------- cork board with three photos of the first dream
    rects = {}
    CORK = ramp('#5a3418', '#7a4a22', '#9a6430', '#b47c3e', '#c99452')
    bx0, by0, bx1, by1 = 128, 60, 206, 112
    for y in range(by0, by1 + 1):
        for x in range(bx0, bx1 + 1):
            e = min(x - bx0, bx1 - x, y - by0, by1 - y)
            if e <= 2:
                img[y, x] = WOOD[[0, 4, 2][e]] if not (e == 1 and (x == bx0 + 1 or y == by0 + 1)) else WOOD[5]
            else:
                h = ((x * 73856093) ^ (y * 19349663)) % 1000 / 1000.0
                lv = 2.2 + light[y, x] * 1.6 + (h - 0.5) * 1.4
                img[y, x] = dith(CORK, np.array(lv), np.array(x), np.array(y))
    for y in range(by0 + 2, by1 + 4):                 # shadow on the wall
        for x in (bx1 + 1, bx1 + 2):
            img[y, x] = (img[y, x].astype(np.int32) * 0.7).astype(np.uint8)
    PIN = [hexc('#e8574a'), hexc('#4aa3e8'), hexc('#f2c64a')]
    photos = [('garden', 134, 66, 0), ('flight', 157, 72, 1), ('space', 181, 65, 2)]
    for name, px0, py0, k in photos:
        art = pixelize(os.path.join(PHOTOS, name + '.jpg'), 18, 12)
        pw, ph = 22, 19                                  # polaroid: white border, wider bottom
        for y in range(py0, py0 + ph):
            for x in range(px0, px0 + pw):
                img[y, x] = hexc('#f4efe4') if (x + y) % 5 else hexc('#e6dfd2')
        img[py0 + 2:py0 + 14, px0 + 2:px0 + 20] = art
        for x in range(px0 + 1, px0 + pw + 1):          # little drop shadow
            img[py0 + ph, x] = (img[py0 + ph, x].astype(np.int32) * 0.6).astype(np.uint8)
        for y in range(py0 + 1, py0 + ph + 1):
            img[y, px0 + pw] = (img[y, px0 + pw].astype(np.int32) * 0.6).astype(np.uint8)
        pc = PIN[k]
        img[py0 - 1, px0 + 10:px0 + 12] = pc; img[py0, px0 + 10:px0 + 12] = pc
        img[py0 - 1, px0 + 10] = np.minimum(pc.astype(np.int32) + 60, 255).astype(np.uint8)
    # a yellow sticky note with scribbles
    for y in range(92, 104):
        for x in range(186, 199):
            img[y, x] = hexc('#f6dc6a') if y > 92 else hexc('#e8c64e')
    for y, (xa, xb) in zip((95, 97, 99, 101), ((188, 196), (188, 194), (188, 197), (188, 192))):
        img[y, xa:xb] = hexc('#8a6a3a')
    rects['board'] = (bx0, by0, bx1, by1)
    # brass lamp over the board
    lx = 166
    for x in range(lx - 9, lx + 10):
        img[53, x] = GOLD[2]; img[54, x] = GOLD[4] if abs(x - lx) < 7 else GOLD[3]; img[55, x] = GOLD[1]
    for y in range(49, 53):
        img[y, lx] = GOLD[1]
    img[48, lx - 1:lx + 2] = GOLD[0]
    img[56, lx - 6:lx + 7] = hexc('#fff3c8')

    # ---------------- guestbook on a little table, a wall sconce above it
    tx0, tx1 = 62, 96
    for x in range(tx0, tx1 + 1):                      # table top
        img[128, x] = WOOD[0]; img[129, x] = WOOD[5] if x % 7 else WOOD[4]; img[130, x] = WOOD[3]; img[131, x] = WOOD[0]
    for y in range(132, 136):                          # apron
        for x in range(tx0 + 2, tx1 - 1):
            img[y, x] = WOOD[2] if y < 135 else WOOD[0]
    for lxp in (tx0 + 3, tx1 - 6):                     # legs
        for y in range(136, 156):
            img[y, lxp] = WOOD[1]; img[y, lxp + 1] = WOOD[3]; img[y, lxp + 2] = WOOD[0]
    for x in range(tx0 + 2, tx1):                      # shadow on the floor
        for y in range(154, 158):
            if (x + y) % 2 == 0:
                img[y, x] = (img[y, x].astype(np.int32) * 0.6).astype(np.uint8)
    # the open book (two pages, writing on both), a quill and a candle
    for y in range(121, 128):
        for x in range(68, 88):
            mid = abs(x - 78) <= 0
            edge = y == 121 or x in (68, 87)
            page = hexc('#f4ead2') if (x + y) % 3 else hexc('#e9dcbc')
            img[y, x] = hexc('#7a4a2a') if edge else (hexc('#c9b48c') if mid else page)
    for y in (123, 125):
        img[y, 70:76] = hexc('#8a7a6a'); img[y, 80:86] = hexc('#8a7a6a')
    img[127, 67:89] = hexc('#5a2a14')                  # book cover edge
    for k in range(8):                                 # quill
        img[120 - k, 86 + k // 2] = hexc('#f6f2ea') if k > 2 else hexc('#3a2a20')
    img[126, 91] = hexc('#f6eedb'); img[125, 91] = hexc('#f6eedb'); img[124, 91] = hexc('#f6eedb')
    img[123, 91] = hexc('#ffd36b'); img[122, 91] = hexc('#fff0b8')
    # wall sconce
    sx = 78
    for y in range(80, 90):
        img[y, sx] = GOLD[1]
    for x in range(sx - 3, sx + 4):
        img[90, x] = GOLD[2]
    for y in range(84, 90):
        for x in range(sx - 2, sx + 3):
            img[y, x] = hexc('#ffe7a8') if (y > 85 and abs(x - sx) < 2) else hexc('#f2c66a')
    rects['guestbook'] = (tx0, 121, tx1, 156)

    # ---------------- bench in front of the cork board
    bx0, bx1 = 142, 190
    for x in range(bx0, bx1 + 1):
        img[139, x] = WOOD[0]
        img[140, x] = WOOD[5] if x % 9 else WOOD[4]
        img[141, x] = WOOD[4]
        img[142, x] = WOOD[3]
        img[143, x] = WOOD[2]
        img[144, x] = WOOD[0]
    for lxp in (bx0 + 3, bx1 - 5):
        for y in range(145, 157):
            img[y, lxp] = WOOD[1]; img[y, lxp + 1] = WOOD[3]; img[y, lxp + 2] = WOOD[2]; img[y, lxp + 3] = WOOD[0]
    for x in range(bx0 + 2, bx1 - 1):                # shadow on the floor
        for y in range(155, 159):
            if (x + y) % 2 == 0:
                img[y, x] = (img[y, x].astype(np.int32) * 0.6).astype(np.uint8)

    # ---------------- runner rug in front of the paintings
    for y in range(166, 185):
        t = (y - 166) / 18.0
        xa = int(26 - t * 6); xb = int(256 + t * 4)
        for x in range(xa, xb + 1):
            e = min(x - xa, xb - x, y - 166, 184 - y)
            if e == 0:
                c = RUG['dark']
            elif e <= 1:
                c = RUG['cream']
            elif e <= 3:
                c = RUG['red2'] if (x // 2 + y) % 3 else RUG['orange']
            else:
                c = RUG['red']
                # diamonds along the middle
                dxm = (x - xa) % 22 - 11
                dym = y - 175
                if abs(dxm) + abs(dym) * 1.6 < 6:
                    c = RUG['teal']
                if abs(dxm) + abs(dym) * 1.6 < 3:
                    c = RUG['cream']
                if abs(dxm) + abs(dym) * 1.6 < 1:
                    c = RUG['yellow']
            # light pools and dithered shade
            L = light[min(y, H - 1), x]
            shade = 0.72 + L * 0.5
            for lx, _ in LAMPS:
                shade += 0.25 * np.exp(-(((x - lx) / 24.0) ** 2))
            if BAYER[y % 4, x % 4] > (shade - 0.75) * 2:
                c = (c.astype(np.float32) * 0.82).astype(np.uint8)
            img[y, x] = c

    gallery_assets(room)
    out = os.path.join(ROOT, 'assets', 'hub', 'attic_bg.png')
    cv2.imwrite(out, img)
    print('wrote', out, img.shape, 'frames', rects)
    return img, rects


# ====================================================================== gallery
TILE = 176          # one corridor segment, two painting slots
SLOTS = (44, 132)   # slot centres inside a tile
END = 96            # the far end of the corridor
FRAME_W, FRAME_H = 56, 35
ART_W, ART_H = 48, 27
FRAME_TOP = 58

ROOF = ramp('#190601', '#2a0f07', '#43160e', '#4c1e15', '#5e2314', '#793323')
BEAM = ramp('#3a1206', '#4b1609', '#873619', '#a7451e', '#cd5c2f')

FONT3 = {
    'A': ['010', '101', '111', '101', '101'], 'C': ['011', '100', '100', '100', '011'], 'D': ['110', '101', '101', '101', '110'],
    'E': ['111', '100', '110', '100', '111'], 'I': ['111', '010', '010', '010', '111'], 'M': ['101', '111', '111', '101', '101'],
    'N': ['101', '111', '111', '111', '101'], 'O': ['010', '101', '101', '101', '010'], 'R': ['110', '101', '110', '101', '101'],
    'S': ['011', '100', '010', '001', '110'], 'T': ['111', '010', '010', '010', '010'], 'U': ['101', '101', '101', '101', '111'],
    'Y': ['101', '101', '010', '010', '010'], ' ': ['000', '000', '000', '000', '000'],
}


def corridor(width, lamps, seed):
    """ceiling, wall, baseboard, floor of a corridor piece (lamps = x of picture lamps)"""
    rng = np.random.default_rng(seed)
    img = np.zeros((H, width, 3), np.uint8)
    yy, xx = np.mgrid[0:H, 0:width]
    light = np.full((H, width), 0.37, np.float32) + 0.10 * (yy / H)
    for lx in lamps:
        dx = (xx - lx) / 30.0
        dy = (yy - (FRAME_TOP - 2 + 18)) / 34.0
        light += 0.42 * np.exp(-(dx * dx + dy * dy) * 1.6) * (yy > FRAME_TOP - 4)
    # wall
    wl = (light - 0.18) / 0.62 * (len(WALL) - 1)
    img[:] = dith(WALL, wl, xx, yy)
    for _ in range(int(420 * width / 272)):
        x0 = rng.integers(0, width - 8); y0 = rng.integers(26, 144)
        ln = rng.integers(2, 9)
        dark = rng.random() < 0.75
        for x in range(x0, x0 + ln):
            lv = wl[y0, x] + (-1.4 if dark else 0.9)
            img[y0, x] = WALL[int(np.clip(round(lv), 0, len(WALL) - 1))]
    # ceiling: planks of the roof underside, rafters, a tie beam
    for y in range(0, 17):
        plank = y // 4
        for x in range(width):
            seam = (y % 4 == 3)
            jx = (x + plank * 37) % 53 == 0
            lv = 2.4 + ((plank * 7 + (x + plank * 37) // 53 * 3) % 5) * 0.35 - y * 0.05
            img[y, x] = ROOF[0] if seam or jx else dith(ROOF, np.array(lv), np.array(x), np.array(y))
    for rx in range(0, width, 44):
        for y in range(0, 17):
            for x in range(rx, min(width, rx + 4)):
                img[y, x] = ROOF[[1, 4, 3, 1][x - rx]]
    prof = [0, 2, 4, 4, 3, 3, 2, 1, 0]
    for k, y in enumerate(range(16, 25)):
        for x in range(width):
            img[y, x] = BEAM[prof[k]] if k not in (3, 4) or (x * 7 + y) % 11 else BEAM[prof[k] - 1]
    # baseboard
    for x in range(width):
        L = light[150, x]
        img[145, x] = WOOD[1]
        for y in range(146, 152):
            img[y, x] = dith(WOOD, np.array(1.6 + L * 2.6 - (y - 146) * 0.18), np.array(x), np.array(y))
        img[152, x] = WOOD[0]
    # floor: the same board rows as the wing, joints towards the piece's centre
    vy, KL, LU = 104.0, 523.0, 1.7
    vxw = width / 2.0
    for y in range(153, H):
        d = y - vy
        k = KL / d
        row = int(np.floor(k))
        seam = int(np.floor(KL / (d + 1))) != row
        off = np.random.default_rng(row * 977 + 11).random() * LU
        for x in range(width):
            u = (x - vxw) / d + off
            seg = int(np.floor(u / LU))
            joint = int(np.floor(((x + 1 - vxw) / d + off) / LU)) != seg
            tone = 5.4 + (((row * 31 + seg * 17) * 2654435761) % 1000) / 1000.0 * 2.2 - 1.1
            ystep = int(round((k - row) * 6))
            gh = ((row * 7919 + seg * 104729 + ystep * 31 + (x // 5) * 3) * 2654435761) % 1000 / 1000.0
            tone += (gh - 0.5) * 0.9
            lv = tone - 1.9 + light[y, x] * 4.0
            for lx in lamps:
                lv += 1.0 * np.exp(-(((x - lx) / 26.0) ** 2 + ((y - 160) / 9.0) ** 2))
            if seam:
                c = FLOOR[max(0, int(lv) - 3)]
            elif joint:
                c = FLOOR[max(0, int(lv) - 2)]
            else:
                c = dith(FLOOR, np.array(lv), np.array(x), np.array(y))
            img[y, x] = c
    return img, light


def picture_lamp(img, cx):
    y0 = FRAME_TOP
    for x in range(cx - 9, cx + 10):
        img[y0 - 5, x] = GOLD[2]
        img[y0 - 4, x] = GOLD[4] if abs(x - cx) < 7 else GOLD[3]
        img[y0 - 3, x] = GOLD[1]
    for y in range(y0 - 9, y0 - 5):
        img[y, cx] = GOLD[1]
    img[y0 - 10, cx - 1:cx + 2] = GOLD[0]
    img[y0 - 2, cx - 6:cx + 7] = hexc('#fff3c8')


def fairy_lights(img, nails):
    cols = [hexc('#ffd36b'), hexc('#ff9f7a'), hexc('#fff0b8'), hexc('#ffb0c8')]
    i = 0
    for a, b in zip(nails[:-1], nails[1:]):
        for x in range(a, b + 1):
            if x >= img.shape[1]: continue
            t = (x - a) / (b - a)
            y = int(round(30 + 9 * 4 * t * (1 - t)))
            img[y, x] = hexc('#3a1e18')
            if (x - a) % 7 == 3:
                c = cols[i % 4]; i += 1
                img[y + 1, x] = c; img[y + 2, x] = c
                for (dx, dy) in [(-1, 1), (1, 1), (0, 3)]:
                    xx2, yy2 = x + dx, y + dy
                    if 0 <= xx2 < img.shape[1]:
                        img[yy2, xx2] = (img[yy2, xx2].astype(np.int32) * 0.45 + c * 0.55).astype(np.uint8)


def runner(img, light, xa0, xb0, lamps):
    for y in range(168, 185):
        t = (y - 168) / 16.0
        xa = int(xa0 - t * 5); xb = int(xb0 + t * 5)
        for x in range(max(0, xa), min(img.shape[1], xb + 1)):
            e = min(x - xa, xb - x, y - 168, 184 - y)
            if e == 0: c = RUG['dark']
            elif e <= 1: c = RUG['cream']
            elif e <= 3: c = RUG['red2'] if (x // 2 + y) % 3 else RUG['orange']
            else:
                c = RUG['red']
                dxm = (x - xa) % 22 - 11
                dym = y - 176
                q = abs(dxm) + abs(dym) * 1.6
                if q < 6: c = RUG['teal']
                if q < 3: c = RUG['cream']
                if q < 1: c = RUG['yellow']
            shade = 0.72 + light[y, x] * 0.5
            for lx in lamps:
                shade += 0.25 * np.exp(-(((x - lx) / 24.0) ** 2))
            if BAYER[y % 4, x % 4] > (shade - 0.75) * 2:
                c = (c.astype(np.float32) * 0.82).astype(np.uint8)
            img[y, x] = c


def gallery_assets(room):
    hub = os.path.join(ROOT, 'assets', 'hub')
    # --- corridor tile with two lamp-lit slots (frames are drawn by the game)
    tile, light = corridor(TILE, SLOTS, 101)
    fairy_lights(tile, [0, 88, 176])
    for cx in SLOTS: picture_lamp(tile, cx)
    runner(tile, light, 14, TILE - 15, SLOTS)
    # a small round table with a candle between the slots
    for y in range(140, 157):
        for x in range(84, 93):
            if y < 143: tile[y, x] = WOOD[4] if y == 140 else WOOD[3]
            elif x in (87, 88): tile[y, x] = WOOD[1]
    tile[139, 87:89] = hexc('#f6eedb'); tile[138, 87:89] = hexc('#f6eedb'); tile[137, 88] = hexc('#ffd36b'); tile[136, 88] = hexc('#fff0b8')
    cv2.imwrite(os.path.join(hub, 'gallery_tile.png'), tile)
    # --- the far end: a round night window, the monstera, blank canvases
    end, light = corridor(END, [], 202)
    fairy_lights(end, [10, 96])
    cx, cy, R = 52, 86, 19
    for y in range(cy - R - 3, cy + R + 4):
        for x in range(cx - R - 3, cx + R + 4):
            d = np.hypot(x - cx, y - cy)
            if d <= R:
                t = (y - (cy - R)) / (2 * R)
                c = (np.array([60, 20, 22]) * (1 - t) + np.array([110, 45, 60]) * t).astype(np.uint8)
                h = (x * 73856093 ^ y * 19349663) % 997
                if h < 9: c = hexc('#fff3c8') if h < 4 else hexc('#b9c8ff')
                if np.hypot(x - (cx + 7), y - (cy - 7)) < 5 and np.hypot(x - (cx + 9), y - (cy - 9)) >= 4.5:
                    c = hexc('#fff0c0')
                if abs(x - cx) <= 1 or abs(y - cy) <= 1: c = WOOD[2]
                end[y, x] = c
            elif d <= R + 3:
                end[y, x] = WOOD[[4, 3, 2][min(2, int(d - R))]]
    for x in range(cx - 14, cx + 15):          # sill
        end[cy + R + 3, x] = WOOD[4]; end[cy + R + 4, x] = WOOD[2]
    # moonlight on the floor
    for y in range(156, 200):
        for x in range(END):
            if abs((x - cx) - (y - 156) * 0.35) < 10 - (y - 156) * 0.12 and BAYER[y % 4, x % 4] < 0.45:
                end[y, x] = np.clip(end[y, x].astype(np.int32) + np.array([30, 18, 14]), 0, 255).astype(np.uint8)
    draw_monstera(end, 20)
    # blank canvases leaning on the wall
    for i, (x0, w, h) in enumerate([(70, 18, 24), (76, 16, 20)]):
        for y in range(156 - h, 156):
            for x in range(x0 - (156 - y) // 6, x0 - (156 - y) // 6 + w):
                if 0 <= x < END:
                    edge = x == x0 - (156 - y) // 6 or y == 156 - h
                    end[y, x] = WOOD[2] if edge else (hexc('#e9dcc0') if (x + y) % 2 else hexc('#ded0b2'))
    # corner shadow at the far left
    for x in range(0, 6):
        for y in range(0, H):
            if BAYER[y % 4, x % 4] < 0.75 - x * 0.12:
                end[y, x] = (end[y, x].astype(np.float32) * 0.6).astype(np.uint8)
    cv2.imwrite(os.path.join(hub, 'gallery_end.png'), end)
    # --- gold frame with a transparent inside
    fr = np.zeros((FRAME_H, FRAME_W, 4), np.uint8)
    for y in range(FRAME_H):
        for x in range(FRAME_W):
            e = min(x, FRAME_W - 1 - x, y, FRAME_H - 1 - y)
            lit = (x + (FRAME_H - 1 - y)) > ((FRAME_W - 1 - x) + y)
            if e == 0: c = GOLD[0]
            elif e == 1: c = GOLD[4] if (y == 1 or x == 1) else (GOLD[2] if lit else GOLD[1])
            elif e == 2: c = GOLD[3] if (y == 2 or x == 2) else GOLD[2]
            elif e == 3: c = GOLD[0]
            else: continue
            fr[y, x, :3] = c; fr[y, x, 3] = 255
    cv2.imwrite(os.path.join(hub, 'frame_gold.png'), fr)
    # --- an empty canvas for free slots
    cv = np.zeros((ART_H, ART_W, 3), np.uint8)
    for y in range(ART_H):
        for x in range(ART_W):
            c = hexc('#e9dcc0') if (x + y) % 2 else hexc('#ded0b2')
            if (x * 7 + y * 13) % 23 == 0: c = hexc('#c9b693')
            cv[y, x] = c
    # a small "+" in the middle
    for k in range(-3, 4):
        cv[ART_H // 2, ART_W // 2 + k] = hexc('#b49c78'); cv[ART_H // 2 + k, ART_W // 2] = hexc('#b49c78')
    cv2.imwrite(os.path.join(hub, 'canvas_empty.png'), cv)
    # --- a little gold star badge for finished dreams
    st = np.zeros((9, 9, 4), np.uint8)
    star = ['....#....', '....#....', '...###...', '#########', '.#######.', '..#####..', '..##.##..', '.##...##.', '.#.....#.']
    for y, row in enumerate(star):
        for x, ch in enumerate(row):
            if ch == '#':
                st[y, x, :3] = GOLD[4] if y < 4 else GOLD[3]
                st[y, x, 3] = 255
    cv2.imwrite(os.path.join(hub, 'star_badge.png'), st)
    # --- hanging sign over the corridor entrance
    text = 'COMMUNITY DREAMS'
    tw = len(text) * 4 - 1
    sw, sh = tw + 8, 11
    sg = np.zeros((sh + 6, sw, 4), np.uint8)
    for x in (3, sw - 4):                    # strings
        for y in range(0, 6):
            sg[y, x, :3] = hexc('#3a1e18'); sg[y, x, 3] = 255
    for y in range(6, 6 + sh):
        for x in range(sw):
            e = min(x, sw - 1 - x, y - 6, 6 + sh - 1 - y)
            c = WOOD[0] if e == 0 else (WOOD[4] if y == 7 else WOOD[3])
            sg[y, x, :3] = c; sg[y, x, 3] = 255
    for i, ch in enumerate(text):
        g = FONT3[ch]
        for gy in range(5):
            for gx in range(3):
                if g[gy][gx] == '1':
                    sg[9 + gy, 4 + i * 4 + gx, :3] = hexc('#fff0c8')
    cv2.imwrite(os.path.join(hub, 'gallery_sign.png'), sg)
    print('gallery assets written')


if __name__ == '__main__':
    build()
