"""The four shipped fighters, drawn as anime-style cel figures on the shared skeleton.

`build_figure(fighter_id, pose, p2, ctx)` poses the fighter's rig and returns a raster.Figure with
the soles of a grounded pose on the anchor line. Every fighter is drawn at one fixed scale: nothing
here shrinks a figure to fit, so a fighter never changes size between frames.

Pose: the skeleton dict from gen_fighters (hx, hy, lean, head, fa, ba, fl, bl, glow, fist).
Frame context `ctx` (all optional):
  flow   -1..1  how hard cloth and hair trail behind the fighter (0 hangs at rest, <0 swings forward)
  lift   -1..1  cloth rising (+, falling body) or pulled straight down (-, rising body)
  sway   radians, phase of the idle ripple along scarf / cape / braid
  spin   degrees (screen clockwise) the finished figure is rotated about its hips: tumbling and falling
  lying  True for a figure spun onto its back: it rests on its body, and cloth runs along the ground
  expr   "neutral" | "hurt" (eyes shut, mouth open) | "out" (eyes shut)
  focus  False drops held effects (Ilse's orb) for frames where the fighter is not in control
  hang   screen heading (degrees: 90 = straight down) every piece of cloth takes on a spun figure, so it
         hangs or trails in the finished frame instead of turning with the body
  trail  cloth trails at least this far back (heading in degrees; 90 down, 180 straight behind): a rising body
  curl   -1..1 how the braid bends along its length (+ whips upward, - arcs back down); default follows lift
  flat   True for a lying figure seen as one line along the ground: both shoulders and both hips sit on the
         ground side of the body (so an arm lies beside it instead of across the chest) and the soles are
         put flat on the ground
  plant  a reference pose: both feet stay where that pose puts them and the legs are re-solved, so
         the hips can bob without the feet sliding (idle breathing)
"""
import math

import facekit as fk
import raster as rs
from raster import ANCHOR_X as AX, ANCHOR_Y as AY, K, Cel

INNER = rs.INNER_W
AIR_HY = -3                     # pose["hy"] below this is airborne: the feet are not put on the ground
LIE_GAP = 2 * K                 # a lying figure rests this far above the anchor line
CAST_GLOW = ("hand", True)      # pose["glow"] values that light the hands ("foot" lights the kicking foot)
OUTLINE = rs.OUTLINE
FIGHTERS = ("kestrel", "bruno", "ilse", "rook")
CTX = dict(flow=0.0, lift=0.0, sway=0.0, spin=0.0, lying=False, expr="neutral", focus=True, plant=None,
           hang=None, trail=None, curl=None, flat=False)


def M(base, shadow, hi=None, **kw):
    return Cel(base, shadow, hi, **kw)


# ------------------------------------------------------------------ small helpers
def add(a, b):
    return (a[0] + b[0], a[1] + b[1])


def sc(a, k):
    return (a[0] * k, a[1] * k)


def vec2(theta_deg, length):
    """Screen vector: 0 = facing (+x), 90 = down, 180 = behind."""
    t = math.radians(theta_deg)
    return (math.cos(t) * length, math.sin(t) * length)


def lerp(a, b, t):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


def cap(fig, a, b, ra, rb, mat, layer, bias=0.0, ol=None, flat=None):
    fig.cap(a, b, ra, rb, mat, layer, bias, INNER if ol is None else ol, flat)


def disc(fig, c, r, mat, layer, bias=0.0, ol=None, flat=None):
    fig.disc(c, r, mat, layer, bias, INNER if ol is None else ol, flat)


def quad(fig, pts, mat, layer, ax0, ax1, hw, bias=0.0, ol=None):
    fig.quad(pts, mat, layer, ax0, ax1, hw, bias, INNER if ol is None else ol)


def chain(fig, pts, w0, w1, mat, layer, bias=0.0, ol=None, flat=None):
    n = len(pts) - 1
    for i in range(n):
        cap(fig, pts[i], pts[i + 1], w0 + (w1 - w0) * i / n, w0 + (w1 - w0) * (i + 1) / n,
            mat, layer, bias, ol, flat)


def ribbon(fig, pts, w0, w1, mat, layer, hi=True):
    """Flat cloth strip: shadow tone full width, lit tone offset toward the light, crisp highlight line."""
    m = fig.mats[mat]
    n = len(pts) - 1
    wid = [w0 + (w1 - w0) * i / n for i in range(n + 1)]
    chain(fig, pts, w0, w1, None, layer, ol=INNER, flat=m.shadow)
    lx, ly = fk.lv((-0.30, -0.32))
    lit = [(p[0] + lx * w, p[1] + ly * w) for p, w in zip(pts, wid)]
    chain(fig, lit, w0 * 0.64, w1 * 0.64, None, layer + 0.001, ol=0, flat=m.base)
    if hi and m.hi:
        hx_, hy_ = fk.lv((-0.46, -0.5))
        hl = [(p[0] + hx_ * w, p[1] + hy_ * w) for p, w in zip(pts, wid)]
        chain(fig, hl[:-1], w0 * 0.12, w1 * 0.12, None, layer + 0.002, ol=0, flat=m.hi)


def wave(start, theta, length, n, amp, waves, phase=0.0, droop=0.0):
    """Polyline flowing from `start` heading theta (screen degrees, y down), swaying by amp deg."""
    pts = [start]
    p = start
    for i in range(n):
        t = (i + 0.5) / n
        th = theta + amp * math.sin(2 * math.pi * waves * t + phase) + droop * t
        p = add(p, vec2(th, length / n))
        pts.append(p)
    return pts


def cloth_theta(R, rest, flow_gain, lift_gain=50.0, lo=70.0):
    """Heading (screen degrees, before any spin) for cloth trailing from the body: `rest` at flow 0, swinging
    back and up by flow_gain at full flow and by lift_gain at full lift. A lying figure's cloth runs along the
    body; a spun (tumbling) figure's cloth simply turns with it, which lands close to hanging straight down.
    `lo` stops cloth that hangs down the back from swinging forward through the body."""
    c = R["ctx"]
    if c["lying"]:
        return 95.0
    if c["hang"] is not None:
        return c["hang"] - c["spin"] + (rest - 104.0) * 0.12
    th = max(lo, min(262.0, rest + c["flow"] * flow_gain + c["lift"] * lift_gain))
    if c["trail"] is not None:
        th = max(th, c["trail"] + (rest - 104.0) * 0.12)
    return th


def settle(R, pts, pad=0.0):
    """Keep trailing cloth off the floor: points that would sink below the ground line slide back along it."""
    if R["floor"] is None:
        return pts
    top = R["floor"] - pad
    return [(x - (y - top) * 0.7, top) if y > top else (x, y) for x, y in pts]


def open_hand(fig, hand, fd, hs, mat, layer, shift, ol=INNER, bend=-58.0):
    """Open palm thrust: the hand bends back at the wrist so the fingers point up and the palm faces forward.
    Four separate fingers of uneven length fan out of the palm block and the thumb stands off its lower edge,
    so the silhouette reads as a hand rather than a mitten. Returns the palm centre."""
    d = fk.rot(fd, bend)
    n = (-d[1], d[0])
    L = lambda a_, b_: (hand[0] + (d[0] * a_ + n[0] * b_) * hs, hand[1] + (d[1] * a_ + n[1] * b_) * hs)
    fo = min(ol, 1.1)
    # thumb: two joints angled away from the palm
    Th = fk.tube([L(0.2, 1.6), L(1.9, 4.3), L(4.3, 5.5)], [(0, 1.5 * hs), (0.6, 1.25 * hs), (1.0, 0.95 * hs)], n=4)
    fk.tube_draw(fig, Th, mat, layer, k=0.36, ol=ol)
    # fingers, far one first; each keeps its own contour so the gaps between them show
    for i, (b0, b1, tip) in enumerate(((-2.45, -3.5, 8.3), (-0.85, -1.25, 9.9), (0.75, 0.95, 9.6), (2.2, 3.0, 8.0))):
        F = fk.tube([L(3.6, b0), L(6.4, (b0 + b1) / 2), L(tip, b1)], [(0, 1.0 * hs), (0.7, 0.92 * hs), (1.0, 0.72 * hs)], n=4)
        fk.tube_draw(fig, F, mat, layer + 0.004 + i * 0.001, k=0.34, ol=fo)
    palm = fk.smooth([L(-1.4, -2.6), L(1.6, -3.4), L(4.4, -3.5), L(5.2, -1.8), L(5.4, 0.2), L(5.2, 2.0), L(4.4, 3.2),
                      L(2.0, 3.1), L(-1.2, 2.6)], 4, True)
    fk.cel_shape(fig, palm, mat, layer + 0.01, ol=fo, shift=shift)
    # crease under the knuckles
    fk.stroke(fig, [L(4.5, -2.6), L(4.9, 0.2), L(4.5, 2.6)], 0.5, 0.5, fk.linec(mat), layer + 0.02)
    return L(2.6, 0.0)


# ------------------------------------------------------------------ rig
def solve_leg(hip, ankle, thigh, shin):
    """(thigh angle, knee bend) that puts the ankle on a target with the knee pointing forward."""
    dx, dy = ankle[0] - hip[0], ankle[1] - hip[1]
    d = min(math.hypot(dx, dy), (thigh + shin) * 0.999999)
    reach = math.degrees(math.atan2(dx, dy))
    ta = reach + math.degrees(math.acos(max(-1.0, min(1.0, (thigh * thigh + d * d - shin * shin) / (2 * thigh * d)))))
    knee = add(hip, rs.vec(ta, thigh))
    return ta, ta - math.degrees(math.atan2(ankle[0] - knee[0], ankle[1] - knee[1]))


def make_rig(ch, pose, ctx):
    """Joint positions for a pose. Design keys: height, build, head (radius), torso / leg / arm_len
    (length factors), thigh / shin / upper / fore (segment lengths), neck_len, head_fwd, chest, waist,
    limb, sh_off (front, back shoulder x offsets) or sh_tw (shoulders placed on the torso frame), hip_off,
    sole (ankle-to-ground height of the shoe)."""
    s = ch["height"] / 94.0 * K
    b = ch["build"]
    R = dict(s=s, b=b, pose=pose, ctx=ctx, grounded=pose["hy"] >= AIR_HY and not ctx["spin"])
    thigh, shin = ch.get("thigh", 21) * s * ch.get("leg", 1.0), ch.get("shin", 20) * s * ch.get("leg", 1.0)
    upper, fore = ch.get("upper", 15) * s * ch.get("arm_len", 1.0), ch.get("fore", 14) * s * ch.get("arm_len", 1.0)
    torso_len = 31 * s * ch.get("torso", 1.0)
    head_r = ch["head"] * s
    limb_r = 5.4 * b * s * ch.get("limb", 1.0)
    stand_hip = thigh + shin - 2 * K
    hip = (AX + pose["hx"] * K, AY - stand_hip + pose["hy"] * K)
    lean = pose["lean"]
    cd = rs.vec(180 - lean, 1)
    neck_pt = add(hip, sc(cd, torso_len))
    shoulder = add(hip, sc(cd, torso_len * 0.86))
    tilt = lean + pose["head"]
    head_c = add(neck_pt, rs.vec(180 - tilt, ch.get("neck_len", 2.5) * s + head_r))
    head_c = add(head_c, (ch.get("head_fwd", 0.0) * s, 0))
    R.update(thigh=thigh, shin=shin, upper=upper, fore=fore, torso_len=torso_len, hr=head_r,
             limb_r=limb_r, hip=hip, neck=neck_pt, shoulder=shoulder, tilt=tilt, hc=head_c, cd=cd,
             chest_w=13.5 * b * s * ch.get("chest", 1.0), waist_w=9.5 * b * s * ch.get("waist", 1.0))
    px, py = -cd[1], cd[0]
    R["perp"] = (px, py)

    def tp(t, w):
        """Point at fraction t along hip->neck and signed width w across the torso."""
        return (hip[0] + (neck_pt[0] - hip[0]) * t + px * w, hip[1] + (neck_pt[1] - hip[1]) * t + py * w)

    R["tp"] = tp
    if "sh_tw" in ch:
        (tf, wf), (tb, wb) = ch["sh_tw"]
        R["sh_f"], R["sh_b"] = tp(tf, wf * s), tp(tb, wb * s)
    else:
        so = ch.get("sh_off", (5.0 * b, -6.0 * b))
        R["sh_f"], R["sh_b"] = add(shoulder, (so[0] * s, 0)), add(shoulder, (so[1] * s, 0))
    ho = ch.get("hip_off", 4.5 * b)
    R["hip_f"] = add(hip, (ho * s, 0))
    R["hip_b"] = add(hip, (-ho * s, 0))
    if ctx["flat"]:
        R["sh_f"], R["sh_b"] = tp(0.87, -9.0 * s), tp(0.86, -7.0 * s)      # rig side "b" is the near arm
        R["hip_f"], R["hip_b"] = add(hip, (-3.0 * s, 0)), add(hip, (-5.0 * s, 0))
    for side, sh, spec in (("f", R["sh_f"], pose["fa"]), ("b", R["sh_b"], pose["ba"])):
        elbow = add(sh, rs.vec(spec[0], upper))
        hand = add(elbow, rs.vec(spec[0] + spec[1], fore))
        R["elbow_" + side], R["hand_" + side] = elbow, hand
    legs = {"f": pose["fl"], "b": pose["bl"]}
    if ctx["plant"] is not None:
        ref = make_rig(ch, ctx["plant"], dict(ctx, plant=None))
        legs = {side: solve_leg(R["hip_" + side], ref["ankle_" + side], thigh, shin) for side in "fb"}
    R["legs"] = legs
    for side, hp, spec in (("f", R["hip_f"], legs["f"]), ("b", R["hip_b"], legs["b"])):
        knee = add(hp, rs.vec(spec[0], thigh))
        ankle = add(knee, rs.vec(spec[0] - spec[1], shin))
        toe = add(ankle, rs.vec(spec[0] - spec[1] + 80, 6.5 * s))
        R["knee_" + side], R["ankle_" + side], R["toe_" + side] = knee, ankle, toe
    # approximate ground line under a standing figure, for cloth that would otherwise hang through it
    R["floor"] = max(R["ankle_f"][1], R["ankle_b"][1]) + ch["sole"] * s if R["grounded"] else None
    return R


# ------------------------------------------------------------------ KESTREL: ice-scarf striker
KESTREL = dict(
    height=85, build=1.0, head=9.5, chest=1.0, torso=1.10, thigh=21.0, shin=20.0, upper=15.0, fore=14.0,
    sh_off=(7.0, -9.1), hip_off=3.1, sole=7.4,
    mats={
        "skin": M((236, 180, 140), (192, 120, 106), (252, 214, 182)),
        "bskin": M((242, 190, 150), (200, 120, 104), shadow_t=0.40),
        "hair": M((218, 232, 255), (140, 170, 236), (255, 255, 255), hi_t=0.9),
        "gi": M((48, 120, 232), (30, 66, 170), shadow_t=0.38),
        "wrap": M((246, 238, 218), (190, 172, 148), shadow_t=0.38),
        "scarf": M((44, 200, 214), (18, 124, 160), (176, 248, 252), hi_t=0.9),
        "pants": M((50, 64, 150), (30, 34, 100), shadow_t=0.38),
        "sash": M((232, 240, 252), (150, 166, 204), (255, 255, 255)),
        "shoe": M((244, 240, 232), (170, 164, 172), shadow_t=0.34),
        "sole": M((44, 38, 62), (24, 20, 38), (96, 90, 130)),
        "trim": M((44, 200, 214), (18, 124, 160), (176, 248, 252)),
    },
    mats2={
        "gi": M((232, 52, 64), (150, 24, 56), shadow_t=0.38),
        "hair": M((84, 60, 160), (46, 32, 104), (170, 140, 250), hi_t=0.96),
        "scarf": M((252, 184, 40), (190, 112, 10), (255, 236, 150), hi_t=0.9),
        "sash": M((246, 232, 210), (176, 150, 130), (255, 250, 236)),
        "trim": M((252, 184, 40), (190, 112, 10), (255, 236, 150)),
        "pants": M((96, 70, 150), (58, 40, 104), shadow_t=0.38),
        "shoe": M((236, 228, 208), (168, 158, 150), shadow_t=0.34),
        "sole": M((252, 184, 40), (190, 112, 10), (255, 236, 150)),
    },
    face=dict(skin="skin", iris=(60, 206, 232), iris_lo=(18, 96, 150), lowerlid=(196, 124, 108),
              browmat=(70, 80, 124), mouth="smile", eh=1.12, lash=False, brow_gap=0.37, brow_lay=5.3, brow=0.12, brow_w=0.06,
              blush=(246, 130, 120)),
    face2=dict(iris=(246, 176, 56), iris_lo=(150, 70, 20), browmat=(44, 40, 70)),
    glow=(28, 170, 200), glow_hi=(120, 240, 255), glow2=(230, 110, 20), glow2_hi=(255, 214, 96),
)


def kestrel_leg(fig, R, side, layer):
    """Fitted trousers over an athletic leg (shaped thigh, knee, calf), shin wraps, low trainer."""
    u = R["s"]
    back = side == "b"
    hp, knee, ankle = R["hip_" + side], R["knee_" + side], R["ankle_" + side]
    pants, wrap, shoe, sole, trim = fig.mats["pants"], fig.mats["wrap"], fig.mats["shoe"], fig.mats["sole"], fig.mats["trim"]
    if back:
        pants, wrap, shoe, sole, trim = (fk.far(pants, 0.5), fk.far(wrap, 0.5), fk.far(shoe, 0.5), fk.far(sole, 0.4),
                                         fk.far(trim, 0.5))
    T = fk.tube([hp, knee, ankle], [(0, 6.0 * u), (0.20, 5.9 * u), (0.46, 4.1 * u), (0.55, 3.9 * u), (0.70, 4.3 * u),
                                    (1.0, 2.6 * u)], n=8)
    fk.tube_draw(fig, T, pants, layer, k=0.40, ol=INNER)
    # side stripe down the thigh, knee crease
    m_ = len(T["C"])
    st = [fk.offs(T["C"][j], T["N"][j], -T["W"][j] * 0.30 * T["shade_side"]) for j in range(1, int(m_ * 0.56))]
    fk.stroke(fig, st, 0.9, 0.8, trim.base, layer + 0.01)
    # shin wraps
    w0 = lerp(knee, ankle, 0.52)
    W = fk.tube([w0, ankle], [(0, 4.1 * u), (0.4, 3.7 * u), (1.0, 2.8 * u)], n=4, caps=(False, False))
    sd = fk.unit(knee, ankle)
    sn = (-sd[1], sd[0])
    # trainer
    L = fk.foot_frame(R, side, 1.26)
    pts = [L(-3.0, 0.6), L(-3.5, 3.6), L(-3.2, 5.7), L(-0.6, 5.9), L(3.0, 5.4), L(8.0, 5.6), L(11.4, 5.3), L(12.8, 4.2),
           L(12.2, 3.0), L(9.8, 1.9), L(6.4, 0.6), L(3.8, -1.6), L(2.8, -2.8), L(-2.6, -2.8)]
    poly = fk.smooth(pts, 4, True, corners=(2, 3, 7, 12, 13))
    fk.cel_shape(fig, poly, shoe, layer + 0.12, ol=INNER, shift=(1.0, 1.4))
    fk.fillp(fig, [L(8.6, -1), L(14, -1), L(14, 7), L(9.4, 7)], trim.base, layer + 0.123, clip=poly)
    fk.fillp(fig, [L(10.4, 3.6), L(14, 3.2), L(14, 7), L(9.4, 7)], trim.shadow, layer + 0.124, clip=poly)
    fk.fillp(fig, [L(-4.4, 4.5), L(14, 4.3), L(14, 7), L(-4.4, 7)], sole.base, layer + 0.125, clip=poly)
    fk.stroke(fig, [L(1.2, 3.9), L(4.6, 0.4)], 0.6, 0.6, trim.base, layer + 0.126)
    fk.ground(R, poly)
    fk.tube_draw(fig, W, wrap, layer + 0.2, k=0.38, ol=1.1)
    for t, r in ((0.33, 3.6), (0.70, 3.1)):
        c = lerp(w0, ankle, t)
        fk.stroke(fig, [fk.offs(fk.offs(c, sn, r * u), sd, -0.6 * u), fk.offs(fk.offs(c, sn, -r * u), sd, 0.6 * u)], 0.5, 0.5,
                  fk.linec(wrap), layer + 0.22)


def kestrel_arm(fig, R, side, layer):
    """Bare athletic arm (one tapered tube), wrapped forearm, wrapped fist (or open palm)."""
    u = R["s"]
    back = side == "b"
    sh, elbow, hand = R["sh_" + side], R["elbow_" + side], R["hand_" + side]
    skin, wrap = fig.mats["bskin"], fig.mats["wrap"]
    if back:
        skin, wrap = fk.far(skin, 0.55), fk.far(wrap, 0.5)
    T = fk.tube([sh, elbow, hand], [(0, 4.5 * u), (0.16, 4.7 * u), (0.42, 3.5 * u), (0.50, 3.3 * u), (0.62, 3.9 * u),
                                    (0.85, 3.2 * u), (1.0, 3.0 * u)], n=8, caps=(True, False))
    fk.tube_draw(fig, T, skin, layer, k=0.36, ol=INNER)
    fd = fk.unit(elbow, hand)
    nn = (-fd[1], fd[0])
    ud = fk.unit(sh, elbow)
    un = (-ud[1], ud[0])
    # deltoid / biceps separation
    fk.stroke(fig, [fk.offs(fk.offs(sh, ud, 5.2 * u), un, -3.2 * u * T["shade_side"]), fk.offs(fk.offs(sh, ud, 6.6 * u), un, 0.2 * u)],
              0.7, 0.4, skin.shadow, layer + 0.01)
    # forearm wrap
    w0 = lerp(elbow, hand, 0.30)
    W = fk.tube([w0, hand], [(0, 3.85 * u), (1.0, 3.3 * u)], n=4, caps=(False, False))
    fk.tube_draw(fig, W, wrap, layer + 0.1, k=0.36, ol=1.1)
    for t, r in ((0.30, 3.6), (0.66, 3.3)):
        c = lerp(w0, hand, t)
        fk.stroke(fig, [fk.offs(fk.offs(c, nn, r * u), fd, -0.7 * u), fk.offs(fk.offs(c, nn, -r * u), fd, 0.7 * u)], 0.5, 0.5,
                  fk.linec(wrap), layer + 0.12)
    hs = 1.34 * u
    if not R["pose"]["fist"]:
        open_hand(fig, hand, fd, hs, wrap, layer + 0.5, shift=(0.5 * u, 0.6 * u))
        return
    # fist: rounded block, knuckles forward, thumb folded across
    L = lambda a_, b_: (hand[0] + (fd[0] * a_ + nn[0] * b_) * hs, hand[1] + (fd[1] * a_ + nn[1] * b_) * hs)
    fist = fk.smooth([L(-1.0, -2.5), L(1.6, -3.3), L(4.6, -3.2), L(5.9, -1.9), L(6.0, 1.5), L(4.8, 3.1), L(1.4, 3.2),
                      L(-1.0, 2.5)], 4, True)
    fk.cel_shape(fig, fist, wrap, layer + 0.5, ol=INNER, shift=(1.0 * u * 0.5, 1.2 * u * 0.5))
    for v in (-1.0, 1.0):
        fk.stroke(fig, [L(5.7, v), L(4.2, v)], 0.6, 0.4, fk.linec(wrap), layer + 0.52)
    fk.stroke(fig, [L(1.2, -3.1), L(1.5, 3.0)], 0.55, 0.55, fk.linec(wrap), layer + 0.52)


def kestrel_scarf(fig, R):
    """Two long scarf tails streaming from the back of the neck; flow whips them back and shortens the sag."""
    s = R["s"]
    N = R["neck"]
    flow, sway = R["ctx"]["flow"], R["ctx"]["sway"]
    for L, w, ph, off in ((96 * s / 2, 7.6 * s / 2, 0.0, 0), (70 * s / 2, 6.4 * s / 2, 1.3, 8)):
        start = add(N, (-4.5 * s, 1.0 * s + off * 0.4))
        if R["ctx"]["lying"]:
            pts = wave(start, cloth_theta(R, 150, 44) + off * 0.5, L * 0.62, 9, 5, 1.25, ph)
        else:
            pts = wave(start, cloth_theta(R, 150, 44) + off, L * (1 - 0.18 * flow), 9, 11, 1.25, ph + sway,
                       droop=-flow * 6 - 26 * (1 - flow))
        ribbon(fig, settle(R, pts, w), w, w * 0.3, "scarf", 2.5)


def kestrel_body(fig, R):
    s, tp = R["s"], R["tp"]
    u = s
    T = lambda t, w: tp(t, w * u)
    skin, gi, sash, pants, scarf = fig.mats["bskin"], fig.mats["gi"], fig.mats["sash"], fig.mats["pants"], fig.mats["scarf"]
    kestrel_arm(fig, R, "b", 1.0)
    kestrel_leg(fig, R, "b", 1)
    # torso silhouette: hips, tucked waist, rib cage, chest, shoulder slope
    tbl = [(-0.04, 5.6, 6.2), (0.10, 5.0, 5.4), (0.27, 4.3, 4.5), (0.44, 5.6, 5.0), (0.60, 7.3, 5.8),
           (0.74, 7.7, 6.5), (0.87, 6.3, 6.7), (0.96, 4.4, 5.2), (1.01, 3.0, 3.6)]
    fr = [T(t, f) for t, f, b in tbl]
    bk = [T(t, -b) for t, f, b in tbl]
    tor = fk.smooth(fr + bk[::-1], 4, True, corners=(0, len(fr) - 1, len(fr), 2 * len(fr) - 1))
    fk.cel_shape(fig, tor, skin, 3.0, ol=INNER, shift=(1.6, 1.2))
    # abs
    fk.stroke(fig, [T(0.16, 1.6), T(0.36, 2.0)], 0.5, 0.4, skin.shadow, 3.02)
    # sleeveless gi top: cropped hem rising toward the back, V neck
    top = fk.smooth([T(0.40, 8.5), T(0.44, 2.0), T(0.50, -7.5), T(1.1, -9), T(1.1, 9)], 4, True, corners=(0, 2, 3, 4))
    fk.fillp(fig, top, gi.shadow, 3.05, clip=tor)
    gx, gy = fk.lv((-2.0, -1.6))
    fk.fillp(fig, [(x + gx, y + gy) for x, y in tor], gi.base, 3.051, clip=top)
    fk.fillp(fig, fk.smooth([T(0.30, 9), T(0.62, 9), T(0.56, 4.6), T(0.46, 3.4), T(0.38, 4.0)], 3, True), gi.shadow, 3.052, clip=top)
    hem = fk.smooth([T(0.41, 6.6), T(0.44, 2.0), T(0.495, -6.2)], 4, False)
    fk.stroke(fig, hem, 1.0, 1.0, sash.base, 3.06)
    vee = fk.smooth([T(1.02, -2.4), T(1.02, 3.2), T(0.80, 3.0), T(0.70, 2.4), T(0.84, 0.2)], 3, True, corners=(0, 1, 3))
    fk.fillp(fig, vee, skin.base, 3.07, clip=tor)
    fk.stroke(fig, fk.smooth([T(1.0, 3.6), T(0.80, 3.3), T(0.69, 2.5), T(0.84, 0.0), T(1.0, -2.6)], 3, False, corners=(2,)),
              0.9, 0.9, sash.base, 3.08)
    # pelvis (pants) + obi
    pel = fk.smooth([T(0.13, 5.3), T(0.13, -5.6), T(-0.10, -6.6), T(-0.20, 0), T(-0.10, 6.4)], 4, True, corners=(0, 1))
    fk.cel_shape(fig, pel, pants, 3.1, ol=INNER)
    obi = fk.smooth([T(0.19, 5.0), T(0.19, -5.2), T(0.10, -5.9), T(0.10, 5.7)], 3, True, corners=(0, 1, 2, 3))
    fk.cel_shape(fig, obi, sash, 3.5, ol=1.1, shift=(1.0, 0.9))
    disc(fig, T(0.145, -5.5), 2.0 * u, "sash", 3.52, ol=1.1)
    # neck
    Nk = fk.tube([add(R["neck"], (0, 1.5 * u)), fk.head_pt(R, -0.05, 0.86)], [(0, 3.0 * u), (1, 2.6 * u)], caps=(False, False))
    fk.tube_draw(fig, Nk, fk.far(skin, 0.35), 3.7, k=0.5, ol=INNER)
    # scarf wound round the neck: chunky roll that sags at the throat
    N = R["neck"]
    roll = fk.tube([add(N, (-5.0 * u, -0.6 * u)), add(N, (-0.6 * u, 1.9 * u)), add(N, (4.4 * u, 0.4 * u))],
                   [(0, 2.5 * u), (0.5, 3.0 * u), (1.0, 2.3 * u)], n=6)
    fk.tube_draw(fig, roll, scarf, 3.9, k=0.4, hi=True, ol=INNER)
    fk.stroke(fig, [add(N, (-2.4 * u, -1.0 * u)), add(N, (-1.2 * u, 3.6 * u))], 0.5, 0.4, scarf.shadow, 3.91)
    fk.stroke(fig, [add(N, (1.4 * u, -1.2 * u)), add(N, (2.2 * u, 3.0 * u))], 0.5, 0.4, scarf.shadow, 3.91)
    kestrel_leg(fig, R, "f", 5)


def kestrel_hair(fig, R):
    """Spiky mane: a fan of swept-back spikes behind the skull, a skull cap, and a jagged fringe."""
    hair = fig.mats["hair"]
    r = R["hr"]
    sh = (0.085 * r, 0.10 * r)
    fl = R["ctx"]["flow"] * 0.18
    back = [((-0.80, -0.05), (-0.62, 0.52), (-1.62 - fl, 0.62)),
            ((-1.02, -0.50), (-0.86, 0.16), (-2.02 - fl, -0.10)),
            ((-0.90, -0.92), (-1.04, -0.26), (-1.98 - fl, -0.92)),
            ((-0.46, -1.10), (-0.98, -0.66), (-1.50 - fl, -1.74)),
            ((0.02, -1.12), (-0.60, -0.98), (-0.70 - fl, -2.10)),
            ((0.46, -1.02), (-0.14, -1.10), (0.12 - fl, -1.96)),
            ((0.80, -0.78), (0.28, -1.04), (0.86 - fl, -1.56))]
    for i, (a, b, tip) in enumerate(back):
        fk.cel_shape(fig, fk.spike(R, a, b, tip, 0.10), hair, 3.80 + i * 0.004, ol=INNER, shift=sh)
    # skull cap with the hairline: temple, sideburn in front of the ear, nape
    cap_ = fk.hpoly(R, [(0.93, -0.56), (0.86, -0.86), (0.50, -1.10), (-0.18, -1.18), (-0.80, -1.02), (-1.08, -0.55),
                        (-1.06, 0.02), (-0.86, 0.40), (-0.62, 0.34), (-0.56, 0.00), (-0.40, -0.26), (-0.14, -0.50),
                        (0.22, -0.66), (0.60, -0.70)], 5, corners=(0,))
    fk.cel_shape(fig, cap_, hair, 5.0, ol=1.1, shift=sh)
    fk.shine(fig, R, [(-0.86, -0.56), (-0.62, -0.80), (-0.34, -0.86), (-0.06, -0.98), (0.22, -0.92), (0.48, -0.96)],
             fk.shine_tone(hair), 5.004, cap_, w=0.12)
    # fringe: jagged locks over the forehead, tips above the brows; sideburn spike
    fringe = [((-0.50, -0.50), (-0.22, -0.56), (-0.40, 0.14), 0.0, 5.04),
              ((-0.34, -0.80), (0.10, -0.74), (-0.10, -0.40), 0.05, 5.06),
              ((0.02, -0.90), (0.44, -0.76), (0.36, -0.44), 0.05, 5.08),
              ((0.36, -0.90), (0.74, -0.74), (0.74, -0.46), 0.04, 5.10),
              ((0.66, -0.84), (0.93, -0.60), (0.99, -0.42), 0.03, 5.12)]
    for a, b, tip, bg, lay in fringe:
        fk.cel_shape(fig, fk.spike(R, a, b, tip, bg), hair, lay, ol=1.1, shift=sh)
    # crown tuft spikes rising in front of the fan
    for i, (a, b, tip) in enumerate((((-0.30, -1.00), (-0.74, -0.80), (-1.02 - fl, -1.50)),
                                     ((0.26, -1.04), (-0.26, -1.00), (-0.22 - fl, -1.70)),
                                     ((0.66, -0.90), (0.20, -1.02), (0.50 - fl, -1.50)))):
        fk.cel_shape(fig, fk.spike(R, a, b, tip, 0.08), hair, 5.02 + i * 0.002, ol=1.1, shift=sh)


def draw_kestrel(fig, R, face, glow, glow_hi):
    kestrel_scarf(fig, R)
    kestrel_body(fig, R)
    fk.head34(fig, R, face, fig.mats["skin"], 4.0, ol=INNER)
    kestrel_hair(fig, R)
    kestrel_arm(fig, R, "f", 6.0)
    s = R["s"]
    where = R["pose"]["glow"]
    if where == "foot":         # frost trailing the kicking heel
        fig.glow(add(R["ankle_f"], (-2 * s, 2 * s)), 10 * s, glow_hi, glow, 1.9)
    elif where:
        fig.glow(add(R["hand_f"], sc(fk.unit(R["elbow_f"], R["hand_f"]), 4 * s)), 11 * s, glow_hi, glow, 1.9)


# ------------------------------------------------------------------ BRUNO: forge-gauntlet grappler
BRUNO = dict(
    height=89, build=1.2, head=10.0, neck_len=5.2, torso=1.08, leg=0.84, limb=1.0, chest=1.0, waist=1.0, arm_len=1.0,
    hip_off=6.0, sh_tw=((0.86, 11.0), (0.87, -9.5)), head_fwd=3.5, sole=10.9,
    mats={
        "skin": M((214, 152, 110), (164, 98, 76), (244, 196, 154), hi_t=0.985),
        "hair": M((216, 84, 30), (140, 40, 26), (255, 160, 80), hi_t=0.93),
        "apron": M((226, 62, 50), (150, 30, 44), (255, 130, 100), hi_t=0.97),
        "pants": M((84, 92, 150), (50, 52, 104)),
        "metal": M((132, 150, 190), (76, 84, 136), (226, 236, 255), hi_t=0.9),
        "boot": M((150, 86, 48), (96, 48, 36), (214, 140, 90), hi_t=0.97),
        "sole": M((90, 52, 52), (56, 32, 40)),
        "gold": M((240, 182, 60), (166, 104, 24), (255, 238, 150)),
        "patch": M((246, 190, 70), (176, 112, 30), (255, 238, 150), hi_t=0.97),
    },
    mats2={
        "hair": M((236, 226, 186), (170, 156, 118), (255, 252, 226), hi_t=0.93),
        "apron": M((30, 176, 170), (16, 108, 124), (130, 236, 222), hi_t=0.97),
        "pants": M((218, 208, 180), (150, 140, 120)),
        "metal": M((180, 150, 210), (112, 86, 156), (240, 226, 255), hi_t=0.9),
        "boot": M((60, 84, 180), (34, 46, 120), (130, 156, 240), hi_t=0.97),
        "sole": M((40, 44, 96), (24, 26, 64)),
        "gold": M((208, 214, 230), (130, 140, 168), (255, 255, 255)),
        "patch": M((58, 112, 168), (34, 68, 112), (130, 182, 232), hi_t=0.97),
    },
    glow=(255, 140, 30), glow_hi=(255, 214, 96), glow2=(60, 210, 255), glow2_hi=(210, 250, 255),
    face=dict(skin="skin", iris=(224, 150, 40), iris_lo=(120, 60, 20), lowerlid=(156, 92, 72),
              browmat=(84, 30, 20), brow=0.22, brow_w=0.085, mouth="none", nose="none", es=1.0, eh=1.0, ey=0.04,
              brow_gap=0.40, lash=False, lid_w=0.065, ex=0.15, fx=0.75, iris_r=0.19,
              outline=[(0.02, -1.02), (0.52, -0.92), (0.84, -0.62), (0.95, -0.30), (0.89, -0.04), (0.93, 0.20), (0.90, 0.52),
                       (0.78, 0.84), (0.52, 1.02), (0.28, 0.98), (-0.08, 0.84), (-0.42, 0.58), (-0.64, 0.26), (-0.94, 0.02),
                       (-1.02, -0.38), (-0.84, -0.76), (-0.46, -0.98)]),
    face2=dict(iris=(80, 200, 220), iris_lo=(20, 90, 110), browmat=(150, 130, 80)),
)


def bruno_leg(fig, R, side, layer):
    """Heavy work trousers (shaped thigh / knee / calf), steel knee guard, cuffed work boot with a steel toe."""
    u = R["s"]
    back = side == "b"
    hp, kn, an = R["hip_" + side], R["knee_" + side], R["ankle_" + side]
    pants, metal, boot, sole, patch = (fig.mats["pants"], fig.mats["metal"], fig.mats["boot"], fig.mats["sole"],
                                       fig.mats["patch"])
    if back:
        pants, metal, boot, sole, patch = (fk.far(pants, 0.5), fk.far(metal, 0.5), fk.far(boot, 0.5), fk.far(sole, 0.4),
                                           fk.far(patch, 0.5))
    T = fk.tube([hp, kn, an], [(0, 10.4 * u), (0.22, 10.0 * u), (0.47, 7.6 * u), (0.56, 7.3 * u), (0.72, 7.8 * u),
                               (1.0, 6.0 * u)], n=8)
    fk.tube_draw(fig, T, pants, layer, k=0.38, ol=INNER)
    d = fk.unit(hp, kn)
    pr = (-d[1], d[0])
    if pr[0] < 0:
        pr = (-pr[0], -pr[1])
    # steel knee guard on the front of the knee
    kg = fk.offs(kn, pr, 2.6 * u)
    Lk = lambda al, fw: fk.offs(fk.offs(kg, d, al * u), pr, fw * u)
    plate = fk.smooth([Lk(-5.4, -2.4), Lk(-5.2, 2.4), Lk(-2.6, 5.2), Lk(2.6, 5.2), Lk(5.2, 2.4), Lk(5.4, -2.4)], 3, True,
                      corners=(0, 5))
    fk.cel_shape(fig, plate, metal, layer + 0.2, ol=1.2, shift=(1.4, 1.5))
    # boot: foot first, then the shaft and its folded cuff on top
    sd = fk.unit(kn, an)
    top = lerp(kn, an, 0.60)
    L = fk.foot_frame(R, side, 1.45, lo=0.0, hi=30.0)
    pts = [L(-3.2, 1.6), L(-3.7, 5.0), L(-3.4, 7.3), L(-0.8, 7.5), L(2.6, 6.9), L(7.6, 7.1), L(11.6, 6.9), L(13.4, 5.6),
           L(13.2, 3.6), L(11.2, 1.8), L(7.6, 0.2), L(4.6, -1.6), L(3.4, -3.2), L(-3.0, -3.2)]
    poly = fk.smooth(pts, 4, True, corners=(2, 3, 12, 13))
    fk.cel_shape(fig, poly, boot, layer + 0.12, ol=INNER, shift=(1.6, 2.0))
    cap_ = [L(9.0, -1), L(15, -1), L(15, 9), L(8.4, 9), L(8.2, 4.0)]
    fk.fillp(fig, cap_, metal.shadow, layer + 0.123, clip=poly)
    tx_, ty_ = fk.lv((-1.4, -1.6))
    fk.fillp(fig, [(x + tx_, y + ty_) for x, y in poly], metal.base, layer + 0.1235, clip=cap_)
    fk.fillp(fig, [L(-5, 5.6), L(15, 5.6), L(15, 9), L(-5, 9)], sole.base, layer + 0.125, clip=poly)
    fk.fillp(fig, [L(-5, 4.2), L(-0.8, 4.2), L(-0.6, 9), L(-5, 9)], sole.shadow, layer + 0.126, clip=poly)
    fk.ground(R, poly)
    S = fk.tube([top, an], [(0, 7.3 * u), (1.0, 6.2 * u)], n=4, caps=(False, False))
    fk.tube_draw(fig, S, boot, layer + 0.3, k=0.38, ol=INNER)
    C = fk.tube([fk.offs(top, sd, -1.2 * u), fk.offs(top, sd, 2.0 * u)], [(0, 8.0 * u), (1.0, 7.8 * u)], n=3, caps=(False, False))
    fk.tube_draw(fig, C, patch, layer + 0.35, k=0.4, ol=1.2)


def bruno_arm(fig, R, side, layer, glow, glow_hi, part="all", far=False):
    """Bare slab of an upper arm, gold armband, forge gauntlet with a furnace port, plated fist (or open palm).
    `part` draws only the upper arm or only the forearm, so a far forearm can pass in front of the body.
    `far` tints the arm as the one on the far side of the body."""
    u = R["s"]
    back = far
    sh, el, ha = R["sh_" + side], R["elbow_" + side], R["hand_" + side]
    skin, metal, gold = fig.mats["skin"], fig.mats["metal"], fig.mats["gold"]
    if back:
        skin, metal, gold = fk.far(skin, 0.5), fk.far(metal, 0.45), fk.far(gold, 0.5)
    ud = fk.unit(sh, el)
    fd = fk.unit(el, ha)
    pp = (-fd[1], fd[0])
    if part in ("all", "upper"):
        U = fk.tube([fk.offs(sh, ud, -1.0 * u), el], [(0, 9.2 * u), (0.3, 9.6 * u), (0.72, 7.4 * u), (1.0, 6.6 * u)], n=6)
        if not back and "tor" in R:
            # cast shadow on the chest so the bare arm separates from the bare torso
            cx_, cy_ = fk.lv((4.2 * u, 3.4 * u))
            fk.fillp(fig, [(x + cx_, y + cy_) for x, y in U["poly"]], fig.mats["skin"].shadow, 3.03, clip=R["tor"])
            skin = Cel(fk.mixc(skin.base, (255, 236, 214), 0.26), fk.mixc(skin.base, skin.shadow, 0.55), skin.hi)
        fk.outline(fig, U["poly"], layer, 1.7 if back else 2.4, col=OUTLINE)
        fk.tube_draw(fig, U, skin, layer, k=0.36, ol=0)
        un = (-ud[1], ud[0])
        # deltoid seam
        fk.stroke(fig, [fk.offs(fk.offs(sh, ud, 6.5 * u), un, 6.0 * u * U["shade_side"]), fk.offs(fk.offs(sh, ud, 8.4 * u), un, 0.5 * u)],
                  0.8, 0.5, skin.shadow, layer + 0.01)
        mid = lerp(sh, el, 0.66)
        B = fk.tube([fk.offs(mid, ud, -1.3 * u), fk.offs(mid, ud, 1.3 * u)], [(0, 8.1 * u), (1, 7.7 * u)], n=3, caps=(False, False))
        fk.tube_draw(fig, B, gold, layer + 0.1, k=0.4, ol=1.1)
    if part in ("all", "fore"):
        fl = layer
        wr = lerp(el, ha, 0.92)
        G = fk.tube([fk.offs(el, fd, -1.2 * u), lerp(el, wr, 0.5), wr], [(0, 6.6 * u), (0.5, 7.5 * u), (1.0, 7.7 * u)], n=5,
                    caps=(True, False))
        fk.tube_draw(fig, G, metal, fl + 0.3, k=0.38, hi=True, ol=INNER)
        C = fk.tube([lerp(el, ha, 0.60), lerp(el, ha, 0.82)], [(0, 8.6 * u), (1, 8.9 * u)], n=3, caps=(False, False))
        fk.tube_draw(fig, C, metal, fl + 0.35, k=0.38, hi=True, ol=1.2)
        for t in (0.26, 0.44):
            c = lerp(el, ha, t)
            r_ = (6.9 + 1.4 * t) * u
            fk.stroke(fig, [fk.offs(c, pp, r_), fk.offs(c, pp, -r_)], 1.5, 1.5, glow, fl + 0.4)
        if not R["pose"]["fist"]:
            # open gauntlet: plated palm with the furnace port glowing in its centre
            pc = open_hand(fig, ha, fd, 2.1 * u, metal, fl + 0.5, shift=(1.6, 1.8))
            fk.fillp(fig, fk.circle(pc, 3.0 * u, 12), glow, fl + 0.53)
            fk.fillp(fig, fk.circle(pc, 1.6 * u, 10), glow_hi, fl + 0.54)
            return
        # fist: plated block, three finger plates, glowing grooves
        L = lambda a_, b_: (ha[0] + (fd[0] * a_ + pp[0] * b_) * u, ha[1] + (fd[1] * a_ + pp[1] * b_) * u)
        fist = fk.smooth([L(-1.6, -7.4), L(3.0, -8.2), L(7.4, -7.6), L(9.6, -4.8), L(9.8, 3.6), L(8.2, 7.0), L(3.4, 8.0),
                          L(-1.6, 7.2)], 4, True)
        fk.cel_shape(fig, fist, metal, fl + 0.5, ol=INNER, shift=(1.6, 1.8))
        for v in (-2.5, 2.7):
            fk.stroke(fig, [L(9.5, v * 0.92), L(5.2, v)], 0.9, 0.7, fk.linec(metal), fl + 0.52)
        for v in (-5.0, 0.1, 5.2):
            fk.fillp(fig, fk.circle(L(7.3, v), 1.7 * u, 10), glow, fl + 0.53)
            fk.fillp(fig, fk.circle(L(7.1, v - 0.2), 0.9 * u, 8), glow_hi, fl + 0.54)


def bruno_body(fig, R, glow, glow_hi):
    s, tp = R["s"], R["tp"]
    u = s
    T = lambda t, w: tp(t, w * u)
    skin, apron, gold, pants, patch = fig.mats["skin"], fig.mats["apron"], fig.mats["gold"], fig.mats["pants"], fig.mats["patch"]
    # ---- back limbs
    bruno_leg(fig, R, "b", 1)
    px, py = R["perp"]
    # The lead arm (rig side "f", its shoulder on the facing side of the chest) is the FAR arm of the 3/4 view:
    # it leaves its shoulder behind the torso and its forearm comes out ahead of the chest. The rear arm (rig
    # side "b") is the near one and is drawn over the torso from its own shoulder (see draw_bruno).
    hb = R["hand_f"]
    fwd = ((hb[0] - R["hip"][0]) * px + (hb[1] - R["hip"][1]) * py) / u
    R["back_fore_front"] = fwd > 6.0
    bruno_arm(fig, R, "f", 1, glow, glow_hi, "upper" if R["back_fore_front"] else "all", far=True)
    bruno_leg(fig, R, "f", 2.2)
    # ---- torso: belly, barrel chest, yoke of the shoulders
    tbl = [(-0.06, 10.6, 10.6), (0.10, 11.8, 10.6), (0.28, 12.6, 10.6), (0.46, 13.4, 11.4), (0.62, 15.2, 13.0),
           (0.76, 16.0, 14.6), (0.87, 14.8, 15.0), (0.96, 9.6, 11.0), (1.04, 5.6, 6.6)]
    fr = [T(t, f) for t, f, b in tbl]
    bk = [T(t, -b) for t, f, b in tbl]
    tor = fk.smooth(fr + bk[::-1], 4, True, corners=(0, len(fr) - 1, len(fr), 2 * len(fr) - 1))
    fk.cel_shape(fig, tor, skin, 3.0, ol=INNER, shift=(2.4, 2.0))
    R["tor"] = tor
    # pecs, sternum, collar bones
    sd = skin.shadow
    fk.stroke(fig, fk.smooth([T(0.70, -11.0), T(0.655, -5.0), T(0.67, 1.2), T(0.64, 8.0), T(0.69, 14.5)], 4, False), 1.0, 0.8, sd, 3.02)
    # pants over the pelvis
    pel = fk.smooth([T(0.12, 11.6), T(0.12, -10.6), T(-0.12, -11.6), T(-0.30, 0), T(-0.12, 12.0)], 4, True, corners=(0, 1))
    fk.cel_shape(fig, pel, pants, 3.05, ol=INNER)
    # ---- leather apron: bib on the chest (clipped to the body), skirt hanging over the thighs
    AL = 5.15
    bib = fk.smooth([T(0.60, -4.4), T(0.60, 11.0), T(0.50, 17), T(0.02, 17), T(0.02, -8.0), T(0.30, -7.0)], 3, True,
                    corners=(0, 1, 2, 3, 4))
    fk.fillp(fig, bib, apron.base, 3.2, clip=tor)
    fk.fillp(fig, fk.smooth([T(0.62, 8.0), T(0.62, 18), T(0.0, 18), T(0.0, 9.4), T(0.3, 8.8)], 3, True), apron.shadow, 3.201, clip=bib)
    fk.stroke(fig, [T(0.60, -4.4), T(0.60, 10.8)], 0.9, 0.9, apron.hi or apron.base, 3.21)
    fk.stroke(fig, fk.smooth([T(0.60, -4.4), T(0.30, -7.0), T(0.10, -7.9)], 3, False), 1.0, 1.0, fk.olcol(apron), 3.21)
    # halter straps up to the neck
    for w0, w1 in ((-4.0, -4.0), (10.6, 4.8)):
        fk.stroke(fig, [T(0.60, w0), T(1.00, w1)], 1.5 * u * 0.5 + 1.6, 1.3 * u * 0.5 + 1.4, fk.olcol(apron), 3.22)
        fk.stroke(fig, [T(0.60, w0), T(1.00, w1)], 1.5 * u * 0.5 + 0.5, 1.3 * u * 0.5 + 0.4, apron.base, 3.23)
    if R["ctx"]["flat"]:        # lying: the skirt settles flat on the lap, shorter and lower than it hangs
        skirt = fk.smooth([T(0.06, -8.2), T(0.06, 10.6), T(-0.16, 10.6), T(-0.34, 9.0), T(-0.38, -6.2), T(-0.2, -8.4)], 4, True,
                          corners=(0, 1, 3, 4))
        hem = [T(-0.33, 8.8), T(-0.365, -6.0)]
    else:
        skirt = fk.smooth([T(0.06, -8.2), T(0.06, 12.8), T(-0.20, 14.6), T(-0.47, 15.4), T(-0.50, -4.2), T(-0.2, -7.4)], 4, True,
                          corners=(0, 1, 3, 4))
        hem = [T(-0.455, 15.0), T(-0.485, -4.0)]
    fk.cel_shape(fig, skirt, apron, AL, ol=INNER, shift=(2.0, 1.2))
    fk.stroke(fig, hem, 0.7, 0.7, apron.hi or apron.base, AL + 0.03)
    # tool pocket
    pk = fk.smooth([T(-0.06, 2.4), T(-0.06, 9.6), T(-0.30, 10.2), T(-0.30, 2.8)], 3, True, corners=(0, 1, 2, 3))
    fk.cel_shape(fig, pk, patch, AL + 0.25, ol=1.0, shift=(1.2, 1.0))
    # belt + buckle
    belt = fk.smooth([T(0.12, -10.9), T(0.12, 12.4), T(0.00, 12.8), T(0.00, -11.0)], 3, True, corners=(0, 1, 2, 3))
    fk.cel_shape(fig, belt, gold, AL + 0.35, ol=1.2, shift=(1.2, 1.0))
    bp = fk.smooth([T(0.15, 5.6), T(0.15, 10.4), T(-0.03, 10.4), T(-0.03, 5.6)], 3, True, corners=(0, 1, 2, 3))
    fk.cel_shape(fig, bp, gold, AL + 0.4, ol=1.2, shift=(0.9, 0.8))
    fk.fillp(fig, fk.circle(T(0.06, 8.0), 1.5 * u, 10), fk.linec(gold, 0.2), AL + 0.42)
    # ---- neck
    Nk = fk.tube([T(0.98, 0.5), fk.head_pt(R, -0.05, 0.80)], [(0, 6.6 * u), (1, 5.6 * u)], caps=(False, False))
    fk.tube_draw(fig, Nk, fk.far(skin, 0.3), 3.7, k=0.5, ol=INNER)
    if R["back_fore_front"]:
        bruno_arm(fig, R, "f", 5.4, glow, glow_hi, "fore", far=True)


def bruno_hair(fig, R):
    """Topknot + gold ring, heavy brow, bulb nose, full beard with a moustache and a chest-length braid."""
    r = R["hr"]
    hair, gold, skin = fig.mats["hair"], fig.mats["gold"], fig.mats["skin"]
    H = lambda f, d: fk.head_pt(R, f, d)
    sh = (0.07 * r, 0.085 * r)
    # tied topknot on the crown: bound stem, gold band, round knot with two loose ends
    stem = fk.hpoly(R, [(-0.34, -0.96), (-0.02, -1.00), (-0.06, -1.26), (-0.30, -1.24)], 3, corners=(0, 1, 2, 3))
    fk.cel_shape(fig, stem, hair, 4.78, ol=INNER, shift=sh)
    fk.cel_shape(fig, fk.circle(H(-0.17, -1.48), r * 0.38, 16, 1.2, 0.9), hair, 4.8, ol=INNER, shift=sh)
    fk.stroke(fig, fk.hpoly(R, [(-0.46, -1.50), (-0.17, -1.40), (0.12, -1.50)], 3, closed=False), r * 0.025, r * 0.02, hair.shadow, 4.81)
    ring = fk.hpoly(R, [(-0.40, -1.10), (0.04, -1.16), (0.06, -1.02), (-0.38, -0.96)], 3, corners=(0, 1, 2, 3))
    fk.cel_shape(fig, ring, gold, 4.85, ol=1.1, shift=(0.8, 0.8))
    # bulb nose
    nose = fk.hpoly(R, [(0.60, 0.04), (0.76, 0.18), (0.88, 0.36), (0.80, 0.50), (0.60, 0.50), (0.52, 0.34)], 4)
    fk.fillp(fig, nose, skin.shadow, 4.4)
    nx_, ny_ = fk.lv((-0.07 * r, -0.07 * r))
    fk.fillp(fig, [(x + nx_, y + ny_) for x, y in nose], skin.base, 4.401, clip=nose)
    fk.stroke(fig, fk.hpoly(R, [(0.60, 0.04), (0.54, 0.26), (0.56, 0.44)], 3, closed=False), r * 0.02, r * 0.03, skin.shadow, 4.41)
    # full beard hugging the jaw
    beard = fk.hpoly(R, [(-0.34, 0.12), (-0.18, 0.40), (0.10, 0.50), (0.44, 0.52), (0.80, 0.50), (0.93, 0.70), (0.84, 1.06),
                         (0.56, 1.34), (0.16, 1.28), (-0.22, 1.02), (-0.50, 0.60)], 4, corners=(0,))
    fk.cel_shape(fig, beard, hair, 5.0, ol=INNER, shift=sh)
    for pts in ([(0.10, 0.80), (0.20, 1.08)], [(0.56, 0.86), (0.56, 1.14)]):
        fk.stroke(fig, [H(*pts[0]), H(*pts[1])], r * 0.03, r * 0.015, hair.shadow, 5.02)
    # moustache: two heavy lobes drooping from under the nose
    for pts, lay in (([(0.70, 0.46), (0.94, 0.52), (1.00, 0.80), (0.86, 0.62), (0.70, 0.60)], 5.3),
                     ([(0.74, 0.46), (0.40, 0.48), (0.10, 0.84), (0.44, 0.72), (0.72, 0.62)], 5.32)):
        fk.cel_shape(fig, fk.hpoly(R, pts, 4, corners=(2,)), hair, lay, ol=1.1, shift=sh)
    # braid hanging from the chin onto the chest, gold bead at the tip
    p = H(0.48, 1.36)
    n = 4
    g = fk.lv((0.0, 1.0))       # the braid hangs with gravity, whichever way he has been tipped
    gn = (g[1], -g[0])
    bead = lambda a_, b_: (p[0] + g[0] * a_ + gn[0] * b_, p[1] + g[1] * a_ + gn[1] * b_)
    for i in range(n):
        c = bead(i * r * 0.30, math.sin(i * 2.6) * 0.07 * r + i * 0.02 * r)
        rr = r * (0.26 - i * 0.03)
        fk.cel_shape(fig, fk.circle(c, rr, 12, 1.0, 1.12), hair, 6.6 + i * 0.01, ol=1.1, shift=(0.06 * r, 0.07 * r))
    fk.cel_shape(fig, fk.circle(bead(n * r * 0.30 - 0.02 * r, 0.08 * r), r * 0.13, 10), gold, 6.7, ol=1.1, shift=(0.7, 0.7))
    # gold earring
    fk.cel_shape(fig, fk.circle(H(-0.50, 0.34), r * 0.09, 10), gold, 4.5, ol=1.0, shift=(0.6, 0.6))


def draw_bruno(fig, R, face, glow, glow_hi):
    bruno_body(fig, R, glow, glow_hi)
    fk.head34(fig, R, face, fig.mats["skin"], 4.0, ol=INNER)
    bruno_hair(fig, R)
    bruno_arm(fig, R, "b", 6, glow, glow_hi)
    # the furnace ports always smoulder; a glow pose stokes them
    s = R["s"]
    knuckles = add(R["hand_f"], sc(fk.unit(R["elbow_f"], R["hand_f"]), 6 * s))
    fig.glow(knuckles, (12 if R["pose"]["glow"] else 7) * s, glow_hi, glow, 2.0)


# ------------------------------------------------------------------ ILSE: orb-casting zoner
ILSE = dict(
    height=89, build=1.0, head=8.9, torso=0.95, thigh=21.5, shin=20.5, neck_len=3.0, sh_off=(4.8, -5.0), hip_off=2.4, sole=8.8,
    mats={
        "skin": M((250, 216, 194), (222, 164, 154), (255, 238, 222)),
        "hair": M((214, 208, 252), (150, 138, 228), (255, 255, 255)),
        "coat": M((228, 50, 72), (156, 24, 70), (255, 136, 130)),
        "gold": M((244, 200, 78), (176, 124, 30), (255, 242, 168)),
        "shirt": M((244, 236, 222), (192, 176, 170), (255, 252, 244)),
        "pants": M((96, 72, 156), (60, 42, 110), (150, 124, 210)),
        "boot": M((150, 78, 62), (98, 44, 50), (214, 132, 100)),
        "sole": M((84, 46, 56), (54, 30, 44), (130, 84, 84)),
        "sash": M((84, 60, 150), (52, 36, 104), (140, 112, 210)),
        "gem": M((178, 96, 255), (108, 46, 214), (244, 224, 255)),
    },
    mats2={
        "coat": M((22, 160, 176), (14, 100, 136), (120, 232, 232)),
        "gold": M((226, 234, 246), (136, 150, 176), (255, 255, 255)),
        "hair": M((255, 214, 96), (226, 150, 60), (255, 246, 196)),
        "pants": M((236, 226, 204), (178, 162, 144), (252, 248, 234)),
        "boot": M((60, 84, 170), (36, 48, 116), (126, 150, 230)),
        "sole": M((36, 44, 96), (22, 26, 64), (84, 96, 160)),
        "sash": M((250, 246, 236), (190, 190, 214), (255, 255, 255)),
        "shirt": M((250, 246, 236), (196, 190, 182), (255, 255, 250)),
        "gem": M((90, 236, 206), (28, 162, 170), (226, 255, 250)),
    },
    glow=(170, 120, 255), glow_hi=(240, 224, 255), glow2=(96, 238, 214), glow2_hi=(232, 255, 250),
    face=dict(skin="skin", iris=(176, 118, 244), iris_lo=(84, 40, 156), lowerlid=(216, 160, 150),
              browmat=(128, 132, 180), ear=False, blush=(246, 130, 140), mouth="smile", brow_gap=0.40, brow=0.02),
    face2=dict(iris=(66, 206, 190), iris_lo=(16, 94, 112), browmat=(184, 128, 72)),
)


def ilse_tails(fig, R):
    """Everything that trails behind her: the two coat tails and the long braid."""
    s = R["s"]
    gold, coat = fig.mats["gold"], fig.mats["coat"]
    flow, sway = R["ctx"]["flow"], R["ctx"]["sway"]
    # coat tails: two tapering panels with a gold edge
    for L, w0, w1, th, off, ph, lay in ((84, 9.0, 5.0, 112, 0, 0.3, 1.9), (66, 8.0, 4.4, 96, 4, 1.7, 1.85)):
        start = add(R["hip"], (-3.0 * s + off, -1.0 * s))
        path = wave(start, cloth_theta(R, th, 40) + off * 0.4, L * s / 2 * (1 - 0.22 * max(0.0, flow)), 5,
                    7 * (1 - 0.3 * flow), 1.0, ph + sway)
        path = settle(R, path, w1 * s * 0.6)
        T = fk.tube(path, [(0, w0 * s * 0.5), (0.5, w1 * s * 0.6), (1.0, 1.0 * s * 0.5)], caps=(False, False))
        fk.tube_draw(fig, T, fk.far(coat, 0.22), lay, k=0.5, ol=INNER)
        fk.stroke(fig, T["L"] if T["shade_side"] < 0 else T["R"], 1.1, 1.0, gold.base, lay + 0.01)
    # long braid from the nape
    p0 = fk.head_pt(R, -0.82, 0.30)
    c = R["ctx"]
    lift = c["lift"]
    curl = c["curl"] if c["curl"] is not None else max(0.0, lift) * 1.7
    if c["lying"] or c["hang"] is not None:
        curl = 0.0
    # a falling body leaves the braid behind: it swings up from the nape and whips further up along its length
    # (curl > 0); on landing it is already arcing back down (curl < 0). It never sticks straight out.
    pts = settle(R, wave(p0, cloth_theta(R, 104, -8, 100, lo=92), 86 * s / 2, 10, 7, 1.3, 0.2 + sway, droop=curl * 100),
                 0.4 * R["hr"])
    T = fk.tube(pts, [(0, 0.36 * R["hr"]), (0.55, 0.31 * R["hr"]), (1.0, 0.16 * R["hr"])], caps=(True, True))
    hair = fig.mats["hair"]
    fk.tube_draw(fig, T, hair, 2.4, k=0.38, ol=INNER)
    # plait chevrons
    m = len(T["C"])
    for j in range(3, m - 4, 6):
        c, tn, nn, w = T["C"][j], T["T"][j], T["N"][j], T["W"][j]
        a = fk.offs(fk.offs(c, nn, w * 0.8), tn, -w * 0.5)
        b = fk.offs(fk.offs(c, tn, w * 0.55), nn, 0.0)
        d = fk.offs(fk.offs(c, nn, -w * 0.8), tn, -w * 0.5)
        fk.stroke(fig, [a, b, d], 1.0, 1.0, hair.shadow, 2.45)
    e = T["C"][-1]
    disc(fig, e, 2.2 * s / 2 + 1.0, "gold", 2.6, ol=1.2)
    tn = T["T"][-1]
    fk.stroke(fig, [e, fk.offs(e, tn, 6 * s / 2), fk.offs(fk.offs(e, tn, 8 * s / 2), (0, 1), 2)], 1.4, 0.8, gold.base, 2.58)
    fk.stroke(fig, [fk.offs(e, tn, 6 * s / 2), fk.offs(fk.offs(e, tn, 8 * s / 2), (0, 1), 2)], 1.2, 0.6, gold.shadow, 2.59)


def ilse_foot(fig, R, ankle, toe, layer, m_boot, m_sole, back):
    """Boot: heel block, sole, arch, instep and a pointed toe cap, rotated to the foot angle."""
    s = R["s"]
    ang = math.degrees(math.atan2(toe[1] - ankle[1], toe[0] - ankle[0]))     # screen angle, +x forward
    ang = max(-4.0, min(40.0, ang))          # ankle flex: toes forward, flat-ish
    f = (math.cos(math.radians(ang)), math.sin(math.radians(ang)))
    d = (-f[1], f[0])

    def L(u, v, s=s * 1.2):
        return (ankle[0] + (f[0] * u + d[0] * v) * s, ankle[1] + (f[1] * u + d[1] * v) * s)

    pts = [L(-3.0, 2.0), L(-3.5, 5.2), L(-3.2, 7.1), L(-0.8, 7.3), L(2.6, 6.2), L(7.6, 6.6), L(11.0, 6.3),
           L(12.9, 5.2), L(12.6, 4.2), L(10.6, 3.4), L(7.4, 1.9), L(4.4, -0.8), L(3.0, -3.0), L(-2.8, -3.0)]
    poly = fk.smooth(pts, 4, True, corners=(2, 3, 7, 12, 13))
    mb = fk.far(m_boot, 0.5) if back else m_boot
    ms = fk.far(m_sole, 0.4) if back else m_sole
    fk.outline(fig, poly, layer, INNER, col=fk.olcol(mb))
    fk.fillp(fig, poly, mb.base, layer)
    fk.fillp(fig, fk.smooth([L(-4.5, 3.4), L(-1, 4.4), L(5, 4.6), L(10, 4.4), L(14, 4.4), L(14, 9), L(-4.5, 9)], 3, True),
          mb.shadow, layer + 0.001, clip=poly)
    if mb.hi:
        fk.fillp(fig, fk.smooth([L(6.8, 2.3), L(10.0, 3.4), L(11.6, 4.2), L(9.8, 4.0), L(6.6, 3.0)], 3, True),
              mb.hi, layer + 0.002, clip=poly)
    sole = [L(-4.2, 6.2), L(-3.4, 7.5), L(11.8, 6.9), L(13.6, 5.7), L(13.5, 4.9), L(11.4, 5.5), L(-3.6, 5.8)]
    fk.fillp(fig, sole, ms.base, layer + 0.004, clip=poly)
    fk.fillp(fig, [L(-4.4, 4.4), L(-1.4, 4.4), L(-1.0, 7.8), L(-4.4, 7.8)], ms.shadow, layer + 0.005, clip=poly)
    R.setdefault("feet", []).append(max(p[1] for p in poly) + 1.0)
    return poly


def ilse_leg(fig, R, side, layer):
    """Slim trousers with a lit kneecap, knee boot with a folded gold cuff."""
    s = R["s"]
    back = side == "b"
    hp, knee, ankle, toe = R["hip_" + side], R["knee_" + side], R["ankle_" + side], R["toe_" + side]
    pants, boot, gold, sole = fig.mats["pants"], fig.mats["boot"], fig.mats["gold"], fig.mats["sole"]
    mp = fk.far(pants, 0.5) if back else pants
    mbt = fk.far(boot, 0.5) if back else boot
    mg = fk.far(gold, 0.5) if back else gold
    T = fk.tube([hp, knee, ankle], [(0, 5.4 * s), (0.22, 5.2 * s), (0.50, 3.8 * s), (0.60, 3.6 * s), (0.76, 3.7 * s),
                                 (1.0, 2.3 * s)], n=8)
    fk.tube_draw(fig, T, mp, layer, k=0.42, hi=True, ol=INNER)
    # kneecap: lit cap + crease so the joint reads
    kn = knee
    ax = fk.unit(hp, ankle)
    nn = (-ax[1], ax[0])
    fr = nn if nn[0] > 0 else (-nn[0], -nn[1])
    fk.fillp(fig, fk.circle(fk.offs(kn, fr, 0.3 * s), 3.85 * s, 14), mp.base, layer + 0.03)
    # boot shaft below the knee
    b0 = lerp(knee, ankle, 0.36)
    B = fk.tube([b0, lerp(b0, ankle, 0.5), ankle], [(0, 3.6 * s), (0.5, 3.2 * s), (1.0, 2.8 * s)], n=5)
    ilse_foot(fig, R, ankle, toe, layer + 0.12, boot, sole, back)
    fk.tube_draw(fig, B, mbt, layer + 0.2, k=0.42, hi=True, ol=INNER)
    # folded gold cuff
    c0, c1 = b0, lerp(b0, ankle, 0.15)
    Cu = fk.tube([c0, c1], [(0, 4.0 * s), (1.0, 3.8 * s)], n=3, caps=(False, False))
    fk.tube_draw(fig, Cu, mg, layer + 0.3, ol=1.2, k=0.4)


def ilse_arm(fig, R, side, layer):
    """Coat sleeve with a gold cuff and an open caster's hand; the front palm is where the orb floats."""
    s = R["s"]
    back = side == "b"
    sh, elbow, hand = R["sh_" + side], R["elbow_" + side], R["hand_" + side]
    glow_pose = (not back) and R["pose"]["glow"] in CAST_GLOW
    coat, gold, skin = fig.mats["coat"], fig.mats["gold"], fig.mats["skin"]
    mc = fk.far(coat, 0.5) if back else coat
    mg = fk.far(gold, 0.5) if back else gold
    ms = fk.far(skin, 0.5) if back else skin
    T = fk.tube([sh, elbow, hand], [(0, 4.2 * s), (0.18, 4.0 * s), (0.50, 3.0 * s), (0.62, 3.2 * s), (0.85, 2.5 * s),
                                  (1.0, 2.4 * s)], n=8, caps=(True, False))
    fk.tube_draw(fig, T, mc, layer, k=0.42, ol=INNER)
    fd = fk.unit(elbow, hand)
    nn = (-fd[1], fd[0])
    # gold cuff
    c0, c1 = lerp(elbow, hand, 0.74), hand
    Cu = fk.tube([c0, c1], [(0, 3.0 * s), (1, 2.9 * s)], n=3, caps=(False, False))
    fk.tube_draw(fig, Cu, mg, layer + 0.3, ol=1.3, k=0.4)
    # hand: palm + fingers + thumb (open caster's hand, palm toward the orb)
    hs = 1.28 * s
    curl = 24 if not glow_pose else 12
    fdir = fk.rot(fd, -curl)
    w = hand
    palm_end = fk.offs(w, fd, 3.4 * hs)
    P1 = fk.tube([fk.offs(w, fd, -0.6 * hs), palm_end], [(0, 2.35 * hs), (1.0, 2.5 * hs)], n=3)
    fk.tube_draw(fig, P1, ms, layer + 0.5, k=0.4, ol=INNER)
    # fingers: one tapered mass with separation lines
    f0 = fk.offs(w, fd, 2.8 * hs)
    mid = fk.offs(f0, fk.rot(fd, -curl * 0.5), 3.0 * hs)
    tip = fk.offs(mid, fdir, 2.8 * hs)
    F1 = fk.tube([f0, mid, tip], [(0, 2.2 * hs), (0.6, 1.9 * hs), (1.0, 1.15 * hs)], n=5)
    fk.tube_draw(fig, F1, ms, layer + 0.52, k=0.4, ol=INNER)
    # thumb
    t0 = fk.offs(fk.offs(w, fd, 1.0 * hs), nn, -1.6 * hs * (1 if nn[1] < 0 else 1))
    tdir = fk.rot(fd, -48)
    t1 = fk.offs(t0, tdir, 2.6 * hs)
    t2 = fk.offs(t1, fk.rot(fd, -30), 2.0 * hs)
    Th = fk.tube([t0, t1, t2], [(0, 1.5 * hs), (1.0, 1.0 * hs)], n=4)
    fk.tube_draw(fig, Th, ms, layer + 0.58, k=0.4, ol=INNER)
    if not back:
        R["palm"] = fk.offs(w, fd, 4.2 * 1.28 * s)


def ilse_body(fig, R):
    s, tp = R["s"], R["tp"]
    pose = R["pose"]
    coat, gold, shirt, skin = fig.mats["coat"], fig.mats["gold"], fig.mats["shirt"], fig.mats["skin"]
    sash = fig.mats["sash"]
    cd = R["cd"]
    px, py = R["perp"]

    def T(t, w):
        return tp(t, w * s)

    def NP(h, w):
        return (R["neck"][0] + cd[0] * h * s + px * w * s, R["neck"][1] + cd[1] * h * s + py * w * s)

    # ---- back limbs
    ilse_arm(fig, R, "b", 1.2)
    ilse_leg(fig, R, "b", 1.0)

    # ---- torso (coat bodice): chest, waist, rib cage, hips
    tbl = [(0.02, 6.8, 7.3), (0.14, 5.9, 6.3), (0.28, 4.3, 4.5), (0.42, 5.5, 4.9), (0.55, 7.3, 5.3),
           (0.66, 7.9, 5.6), (0.78, 6.7, 6.1), (0.90, 5.1, 5.5), (0.99, 3.3, 3.9)]
    fr = [T(t, f) for t, f, b in tbl]
    bk = [T(t, -b) for t, f, b in tbl]
    tor = fk.smooth(fr + bk[::-1], 4, True, corners=(0, len(fr) - 1, len(fr), 2 * len(fr) - 1))
    # key light is upper-left (behind her): the belly side below the bust falls into shadow
    sh_back = [T(-0.1, 9), T(0.50, 9), T(0.56, 3.4), T(0.44, 1.6), T(0.28, 0.8), T(-0.1, 1.4)]
    sh_under = [T(0.50, 2), T(0.62, 4.0), T(0.7, 7.5), T(0.42, 8), T(0.40, 3)]
    spun = abs(fk.spin()) > 30
    if spun:        # tipped onto her back: the light now falls on her front, the side resting toward the ground is shaded
        tor_sh = [fk.smooth([T(-0.1, -9), T(1.1, -9), T(1.1, -2.8), T(0.5, -1.4), T(-0.1, -2.8)], 3, True)]
    else:
        tor_sh = [fk.smooth(sh_back, 3, True), fk.smooth(sh_under, 3, True)]
    fk.shape_draw(fig, tor, coat, 3.0, shades=tor_sh, ol=INNER)
    # shirt V and gold lapel trim
    vee = fk.smooth([T(0.99, -3.2), T(0.99, 3.0), T(0.78, 1.6), T(0.62, 0.3), T(0.80, -1.2)], 4, True, corners=(0, 1, 3))
    fk.shape_draw(fig, vee, shirt, 3.1, ol=1.0)
    fk.stroke(fig, fk.smooth([T(0.99, 3.3), T(0.80, 2.3), T(0.60, 1.0), T(0.50, 0.3)], 4, False), 1.0, 0.9, gold.base, 3.15)
    fk.stroke(fig, fk.smooth([T(0.99, -3.5), T(0.82, -1.9), T(0.62, -0.5), T(0.50, 0.2)], 4, False), 1.0, 0.9, gold.base, 3.15)
    # gold princess seam / piping on the bodice front
    # medallion
    mc = T(0.66, 3.3)
    disc(fig, mc, 2.6 * s / 1.6, "gold", 3.4, ol=1.0)
    disc(fig, mc, 1.5 * s / 1.6, "gem", 3.45, ol=0)
    disc(fig, add(mc, (-0.7, -0.9)), 0.7, None, 3.5, ol=0, flat=(255, 255, 255))
    # ---- front leg then a cutaway coat skirt on top (front rides high, tails fall behind)
    ilse_leg(fig, R, "f", 3.15)
    F = add(add(R["hip_f"], rs.vec(R["legs"]["f"][0] * 0.5, R["thigh"] * 0.34)), (3.6 * s, 0))
    tail = add(add(R["hip_b"], rs.vec(R["legs"]["b"][0] * 0.7 - 5, R["thigh"] * 0.98)), (-4.0 * s, 0))
    q1 = add(lerp(F, tail, 0.34), (-0.6 * s, 2.0 * s))
    q2 = add(lerp(F, tail, 0.68), (0.4 * s, 2.0 * s))
    sk = [T(0.30, 4.7), T(0.20, 6.4), add(F, (0.8 * s, -1.5 * s)), F, q1, q2, tail, add(tail, (-1.0 * s, -6 * s)),
          T(0.06, -7.4), T(0.18, -6.6), T(0.30, -4.9)]
    skirt = fk.smooth(sk, 5, True, corners=(3, 6))
    # upper-left key light: the facing (front) panel and the underside of the hem are in shadow, the back panel is lit
    sh_sk = [T(0.31, 1.2), T(0.20, 7.4), add(F, (2.0 * s, -1.5 * s)), add(F, (1.0 * s, 2.0 * s)), add(q1, (0.0, 3.0 * s)),
             add(q2, (0.0, 3.0 * s)), add(tail, (0.0, 3.0 * s)), add(q2, (-0.6 * s, -2.4 * s)), add(q1, (-1.6 * s, -3.4 * s)), T(0.14, 2.2)]
    hi_sk = [T(0.29, -4.6), T(0.17, -6.4), lerp(T(0.06, -7.4), tail, 0.55), add(lerp(T(0.06, -7.4), tail, 0.55), (1.6 * s, -0.4 * s)),
             T(0.18, -4.6)]
    if spun:
        back_w = T(0.06, -7.4)
        sh_sk = [T(0.32, -2.4), add(q2, (-0.8 * s, -2.6 * s)), add(q2, (0.0, 3.0 * s)), add(tail, (0.0, 3.0 * s)),
                 add(tail, (-4.0 * s, -6.0 * s)), add(back_w, (-3.0 * s, 0.0)), T(0.32, -8.0)]
        fk.shape_draw(fig, skirt, coat, 3.3, shades=[fk.smooth(sh_sk, 3, True)], ol=INNER)
    else:
        fk.shape_draw(fig, skirt, coat, 3.3, shades=[fk.smooth(sh_sk, 3, True)], his=[fk.smooth(hi_sk, 3, True)], ol=INNER)
    hem_line = fk.smooth([F, q1, q2, tail], 5, False, corners=())
    fk.stroke(fig, hem_line, 1.25, 1.25, gold.base, 3.35)
    fk.stroke(fig, fk.smooth([T(0.30, 4.8), T(0.20, 6.5), add(F, (0.8 * s, -1.5 * s)), F], 5, False), 1.1, 1.1, gold.base, 3.35)
    # ---- sash
    belt = [T(0.33, -5.0), T(0.33, 5.0), T(0.22, 5.6), T(0.22, -5.4)]
    fk.shape_draw(fig, fk.smooth(belt, 4, True, corners=(0, 1, 2, 3)), sash, 3.5, ol=1.2)
    fk.stroke(fig, [T(0.33, -5.0), T(0.33, 5.0)], 0.9, 0.9, gold.base, 3.52)
    fk.stroke(fig, [T(0.22, -5.4), T(0.22, 5.6)], 0.9, 0.9, gold.base, 3.52)
    # buckle
    bc = T(0.275, 4.4)
    disc(fig, bc, 2.5 * s / 1.6, "gold", 3.6, ol=1.0)
    disc(fig, bc, 1.2 * s / 1.6, "gem", 3.65, ol=0)
    # tassels
    for dx, L in ((0.0, 15),):
        a0 = add(bc, (dx * s * 0.5 + 0.5 * s, 1.8 * s))
        fk.stroke(fig, [a0, add(a0, (dx * 0.3 + 0.6, L * s / 2.1))], 1.6, 1.0, gold.base, 3.7)
        disc(fig, add(a0, (dx * 0.3 + 0.7, L * s / 2.1 + 2)), 2.0 * s / 1.6, "gold", 3.72, ol=1.0)
    # ---- neck and high collar
    N = fk.tube([add(R["neck"], (0, 1.5 * s)), fk.head_pt(R, 0.0, 1.0)], [(0, 2.4 * s), (1, 2.1 * s)], caps=(False, False))
    fk.tube_draw(fig, N, skin, 3.7, k=0.55, ol=INNER)
    col = [NP(-1.6, -3.9), NP(3.2, -3.4), NP(3.4, 2.3), NP(1.8, 3.0), NP(-1.6, 4.2)]
    colp = fk.smooth(col, 3, True, corners=(0, 1, 2, 3, 4))
    sh = [NP(-1.6, -4), NP(3.4, -4), NP(3.4, -2.2), NP(-1.6, -1.8)]
    fk.shape_draw(fig, colp, coat, 3.85, shades=[sh], ol=1.3)
    fk.stroke(fig, [NP(3.2, -3.4), NP(3.4, 2.3), NP(1.8, 3.0)], 1.0, 1.0, gold.base, 3.9)
    fk.stroke(fig, [NP(-1.6, 4.2), NP(1.8, 3.0)], 0.9, 0.9, gold.base, 3.9)


def hstrand(R, fd_pts, w, n=5):
    """Pointed hair lock along head-local control points; returns tube dict."""
    r = R["hr"]
    path = [fk.head_pt(R, f, d) for f, d in fd_pts]
    return fk.tube(path, [(0, w * r), (0.55, w * 0.78 * r), (1.0, 0.03 * r)], n=n, caps=(True, False))


def ilse_hair(fig, R):
    r = R["hr"]
    HP = lambda f, d: fk.head_pt(R, f, d)
    hair = fig.mats["hair"]
    gold = fig.mats["gold"]
    O = 1.1
    # swept-back mass hugging the skull, converging on the nape where the braid starts
    back = fk.hpoly(R, [(0.05, -1.10), (-0.55, -1.08), (-1.00, -0.66), (-1.16, -0.10), (-1.08, 0.40), (-0.92, 0.70),
                     (-0.62, 0.62), (-0.30, 0.2), (0.0, -0.1)], 5)
    fk.shape_draw(fig, back, hair, 3.95,
               shades=[fk.hpoly(R, [(-1.6, 0.0), (-0.5, 0.1), (-0.65, 1.0), (-1.6, 1.0)], 4)], ol=O)
    # skull cap with a clean hairline; sideburn hides the ear
    cap_ = fk.hpoly(R, [(0.92, -0.60), (0.86, -0.90), (0.50, -1.14), (-0.18, -1.22), (-0.80, -1.04), (-1.08, -0.55),
                     (-1.04, 0.10), (-0.84, 0.50), (-0.50, 0.58), (-0.30, 0.38), (-0.27, -0.05), (-0.16, -0.44),
                     (0.20, -0.70), (0.60, -0.74)], 5, corners=(0,))
    sh1 = fk.hpoly(R, [(-1.5, 0.02), (-0.86, -0.16), (-0.44, -0.30), (-0.10, -0.52), (0.1, -0.2), (-0.2, 0.9), (-1.5, 0.9)], 4)
    fk.shape_draw(fig, cap_, hair, 5.0, shades=[sh1], ol=O)
    # flow lines sweeping back from the parting
    fk.shine(fig, R, [(-0.98, -0.42), (-0.78, -0.70), (-0.52, -0.74), (-0.26, -0.90), (0.0, -0.84), (0.26, -0.92)],
                  fk.shine_tone(hair), 5.02, cap_, w=0.11)
    # side-swept bangs: three pointed clumps, back to front, each casting a shadow behind it
    capc = cap_
    clumps = (
        ([(0.14, -1.00), (-0.18, -0.88), (-0.32, -0.52), (-0.30, -0.20), (-0.19, -0.42), (-0.05, -0.60), (0.10, -0.72)], 3, 5.05),
        ([(-0.12, -1.02), (0.28, -0.96), (0.46, -0.68), (0.50, -0.34), (0.34, -0.46), (0.14, -0.62), (-0.08, -0.74)], 3, 5.09),
        ([(0.24, -1.02), (0.64, -0.92), (0.80, -0.66), (0.81, -0.34), (0.66, -0.44), (0.50, -0.60), (0.32, -0.74)], 3, 5.13),
        ([(0.60, -0.94), (0.86, -0.82), (0.96, -0.58), (0.95, -0.38), (0.85, -0.48), (0.75, -0.64), (0.66, -0.74)], 3, 5.17),
    )
    for fd, tipi, lay in clumps:
        poly = fk.hpoly(R, fd, 4, corners=(tipi,))
        line = fk.hpoly(R, fd, 4, corners=(tipi,), closed=False)
        low = fd[tipi:]
        shp = fk.hpoly(R, low + [(f, d - 0.17) for f, d in reversed(low)], 3, corners=(0, len(low) - 1, len(low), 2 * len(low) - 1))
        sx_, sy_ = fk.lv((1.0, 2.2))
        sd = [(x + sx_, y + sy_) for x, y in poly]
        fk.fillp(fig, sd, hair.shadow, lay - 0.015, clip=capc)
        fk.outline(fig, line, lay, O, closed=False, col=fk.olcol(hair))
        fk.fillp(fig, poly, hair.base, lay)
        fk.fillp(fig, shp, hair.shadow, lay + 0.001, clip=poly)
    # slim lock framing the cheek, in front of the sideburn
    T = hstrand(R, [(-0.24, -0.30), (-0.22, 0.10), (-0.25, 0.70), (-0.36, 1.25)], 0.12)
    fk.tube_draw(fig, T, hair, 5.2, ol=O, k=0.5, open_root=True, u0=0.15)
    # hair clip
    fk.stroke(fig, [HP(-0.74, -0.64), HP(-0.86, -0.24)], r * 0.12, r * 0.12, OUTLINE, 5.3)
    fk.stroke(fig, [HP(-0.74, -0.64), HP(-0.86, -0.24)], r * 0.08, r * 0.08, gold.base, 5.35)


def ilse_shoulder(fig, R):
    """Gold epaulette crescent over the front shoulder with a tassel."""
    s = R["s"]
    gold = fig.mats["gold"]
    sh = R["sh_f"]
    outer = [(sh[0] + math.cos(math.radians(a)) * 4.9 * s, sh[1] + math.sin(math.radians(a)) * 4.4 * s)
             for a in range(185, 356, 17)]
    cin = (sh[0] + 0.5 * s, sh[1] + 1.3 * s)
    inner = [(cin[0] + math.cos(math.radians(a)) * 3.5 * s, cin[1] + math.sin(math.radians(a)) * 3.2 * s)
             for a in range(350, 189, -17)]
    poly = fk.smooth(outer + inner, 3, True, corners=(0, len(outer) - 1, len(outer), len(outer) + len(inner) - 1))
    fk.shape_draw(fig, poly, gold, 6.7, shades=[fk.smooth([(sh[0] - 6 * s, sh[1] - 6 * s), (sh[0] + 1 * s, sh[1] - 6 * s),
                                                      (sh[0] + 0.5 * s, sh[1] - 1.0 * s), (sh[0] - 6 * s, sh[1] + 1 * s)], 3, True)],
               ol=1.1)
    a0 = outer[0]
    fk.stroke(fig, [add(a0, (0.5, 0.5)), add(a0, (-0.6, 6.0 * s))], 1.3, 0.9, gold.base, 6.72)
    disc(fig, add(a0, (-0.8, 6.8 * s)), 1.9 * s / 1.6, "gold", 6.74, ol=1.0)


def ring(fig, c, r, sx, sy, rot_, w, col, layer, n=28, arc=(0, 360)):
    pts = [(c[0] + math.cos(math.radians(a)) * r * sx * math.cos(rot_) - math.sin(math.radians(a)) * r * sy * math.sin(rot_),
            c[1] + math.cos(math.radians(a)) * r * sx * math.sin(rot_) + math.sin(math.radians(a)) * r * sy * math.cos(rot_))
           for a in [arc[0] + (arc[1] - arc[0]) * i / n for i in range(n + 1)]]
    fk.stroke(fig, pts, w, w, col, layer)


def ilse_orb(fig, R, g, gh):
    """Her focus: a small orb hovering over the front palm, swelling in front of it when she casts.
    When the hand is raised to head height or above, the orb drifts out in front of the palm instead."""
    s = R["s"]
    palm = R["palm"]
    if R["pose"]["glow"] in CAST_GLOW:
        oc, r0, halo = add(palm, (11 * s, -1)), 7.5 * s, 16 * s
    else:
        high = max(0.0, min(1.0, (R["hc"][1] + 1.6 * R["hr"] - palm[1]) / (2.2 * R["hr"])))
        oc, r0, halo = add(palm, (2 + 11 * s * high, -12.5 * s * (1 - 0.8 * high))), 5.4 * s, 15 * s
    fig.glow(oc, halo, gh, g, 1.6)
    # arcane rings orbiting the sphere, thin and bright
    ring(fig, oc, r0 * 1.55, 1.0, 0.34, math.radians(-24), 0.8, gh, 7.0, arc=(200, 520))
    ring(fig, oc, r0 * 1.9, 1.0, 0.30, math.radians(28), 0.6, g, 7.0, arc=(40, 300))
    fig.orb(oc, r0, (255, 255, 255), g)


def draw_ilse(fig, R, face, glow, glow_hi):
    ilse_tails(fig, R)
    ilse_body(fig, R)
    fk.head34(fig, R, face, fig.mats["skin"], 4.0, ol=INNER)
    ilse_hair(fig, R)
    ilse_arm(fig, R, "f", 6.0)
    ilse_shoulder(fig, R)
    if R["ctx"]["focus"]:
        ilse_orb(fig, R, glow, glow_hi)
    if R["pose"]["glow"] == "foot":
        fig.glow(add(R["ankle_f"], (2 * R["s"], 2 * R["s"])), 11 * R["s"], glow_hi, glow, 1.8)


# ------------------------------------------------------------------ ROOK: plate-armoured rocket knight
ROOK = dict(
    height=83, build=1.3, head=10.1, chest=0.95, waist=0.9, limb=0.88, torso=1.1, leg=0.93, sole=9.8,
    mats={
        "steel": M((178, 198, 236), (104, 124, 190), (255, 255, 255), hi_t=0.9),
        "dark": M((66, 84, 160), (40, 48, 110), (120, 140, 214)),
        "trim": M((250, 196, 62), (190, 118, 30), (255, 240, 160), hi_t=0.9),
        "cape": M((232, 46, 62), (156, 20, 62), (255, 130, 120), hi_t=0.97),
    },
    mats2={
        "steel": M((250, 192, 56), (196, 112, 26), (255, 244, 170), hi_t=0.9),
        "trim": M((250, 244, 230), (186, 180, 204), (255, 255, 255), hi_t=0.9),
        "dark": M((30, 110, 128), (16, 66, 96), (90, 190, 200)),
        "cape": M((20, 180, 160), (12, 112, 124), (120, 240, 210), hi_t=0.97),
    },
    glow=(255, 70, 60), glow_hi=(255, 196, 180), glow2=(60, 240, 255), glow2_hi=(210, 255, 255),
    face=dict(skin="skin"),
)


def dk(m, k=0.0):
    """Darkened shadow tone of a material, for flat engraved lines."""
    return rs.mix(m.shadow, (8, 8, 20), k)


def hl(m):
    return m.hi if m.hi else m.base


def pt(o, d, n, a, b):
    """Point at o + d*a + n*b."""
    return (o[0] + d[0] * a + n[0] * b, o[1] + d[1] * a + n[1] * b)


def rook_cape(fig, R):
    """One heavy cape hanging from the shoulders (a single mass, so it cannot read as extra limbs)."""
    s = R["s"]
    cape = fig.mats["cape"]
    flow, sway = R["ctx"]["flow"], R["ctx"]["sway"]
    start = add(R["neck"], (-5.5 * s, 3.0 * s))
    short = 0.8 if R["ctx"]["hang"] is not None else 1.0     # a tumbling body bunches the cape up
    path = wave(start, cloth_theta(R, 104, 34, lo=96), 50 * s * (1 - 0.08 * flow) * short, 7, 7, 0.9, 0.6 + sway,
                droop=-flow * 10)
    path = settle(R, path, 9.5 * s)
    T = fk.tube(path, [(0, 5.0 * s), (0.35, 8.0 * s), (0.8, 10.0 * s), (1.0, 9.0 * s)], n=6, caps=(False, False))
    fk.tube_draw(fig, T, fk.far(cape, 0.25), 0.8, k=0.34, ol=INNER)
    m = len(T["C"])
    for off, a0, a1 in ((0.2, 0.3, 0.97),):
        pts = [fk.offs(T["C"][j], T["N"][j], T["W"][j] * off) for j in range(int(m * a0), int(m * a1))]
        fk.stroke(fig, pts, 0.5, 1.0, cape.shadow, 0.82)


def rook_leg(fig, R, side, layer):
    """Plate leg: mail thigh under a shaped cuisse, winged poleyn, greave with a calf swell, pointed sabaton."""
    u = R["s"]
    back = side == "b"
    hp, knee, ankle = R["hip_" + side], R["knee_" + side], R["ankle_" + side]
    L0 = layer
    steel, dark, trim = fig.mats["steel"], fig.mats["dark"], fig.mats["trim"]
    if back:
        steel, dark, trim = fk.far(steel, 0.5), fk.far(dark, 0.4), fk.far(trim, 0.5)
    Th = fk.tube([hp, knee], [(0, 8.0 * u), (1.0, 5.6 * u)], n=4)
    fk.tube_draw(fig, Th, dark, L0, k=0.4, ol=INNER)
    Cu = fk.tube([lerp(hp, knee, 0.10), lerp(hp, knee, 0.86)], [(0, 8.3 * u), (0.45, 7.7 * u), (1.0, 6.0 * u)], n=5,
                 caps=(False, False))
    fk.tube_draw(fig, Cu, steel, L0 + 0.1, k=0.36, hi=True, ol=1.2)
    Gr = fk.tube([knee, lerp(knee, ankle, 0.5), ankle], [(0, 5.8 * u), (0.30, 6.5 * u), (0.72, 5.0 * u), (1.0, 4.3 * u)], n=6,
                 caps=(True, False))
    fk.tube_draw(fig, Gr, steel, L0 + 0.12, k=0.36, hi=True, ol=INNER)
    # sabaton: pointed toe, lames over the instep, heel block, sole
    L = fk.foot_frame(R, side, 1.42, lo=0.0, hi=34.0)
    pts = [L(-3.2, 1.2), L(-3.7, 4.6), L(-3.4, 6.7), L(-0.8, 6.9), L(3.0, 6.4), L(8.0, 6.6), L(12.4, 6.5), L(15.4, 6.2),
           L(12.6, 4.2), L(9.2, 2.6), L(6.2, 0.9), L(4.0, -1.4), L(3.2, -3.0), L(-2.8, -3.0)]
    poly = fk.smooth(pts, 4, True, corners=(2, 3, 7, 12, 13))
    fk.cel_shape(fig, poly, steel, L0 + 0.2, ol=INNER, shift=(1.4, 1.8))
    fk.fillp(fig, [L(-5, 5.5), L(16, 5.6), L(16, 8), L(-5, 8)], trim.shadow, L0 + 0.205, clip=poly)
    fk.fillp(fig, [L(-5, 4.0), L(-1.0, 4.0), L(-0.8, 8), L(-5, 8)], trim.base, L0 + 0.206, clip=poly)
    fk.ground(R, poly)
    # ankle band
    A = fk.tube([lerp(knee, ankle, 0.82), lerp(knee, ankle, 1.0)], [(0, 5.2 * u), (1.0, 5.2 * u)], n=3, caps=(False, False))
    fk.tube_draw(fig, A, trim, L0 + 0.3, k=0.4, ol=1.1)
    # poleyn with a side wing
    d = fk.unit(hp, knee)
    fn = (-d[1], d[0])
    if fn[0] < 0:
        fn = (-fn[0], -fn[1])
    Kp = lambda a_, b_: fk.offs(fk.offs(knee, d, a_ * u), fn, b_ * u)
    pol = fk.smooth([Kp(-5.8, -4.6), Kp(-6.0, 3.4), Kp(-2.6, 7.8), Kp(2.6, 7.2), Kp(5.6, 3.8), Kp(5.6, -4.6)], 4, True, corners=(0, 5))
    fk.cel_shape(fig, pol, steel, L0 + 0.32, ol=1.2, shift=(1.5, 1.7))


def rook_arm(fig, R, side, layer, far=False):
    """Plate arm: mail sleeve, rerebrace, round couter, vambrace with a flared cuff, blocky gauntlet fist
    (or open palm). `far` tints it as the arm on the far side of the body."""
    u = R["s"]
    back = far
    sh, elbow, hand = R["sh_" + side], R["elbow_" + side], R["hand_" + side]
    steel, dark, trim = fig.mats["steel"], fig.mats["dark"], fig.mats["trim"]
    if back:
        steel, dark, trim = fk.far(steel, 0.5), fk.far(dark, 0.4), fk.far(trim, 0.5)
    U = fk.tube([sh, elbow], [(0, 5.4 * u), (1.0, 4.4 * u)], n=4)
    fk.tube_draw(fig, U, dark, layer, k=0.4, ol=INNER)
    Rb = fk.tube([lerp(sh, elbow, 0.22), lerp(sh, elbow, 0.84)], [(0, 5.9 * u), (1.0, 5.0 * u)], n=4, caps=(False, False))
    fk.tube_draw(fig, Rb, steel, layer + 0.1, k=0.36, hi=True, ol=1.2)
    F = fk.tube([elbow, lerp(elbow, hand, 0.5), hand], [(0, 4.9 * u), (0.45, 5.5 * u), (1.0, 4.5 * u)], n=5, caps=(True, False))
    fk.tube_draw(fig, F, steel, layer + 0.12, k=0.36, hi=True, ol=INNER)
    fk.cel_shape(fig, fk.circle(elbow, 5.3 * u, 16), steel, layer + 0.3, ol=1.2, shift=(1.6, 1.8))
    fk.cel_shape(fig, fk.circle(elbow, 2.2 * u, 10), trim, layer + 0.32, ol=0.9, shift=(0.8, 0.8))
    C = fk.tube([lerp(elbow, hand, 0.56), lerp(elbow, hand, 0.90)], [(0, 5.3 * u), (1.0, 6.3 * u)], n=3, caps=(False, False))
    fk.tube_draw(fig, C, trim, layer + 0.4, k=0.4, hi=True, ol=1.2)
    fd = fk.unit(elbow, hand)
    pp = (-fd[1], fd[0])
    hs = 1.2 * u
    if not R["pose"]["fist"]:
        open_hand(fig, hand, fd, 1.9 * u, steel, layer + 0.5, shift=(1.6, 1.8))
        return
    L = lambda a_, b_: (hand[0] + (fd[0] * a_ + pp[0] * b_) * hs, hand[1] + (fd[1] * a_ + pp[1] * b_) * hs)
    fist = fk.smooth([L(-1.4, -5.0), L(2.4, -5.8), L(6.4, -5.5), L(8.2, -3.4), L(8.4, 2.6), L(7.0, 5.2), L(2.6, 5.8),
                      L(-1.4, 5.0)], 4, True)
    fk.cel_shape(fig, fist, steel, layer + 0.5, ol=INNER, shift=(1.6, 1.8))
    for v in (-1.7, 1.9):
        fk.stroke(fig, [L(8.2, v * 0.9), L(5.0, v)], 0.7, 0.5, fk.linec(steel), layer + 0.52)


def rook_pauldron(fig, c, S, layer, back=False):
    """Spaulder: smooth dome with a trim rim and two lames underneath."""
    steel, trim = fig.mats["steel"], fig.mats["trim"]
    if back:
        steel, trim = fk.far(steel, 0.5), fk.far(trim, 0.5)
    P = lambda x, y: (c[0] + x * S, c[1] + y * S)
    lame1 = fk.smooth([P(-1.38, 0.3), P(1.38, 0.3), P(1.22, 1.08), P(0.0, 1.24), P(-1.22, 1.08)], 3, True, corners=(0, 1))
    fk.cel_shape(fig, lame1, trim, layer - 0.02, ol=1.2, shift=(S * 0.14, S * 0.16))
    dome = fk.smooth([P(-1.52, 0.46), P(-1.46, -0.34), P(-0.92, -0.98), P(0.0, -1.2), P(0.92, -0.98), P(1.46, -0.34),
                      P(1.52, 0.46), P(0.0, 0.66)], 4, True, corners=(0, 6))
    hi = fk.smooth([P(-1.05, -0.5), P(-0.5, -0.95), P(0.2, -1.02), P(-0.4, -0.7), P(-0.85, -0.2)], 3, True)
    fk.cel_shape(fig, dome, steel, layer, ol=INNER, shift=(S * 0.2, S * 0.22), hi=hi)
    fk.stroke(fig, fk.smooth([P(-1.44, 0.34), P(0.0, 0.52), P(1.44, 0.34)], 4, False), 0.9, 0.9, trim.base, layer + 0.01)


def rook_body(fig, R, glow, glow_hi):
    s, tp = R["s"], R["tp"]
    cw, ww = R["chest_w"], R["waist_w"]
    lr = R["limb_r"]
    # the lead arm (rig side "f", shoulder on the facing side of the chest) is the far arm of the 3/4 view: it
    # starts behind the breastplate and comes out ahead of it; the rear arm (side "b") is the near one, drawn
    # over the torso from its own shoulder in draw_rook
    rook_arm(fig, R, "f", 1, far=True)
    rook_pauldron(fig, add(R["sh_f"], (-1.0 * s, -0.5 * s)), lr * 1.05, 1.6, True)
    u = s
    T = lambda t, w: tp(t, w * u)
    steel, dark, trim = fig.mats["steel"], fig.mats["dark"], fig.mats["trim"]
    rook_leg(fig, R, "b", 1)
    # padded undersuit torso (one smooth silhouette)
    tbl = [(-0.02, 10.6, 10.6), (0.20, 10.8, 10.2), (0.36, 11.6, 10.6), (0.62, 15.8, 13.6), (0.80, 16.4, 14.8),
           (0.92, 13.8, 14.2), (1.00, 8.4, 9.4)]
    fr = [T(t, f) for t, f, b in tbl]
    bk = [T(t, -b) for t, f, b in tbl]
    tor = fk.smooth(fr + bk[::-1], 4, True, corners=(0, len(fr) - 1, len(fr), 2 * len(fr) - 1))
    fk.cel_shape(fig, tor, dark, 3.0, ol=INNER, shift=(2.0, 1.8))
    # tabard cloth hanging from the belt
    H0 = R["hip"]
    tab = [add(H0, (-ww * 0.5, -2)), add(H0, (ww * 1.0, -2)), add(H0, (ww * 1.18, 40 * s / 2 * 1.5)),
           add(H0, (-ww * 0.2, 44 * s / 2 * 1.5))]
    tab_ax = (0, 44 * s / 2 * 1.5)
    tip = min(1.0, abs(R["ctx"]["spin"]) / 90.0)
    if tip:
        # tipped back or lying, the cloth no longer hangs toward his feet: it lies shorter across the lap and
        # sags toward the ground
        kl, ks = 1.0 - 0.4 * tip, 0.62 * tip
        lie = lambda p_: add(H0, ((p_[0] - H0[0]) - ks * (p_[1] - H0[1]) * kl, (p_[1] - H0[1]) * kl))
        tab = [tab[0], tab[1], lie(tab[2]), lie(tab[3])]
        tab_ax = (-ks * tab_ax[1] * kl, tab_ax[1] * kl)
    quad(fig, tab, "cape", 3.35, add(H0, (0, 0)), add(H0, tab_ax), ww * 0.9)
    cap(fig, tab[3], tab[2], 1.6, 1.6, None, 3.4, ol=0, flat=hl(trim))
    # breastplate: rounded barrel with a keel ridge toward the facing side (3/4 turn)
    bp = fk.smooth([T(0.34, -10.8), T(0.34, 11.9), T(0.60, 15.9), T(0.80, 16.6), T(0.93, 13.6), T(1.00, 8.0), T(1.00, -9.0),
                    T(0.92, -14.3), T(0.80, -15.0), T(0.60, -13.6)], 4, True, corners=(0, 1))
    hi = fk.smooth([T(0.95, -10.5), T(0.97, -3.0), T(0.90, 1.5), T(0.62, 1.0), T(0.44, -1.5), T(0.70, -4.0), T(0.86, -9.0)], 3, True)
    fk.cel_shape(fig, bp, steel, 3.2, ol=INNER, shift=(3.0, 2.6), hi=hi)
    fk.stroke(fig, fk.smooth([T(0.99, 4.6), T(0.70, 6.6), T(0.36, 5.6)], 4, False), 0.9, 0.9, steel.shadow, 3.26)
    # plackart band + waist belt
    plb = [tp(0.34, -0.7 * cw), tp(0.34, 0.86 * cw), tp(0.2, 0.9 * cw), tp(0.2, -0.74 * cw)]
    quad(fig, plb, "trim", 3.3, tp(0.2, 0), tp(0.34, 0), cw * 0.8)
    # core gem
    gc = T(0.56, 0.5)
    disc(fig, gc, 5.2, "trim", 3.4, ol=1.0)
    disc(fig, gc, 3.2, None, 3.45, ol=0, flat=glow)
    disc(fig, add(gc, (-0.8, -0.9)), 1.2, None, 3.5, ol=0, flat=glow_hi)
    # belt and fauld lames
    for k, (t0, t1, m, w) in enumerate(((0.07, -0.08, "trim", 1.12), (-0.05, -0.2, "steel", 1.16))):
        pts = [tp(t0, -ww * w), tp(t0, ww * w), tp(t1, ww * (w + 0.04)), tp(t1, -ww * (w + 0.04))]
        quad(fig, pts, m, 3.5 + k * 0.01, tp(t1, 0), tp(t0, 0), ww * w)
    cap(fig, tp(0.08, -ww * 1.1), tp(0.08, ww * 1.1), 3.0 * s / 2, 3.0 * s / 2, "trim", 3.53)
    disc(fig, tp(0.08, ww * 0.55), 4.2, "steel", 3.56, ol=1.0)
    cap(fig, R["hip_b"], R["hip_f"], ww * 0.55, ww * 0.55, "dark", 3)
    # neck (mail) + gorget collar
    Nk = fk.tube([add(R["neck"], (0, 1.0 * u)), fk.head_pt(R, -0.05, 0.8)], [(0, 4.6 * u), (1, 4.2 * u)], caps=(False, False))
    fk.tube_draw(fig, Nk, dark, 3.7, k=0.5, ol=INNER)
    N = R["neck"]
    G = fk.tube([add(N, (-6.6 * u, 1.2 * u)), add(N, (0.0, 2.6 * u)), add(N, (6.4 * u, 1.4 * u))],
                [(0, 2.6 * u), (0.5, 3.2 * u), (1.0, 2.6 * u)], n=5)
    fk.tube_draw(fig, G, trim, 3.8, k=0.4, hi=True, ol=INNER)
    rook_leg(fig, R, "f", 5)
    # front tasset hanging over the thigh
    hp, kn = R["hip_f"], R["knee_f"]
    d = (kn[0] - hp[0], kn[1] - hp[1])
    ln = math.hypot(*d)
    d = (d[0] / ln, d[1] / ln)
    n = (d[1], -d[0])
    if n[0] < 0:
        n = (-n[0], -n[1])
    w1, w2, Lt = lr * 1.5, lr * 1.3, ln * 0.52
    t0 = [pt(hp, d, n, -2, -w1 * 0.9), pt(hp, d, n, -2, w1 * 1.05), pt(hp, d, n, Lt * 0.82, w2 * 1.0),
          pt(hp, d, n, Lt * 1.1, 0.05 * w2), pt(hp, d, n, Lt * 0.82, -w2 * 0.95)]
    quad(fig, t0, "steel", 5.3, pt(hp, d, n, Lt, 0), hp, w1)
    cap(fig, pt(hp, d, n, 4, w1 * 0.7), pt(hp, d, n, Lt * 0.8, w2 * 0.66), 1.2, 1.0, None, 5.35, ol=0, flat=hl(steel))
    cap(fig, pt(hp, d, n, Lt * 0.1, -w1 * 0.9), pt(hp, d, n, Lt * 0.1, w1 * 1.0), 1.0, 1.0, None, 5.35, ol=0,
        flat=dk(steel, 0.1))


def rook_helmet(fig, R, glow):
    """Great helm in the shared 3/4 view: keel ridge off-centre toward the facing side, ONE visor slit that
    wraps from the near cheek across the keel to the far edge, breaths on the near cheek, plume from the crown."""
    r = R["hr"]
    steel, trim, cape = fig.mats["steel"], fig.mats["trim"], fig.mats["cape"]
    H = lambda f, d: fk.head_pt(R, f, d)
    sh = (0.10 * r, 0.11 * r)
    # plume: horsehair crest rising from the crown and sweeping back
    # (on a helm resting on the ground the crest cannot sweep down past the back of it: it flattens along the floor)
    sq = (lambda f, d: (-1.25 + (f + 1.25) * 0.25 if f < -1.25 else f, d)) if R["ctx"]["flat"] else (lambda f, d: (f, d))
    plume = fk.hpoly(R, [sq(*q) for q in [(0.16, -1.12), (-0.02, -1.74), (-0.66, -2.12), (-1.50, -1.96), (-2.12, -1.26),
                                          (-2.36, -0.30), (-1.92, -0.92), (-1.40, -1.26), (-0.84, -1.30), (-0.44, -1.06)]],
                     5, corners=(5,))
    fk.cel_shape(fig, plume, cape, 4.4, ol=INNER, shift=sh)
    for pts in ([(-0.20, -1.32), (-0.80, -1.62), (-1.46, -1.50), (-2.00, -0.90)],):
        fk.stroke(fig, fk.hpoly(R, [sq(*q) for q in pts], 4, closed=False), r * 0.035, r * 0.015, cape.shadow, 4.42)
    # shell
    shell = fk.hpoly(R, [(-0.96, -0.56), (-0.70, -1.00), (-0.14, -1.20), (0.46, -1.12), (0.88, -0.80), (1.02, -0.30),
                         (1.00, 0.26), (0.90, 0.74), (0.62, 1.10), (0.18, 1.04), (-0.46, 0.84), (-1.02, 0.70), (-1.06, 0.02)],
                     5, corners=(8, 11))
    hi = fk.hpoly(R, [(-0.80, -0.62), (-0.56, -0.98), (-0.06, -1.10), (0.30, -1.04), (-0.10, -0.92), (-0.50, -0.70), (-0.70, -0.36)], 4)
    fk.cel_shape(fig, shell, steel, 4.6, ol=INNER, shift=sh, hi=hi)
    # bevor (lower face plate) in the trim metal
    bev = fk.hpoly(R, [(-1.2, 0.50), (-0.30, 0.44), (0.40, 0.50), (0.74, 0.40), (1.2, 0.42), (1.2, 1.4), (-1.2, 1.4)], 3,
                   corners=(3,))
    fk.fillp(fig, bev, trim.shadow, 4.62, clip=shell)
    bx_, by_ = fk.lv((-sh[0], -sh[1]))
    fk.fillp(fig, [(x + bx_, y + by_) for x, y in shell], trim.base, 4.621, clip=bev)
    fk.stroke(fig, fk.hpoly(R, [(-1.04, 0.50), (-0.30, 0.44), (0.40, 0.50), (0.74, 0.40), (1.00, 0.42)], 3, closed=False, corners=(3,)),
              r * 0.03, r * 0.03, fk.olcol(steel), 4.63)
    # keel ridge
    fk.stroke(fig, fk.hpoly(R, [(0.50, -1.10), (0.70, -0.60), (0.76, 0.00), (0.74, 0.40), (0.64, 1.06)], 4, closed=False),
              r * 0.035, r * 0.035, steel.shadow, 4.64)
    fk.stroke(fig, fk.hpoly(R, [(0.44, -1.08), (0.63, -0.60), (0.69, -0.18)], 4, closed=False), r * 0.022, r * 0.022,
              steel.hi or steel.base, 4.64)
    # brow band
    bb = [(-0.98, -0.40), (-0.30, -0.44), (0.40, -0.40), (0.76, -0.46), (1.00, -0.40)]
    fk.stroke(fig, fk.hpoly(R, bb, 3, closed=False, corners=(3,)), r * 0.07, r * 0.07, fk.olcol(trim), 4.66)
    fk.stroke(fig, fk.hpoly(R, bb, 3, closed=False, corners=(3,)), r * 0.04, r * 0.04, trim.base, 4.67)
    # the single visor slit: near side long, dips at the keel, short foreshortened far side
    sp = fk.hpoly(R, [(-0.22, -0.08), (0.30, -0.06), (0.76, 0.02), (1.02, -0.07)], 4, closed=False, corners=(2,))
    fk.stroke(fig, sp, r * 0.15, r * 0.12, (40, 26, 76), 4.9)
    gl = fk.hpoly(R, [(-0.10, -0.08), (0.30, -0.06), (0.74, 0.02), (0.96, -0.06)], 4, closed=False, corners=(2,))
    fk.stroke(fig, gl, r * 0.075, r * 0.06, glow[0], 4.95)
    fk.stroke(fig, fk.hpoly(R, [(0.10, -0.075), (0.30, -0.065), (0.70, 0.005)], 3, closed=False), r * 0.025, r * 0.02, glow[1], 4.96)
    # breath holes on the near cheek
    for i in range(3):
        fk.stroke(fig, [H(0.04 + i * 0.21, 0.64 - i * 0.02), H(0.04 + i * 0.21, 0.86 - i * 0.02)], r * 0.035, r * 0.035,
                  fk.linec(trim, 0.5), 4.7)
    fig.glow(H(0.62, -0.03), r * 0.6, glow[1], glow[0], 2.6)



def draw_rook(fig, R, face, glow, glow_hi):
    s = R["s"]
    rook_cape(fig, R)
    rook_body(fig, R, glow, glow_hi)
    rook_arm(fig, R, "b", 6)
    rook_pauldron(fig, add(R["sh_b"], (-0.5 * s, -1.5 * s)), R["limb_r"] * 0.98, 6.2)
    rook_helmet(fig, R, (glow, glow_hi))
    where = R["pose"]["glow"]
    if where == "foot":
        fig.glow(add(R["ankle_f"], (2 * s, 2 * s)), 11 * s, glow_hi, glow, 1.8)
    elif where:                 # thruster flare just beyond the gauntlet
        oc = add(R["hand_f"], sc(fk.unit(R["elbow_f"], R["hand_f"]), 10.5 * s))
        fig.glow(oc, 10 * s, glow_hi, glow, 1.7)
        fig.orb(oc, 4.6 * s, (255, 255, 255), glow)


# ------------------------------------------------------------------ assembly
DESIGNS = {"kestrel": KESTREL, "bruno": BRUNO, "ilse": ILSE, "rook": ROOK}
_MATS = {}


def materials(fid, p2):
    """Stylised material table and face for a fighter's main (P1) or alternate (P2) costume."""
    key = (fid, bool(p2))
    if key not in _MATS:
        ch = DESIGNS[fid]
        mats = dict(ch["mats"])
        face = dict(ch["face"])
        if p2:
            mats.update(ch["mats2"])
            face.update(ch.get("face2", {}))
        _MATS[key] = (fk.stylize(mats), face)
    return _MATS[key]


def glow_colours(fid, p2):
    """(glow, glow_hi) effect colours of a costume."""
    ch = DESIGNS[fid]
    return (ch["glow2"], ch["glow2_hi"]) if p2 else (ch["glow"], ch["glow_hi"])


EXPRESSIONS = {
    "neutral": {},
    "hurt": dict(shut="wince", mouth="open", brow=-0.14),
    "out": dict(shut="rest", mouth="calm", brow=-0.06),
}


def build_raw(fid, pose, p2=False, ctx=None):
    """Posed figure in rig coordinates plus its rig (R["feet"] lists the sole lines)."""
    ctx = dict(CTX, **(ctx or {}))
    mats, face = materials(fid, p2)
    if ctx["expr"] != "neutral" and face.get("mouth") != "none":
        face = dict(face, **EXPRESSIONS[ctx["expr"]])
    elif ctx["expr"] != "neutral":
        face = dict(face, shut=EXPRESSIONS[ctx["expr"]]["shut"])
    fig = rs.Figure(mats)
    fk.set_spin(ctx["spin"])
    R = make_rig(DESIGNS[fid], pose, ctx)
    g, gh = glow_colours(fid, p2)
    DRAW[fid](fig, R, face, g, gh)
    return fig, R


DRAW = {"kestrel": draw_kestrel, "bruno": draw_bruno, "ilse": draw_ilse, "rook": draw_rook}
_AIR_DROP = {}


def air_drop(fid):
    """Vertical offset that puts a straight-legged standing rig's soles on the anchor line; airborne
    poses use it so a jump leaves the ground by exactly the pose's hy."""
    if fid not in _AIR_DROP:
        straight = dict(hx=0, hy=0, lean=0, head=0, fa=(0, 0), ba=(0, 0), fl=(0, 0), bl=(0, 0), glow=False, fist=True)
        _AIR_DROP[fid] = AY - max(build_raw(fid, straight)[1]["feet"])
    return _AIR_DROP[fid]


def build_figure(fid, pose, p2=False, ctx=None):
    """The posed fighter as a Figure in cell coordinates: grounded poses stand with their soles on the
    anchor line under (ANCHOR_X + hx), airborne ones hang above it, lying ones rest on their back."""
    fig, R = build_raw(fid, pose, p2, ctx)
    c = R["ctx"]
    if c["spin"]:
        hx, hy = R["hip"]
        ca, sa = math.cos(math.radians(c["spin"])), math.sin(math.radians(c["spin"]))
        fig = rs.transform_figure(fig, lambda x, y: (hx + (x - hx) * ca - (y - hy) * sa, hy + (x - hx) * sa + (y - hy) * ca))
    dx = 0.0
    if c["lying"]:
        x0, x1, _, y1 = rs.figure_bounds(fig)
        dx, dy = AX - (x0 + x1) / 2, AY - LIE_GAP - y1
    elif R["grounded"]:
        dy = AY - max(R["feet"])
    else:
        dy = air_drop(fid)
    return rs.transform_figure(fig, lambda x, y: (x + dx, y + dy))


def projectile(fid, p2, frame):
    """Projectile cell (frame 0 / 1) in the costume's glow colours, centred in the cell."""
    g, gh = glow_colours(fid, p2)
    core = rs.mix(gh, (255, 255, 255), 0.6)
    fig = rs.Figure()
    c = (AX, rs.CELL / 2)
    wob = 1.5 * K if frame else 0
    fig.glow(c, 34 + wob * 2, gh, g, 1.8)
    for i in range(5):
        a = i * 72 + frame * 36
        tail = add(c, rs.vec(-90 + (a % 360) * 0.18 - 32, 13 * K + wob))
        fig.streak(c, tail, 5.5 * K, 1.0 * K, gh, 0.75)
    if fid == "ilse":           # her shots are the orb she carries: same arcane rings
        r0 = 9.5 * K + wob
        ring(fig, c, r0 * 1.5, 1.0, 0.34, math.radians(-24 + frame * 50), 1.0, gh, 7.0, arc=(200, 520))
        ring(fig, c, r0 * 1.8, 1.0, 0.30, math.radians(28 - frame * 40), 0.8, g, 7.0, arc=(40, 300))
    fig.orb(c, 9.5 * K + wob, core, rs.mix(gh, g, 0.55))
    fig.orb((c[0] + K, c[1] - K), 5.5 * K, (255, 255, 255), core)
    return fig
