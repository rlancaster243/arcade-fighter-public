"""Shared shape and face kit for the four fighters (kestrel, bruno, ilse, rook).

Shape kit: smooth closed outlines, tapered tubes for limbs, and flat cel fills (base tone, one shadow tone
hugging the lower-right edges, optional highlight) drawn as polygons on the raster.Figure prim list.

Head kit: one head convention for the whole cast, a true 3/4 view facing +x. The near eye is full size, the
far eye is mirrored, foreshortened and tucked against the far cheek contour, the nose sits between them (no
profile nose on the silhouette), and the chin hangs under the face centre line. Key light: upper-left.
Everything on the head is placed in head-local coordinates, so it holds up at any head tilt.
"""
import colorsys
import math

from raster import Cel

INNER = 1.7                 # default contour width for kit shapes, texels
OUTLINE = (50, 34, 92)      # deep indigo: tinted, never black
INK = (52, 32, 78)
LIGHT2 = (-0.66, -0.75)     # screen direction pointing toward the key light (upper-left)
_SPIN = 0.0                 # degrees the figure being drawn will be rotated afterwards (see set_spin)


def set_spin(deg):
    """A tumbling or lying figure is drawn upright and rotated afterwards by `deg`. Everything that bakes the
    key light into geometry (cel shadows, tube shading, highlights) turns it the other way first, so the
    finished figure is still lit from the upper left."""
    global _SPIN
    _SPIN = float(deg)


def spin():
    return _SPIN


def lv(v):
    """A screen-space direction or offset expressed in the frame the figure is drawn in (before its spin)."""
    if not _SPIN:
        return v
    t = math.radians(-_SPIN)
    return (v[0] * math.cos(t) - v[1] * math.sin(t), v[0] * math.sin(t) + v[1] * math.cos(t))


def lturn(pts, about):
    """Turn a hand-placed highlight / shade polygon about `about` so it stays on the lit side after the spin."""
    if not _SPIN:
        return pts
    t = math.radians(-_SPIN)
    c, s_ = math.cos(t), math.sin(t)
    return [(about[0] + (x - about[0]) * c - (y - about[1]) * s_, about[1] + (x - about[0]) * s_ + (y - about[1]) * c)
            for x, y in pts]


def centre(pts):
    xs, ys = [p[0] for p in pts], [p[1] for p in pts]
    return ((min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2)


def add(a, b):
    return (a[0] + b[0], a[1] + b[1])


def head_pt(R, f, d):
    """Point in head-local coordinates (units of head radius): f forward, d downward."""
    t = math.radians(R["tilt"])
    r = R["hr"]
    return (R["hc"][0] + (math.cos(t) * f - math.sin(t) * d) * r,
            R["hc"][1] + (math.sin(t) * f + math.cos(t) * d) * r)


# ------------------------------------------------------------------ colour helpers
def mixc(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def far(m, k=0.5):
    """Slightly deeper variant for far-side parts (kept saturated: no muddy greys)."""
    k *= 0.62
    return Cel(mixc(m.base, m.shadow, k), mixc(m.shadow, (70, 40, 110), 0.07 + 0.06 * k),
               mixc(m.hi, m.base, 0.5) if m.hi else None)


def _hsv(c):
    return colorsys.rgb_to_hsv(c[0] / 255.0, c[1] / 255.0, c[2] / 255.0)


def _rgb(h, s, v):
    return tuple(255.0 * x for x in colorsys.hsv_to_rgb(h % 1.0, min(1.0, max(0.0, s)), min(1.0, max(0.0, v))))


def vivid(c, sat=1.14, lift=0.16):
    h, s, v = _hsv(c)
    if s > 0.07:
        s = s * sat + 0.03
    return _rgb(h, s, v + (1.0 - v) * lift)


def stylize(mats):
    """Bright flat-cel pass shared by the whole cast: saturated base, ONE clear shadow tone that stays
    colourful, and a crisp light highlight."""
    out = {}
    for name, m in mats.items():
        base = vivid(m.base)
        sh = vivid(mixc(m.shadow, m.base, 0.34), 1.10, 0.06)
        hi = mixc(m.hi, (255, 255, 255), 0.25) if m.hi else None
        out[name] = Cel(base, sh, hi, m.shadow_t, m.hi_t)
    return out


def fillp(fig, pts, col, layer, clip=None, alpha=1.0):
    fig.poly(pts, col, layer, clip, alpha)


def olcol(m):
    return mixc(m.shadow, OUTLINE, 0.58)


def linec(m, k=0.32):
    """Colour for the few interior detail lines (darker than the shadow tone, still tinted)."""
    return mixc(m.shadow, OUTLINE, k)


def outline(fig, pts, layer, w=INNER, closed=True, col=OUTLINE):
    n = len(pts)
    for i in range(n if closed else n - 1):
        fig.cap(pts[i], pts[(i + 1) % n], w, w, None, layer - 0.02, 0.0, 0, col)


def stroke(fig, pts, w0, w1, col, layer):
    n = len(pts) - 1
    for i in range(n):
        wa = w0 + (w1 - w0) * i / max(1, n)
        wb = w0 + (w1 - w0) * (i + 1) / max(1, n)
        fig.cap(pts[i], pts[i + 1], wa, wb, None, layer, 0.0, 0, col)


def smooth(pts, n=6, closed=True, corners=()):
    N = len(pts)
    out = []

    def P(i):
        return pts[i % N] if closed else pts[min(max(i, 0), N - 1)]

    for i in range(N if closed else N - 1):
        p0, p1, p2, p3 = P(i - 1), P(i), P(i + 1), P(i + 2)
        c1 = i in corners
        c2 = ((i + 1) % N) in corners
        ch = (p2[0] - p1[0], p2[1] - p1[1])
        m1 = ch if c1 else (0.5 * (p2[0] - p0[0]), 0.5 * (p2[1] - p0[1]))
        m2 = ch if c2 else (0.5 * (p3[0] - p1[0]), 0.5 * (p3[1] - p1[1]))
        for j in range(n):
            t = j / n
            t2, t3 = t * t, t * t * t
            h00, h10, h01, h11 = 2 * t3 - 3 * t2 + 1, t3 - 2 * t2 + t, -2 * t3 + 3 * t2, t3 - t2
            out.append((h00 * p1[0] + h10 * m1[0] + h01 * p2[0] + h11 * m2[0],
                        h00 * p1[1] + h10 * m1[1] + h01 * p2[1] + h11 * m2[1]))
    if not closed:
        out.append(pts[-1])
    return out


def prof_w(prof, u):
    if u <= prof[0][0]:
        return prof[0][1]
    for (u0, w0), (u1, w1) in zip(prof, prof[1:]):
        if u <= u1:
            t = (u - u0) / (u1 - u0)
            t = t * t * (3 - 2 * t)
            return w0 + (w1 - w0) * t
    return prof[-1][1]


def tube(path, prof, n=7, scale=1.0, caps=(True, True)):
    """Smooth tapered limb along `path` with width profile [(u, halfwidth)] (u = arc fraction)."""
    dense = smooth(path, n, closed=False)
    cum = [0.0]
    for i in range(1, len(dense)):
        cum.append(cum[-1] + math.hypot(dense[i][0] - dense[i - 1][0], dense[i][1] - dense[i - 1][1]))
    tot = cum[-1] or 1.0
    Lp, Rp, N, W, Tn = [], [], [], [], []
    for i, p in enumerate(dense):
        a, b = dense[max(i - 1, 0)], dense[min(i + 1, len(dense) - 1)]
        tx, ty = b[0] - a[0], b[1] - a[1]
        l = math.hypot(tx, ty) or 1.0
        tx, ty = tx / l, ty / l
        nx, ny = -ty, tx
        w = prof_w(prof, cum[i] / tot) * scale
        Lp.append((p[0] + nx * w, p[1] + ny * w))
        Rp.append((p[0] - nx * w, p[1] - ny * w))
        N.append((nx, ny))
        W.append(w)
        Tn.append((tx, ty))

    def arc(i, a0, a1, steps=6):
        c = dense[i]
        (nx, ny), (tx, ty), w = N[i], Tn[i], W[i]
        out = []
        for j in range(1, steps):
            th = a0 + (a1 - a0) * j / steps
            out.append((c[0] + w * (math.cos(th) * nx + math.sin(th) * tx),
                        c[1] + w * (math.cos(th) * ny + math.sin(th) * ty)))
        return out

    poly = list(Lp)
    if caps[1]:
        poly += arc(len(dense) - 1, 0, math.pi)
    poly += list(reversed(Rp))
    if caps[0]:
        poly += arc(0, math.pi, 2 * math.pi)
    lx, ly = lv(LIGHT2)
    mean = sum(nx * lx + ny * ly for nx, ny in N) / len(N)
    return dict(poly=poly, C=dense, N=N, W=W, T=Tn, L=Lp, R=Rp, shade_side=(-1 if mean > 0 else 1),
                u=[c / tot for c in cum])


def strip(T, side, a, b, wob=0.0, u0=0.0):
    """Region of the tube between offsets side*w*a and side*w*b (|a|>|b|)."""
    E, I = [], []
    for i, (p, n, w) in enumerate(zip(T["C"], T["N"], T["W"])):
        u = T["u"][i]
        bb = b + wob * math.sin(math.pi * u * 2.0)
        if u0 > 0:
            rp = min(1.0, max(0.0, (u - u0) / 0.3))
            bb = a + (bb - a) * rp
        E.append((p[0] + n[0] * side * w * a, p[1] + n[1] * side * w * a))
        I.append((p[0] + n[0] * side * w * bb, p[1] + n[1] * side * w * bb))
    return E + I[::-1]


def tube_draw(fig, T, m, layer, ol=INNER, k=0.40, hi=None, wob=0.08, open_root=False, u0=0.0):
    poly = T["poly"]
    if ol:
        if open_root:
            outline(fig, T["L"] + T["R"][::-1], layer, ol, closed=False, col=olcol(m))
        else:
            outline(fig, poly, layer, ol, col=olcol(m))
    fillp(fig, poly, m.base, layer)
    if k:
        sh = strip(T, T["shade_side"], 1.25, 1.0 - 2 * k, wob, u0)
        fillp(fig, sh, m.shadow, layer + 0.001, clip=poly)
    if hi and m.hi:
        hs = strip(T, -T["shade_side"], 0.80 + 0.0, 0.52, 0.0, u0)
        fillp(fig, hs, m.hi, layer + 0.002, clip=poly)


def shape_draw(fig, pts, m, layer, shades=(), his=(), ol=INNER):
    if ol:
        outline(fig, pts, layer, ol, col=olcol(m))
    fillp(fig, pts, m.base, layer)
    for sp in shades:
        fillp(fig, sp, m.shadow, layer + 0.001, clip=pts)
    for hp_ in his:
        fillp(fig, hp_, m.hi or m.base, layer + 0.002, clip=pts)


def circle(c, r, n=14, sx=1.0, sy=1.0, rot=0.0):
    out = []
    cr, sr = math.cos(rot), math.sin(rot)
    for i in range(n):
        a = 2 * math.pi * i / n
        x, y = math.cos(a) * r * sx, math.sin(a) * r * sy
        out.append((c[0] + x * cr - y * sr, c[1] + x * sr + y * cr))
    return out


def unit(a, b):
    dx, dy = b[0] - a[0], b[1] - a[1]
    l = math.hypot(dx, dy) or 1.0
    return dx / l, dy / l


def offs(p, d, k):
    return (p[0] + d[0] * k, p[1] + d[1] * k)


def rot(v, deg):
    t = math.radians(deg)
    return (v[0] * math.cos(t) - v[1] * math.sin(t), v[0] * math.sin(t) + v[1] * math.cos(t))


# ------------------------------------------------------------------ shared 3/4 head
def hpoly(R, fd, n=5, corners=(), closed=True):
    return smooth([head_pt(R, f, d) for f, d in fd], n, closed, corners)


# head-local outline (f forward, d down, units of head radius), clockwise from the crown
HEAD34 = [(0.02, -1.02), (0.52, -0.92), (0.84, -0.62), (0.94, -0.30), (0.88, -0.04), (0.92, 0.20), (0.86, 0.50),
          (0.72, 0.80), (0.52, 0.99), (0.30, 0.96), (-0.02, 0.76), (-0.34, 0.50), (-0.60, 0.26), (-0.92, 0.02),
          (-1.02, -0.38), (-0.84, -0.76), (-0.46, -0.98)]
EYE = [(-0.30, 0.02), (-0.15, -0.22), (0.12, -0.25), (0.31, -0.07), (0.22, 0.14), (-0.02, 0.19), (-0.20, 0.13)]
LID = [(-0.36, 0.00), (-0.20, -0.23), (0.06, -0.29), (0.29, -0.15), (0.35, 0.02)]


def eye34(fig, R, face, cx, cy, sx, sy, lay, clip, far_eye=False):
    """One anime eye. sx<0 mirrors it (far eye); the gaze always goes toward +f.
    face["shut"] closes it: "rest" is a relaxed downward arc, "wince" a squeezed chevron."""
    r = R["hr"]
    HP = lambda f, d: head_pt(R, f, d)
    E = lambda pts: [(cx + x * sx, cy + y * sy) for x, y in pts]
    ax = abs(sx)
    shut = face.get("shut")
    if shut:
        arc = [(-0.33, -0.02), (-0.02, 0.12), (0.31, 0.0)] if shut == "rest" else [(-0.30, -0.14), (0.20, 0.03), (-0.26, 0.17)]
        line = hpoly(R, E(arc), 3, closed=False, corners=(1,) if shut == "wince" else ())
        w = r * face.get("lid_w", 0.066) * (0.7 if far_eye else 1.0)
        stroke(fig, line, w, w * 0.8, INK, lay + 0.2)
        return None
    eye = hpoly(R, E(EYE), 4, corners=(0, 3))
    fillp(fig, eye, (252, 250, 247), lay, clip=clip)
    # lid shadow on the white
    fillp(fig, hpoly(R, E([(-0.34, -0.3), (0.36, -0.3), (0.36, -0.13), (-0.34, -0.10)]), 2), (206, 212, 238), lay + 0.01, clip=eye)
    gz = face.get("gaze", 0.05) * (1.0 if not far_eye else 0.5)
    ir = face.get("iris_r", 0.185) * sy
    wx = max(0.62, ax) if far_eye else 1.0
    ic = (cx + gz, cy - 0.01 * sy)
    fillp(fig, circle(HP(ic[0], ic[1] - 0.01 * sy), r * ir, 14, wx, 1.38), face["iris_lo"], lay + 0.02, clip=eye)
    fillp(fig, circle(HP(ic[0], ic[1] + 0.07 * sy), r * ir * 0.82, 14, wx, 1.18), face["iris"], lay + 0.04, clip=eye)
    fillp(fig, circle(HP(ic[0] + 0.01, ic[1] + 0.01 * sy), r * ir * 0.40, 10, wx, 1.2), (24, 14, 30), lay + 0.06, clip=eye)
    if face.get("glint", True):
        fillp(fig, circle(HP(ic[0] - 0.085 * wx, ic[1] - 0.115 * sy), r * ir * (0.44 if not far_eye else 0.36), 10), (255, 255, 255), lay + 0.1, clip=eye)
        if not far_eye:
            fillp(fig, circle(HP(ic[0] + 0.075, ic[1] + 0.15 * sy), r * ir * 0.2, 8), (255, 255, 255), lay + 0.1, clip=eye)
    lw = face.get("lid_w", 0.066)
    lid = hpoly(R, E(LID), 4, closed=False)
    if sx < 0:
        lid = lid[::-1]
    # near eye: heavy at the outer (back) corner, lighter toward the nose; far eye: lighter overall
    k = 0.7 if far_eye else 1.0
    stroke(fig, lid, r * lw * k * (0.6 if sx < 0 else 1.0), r * lw * k * (1.0 if sx < 0 else 0.6), INK, lay + 0.2)
    if face.get("lash", True) and not far_eye:
        stroke(fig, [HP(*E([(-0.36, 0.00)])[0]), HP(*E([(-0.48, -0.09)])[0])], r * lw * 0.85, r * 0.012, INK, lay + 0.2)
    lo = hpoly(R, E([(-0.15, 0.18), (0.06, 0.225), (0.23, 0.16)]), 3, closed=False)
    stroke(fig, lo, r * 0.022, r * 0.022, face["lowerlid"], lay + 0.15)
    return eye


def head34(fig, R, face, skin, lay=4.0, ol=1.5):
    """Skin, ear, eyes, brows, nose, mouth of a 3/4 head. Returns dict(head=poly, ...)."""
    r = R["hr"]
    HP = lambda f, d: head_pt(R, f, d)
    fd = face.get("outline", HEAD34)
    head = hpoly(R, fd, 5, corners=face.get("corners", ()))
    # form shadow: far cheek + under-jaw strip (light comes from the upper-left, behind the fighter)
    if abs(_SPIN) > 30 and "shade" not in face:
        # tipped back or lying face-up: the light falls on the face, only the underside of the jaw is shaded
        face = dict(face, shade=[(-1.2, 0.06), (-0.56, 0.16), (-0.36, 0.36), (-0.06, 0.58), (0.24, 0.80), (0.52, 0.84), (0.7, 1.3), (-1.2, 1.3)])
    sh = hpoly(R, face.get("shade", [(1.2, -0.25), (0.93, -0.2), (0.84, 0.06), (0.86, 0.36), (0.74, 0.62), (0.52, 0.84),
                                     (0.24, 0.80), (-0.06, 0.58), (-0.36, 0.36), (-0.7, 0.4), (-0.4, 1.3), (1.2, 1.3)]), 4)
    shape_draw(fig, head, skin, lay, shades=[sh], ol=ol)
    if face.get("blush"):
        fillp(fig, circle(HP(0.26, 0.52), r * 0.17, 12, 1.5, 0.62, 0.0), face["blush"], lay + 0.05, clip=head, alpha=0.42)
    # ear
    if face.get("ear", True):
        ef, ed = face.get("ear_at", (-0.42, 0.06))
        ear = hpoly(R, [(ef + 0.10, ed - 0.22), (ef - 0.08, ed - 0.26), (ef - 0.17, ed - 0.06), (ef - 0.10, ed + 0.20),
                        (ef + 0.04, ed + 0.24), (ef + 0.10, ed + 0.04)], 4)
        shape_draw(fig, ear, skin, lay + 0.06, ol=1.1)
        stroke(fig, hpoly(R, [(ef + 0.03, ed - 0.13), (ef - 0.08, ed - 0.08), (ef - 0.04, ed + 0.10)], 3, closed=False),
               r * 0.035, r * 0.02, skin.shadow, lay + 0.07)
    # eyes
    ex, ey = face.get("ex", 0.11), face.get("ey", 0.13)
    fx, fy = face.get("fx", 0.735), face.get("fy", ey - 0.005)
    es, eh = face.get("es", 1.08), face.get("eh", 1.14)
    fs = face.get("fs", 0.42)
    eye34(fig, R, face, ex, ey, es, eh, lay + 0.2, head)
    eye34(fig, R, face, fx, fy, -es * fs, eh * 0.94, lay + 0.2, head, far_eye=True)
    # brows: sl > 0 is stern (inner ends pulled down toward the nose)
    bm, bw, sl = face["browmat"], face.get("brow_w", 0.045), face.get("brow", 0.0)
    by = ey - face.get("brow_gap", 0.40) * eh
    near = [(ex - 0.36 * es, by + 0.03 - sl * 0.25), (ex - 0.08 * es, by - 0.08 - sl * 0.1), (ex + 0.22 * es, by - 0.02 + sl * 0.5),
            (ex + 0.36 * es, by + 0.07 + sl)]
    bl = face.get("brow_lay", lay + 0.3)
    stroke(fig, hpoly(R, near, 3, closed=False), r * bw * 0.7, r * bw, bm, bl)
    farb = [(fx - 0.15, by + 0.07 + sl), (fx - 0.02, by - 0.02 + sl * 0.4), (fx + 0.11, by + 0.0)]
    stroke(fig, hpoly(R, farb, 3, closed=False), r * bw, r * bw * 0.6, bm, bl)
    # nose: bridge-side tick + small cast shadow, sitting between the eyes toward the far side
    nf, nd = face.get("nose_at", (0.70, 0.47))
    nose = face.get("nose", "tick")
    if nose == "tick":
        fillp(fig, hpoly(R, [(nf - 0.01, nd - 0.09), (nf + 0.07, nd + 0.0), (nf + 0.02, nd + 0.05), (nf - 0.04, nd + 0.02)], 3,
                         corners=(0,)), skin.shadow, lay + 0.12, clip=head)
    # mouth
    mouth = face.get("mouth", "calm")
    mc = face.get("mouthcol", (170, 84, 92))
    mf, md = face.get("mouth_at", (0.58, 0.70))
    if mouth == "calm":
        stroke(fig, hpoly(R, [(mf - 0.15, md - 0.01), (mf, md + 0.03), (mf + 0.13, md - 0.02)], 3, closed=False),
               r * 0.03, r * 0.026, mc, lay + 0.12)
    elif mouth == "smirk":
        stroke(fig, hpoly(R, [(mf - 0.17, md + 0.02), (mf - 0.02, md + 0.04), (mf + 0.13, md - 0.05)], 3, closed=False),
               r * 0.034, r * 0.026, mc, lay + 0.12)
    elif mouth == "smile":
        stroke(fig, hpoly(R, [(mf - 0.17, md - 0.04), (mf - 0.03, md + 0.05), (mf + 0.13, md - 0.05)], 3, closed=False),
               r * 0.034, r * 0.028, mc, lay + 0.12)
    elif mouth == "open":
        fillp(fig, circle(HP(mf, md + 0.03), r * 0.105, 12, 1.0, 1.25, math.radians(R["tilt"])), (124, 44, 66), lay + 0.12, clip=head)
    elif mouth == "lips":
        stroke(fig, hpoly(R, [(mf - 0.15, md - 0.01), (mf, md + 0.03), (mf + 0.13, md - 0.02)], 3, closed=False),
               r * 0.03, r * 0.026, mc, lay + 0.12)
        fillp(fig, hpoly(R, [(mf - 0.09, md + 0.035), (mf + 0.02, md + 0.05), (mf + 0.09, md + 0.02), (mf + 0.0, md + 0.115)], 3),
              face.get("lipcol", (236, 128, 138)), lay + 0.11, clip=head)
    return dict(head=head)


def spike(R, a, b, tip, bulge=0.0, n=4):
    """Pointed hair clump: root edge a->b (head-local), sharp tip; bulge bows the leading edge."""
    ma = ((a[0] + tip[0]) / 2, (a[1] + tip[1]) / 2)
    mb = ((b[0] + tip[0]) / 2, (b[1] + tip[1]) / 2)
    dx, dy = tip[0] - (a[0] + b[0]) / 2, tip[1] - (a[1] + b[1]) / 2
    L = math.hypot(dx, dy) or 1.0
    nx, ny = -dy / L, dx / L
    ma = (ma[0] + nx * bulge, ma[1] + ny * bulge)
    mb = (mb[0] + nx * bulge * 0.4, mb[1] + ny * bulge * 0.4)
    return hpoly(R, [a, ma, tip, mb, b], n, corners=(2,))


def cel_shape(fig, poly, m, layer, ol=INNER, shift=(1.3, 1.5), hi=None, clip=None):
    """Outline + shadow fill + lit fill inset toward the upper-left key light (shadow hugs the lower-right edges)."""
    if ol:
        outline(fig, poly, layer, ol, col=olcol(m))
    fillp(fig, poly, m.shadow, layer, clip=clip)
    shift = lv(shift)
    fillp(fig, [(x - shift[0], y - shift[1]) for x, y in poly], m.base, layer + 0.001, clip=poly)
    if hi is not None and m.hi:
        fillp(fig, lturn(hi, centre(poly)), m.hi, layer + 0.002, clip=poly)


# ------------------------------------------------------------------ shared feet
def foot_frame(R, side, scale=1.0, lo=-4.0, hi=38.0):
    """Foot-local frame at the ankle: L(u, v) with u toward the toes and v toward the sole.
    The toe direction comes from the rig (toes forward). A planted foot is clamped to lie flat-ish on the floor;
    a raised foot follows the rig so a kick shows its sole."""
    an, toe = R["ankle_" + side], R["toe_" + side]
    ang = math.degrees(math.atan2(toe[1] - an[1], toe[0] - an[0]))
    low = max(R["ankle_f"][1], R["ankle_b"][1])
    if R["grounded"] and an[1] > low - 9.0 * R["s"]:
        ang = max(lo, min(hi, ang * 0.4))      # planted: nearly flat, trailing heel lifts a little
    f = (math.cos(math.radians(ang)), math.sin(math.radians(ang)))
    d = (-f[1], f[0])
    s = R["s"] * scale
    return lambda u, v: (an[0] + (f[0] * u + d[0] * v) * s, an[1] + (f[1] * u + d[1] * v) * s)


def ground(R, poly, pad=1.0):
    R.setdefault("feet", []).append(max(p[1] for p in poly) + pad)


def shine_tone(m):
    """Colour of the hair shine band: the highlight tone, or on hair too pale for a highlight to show
    (white, platinum) a band tinted with the hair's own shadow hue."""
    if m.hi and math.dist(m.hi, m.base) > 90:
        return m.hi
    return mixc(m.base, m.shadow, 0.55)


def shine(fig, R, fd, col, layer, clip, w=0.09):
    """Simple anime hair shine: one soft zig-zag band (head-local polyline `fd`) clipped to a hair shape."""
    top = [head_pt(R, f, d - w * (1.0 if i % 2 == 0 else 0.45)) for i, (f, d) in enumerate(fd)]
    bot = [head_pt(R, f, d + w * (1.0 if i % 2 == 1 else 0.45)) for i, (f, d) in enumerate(fd)]
    fillp(fig, top + bot[::-1], col, layer, clip=clip)
