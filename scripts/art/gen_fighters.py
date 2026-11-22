#!/usr/bin/env python3
"""PS2-era hi-res 2D fighter sprite generator (stdlib only, deterministic).

Builds every shipped fighter from a jointed 2D skeleton, poses it per animation frame,
and paints it the way early-2000s 2D fighters (Guilty Gear XX, KOF 2002) looked: smooth
multi-step gradient shading driven by one key light, a baked rim light on the side away
from that light, glossy highlights on hard materials, hue-shifted shadows, darker far-side
limbs, and a soft anti-aliased ~2px dark outline.

Rendering is analytic: every body part is a shape with a signed-distance coverage value
(so edges are anti-aliased without supersampling), composited back to front in layer order.
Writes each bundle's `<id>.png` (RGBA, straight alpha) and `sheet.json`
(`{"texelScale": 2, "frames": [...]}`, rects/anchors in sheet pixels) for the schema in
docs/fighter-schema.md and docs/superpowers/specs/2026-11-21-ps2-visuals-design.md.
224x224 cells, anchor (112, 220), 8 columns: twice the texel density of the old PS1 sheets.

Usage: python3 -I scripts/art/gen_fighters.py [repo_root]
       python3 -I scripts/art/gen_fighters.py --preview <id> <out.png> [--half] <frame>...
Frame names are the contract with AppLogic/Render/SpriteSelection.swift.
The greybox fixture fighter is a separate 1x asset and is not regenerated here.
"""
import json
import math
import os
import struct
import sys
import zlib
from concurrent.futures import ProcessPoolExecutor

K = 2                       # texel scale over the old 1x skeleton
CELL = 112 * K              # 224
COLS = 8
ANCHOR_X, ANCHOR_Y = 56 * K, 110 * K   # (112, 220): feet 4px above the cell bottom
LIGHT = (-0.55, -0.62, 0.56)           # key light: upper-left-front, y-down screen space
OUTLINE_W = 2.0             # outer silhouette outline, texels
INNER_W = 1.15              # contour between overlapping body layers, texels
RIM_K = 0.62                # rim light strength


def _unit(v):
    n = math.sqrt(sum(c * c for c in v))
    return tuple(c / n for c in v)


L3 = _unit(LIGHT)
HALF = _unit((L3[0], L3[1], L3[2] + 1.0))           # blinn half vector (viewer on +z)
RIM_DIR = _unit((-L3[0], -L3[1], 0.0))[:2]          # screen direction pointing away from the light

# ---------------------------------------------------------------- palettes & designs
# Palette slots: 0 unused, 1 outline, 2-4 skin, 5-7 primary, 8-10 secondary,
# 11-12 accent, 13-14 hair, 15 glow/highlight. Each (dark, mid, light) triple becomes a
# smooth 5-stop gradient (deep shadow -> dark -> mid -> light -> highlight).


def ramp(dark, mid, light):
    return [dark, mid, light]


DESIGNS = {
    "kestrel": dict(
        height=94, build=0.92, rim=(150, 215, 255),
        gloss=dict(primary=0.30, accent=0.35, hair=0.45, skin=0.10),
        palette=[(0, 0, 0), (18, 16, 30)]
        + ramp((150, 96, 72), (214, 150, 112), (246, 196, 158))    # skin
        + ramp((40, 92, 150), (78, 150, 210), (170, 222, 248))      # ice jacket
        + ramp((34, 40, 58), (58, 68, 92), (92, 104, 132))          # slate pants
        + [(28, 170, 190), (130, 240, 240)]                         # frost accent
        + [(96, 104, 134), (186, 194, 218)]                         # silver hair
        + [(224, 252, 255)],
        torso="primary", sleeve="primary", forearm="skin", glove="accent",
        pants="secondary", boots="accent", belt="accent", hair="spiky",
        scarf=True,
    ),
    "bruno": dict(
        height=98, build=1.32, rim=(255, 150, 72),
        gloss=dict(primary=0.28, skin=0.22, accent=0.35, hair=0.12),
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
        height=92, build=0.96, rim=(255, 214, 150),
        gloss=dict(primary=0.34, secondary=0.22, accent=0.55, skin=0.10),
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
        height=96, build=1.12, rim=(125, 172, 255),
        gloss=dict(primary=0.85, secondary=0.25, accent=0.6, hair=0.8, skin=0.2),
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
}
MATERIAL_SLOTS = {"skin": [2, 3, 4], "primary": [5, 6, 7], "secondary": [8, 9, 10],
                  "accent": [11, 12, 12], "hair": [13, 14, 14], "glow": [15, 15, 15]}
FIGHTERS = ("kestrel", "bruno", "ilse", "rook")

# ---------------------------------------------------------------- poses
# Angles in degrees measured from straight down, positive rotates toward facing (+x).
# 90 = horizontal forward, 180 = straight up. Elbow/knee are relative bends.
# Offsets (hx, hy) are in the old 1x skeleton units; the builder scales them by K.
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


# ---------------------------------------------------------------- colour & shading


def mix(a, b, t):
    return tuple(x + (y - x) * t for x, y in zip(a, b))


def make_lut(dark, mid, light):
    """256-entry smooth gradient: deep (cool, hue-shifted) -> dark -> mid -> light -> highlight."""
    if tuple(mid) == tuple(light):
        light = mix(mid, (255, 255, 255), 0.36)
    deep = mix(tuple(c * 0.66 for c in dark), (22, 26, 70), 0.30)
    hi = mix(light, (255, 250, 236), 0.34)
    stops = [(0.0, deep), (0.26, dark), (0.52, mid), (0.80, light), (1.0, hi)]
    lut = []
    for i in range(256):
        v = i / 255.0
        for j in range(len(stops) - 1):
            v0, c0 = stops[j]
            v1, c1 = stops[j + 1]
            if v <= v1:
                t = (v - v0) / (v1 - v0)
                t = t * t * (3 - 2 * t) * 0.35 + t * 0.65      # soft knees, still monotonic
                lut.append(mix(c0, c1, t))
                break
    return lut


class Material:
    def __init__(self, lut, gloss, rim):
        self.lut = lut
        self.gloss = gloss
        self.rim = rim


def build_materials(design):
    pal = design["palette"]
    mats = {}
    for name, slots in MATERIAL_SLOTS.items():
        d, m, l = (pal[i] for i in slots)
        if name == "glow":
            flat = [tuple(float(c) for c in m)] * 256
            mats[name] = Material(flat, 0.0, design["rim"])
        else:
            mats[name] = Material(make_lut(d, m, l), design["gloss"].get(name, 0.12), design["rim"])
    return mats


def shade(mat, nx, ny, bias):
    """Surface colour for a screen-space normal (nx, ny); bias darkens far-side parts."""
    q = nx * nx + ny * ny
    if q > 1.0:
        s = 1.0 / math.sqrt(q)
        nx, ny, q = nx * s, ny * s, 1.0
    nz = math.sqrt(1.0 - q)
    lit = nx * L3[0] + ny * L3[1] + nz * L3[2]
    v = 0.40 + 0.50 * lit - bias
    v = 0.0 if v < 0.0 else (1.0 if v > 1.0 else v)
    r, g, b = mat.lut[int(v * 255)]
    if mat.gloss:
        h = nx * HALF[0] + ny * HALF[1] + nz * HALF[2]
        if h > 0.0:
            sp = mat.gloss * (h ** 26) * (1.0 - bias * 2.2)
            if sp > 0:
                r += (255 - r) * sp
                g += (255 - g) * sp
                b += (255 - b) * sp
    ro = nx * RIM_DIR[0] + ny * RIM_DIR[1]
    if ro > 0.0:
        k = RIM_K * (ro ** 1.25) * ((1.0 - nz) ** 1.7) * (1.0 - bias * 2.0)
        if k > 0.0:
            rr, rg, rb = mat.rim
            r += (rr - r) * k
            g += (rg - g) * k
            b += (rb - b) * k
    return r, g, b


# ---------------------------------------------------------------- shapes (prims)
# A prim is a dict painted back to front by (layer, seq). Coverage is analytic.


def vec(angle_deg, length):
    a = math.radians(angle_deg)
    return (math.sin(a) * length, math.cos(a) * length)


def add(a, b):
    return (a[0] + b[0], a[1] + b[1])


def _convex(pts):
    n = len(pts)
    for i in range(n):
        x1, y1 = pts[i]
        x2, y2 = pts[(i + 1) % n]
        x3, y3 = pts[(i + 2) % n]
        if (x2 - x1) * (y3 - y2) - (y2 - y1) * (x3 - x2) < 0:
            return False
    return True


def _area(pts):
    a = 0
    for i in range(len(pts)):
        x1, y1 = pts[i]
        x2, y2 = pts[(i + 1) % len(pts)]
        a += x1 * y2 - x2 * y1
    return a


class Figure:
    def __init__(self, outline_rgb):
        self.prims = []
        self.fx = []
        self.outline_rgb = outline_rgb

    def _add(self, prim):
        prim["seq"] = len(self.prims)
        self.prims.append(prim)

    def cap(self, a, b, ra, rb, mat, layer, bias=0.0, ol=INNER_W, flat=None, alpha=1.0):
        """Tapered capsule. `ol` > 0 first paints a dark contour that only shows over lower layers."""
        if ol:
            self._add(dict(kind="cap", a=a, b=b, ra=ra + ol, rb=rb + ol, flat=self.outline_rgb,
                           layer=layer - 0.02, alpha=1.0))
        self._add(dict(kind="cap", a=a, b=b, ra=ra, rb=rb, mat=mat, flat=flat, bias=bias,
                       layer=layer, alpha=alpha))

    def disc(self, c, r, mat, layer, bias=0.0, ol=INNER_W, flat=None, alpha=1.0):
        self.cap(c, c, r, r, mat, layer, bias, ol, flat, alpha)

    def quad(self, pts, mat, layer, ax0, ax1, hw, bias=0.0, ol=INNER_W):
        pts = pts if _area(pts) > 0 else list(reversed(pts))
        if ol:
            self._add(dict(kind="quad", pts=pts, grow=ol, flat=self.outline_rgb, layer=layer - 0.02,
                           ax0=ax0, ax1=ax1, hw=hw, alpha=1.0))
        self._add(dict(kind="quad", pts=pts, grow=0.0, mat=mat, bias=bias, layer=layer,
                       ax0=ax0, ax1=ax1, hw=hw, alpha=1.0))

    def shadow(self, a, b, ra, rb, layer, strength):
        """Cast shadow: darkens (cool-tinted) whatever is already painted, never adds coverage."""
        self._add(dict(kind="shadow", a=a, b=b, ra=ra, rb=rb, layer=layer, strength=strength))

    def glow(self, c, r, inner, outer, power):
        """Soft additive-looking radial halo painted over everything (never outlined)."""
        self.fx.append(dict(kind="radial", c=c, r=r, inner=inner, outer=outer, power=power, core=False))

    def orb(self, c, r, inner, outer):
        """Gradient disc, opaque edge, painted over everything (never outlined)."""
        self.fx.append(dict(kind="radial", c=c, r=r, inner=inner, outer=outer, power=0.0, core=True))

    def streak(self, a, b, ra, rb, rgb, alpha):
        self.fx.append(dict(kind="cap", a=a, b=b, ra=ra, rb=rb, flat=rgb, mat=None, bias=0.0,
                            layer=0, alpha=alpha))


def _clamp01(x):
    return 0.0 if x < 0.0 else (1.0 if x > 1.0 else x)


class Buf:
    def __init__(self):
        n = CELL * CELL
        self.R = [0.0] * n
        self.G = [0.0] * n
        self.B = [0.0] * n
        self.A = [0.0] * n


def _put(buf, i, r, g, b, cov):
    ia = 1.0 - cov
    buf.R[i] = r * cov + buf.R[i] * ia
    buf.G[i] = g * cov + buf.G[i] * ia
    buf.B[i] = b * cov + buf.B[i] * ia
    buf.A[i] = cov + buf.A[i] * ia


def raster_cap(buf, p, mats):
    ax, ay = p["a"]
    bx, by = p["b"]
    ra, rb = p["ra"], p["rb"]
    pad = max(ra, rb) + 1.5
    x0, x1 = max(0, int(min(ax, bx) - pad)), min(CELL, int(max(ax, bx) + pad) + 2)
    y0, y1 = max(0, int(min(ay, by) - pad)), min(CELL, int(max(ay, by) + pad) + 2)
    dx, dy = bx - ax, by - ay
    ll = dx * dx + dy * dy or 1e-6
    flat = p.get("flat")
    mat = mats[p["mat"]] if not flat else None
    bias = p.get("bias", 0.0)
    alpha = p.get("alpha", 1.0)
    for y in range(y0, y1):
        py = y + 0.5
        row = y * CELL
        for x in range(x0, x1):
            px = x + 0.5
            t = ((px - ax) * dx + (py - ay) * dy) / ll
            t = 0.0 if t < 0.0 else (1.0 if t > 1.0 else t)
            vx, vy = px - (ax + dx * t), py - (ay + dy * t)
            r = ra + (rb - ra) * t
            d = math.sqrt(vx * vx + vy * vy)
            cov = r - d + 0.5
            if cov <= 0.0:
                continue
            if cov > 1.0:
                cov = 1.0
            cov *= alpha
            if flat:
                cr, cg, cb = flat
            else:
                inv = 1.0 / (r if r > 0.3 else 0.3)
                cr, cg, cb = shade(mat, vx * inv, vy * inv, bias)
            _put(buf, row + x, cr, cg, cb, cov)


def raster_shadow(buf, p):
    ax, ay = p["a"]
    bx, by = p["b"]
    ra, rb = p["ra"], p["rb"]
    pad = max(ra, rb) + 3.0
    x0, x1 = max(0, int(min(ax, bx) - pad)), min(CELL, int(max(ax, bx) + pad) + 2)
    y0, y1 = max(0, int(min(ay, by) - pad)), min(CELL, int(max(ay, by) + pad) + 2)
    dx, dy = bx - ax, by - ay
    ll = dx * dx + dy * dy or 1e-6
    st = p["strength"]
    soft = 2.5      # penumbra width, texels
    for y in range(y0, y1):
        py = y + 0.5
        row = y * CELL
        for x in range(x0, x1):
            i = row + x
            a = buf.A[i]
            if a <= 0.0:
                continue
            px = x + 0.5
            t = ((px - ax) * dx + (py - ay) * dy) / ll
            t = 0.0 if t < 0.0 else (1.0 if t > 1.0 else t)
            vx, vy = px - (ax + dx * t), py - (ay + dy * t)
            r = ra + (rb - ra) * t
            k = (r - math.sqrt(vx * vx + vy * vy)) / soft + 0.5
            if k <= 0.0:
                continue
            k = (1.0 if k > 1.0 else k) * st * (a if a < 1.0 else 1.0)
            buf.R[i] *= 1.0 - k * 0.92
            buf.G[i] *= 1.0 - k * 0.84
            buf.B[i] *= 1.0 - k * 0.62


def raster_quad(buf, p, mats):
    pts = p["pts"]
    n = len(pts)
    grow = p["grow"]
    edges = []
    for i in range(n):
        x1, y1 = pts[i]
        x2, y2 = pts[(i + 1) % n]
        ex, ey = x2 - x1, y2 - y1
        ln = math.hypot(ex, ey) or 1e-6
        edges.append((x1, y1, ex / ln, ey / ln))
    xs = [q[0] for q in pts]
    ys = [q[1] for q in pts]
    pad = grow + 2
    x0, x1 = max(0, int(min(xs) - pad)), min(CELL, int(max(xs) + pad) + 1)
    y0, y1 = max(0, int(min(ys) - pad)), min(CELL, int(max(ys) + pad) + 1)
    flat = p.get("flat")
    mat = mats[p["mat"]] if not flat else None
    bias = p.get("bias", 0.0)
    a0x, a0y = p["ax0"]
    a1x, a1y = p["ax1"]
    adx, ady = a1x - a0x, a1y - a0y
    al = math.hypot(adx, ady) or 1e-6
    ux, uy = adx / al, ady / al            # axis direction
    perp = (-uy, ux) if -uy >= 0 else (uy, -ux)   # pointing screen-right for upright parts
    hw = max(p["hw"], 1.0)
    for y in range(y0, y1):
        py = y + 0.5
        row = y * CELL
        for x in range(x0, x1):
            px = x + 0.5
            m = 1e9
            for (ex1, ey1, ux_, uy_) in edges:
                dd = ux_ * (py - ey1) - uy_ * (px - ex1)
                if dd < m:
                    m = dd
                    if m + grow + 0.5 <= 0.0:
                        break
            cov = m + grow + 0.5
            if cov <= 0.0:
                continue
            if cov > 1.0:
                cov = 1.0
            if flat:
                cr, cg, cb = flat
            else:
                rx, ry = px - a0x, py - a0y
                s = (rx * perp[0] + ry * perp[1]) / hw
                s = -0.97 if s < -0.97 else (0.97 if s > 0.97 else s)
                tt = (rx * ux + ry * uy) / al          # 0 at ax0 -> 1 at ax1
                k = (tt - 0.5) * 0.5
                cr, cg, cb = shade(mat, perp[0] * s * 0.92 + ux * k, perp[1] * s * 0.92 + uy * k,
                                     bias + 0.18 * max(0.0, 0.7 - tt) ** 2 * 2.0)
            _put(buf, row + x, cr, cg, cb, cov)


def raster_radial(buf, p):
    cx, cy = p["c"]
    r = p["r"]
    x0, x1 = max(0, int(cx - r - 2)), min(CELL, int(cx + r + 3))
    y0, y1 = max(0, int(cy - r - 2)), min(CELL, int(cy + r + 3))
    i0, i1 = p["inner"], p["outer"]
    power = p["power"]
    core = p["core"]
    for y in range(y0, y1):
        py = y + 0.5
        row = y * CELL
        for x in range(x0, x1):
            px = x + 0.5
            d = math.hypot(px - cx, py - cy)
            if d >= r + 0.5:
                continue
            t = d / r
            if t > 1.0:
                t = 1.0
            if core:
                cov = _clamp01(r - d + 0.5)
            else:
                cov = (1.0 - t) ** power
                cov = cov * cov * (3 - 2 * cov) * p.get("gain", 0.9)
            if cov <= 0.002:
                continue
            c = mix(i0, i1, t)
            _put(buf, row + x, c[0], c[1], c[2], cov)


def raster_prims(buf, prims, mats):
    for p in sorted(prims, key=lambda q: (q.get("layer", 0), q.get("seq", 0))):
        if p["kind"] == "cap":
            raster_cap(buf, p, mats)
        elif p["kind"] == "shadow":
            raster_shadow(buf, p)
        elif p["kind"] == "quad":
            raster_quad(buf, p, mats)
        else:
            raster_radial(buf, p)


def outer_ring(body, outline_rgb, width, tint):
    """Soft outline around the silhouette: returns (ring_alpha, ring_rgb) as sparse dicts.

    Distance to the shape is estimated from anti-aliased coverage: a pixel with coverage a
    sits 0.5 - a outside the true edge, so d(p) = min_q(|p-q| + 0.5 - a_q) over boundary q."""
    A = body.A
    reach = int(width + 2)
    offs = []
    for oy in range(-reach, reach + 1):
        for ox in range(-reach, reach + 1):
            dist = math.hypot(ox, oy)
            if dist <= width + 1.0:
                offs.append((ox, oy, dist))
    best = {}
    for y in range(CELL):
        row = y * CELL
        for x in range(CELL):
            a = A[row + x]
            if a <= 0.01:
                continue
            edge = a < 0.99
            if not edge:
                if x == 0 or y == 0 or x == CELL - 1 or y == CELL - 1:
                    edge = True
                else:
                    i = row + x
                    edge = A[i - 1] < 0.99 or A[i + 1] < 0.99 or A[i - CELL] < 0.99 or A[i + CELL] < 0.99
            if not edge:
                continue
            base = 0.5 - a
            i = row + x
            for ox, oy, dist in offs:
                nx, ny = x + ox, y + oy
                if 0 <= nx < CELL and 0 <= ny < CELL:
                    d = dist + base
                    j = ny * CELL + nx
                    cur = best.get(j)
                    if cur is None or d < cur[0]:
                        best[j] = (d, i)
    ring = {}
    for j, (d, i) in best.items():
        o = _clamp01(width + 0.5 - d)
        if o <= 0.0:
            continue
        qa = A[i]
        qc = (body.R[i] / qa, body.G[i] / qa, body.B[i] / qa) if qa > 0.01 else outline_rgb
        col = mix(outline_rgb, tuple(c * 0.28 for c in qc), tint)
        ring[j] = (o, col)
    return ring


def q8(v):
    """8-bit channel value snapped to a 7-bit grid (halves PNG noise; gradients stay smooth)."""
    return min(255, (int(v * 0.5 + 0.5)) * 2)


def finish(body, fx, ring, outline_rgb):
    """body over ring, fx over that; returns straight-alpha RGBA bytes for the cell."""
    n = CELL * CELL
    out = bytearray(n * 4)
    BR, BG, BB, BA = body.R, body.G, body.B, body.A
    for i in range(n):
        ba = BA[i]
        rg = ring.get(i)
        fa = fx.A[i]
        if ba <= 0.0 and rg is None and fa <= 0.0:
            out[i * 4], out[i * 4 + 1], out[i * 4 + 2] = outline_rgb
            continue
        ia = 1.0 - ba
        if rg is not None:
            o, col = rg
            r = BR[i] + col[0] * o * ia
            g = BG[i] + col[1] * o * ia
            b = BB[i] + col[2] * o * ia
            a = ba + o * ia
        else:
            r, g, b, a = BR[i], BG[i], BB[i], ba
        if fa > 0.0:
            ifa = 1.0 - fa
            r = fx.R[i] + r * ifa
            g = fx.G[i] + g * ifa
            b = fx.B[i] + b * ifa
            a = fa + a * ifa
        if a <= 0.002:
            out[i * 4], out[i * 4 + 1], out[i * 4 + 2] = outline_rgb
            continue
        k = 1.0 / a
        out[i * 4] = q8(r * k)
        out[i * 4 + 1] = q8(g * k)
        out[i * 4 + 2] = q8(b * k)
        out[i * 4 + 3] = min(255, int(a * 255 + 0.5))
    return bytes(out)


def render(fig, design, mats, outlined=True):
    body = Buf()
    raster_prims(body, fig.prims, mats)
    ring = outer_ring(body, fig.outline_rgb, OUTLINE_W, 0.45) if outlined else {}
    fx = Buf()
    raster_prims(fx, fig.fx, mats)
    return finish(body, fx, ring, fig.outline_rgb)


# ---------------------------------------------------------------- skeleton


def ground_offset(design):
    """How far the skeleton's standing boots hang below ANCHOR_Y; the builder lifts by this so
    the soles of a grounded idle pose rest on the anchor line (the outline then fits in the cell)."""
    if "_ground" not in design:
        fig = build_figure(design, IDLE[0], ground=0.0, fit=False)
        design["_ground"] = figure_bounds(fig)[3] - ANCHOR_Y
    return design["_ground"]


def build_figure(design, pose, ground=None, fit=True):
    """Returns a Figure with the posed fighter, feet at (ANCHOR_X, ANCHOR_Y)."""
    if ground is None:
        ground = ground_offset(design)
    fig = Figure(tuple(design["palette"][1]))
    H = design["height"]
    b = design["build"]
    s = H / 94.0 * K
    thigh, shin = 21 * s, 20 * s
    torso_len, neck = 31 * s, 2.5 * s
    upper, fore = 15 * s, 14 * s
    head_r = 8.0 * s
    limb_r = 5.4 * b * s
    stand_hip = thigh + shin - 2 * K
    hip = (ANCHOR_X + pose["hx"] * K, ANCHOR_Y - stand_hip + pose["hy"] * K - ground)

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
        if layer >= 6:
            off = (2.5 * K, 4 * K)
            fig.shadow(add(sh, off), add(elbow, off), limb_r * 1.1, limb_r * 0.95, layer - 0.1, 0.38)
            fig.shadow(add(elbow, off), add(hand, off), limb_r * 0.95, limb_r * 0.85, layer - 0.1, 0.38)
        fig.disc(sh, limb_r * 1.35, design["sleeve"], layer, bias)  # deltoid
        fig.cap(sh, elbow, limb_r * 1.1, limb_r * 0.9, design["sleeve"], layer, bias)
        fig.cap(elbow, hand, limb_r * 0.9, limb_r * 0.8, design["forearm"], layer, bias)
        # wrist cuff
        c0 = add(elbow, ((hand[0] - elbow[0]) * 0.74, (hand[1] - elbow[1]) * 0.74))
        c1 = add(elbow, ((hand[0] - elbow[0]) * 0.9, (hand[1] - elbow[1]) * 0.9))
        fig.cap(c0, c1, limb_r * 0.86, limb_r * 0.84, "accent", layer + 0.3, bias, ol=0)
        fig.disc(hand, limb_r * (1.05 if pose["fist"] else 0.85), design["glove"], layer + 0.5, bias)
        return hand

    def leg(hp, spec, layer, bias):
        ta, kb = spec
        knee = add(hp, vec(ta, thigh))
        ankle = add(knee, vec(ta - kb, shin))
        fig.cap(hp, knee, limb_r * 1.55, limb_r * 1.2, design["pants"], layer, bias)
        fig.cap(knee, ankle, limb_r * 1.2, limb_r * 0.95, design["pants"], layer, bias)
        toe = add(ankle, vec(ta - kb - 80, 6.5 * s))
        fig.cap(ankle, toe, limb_r * 0.95, limb_r * 0.8, design["boots"], layer + 0.5, bias)

    # back limbs (far side, darker), torso, head, front limbs
    arm(sh_b, pose["ba"], 1, 0.22)
    leg(hip_b, pose["bl"], 1, 0.22)
    chest_w, waist_w = 13.5 * b * s, 9.5 * b * s
    px, py = -chest_dir[1], chest_dir[0]  # perpendicular

    def tp(t, w):
        """Point at fraction t along hip->neck and signed width w across the torso."""
        return (hip[0] + (neck_pt[0] - hip[0]) * t + px * w, hip[1] + (neck_pt[1] - hip[1]) * t + py * w)

    wl = lambda t: waist_w + (chest_w - waist_w) * t
    torso_pts = [tp(0, -waist_w), tp(0, waist_w), tp(0.55, wl(0.55) * 1.02), tp(0.84, chest_w * 0.98),
                 tp(0.97, chest_w * 0.72), tp(0.97, -chest_w * 0.72), tp(0.84, -chest_w * 0.98),
                 tp(0.55, -wl(0.55) * 1.02)]
    fig.quad(torso_pts, design["torso"], 3, hip, neck_pt, (chest_w + waist_w) / 2)
    fig.cap(hip_b, hip_f, waist_w * 0.55, waist_w * 0.55, design["pants"], 3)
    # belt / sash and buckle
    fig.cap(add(hip, (-waist_w, -2 * K)), add(hip, (waist_w, -2 * K)), 1.6 * s, 1.6 * s, design["belt"], 3.5)
    fig.disc(add(hip, (waist_w * 0.34, -2 * K)), 2.1 * s, "glow", 3.55, ol=0)
    if design.get("skirt"):
        hem_f = add(hip_f, vec(pose["fl"][0] * 0.6, thigh * 1.05))
        hem_b = add(hip_b, vec(pose["bl"][0] * 0.6, thigh * 1.05))
        sk = [(hip[0] - waist_w, hip[1]), (hip[0] + waist_w, hip[1]),
              (hem_f[0] + 4 * s, hem_f[1]), (hem_b[0] - 4 * s, hem_b[1])]
        mid_hem = ((hem_f[0] + hem_b[0]) / 2, (hem_f[1] + hem_b[1]) / 2)
        fig.quad(sk, design["torso"], 3.2, hip, mid_hem, waist_w * 1.4)
        # gold hem trim (only while the skirt quad is a clean convex shape)
        if _convex(sk if _area(sk) > 0 else list(reversed(sk))):
            fig.cap((hem_b[0] - 4 * s, hem_b[1] - 1.2 * s), (hem_f[0] + 4 * s, hem_f[1] - 1.2 * s),
                    1.1 * s, 1.1 * s, "accent", 3.3, ol=0)
    if design.get("scarf"):
        tail = add(neck_pt, vec(-110 - lean, 14 * s))
        fig.cap(add(neck_pt, (0, 1 * K)), tail, 2.6 * s, 1.4 * s, "accent", 3.6)
    fig.shadow(add(head_c, (2.5 * K, 5 * K)), add(head_c, (2.5 * K, 5 * K)), head_r * 1.05, head_r * 1.05, 3.65, 0.42)
    fig.cap(add(neck_pt, (0, 2 * K)), head_c, 3 * s, 3 * s, "skin", 3.7, bias=0.2)
    fig.disc(head_c, head_r, "skin", 4)
    # nose and ear give the round head a profile
    fig.disc(add(head_c, (head_r * 0.93, head_r * 0.12)), head_r * 0.19, "skin", 4.05, ol=0)
    fig.disc(add(head_c, (-head_r * 0.12, head_r * 0.08)), head_r * 0.2, "skin", 4.05, bias=0.12, ol=0)
    hair(fig, design, head_c, head_r, lean + pose["head"], s)
    if design["hair"] != "helmet":
        ex, ey = head_c[0] + head_r * 0.46, head_c[1] - head_r * 0.06
        fig.disc((ex, ey), head_r * 0.2, None, 5.2, ol=0, flat=(244, 242, 238))
        fig.disc((ex + head_r * 0.05, ey), head_r * 0.13, None, 5.25, ol=0, flat=tuple(design["palette"][1]))
        fig.disc((ex + head_r * 0.08, ey - head_r * 0.06), head_r * 0.045, None, 5.3, ol=0, flat=(255, 255, 255))
        fig.cap((ex - head_r * 0.2, ey - head_r * 0.3), (ex + head_r * 0.28, ey - head_r * 0.36),
                head_r * 0.07, head_r * 0.07, None, 5.2, ol=0, flat=tuple(design["palette"][1]))
    leg(hip_f, pose["fl"], 5, 0.0)
    hand = arm(sh_f, pose["fa"], 6, 0.0)
    if pose["glow"]:
        fig.glow(hand, 15 * s, tuple(design["palette"][12]), tuple(design["palette"][11]), 1.7)
        fig.orb(hand, 6.0 * s, tuple(design["palette"][15]), tuple(design["palette"][12]))
    return fit_figure(fig, pose["hy"] >= -3) if fit else fig


def hair(fig, design, c, r, tilt, s):
    style = design["hair"]
    up = vec(180 - tilt, 1)
    back = vec(-90 - tilt, 1)
    if style == "spiky":
        for i, ang in enumerate((-60, -30, 0, 30, 60)):
            base = add(c, vec(180 - tilt + ang * 0.8, r * 0.7))
            tip = add(c, vec(180 - tilt + ang - 25, r * (1.9 if i % 2 else 1.6)))
            fig.cap(base, tip, 2.8 * s, 0.6 * s, "hair", 5)
        fig.cap(add(c, (up[0] * r * 0.4, up[1] * r * 0.4)), add(c, (back[0] * r * 0.6, back[1] * r * 0.6)),
                r * 0.75, r * 0.6, "hair", 5)
    elif style == "bald_beard":
        chin = add(c, vec(30 - tilt, r * 0.85))
        jaw = add(c, vec(60 - tilt, r * 0.78))
        fig.cap(jaw, chin, r * 0.3, r * 0.34, "hair", 5)   # full beard along the jaw
        fig.disc(add(chin, (r * 0.04, r * 0.16)), r * 0.28, "hair", 5.05, ol=0)
    elif style == "veil":
        # hood over the crown and back of the head; the face (front) stays skin
        fig.cap(add(c, (up[0] * r * 0.35 + back[0] * r * 0.25, up[1] * r * 0.35 + back[1] * r * 0.25)),
                add(c, (back[0] * r * 0.9, back[1] * r * 0.9)), r * 0.85, r * 0.85, "hair", 5)
        fig.cap(add(c, (up[0] * r * 0.8, up[1] * r * 0.8)), add(c, (up[0] * r * 0.6 + r * 0.55, up[1] * r * 0.6)),
                r * 0.35, r * 0.25, "hair", 5)
        fig.cap(add(c, (back[0] * r * 0.8, back[1] * r * 0.8)),
                add(c, (back[0] * r * 1.4, back[1] * r * 1.4 + r * 2.6)), r * 0.8, r * 1.0, "hair", 2.9)
        fig.cap(add(c, (-r * 0.2, -r * 0.95)), add(c, (r * 0.5, -r * 0.95)), 1.3 * s, 1.3 * s, "accent", 5.5)
    elif style == "helmet":
        fig.cap(add(c, (up[0] * r * 0.1, up[1] * r * 0.1)), add(c, (back[0] * r * 0.3, back[1] * r * 0.3)),
                r * 1.08, r * 1.0, "hair", 5)
        fig.cap(add(c, (r * 0.05, -r * 0.05)), add(c, (r * 0.85, -r * 0.05)), 1.6 * s, 1.6 * s, "accent", 5.5)
        fig.cap(add(c, (-r * 0.2, -r * 1.0)), add(c, (-r * 0.9, -r * 1.7)), 1.4 * s, 0.6 * s, "accent", 5.5)


def _xf_point(p, fn):
    return fn(p[0], p[1])


def transform_figure(fig, fn, k=1.0):
    """Apply a similarity map (point function `fn`, uniform scale `k`) to every prim, so radii
    and normals follow and shading stays correct."""
    out = Figure(fig.outline_rgb)
    for p in fig.prims:
        q = dict(p)
        for key in ("ra", "rb", "hw", "grow"):
            if key in q:
                q[key] = q[key] * k
        for key in ("a", "b", "ax0", "ax1"):
            if key in q:
                q[key] = _xf_point(q[key], fn)
        if "pts" in q:
            q["pts"] = [_xf_point(pt, fn) for pt in q["pts"]]
        out.prims.append(q)
    for p in fig.fx:
        q = dict(p)
        for key in ("ra", "rb", "r"):
            if key in q:
                q[key] = q[key] * k
        for key in ("a", "b", "c"):
            if key in q:
                q[key] = _xf_point(q[key], fn)
        out.fx.append(q)
    return out


def fit_figure(fig, grounded, margin=3.0):
    """Keep a posed figure inside its cell: rest grounded poses on the anchor line, nudge
    sideways / down by a bounded amount, and as a last resort shrink slightly about the feet
    so a long reach or a raised arm is not cut off."""
    x0, x1, y0, y1 = figure_bounds(fig)
    dx = dy = 0.0
    if grounded and y1 > ANCHOR_Y:
        dy = ANCHOR_Y - y1
    if not grounded and y0 + dy < margin:
        dy += min(margin - (y0 + dy), 44.0)
    if x0 < margin:
        dx = min(margin - x0, 16.0)
    elif x1 > CELL - margin:
        dx = -min(x1 - (CELL - margin), 16.0)
    if y1 + dy > CELL - margin:
        dy = CELL - margin - y1
    x0, x1, y0, y1 = x0 + dx, x1 + dx, y0 + dy, y1 + dy
    f = 1.0
    if y0 < margin:
        f = min(f, (y1 - margin) / (y1 - y0))
    if x1 > CELL - margin:
        f = min(f, (CELL - margin - ANCHOR_X) / (x1 - ANCHOR_X))
    if x0 < margin:
        f = min(f, (ANCHOR_X - margin) / (ANCHOR_X - x0))
    f = max(f, 0.86)
    if f == 1.0 and dx == 0.0 and dy == 0.0:
        return fig
    cx, cy = ANCHOR_X, y1
    return transform_figure(fig, lambda x, y: (cx + (x + dx - cx) * f, cy + (y + dy - cy) * f), f)


def figure_bounds(fig):
    xs0, xs1, ys0, ys1 = [], [], [], []
    for p in fig.prims:
        if p["kind"] == "shadow":
            continue
        if p["kind"] == "cap":
            r = max(p["ra"], p["rb"])
            xs0.append(min(p["a"][0], p["b"][0]) - r)
            xs1.append(max(p["a"][0], p["b"][0]) + r)
            ys0.append(min(p["a"][1], p["b"][1]) - r)
            ys1.append(max(p["a"][1], p["b"][1]) + r)
        else:
            xs0.append(min(q[0] for q in p["pts"]))
            xs1.append(max(q[0] for q in p["pts"]))
            ys0.append(min(q[1] for q in p["pts"]))
            ys1.append(max(q[1] for q in p["pts"]))
    for p in fig.fx:            # glow orbs and the bright part of their halo
        if p["kind"] == "radial":
            r = p["r"] * (1.0 if p["core"] else 0.62)
            xs0.append(p["c"][0] - r)
            xs1.append(p["c"][0] + r)
            ys0.append(p["c"][1] - r)
            ys1.append(p["c"][1] + r)
    return min(xs0), max(xs1), min(ys0), max(ys1)


def lying_figure(design, ko):
    """Knocked-down body: the standing figure rotated 90 degrees onto its back, head behind
    (-x), feet toward the facing side, resting on the ground line."""
    flat = P(lean=0, fa=(-10, 20), ba=(10, 20), fl=(8, 6), bl=(-8, 8), head=0 if ko else -10)
    stand = build_figure(design, flat)

    def rot(x, y):
        return (y - ANCHOR_Y, -(x - ANCHOR_X))

    rotated = transform_figure(stand, rot)
    x0, x1, y0, y1 = figure_bounds(rotated)
    shx = ANCHOR_X - (x0 + x1) / 2
    shy = (ANCHOR_Y - 2 * K) - y1

    def move(x, y):
        return (x + shx, y + shy)

    return transform_figure(rotated, move)


def projectile_cell(design, frame):
    fig = Figure(tuple(design["palette"][1]))
    pal = design["palette"]
    c = (ANCHOR_X, CELL / 2)
    wob = 1.5 * K if frame else 0
    fig.glow(c, 34 + wob * 2, tuple(pal[12]), tuple(pal[11]), 1.8)
    for i in range(5):
        a = (i * 72 + frame * 36)
        tail = add(c, vec(-90 + (a % 360) * 0.18 - 32, 13 * K + wob))
        fig.streak(c, tail, 5.5 * K, 1.0 * K, tuple(pal[12]), 0.75)
    fig.orb(c, 9.5 * K + wob, tuple(pal[15]), tuple(pal[12]))
    fig.orb((c[0] + K, c[1] - K), 5.5 * K, (255, 255, 255), tuple(pal[15]))
    return fig


# ---------------------------------------------------------------- PNG


def png_bytes(width, height, raw_rows, colortype):
    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    raw = b"".join(b"\x00" + bytes(r) for r in raw_rows)
    return (b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, colortype, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


# ---------------------------------------------------------------- sheet assembly


def frames_for(design, fighter):
    """Ordered list of (name, Figure)."""
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
    # legacy name some move entries still reference
    frames.append(("stance_1", build_figure(design, IDLE[2])))
    for move in fighter["moves"]:
        tpl = move_template(move, False)
        s, a, r = tpl
        frames.append((f"{move['id']}_0", build_figure(design, s)))
        frames.append((f"{move['id']}_1", build_figure(design, a)))
        frames.append((f"{move['id']}_2", build_figure(design, lerp_pose(a, r, 0.6))))
    frames.append(("proj_0", projectile_cell(design, 0)))
    frames.append(("proj_1", projectile_cell(design, 1)))
    return frames


def bundle_dir(root, fid):
    return os.path.join(root, "Content", "Fighters", fid, f"{fid}.contentbundle")


def render_frame(name, fig, design, mats):
    return render(fig, design, mats, outlined=not name.startswith("proj_"))


def generate(root, fid):
    bundle = bundle_dir(root, fid)
    fighter = json.load(open(os.path.join(bundle, "fighter.json")))
    design = dict(DESIGNS[fid])
    for key in ("torso", "sleeve", "forearm", "glove", "pants", "boots", "belt"):
        assert design[key] in MATERIAL_SLOTS, (fid, key)
    mats = build_materials(design)
    frames = frames_for(design, fighter)
    rows_n = (len(frames) + COLS - 1) // COLS
    W, Hh = COLS * CELL, rows_n * CELL
    sheet = bytearray(W * Hh * 4)
    # transparent texels carry the outline colour so bilinear filtering never bleeds black
    oc = bytes(design["palette"][1]) + b"\x00"
    sheet[:] = oc * (W * Hh)
    meta = []
    for i, (name, fig) in enumerate(frames):
        ox, oy = (i % COLS) * CELL, (i // COLS) * CELL
        px = render_frame(name, fig, design, mats)
        for y in range(CELL):
            o = ((oy + y) * W + ox) * 4
            sheet[o:o + CELL * 4] = px[y * CELL * 4:(y + 1) * CELL * 4]
        anchor_y = CELL // 2 if name.startswith("proj_") else ANCHOR_Y
        meta.append(dict(name=name, x=ox, y=oy, w=CELL, h=CELL, anchorX=ANCHOR_X, anchorY=anchor_y))
    rows = [sheet[y * W * 4:(y + 1) * W * 4] for y in range(Hh)]
    png = png_bytes(W, Hh, rows, 6)
    with open(os.path.join(bundle, fighter["spriteSheet"]), "wb") as f:
        f.write(png)
    with open(os.path.join(bundle, fighter["sheetMeta"]), "w") as f:
        f.write(json.dumps({"texelScale": K, "frames": meta}, indent=2) + "\n")
    return fid, len(frames), W, Hh, len(png)


def preview(root, fid, names, out, half=False):
    """Debug: composite chosen frames over a dusk backdrop into an RGB PNG (not shipped)."""
    fighter = json.load(open(os.path.join(bundle_dir(root, fid), "fighter.json")))
    design = DESIGNS[fid]
    mats = build_materials(design)
    frames = dict(frames_for(design, fighter))
    f = 2 if half else 1
    cw = CELL // f
    zoom = 2 if "zoom" in os.environ.get("GF_PREVIEW", "") else 1
    W, H = cw * len(names), cw
    rows = [bytearray() for _ in range(H)]
    for n in names:
        px = render_frame(n, frames[n], design, mats)
        for y in range(cw):
            row = rows[y]
            bg0 = (74 + y * 20 // cw, 80 + y * 14 // cw, 108 - y * 20 // cw)
            for x in range(cw):
                acc = [0.0, 0.0, 0.0, 0.0]
                for sy in range(f):
                    for sx in range(f):
                        i = ((y * f + sy) * CELL + x * f + sx) * 4
                        a = px[i + 3] / 255.0
                        acc[0] += px[i] * a
                        acc[1] += px[i + 1] * a
                        acc[2] += px[i + 2] * a
                        acc[3] += a
                k = 1.0 / (f * f)
                a = acc[3] * k
                for c in range(3):
                    row.append(int(acc[c] * k + bg0[c] * (1 - a) + 0.5))
    if zoom > 1:
        rows = [bytearray(b"".join(bytes(r[x * 3:x * 3 + 3]) * zoom for x in range(W))) for r in rows for _ in range(zoom)]
        W, H = W * zoom, H * zoom
    with open(out, "wb") as fh:
        fh.write(png_bytes(W, H, rows, 2))


def _repo_root():
    return os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


if __name__ == "__main__":
    if len(sys.argv) > 3 and sys.argv[1] == "--preview":
        args = sys.argv[4:]
        half = "--half" in args
        preview(_repo_root(), sys.argv[2], [a for a in args if a != "--half"], sys.argv[3], half)
        sys.exit(0)
    root = sys.argv[1] if len(sys.argv) > 1 else _repo_root()
    with ProcessPoolExecutor(max_workers=len(FIGHTERS)) as pool:
        futures = [pool.submit(generate, root, fid) for fid in FIGHTERS]
        total = 0
        for fut in futures:   # submission order keeps the log deterministic
            fid, n, w, h, size = fut.result()
            total += size
            print(f"{fid}: {n} frames, {w}x{h}, {size / 1024:.0f} KiB")
        print(f"total {total / 1024 / 1024:.2f} MiB")
