"""Tileable fabric and cardboard textures for the Plush Desk.

Writes ../textures/*.png. All of them tile seamlessly.
  felt.png    RG = fibre normal (xy), B = fibre height        (data)
  knit.png    RG = knit normal,       B = yarn height          (data)
  cord.png    RG = corduroy normal,   B = rib height           (data)
  weave.png   RG = cotton weave normal, B = thread height      (data)
  mottle.png  RGB = three soft noises for colour variation     (data)
  kraft.png   cardboard (kraft paper) albedo                   (colour)
  labels.png  R = embroidered key legends, G = blurred (emboss) (data)

Usage: python3 make_textures.py
"""
import os, math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "textures")
FONT = os.path.join(HERE, "..", "fonts", "Fredoka-Bold.woff2")
os.makedirs(OUT, exist_ok=True)


def norm01(a):
    a = a - a.min()
    return a / max(a.max(), 1e-9)


def fft_noise(n, beta, seed, fmin=0.0):
    """Periodic 1/f^beta noise in 0..1."""
    r = np.random.default_rng(seed)
    f = np.fft.fftfreq(n)
    fx, fy = np.meshgrid(f, f)
    k = np.sqrt(fx * fx + fy * fy)
    k[0, 0] = 1.0
    amp = k ** (-beta / 2.0)
    amp[k < fmin] = 0.0
    amp[0, 0] = 0.0
    spec = (r.normal(size=(n, n)) + 1j * r.normal(size=(n, n))) * amp
    return norm01(np.real(np.fft.ifft2(spec)))


def wrap_blur(h, s):
    return ndimage.gaussian_filter(h, s, mode="wrap")


def pack(h, strength, extra=None):
    """height -> RGB (normal xy in RG, height in B), OpenGL (Y+) convention."""
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5
    nx, ny, nz = -dx * strength, dy * strength, np.ones_like(h)
    l = np.sqrt(nx * nx + ny * ny + nz * nz)
    nx, ny = nx / l, ny / l
    b = norm01(h) if extra is None else extra
    rgb = np.stack([nx * 0.5 + 0.5, ny * 0.5 + 0.5, b], -1)
    return Image.fromarray((np.clip(rgb, 0, 1) * 255 + 0.5).astype(np.uint8), "RGB")


def fibres(n, count, lmin, lmax, wmin, wmax, curl, seed, layers=1.0):
    """Z-buffered random curly fibres (later = higher), wrapped at the edges."""
    r = np.random.default_rng(seed)
    im = Image.new("L", (n, n), 0)
    d = ImageDraw.Draw(im)
    heights = np.sort(r.random(count))
    for i in range(count):
        x, y = r.random() * n, r.random() * n
        a = r.random() * math.tau
        L = r.uniform(lmin, lmax)
        w = int(round(r.uniform(wmin, wmax)))
        k = r.normal() * curl
        pts = []
        steps = max(3, int(L / 6))
        for s in range(steps + 1):
            pts.append((x, y))
            a += k / steps
            x += math.cos(a) * L / steps
            y += math.sin(a) * L / steps
        v = int(40 + 215 * heights[i] ** layers)
        for ox in (-n, 0, n):
            for oy in (-n, 0, n):
                p = [(px + ox, py + oy) for px, py in pts]
                xs = [q[0] for q in p]
                ys = [q[1] for q in p]
                if max(xs) < -4 or min(xs) > n + 4 or max(ys) < -4 or min(ys) > n + 4:
                    continue
                d.line(p, fill=v, width=w)
    return np.asarray(im, dtype=np.float32) / 255.0


# --------------------------------------------------------------------------- felt
def make_felt():
    n = 1024
    fib = fibres(n, 26000, 18, 70, 1, 2, 2.2, 11, layers=0.8)
    fib = wrap_blur(fib, 0.7)
    cloud = fft_noise(n, 2.6, 12)            # matted density clouds
    fine = fft_noise(n, 1.2, 13)             # fine fuzz
    h = fib * 0.55 + cloud * 0.6 + fine * 0.18
    pack(h, 9.0).save(os.path.join(OUT, "felt.png"), optimize=True)


# --------------------------------------------------------------------------- knit
def make_knit():
    """Stockinette: columns of V-shaped stitches, 8 columns x 10 rows per tile."""
    n = 512
    cols, rows = 8, 10
    y, x = np.mgrid[0:n, 0:n].astype(np.float32) / n
    u = (x * cols) % 1.0
    v = (y * rows) % 1.0
    h = np.zeros((n, n), np.float32)
    for cx, ang in ((0.27, 0.42), (0.73, -0.42)):
        for dv in (-1.0, 0.0, 1.0):        # the legs overlap the next row a bit
            px, py = u - cx, (v - 0.5 - dv) * (cols / rows) * 1.25
            ca, sa = math.cos(ang), math.sin(ang)
            lx = px * ca - py * sa
            ly = px * sa + py * ca
            e = (lx / 0.2) ** 2 + (ly / 0.5) ** 2
            leg = np.sqrt(np.clip(1.0 - e, 0.0, 1.0))
            # twisted plies along each leg
            ply = 0.85 + 0.15 * np.sin((ly * 9.0 + lx * 22.0) * math.pi)
            h = np.maximum(h, leg * ply)
    fuzz = fft_noise(n, 1.3, 21)
    h = h + fuzz * 0.12 + fft_noise(n, 2.4, 22) * 0.1
    pack(wrap_blur(h, 0.6), 6.0).save(os.path.join(OUT, "knit.png"), optimize=True)


# --------------------------------------------------------------------------- corduroy
def make_cord():
    n = 512
    ribs = 14
    y, x = np.mgrid[0:n, 0:n].astype(np.float32) / n
    t = (x * ribs) % 1.0
    prof = np.sqrt(np.clip(1.0 - (2.0 * t - 1.0) ** 2, 0, 1)) ** 0.6
    r = np.random.default_rng(31)
    rib_id = np.floor(x * ribs).astype(int) % ribs
    rib_var = r.uniform(0.85, 1.0, ribs)[rib_id]
    pile = wrap_blur(fibres(n, 9000, 4, 12, 1, 1, 0.5, 32), 0.5)
    pile_streak = ndimage.gaussian_filter(r.random((n, n)).astype(np.float32), (6, 0.6), mode="wrap")
    h = prof * rib_var + pile * 0.12 + norm01(pile_streak) * 0.15
    pack(h, 7.0).save(os.path.join(OUT, "cord.png"), optimize=True)


# --------------------------------------------------------------------------- weave
def make_weave():
    """Plain cotton weave, 32 threads per tile each way."""
    n = 512
    th = 32
    y, x = np.mgrid[0:n, 0:n].astype(np.float32) / n
    tx, ty = (x * th) % 1.0, (y * th) % 1.0
    ix, iy = np.floor(x * th).astype(int), np.floor(y * th).astype(int)
    warp_prof = np.sqrt(np.clip(1 - (2 * tx - 1) ** 2, 0, 1))
    weft_prof = np.sqrt(np.clip(1 - (2 * ty - 1) ** 2, 0, 1))
    # over/under: warp is on top where (ix+iy) even
    over = ((ix + iy) % 2 == 0)
    warp_h = warp_prof * (0.75 + 0.25 * np.where(over, np.cos((ty - 0.5) * math.pi), -np.cos((ty - 0.5) * math.pi)))
    weft_h = weft_prof * (0.75 + 0.25 * np.where(~over, np.cos((tx - 0.5) * math.pi), -np.cos((tx - 0.5) * math.pi)))
    h = np.maximum(warp_h, weft_h)
    h = h + fft_noise(n, 1.4, 41) * 0.15 + fft_noise(n, 2.6, 42) * 0.12
    pack(wrap_blur(h, 0.5), 5.0).save(os.path.join(OUT, "weave.png"), optimize=True)


# --------------------------------------------------------------------------- mottle
def make_mottle():
    n = 512
    rgb = np.stack([fft_noise(n, 2.8, 51), fft_noise(n, 2.2, 52), fft_noise(n, 3.2, 53)], -1)
    Image.fromarray((rgb * 255 + 0.5).astype(np.uint8), "RGB").save(os.path.join(OUT, "mottle.png"), optimize=True)


# --------------------------------------------------------------------------- kraft
def make_kraft():
    n = 1024
    base = np.array([0.66, 0.49, 0.32], np.float32)
    cloud = fft_noise(n, 2.7, 61)
    fine = fft_noise(n, 1.0, 62)
    fib_d = wrap_blur(fibres(n, 9000, 6, 26, 1, 1, 1.5, 63), 0.4)
    fib_l = wrap_blur(fibres(n, 5000, 5, 18, 1, 1, 1.5, 64), 0.4)
    lum = 1.0 + (cloud - 0.5) * 0.16 + (fine - 0.5) * 0.08 - (fib_d > 0.15) * fib_d * 0.16 + (fib_l > 0.15) * fib_l * 0.12
    r = np.random.default_rng(65)
    specks = np.zeros((n, n), np.float32)
    for _ in range(500):
        sx, sy = r.integers(0, n, 2)
        specks[sy, sx] = r.uniform(0.3, 1.0)
    specks = wrap_blur(specks, 0.8) * 5.0
    col = base[None, None, :] * lum[..., None]
    col = col * (1.0 - np.clip(specks, 0, 0.6)[..., None] * 0.7)
    col = np.clip(col, 0, 1) ** (1 / 1.0)
    Image.fromarray((col * 255 + 0.5).astype(np.uint8), "RGB").save(os.path.join(OUT, "kraft.png"), optimize=True)


# --------------------------------------------------------------------------- key legends
# Atlas of 10x10 cells, 128 px each. Order matters: plush_desk.gd mirrors this list.
LABELS = (
    list("ABCDEFGHIJKLMNOPQRSTUVWXYZ") + list("0123456789") + list("ÄÖÜß")
    + list("`-=[]\\;',./<#+^´")
    + ["esc", "tab", "caps", "shift", "ctrl", "alt", "enter", "del", "ins", "home", "end",
       "pg up", "pg dn", "fn", "menu", "BKSP", "LEFT", "RIGHT", "UP", "DOWN", "STAR"]
    + ["F%d" % i for i in range(1, 13)]
    + ["prt", "scr", "pause", "alt gr"]
)


def make_labels():
    C, G = 128, 10
    im = Image.new("L", (C * G, C * G), 0)
    d = ImageDraw.Draw(im)
    for i, lab in enumerate(LABELS):
        cx, cy = (i % G) * C + C / 2, (i // G) * C + C / 2
        if lab == "BKSP":
            pts = [(-34, 0), (-14, -20), (30, -20), (30, 20), (-14, 20)]
            d.polygon([(cx + x, cy + y) for x, y in pts], fill=255)
            d.polygon([(cx + x * 0.62 + 2, cy + y * 0.55) for x, y in pts], fill=0)
            for s in (-1, 1):
                d.line([(cx - 2, cy - 8), (cx + 14, cy + 8)][::s], fill=255, width=6)
            d.line([(cx - 2, cy - 8), (cx + 14, cy + 8)], fill=255, width=6)
            d.line([(cx - 2, cy + 8), (cx + 14, cy - 8)], fill=255, width=6)
            continue
        if lab in ("LEFT", "RIGHT", "UP", "DOWN"):
            ang = {"RIGHT": 0, "DOWN": 90, "LEFT": 180, "UP": 270}[lab]
            pts = [(30, 0), (2, -26), (2, -10), (-28, -10), (-28, 10), (2, 10), (2, 26)]
            ca, sa = math.cos(math.radians(ang)), math.sin(math.radians(ang))
            d.polygon([(cx + x * ca - y * sa, cy + x * sa + y * ca) for x, y in pts], fill=255)
            continue
        if lab == "STAR":
            pts = []
            for k in range(8):
                rr = 34 if k % 2 == 0 else 11
                a = k * math.pi / 4 - math.pi / 2
                pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
            d.polygon(pts, fill=255)
            continue
        size = 84 if len(lab) == 1 else (50 if len(lab) <= 3 else 38)
        f = ImageFont.truetype(FONT, size)
        d.text((cx, cy), lab, font=f, fill=255, anchor="mm")
    m = np.asarray(im, np.float32) / 255.0
    emb = ndimage.gaussian_filter(m, 3.0)
    rgb = np.stack([m, norm01(emb), np.zeros_like(m)], -1)
    Image.fromarray((rgb * 255 + 0.5).astype(np.uint8), "RGB").save(os.path.join(OUT, "labels.png"), optimize=True)


if __name__ == "__main__":
    make_felt(); print("felt")
    make_knit(); print("knit")
    make_cord(); print("cord")
    make_weave(); print("weave")
    make_mottle(); print("mottle")
    make_kraft(); print("kraft")
    make_labels(); print("labels", len(LABELS))
