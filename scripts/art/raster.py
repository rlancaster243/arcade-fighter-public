"""Analytic-coverage 2D rasteriser for the fighter sprite generator (stdlib only, deterministic).

A Figure is a list of prims (capsules, convex quads, even-odd polygons, radial glows) painted back
to front by (layer, seq) into one CELL x CELL cell. Edges are anti-aliased from signed distance /
scanline coverage, so nothing is supersampled. Shaded prims use a hard-edged cel shader (one key
light: base tone, one shadow tone, optional highlight); flat prims carry their own colour.
`render` adds the soft tinted silhouette outline and returns straight-alpha RGBA bytes.
"""
import math
import struct
import zlib

K = 2                       # texel scale over the 1x logical skeleton
CELL = 112 * K              # 224
ANCHOR_X, ANCHOR_Y = 56 * K, 110 * K   # (112, 220): feet 4px above the cell bottom
LIGHT = (-0.55, -0.62, 0.56)           # key light: upper-left-front, y-down screen space
OUTLINE = (50, 34, 92)      # deep indigo: tinted, never black
OUTLINE_W = 2.3             # outer silhouette outline, texels
INNER_W = 1.35              # default contour between overlapping body layers, texels


def _unit(v):
    n = math.sqrt(sum(c * c for c in v))
    return tuple(c / n for c in v)


L3 = _unit(LIGHT)
HALF = _unit((L3[0], L3[1], L3[2] + 1.0))           # blinn half vector (viewer on +z)


class Cel:
    """Flat cel material: base tone, one shadow tone, optional highlight tone."""

    def __init__(self, base, shadow, hi=None, shadow_t=0.2, hi_t=0.93):
        self.base, self.shadow, self.hi = base, shadow, hi
        self.shadow_t, self.hi_t = shadow_t, hi_t


def mix(a, b, t):
    return tuple(x + (y - x) * t for x, y in zip(a, b))


def shade(mat, nx, ny, bias):
    """Cel colour for a screen-space normal (nx, ny); bias pushes far-side parts into shadow."""
    q = nx * nx + ny * ny
    if q > 1.0:
        s = 1.0 / math.sqrt(q)
        nx, ny, q = nx * s, ny * s, 1.0
    nz = math.sqrt(1.0 - q)
    lit = nx * L3[0] + ny * L3[1] + nz * L3[2]
    c = mat.shadow if lit - bias * 1.7 < mat.shadow_t else mat.base
    if mat.hi is not None and bias < 0.05:
        h = nx * HALF[0] + ny * HALF[1] + nz * HALF[2]
        if h > mat.hi_t:
            c = mat.hi
    return c


def vec(angle_deg, length):
    """Skeleton vector: angle measured from straight down, positive toward facing (+x)."""
    a = math.radians(angle_deg)
    return (math.sin(a) * length, math.cos(a) * length)


def add(a, b):
    return (a[0] + b[0], a[1] + b[1])


def _area(pts):
    a = 0
    for i in range(len(pts)):
        x1, y1 = pts[i]
        x2, y2 = pts[(i + 1) % len(pts)]
        a += x1 * y2 - x2 * y1
    return a


# ---------------------------------------------------------------- figure (prim list)


class Figure:
    """Prims painted back to front by (layer, seq); `fx` prims go over everything, never outlined.
    `mats` maps material names to Cel objects for the shaded cap/quad prims."""

    def __init__(self, mats=None, outline_rgb=OUTLINE):
        self.prims = []
        self.fx = []
        self.mats = mats or {}
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
        """Convex polygon shaded as a half-cylinder around the axis ax0 -> ax1 of half-width hw."""
        pts = pts if _area(pts) > 0 else list(reversed(pts))
        if ol:
            self._add(dict(kind="quad", pts=pts, grow=ol, flat=self.outline_rgb, layer=layer - 0.02,
                           ax0=ax0, ax1=ax1, hw=hw, alpha=1.0))
        self._add(dict(kind="quad", pts=pts, grow=0.0, mat=mat, bias=bias, layer=layer,
                       ax0=ax0, ax1=ax1, hw=hw, alpha=1.0))

    def poly(self, pts, col, layer, clip=None, alpha=1.0):
        """Flat even-odd polygon, optionally clipped to another polygon `clip`."""
        self._add(dict(kind="poly", pts=list(pts), flat=col, layer=layer, cpts=clip, alpha=alpha))

    def glow(self, c, r, inner, outer, power):
        """Soft radial halo painted over everything."""
        self.fx.append(dict(kind="radial", c=c, r=r, inner=inner, outer=outer, power=power, core=False))

    def orb(self, c, r, inner, outer):
        """Gradient disc with an opaque edge, painted over everything."""
        self.fx.append(dict(kind="radial", c=c, r=r, inner=inner, outer=outer, power=0.0, core=True))

    def streak(self, a, b, ra, rb, rgb, alpha):
        self.fx.append(dict(kind="cap", a=a, b=b, ra=ra, rb=rb, flat=rgb, mat=None, bias=0.0,
                            layer=0, alpha=alpha))


def transform_figure(fig, fn, k=1.0):
    """Apply a similarity map (point function `fn`, uniform scale `k`) to every prim."""
    out = Figure(fig.mats, fig.outline_rgb)
    clips = {}
    for p in fig.prims:
        q = dict(p)
        for key in ("ra", "rb", "hw", "grow"):
            if key in q:
                q[key] = q[key] * k
        for key in ("a", "b", "ax0", "ax1"):
            if key in q:
                q[key] = fn(*q[key])
        if "pts" in q:
            q["pts"] = [fn(*pt) for pt in q["pts"]]
        cp = q.get("cpts")
        if cp is not None:          # shared clip polygons stay shared (the rasteriser caches by identity)
            if id(cp) not in clips:
                clips[id(cp)] = [fn(*pt) for pt in cp]
            q["cpts"] = clips[id(cp)]
        out.prims.append(q)
    for p in fig.fx:
        q = dict(p)
        for key in ("ra", "rb", "r"):
            if key in q:
                q[key] = q[key] * k
        for key in ("a", "b", "c"):
            if key in q:
                q[key] = fn(*q[key])
        out.fx.append(q)
    return out


def figure_bounds(fig):
    """(x0, x1, y0, y1) of everything the figure paints, before the outer outline."""
    xs0, xs1, ys0, ys1 = [], [], [], []

    def box(x0, x1, y0, y1):
        xs0.append(x0)
        xs1.append(x1)
        ys0.append(y0)
        ys1.append(y1)

    for p in fig.prims + fig.fx:
        if p["kind"] == "cap":
            r = max(p["ra"], p["rb"])
            box(min(p["a"][0], p["b"][0]) - r, max(p["a"][0], p["b"][0]) + r,
                min(p["a"][1], p["b"][1]) - r, max(p["a"][1], p["b"][1]) + r)
        elif p["kind"] == "radial":
            box(p["c"][0] - p["r"], p["c"][0] + p["r"], p["c"][1] - p["r"], p["c"][1] + p["r"])
        else:
            g = p.get("grow", 0.0)
            b = [min(q[0] for q in p["pts"]) - g, max(q[0] for q in p["pts"]) + g,
                 min(q[1] for q in p["pts"]) - g, max(q[1] for q in p["pts"]) + g]
            cp = p.get("cpts")
            if cp is not None:
                b = [max(b[0], min(q[0] for q in cp)), min(b[1], max(q[0] for q in cp)),
                     max(b[2], min(q[1] for q in cp)), min(b[3], max(q[1] for q in cp))]
                if b[0] >= b[1] or b[2] >= b[3]:
                    continue
            box(*b)
    return min(xs0), max(xs1), min(ys0), max(ys1)


# ---------------------------------------------------------------- rasterising


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
                cov = cov * cov * (3 - 2 * cov) * 0.9
            if cov <= 0.002:
                continue
            c = mix(i0, i1, t)
            _put(buf, row + x, c[0], c[1], c[2], cov)


def scan_coverage(pts, sub=4):
    """Even-odd polygon coverage {pixel_index: 0..1}; exact in x, `sub` samples in y."""
    n = len(pts)
    ymin = max(0, int(math.floor(min(p[1] for p in pts))))
    ymax = min(CELL - 1, int(math.floor(max(p[1] for p in pts))))
    if ymax < ymin:
        return {}
    rows = ymax - ymin + 1
    cross = [[] for _ in range(rows * sub)]
    for i in range(n):
        x1, y1 = pts[i]
        x2, y2 = pts[(i + 1) % n]
        if y1 == y2:
            continue
        if y1 > y2:
            x1, y1, x2, y2 = x2, y2, x1, y1
        k0 = max(int(math.ceil((y1 - ymin) * sub - 0.5)), 0)
        k1 = min(int(math.ceil((y2 - ymin) * sub - 0.5)) - 1, rows * sub - 1)
        dxdy = (x2 - x1) / (y2 - y1)
        for k in range(k0, k1 + 1):
            cross[k].append(x1 + (ymin + (k + 0.5) / sub - y1) * dxdy)
    cov = {}
    inv = 1.0 / sub
    for k, xs in enumerate(cross):
        if len(xs) < 2:
            continue
        xs.sort()
        base = (ymin + k // sub) * CELL
        for j in range(0, len(xs) - 1, 2):
            xa, xb = max(xs[j], 0.0), min(xs[j + 1], float(CELL))
            if xb <= xa:
                continue
            ia, ib = int(xa), int(xb)
            if ia == ib:
                cov[base + ia] = cov.get(base + ia, 0.0) + (xb - xa) * inv
            else:
                cov[base + ia] = cov.get(base + ia, 0.0) + (ia + 1 - xa) * inv
                for x in range(ia + 1, ib):
                    cov[base + x] = cov.get(base + x, 0.0) + inv
                if ib < CELL:
                    cov[base + ib] = cov.get(base + ib, 0.0) + (xb - ib) * inv
    return cov


def raster_poly(buf, p, clip_cache):
    cov = scan_coverage(p["pts"])
    cp = p.get("cpts")
    cc = None
    if cp is not None:
        cc = clip_cache.get(id(cp))
        if cc is None:
            cc = clip_cache[id(cp)] = scan_coverage(cp)
    r, g, b = p["flat"]
    alpha = p.get("alpha", 1.0)
    for i, c in cov.items():
        if cc is not None:
            c *= min(1.0, cc.get(i, 0.0))
        c = min(1.0, c) * alpha
        if c > 0.004:
            _put(buf, i, r, g, b, c)


def raster_prims(buf, prims, mats):
    clip_cache = {}
    for p in sorted(prims, key=lambda q: (q.get("layer", 0), q.get("seq", 0))):
        kind = p["kind"]
        if kind == "poly":
            raster_poly(buf, p, clip_cache)
        elif kind == "cap":
            raster_cap(buf, p, mats)
        elif kind == "quad":
            raster_quad(buf, p, mats)
        else:
            raster_radial(buf, p)


def outer_ring(body, outline_rgb, width, tint):
    """Soft outline around the silhouette: returns {pixel: (alpha, rgb)}.

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
    """body over ring, fx over that; returns straight-alpha RGBA bytes for the cell.
    Transparent texels carry the outline colour so bilinear filtering never bleeds black."""
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


def render(fig, outlined=True):
    """Rasterise a Figure into CELL x CELL straight-alpha RGBA bytes."""
    body = Buf()
    raster_prims(body, fig.prims, fig.mats)
    ring = outer_ring(body, fig.outline_rgb, OUTLINE_W, 0.45) if outlined else {}
    fx = Buf()
    raster_prims(fx, fig.fx, fig.mats)
    return finish(body, fx, ring, fig.outline_rgb)


# ---------------------------------------------------------------- PNG


def png_bytes(width, height, raw_rows, colortype):
    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    raw = b"".join(b"\x00" + bytes(r) for r in raw_rows)
    return (b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, colortype, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))
