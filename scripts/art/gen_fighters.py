#!/usr/bin/env python3
"""Fighter sprite-sheet generator (stdlib only, deterministic).

Poses every shipped fighter's jointed 2D skeleton per animation frame and has fighter_designs.py
draw it as an anime-style cel figure: bold shapes, a single shadow tone per material, a tinted
outline, and a 3/4 face. Rendering is analytic (raster.py), so edges are anti-aliased without
supersampling and two runs produce identical bytes.

Writes each bundle's `<id>.png`, the alternate costume `<id>_alt.png` (RGBA, straight alpha) and
`sheet.json` (`{"texelScale": 2, "frames": [...]}`, rects/anchors in sheet pixels) for the schema in
docs/fighter-schema.md. 224x224 cells, anchor (112, 220), 8 columns; `proj_*` cells anchor at the
cell centre. A fighter is drawn at one scale in every frame: a pose that would leave its cell is
shifted inside it (never shrunk), and scripts/art/contact_sheet.py lists every such shift.

Usage: python3 -I scripts/art/gen_fighters.py [repo_root]
Frame names are the contract with AppLogic/Render/SpriteSelection.swift.
The greybox fixture fighter is a separate 1x asset and is not regenerated here.
"""
import json
import math
import os
import sys
from concurrent.futures import ProcessPoolExecutor

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))   # sibling modules, also under `python3 -I`

import fighter_designs as designs  # noqa: E402
import raster as rs  # noqa: E402
from fighter_designs import FIGHTERS  # noqa: E402
from raster import ANCHOR_X, ANCHOR_Y, CELL, K  # noqa: E402

COLS = 8
MARGIN = 4.0                # clear texels kept between a figure and its cell edge (room for the outline)

# ---------------------------------------------------------------- poses
# Angles in degrees measured from straight down, positive rotates toward facing (+x).
# 90 = horizontal forward, 180 = straight up. Elbow/knee are relative bends.
# Offsets (hx, hy) are in 1x skeleton units; the rig scales them by K. A grounded pose always
# stands on the anchor line (its hip height follows from the legs), so hy only matters for
# airborne poses (hy < designs.AIR_HY) and for planted-feet frames like the idle bob.
# glow: False, "hand" or "foot" (which limb carries the fighter's effect).
BASE = dict(hx=0, hy=0, lean=6, head=0,
            fa=(28, 70), ba=(14, 80),        # (upper arm angle, elbow bend) front/back
            fl=(14, 18), bl=(-12, 10),       # (thigh angle, knee bend) front/back
            glow=False, fist=True)

# Each fighter's ready stance: what every pose falls back to for the limbs it does not set.
STANCES = {
    "kestrel": dict(lean=9, fa=(34, 96), ba=(44, 96), fl=(42, 54), bl=(-30, 4)),
    "bruno": dict(lean=6, fa=(40, 84), ba=(12, 96), fl=(34, 14), bl=(-32, 8)),
    "ilse": dict(lean=4, fa=(52, 60), ba=(12, 88)),
    "rook": dict(lean=4, fa=(52, 60), ba=(12, 88), fl=(28, 24), bl=(-28, 14)),
}


def lerp_pose(a, b, t):
    out = {}
    for k, v in a.items():
        w = b[k]
        if isinstance(v, tuple):
            out[k] = tuple(x + (y - x) * t for x, y in zip(v, w))
        elif isinstance(v, (bool, str)):
            out[k] = v if t < 0.5 else w
        else:
            out[k] = v + (w - v) * t
    return out


def leg_units(fid):
    """Hip-to-ankle length of a fighter's straight leg in the 1x units pose["hy"] is measured in."""
    ch = designs.DESIGNS[fid]
    return (ch.get("thigh", 21) + ch.get("shin", 20)) * ch.get("leg", 1.0) * ch["height"] / 94.0


def pose_tables(fid):
    """Every pose of a fighter, keyed by table name: single poses, lists, and T_* move templates
    (startup, active, recovery)."""
    stance = dict(BASE, **STANCES[fid])

    def P(**kw):
        return dict(stance, **kw)

    def bend(spec, da, db):
        return (spec[0] + da, spec[1] + db)

    fa, ba = stance["fa"], stance["ba"]
    T = {}
    # idle: the hips sink and the guard breathes; frames_for plants the feet so they never slide
    T["IDLE"] = [P(hy=h, fa=bend(fa, k, 2 * k), ba=bend(ba, k / 2, k)) for h, k in ((0, 0), (1, 2), (2, 4), (1, 2))]
    T["WALK"] = []
    for i in range(6):
        ph = i / 6 * 2 * math.pi
        dip = 12 * (1 - abs(math.sin(ph)))      # knees give as the legs pass, so the head does not bob up
        T["WALK"].append(P(lean=stance["lean"] + 2,
                           fl=(14 + 26 * math.sin(ph), 16 + dip + 22 * max(0, -math.cos(ph))),
                           bl=(-12 - 26 * math.sin(ph), 16 + dip + 22 * max(0, math.cos(ph))),
                           fa=bend(fa, -10 * math.sin(ph), 0), ba=bend(ba, 14 * math.sin(ph), 0)))
    # crouch / crouch block / landing: frames_for plants both feet where CROUCH_REF puts them and the hips drop
    # by a share of the leg length, so the knees fold forward over feet that stay flat on the ground line
    leg = leg_units(fid)
    # (the back ankle sits higher in the reference: that foot ends up on its ball with the heel raised)
    T["CROUCH_REF"] = P(lean=0, fl=(26, 6), bl=(16, 72))
    T["CROUCH"] = P(hy=0.40 * leg, lean=18, fa=(40, 80), ba=(30, 90))
    T["JUMP"] = [P(hy=10, lean=14, fl=(40, 60), bl=(10, 50)),
                 P(hy=-4, lean=4, fl=(42, 64), bl=(-24, 52), fa=(72, 52), ba=(52, 60)),
                 # apex tuck: front knee high with the shin hanging under it, back leg folded behind
                 P(hy=-10, lean=10, fl=(98, 106), bl=(-6, 104), fa=(50, 90), ba=(40, 90)),
                 P(hy=-4, lean=2, fl=(32, 48), bl=(-8, 60), fa=(86, 40), ba=(64, 50))]
    T["LAND"] = P(hy=0.24 * leg, lean=16)
    T["BLOCK"] = P(hy=4, lean=-4, fa=(80, 120), ba=(70, 125), fl=(20, 22), bl=(-20, 16))
    T["BLOCK_C"] = P(hy=0.40 * leg, lean=10, fa=(80, 125), ba=(70, 125))
    T["HIT"] = [P(hy=2, lean=-22, head=-14, fa=(-10, 30), ba=(-20, 40), fl=(20, 20), bl=(-26, 10)),
                P(hy=4, lean=-30, head=-20, fa=(-30, 20), ba=(-40, 30), fl=(30, 30), bl=(-20, 20))]
    # knocked off the feet (posed near upright, then frames_for spins the whole figure backwards): the body
    # goes first, head thrown back, and the arms and legs lag behind it
    T["FALL"] = P(hy=-6, lean=-12, head=-14, fa=(84, 36), ba=(60, 40), fl=(60, 50), bl=(26, 66))
    # on the back (posed standing, then spun; angles > 0 lift a limb off the ground): winded, head and one
    # forearm lifted, front knee drawn up
    T["LYING"] = P(lean=0, head=12, fa=(26, 44), ba=(-14, 24), fl=(64, 116), bl=(36, 72))
    # out cold: head back on the ground, arms limp at the sides, legs slack with one knee slightly raised
    T["KO"] = P(lean=0, head=-12, fa=(-14, 34), ba=(-18, 22), fl=(34, 60), bl=(12, 22))
    T["GETUP"] = P(hy=26, lean=30, fl=(80, 130), bl=(20, 120), fa=(10, 20), ba=(0, 30))
    T["WIN"] = [P(lean=0, fa=(136, 30), ba=(20, 60), fl=(16, 14), bl=(-14, 14)),
                P(lean=-2, fa=(142, 44), ba=(25, 70), fl=(16, 14), bl=(-14, 14))]
    T["GRAB"] = P(lean=14, fa=(80, 40), ba=(70, 50), fl=(30, 20), bl=(-20, 10))
    T["THROWN"] = P(hy=-14, lean=-8, head=-16, fa=(120, 40), ba=(132, 58), fl=(62, 84), bl=(26, 60))

    T["T_JAB"] = (P(fa=(60, 110), lean=8), P(fa=(90, 0), lean=12, hx=2), P(fa=(70, 60), lean=8))
    T["T_CROSS"] = (P(ba=(40, 100), lean=-2, fa=(40, 90)),
                    P(fa=(92, 0), ba=(-58, 42), lean=20, hx=2, fl=(30, 20), bl=(-30, 4)),
                    P(fa=(70, 50), lean=10, hx=3))
    T["T_LK"] = (P(fl=(50, 90), lean=0), P(fl=(78, 6), bl=(-8, 4), lean=-6), P(fl=(40, 50)))
    T["T_HK"] = (P(fl=(70, 120), lean=-6, hy=-2),
                 P(fl=(118, 0), bl=(-6, 4), lean=-24, fa=(10, 60), ba=(-20, 50)),
                 P(fl=(60, 70), lean=-8))
    T["T_PUSH"] = (P(fa=(30, 130), ba=(20, 130), lean=-6, fl=(30, 20), bl=(-30, 10)),
                   P(fa=(88, 4), ba=(84, 10), lean=10, fl=(36, 24), bl=(-34, 6), glow="hand", fist=False),
                   P(fa=(70, 30), ba=(60, 40), lean=8))
    T["T_UPPER"] = (P(hy=16, lean=20, fa=(40, 120), fl=(60, 100), bl=(20, 90)),
                    P(hy=-18, lean=-4, fa=(164, 10), ba=(30, 60), fl=(56, 96), bl=(4, 70), glow="hand"),
                    P(hy=-6, lean=0, fa=(130, 40), fl=(30, 40), bl=(-20, 40)))
    T["T_RUSHK"] = (P(hy=6, lean=20, fl=(60, 100), bl=(-10, 40)),
                    P(hy=-12, lean=-16, fl=(96, 0), bl=(20, 110), fa=(20, 60), ba=(-48, 46), glow="foot"),
                    P(hy=4, lean=8, fl=(40, 50)))
    T["T_RUSHP"] = (P(hy=6, lean=24, fa=(30, 120), fl=(50, 70), bl=(-30, 20)),
                    P(hy=0, lean=26, fa=(92, 0), ba=(-84, 34), fl=(50, 30), bl=(-50, 10), glow="hand"),
                    P(lean=14, fa=(70, 40)))
    T["T_GUARD"] = (P(fa=(70, 120), ba=(60, 120), lean=-6),
                    P(fa=(100, 100), ba=(90, 110), lean=-10, glow="hand"),
                    P(fa=(60, 90), lean=0))
    T["T_SWEEP"] = (P(hy=22, lean=24, fl=(60, 110), bl=(30, 100)),
                    P(hy=26, lean=40, fl=(88, 0), bl=(20, 120), fa=(-10, 40), ba=(-20, 30), glow="foot"),
                    P(hy=20, lean=20, fl=(60, 100), bl=(30, 100)))
    T["T_GRAB"] = (P(fa=(60, 80), ba=(50, 80), lean=10), T["GRAB"], P(fa=(150, 40), ba=(130, 50), lean=-10))
    T["T_SUPER"] = (P(hy=14, lean=-10, fa=(20, 140), ba=(10, 140), fl=(40, 60), bl=(-40, 40), glow="hand"),
                    P(hy=-2, lean=18, fa=(90, 0), ba=(86, 4), fl=(50, 20), bl=(-50, 4), glow="hand", fist=False),
                    P(hy=6, lean=10, fa=(70, 40), ba=(60, 50)))
    for name, tweak in FIGHTER_TWEAKS.get(fid, {}).items():
        T[name] = tweak(T[name], P)
    return T


# Per-fighter departures from the shared tables: {table: fn(table_value, P) -> new value}.
FIGHTER_TWEAKS = {
    # Bruno's heavy punch is the approved haymaker: gauntlet stoked, feet set wide.
    # and his gauntlet is too big to raise past his face, so he wins with it cocked out in front.
    # He also stands almost as tall as the cell, so he jumps with his knees bent further (and see WALK_SINK).
    "bruno": {"T_CROSS": lambda t, P: (t[0], P(lean=16, fa=(92, 0), ba=(-58, 42), fl=(40, 18), bl=(-32, 14),
                                             glow="hand"), t[2]),
              "WIN": lambda t, P: [dict(t[0], fa=(106, 70), fl=(20, 22), bl=(-18, 22)),
                                   dict(t[1], fa=(110, 62), fl=(20, 22), bl=(-18, 22))],
              "T_GRAB": lambda t, P: (t[0], t[1], dict(t[2], fa=(104, 44), ba=(92, 56))),
              "JUMP": lambda t, P: [t[0], dict(t[1], fl=(50, 82), bl=(-14, 68)), t[2], dict(t[3], fl=(52, 88), bl=(10, 88))],
              # his guard sits below the chin: a gauntlet raised any higher hides his whole face
              "BLOCK": lambda t, P: dict(t, **LOW_GUARD),
              "BLOCK_C": lambda t, P: dict(t, **LOW_GUARD),
              # he is nearly as long as the cell is wide, so he lies with his knees drawn further up
              "LYING": lambda t, P: dict(t, fa=(20, 34), fl=(70, 124), bl=(44, 86)),
              "KO": lambda t, P: dict(t, fl=(60, 104), bl=(42, 80)),
              "FALL": lambda t, P: dict(t, fa=(72, 56), fl=(68, 80), bl=(34, 84)),
              "THROWN": lambda t, P: dict(t, fl=(66, 96), bl=(34, 76)),
              # heavy kick: the gauntlet comes up to the chest so it does not cover the kicking leg
              "T_HK": lambda t, P: (t[0], dict(t[1], lean=-20, fl=(108, 0), fa=(60, 110), ba=(-24, 56)), t[2]),
              # super wind-up: the back foot stays planted behind him instead of hanging in the air
              "T_SUPER": lambda t, P: (dict(t[0], bl=(-30, 10)), t[1], t[2])},
    # Rook's guard is lowered the same way so the visor slit stays visible.
    # In full plate he is also too long for the cell with his legs out, so he falls and lies with them drawn up.
    "rook": {"FALL": lambda t, P: dict(t, fa=(70, 52), fl=(70, 86), bl=(36, 88)),
             "LYING": lambda t, P: dict(t, fl=(70, 124), bl=(44, 86)),
             "BLOCK": lambda t, P: dict(t, **LOW_GUARD),
             "BLOCK_C": lambda t, P: dict(t, **LOW_GUARD)},
    # Ilse holds her orb up at shoulder height rather than overhead, and wards with her palms held out in
    # front of her (the shared guard would put an open hand flat over her face).
    # and her super leans in less, so the cast orb and the flying coat tails both stay in the cell.
    "ilse": {"WIN": lambda t, P: [dict(t[0], fa=(86, 40)), dict(t[1], fa=(88, 46))],
             "BLOCK": lambda t, P: dict(t, fa=(68, 66), ba=(52, 78)),
             "BLOCK_C": lambda t, P: dict(t, fa=(68, 66), ba=(52, 78)),
             "T_SUPER": lambda t, P: (t[0], dict(t[1], lean=10, fl=(44, 22), bl=(-40, 6)), t[2]),
             # the orb rides over her front palm, so in the heavy kick and the slide kick that hand comes up
             # to chest / head height instead of hanging beside the kicking leg
             "T_HK": lambda t, P: (t[0], dict(t[1], fa=(62, 72)), t[2]),
             "T_SWEEP": lambda t, P: (t[0], dict(t[1], fa=(88, 70)), t[2])},
}

LOW_GUARD = dict(fa=(66, 84), ba=(56, 92))

# How far (1x units) a fighter's hips sink below the shared walk cycle, feet staying where the cycle puts them.
WALK_SINK = {"bruno": 4}

# Cloth / hair response per move phase (startup, active, recovery): (flow, lift).
MOVE_CLOTH = {
    "T_JAB": ((0.1, 0), (0.4, 0), (0.2, 0)),
    "T_CROSS": ((0.0, 0), (0.7, 0), (0.4, 0)),
    "T_LK": ((0.1, 0), (0.4, 0), (0.2, 0)),
    "T_HK": ((0.2, 0), (0.6, 0), (0.3, 0)),
    "T_PUSH": ((0.0, 0), (0.85, 0), (0.4, 0)),
    "T_UPPER": ((0.0, 0.2), (0.2, -0.6), (0.0, 0.4)),
    "T_RUSHK": ((0.3, 0), (1.0, 0), (0.5, 0)),
    "T_RUSHP": ((0.3, 0), (1.0, 0), (0.5, 0)),
    "T_GUARD": ((0.0, 0), (0.2, 0.2), (0.1, 0)),
    "T_SWEEP": ((0.2, 0), (0.6, 0), (0.3, 0)),
    "T_GRAB": ((0.1, 0), (0.4, 0), (-0.3, 0)),
    "T_SUPER": ((-0.2, 0.5), (0.7, 0), (0.4, 0)),
}


def move_template(move):
    """Name of the pose template a move's three frames are drawn from."""
    mid = move["id"]
    inp = move.get("input", {})
    button = inp.get("button", "")
    motion = inp.get("motion", "")
    if inp.get("stance") == "throw" or "+" in button:
        return "T_GRAB"
    if mid.startswith("super"):
        return "T_SUPER"
    if "projectile" in move:
        return "T_PUSH"
    if motion == "623":
        return "T_UPPER"
    if move.get("guard") == "throw" and move.get("unblockable"):
        return "T_GRAB"
    if motion == "214" and "P" in button:
        return "T_GUARD"
    if motion == "214":
        return "T_SWEEP"
    if motion == "236":
        return "T_RUSHK" if "K" in button else "T_RUSHP"
    return {"LP": "T_JAB", "HP": "T_CROSS", "LK": "T_LK", "HK": "T_HK"}.get(button, "T_JAB")


# ---------------------------------------------------------------- frames


def frame_specs(fid, fighter):
    """Ordered list of (frame name, pose, frame context) for a fighter's sheet; projectiles excluded."""
    T = pose_tables(fid)
    out = []

    def frame(name, pose, **ctx):
        out.append((name, pose, ctx))

    for i, p in enumerate(T["IDLE"]):
        frame(f"idle_{i}", p, plant=T["IDLE"][0], sway=i * math.pi / 2)
    for i, p in enumerate(T["WALK"]):
        frame(f"walk_{i}", dict(p, hy=WALK_SINK.get(fid, 0)), plant=p, flow=0.25, sway=i * math.pi / 3)
    frame("crouch_0", T["CROUCH"], plant=T["CROUCH_REF"])
    # rising: cloth and hair are left behind and below; apex: level; falling: they lift
    for i, cloth in enumerate((dict(), dict(lift=-0.5, trail=134), dict(flow=0.15), dict(lift=0.55))):
        frame(f"jump_{i}", T["JUMP"][i], **cloth)
    frame("land_0", T["LAND"], plant=T["CROUCH_REF"], lift=0.35, curl=-0.6)
    frame("block_0", T["BLOCK"], flow=-0.2)
    frame("block_1", T["BLOCK_C"], plant=T["CROUCH_REF"], flow=-0.2)
    for i, p in enumerate(T["HIT"]):
        frame(f"hit_{i}", p, flow=-0.5 - 0.2 * i, expr="hurt", focus=False)
    frame("down_0", T["FALL"], spin=-48, hang=102, expr="hurt", focus=False)
    frame("down_1", T["LYING"], spin=-90, lying=True, expr="hurt", focus=False)
    frame("getup_0", T["GETUP"], focus=False)
    frame("ko_0", T["KO"], spin=-90, lying=True, expr="out", focus=False)
    for i, p in enumerate(T["WIN"]):
        frame(f"win_{i}", p, sway=i * math.pi)
    frame("throw_0", T["GRAB"], flow=0.3, focus=False)
    frame("thrown_0", T["THROWN"], spin=-78, hang=94, expr="hurt", focus=False)
    # legacy name some move entries still reference
    frame("stance_1", T["IDLE"][2], plant=T["IDLE"][0], sway=math.pi)
    for move in fighter["moves"]:
        name = move_template(move)
        start, active, recovery = T[name]
        cloth = MOVE_CLOTH[name]
        focus = name != "T_GRAB"
        for i, p in enumerate((start, active, lerp_pose(active, recovery, 0.6))):
            frame(f"{move['id']}_{i}", p, flow=cloth[i][0], lift=cloth[i][1], focus=focus)
    return out


def fit_figure(fig, grounded):
    """Keep a posed figure inside its cell by moving it, never by scaling it: sideways as far as it
    pokes out, and (airborne or lying figures only) down or up. Returns (figure, dx, dy, overflow):
    overflow is how many texels still stick out because the figure is larger than the cell."""
    x0, x1, y0, y1 = rs.figure_bounds(fig)
    lo, hi = MARGIN, CELL - MARGIN
    dx = dy = 0.0
    if x1 - x0 <= hi - lo:
        dx = lo - x0 if x0 < lo else (hi - x1 if x1 > hi else 0.0)
    else:
        dx = (lo + hi) / 2 - (x0 + x1) / 2
    if not grounded:
        if y1 - y0 <= hi - lo:
            dy = lo - y0 if y0 < lo else (hi - y1 if y1 > hi else 0.0)
        else:
            dy = hi - y1
    # a grounded figure's soles are pinned to the anchor line by construction: only its top can overflow
    overflow = max(0.0, lo - (x0 + dx), (x1 + dx) - hi, lo - (y0 + dy), 0.0 if grounded else (y1 + dy) - hi)
    overflow = overflow if overflow > 1e-6 else 0.0
    if dx or dy:
        fig = rs.transform_figure(fig, lambda x, y: (x + dx, y + dy))
    return fig, dx, dy, overflow


def frames_for(fid, fighter, p2=False):
    """Ordered list of (name, Figure, fit) where fit = (dx, dy, overflow) from fit_figure."""
    frames = []
    for name, pose, ctx in frame_specs(fid, fighter):
        fig = designs.build_figure(fid, pose, p2, ctx)
        grounded = pose["hy"] >= designs.AIR_HY and not ctx.get("spin")
        fig, dx, dy, overflow = fit_figure(fig, grounded)
        frames.append((name, fig, (dx, dy, overflow)))
    for i in range(2):
        frames.append((f"proj_{i}", designs.projectile(fid, p2, i), (0.0, 0.0, 0.0)))
    return frames


def render_frame(name, fig):
    return rs.render(fig, outlined=not name.startswith("proj_"))


# ---------------------------------------------------------------- sheet assembly


def bundle_dir(root, fid):
    return os.path.join(root, "Content", "Fighters", fid, f"{fid}.contentbundle")


def load_fighter(root, fid):
    with open(os.path.join(bundle_dir(root, fid), "fighter.json")) as f:
        return json.load(f)


def generate(root, fid):
    """Writes the main sheet, the `<id>_alt.png` costume, and sheet.json; returns PNG sizes."""
    bundle = bundle_dir(root, fid)
    fighter = load_fighter(root, fid)
    sheet_name = fighter["spriteSheet"]
    alt_name = sheet_name[:-4] + "_alt.png"
    size = 0
    for p2, name in ((False, sheet_name), (True, alt_name)):
        n, W, Hh, png_len, meta = _generate_sheet(bundle, fid, fighter, p2, name)
        size += png_len
    with open(os.path.join(bundle, fighter["sheetMeta"]), "w") as f:
        f.write(json.dumps({"texelScale": K, "frames": meta}, indent=2) + "\n")
    return fid, n, W, Hh, size


def _generate_sheet(bundle, fid, fighter, p2, png_name):
    frames = frames_for(fid, fighter, p2)
    rows_n = (len(frames) + COLS - 1) // COLS
    W, Hh = COLS * CELL, rows_n * CELL
    # transparent texels carry the outline colour so bilinear filtering never bleeds black
    sheet = bytearray(bytes(rs.OUTLINE) + b"\x00") * (W * Hh)
    meta = []
    for i, (name, fig, _) in enumerate(frames):
        ox, oy = (i % COLS) * CELL, (i // COLS) * CELL
        px = render_frame(name, fig)
        for y in range(CELL):
            o = ((oy + y) * W + ox) * 4
            sheet[o:o + CELL * 4] = px[y * CELL * 4:(y + 1) * CELL * 4]
        anchor_y = CELL // 2 if name.startswith("proj_") else ANCHOR_Y
        meta.append(dict(name=name, x=ox, y=oy, w=CELL, h=CELL, anchorX=ANCHOR_X, anchorY=anchor_y))
    rows = [sheet[y * W * 4:(y + 1) * W * 4] for y in range(Hh)]
    png = rs.png_bytes(W, Hh, rows, 6)
    with open(os.path.join(bundle, png_name), "wb") as f:
        f.write(png)
    return len(frames), W, Hh, len(png), meta


def repo_root():
    return os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


if __name__ == "__main__":
    root = sys.argv[1] if len(sys.argv) > 1 else repo_root()
    with ProcessPoolExecutor(max_workers=len(FIGHTERS)) as pool:
        futures = [pool.submit(generate, root, fid) for fid in FIGHTERS]
        total = 0
        for fut in futures:   # submission order keeps the log deterministic
            fid, n, w, h, size = fut.result()
            total += size
            print(f"{fid}: {n} frames, {w}x{h}, {size / 1024:.0f} KiB")
        print(f"total {total / 1024 / 1024:.2f} MiB")
