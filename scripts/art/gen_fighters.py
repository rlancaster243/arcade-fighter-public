#!/usr/bin/env python3
"""PS1-era 2D fighter sprite generator (stdlib only, deterministic).

Builds every shipped fighter from a jointed 2D skeleton, poses it per animation frame,
and rasterises it the way late-90s PlayStation 2D fighters looked on a 4-bit CLUT:
16-colour indexed palette, 3-tone shading with ordered (Bayer) dithering, darker far-side
limbs for depth, and a 1px dark outline. Writes each bundle's `<id>.png` + `sheet.json`
in the format of docs/fighter-schema.md (112x112 cells, anchor bottom-centre).

Usage: python3 -I scripts/art/gen_fighters.py [repo_root]
Frame names are the contract with AppLogic/Render/SpriteSelection.swift.
"""
import json
import math
import os
import struct
import sys
import zlib

CELL = 112
COLS = 8
ANCHOR_X, ANCHOR_Y = 56, 110  # feet 2px above the cell bottom so the outline isn't clipped
BAYER4 = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
LIGHT = (-0.55, -0.62, 0.56)  # from upper-left-front, y-down screen space

# ---------------------------------------------------------------- palettes & designs
# Palette slots: 0 transparent, 1 outline, 2-4 skin, 5-7 primary, 8-10 secondary,
# 11-12 accent, 13-14 hair, 15 glow/highlight.


def ramp(dark, mid, light):
    return [dark, mid, light]


DESIGNS = {
    "kestrel": dict(
        height=94, build=0.92,
        palette=[(0, 0, 0), (18, 16, 30)]
        + ramp((150, 96, 72), (214, 150, 112), (246, 196, 158))    # skin
        + ramp((40, 92, 150), (78, 150, 210), (170, 222, 248))      # ice jacket
        + ramp((34, 40, 58), (58, 68, 92), (92, 104, 132))          # slate pants
        + [(28, 170, 190), (130, 240, 240)]                         # frost accent
        + [(150, 156, 176), (232, 236, 248)]                        # silver hair
        + [(224, 252, 255)],
        torso="primary", sleeve="primary", forearm="skin", glove="accent",
        pants="secondary", boots="accent", belt="accent", hair="spiky",
        scarf=True,
    ),
    "bruno": dict(
        height=98, build=1.32,
        palette=[(0, 0, 0), (22, 14, 10)]
        + ramp((104, 62, 40), (152, 98, 66), (200, 146, 104))     # skin
        + ramp((40, 24, 18), (70, 44, 30), (108, 72, 48))          # dark leather apron
        + ramp((38, 36, 40), (64, 60, 66), (98, 94, 100))          # charcoal pants
        + [(196, 82, 20), (255, 168, 60)]                          # forge orange
        + [(24, 18, 16), (60, 46, 40)]                             # beard
        + [(255, 226, 150)],
        torso="primary", sleeve="skin", forearm="skin", glove="accent",
        pants="secondary", boots="primary", belt="accent", hair="bald_beard",
    ),
    "ilse": dict(
        height=92, build=0.96,
        palette=[(0, 0, 0), (20, 12, 18)]
        + ramp((168, 120, 98), (226, 176, 148), (250, 216, 190))    # skin
        + ramp((92, 18, 34), (150, 34, 52), (204, 72, 84))          # crimson habit
        + ramp((176, 164, 140), (224, 214, 190), (250, 246, 230))   # cream
        + [(172, 132, 40), (250, 214, 100)]                         # gold
        + [(176, 164, 140), (250, 246, 230)]                        # veil (cream)
        + [(255, 250, 210)],
        torso="primary", sleeve="primary", forearm="primary", glove="skin",
        pants="primary", boots="secondary", belt="accent", hair="veil", skirt=True,
    ),
    "rook": dict(
        height=96, build=1.12,
        palette=[(0, 0, 0), (12, 14, 20)]
        + ramp((40, 46, 70), (62, 70, 104), (96, 106, 146))        # undersuit
        + ramp((86, 94, 106), (146, 154, 166), (210, 216, 224))    # steel plate
        + ramp((40, 46, 70), (62, 70, 104), (96, 106, 146))        # navy
        + [(176, 30, 36), (255, 90, 80)]                           # red visor
        + [(86, 94, 106), (210, 216, 224)]                         # helmet
        + [(255, 200, 190)],
        torso="primary", sleeve="primary", forearm="secondary", glove="primary",
        pants="secondary", boots="primary", belt="accent", hair="helmet",
    ),
    "greybox": dict(
        height=92, build=1.0,
        palette=[(0, 0, 0), (16, 16, 18)]
        + ramp((96, 96, 100), (150, 150, 156), (204, 204, 210))
        + ramp((70, 72, 78), (118, 120, 128), (176, 178, 186))
        + ramp((52, 54, 58), (90, 92, 98), (134, 136, 142))
        + [(200, 120, 40), (250, 200, 120)]
        + [(96, 96, 100), (204, 204, 210)]
        + [(255, 255, 255)],
        torso="primary", sleeve="primary", forearm="skin", glove="skin",
        pants="secondary", boots="secondary", belt="accent", hair="none",
    ),
}
MATERIAL_SLOTS = {"skin": [2, 3, 4], "primary": [5, 6, 7], "secondary": [8, 9, 10],
                  "accent": [11, 12, 12], "hair": [13, 14, 14], "glow": [15, 15, 15]}

# ---------------------------------------------------------------- poses
# Angles in degrees measured from straight down, positive rotates toward facing (+x).
# 90 = horizontal forward, 180 = straight up. Elbow/knee are relative bends.
BASE = dict(hx=0, hy=0, lean=6, head=0,
            fa=(28, 70), ba=(14, 80),        # (upper arm angle, elbow bend) front/back
            fl=(14, 18), bl=(-12, 10),       # (thigh angle, knee bend) front/back
            glow=False, fist=True)


def P(**kw):
    p = dict(BASE)
    p.update(kw)
    return p


def lerp_pose(a, b, t):
    out = {}
    for k, v in a.items():
        w = b[k]
        if isinstance(v, tuple):
            out[k] = tuple(x + (y - x) * t for x, y in zip(v, w))
        elif isinstance(v, bool):
            out[k] = v if t < 0.5 else w
        else:
            out[k] = v + (w - v) * t
    return out


IDLE = [P(hy=0), P(hy=1, fa=(30, 74)), P(hy=2, fa=(32, 78), ba=(16, 84)), P(hy=1, fa=(30, 74))]
WALK = []
for i in range(6):
    ph = i / 6 * 2 * math.pi
    WALK.append(P(hy=abs(math.sin(ph)) * -2 + 1, lean=8,
                  fl=(14 + 26 * math.sin(ph), 10 + 22 * max(0, -math.cos(ph))),
                  bl=(-12 - 26 * math.sin(ph), 10 + 22 * max(0, math.cos(ph))),
                  fa=(28 - 10 * math.sin(ph), 70), ba=(14 + 14 * math.sin(ph), 80)))
CROUCH = P(hy=24, lean=18, fl=(70, 120), bl=(30, 110), fa=(40, 80), ba=(30, 90))
JUMP = [P(hy=10, lean=14, fl=(40, 60), bl=(10, 50)),
        P(hy=-4, lean=4, fl=(30, 40), bl=(-30, 30), fa=(120, 40), ba=(100, 50)),
        P(hy=-10, lean=10, fl=(80, 120), bl=(50, 110), fa=(50, 90), ba=(40, 90)),
        P(hy=-4, lean=2, fl=(20, 20), bl=(-10, 30), fa=(140, 30), ba=(120, 40))]
LAND = P(hy=12, lean=16, fl=(44, 70), bl=(10, 60))
BLOCK = P(hy=4, lean=-4, fa=(80, 120), ba=(70, 125), fl=(20, 22), bl=(-20, 16))
BLOCK_C = P(hy=24, lean=10, fl=(70, 120), bl=(30, 110), fa=(80, 125), ba=(70, 125))
HIT = [P(hy=2, lean=-22, head=-14, fa=(-10, 30), ba=(-20, 40), fl=(20, 20), bl=(-26, 10)),
       P(hy=4, lean=-30, head=-20, fa=(-30, 20), ba=(-40, 30), fl=(30, 30), bl=(-20, 20))]
DOWN = [P(hy=-6, lean=-60, head=-20, fa=(-60, 20), ba=(-80, 30), fl=(60, 20), bl=(40, 30)),
        "lying"]
GETUP = P(hy=26, lean=30, fl=(80, 130), bl=(20, 120), fa=(10, 20), ba=(0, 30))
WIN = [P(lean=0, fa=(175, 10), ba=(20, 60), fl=(12, 6), bl=(-12, 6)),
       P(lean=0, hy=-2, fa=(170, 30), ba=(25, 70), fl=(12, 6), bl=(-12, 6))]
GRAB = P(lean=14, fa=(80, 40), ba=(70, 50), fl=(30, 20), bl=(-20, 10))
THROWN = P(hy=-14, lean=-70, head=-30, fa=(140, 20), ba=(160, 30), fl=(80, 40), bl=(60, 60))

# Move templates: (startup, active, recovery)
T_JAB = (P(fa=(60, 110), lean=8), P(fa=(90, 0), lean=12, hx=2), P(fa=(70, 60), lean=8))
T_CROSS = (P(ba=(40, 100), lean=-2, fa=(40, 90)),
           P(fa=(92, 0), ba=(10, 70), lean=20, hx=5, fl=(30, 20), bl=(-30, 4)),
           P(fa=(70, 50), lean=10, hx=3))
T_LK = (P(fl=(50, 90), lean=0), P(fl=(78, 6), bl=(-8, 4), lean=-6), P(fl=(40, 50)))
T_HK = (P(fl=(70, 120), lean=-6, hy=-2), P(fl=(118, 0), bl=(-6, 4), lean=-24, fa=(10, 60), ba=(-20, 50)),
        P(fl=(60, 70), lean=-8))
T_PUSH = (P(fa=(30, 130), ba=(20, 130), lean=-6, fl=(30, 20), bl=(-30, 10)),
          P(fa=(88, 4), ba=(84, 10), lean=14, hx=4, fl=(36, 24), bl=(-34, 6), glow=True, fist=False),
          P(fa=(70, 30), ba=(60, 40), lean=8))
T_UPPER = (P(hy=16, lean=20, fa=(40, 120), fl=(60, 100), bl=(20, 90)),
           P(hy=-18, lean=-4, fa=(172, 6), ba=(30, 60), fl=(50, 70), bl=(-10, 20), glow=True),
           P(hy=-6, lean=0, fa=(130, 40), fl=(30, 40), bl=(-20, 40)))
T_RUSHK = (P(hy=6, lean=20, fl=(60, 100), bl=(-10, 40)),
           P(hy=-12, lean=-16, fl=(96, 0), bl=(20, 110), fa=(20, 60), ba=(100, 40), glow=True),
           P(hy=4, lean=8, fl=(40, 50)))
T_RUSHP = (P(hy=6, lean=24, fa=(30, 120), fl=(50, 70), bl=(-30, 20)),
           P(hy=0, lean=30, hx=8, fa=(92, 0), ba=(0, 60), fl=(50, 30), bl=(-50, 10), glow=True),
           P(lean=14, fa=(70, 40)))
T_GUARD = (P(fa=(70, 120), ba=(60, 120), lean=-6), P(fa=(100, 100), ba=(90, 110), lean=-10, glow=True),
           P(fa=(60, 90), lean=0))
T_SWEEP = (P(hy=22, lean=24, fl=(60, 110), bl=(30, 100)),
           P(hy=26, lean=40, fl=(88, 0), bl=(20, 120), fa=(-10, 40), ba=(-20, 30), glow=True),
           P(hy=20, lean=20, fl=(60, 100), bl=(30, 100)))
T_GRAB = (P(fa=(60, 80), ba=(50, 80), lean=10), GRAB, P(fa=(150, 40), ba=(130, 50), lean=-10))
T_SUPER = (P(hy=14, lean=-10, fa=(20, 140), ba=(10, 140), fl=(40, 60), bl=(-40, 40), glow=True),
           P(hy=-2, lean=24, hx=10, fa=(90, 0), ba=(86, 4), fl=(50, 20), bl=(-50, 4), glow=True, fist=False),
           P(hy=6, lean=10, fa=(70, 40), ba=(60, 50)))


def move_template(move, has_projectile_moves):
    mid = move["id"]
    inp = move.get("input", {})
    button = inp.get("button", "")
    motion = inp.get("motion", "")
    if inp.get("stance") == "throw" or "+" in button:
        return T_GRAB
    if mid.startswith("super"):
        return T_SUPER
    if "projectile" in move:
        return T_PUSH
    if motion == "623":
        return T_UPPER
    if move.get("guard") == "throw" and move.get("unblockable"):
        return T_GRAB
    if motion == "214" and "P" in button:
        return T_GUARD
    if motion == "214":
        return T_SWEEP
    if motion == "236":
        return T_RUSHK if "K" in button else T_RUSHP
    return {"LP": T_JAB, "HP": T_CROSS, "LK": T_LK, "HK": T_HK}.get(button, T_JAB)


# ---------------------------------------------------------------- skeleton & raster


def vec(angle_deg, length):
    a = math.radians(angle_deg)
    return (math.sin(a) * length, math.cos(a) * length)


def add(a, b):
    return (a[0] + b[0], a[1] + b[1])


class Canvas:
    def __init__(self):
        self.mat = [[None] * CELL for _ in range(CELL)]   # (material, shade, layer)

    def put(self, x, y, material, shade, layer):
        if 0 <= x < CELL and 0 <= y < CELL:
            cur = self.mat[y][x]
            if cur is None or layer >= cur[2]:
                self.mat[y][x] = (material, shade, layer)


def shade_value(nx, ny, depth_bias):
    nz = math.sqrt(max(0.0, 1 - nx * nx - ny * ny))
    lit = nx * LIGHT[0] + ny * LIGHT[1] + nz * LIGHT[2]
    return max(0.0, min(1.0, 0.5 + 0.75 * lit - depth_bias))


def quantise(v, x, y):
    t = (BAYER4[y % 4][x % 4] + 0.5) / 16.0
    s = v * 2 + (t - 0.5) * 0.9  # dither band between tones
    return 0 if s < 0.5 else (1 if s < 1.5 else 2)


def capsule(cv, a, b, ra, rb, material, layer, depth_bias=0.0):
    ax, ay = a
    bx, by = b
    minx = int(min(ax, bx) - max(ra, rb) - 1)
    maxx = int(max(ax, bx) + max(ra, rb) + 2)
    miny = int(min(ay, by) - max(ra, rb) - 1)
    maxy = int(max(ay, by) + max(ra, rb) + 2)
    dx, dy = bx - ax, by - ay
    ll = dx * dx + dy * dy or 1e-6
    for y in range(miny, maxy):
        for x in range(minx, maxx):
            px, py = x + 0.5, y + 0.5
            t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / ll))
            cx, cy = ax + dx * t, ay + dy * t
            r = ra + (rb - ra) * t
            vx, vy = px - cx, py - cy
            d = math.hypot(vx, vy)
            if d <= r:
                v = shade_value(vx / r, vy / r, depth_bias)
                cv.put(x, y, material, quantise(v, x, y), layer)


def disc(cv, c, r, material, layer, depth_bias=0.0):
    capsule(cv, c, c, r, r, material, layer, depth_bias)


def quad(cv, pts, material, layer, centre, half_width):
    """Filled convex polygon, shaded as a cylinder around `centre` (torso, apron)."""
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    for y in range(int(min(ys)) - 1, int(max(ys)) + 2):
        for x in range(int(min(xs)) - 1, int(max(xs)) + 2):
            px, py = x + 0.5, y + 0.5
            inside = True
            n = len(pts)
            for i in range(n):
                x1, y1 = pts[i]
                x2, y2 = pts[(i + 1) % n]
                if (x2 - x1) * (py - y1) - (y2 - y1) * (px - x1) < 0:
                    inside = False
                    break
            if inside:
                nx = max(-0.95, min(0.95, (px - centre[0]) / max(half_width, 1)))
                v = shade_value(nx, -0.2, 0.0)
                cv.put(x, y, material, quantise(v, x, y), layer)


def build_figure(design, pose):
    """Returns a Canvas with the posed fighter, feet at (ANCHOR_X, ANCHOR_Y)."""
    cv = Canvas()
    H = design["height"]
    b = design["build"]
    s = H / 94.0
    thigh, shin = 21 * s, 20 * s
    torso_len, neck = 31 * s, 2.5 * s
    upper, fore = 15 * s, 14 * s
    head_r = 8.0 * s
    limb_r = 5.4 * b * s
    stand_hip = thigh + shin - 2
    hip = (ANCHOR_X + pose["hx"], ANCHOR_Y - stand_hip + pose["hy"])

    if pose == "lying":
        return cv
    lean = pose["lean"]
    chest_dir = vec(180 - lean, 1)
    neck_pt = add(hip, (chest_dir[0] * torso_len, chest_dir[1] * torso_len))
    shoulder = add(hip, (chest_dir[0] * torso_len * 0.86, chest_dir[1] * torso_len * 0.86))
    head_c = add(neck_pt, vec(180 - lean - pose["head"], neck + head_r))
    sh_f = add(shoulder, (5.0 * b * s, 0))
    sh_b = add(shoulder, (-6.0 * b * s, 0))
    hip_f = add(hip, (4.5 * b * s, 0))
    hip_b = add(hip, (-4.5 * b * s, 0))

    def arm(sh, spec, layer, bias):
        ua, el = spec
        elbow = add(sh, vec(ua, upper))
        hand = add(elbow, vec(ua + el, fore))
        disc(cv, sh, limb_r * 1.35, design["sleeve"], layer, bias)  # deltoid
        capsule(cv, sh, elbow, limb_r * 1.1, limb_r * 0.9, design["sleeve"], layer, bias)
        capsule(cv, elbow, hand, limb_r * 0.9, limb_r * 0.8, design["forearm"], layer, bias)
        disc(cv, hand, limb_r * (1.05 if pose["fist"] else 0.85), design["glove"], layer + 0.5, bias)
        return hand

    def leg(hp, spec, layer, bias):
        ta, kb = spec
        knee = add(hp, vec(ta, thigh))
        ankle = add(knee, vec(ta - kb, shin))
        capsule(cv, hp, knee, limb_r * 1.55, limb_r * 1.2, design["pants"], layer, bias)
        capsule(cv, knee, ankle, limb_r * 1.2, limb_r * 0.95, design["pants"], layer, bias)
        toe = add(ankle, vec(ta - kb - 80, 6.5 * s))
        capsule(cv, ankle, toe, limb_r * 0.95, limb_r * 0.8, design["boots"], layer + 0.5, bias)

    # back limbs (far side, darker), torso, head, front limbs
    arm(sh_b, pose["ba"], 1, 0.22)
    leg(hip_b, pose["bl"], 1, 0.22)
    chest_w, waist_w = 13.5 * b * s, 9.5 * b * s
    px, py = -chest_dir[1], chest_dir[0]  # perpendicular
    torso_pts = [
        (hip[0] - px * waist_w, hip[1] - py * waist_w),
        (hip[0] + px * waist_w, hip[1] + py * waist_w),
        (neck_pt[0] + px * chest_w, neck_pt[1] + py * chest_w),
        (neck_pt[0] - px * chest_w, neck_pt[1] - py * chest_w),
    ]
    # winding must be consistent for the inside test
    torso_pts = torso_pts if _area(torso_pts) > 0 else list(reversed(torso_pts))
    quad(cv, torso_pts, design["torso"], 3, ((hip[0] + neck_pt[0]) / 2, 0), chest_w)
    capsule(cv, hip_b, hip_f, waist_w * 0.55, waist_w * 0.55, design["pants"], 3)
    # belt / sash
    capsule(cv, add(hip, (-waist_w, -2)), add(hip, (waist_w, -2)), 1.6 * s, 1.6 * s, design["belt"], 3.5)
    if design.get("skirt"):
        hem_f = add(hip_f, vec(pose["fl"][0] * 0.6, thigh * 1.05))
        hem_b = add(hip_b, vec(pose["bl"][0] * 0.6, thigh * 1.05))
        sk = [(hip[0] - waist_w, hip[1]), (hip[0] + waist_w, hip[1]),
              (hem_f[0] + 4 * s, hem_f[1]), (hem_b[0] - 4 * s, hem_b[1])]
        sk = sk if _area(sk) > 0 else list(reversed(sk))
        quad(cv, sk, design["torso"], 3.2, (hip[0], 0), waist_w * 1.4)
    if design.get("scarf"):
        tail = add(neck_pt, vec(-110 - lean, 14 * s))
        capsule(cv, add(neck_pt, (0, 1)), tail, 2.6 * s, 1.4 * s, "accent", 3.6)
    capsule(cv, add(neck_pt, (0, 2)), head_c, 3 * s, 3 * s, "skin", 3.7)
    disc(cv, head_c, head_r, "skin", 4)
    hair(cv, design, head_c, head_r, lean + pose["head"], s)
    # eye: 1 dark pixel toward the facing side
    ex, ey = int(head_c[0] + head_r * 0.45), int(head_c[1] - head_r * 0.05)
    cv.put(ex, ey, "outline", 0, 6)
    leg(hip_f, pose["fl"], 5, 0.0)
    hand = arm(sh_f, pose["fa"], 6, 0.0)
    if pose["glow"]:
        for r, mat in ((6.5 * s, "accent"), (4 * s, "glow")):
            disc(cv, hand, r, mat, 7)
    return cv


def hair(cv, design, c, r, tilt, s):
    style = design["hair"]
    up = vec(180 - tilt, 1)
    back = vec(-90 - tilt, 1)
    if style == "spiky":
        for i, ang in enumerate((-60, -30, 0, 30, 60)):
            base = add(c, vec(180 - tilt + ang * 0.8, r * 0.7))
            tip = add(c, vec(180 - tilt + ang - 25, r * (1.9 if i % 2 else 1.6)))
            capsule(cv, base, tip, 2.8 * s, 0.6 * s, "hair", 5)
        capsule(cv, add(c, (up[0] * r * 0.4, up[1] * r * 0.4)), add(c, (back[0] * r * 0.6, back[1] * r * 0.6)),
                r * 0.75, r * 0.6, "hair", 5)
    elif style == "bald_beard":
        chin = add(c, vec(30 - tilt, r * 0.85))
        disc(cv, chin, r * 0.32, "hair", 5)  # chin tuft; the face stays readable
    elif style == "veil":
        # hood over the crown and back of the head; the face (front) stays skin
        capsule(cv, add(c, (up[0] * r * 0.35 + back[0] * r * 0.25, up[1] * r * 0.35 + back[1] * r * 0.25)),
                add(c, (back[0] * r * 0.9, back[1] * r * 0.9)), r * 0.85, r * 0.85, "hair", 5)
        capsule(cv, add(c, (up[0] * r * 0.8, up[1] * r * 0.8)), add(c, (up[0] * r * 0.6 + r * 0.55, up[1] * r * 0.6)),
                r * 0.35, r * 0.25, "hair", 5)
        capsule(cv, add(c, (back[0] * r * 0.8, back[1] * r * 0.8)),
                add(c, (back[0] * r * 1.4, back[1] * r * 1.4 + r * 2.6)), r * 0.8, r * 1.0, "hair", 2.9)
        capsule(cv, add(c, (-r * 0.2, -r * 0.95)), add(c, (r * 0.5, -r * 0.95)), 1.3 * s, 1.3 * s, "accent", 5.5)
    elif style == "helmet":
        capsule(cv, add(c, (up[0] * r * 0.1, up[1] * r * 0.1)), add(c, (back[0] * r * 0.3, back[1] * r * 0.3)),
                r * 1.08, r * 1.0, "hair", 5)
        capsule(cv, add(c, (r * 0.05, -r * 0.05)), add(c, (r * 0.85, -r * 0.05)), 1.6 * s, 1.6 * s, "accent", 5.5)
        capsule(cv, add(c, (-r * 0.2, -r * 1.0)), add(c, (-r * 0.9, -r * 1.7)), 1.4 * s, 0.6 * s, "accent", 5.5)


def _area(pts):
    a = 0
    for i in range(len(pts)):
        x1, y1 = pts[i]
        x2, y2 = pts[(i + 1) % len(pts)]
        a += x1 * y2 - x2 * y1
    return a


def lying_figure(design, ko):
    """Knocked-down body: a standing figure rotated flat, feet toward the facing side."""
    flat = P(lean=0, fa=(-10, 20), ba=(10, 20), fl=(8, 6), bl=(-8, 8), head=0 if ko else -10)
    stand = build_figure(design, flat)
    cv = Canvas()
    for y in range(CELL):
        for x in range(CELL):
            v = stand.mat[y][x]
            if v is None:
                continue
            # lay the body flat: height above the feet becomes distance toward -x (head behind)
            h = ANCHOR_Y - y
            rx = ANCHOR_X + 48 - h
            ry = ANCHOR_Y - 1 - (x - (ANCHOR_X - 16)) * 0.75
            cv.put(int(rx), int(ry), v[0], v[1], v[2])
    return cv


def projectile_cell(design, frame):
    cv = Canvas()
    c = (ANCHOR_X, CELL / 2)
    wob = 1.5 if frame else 0
    for i in range(5):
        a = (i * 72 + frame * 36)
        tail = add(c, vec(-90 + (a % 360) * 0.18 - 32, 13 + wob))
        capsule(cv, c, tail, 5.5, 1.0, "accent", 1)
    disc(cv, c, 9.5 + wob, "accent", 2)
    disc(cv, (c[0] + 1, c[1] - 1), 6, "glow", 3)
    return cv


def to_indices(cv, palette_slots):
    out = [[0] * CELL for _ in range(CELL)]
    for y in range(CELL):
        for x in range(CELL):
            v = cv.mat[y][x]
            if v is None:
                continue
            mat, shade, _ = v
            out[y][x] = 1 if mat == "outline" else palette_slots[mat][shade]
    # 1px outline around the silhouette
    for y in range(CELL):
        for x in range(CELL):
            if out[y][x] != 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < CELL and 0 <= ny < CELL and cv.mat[ny][nx] is not None:
                    out[y][x] = 1
                    break
    # inner contour: front-layer pixels bordering the far-side layers
    for y in range(1, CELL - 1):
        for x in range(1, CELL - 1):
            v = cv.mat[y][x]
            if v is None or v[2] < 5:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n = cv.mat[y + dy][x + dx]
                if n is not None and n[2] < 3 and out[y][x] != 1:
                    out[y][x] = 1
                    break
    return out


# ---------------------------------------------------------------- PNG


def write_png(path, width, height, rows, palette):
    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    raw = b"".join(b"\x00" + bytes(r) for r in rows)
    plte = b"".join(bytes(c) for c in palette)
    trns = b"\x00" + b"\xff" * (len(palette) - 1)
    data = (b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 3, 0, 0, 0))
            + chunk(b"PLTE", plte) + chunk(b"tRNS", trns)
            + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))
    with open(path, "wb") as f:
        f.write(data)


# ---------------------------------------------------------------- sheet assembly


def frames_for(design, fighter):
    frames = []
    for i, p in enumerate(IDLE):
        frames.append((f"idle_{i}", build_figure(design, p)))
    for i, p in enumerate(WALK):
        frames.append((f"walk_{i}", build_figure(design, p)))
    frames.append(("crouch_0", build_figure(design, CROUCH)))
    for i, p in enumerate(JUMP):
        frames.append((f"jump_{i}", build_figure(design, p)))
    frames.append(("land_0", build_figure(design, LAND)))
    frames.append(("block_0", build_figure(design, BLOCK)))
    frames.append(("block_1", build_figure(design, BLOCK_C)))
    for i, p in enumerate(HIT):
        frames.append((f"hit_{i}", build_figure(design, p)))
    frames.append(("down_0", build_figure(design, DOWN[0])))
    frames.append(("down_1", lying_figure(design, ko=False)))
    frames.append(("getup_0", build_figure(design, GETUP)))
    frames.append(("ko_0", lying_figure(design, ko=True)))
    for i, p in enumerate(WIN):
        frames.append((f"win_{i}", build_figure(design, p)))
    frames.append(("throw_0", build_figure(design, GRAB)))
    frames.append(("thrown_0", build_figure(design, THROWN)))
    # legacy names some move entries still reference
    frames.append(("stance_1", build_figure(design, IDLE[2])))
    frames.append(("idle_1_legacy", build_figure(design, IDLE[1])))
    for move in fighter["moves"]:
        tpl = move_template(move, False)
        s, a, r = tpl
        frames.append((f"{move['id']}_0", build_figure(design, s)))
        frames.append((f"{move['id']}_1", build_figure(design, a)))
        frames.append((f"{move['id']}_2", build_figure(design, lerp_pose(a, r, 0.6))))
    frames.append(("proj_0", projectile_cell(design, 0)))
    frames.append(("proj_1", projectile_cell(design, 1)))
    # drop the helper alias; idle_1 itself exists from IDLE
    return [(n, c) for n, c in frames if n != "idle_1_legacy"]


def generate(root, fid):
    bundle = os.path.join(root, "Content", "Fighters", fid, f"{fid}.contentbundle")
    fighter = json.load(open(os.path.join(bundle, "fighter.json")))
    design = dict(DESIGNS[fid])
    slots = dict(MATERIAL_SLOTS)
    for key in ("torso", "sleeve", "forearm", "glove", "pants", "boots", "belt"):
        assert design[key] in slots, (fid, key)
    frames = frames_for(design, fighter)
    rows_n = (len(frames) + COLS - 1) // COLS
    W, Hh = COLS * CELL, rows_n * CELL
    sheet = [[0] * W for _ in range(Hh)]
    meta = []
    for i, (name, cv) in enumerate(frames):
        ox, oy = (i % COLS) * CELL, (i // COLS) * CELL
        idx = to_indices(cv, slots)
        for y in range(CELL):
            sheet[oy + y][ox:ox + CELL] = idx[y]
        anchor_y = CELL // 2 if name.startswith("proj_") else ANCHOR_Y
        meta.append(dict(name=name, x=ox, y=oy, w=CELL, h=CELL, anchorX=ANCHOR_X, anchorY=anchor_y))
    pal = design["palette"]
    assert len(pal) == 16, (fid, len(pal))
    write_png(os.path.join(bundle, fighter["spriteSheet"]), W, Hh, sheet, pal)
    with open(os.path.join(bundle, fighter["sheetMeta"]), "w") as f:
        f.write(json.dumps(meta, indent=2) + "\n")
    return len(frames), W, Hh


def preview(root, fid, names, out, scale=3):
    """Debug: upscale chosen frames side by side into an RGB PNG (not shipped)."""
    bundle = os.path.join(root, "Content", "Fighters", fid, f"{fid}.contentbundle")
    fighter = json.load(open(os.path.join(bundle, "fighter.json")))
    design = DESIGNS[fid]
    frames = dict(frames_for(design, fighter))
    pal = design["palette"]
    W, H = CELL * scale * len(names), CELL * scale
    rows = []
    cells = [to_indices(frames[n], MATERIAL_SLOTS) for n in names]
    for y in range(H):
        row = bytearray()
        for idx in cells:
            for x in range(CELL * scale):
                i = idx[y // scale][x // scale]
                row += bytes(pal[i]) if i else bytes((48, 52, 64))
        rows.append(row)
    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    raw = b"".join(b"\x00" + bytes(r) for r in rows)
    with open(out, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 2, 0, 0, 0))
                + chunk(b"IDAT", zlib.compress(raw, 6)) + chunk(b"IEND", b""))


if __name__ == "__main__":
    if len(sys.argv) > 2 and sys.argv[1] == "--preview":
        fid, out = sys.argv[2], sys.argv[3]
        preview(os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..")), fid, sys.argv[4:], out)
        sys.exit(0)
    root = sys.argv[1] if len(sys.argv) > 1 else os.path.abspath(
        os.path.join(os.path.dirname(__file__), "..", ".."))
    for fid in ("kestrel", "bruno", "ilse", "rook", "greybox"):
        n, w, h = generate(root, fid)
        print(f"{fid}: {n} frames, {w}x{h}")
