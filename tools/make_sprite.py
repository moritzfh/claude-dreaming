"""Pixel-art robot sprite sheet for the 2D attic hub (matches the film's pixel robot)."""
from PIL import Image

W, H = 28, 36
OUT = (58, 38, 40, 255)
CREAM = (244, 238, 226, 255); CREAM_S = (214, 204, 192, 255); CREAM_H = (255, 252, 244, 255)
SCREEN = (22, 18, 26, 255); SCREEN_H = (48, 44, 60, 255)
EYE = (255, 168, 60, 255); EYE_C = (255, 232, 160, 255)
CORAL = (222, 104, 80, 255); CORAL_S = (176, 74, 62, 255); CORAL_H = (244, 150, 118, 255)
GOLD = (236, 184, 76, 255); STAR = (255, 196, 150, 255)
WHITE = (250, 248, 244, 255); CUFF = (70, 50, 60, 255)

def px(img, x, y, c):
    if 0 <= x < W and 0 <= y < H: img.putpixel((x, y), c)

def rect(img, x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1): px(img, x, y, c)

def rrect(img, x0, y0, x1, y1, fill, outline, r=2):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            dx = max(x0 + r - x, 0, x - (x1 - r)); dy = max(y0 + r - y, 0, y - (y1 - r))
            if dx * dx + dy * dy <= r * r + 1:
                edge = False
                for ox, oy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    xx, yy = x + ox, y + oy
                    ddx = max(x0 + r - xx, 0, xx - (x1 - r)); ddy = max(y0 + r - yy, 0, yy - (y1 - r))
                    if not (x0 <= xx <= x1 and y0 <= yy <= y1) or ddx * ddx + ddy * ddy > r * r + 1: edge = True
                px(img, x, y, outline if edge else fill)

def ellipse(img, cx, cy, rx, ry, fill, outline=None):
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            v = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
            if v <= 1.0:
                px(img, x, y, fill)
                if outline and v > 0.62: px(img, x, y, outline)

def robot(frame="idle", phase=0, eyes="normal"):
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    bob = 0
    if frame == "walk": bob = 1 if phase in (1, 3) else 0
    if frame == "idle" and phase == 1: bob = 1
    by = 21 + bob    # body top
    # legs / feet
    lf = [(0, 0), (1, -1), (0, 0), (-1, 0)][phase % 4] if frame == "walk" else (0, 0)
    rf = [(0, 0), (-1, 0), (0, 0), (1, -1)][phase % 4] if frame == "walk" else (0, 0)
    for (fx, fy), x0 in ((lf, 9), (rf, 15)):
        rect(img, x0 + fx, 30 + fy, x0 + 3 + fx, 33 + fy, CORAL)
        rect(img, x0 - 1 + fx, 34 + fy, x0 + 4 + fx, 34 + fy, OUT)
        rect(img, x0 - 1 + fx, 30 + fy, x0 - 1 + fx, 33 + fy, OUT); rect(img, x0 + 4 + fx, 30 + fy, x0 + 4 + fx, 33 + fy, OUT)
        rect(img, x0 + 1 + fx, 31 + fy, x0 + 1 + fx, 32 + fy, CORAL_H)
    # body
    ellipse(img, 13.5, by + 4.8, 7.6, 5.4, CORAL, OUT)
    ellipse(img, 13.5, by + 5.0, 2.6, 2.4, WHITE)
    px(img, 13, by + 5, CORAL); px(img, 14, by + 5, CORAL)
    for x in range(9, 13): px(img, x, by + 1, CORAL_H)
    # arms (swing)
    sw = [0, 1, 0, -1][phase % 4] if frame == "walk" else 0
    for side, ax in ((-1, 5), (1, 22)):
        dy = sw * side
        x0 = ax - 1 if side < 0 else ax
        rect(img, x0 - 1, by + 2 + dy, x0 + 2, by + 6 + dy, OUT)
        rect(img, x0, by + 3 + dy, x0 + 1, by + 5 + dy, CORAL)
        rect(img, x0, by + 6 + dy, x0 + 1, by + 6 + dy, CUFF)
        rect(img, x0 - 1, by + 7 + dy, x0 + 2, by + 9 + dy, OUT)
        rect(img, x0, by + 7 + dy, x0 + 1, by + 8 + dy, WHITE)
    # head
    hy = 4 + bob
    rrect(img, 3, hy, 24, hy + 16, CREAM, OUT, 3)
    for x in range(5, 23): px(img, x, hy + 15, CREAM_S)
    for y in range(hy + 3, hy + 14): px(img, 23, y, CREAM_S)
    for x in range(6, 12): px(img, x, hy + 1, CREAM_H)
    # side ear (coral disc on the right side of the head)
    ellipse(img, 24.0, hy + 8.5, 1.6, 3.0, CORAL, OUT)
    # screen
    rrect(img, 6, hy + 3, 21, hy + 13, SCREEN, SCREEN, 2)
    px(img, 7, hy + 4, SCREEN_H); px(img, 8, hy + 4, SCREEN_H)
    # eyes
    if eyes == "blink":
        rect(img, 9, hy + 8, 11, hy + 8, EYE); rect(img, 16, hy + 8, 18, hy + 8, EYE)
    elif eyes == "happy":
        for ex in (9, 16):
            px(img, ex, hy + 9, EYE); px(img, ex + 1, hy + 8, EYE_C); px(img, ex + 2, hy + 9, EYE)
            px(img, ex, hy + 10, EYE); px(img, ex + 2, hy + 10, EYE)
    else:
        for ex in (9, 16):
            rect(img, ex, hy + 6, ex + 2, hy + 10, EYE)
            rect(img, ex + 1, hy + 7, ex + 1, hy + 9, EYE_C)
    # antenna + star
    rect(img, 13, hy - 3, 13, hy - 1, GOLD)
    px(img, 12, hy - 1, GOLD); px(img, 14, hy - 1, GOLD)
    for (x, y) in ((13, hy - 6), (12, hy - 5), (13, hy - 5), (14, hy - 5), (11, hy - 4), (13, hy - 4), (15, hy - 4)):
        px(img, x, y, STAR)
    return img

frames = []
for i in range(2): frames.append(robot("idle", i, "normal"))
frames.append(robot("idle", 0, "blink"))
frames.append(robot("idle", 0, "happy"))
for i in range(4): frames.append(robot("walk", i, "normal"))
sheet = Image.new("RGBA", (W * len(frames), H), (0, 0, 0, 0))
for i, f in enumerate(frames): sheet.paste(f, (i * W, 0))
sheet.save("/home/claude/dreamgame/assets/hub/robot_sheet.png")
sheet.resize((sheet.width * 8, sheet.height * 8), Image.NEAREST).save("/tmp/robot_sheet_preview.png")
print(len(frames), "frames")
