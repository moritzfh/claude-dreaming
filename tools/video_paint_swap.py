# Offline tool (OpenCV), run in a folder with the extracted film frames (frames/f_0001.png ...),
# the tracked canvas rects (rects.json), the film painting P_film2.png and our painting render.
# Output: out/f_*.png -> re-encode part_a6.ogv with ffmpeg (libtheora -q:v 6, 30 fps).
"""Replace the painting Claude paints in film part A (frames 146-458 of part_a6)
with our own world (P_ours), keeping the film's painting progress
(sepia under-painting -> colour), its lighting and everything in front of the
canvas (robot, brush, sparkles).

Pass 1 measures, per frame and in canvas coordinates (192x108), how far the
film's painting has progressed from sepia to colour (w), plus the shot's
colour transform (g, o). These are smoothed over time (and kept monotonic),
so the replacement does not flicker. Pass 2 composites at full resolution.
"""
import cv2, numpy as np, json, sys, time
from scipy.signal import savgol_filter
from scipy.ndimage import gaussian_filter1d

R = {int(k): v for k, v in json.load(open('rects.json')).items()}
# the tracker is reliable from frame 168 on (before that it sometimes locks
# onto the wrong frame); the camera is a slow zoom on a fixed centre, so the
# earlier frames are extrapolated from the first reliable ones
idx = np.arange(168, 459)
x = np.array([R[i][1] for i in idx]); y = np.array([R[i][2] for i in idx]); w = np.array([R[i][3] for i in idx])
cx = savgol_filter(x + w / 2, 15, 2, mode='nearest'); cy = savgol_filter(y + w * 9 / 32, 15, 2, mode='nearest'); lw = savgol_filter(np.log(w), 15, 2, mode='nearest')
rect = {}
for k, i in enumerate(idx): rect[i] = (cx[k], cy[k], float(np.exp(lw[k])))
# the zoom eases in: canvas widths measured by hand on frames 130/146/158
from scipy.interpolate import PchipInterpolator
c0 = (float(np.mean((x + w / 2)[:20])), float(np.mean((y + w * 9 / 32)[:20])))
ease = PchipInterpolator([120, 130, 146, 158, 168, 172], np.log([330.0, 338.0, 355.0, 371.0, float(np.exp(lw[0])), float(np.exp(lw[4]))]))
for i in range(120, 168):
    rect[i] = (c0[0], c0[1], float(np.exp(ease(i))))
START, FADE_END, LAST = 146, 162, 458
LW, LH = 192, 108

P_film = cv2.imread('P_film2.png').astype(np.float32)
P_ours = cv2.imread(sys.argv[1] if len(sys.argv) > 1 else '/home/claude/shots/P_ours.png').astype(np.float32)
P_ours = cv2.resize(P_ours, (1920, 1080), interpolation=cv2.INTER_AREA)

def warp(img, r):
    c_x, c_y, ww = r; hh = ww * 9 / 16
    if ww < 1900:
        small = cv2.resize(img, (max(2, int(round(ww))), max(2, int(round(hh)))), interpolation=cv2.INTER_AREA)
        M2 = np.array([[ww / small.shape[1], 0, c_x - ww / 2], [0, hh / small.shape[0], c_y - hh / 2]], np.float32)
        return cv2.warpAffine(small, M2, (1920, 1080), flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_REPLICATE)
    M = np.array([[ww / img.shape[1], 0, c_x - ww / 2], [0, hh / img.shape[0], c_y - hh / 2]], np.float32)
    return cv2.warpAffine(img, M, (1920, 1080), flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_REPLICATE)

def unwarp_lo(F, r):
    """film frame -> canvas coordinates at LWxLH (+ validity mask)"""
    c_x, c_y, ww = r; hh = ww * 9 / 16
    s = ww / LW
    Fb = cv2.GaussianBlur(F, (0, 0), max(0.6, 0.5 * s))
    U, V = np.meshgrid(np.arange(LW, dtype=np.float32) + 0.5, np.arange(LH, dtype=np.float32) + 0.5)
    mx = (c_x - ww / 2 + U * ww / LW).astype(np.float32); my = (c_y - hh / 2 + V * hh / LH).astype(np.float32)
    out = cv2.remap(Fb, mx, my, cv2.INTER_LINEAR, borderMode=cv2.BORDER_REPLICATE)
    inset = 1.5 * s
    valid = (mx > c_x - ww / 2 + inset) & (mx < c_x + ww / 2 - inset) & (my > c_y - hh / 2 + inset) & (my < c_y + hh / 2 - inset)
    valid &= (mx > 1) & (mx < 1918) & (my > 1) & (my < 1078)
    return out, valid

def rect_mask(r, inset=2.0):
    c_x, c_y, ww = r; hh = ww * 9 / 16
    m = np.zeros((1080, 1920), np.float32)
    x0 = int(np.ceil(c_x - ww / 2 + inset)); y0 = int(np.ceil(c_y - hh / 2 + inset))
    x1 = int(np.floor(c_x + ww / 2 - inset)); y1 = int(np.floor(c_y + hh / 2 - inset))
    m[max(y0, 0):min(y1, 1080), max(x0, 0):min(x1, 1920)] = 1.0
    return m

def lum(img): return img @ np.array([0.114, 0.587, 0.299], np.float32)

# --- the film's sepia under-painting as a function of painting luminance
Fs, Ls = [], []
for i in range(150, 161):
    F = cv2.imread(f'frames/f_{i:04d}.png').astype(np.float32)
    r = rect[i]; m = rect_mask(r, 6) > 0
    Fs.append(cv2.GaussianBlur(F, (0, 0), 2)[m]); Ls.append(lum(cv2.GaussianBlur(warp(P_film, r), (0, 0), 2))[m])
Fs = np.concatenate(Fs); Ls = np.concatenate(Ls) / 255.0
A = np.stack([np.ones_like(Ls), Ls, Ls * Ls], 1)
coef = np.linalg.lstsq(A, Fs, rcond=None)[0]
for _ in range(2):
    res = np.abs(A @ coef - Fs).sum(1); keep = res < np.percentile(res, 70)
    coef = np.linalg.lstsq(A[keep], Fs[keep], rcond=None)[0]
def sepia(img):
    L = lum(img) / 255.0
    return np.clip(np.stack([np.ones_like(L), L, L * L], -1) @ coef, 0, 255).astype(np.float32)
S_film = sepia(P_film); S_ours = sepia(P_ours)
Pf_lo = cv2.resize(cv2.GaussianBlur(P_film, (0, 0), 3), (LW, LH), interpolation=cv2.INTER_AREA)
Sf_lo = cv2.resize(cv2.GaussianBlur(S_film, (0, 0), 3), (LW, LH), interpolation=cv2.INTER_AREA)
print('sepia coef', coef.round(1).tolist(), flush=True)

# --- pass 1: progress map + colour transform per frame
frames = list(range(START, LAST + 1))
T = len(frames)
W = np.full((T, LH, LW), np.nan, np.float32)
G = np.ones((T, 3), np.float32); O = np.zeros((T, 3), np.float32)
d = Pf_lo - Sf_lo
dd = (d * d).sum(-1) + 60.0
t0 = time.time()
LO = {}
for t, i in enumerate(frames):
    F = cv2.imread(f'frames/f_{i:04d}.png').astype(np.float32)
    LO[i] = unwarp_lo(F, rect[i])

def measure(Fl, valid, g, o, fit):
    keep = valid.copy()
    for it in range(4 if fit else 2):
        Fc = (Fl - o) / g
        wl = np.clip(((Fc - Sf_lo) * d).sum(-1) / dd, 0, 1)
        model = Sf_lo + d * wl[..., None]
        if fit:
            for c in range(3):
                xv = model[..., c][keep]; yv = Fl[..., c][keep]
                if xv.size < 300: break
                g[c], o[c] = np.linalg.lstsq(np.stack([xv, np.ones_like(xv)], 1), yv, rcond=None)[0]
        resid = np.abs(Fl - (model * g + o)).sum(-1)
        thr = max(30.0, 3.0 * np.median(resid[valid]))
        keep = valid & (resid < thr)
    return wl, keep, g, o

# the shot's colour transform only can be measured once the painting is done
# (otherwise it trades off against the sepia->colour progress), and the attic
# light does not change: fit it on the late frames, use it everywhere
for t, i in enumerate(frames):
    if i < 260: continue
    _, _, g, o = measure(*LO[i], np.ones(3, np.float32), np.zeros(3, np.float32), True)
    G[t] = g; O[t] = o
late = np.array(frames) >= 260
g_fix = np.median(G[late], 0); o_fix = np.median(O[late], 0)
print('grade', g_fix.round(3), o_fix.round(1), flush=True)
for t, i in enumerate(frames):
    wl, keep, _, _ = measure(*LO[i], g_fix.copy(), o_fix.copy(), False)
    keep = cv2.erode(keep.astype(np.uint8), np.ones((3, 3), np.uint8)) > 0
    W[t][keep] = wl[keep]
    G[t] = g_fix; O[t] = o_fix
    if i % 25 == 0: print('p1', i, 'w=%.2f keep=%.2f' % (np.nanmean(W[t]), keep.mean()), '%.0fs' % (time.time() - t0), flush=True)

# --- temporal treatment: fill gaps, smooth, never go back from colour to sepia
tt = np.arange(T)
flat = W.reshape(T, -1)
for p in range(flat.shape[1]):
    col = flat[:, p]; ok = ~np.isnan(col)
    if ok.sum() == 0: col[:] = np.nan
    elif ok.sum() < T: col[~ok] = np.interp(tt[~ok], tt[ok], col[ok])
mean_t = np.nanmean(flat, 1)
for t in range(T):
    bad = np.isnan(flat[t]); flat[t][bad] = mean_t[t]
W = flat.reshape(T, LH, LW)
W = gaussian_filter1d(W, 2.5, axis=0)
W = np.maximum.accumulate(W, axis=0)
# the last frames show the finished painting: that is full colour per pixel.
W_end = np.maximum(W[-8:].mean(0), 0.5)
r = np.clip(W / W_end, 0, 1)
# the film's intermediate stages are muted; perceptually its colour arrives
# later than the raw projection says
x_ = np.clip((r - 0.5) / 0.42, 0, 1)
W = x_ * x_ * (3 - 2 * x_)
for t in range(T): W[t] = cv2.GaussianBlur(W[t], (0, 0), 1.5)
np.savez('pass1.npz', W=W, G=G, O=O)
print('pass1 done %.0fs' % (time.time() - t0), 'w by frame:', [round(float(W[t].mean()), 2) for t in range(0, T, 30)], flush=True)

# --- pass 2: composite
# the film's painter signs the canvas in the bottom right corner at the very
# end ("Claude"); keep the letters, but not the film's water around them
SIG = np.zeros((1080, 1920), np.float32); SIG[985:1056, 1768:1872] = 1.0
# ... and just before that it paints a tiny Claude onto the garden path
# (frame 446). Ours stands where the player really is when the game starts:
# the spawn point seen from the intro camera (feet at FEET in canvas pixels).
TINY_X0, TINY_X1, TINY_Y0, TINY_Y1 = 630, 740, 620, 740
TINY_FROM = 446
FEET = (891.0, 716.0)
crops = []
Uc, Vc = np.meshgrid(np.arange(TINY_X0, TINY_X1, dtype=np.float32) + 0.5, np.arange(TINY_Y0, TINY_Y1, dtype=np.float32) + 0.5)
for i in range(448, 459):
    c_x, c_y, ww = rect[i]; hh = ww * 9 / 16
    mx = (c_x - ww / 2 + Uc * ww / 1920).astype(np.float32); my = (c_y - hh / 2 + Vc * hh / 1080).astype(np.float32)
    crops.append(cv2.remap(cv2.imread(f'frames/f_{i:04d}.png').astype(np.float32), mx, my, cv2.INTER_LINEAR))
spr = np.median(np.stack(crops), 0)
bg = P_film[TINY_Y0:TINY_Y1, TINY_X0:TINY_X1]
sa = np.clip((np.abs(spr - bg).sum(-1) - 45.0) / 50.0, 0, 1)
# its red body sits on an orange under-painting ghost: key it by colour too
body = np.clip((np.minimum(spr[..., 2] - spr[..., 0], spr[..., 2] - spr[..., 1]) - 45.0) / 30.0, 0, 1)
box = np.zeros_like(sa); box[40:85, 30:65] = 1.0
sa = np.maximum(sa, body * box) * box
n_l, lab, stats, _ = cv2.connectedComponentsWithStats((sa > 0.5).astype(np.uint8))
if n_l > 1:
    keep_l = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
    blob = cv2.dilate((lab == keep_l).astype(np.uint8), np.ones((5, 5), np.uint8)).astype(np.float32)
    sa = sa * blob
sa = cv2.GaussianBlur(sa, (0, 0), 0.7)
ys_, xs_ = np.where(sa > 0.5)
fx_, fy_ = xs_.mean(), ys_.max()          # feet of the film's tiny robot
SPR = np.zeros((1080, 1920, 3), np.float32); SPR_A = np.zeros((1080, 1920), np.float32)
ox, oy = int(round(FEET[0] - fx_)), int(round(FEET[1] - fy_))
h_, w_ = sa.shape
SPR[oy:oy + h_, ox:ox + w_] = spr; SPR_A[oy:oy + h_, ox:ox + w_] = sa
TINY = np.zeros((1080, 1920), np.float32); TINY[TINY_Y0:TINY_Y1, TINY_X0:TINY_X1] = 1.0
print('tiny robot sprite', int((sa > 0.5).sum()), 'px, moved by', ox - TINY_X0, oy - TINY_Y0, flush=True)
import os
p2_range = os.environ.get('FRAMES')
p2_lo, p2_hi = (int(v) for v in p2_range.split('-')) if p2_range else (START, LAST)
log = {}
for t, i in enumerate(frames):
    if i < p2_lo or i > p2_hi: continue
    F = cv2.imread(f'frames/f_{i:04d}.png').astype(np.float32)
    r = rect[i]
    m = rect_mask(r)
    Pf, Sf = warp(P_film, r), warp(S_film, r)
    Po, So = warp(P_ours, r), warp(S_ours, r)
    wmap = warp(cv2.resize(W[t], (1920, 1080), interpolation=cv2.INTER_CUBIC), r)
    wmap = np.clip(wmap, 0, 1)[..., None]
    g, o = G[t], O[t]
    Fb = cv2.GaussianBlur(F, (0, 0), 2.0)
    Pfb, Sfb = cv2.GaussianBlur(Pf, (0, 0), 2.0), cv2.GaussianBlur(Sf, (0, 0), 2.0)
    # occluders: compare the film to its own painting under a fine, per-frame progress map
    dloc = Pfb - Sfb
    wpx = np.clip((((Fb - o) / g - Sfb) * dloc).sum(-1) / ((dloc * dloc).sum(-1) + 60.0), 0, 1)
    sig = max(3.0, r[2] * 0.012)
    wf = cv2.GaussianBlur(wpx * m, (0, 0), sig) / np.maximum(cv2.GaussianBlur(m, (0, 0), sig), 1e-3)
    model_f = (Sfb + dloc * np.clip(wf, 0, 1)[..., None]) * g + o
    resid = np.abs(Fb - model_f).sum(-1)
    sel = m > 0
    thr = max(45.0, 3.0 * np.median(resid[sel])) if sel.any() else 45.0
    occ = ((resid > thr) & sel).astype(np.uint8)
    occ = cv2.morphologyEx(occ, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))
    occ = cv2.dilate(occ, np.ones((5, 5), np.uint8))
    occ = cv2.GaussianBlur(occ.astype(np.float32), (0, 0), 1.5)
    ours = (So + (Po - So) * wmap) * g + o
    sreg = warp(SIG, r) > 0.5
    letters = None
    if sreg.any():
        # in the signature corner only big blobs (robot pixels) count as occluders
        big = ((resid > thr) & sreg).astype(np.uint8)
        big = cv2.morphologyEx(big, cv2.MORPH_OPEN, np.ones((7, 7), np.uint8))
        big = cv2.GaussianBlur(big.astype(np.float32), (0, 0), 0.6)
        occ = np.where(sreg, big, occ)
        red = F[..., 2] - np.maximum(F[..., 0], F[..., 1])
        letters = np.clip((red - 12.0) / 40.0, 0, 1) * sreg * (1.0 - np.clip(big * 2, 0, 1))
    if i >= TINY_FROM:
        occ = occ * (1.0 - (warp(TINY, r) > 0.5))
    alpha = m * (1.0 - np.clip(occ * 1.6, 0, 1))
    alpha = np.minimum(alpha, cv2.GaussianBlur(m, (0, 0), 1.2))
    if i < FADE_END:
        alpha *= (i - START + 1) / (FADE_END - START + 1)
    if i >= TINY_FROM:
        a_ = np.clip(warp(SPR_A, r), 0, 1)[..., None]
        ours = ours * (1 - a_) + warp(SPR, r) * a_
    out = F * (1 - alpha[..., None]) + np.clip(ours, 0, 255) * alpha[..., None]
    if letters is not None and letters.max() > 0:
        ink = np.array([52.0, 58.0, 168.0], np.float32)
        sel_l = letters > 0.8
        if sel_l.sum() > 20: ink = np.clip(np.median(F[sel_l], 0) * np.array([0.9, 0.9, 1.25], np.float32), 0, 255)
        out = out * (1 - letters[..., None]) + ink * letters[..., None]
    cv2.imwrite(f'out/f_{i:04d}.png', np.clip(out, 0, 255).astype(np.uint8))
    log[i] = [float(wmap.mean()), float(occ[sel].mean()) if sel.any() else 0.0]
    if i % 25 == 0: print('p2', i, 'w=%.2f occ=%.3f' % (wmap[m > 0].mean(), log[i][1]), '%.0fs' % (time.time() - t0), flush=True)
json.dump(log, open('comp_log.json', 'w'))
print('done %.0fs' % (time.time() - t0), flush=True)
