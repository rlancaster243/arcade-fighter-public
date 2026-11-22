#!/usr/bin/env python3
"""PS1-era stage backgrounds (stdlib only, deterministic).

8-bit indexed PNGs (<=256-colour CLUT, like PS1 8bpp backgrounds) with Bayer-dithered
gradients. Layers are 768x216: the arena scrolls up to 384px (FightCamera.arenaWidth).
Floor line sits 32px above the bottom (WorldToScene.floorY), i.e. y = 184 in image space.

Usage: python3 -I scripts/art/gen_stages.py [repo_root]
"""
import math
import os
import random
import struct
import sys
import zlib

W, H = 768, 216
FLOOR = H - 32
BAYER4 = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


class Img:
    def __init__(self, transparent=False):
        self.px = [[None if transparent else (0, 0, 0)] * W for _ in range(H)]

    def set(self, x, y, c):
        if 0 <= x < W and 0 <= y < H:
            self.px[y][x] = c

    def get(self, x, y):
        return self.px[y][x]


def dither_pick(ramp, t, x, y):
    """t in [0,1] across `ramp` colours, ordered-dithered between neighbours."""
    t = max(0.0, min(1.0, t)) * (len(ramp) - 1)
    i = int(t)
    f = t - i
    if i >= len(ramp) - 1:
        return ramp[-1]
    return ramp[i + 1] if f > (BAYER4[y % 4][x % 4] + 0.5) / 16 else ramp[i]


def vgrad(img, y0, y1, ramp, x0=0, x1=W):
    for y in range(y0, y1):
        t = (y - y0) / max(1, y1 - y0 - 1)
        for x in range(x0, x1):
            img.set(x, y, dither_pick(ramp, t, x, y))


def poly(img, pts, colour_fn):
    ys = [p[1] for p in pts]
    for y in range(max(0, int(min(ys))), min(H, int(max(ys)) + 1)):
        xs = []
        n = len(pts)
        for i in range(n):
            (x1, y1), (x2, y2) = pts[i], pts[(i + 1) % n]
            if (y1 <= y < y2) or (y2 <= y < y1):
                xs.append(x1 + (y - y1) * (x2 - x1) / (y2 - y1))
        xs.sort()
        for a, b in zip(xs[0::2], xs[1::2]):
            for x in range(max(0, int(a)), min(W, int(b) + 1)):
                img.set(x, y, colour_fn(x, y))


def rect(img, x0, y0, x1, y1, colour_fn):
    for y in range(max(0, y0), min(H, y1)):
        for x in range(max(0, x0), min(W, x1)):
            img.set(x, y, colour_fn(x, y))


def circle(img, cx, cy, r, colour_fn):
    for y in range(int(cy - r), int(cy + r) + 1):
        for x in range(int(cx - r), int(cx + r) + 1):
            if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                img.set(x, y, colour_fn(x, y))


def write_indexed(path, img):
    colours = {}
    order = []
    if any(c is None for row in img.px for c in row):
        order.append(None)
        colours[None] = 0
    for row in img.px:
        for c in row:
            if c not in colours:
                colours[c] = len(order)
                order.append(c)
    assert len(order) <= 256, (path, len(order))
    rows = [bytes(colours[c] for c in row) for row in img.px]

    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    plte = b"".join(bytes(c if c is not None else (0, 0, 0)) for c in order)
    out = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 3, 0, 0, 0))
           + chunk(b"PLTE", plte))
    if order and order[0] is None:
        out += chunk(b"tRNS", b"\x00")
    out += chunk(b"IDAT", zlib.compress(b"".join(b"\x00" + r for r in rows), 9)) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(out)
    return len(order)


# ---------------------------------------------------------------- stage 1: Glacier Forge Quarry


def stage1():
    rnd = random.Random(1)
    img = Img()
    sky = [(22, 18, 44), (40, 34, 78), (70, 60, 116), (126, 92, 140), (214, 130, 120), (250, 186, 140)]
    vgrad(img, 0, 120, sky)
    # glacier wall: jagged ridge with icy shading
    ice = [(70, 96, 140), (110, 146, 190), (168, 204, 232), (226, 242, 252)]
    ridge = []
    y = 60
    for x in range(0, W + 24, 24):
        y = max(30, min(90, y + rnd.randint(-18, 18)))
        ridge.append((x, y))
    pts = ridge + [(W, 140), (0, 140)]

    def ice_fn(x, yy):
        # light from the left: faces sloping up-right are lit
        return dither_pick(ice, 1 - (yy - 30) / 110 + 0.25 * math.sin(x / 37.0), x, yy)

    poly(img, pts, ice_fn)
    # crevasse streaks
    for x0 in range(10, W, 53):
        for yy in range(70, 140):
            xx = x0 + int((yy - 70) * 0.35)
            if (xx + yy) % 3:
                img.set(xx, yy, ice[0])
    # forge: dark building with glowing mouth and chimney smoke, mid-ground
    stone = [(30, 26, 34), (48, 42, 52), (70, 62, 72)]
    glow = [(120, 30, 10), (210, 80, 20), (255, 170, 60), (255, 236, 160)]
    for fx in (210, 600):
        rect(img, fx, 96, fx + 110, 150, lambda x, yy: dither_pick(stone, (x % 37) / 37, x, yy))
        rect(img, fx + 70, 50, fx + 90, 96, lambda x, yy: dither_pick(stone, 0.3, x, yy))
        for yy in range(10, 52):
            r = 6 + (52 - yy) * 0.3
            cx = fx + 80 + math.sin(yy / 6.0) * 6
            for x in range(int(cx - r), int(cx + r)):
                if (x + yy) % 2 == 0:
                    img.set(x, yy, (96, 86, 110) if yy > 30 else (120, 110, 132))
        circle(img, fx + 40, 140, 22,
               lambda x, yy, c=fx + 40: dither_pick(glow, 1 - math.hypot(x - c, yy - 140) / 22, x, yy))
        rect(img, fx + 24, 122, fx + 56, 150, lambda x, yy: dither_pick(glow, 1 - (yy - 122) / 40, x, yy))
    # quarry wall band behind the floor
    rock = [(42, 36, 44), (66, 58, 66), (94, 84, 90), (122, 110, 112)]
    vgrad(img, 140, FLOOR, rock[::-1])
    for x0 in range(0, W, 32):  # cut-stone blocks
        for yy in range(140, FLOOR):
            if yy % 14 == 0 or (x0 + (16 if (yy // 14) % 2 else 0)) % 32 == x0 % 32 and (yy % 14) == 1:
                pass
        rect(img, x0, 140, x0 + 1, FLOOR, lambda x, yy: rock[0])
    for yy in range(140, FLOOR, 14):
        rect(img, 0, yy, W, yy + 1, lambda x, y2: rock[0])
    # floor: packed snow over stone, perspective bands
    floor = [(150, 168, 190), (190, 206, 222), (228, 236, 246)]
    vgrad(img, FLOOR, H, floor[::-1])
    for yy in range(FLOOR + 4, H, 6):
        for x in range(0, W):
            if (x // 3 + yy) % 7 == 0:
                img.set(x, yy, floor[0])
    rect(img, 0, FLOOR, W, FLOOR + 1, lambda x, yy: (90, 104, 128))
    return img


# ---------------------------------------------------------------- stage 2: Bell Tower Cloister


def stage2_sky():
    rnd = random.Random(2)
    img = Img()
    vgrad(img, 0, H, [(8, 10, 28), (16, 22, 52), (34, 40, 84), (70, 64, 110), (120, 90, 120)])
    for _ in range(140):
        x, y = rnd.randrange(W), rnd.randrange(120)
        img.set(x, y, (220, 220, 255) if rnd.random() < 0.3 else (150, 150, 200))
    moon = [(180, 176, 160), (230, 226, 206), (255, 252, 236)]
    circle(img, 560, 46, 20, lambda x, y: dither_pick(moon, 1 - math.hypot(x - 553, y - 40) / 26, x, y))
    return img


def stage2_bells():
    img = Img(transparent=True)
    wall = [(26, 24, 40), (40, 38, 60), (60, 56, 84)]
    bronze = [(90, 60, 24), (160, 112, 40), (230, 180, 80)]
    for tx, tw, th in ((40, 70, 150), (250, 90, 176), (480, 70, 140), (650, 80, 160)):
        top = H - th
        rect(img, tx, top, tx + tw, H, lambda x, y: dither_pick(wall, (x - tx) / tw, x, y))
        poly(img, [(tx - 6, top), (tx + tw // 2, top - 34), (tx + tw + 6, top)],
             lambda x, y: dither_pick(wall, 0.2 + (x - tx) / (tw * 2), x, y))
        ax, aw, ah = tx + tw // 2 - 14, 28, 36  # belfry arch
        rect(img, ax, top + 14, ax + aw, top + 14 + ah, lambda x, y: (10, 10, 22))
        circle(img, ax + aw // 2, top + 14, aw // 2, lambda x, y: (10, 10, 22))
        circle(img, ax + aw // 2, top + 32, 10,
               lambda x, y, c=ax + aw // 2: dither_pick(bronze, 1 - math.hypot(x - c + 3, y - (top + 28)) / 12, x, y))
        rect(img, ax + aw // 2 - 10, top + 32, ax + aw // 2 + 11, top + 40, lambda x, y: bronze[1])
    return img


def stage2_floor():
    img = Img(transparent=True)
    stone = [(44, 40, 52), (70, 64, 78), (102, 94, 104), (136, 126, 130)]
    # cloister arcade: columns and arches in the near ground
    for cx in range(0, W + 1, 96):
        rect(img, cx - 7, 70, cx + 7, FLOOR, lambda x, y, c=cx: dither_pick(stone, 0.9 - abs(x - c) / 9, x, y))
        rect(img, cx - 10, 66, cx + 10, 72, lambda x, y: stone[2])
    for cx in range(0, W, 96):
        for x in range(cx, cx + 97):
            t = (x - cx) / 96
            yy = int(70 - math.sin(t * math.pi) * 26)
            for y in range(yy - 6, yy):
                img.set(x, y, dither_pick(stone, 0.7, x, y))
    rect(img, 0, 34, W, 44, lambda x, y: dither_pick(stone, 0.5, x, y))
    # flagstone floor
    vgrad(img, FLOOR, H, stone[::-1])
    for y in range(FLOOR + 6, H, 8):
        rect(img, 0, y, W, y + 1, lambda x, yy: stone[0])
    for y0 in range(FLOOR, H, 8):
        off = 12 if (y0 // 8) % 2 else 0
        for x in range(off, W, 24):
            rect(img, x, y0, x + 1, y0 + 8, lambda xx, yy: stone[0])
    rect(img, 0, FLOOR, W, FLOOR + 1, lambda x, y: (150, 140, 120))
    return img


if __name__ == "__main__":
    root = sys.argv[1] if len(sys.argv) > 1 else os.path.abspath(
        os.path.join(os.path.dirname(__file__), "..", ".."))
    st = os.path.join(root, "Content", "Stages")
    out = [
        (os.path.join(st, "stage1", "stage1.contentbundle", "background.png"), stage1()),
        (os.path.join(st, "stage2", "stage2.contentbundle", "cloister_sky.png"), stage2_sky()),
        (os.path.join(st, "stage2", "stage2.contentbundle", "cloister_bells.png"), stage2_bells()),
        (os.path.join(st, "stage2", "stage2.contentbundle", "cloister_floor.png"), stage2_floor()),
    ]
    for path, img in out:
        n = write_indexed(path, img)
        print(f"{os.path.relpath(path, root)}: {W}x{H}, {n} colours")
