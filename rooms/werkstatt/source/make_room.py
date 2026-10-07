"""Die Werkstatt – the room where the game gets built. Only half of it is
painted: on the left a cosy desk at night (a big CRT monitor, a desk lamp, a
rubber duck, a to-do list, a box of bugs), on the right the wall is still
an empty canvas with pencil lines – a bookshelf, a window and a bean bag
that are only sketched – and a ladder and paint buckets where the painting
stopped.

Writes two pictures:
  room.png       the room as it is (half painted, half sketch)
  room_done.png  only the right part, finished – room.gd lays it over the
                 room once "Work in Progress" has been completed

Native pixel art like the rest of the attic: 216 px high, one art pixel =
5 screen pixels at 1080p, the same wall and floor lines as the corridor.
The sketch is made from the finished picture itself (its edges in pencil),
so both versions always match.

Run from the repo root:  python3 rooms/werkstatt/source/make_room.py
"""
import os
import numpy as np
import cv2
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
W, H = 352, 216
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]], np.float32) / 16.0 + 1 / 32.0
SLOT = (64, 58)                 # the painting's gold frame (56 x 35, put up by the game)
SPLIT = 214                     # where the paint stops (ragged, see edge())


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


TEAL = ramp('#121f24', '#17282d', '#1d3237', '#243c40', '#2b474a', '#335354', '#3d605f', '#486d6b', '#557b77', '#648a84', '#76998f')
CEIL = ramp('#0e1416', '#141c1f', '#1a2427', '#212c2f')
FLOOR = ramp('#1e0b05', '#2e1206', '#3e180a', '#4e200f', '#5c2816', '#693317', '#753b1f', '#864324', '#9a4b24', '#ae5729', '#c26133')
WOOD = ramp('#331309', '#4b1f10', '#75361e', '#9a4f2c', '#c26a40', '#e39473')
GOLD = ramp('#3d2410', '#6e4518', '#a8742a', '#d4a24a', '#f2d27a', '#fff0b8')
BEIGE = ramp('#3a3226', '#5c5040', '#83755e', '#a8987a', '#c9b998', '#e4d6b4', '#f4ead0')
CORK = ramp('#4a2c16', '#6b4220', '#8c5a2c', '#a8733c', '#c08c52')
PAPER = hexc('#f1ebdd')
CHECK = hexc('#dcd5c6')
LEAD = hexc('#56525e')
LEAD2 = hexc('#938e9a')
INK = hexc('#22262e')

FONT = {
    'A': ['010', '101', '111', '101', '101'], 'D': ['110', '101', '101', '101', '110'], 'E': ['111', '100', '110', '100', '111'],
    'I': ['111', '010', '010', '010', '111'], 'K': ['101', '110', '100', '110', '101'], 'R': ['110', '101', '110', '101', '101'],
    'S': ['011', '100', '010', '001', '110'], 'T': ['111', '010', '010', '010', '010'], 'W': ['10001', '10001', '10101', '10101', '01010'],
    'O': ['010', '101', '101', '101', '010'], 'G': ['011', '100', '101', '101', '011'], 'U': ['101', '101', '101', '101', '111'],
    'B': ['110', '101', '110', '101', '110'], ' ': ['000', '000', '000', '000', '000'],
}


def text_w(s):
    return sum(len(FONT[ch][0]) + 1 for ch in s) - 1


def text(img, s, x, y, col):
    for ch in s:
        g = FONT[ch]
        for gy in range(5):
            for gx in range(len(g[0])):
                if g[gy][gx] == '1': img[y + gy, x + gx] = col
        x += len(g[0]) + 1


def rect(img, x0, y0, x1, y1, c):
    img[y0:y1 + 1, x0:x1 + 1] = c


def edge(y):
    """x where the paint stops, per row (ragged, slanting on the floor)"""
    r = np.random.default_rng(int(y) * 7 + 3)
    x = SPLIT + 4.0 * np.sin(y * 0.09) + 2.0 * np.sin(y * 0.31 + 1.0) + r.integers(-1, 2)
    if y > 152: x += (y - 152) * 0.42
    return int(round(x))


# ====================================================================== the finished room
def painted():
    img = np.zeros((H, W, 3), np.uint8)
    yy, xx = np.mgrid[0:H, 0:W]
    rng = np.random.default_rng(3)
    # light: the monitor (cool), the desk lamp, the picture lamp (warm), the window (moon)
    MON = (164, 104)
    cool = np.exp(-(((xx - MON[0]) / 46.0) ** 2 + ((yy - MON[1]) / 40.0) ** 2)) * 1.0
    warm = 0.9 * np.exp(-(((xx - 134) / 26.0) ** 2 + ((yy - 128) / 24.0) ** 2)) * (yy > 100)
    warm += 0.6 * np.exp(-(((xx - 92) / 26.0) ** 2 + ((yy - 74) / 26.0) ** 2)) * (yy > 50)
    moon = 0.5 * np.exp(-(((xx - 322) / 36.0) ** 2 + ((yy - 80) / 50.0) ** 2))
    base = 0.25 + 0.15 * (yy / H)

    # ---------------------------------------------------- wall: deep teal, wood panelling below
    wl = (base * 3.2 + cool * 3.2 + warm * 2.2 + moon * 1.6) * 1.0 + 0.6
    img[:] = dith(TEAL, wl, xx, yy)
    # a subtle vertical stripe wallpaper
    for x in range(W):
        if x % 12 == 0:
            for y in range(26, 112):
                img[y, x] = dith(TEAL, np.array(wl[y, x] - 0.7), np.array(x), np.array(y))
    # dado rail and panels
    for x in range(W):
        img[111, x] = WOOD[1]; img[112, x] = WOOD[4] if x % 9 else WOOD[5]; img[113, x] = WOOD[2]; img[114, x] = WOOD[0]
    for y in range(115, 145):
        for x in range(W):
            pan = x % 30
            lv = 1.6 + cool[y, x] * 1.6 + warm[y, x] * 1.8 + moon[y, x]
            if pan in (0, 1) or y in (115, 144): lv -= 1.1
            elif pan in (2,) or y == 116: lv += 0.7
            img[y, x] = dith(WOOD, np.array(lv), np.array(x), np.array(y))

    # ---------------------------------------------------- ceiling, beam
    for y in range(0, 17):
        plank = y // 4
        for x in range(W):
            seam = y % 4 == 3 or (x + plank * 37) % 53 == 0
            lv = 1.6 + ((plank * 7 + (x + plank * 37) // 53 * 3) % 4) * 0.35 + cool[20, x] * 0.8
            img[y, x] = CEIL[0] if seam else dith(CEIL, np.array(lv), np.array(x), np.array(y))
    for rx in range(4, W, 44):
        for y in range(0, 17):
            for x in range(rx, min(W, rx + 4)):
                img[y, x] = WOOD[[1, 3, 2, 1][x - rx]]
    prof = [0, 2, 4, 4, 3, 3, 2, 1, 0]
    for k, y in enumerate(range(16, 25)):
        for x in range(W):
            img[y, x] = WOOD[prof[k]]

    # ---------------------------------------------------- baseboard and floor
    for x in range(W):
        img[145, x] = WOOD[0]
        for y in range(146, 152):
            img[y, x] = dith(WOOD, np.array(1.6 + (cool[150, x] + warm[150, x]) * 2.0 - (y - 146) * 0.15), np.array(x), np.array(y))
        img[152, x] = WOOD[0]
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
            tone = 4.4 + (((row * 31 + seg * 17) * 2654435761) % 1000) / 1000.0 * 1.8 - 0.9
            gh = ((row * 7919 + seg * 104729 + int(round((k - row) * 6)) * 31 + (x // 5) * 3) * 2654435761) % 1000 / 1000.0
            tone += (gh - 0.5) * 0.8
            pool = 2.6 * np.exp(-(((x - 164) / 40.0) ** 2 + ((y - 168) / 14.0) ** 2)) + 1.8 * np.exp(-(((x - 132) / 24.0) ** 2 + ((y - 162) / 9.0) ** 2))
            pool += 1.2 * np.exp(-(((x - 318 + (y - 153) * 0.5) / 30.0) ** 2 + ((y - 172) / 20.0) ** 2))
            lv = tone - 2.4 + pool
            if seam: c = FLOOR[max(0, int(lv) - 3)]
            elif joint: c = FLOOR[max(0, int(lv) - 2)]
            else: c = dith(FLOOR, np.array(lv), np.array(x), np.array(y))
            img[y, x] = c

    # ---------------------------------------------------- the to-do list (cork board)
    bx0, by0, bx1, by1 = 13, 36, 59, 92
    for y in range(by0, by1 + 1):
        for x in range(bx0, bx1 + 1):
            e = min(x - bx0, bx1 - x, y - by0, by1 - y)
            if e < 2: c = WOOD[3] if e == 1 else WOOD[1]
            else: c = dith(CORK, np.array(2.2 + ((x * 13 + y * 7) % 5) * 0.18 + warm[y, x]), np.array(x), np.array(y))
            img[y, x] = c
    text(img, 'TODO', 28, 40, INK)
    notes = [(17, 48, '#ffe58a'), (38, 48, '#ffb3c7'), (17, 70, '#a8e6ff'), (38, 70, '#c8f0a8')]
    for k, (nx, ny, col) in enumerate(notes):
        cc = hexc(col)
        rect(img, nx, ny, nx + 17, ny + 17, cc)
        rect(img, nx + 1, ny + 17, nx + 17, ny + 18, (cc.astype(np.int32) * 0.6).astype(np.uint8))
        img[ny + 1, nx + 8] = hexc('#d0302a'); img[ny + 1, nx + 9] = hexc('#ff6a5a')     # pin
        for li in range(3):                                        # scribbled lines
            for x in range(nx + 3, nx + 11 + (li * 3) % 5):
                if (x + li) % 4: img[ny + 5 + li * 4, x] = INK
        if k < 2:                                                  # done: a green tick
            for (dx, dy) in [(12, 9), (13, 10), (14, 9), (15, 8), (16, 7)]:
                img[ny + dy, nx + dx] = hexc('#1f8a3a')
        elif k == 2:                                               # open: an empty box
            for dx in range(12, 16):
                img[ny + 6, nx + dx] = INK; img[ny + 10, nx + dx] = INK
            for dy in range(6, 11):
                img[ny + dy, nx + 12] = INK; img[ny + dy, nx + 15] = INK

    # ---------------------------------------------------- low cabinet with a cactus and books
    for y in range(116, 157):
        for x in range(12, 61):
            c = WOOD[3] if y < 119 else WOOD[2]
            if x in (12, 60) or y in (116, 156) or (y > 119 and x == 36): c = WOOD[0]
            if y > 119 and (y - 120) % 12 == 11: c = WOOD[1]
            img[y, x] = c
    for (kx, ky) in ((22, 128), (48, 128), (22, 140), (48, 140)):
        img[ky, kx - 2:kx + 3] = GOLD[3]
    POT = ramp('#5a2414', '#8e3a22', '#b8532f', '#d8754a')
    for y in range(106, 116):
        for x in range(18, 28):
            img[y, x] = POT[2] if x > 19 else POT[1]
    for y in range(92, 106):
        for x in range(20, 26):
            if (x - 23) ** 2 / 9.0 + (y - 99) ** 2 / 49.0 <= 1.0:
                img[y, x] = hexc('#4d8f45') if (x + y) % 3 else hexc('#7cb35a')
    for (bx, bh, col) in ((36, 12, '#e8574a'), (40, 10, '#4aa3e8'), (44, 13, '#f2c64a'), (49, 9, '#7ad07a')):
        rect(img, bx, 115 - bh, bx + 3, 115, hexc(col))
        img[115 - bh + 2, bx + 1:bx + 3] = GOLD[4]

    # ---------------------------------------------------- the picture lamp over the frame
    fx = SLOT[0] + 28
    for x in range(fx - 9, fx + 10):
        img[53, x] = GOLD[2]; img[54, x] = GOLD[4] if abs(x - fx) < 7 else GOLD[3]; img[55, x] = GOLD[1]
    for y in range(49, 53): img[y, fx] = GOLD[1]
    img[56, fx - 6:fx + 7] = hexc('#fff3c8')
    for y in range(SLOT[1] + 2, SLOT[1] + 38):
        for x in range(SLOT[0] + 56, SLOT[0] + 58):
            img[y, x] = (img[y, x].astype(np.int32) * 0.6).astype(np.uint8)
    for x in range(SLOT[0] + 2, SLOT[0] + 58):
        for y in range(SLOT[1] + 35, SLOT[1] + 37):
            img[y, x] = (img[y, x].astype(np.int32) * 0.6).astype(np.uint8)

    # ---------------------------------------------------- the desk
    dx0, dx1 = 122, 208
    for x in range(dx0, dx1 + 1):
        img[126, x] = WOOD[5] if x % 7 else WOOD[4]; img[127, x] = WOOD[4]; img[128, x] = WOOD[3]; img[129, x] = WOOD[1]
    for lx in (dx0 + 2, dx1 - 3):
        for y in range(130, 157):
            img[y, lx] = WOOD[3]; img[y, lx + 1] = WOOD[1]
    for x in range(dx0 + 2, dx1 - 1):                       # a drawer rail
        img[134, x] = WOOD[1]
    # computer tower under the desk
    for y in range(133, 157):
        for x in range(184, 201):
            c = BEIGE[3] if x > 185 else BEIGE[2]
            if x in (184, 200) or y in (133, 156): c = BEIGE[1]
            if 137 <= y <= 139 and 188 <= x <= 196: c = BEIGE[1]
            if 142 <= y <= 143 and 188 <= x <= 196: c = BEIGE[1]
            img[y, x] = c
    img[150, 196] = hexc('#3cff6a')
    # the box of bugs under the desk
    for y in range(138, 157):
        for x in range(130, 157):
            c = hexc('#b98a52') if (x + y) % 9 else hexc('#a87a46')
            if x in (130, 156) or y == 156: c = hexc('#6e4a26')
            if y == 138: c = hexc('#d6a868')
            img[y, x] = c
    for x in range(128, 150):                                 # a lid standing a bit open
        y = 137 - (x - 128) // 6
        img[y, x] = hexc('#d6a868'); img[y + 1, x] = hexc('#8a6234')
    text(img, 'BUGS', 135, 145, hexc('#2a1a10'))
    # cables
    for t in np.linspace(0, 1, 120):
        x = int(158 + 26 * t); y = int(155 - 6 * np.sin(t * np.pi))
        img[y, x] = hexc('#14181c')
    # the monitor: a big beige CRT
    mx0, my0, mx1, my1 = 142, 84, 188, 123
    for y in range(my0, my1 + 1):
        for x in range(mx0, mx1 + 1):
            e = min(x - mx0, mx1 - x, y - my0, my1 - y)
            lv = 4.3 - (y - my0) * 0.02 + (0.5 if x < mx0 + 3 else 0)
            c = dith(BEIGE, np.array(lv), np.array(x), np.array(y))
            if e == 0: c = BEIGE[1]
            img[y, x] = c
    sx0, sy0, sx1, sy1 = 147, 89, 183, 114
    for y in range(sy0, sy1 + 1):
        for x in range(sx0, sx1 + 1):
            e = min(x - sx0, sx1 - x, y - sy0, sy1 - y)
            img[y, x] = hexc('#0c1a1e') if e > 0 else hexc('#3a3226')
    rect(img, 160, 124, 170, 125, BEIGE[2])                   # foot
    img[118, 180:183] = hexc('#3cff6a')                        # power led
    for x in range(146, 184):                                  # keyboard
        img[124, x] = BEIGE[1]
        img[125, x] = BEIGE[5] if (x - 146) % 3 else BEIGE[3]
    # the desk lamp (left)
    LAMP = ramp('#2a1010', '#6a1e1e', '#b83a32', '#e8604a', '#ff9a7a')
    for y in range(122, 126): img[y, 126:133] = LAMP[1]
    for t in np.linspace(0, 1, 30):
        x = int(round(129 + 4 * t)); y = int(round(122 - 16 * t)); img[y, x] = LAMP[2]
    for t in np.linspace(0, 1, 20):
        x = int(round(133 + 7 * t)); y = int(round(106 + 4 * t)); img[y, x] = LAMP[2]
    for y in range(106, 113):
        for x in range(136, 145):
            if (x - 140) ** 2 / 20.0 + (y - 108) ** 2 / 8.0 <= 1.0 and y <= 110 + (x - 136) // 3:
                img[y, x] = LAMP[3] if y < 109 else LAMP[2]
    img[111:113, 140:144] = hexc('#fff3c8')
    # a mug with a smiley
    for y in range(117, 126):
        for x in range(194, 201):
            img[y, x] = hexc('#f2efe8') if x > 194 else hexc('#c9c4ba')
    img[119:123, 201] = hexc('#c9c4ba'); img[119, 202] = hexc('#c9c4ba'); img[122, 202] = hexc('#c9c4ba')
    img[117, 194:201] = hexc('#3a2a20')
    # the rubber duck
    DUCK = ramp('#a86a10', '#e8b020', '#ffd84a', '#fff09a')
    for y in range(115, 126):
        for x in range(201, 210):
            body = (x - 205) ** 2 / 16.0 + (y - 122) ** 2 / 9.0 <= 1.0
            head = (x - 203) ** 2 / 5.0 + (y - 117) ** 2 / 5.0 <= 1.0
            if body or head:
                img[y, x] = DUCK[2] if y < 121 else DUCK[1]
    img[116, 202] = INK
    img[117, 200] = hexc('#ff8a2a'); img[118, 200] = hexc('#e86a1a')

    # ---------------------------------------------------- name plate
    s = 'DIE WERKSTATT'
    tw = text_w(s)
    sw = tw + 8
    sx = 170 - sw // 2
    for x in (sx + 3, sx + sw - 4):
        for y in range(25, 30): img[y, x] = hexc('#14181c')
    for y in range(30, 41):
        for x in range(sx, sx + sw):
            e = min(x - sx, sx + sw - 1 - x, y - 30, 40 - y)
            img[y, x] = WOOD[0] if e == 0 else (WOOD[4] if y == 31 else (WOOD[3] if e == 1 else TEAL[1]))
    text(img, s, sx + 4, 33, hexc('#9fe8c8'))

    # ---------------------------------------------------- the right part (the one that's only sketched for now)
    # a bookshelf
    bx0, bx1 = 250, 292
    for y in range(64, 157):
        for x in range(bx0, bx1 + 1):
            if y < 67: c = WOOD[4] if y == 64 else WOOD[3]
            elif x in (bx0, bx0 + 1, bx1 - 1, bx1) or y in (95, 96, 125, 126, 155, 156): c = WOOD[2]
            else: c = WOOD[0] if (x + y) % 5 else WOOD[1]
            img[y, x] = c
    BOOKS = [hexc(h) for h in ('#e8574a', '#4aa3e8', '#f2c64a', '#7ad07a', '#c87ae8', '#f08a3a', '#5bb8a8', '#e070a8')]
    for shelf_y in (77, 107, 137):
        x = bx0 + 3
        while x < bx1 - 5:
            bw = int(rng.integers(3, 6)); bh = int(rng.integers(12, 18))
            col = BOOKS[int(rng.integers(0, len(BOOKS)))]
            if rng.random() < 0.12:
                x += bw + 2
                continue
            for y3 in range(shelf_y + 18 - bh, shelf_y + 18):
                for x3 in range(x, min(x + bw, bx1 - 2)):
                    k = x3 - x
                    c = col if 0 < k < bw - 1 else (col.astype(np.int32) * 0.65).astype(np.uint8)
                    if y3 == shelf_y + 18 - bh + 2 and 0 < k < bw - 1: c = GOLD[4]
                    img[y3, x3] = c
            x += bw
    # a window with the night outside
    wx0, wy0, wx1, wy1 = 302, 36, 342, 92
    for y in range(wy0, wy1 + 1):
        for x in range(wx0, wx1 + 1):
            e = min(x - wx0, wx1 - x, y - wy0, wy1 - y)
            if e < 3: c = WOOD[[1, 3, 4][e]]
            else:
                t = (y - wy0) / (wy1 - wy0)
                c = dith(ramp('#0b0a2c', '#14113f', '#211654', '#30196a', '#45207c'), np.array(0.5 + t * 3.0), np.array(x), np.array(y))
                h = (x * 73856093 ^ y * 19349663) % 1000
                if h < 14: c = hexc('#fff6d8') if h < 6 else hexc('#b9c8ff')
            img[y, x] = c
    for y in range(wy0 + 3, wy1 - 2): img[y, (wx0 + wx1) // 2] = WOOD[3]
    for x in range(wx0 + 3, wx1 - 2): img[(wy0 + wy1) // 2, x] = WOOD[3]
    for y in range(44, 54):                                    # the moon
        for x in range(312, 322):
            if (x - 317) ** 2 + (y - 49) ** 2 <= 16 and (x - 319) ** 2 + (y - 47) ** 2 > 9:
                img[y, x] = hexc('#fff0b8')
    for x in range(wx0 - 2, wx1 + 3):                          # sill
        img[93, x] = WOOD[4]; img[94, x] = WOOD[2]
    # a bean bag
    BEAN = ramp('#5a1a10', '#8e2e1a', '#c24a26', '#e8703a', '#ff9a5a')
    for y in range(128, 157):
        for x in range(296, 346):
            q = ((x - 321) / 25.0) ** 2 + ((y - 146) / 17.0) ** 2
            if q <= 1.0 and y > 128 + 4 * np.sin((x - 296) / 50.0 * np.pi) * 0:
                lv = 3.2 - (y - 128) * 0.06 - (x - 296) * 0.02 + (0.6 if q < 0.3 else 0)
                c = dith(BEAN, np.array(lv), np.array(x), np.array(y))
                if q > 0.9: c = BEAN[0]
                img[y, x] = c
    for t in np.linspace(0, 1, 30):                            # a crease
        img[int(140 + 5 * t), int(312 + 14 * t)] = BEAN[1]

    # a blueprint of a little robot (pinned up for the finished room)
    px0, py0, px1, py1 = 222, 46, 244, 80
    for y in range(py0, py1 + 1):
        for x in range(px0, px1 + 1):
            e = min(x - px0, px1 - x, y - py0, py1 - y)
            c = hexc('#2a5a9a') if (x + y) % 6 else hexc('#30629f')
            if e == 0: c = hexc('#1a3a6a')
            img[y, x] = c
    BL = hexc('#d8ecff')
    for x in range(227, 240):
        img[54, x] = BL; img[64, x] = BL
    for y in range(54, 65):
        img[y, 227] = BL; img[y, 239] = BL
    rect(img, 230, 57, 231, 60, BL); rect(img, 235, 57, 236, 60, BL)          # eyes
    img[50:54, 233] = BL; img[49, 232:235] = BL                                 # antenna
    for y in range(66, 76): img[y, 230] = BL; img[y, 236] = BL                  # body
    for x in range(230, 237): img[66, x] = BL; img[75, x] = BL
    for x in range(225, 229): img[69, x] = BL                                  # arms
    for x in range(238, 242): img[69, x] = BL
    img[47, 223] = hexc('#e04040'); img[47, 243] = hexc('#e04040')             # pins

    # ---------------------------------------------------- the post at the left edge
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
    return img


# ====================================================================== the sketch
def sketch(done):
    """the right part as a pencil sketch on an unpainted canvas"""
    img = done.copy()
    g = cv2.cvtColor(done, cv2.COLOR_RGB2GRAY).astype(np.float32)
    gx = cv2.Sobel(g, cv2.CV_32F, 1, 0, ksize=3)
    gy = cv2.Sobel(g, cv2.CV_32F, 0, 1, ksize=3)
    mag = np.hypot(gx, gy)
    rng = np.random.default_rng(9)
    for y in range(H):
        e = edge(y)
        for x in range(e, W):
            # the unpainted canvas: a transparency checkerboard, like an image editor
            c = PAPER if ((x // 4) + (y // 4)) % 2 == 0 else CHECK
            m = mag[y, x]
            if y in (24, 25, 111, 112, 114, 145, 152):       # structure lines of the room
                c = LEAD2 if (x * 7 + y) % 9 else c
            if m > 150 and rng.random() < 0.95:
                c = LEAD
            elif m > 70 and rng.random() < 0.7:
                c = LEAD2
            # hatch the books and the bean bag a little
            elif g[y, x] < 70 and (x + y) % 4 == 0 and ((252 <= x <= 290 and 67 <= y <= 155) or (297 <= x <= 345 and 132 <= y <= 156)):
                c = LEAD2
            img[y, x] = c
    # floor in perspective, only as guide lines
    vy, KL = 104.0, 523.0
    for y in range(153, H):
        d = y - vy
        if int(np.floor(KL / (d + 1))) != int(np.floor(KL / d)):
            for x in range(edge(y), W):
                if (x // 3) % 3: img[y, x] = LEAD2
    # the ragged paint edge: brush dabs and drips
    for y in range(26, H, 1):
        e = edge(y)
        if y % 7 == 0:
            for x in range(e, e + int(rng.integers(2, 7))):
                if x < W: img[y, x] = done[y, x]
        if y % 23 == 5 and y < 140:
            for k in range(int(rng.integers(4, 12))):
                if y + k < 145: img[y + k, e + 1] = done[y + k, e - 2]
    # pencil notes on the canvas
    # (tiny, scribbled: "regal", "fenster" – read as squiggles at this size)
    for (nx, ny, ln) in ((258, 58, 18), (304, 30, 22), (300, 118, 20)):
        for x in range(nx, nx + ln):
            if (x * 3) % 5: img[ny + (1 if x % 4 == 0 else 0), x] = LEAD
    return img


def props(img):
    """a ladder and paint buckets where the painting stopped"""
    LAD = ramp('#5a3a1c', '#8a5a2a', '#b07a3c', '#d09a58')
    for side in (0, 13):
        for t in np.linspace(0, 1, 200):
            x = int(round(222 + side + 10 * t)); y = int(round(157 - 101 * t))
            img[y, x] = LAD[2]; img[y, x + 1] = LAD[1]
    for k in range(9):
        t = (k + 0.5) / 9
        y = int(round(157 - 101 * t)); x0 = int(round(222 + 10 * t))
        for x in range(x0 + 1, x0 + 14):
            img[y, x] = LAD[3] if x % 2 else LAD[2]
    for (cx, col, h) in ((240, '#e8574a', 12), (252, '#4aa3e8', 9)):
        cc = hexc(col)
        for y in range(157 - h, 157):
            for x in range(cx - 5, cx + 6):
                img[y, x] = hexc('#b8bcc4') if x > cx - 4 else hexc('#7a7e88')
        for x in range(cx - 5, cx + 6):
            img[157 - h, x] = cc; img[157 - h + 1, x] = cc if (x % 3) else hexc('#b8bcc4')
        img[157 - h + 2: 157 - h + 5, cx - 3] = cc                 # a drip
        img[156, cx - 6:cx + 7] = hexc('#3a3e48')
    # a brush lying across the blue bucket
    for x in range(244, 262):
        img[157 - 10, x] = hexc('#c08c52') if x < 256 else hexc('#3a3226')
    img[146, 256:259] = hexc('#4aa3e8')
    return img


def main():
    done = painted()
    room = props(sketch(done))
    Image.fromarray(room).save(os.path.join(HERE, '..', 'room.png'))
    # the finished right part as an overlay (transparent where nothing changes)
    rgba = np.zeros((H, W, 4), np.uint8)
    rgba[:, :, :3] = done
    for y in range(H):
        x0 = max(0, edge(y) - 1)
        rgba[y, x0:, 3] = 255
    for y in range(H):                     # paint over the ladder and the buckets too
        rgba[y, 218:, 3] = 255
    Image.fromarray(rgba).save(os.path.join(HERE, '..', 'room_done.png'))
    print('wrote room.png and room_done.png', room.shape)


if __name__ == '__main__':
    main()
