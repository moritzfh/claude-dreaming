"""Offline prototype of the painterly screen filter (mirrors shaders/painterly.gdshader)."""
import cv2, numpy as np, sys

def kuwahara(img, k):
    # 4-quadrant Kuwahara with k x k quadrants (box filter based)
    m = cv2.blur(img, (k, k)); s = cv2.blur(img * img, (k, k))
    v = (s - m * m).sum(-1)
    h = k // 2
    shifts = [(-h, -h), (h, -h), (-h, h), (h, h)]
    best = np.full(v.shape, 1e9, np.float32); out = np.zeros_like(img)
    for dx, dy in shifts:
        M = np.float32([[1, 0, dx], [0, 1, dy]])
        mv = cv2.warpAffine(v, M, (v.shape[1], v.shape[0]), borderMode=cv2.BORDER_REPLICATE)
        mm = cv2.warpAffine(m, M, (v.shape[1], v.shape[0]), borderMode=cv2.BORDER_REPLICATE)
        sel = mv < best
        best[sel] = mv[sel]; out[sel] = mm[sel]
    return out

def lum(c): return c @ np.array([0.114, 0.587, 0.299], np.float32)

def paint(img, k=8, sat=0.95, warm=(0.84, 1.0, 1.08), lines=0.3, stroke=0.10, seed=3, SL=9.0, con=1.15, lthr=0.22):
    img = img.astype(np.float32) / 255.0
    H, W = img.shape[:2]
    col = kuwahara(img, k)
    # stroke direction from the structure of a blurred luminance
    L = cv2.GaussianBlur(lum(img), (0, 0), 3.0)
    gx = cv2.Sobel(L, cv2.CV_32F, 1, 0, ksize=3); gy = cv2.Sobel(L, cv2.CV_32F, 0, 1, ksize=3)
    # smooth structure tensor
    Jxx = cv2.GaussianBlur(gx * gx, (0, 0), 6); Jyy = cv2.GaussianBlur(gy * gy, (0, 0), 6); Jxy = cv2.GaussianBlur(gx * gy, (0, 0), 6)
    ang = 0.5 * np.arctan2(2 * Jxy, Jxx - Jyy) + np.pi / 2  # along edges
    coh = np.sqrt((Jxx - Jyy) ** 2 + 4 * Jxy ** 2) / (Jxx + Jyy + 1e-4)
    strength = np.clip((Jxx + Jyy) / 0.004, 0, 1) * coh
    # flat areas: gently tilted horizontal dabs
    rng0 = np.random.default_rng(9)
    base = cv2.resize(cv2.GaussianBlur(rng0.random((24, 40)).astype(np.float32), (0, 0), 1.5), (W, H)) - 0.5
    ang0 = base * 1.2
    vx = strength * np.cos(2 * ang) + (1 - strength) * np.cos(2 * ang0)
    vy = strength * np.sin(2 * ang) + (1 - strength) * np.sin(2 * ang0)
    ang = 0.5 * np.arctan2(vy, vx)
    # anisotropic noise along stroke direction: sample a noise texture in a rotated frame
    rng = np.random.default_rng(seed)
    nz = cv2.GaussianBlur(rng.random((H, W)).astype(np.float32), (0, 0), 0.9)
    ca, sa = np.cos(ang), np.sin(ang)
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    acc = np.zeros((H, W), np.float32)
    for kk in range(-6, 7):
        d = kk * SL / 6.0
        acc += cv2.remap(nz, xx + ca * d, yy + sa * d, cv2.INTER_LINEAR, borderMode=cv2.BORDER_REFLECT)
    n = acc / 13.0
    n = np.clip((n - n.mean()) / (n.std() * 3) + 0.5, 0, 1)
    col = col * (1.0 - stroke + 2 * stroke * n[..., None])
    # line work: dark thin lines on strong edges of the fine image
    Lf = lum(cv2.GaussianBlur(img, (0, 0), 1.6))
    e = np.hypot(cv2.Sobel(Lf, cv2.CV_32F, 1, 0, ksize=3), cv2.Sobel(Lf, cv2.CV_32F, 0, 1, ksize=3))
    ln = np.clip((e - lthr) / 0.5, 0, 1)
    col = col * (1.0 - lines * ln[..., None])
    # colour: slightly muted, warm varnish
    l = lum(col)[..., None]
    col = l + (col - l) * sat
    col = col * np.array(warm, np.float32)
    col = (col - 0.5) * con + 0.5
    col = np.clip(col, 0, 1) ** 1.08
    return np.clip(col * 255, 0, 255).astype(np.uint8)

if __name__ == '__main__':
    src = cv2.imread(sys.argv[1])
    out = paint(src)
    cv2.imwrite(sys.argv[2], out)
