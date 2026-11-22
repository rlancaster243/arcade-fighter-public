#!/usr/bin/env python3
"""PS2-era hi-res 2D stage backdrops (stdlib only, deterministic).

Layers are truecolour at 2x texel density: 1536x432 texels for the 768x216 logical layer
(stage.json carries "texelScale": 2). The arena scrolls up to 384 logical px. The floor line
sits 32 logical px (64 texels) above the bottom, i.e. texel row 368 (logical y = 184).

Everything is painted into float RGBA buffers (premultiplied) with anti-aliased shapes,
smooth gradients, value-noise texture, atmospheric haze and soft additive light, then
written as RGB (opaque layers) or RGBA (transparent layers) PNGs. No dithering patterns;
opaque layers get +-0.75 level triangular noise purely to hide 8-bit banding.

Usage: python3 -I scripts/art/gen_stages.py [repo_root]
"""
import math
import os
import random
import struct
import sys
import zlib

S = 2                      # texel scale (stage.json "texelScale")
W, H = 768 * S, 216 * S    # 1536 x 432
FLOOR = H - 32 * S         # 368: floor line in texel rows


# ------------------------------------------------------------------ small maths helpers


def clamp(v, a=0.0, b=1.0):
    return a if v < a else b if v > b else v


def lerp(a, b, t):
    return a + (b - a) * t


def lerpc(c1, c2, t):
    return (c1[0] + (c2[0] - c1[0]) * t, c1[1] + (c2[1] - c1[1]) * t, c1[2] + (c2[2] - c1[2]) * t)


def smoothstep(a, b, x):
    t = clamp((x - a) / (b - a))
    return t * t * (3 - 2 * t)


def hash01(a, b=0, seed=0):
    n = (a * 374761393 + b * 668265263 + seed * 1274126177) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    n ^= n >> 16
    return n / 4294967296.0


class Ramp:
    """Piecewise-linear colour ramp baked into a lookup table."""

    def __init__(self, stops, n=512):
        self.n = n
        self.lut = []
        for i in range(n):
            t = i / (n - 1)
            c = stops[-1][1]
            if t <= stops[0][0]:
                c = stops[0][1]
            else:
                for (t0, c0), (t1, c1) in zip(stops, stops[1:]):
                    if t <= t1:
                        c = lerpc(c0, c1, (t - t0) / (t1 - t0))
                        break
            self.lut.append(c)

    def __call__(self, t):
        return self.lut[int(clamp(t) * (self.n - 1) + 0.5)]


# ------------------------------------------------------------------ noise


class Noise:
    """Smooth value noise on a (cw x ch) texel lattice; row(y) returns W values in 0..1."""

    def __init__(self, seed, cw, ch):
        rnd = random.Random(seed)
        nx, ny = W // cw + 3, H // ch + 3
        self.lat = [[rnd.random() for _ in range(nx)] for _ in range(ny)]
        self.ch = ch
        self.xw = []
        for x in range(W):
            fx = x / cw
            i = int(fx)
            t = fx - i
            self.xw.append((i, t * t * (3 - 2 * t)))

    def row(self, y):
        fy = y / self.ch
        j = int(fy)
        t = fy - j
        t = t * t * (3 - 2 * t)
        lat = [p + (q - p) * t for p, q in zip(self.lat[j], self.lat[j + 1])]
        return [lat[i] + (lat[i + 1] - lat[i]) * s for i, s in self.xw]


class FBM:
    def __init__(self, seed, cells):
        tot = sum(c[2] for c in cells)
        self.n = [Noise(seed + 101 * i, cw, ch) for i, (cw, ch, _) in enumerate(cells)]
        self.w = [c[2] / tot for c in cells]

    def row(self, y):
        out = None
        for n, w in zip(self.n, self.w):
            r = n.row(y)
            out = [v * w for v in r] if out is None else [o + v * w for o, v in zip(out, r)]
        return out


def profile(seed, cell, octaves=4, ridged=False, persistence=0.5):
    """1-D fractal profile over x (W values, roughly 0..1)."""
    rnd = random.Random(seed)
    out = [0.0] * W
    amp, tot, c = 1.0, 0.0, float(cell)
    for _ in range(octaves):
        lat = [rnd.random() for _ in range(int(W / c) + 3)]
        for x in range(W):
            f = x / c
            i = int(f)
            t = f - i
            t = t * t * (3 - 2 * t)
            v = lat[i] + (lat[i + 1] - lat[i]) * t
            if ridged:
                v = 1 - abs(2 * v - 1)
            out[x] += v * amp
        tot += amp
        amp *= persistence
        c /= 2
    return [v / tot for v in out]


# ------------------------------------------------------------------ coverage builders
# cov(y, xa, xb) -> list of 0..1 coverage for pixels xa..xb-1 on row y


def cov_below(top):
    def f(y, xa, xb):
        yy = y + 1.0
        return [min(1.0, max(0.0, yy - t)) for t in top[xa:xb]]
    return f


def cov_rect(rx0, ry0, rx1, ry1):
    def f(y, xa, xb):
        cy = min(y + 1.0, ry1) - max(float(y), ry0)
        if cy <= 0:
            return [0.0] * (xb - xa)
        cy = min(1.0, cy)
        return [cy * min(1.0, max(0.0, min(x + 1.0, rx1) - max(float(x), rx0))) for x in range(xa, xb)]
    return f


def cov_sdf(fn):
    """fn(x, y) -> signed distance in texels (negative inside)."""
    def f(y, xa, xb):
        yy = y + 0.5
        return [min(1.0, max(0.0, 0.5 - fn(x + 0.5, yy))) for x in range(xa, xb)]
    return f


def cov_poly(pts):
    edges = []
    for i in range(len(pts)):
        (x1, y1), (x2, y2) = pts[i], pts[(i + 1) % len(pts)]
        if y1 != y2:
            edges.append((x1, y1, x2, y2) if y1 < y2 else (x2, y2, x1, y1))

    def f(y, xa, xb):
        yc = y + 0.5
        xs = sorted(x1 + (yc - y1) * (x2 - x1) / (y2 - y1) for x1, y1, x2, y2 in edges if y1 <= yc < y2)
        out = [0.0] * (xb - xa)
        for a, b in zip(xs[0::2], xs[1::2]):
            a, b = max(a, xa), min(b, xb)
            if b <= a:
                continue
            ia, ib = int(a), int(b)
            if ia == ib:
                out[ia - xa] += b - a
                continue
            out[ia - xa] += ia + 1 - a
            if ib - ia > 1:
                out[ia + 1 - xa:ib - xa] = [1.0] * (ib - ia - 1)
            if ib < xb:
                out[ib - xa] += b - ib
        return [min(1.0, v) for v in out]
    return f


def cov_radial(cx, cy, rx, ry, strength=1.0, power=2.0):
    def f(y, xa, xb):
        dy = (y + 0.5 - cy) / ry
        dy2 = dy * dy
        if dy2 >= 1:
            return [0.0] * (xb - xa)
        out = []
        for x in range(xa, xb):
            dx = (x + 0.5 - cx) / rx
            d2 = dx * dx + dy2
            out.append(strength * (1 - d2) ** power if d2 < 1 else 0.0)
        return out
    return f


def seg_dist(px, py, x0, y0, x1, y1):
    dx, dy = x1 - x0, y1 - y0
    l2 = dx * dx + dy * dy
    t = 0.0 if l2 == 0 else clamp(((px - x0) * dx + (py - y0) * dy) / l2)
    return math.hypot(px - x0 - t * dx, py - y0 - t * dy)


# ------------------------------------------------------------------ shaders
# shade(y, xa, xb, al) -> (rs, gs, bs) straight colour 0..255


def sh_flat(c):
    def f(y, xa, xb, al):
        n = xb - xa
        return [c[0]] * n, [c[1]] * n, [c[2]] * n
    return f


def sh_px(fn):
    """Per-pixel shader fn(x, y) -> (r, g, b); skips pixels with zero coverage."""
    def f(y, xa, xb, al):
        zero = (0.0, 0.0, 0.0)
        px = [fn(x, y) if a > 0 else zero for x, a in zip(range(xa, xb), al)]
        return [p[0] for p in px], [p[1] for p in px], [p[2] for p in px]
    return f


def sh_rows(fn):
    """fn(y, xa, xb) -> (rs, gs, bs) lists."""
    def f(y, xa, xb, al):
        return fn(y, xa, xb)
    return f


# ------------------------------------------------------------------ layer buffer


class Layer:
    def __init__(self):
        self.R = [[0.0] * W for _ in range(H)]
        self.G = [[0.0] * W for _ in range(H)]
        self.B = [[0.0] * W for _ in range(H)]
        self.A = [[0.0] * W for _ in range(H)]

    def fill_rows(self, y0, y1, fn):
        """Opaque row-constant fill; fn(y) -> colour."""
        for y in range(y0, y1):
            c = fn(y)
            self.R[y] = [c[0]] * W
            self.G[y] = [c[1]] * W
            self.B[y] = [c[2]] * W
            self.A[y] = [1.0] * W

    def blend(self, y, x0, rs, gs, bs, al):
        R, G, B, A = self.R[y], self.G[y], self.B[y], self.A[y]
        x = x0
        for r, g, b, a in zip(rs, gs, bs, al):
            if a > 0.0:
                if a >= 0.999:
                    R[x], G[x], B[x], A[x] = r, g, b, 1.0
                else:
                    ia = 1.0 - a
                    R[x] = R[x] * ia + r * a
                    G[x] = G[x] * ia + g * a
                    B[x] = B[x] * ia + b * a
                    A[x] = A[x] * ia + a
            x += 1

    def draw(self, x0, y0, x1, y1, cov, shade):
        x0, y0 = max(0, int(x0)), max(0, int(y0))
        x1, y1 = min(W, int(math.ceil(x1))), min(H, int(math.ceil(y1)))
        if x1 <= x0:
            return
        for y in range(y0, y1):
            al = cov(y, x0, x1)
            if not any(al):
                continue
            rs, gs, bs = shade(y, x0, x1, al)
            self.blend(y, x0, rs, gs, bs, al)

    def add_row(self, y, x0, rs, gs, bs, al):
        """Additive light (premultiplied 'plus'), alpha grows by 'over'."""
        R, G, B, A = self.R[y], self.G[y], self.B[y], self.A[y]
        x = x0
        for r, g, b, a in zip(rs, gs, bs, al):
            if a > 0.0:
                if a > 1.0:
                    a = 1.0
                a0 = A[x]
                a1 = a0 + a * (1 - a0)
                lim = 255.0 * a1
                v = R[x] + r * a
                R[x] = v if v < lim else lim
                v = G[x] + g * a
                G[x] = v if v < lim else lim
                v = B[x] + b * a
                B[x] = v if v < lim else lim
                A[x] = a1
            x += 1

    def light(self, cx, cy, rx, ry, col, strength, power=2.0):
        """Soft elliptical light with compact smooth falloff."""
        cr, cg, cb = col
        for y in range(max(0, int(cy - ry)), min(H, int(cy + ry) + 1)):
            dy = (y + 0.5 - cy) / ry
            dy2 = dy * dy
            if dy2 >= 1:
                continue
            hw = rx * math.sqrt(1 - dy2)
            xa, xb = max(0, int(cx - hw)), min(W, int(cx + hw) + 1)
            R, G, B, A = self.R[y], self.G[y], self.B[y], self.A[y]
            for x in range(xa, xb):
                dx = (x + 0.5 - cx) / rx
                d2 = dx * dx + dy2
                if d2 >= 1:
                    continue
                a = strength * (1 - d2) ** power
                if a > 1.0:
                    a = 1.0
                a0 = A[x]
                a1 = a0 + a * (1 - a0)
                lim = 255.0 * a1
                v = R[x] + cr * a
                R[x] = v if v < lim else lim
                v = G[x] + cg * a
                G[x] = v if v < lim else lim
                v = B[x] + cb * a
                B[x] = v if v < lim else lim
                A[x] = a1

    def tint(self, y0, y1, col, fn):
        """Pull existing colour toward `col` by fn(y) (atmospheric haze)."""
        for y in range(y0, y1):
            f = fn(y)
            if f <= 0.001:
                continue
            A = self.A[y]
            self.R[y] = [r + (col[0] * a - r) * f for r, a in zip(self.R[y], A)]
            self.G[y] = [g + (col[1] * a - g) * f for g, a in zip(self.G[y], A)]
            self.B[y] = [b + (col[2] * a - b) * f for b, a in zip(self.B[y], A)]

    # -- convenience shapes
    def stroke(self, x0, y0, x1, y1, w, col, alpha=1.0):
        pad = w / 2 + 2
        self.draw(min(x0, x1) - pad, min(y0, y1) - pad, max(x0, x1) + pad, max(y0, y1) + pad,
                  lambda y, xa, xb: [alpha * clamp(w / 2 + 0.5 - seg_dist(x + 0.5, y + 0.5, x0, y0, x1, y1))
                                     for x in range(xa, xb)],
                  sh_flat(col))

    def disc(self, cx, cy, r, shade, alpha=1.0):
        self.draw(cx - r - 2, cy - r - 2, cx + r + 2, cy + r + 2,
                  lambda y, xa, xb: [alpha * clamp(0.5 - (math.hypot(x + 0.5 - cx, y + 0.5 - cy) - r))
                                     for x in range(xa, xb)], shade)

    def blob(self, cx, cy, rx, ry, col, alpha, power=1.6):
        """Soft translucent 'over' blob (smoke, mist)."""
        self.draw(cx - rx, cy - ry, cx + rx + 1, cy + ry + 1, cov_radial(cx, cy, rx, ry, alpha, power), sh_flat(col))

    def sparkle(self, x, y, size, col, alpha, flare=0):
        self.light(x, y, size * 2.4, size * 2.4, col, alpha, 1.6)
        self.light(x, y, size * 0.9, size * 0.9, (255, 255, 255), min(1.0, alpha * 1.2), 1.0)
        if flare:
            self.stroke(x - flare, y, x + flare, y, 1.2, col, alpha * 0.55)
            self.stroke(x, y - flare, x, y + flare, 1.2, col, alpha * 0.55)

    # -- output
    def opaque(self):
        return all(min(a) >= 0.999 for a in self.A)


# ------------------------------------------------------------------ PNG writer


def _chunk(tag, data):
    c = struct.pack(">I", len(data)) + tag + data
    return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)


_ABS = bytes(min(i, 256 - i) for i in range(256))


def _filter_rows(raw_rows, bpp):
    """Per-row choice of None/Sub/Up by minimum sum of |residual|."""
    out = []
    prev = bytes(len(raw_rows[0]))
    for row in raw_rows:
        cands = [(sum(row.translate(_ABS)), b"\x00" + row)]
        sub = bytes(row[:bpp]) + bytes((a - b) & 255 for a, b in zip(row[bpp:], row))
        cands.append((sum(sub.translate(_ABS)), b"\x01" + sub))
        up = bytes((a - b) & 255 for a, b in zip(row, prev))
        cands.append((sum(up.translate(_ABS)), b"\x02" + up))
        out.append(min(cands, key=lambda c: c[0])[1])
        prev = row
    return out


def write_png(path, layer, seed):
    opaque = layer.opaque()
    rnd = random.Random(seed)
    rows = []
    for y in range(H):
        R, G, B, A = layer.R[y], layer.G[y], layer.B[y], layer.A[y]
        if opaque:
            nz = [(rnd.random() + rnd.random() - 1.0) * 0.75 + 0.5 for _ in range(W)]
            row = bytearray(W * 3)
            row[0::3] = bytes([min(255, max(0, int(v + d))) for v, d in zip(R, nz)])
            row[1::3] = bytes([min(255, max(0, int(v + d))) for v, d in zip(G, nz)])
            row[2::3] = bytes([min(255, max(0, int(v + d))) for v, d in zip(B, nz)])
        else:
            row = bytearray(W * 4)
            rr, gg, bb, aa = [], [], [], []
            for r, g, b, a in zip(R, G, B, A):
                if a < 0.004:
                    rr.append(0), gg.append(0), bb.append(0), aa.append(0)
                else:
                    k = 1.0 / a
                    rr.append(min(255, int(r * k + 0.5)))
                    gg.append(min(255, int(g * k + 0.5)))
                    bb.append(min(255, int(b * k + 0.5)))
                    aa.append(min(255, int(a * 255 + 0.5)))
            row[0::4], row[1::4], row[2::4], row[3::4] = bytes(rr), bytes(gg), bytes(bb), bytes(aa)
        rows.append(bytes(row))
    bpp = 3 if opaque else 4
    data = b"".join(_filter_rows(rows, bpp))
    out = (b"\x89PNG\r\n\x1a\n"
           + _chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 2 if opaque else 6, 0, 0, 0))
           + _chunk(b"IDAT", zlib.compress(data, 9)) + _chunk(b"IEND", b""))
    with open(path, "wb") as f:
        f.write(out)
    return len(out), opaque


# ------------------------------------------------------------------ shared stonework


class Courses:
    """Running-bond ashlar: block boundaries per course, counted upward from y_ref."""

    def __init__(self, seed, ch, bw_min, bw_max, y_ref, n):
        rnd = random.Random(seed)
        self.ch, self.y_ref = ch, y_ref
        self.bounds, self.bi, self.tone = [], [], []
        for k in range(n):
            b = [-rnd.randint(0, bw_max)]
            while b[-1] < W + bw_max:
                b.append(b[-1] + rnd.randint(bw_min, bw_max))
            idx, j = [], 0
            for x in range(W):
                while b[j + 1] <= x:
                    j += 1
                idx.append(j)
            self.bounds.append(b)
            self.bi.append(idx)
            self.tone.append([hash01(j, k, seed) for j in range(len(b))])

    def row(self, y, xa, xb):
        """(tones, lights) per pixel; light == -1 marks mortar; None outside the courses."""
        k, yy = divmod(self.y_ref - 1 - y, self.ch)
        if k < 0 or k >= len(self.bounds):
            return None
        bi, bnd, tn = self.bi[k], self.bounds[k], self.tone[k]
        top = 0.5 * (yy - (self.ch - 4)) / 3 if yy >= self.ch - 3 else (-0.4 * (3 - yy) / 3 if yy < 3 else 0.0)
        tones, lights = [], []
        for x in range(xa, xb):
            b = bi[x]
            xl, xr = x - bnd[b], bnd[b + 1] - 1 - x
            lt = top
            if xl < 3:
                lt += 0.3 * (3 - xl) / 3
            elif xr < 3:
                lt -= 0.3 * (3 - xr) / 3
            if xl < 1 or yy < 1:
                lt = -1.0
            tones.append(tn[b])
            lights.append(lt)
        return tones, lights


def poly_bbox(pts):
    return (min(p[0] for p in pts), min(p[1] for p in pts), max(p[0] for p in pts) + 1, max(p[1] for p in pts) + 1)


# ================================================================== STAGE 1: Glacier Forge Quarry


def s1_sky():
    L = Layer()
    horizon = 252
    sky = Ramp([(0, (9, 8, 32)), (.22, (25, 22, 66)), (.45, (56, 46, 110)), (.62, (110, 74, 140)),
                (.76, (204, 110, 130)), (.88, (250, 156, 118)), (1, (255, 206, 152))])
    L.fill_rows(0, H, lambda y: sky(min(1.0, y / horizon)))
    # low sun glow right of centre
    L.light(560, 252, 760, 190, (255, 140, 80), 0.6)
    L.light(560, 246, 300, 130, (255, 190, 120), 0.5)
    # aurora curtains (additive)
    for seed, base, amp, col, st, ph in ((3, 108, 38, (70, 255, 170), 0.26, 0.4), (5, 150, 30, (120, 150, 255), 0.17, 2.1)):
        yc = [base + amp * math.sin(x / 190 + ph) + amp * 0.5 * math.sin(x / 77 + ph * 2) for x in range(W)]
        env = [clamp(0.35 + 0.65 * math.sin(x / 300 + ph)) for x in range(W)]
        rays = [0.6 + 0.4 * math.sin(x * 0.33 + 3 * math.sin(x * 0.045 + ph)) for x in range(W)]
        for y in range(int(base - amp * 1.6 - 70), int(base + amp * 1.6 + 70)):
            al = []
            for x in range(W):
                d = (y - yc[x]) / 34.0
                a = math.exp(-d * d * (1.4 if d < 0 else 5.5))
                al.append(st * a * rays[x] * env[x])
            L.add_row(y, 0, [col[0]] * W, [col[1]] * W, [col[2]] * W, al)
    # stars
    rnd = random.Random(7)
    for i in range(260):
        x, y = rnd.uniform(0, W), 250 * rnd.random() ** 1.5
        b = rnd.uniform(0.25, 1.0) * (1 - smoothstep(110, 250, y))
        if b < 0.08:
            continue
        sz = rnd.choice((0.8, 0.9, 1.0, 1.2, 1.6))
        col = rnd.choice(((220, 230, 255), (255, 240, 220), (200, 215, 255)))
        L.sparkle(x, y, sz, col, b, flare=rnd.choice((0, 0, 0, 0, 9)) if b > 0.7 else 0)
    # cloud wisps lit from below
    cl = FBM(31, [(340, 60, 0.6), (140, 28, 0.4)])
    for y in range(90, 262):
        band = smoothstep(90, 140, y) * (1 - smoothstep(195, 252, y))
        n = cl.row(y)
        al = [0.6 * smoothstep(0.5, 0.64, v) * band for v in n]
        t = (y - 100) / 150.0
        c = lerpc((92, 78, 138), (244, 150, 140), clamp(t))
        L.blend(y, 0, [c[0]] * W, [c[1]] * W, [c[2]] * W, al)
    # sun disc
    L.disc(560, 238, 34, sh_px(lambda x, y: lerpc((255, 248, 220), (255, 176, 112),
                                                   clamp(math.hypot(x - 560, y - 238) / 34) ** 1.5)))
    L.light(560, 238, 120, 120, (255, 205, 140), 0.8)

    # distant ranges: sun-side faces catch warm light, bottoms dissolve into the horizon haze
    def range_layer(seed, base, amp, cell, haze, snow_hi):
        v = profile(seed, cell, 5, ridged=True)
        top = [base - amp * q for q in v]
        streak = FBM(seed + 9, [(70, 90, 0.7), (26, 40, 0.3)])

        def fn(y, xa, xb):
            sn = streak.row(y)
            rs, gs, bs = [], [], []
            for x in range(xa, xb):
                ds = top[min(W - 1, x + 6)] - top[max(0, x - 6)]
                lit = clamp(0.42 + ds * 0.06 + (sn[x] - 0.5) * 0.55)
                c = lerpc((54, 48, 104), snow_hi, lit ** 1.4)
                d = y - top[x]
                hz = clamp(haze + 0.55 * smoothstep(0, 90, d))
                hc = sky(min(1.0, y / horizon))
                c = lerpc(c, hc, hz)
                rim = clamp(1 - d / 6.0)
                c = lerpc(c, (255, 226, 200), rim * 0.55 * lit)
                rs.append(c[0]), gs.append(c[1]), bs.append(c[2])
            return rs, gs, bs
        L.draw(0, min(top) - 2, W, H, cov_below(top), sh_rows(fn))

    range_layer(41, 236, 92, 190, 0.3, (226, 150, 150))
    range_layer(43, 264, 62, 120, 0.1, (196, 120, 148))
    L.light(560, 262, 960, 70, (255, 180, 150), 0.3)
    return L


def s1_glacier():
    L = Layer()
    v = profile(11, 230, 5, ridged=True)
    top = [250 - 112 * q for q in v]
    streak = FBM(61, [(80, 140, 0.55), (34, 70, 0.3), (12, 30, 0.15)])
    capn = FBM(62, [(60, 40, 0.6), (22, 14, 0.4)])
    ice = Ramp([(0, (30, 42, 92)), (.3, (62, 96, 160)), (.55, (110, 158, 210)), (.8, (182, 224, 248)), (1, (242, 250, 255))])

    def fn(y, xa, xb):
        sn = streak.row(y)
        cn = capn.row(y)
        rs, gs, bs = [], [], []
        for x in range(xa, xb):
            ds = top[min(W - 1, x + 7)] - top[max(0, x - 7)]
            lit = clamp(0.5 + ds * 0.035)
            d = y - top[x]
            val = 0.06 + lit * 0.4 + (sn[x] - 0.5) * 0.7 + 0.05 * math.sin(y * 0.13 + sn[x] * 6) - smoothstep(0, 120, d) * 0.3
            c = ice(val)
            capth = 8 + 20 * cn[x] * (0.4 + lit)
            sm = 1 - smoothstep(capth - 5, capth + 2, d)
            c = lerpc(c, (236, 244, 255), sm * 0.9)
            c = lerpc(c, (255, 255, 255), clamp(1 - d / 2.5) * 0.7)
            rs.append(c[0]), gs.append(c[1]), bs.append(c[2])
        return rs, gs, bs
    L.draw(0, min(top) - 2, W, H, cov_below(top), sh_rows(fn))
    # crevasses: dark cracks with a pale lip
    rnd = random.Random(13)
    for _ in range(26):
        x = rnd.uniform(0, W)
        y = top[int(x)] + rnd.uniform(24, 60)
        for _ in range(rnd.randint(3, 6)):
            nx, ny = x + rnd.uniform(-16, 16), y + rnd.uniform(14, 34)
            L.stroke(x + 1.5, y, nx + 1.5, ny, 1.6, (150, 196, 235), 0.35)
            L.stroke(x, y, nx, ny, 2.0, (18, 28, 70), 0.55)
            x, y = nx, ny
    # forges
    stone = Ramp([(0, (22, 18, 34)), (.5, (46, 40, 60)), (1, (92, 82, 104))])
    fcourse = Courses(5, 16, 28, 54, 340, 12)
    forges = (240, 660)
    for fx in forges:
        bx0, bx1, by0 = fx - 112, fx + 112, 206
        mx, my = fx - 34, 266

        def body(x, y, fx=fx, mx=mx, my=my):
            return None

        def bfn(y, xa, xb, fx=fx, mx=mx, my=my):
            info = fcourse.row(y, xa, xb)
            rs, gs, bs = [], [], []
            for i, x in enumerate(range(xa, xb)):
                tone, lt = (info[0][i], info[1][i]) if info else (0.5, 0.0)
                base = 0.22 + tone * 0.3 + (0.12 * lt if lt > -1 else -0.2)
                c = stone(base)
                warm = clamp(1 - math.hypot((x - mx) * 0.8, (y - my) * 1.2) / 210.0) ** 2
                c = (c[0] + 190 * warm, c[1] + 78 * warm, c[2] + 22 * warm)
                shade = 1 - 0.25 * smoothstep(bx0, bx0 + 20, bx0 + 20 - (x - bx0)) if x < bx0 + 20 else 1
                rs.append(c[0] * shade), gs.append(c[1] * shade), bs.append(c[2] * shade)
            return rs, gs, bs
        L.draw(bx0, by0, bx1, 345, cov_rect(bx0, by0, bx1, 345), sh_rows(bfn))
        # roof with snow
        roof = [(bx0 - 22, by0 + 2), (fx - 20, 156), (fx + 20, 156), (bx1 + 22, by0 + 2)]
        bb = poly_bbox(roof)
        L.draw(bb[0], bb[1], bb[2], bb[3], cov_poly(roof),
               sh_px(lambda x, y, fx=fx: lerpc((28, 24, 44), (66, 58, 88), clamp(0.2 + (x - fx) / 400.0 + (206 - y) / 160.0))))
        snow = [(bx0 - 24, by0 - 2), (fx - 21, 152), (fx + 21, 152), (bx1 + 24, by0 - 2),
                (bx1 + 14, by0 - 8), (fx + 18, 160), (fx - 18, 160), (bx0 - 14, by0 - 8)]
        L.draw(bb[0] - 4, bb[1] - 6, bb[2] + 4, bb[3], cov_poly(snow),
               sh_px(lambda x, y: lerpc((246, 250, 255), (176, 198, 232), clamp((y - 152) / 52.0))))
        L.stroke(bx0 - 24, by0 + 3, bx1 + 24, by0 + 3, 4, (14, 12, 24), 0.55)  # eave shadow
        # chimney
        cx0, cx1 = fx + 56, fx + 90
        L.draw(cx0, 96, cx1, 190, cov_rect(cx0, 96, cx1, 190),
               sh_px(lambda x, y, cx0=cx0: lerpc((30, 26, 42), (82, 72, 96), clamp((x - cx0) / 34.0) ** 1.3)))
        L.draw(cx0 - 4, 90, cx1 + 4, 100, cov_rect(cx0 - 4, 90, cx1 + 4, 100), sh_flat((70, 62, 86)))
        L.draw(cx0 - 5, 84, cx1 + 5, 92, cov_rect(cx0 - 5, 84, cx1 + 5, 92), sh_flat((238, 246, 255)))
        # furnace mouth: arch frame + white-hot interior
        fw, ftop = 40, 212
        arch = lambda x, y, mx=mx: (max(math.hypot(x - mx, y - (ftop + fw)) - fw, 0.0) if y < ftop + fw
                                    else abs(x - mx) - fw) if y < 330 else 99.0
        L.draw(mx - fw - 12, ftop - 14, mx + fw + 12, 332,
               cov_sdf(lambda x, y, mx=mx: (math.hypot(x - mx, y - (ftop - 10 + fw + 12)) - (fw + 12)) if y < ftop + fw + 2
                       else abs(x - mx) - (fw + 12)),
               sh_px(lambda x, y, mx=mx: lerpc((70, 62, 84), (130, 118, 140), clamp(0.5 + (x - mx) / 160.0))))
        hot = Ramp([(0, (255, 252, 226)), (.3, (255, 214, 110)), (.62, (244, 118, 34)), (1, (110, 28, 14))])
        L.draw(mx - fw, ftop, mx + fw, 332,
               cov_sdf(lambda x, y, mx=mx: (math.hypot(x - mx, y - (ftop + fw)) - fw) if y < ftop + fw else abs(x - mx) - fw),
               sh_px(lambda x, y, mx=mx: hot(math.hypot((x - mx) * 0.9, (y - 288) * 0.62) / 52.0)))
        # window slits
        for wx in (fx + 40, fx + 82):
            L.draw(wx - 6, 222, wx + 6, 252,
                   cov_sdf(lambda x, y, wx=wx: (math.hypot(x - wx, y - 228) - 6) if y < 228 else max(abs(x - wx) - 6, y - 252)),
                   sh_px(lambda x, y: lerpc((255, 214, 120), (232, 112, 40), clamp((y - 222) / 30.0))))
    # haze toward the horizon (before glows so they stay vivid)
    L.tint(0, H, (96, 88, 156), lambda y: 0.36 * smoothstep(160, 320, y))
    # smoke, embers, glow
    for fx in forges:
        mx = fx - 34
        sx, sy = fx + 73, 84
        for i in range(20):
            t = i / 19.0
            cx = sx + t * 120 + math.sin(i * 1.7) * 9
            cy = sy - t * 90 - 8
            r = 14 + t * 44
            warm = clamp(1 - t * 2.4)
            col = lerpc((78, 70, 102), (170, 104, 90), warm * 0.6)
            for dx, dy, k in ((0, 0, 1.0), (-0.45, 0.2, 0.7), (0.5, -0.15, 0.75)):
                L.blob(cx + dx * r, cy + dy * r, r * (0.8 + 0.2 * k), r * 0.7, col, 0.34 * (1 - t) ** 1.1 * k, 1.4)
        L.light(mx, 262, 520, 300, (255, 96, 30), 0.13)
        L.light(mx, 262, 300, 200, (255, 140, 50), 0.34)
        L.light(mx, 262, 120, 100, (255, 214, 120), 0.62)
        for wx in (fx + 40, fx + 82):
            L.light(wx, 238, 36, 36, (255, 170, 70), 0.5)
        rnd = random.Random(fx)
        for _ in range(16):
            ex, ey = mx + rnd.uniform(-60, 90) + (rnd.random() * 80 if rnd.random() < .4 else 0), 266 - rnd.uniform(10, 120)
            L.sparkle(ex, ey, rnd.uniform(0.7, 1.3), (255, 170, 70), rnd.uniform(0.5, 0.95))
    # glints on the glacier crest
    rnd = random.Random(17)
    for _ in range(30):
        x = rnd.randrange(8, 920)
        L.sparkle(x, top[x] + rnd.uniform(0, 6), rnd.uniform(0.8, 1.5), (210, 236, 255), rnd.uniform(0.4, 0.9),
                  flare=rnd.choice((0, 0, 0, 8, 12)))
    return L


def s1_quarry():
    L = Layer()
    v = profile(21, 110, 3)
    top = [280 + 22 * q for q in v]
    wall = Courses(9, 23, 46, 100, FLOOR, 7)
    rock = Ramp([(0, (22, 20, 32)), (.35, (46, 42, 62)), (.7, (84, 78, 98)), (1, (136, 130, 146))])
    damp = FBM(72, [(150, 70, 0.6), (50, 24, 0.4)])
    frost = FBM(73, [(70, 46, 0.5), (24, 16, 0.5)])

    def wfn(y, xa, xb):
        info = wall.row(y, xa, xb)
        dn, fn_ = damp.row(y), frost.row(y)
        rs, gs, bs = [], [], []
        ao = 0.62 + 0.38 * smoothstep(0, 40, FLOOR - y)
        for i, x in enumerate(range(xa, xb)):
            if info:
                tone, lt = info[0][i], info[1][i]
            else:
                tone, lt = 0.5, 0.0
            if lt <= -1:
                c = (14, 12, 22)
            else:
                base = 0.28 + tone * 0.32 + lt * 0.22 + (dn[x] - 0.5) * 0.32
                c = rock(base)
                fr = smoothstep(0.62, 0.8, fn_[x]) * (1 - smoothstep(top[x] + 20, top[x] + 70, y)) * 0.55
                c = lerpc(c, (200, 220, 244), fr)
            rs.append(c[0] * ao), gs.append(c[1] * ao), bs.append(c[2] * ao)
        return rs, gs, bs
    L.draw(0, min(top) - 2, W, FLOOR, cov_below(top), sh_rows(wfn))
    # buttresses (the snow cap below is drawn over their tops)
    for bx in (150, 480, 940, 1400):
        y0 = int(top[bx]) - 8
        L.draw(bx - 26, y0, bx + 26, FLOOR,
               cov_rect(bx - 26, y0, bx + 26, FLOOR),
               sh_px(lambda x, y, bx=bx: lerpc((26, 24, 40), (122, 116, 138),
                                               clamp(0.5 + (x - bx) / 70.0 + (hash01(x // 3, y // 22, 4) - .5) * .12) ** 1.2)))
    # snow cap with soft shadowed underside
    cap = FBM(74, [(80, 30, 0.6), (26, 12, 0.4)])
    capy = [t + 8 + 22 * c for t, c in zip(top, cap.row(40))]
    L.draw(0, min(top) - 8, W, max(capy) + 8,
           lambda y, xa, xb: [min(1.0, max(0.0, y + 1.0 - (t - 6))) * min(1.0, max(0.0, (c) - y)) for t, c in zip(top[xa:xb], capy[xa:xb])],
           sh_px(lambda x, y: lerpc((250, 252, 255), (160, 184, 224), smoothstep(top[x] - 6, capy[x], y))))
    L.draw(0, min(top), W, max(capy) + 16,
           lambda y, xa, xb: [0.5 * min(1.0, max(0.0, y + 1.0 - c)) * (1 - smoothstep(c, c + 14, y + 0.5)) for c in capy[xa:xb]],
           sh_flat((14, 14, 34)))
    # icicles
    rnd = random.Random(22)
    x = 6.0
    while x < W - 6:
        ln, bw = rnd.uniform(10, 40), rnd.uniform(4, 8)
        y0 = capy[int(x)] - 3
        pts = [(x - bw / 2, y0), (x + bw / 2, y0), (x + rnd.uniform(-1, 1), y0 + ln)]
        bb = poly_bbox(pts)
        L.draw(bb[0], bb[1], bb[2], bb[3], cov_poly(pts),
               sh_px(lambda xx, yy, y0=y0, ln=ln, x=x: lerpc((236, 248, 255), (110, 162, 222), clamp((yy - y0) / ln) ** 0.8)
                     if xx > x - 1 else lerpc((190, 220, 246), (90, 140, 208), clamp((yy - y0) / ln))))
        x += rnd.uniform(26, 90)
    # floor: packed snow over slabs, vignetted toward the viewer
    drift = FBM(75, [(260, 28, 0.6), (80, 12, 0.4)])
    snowr = Ramp([(0, (92, 108, 150)), (.4, (146, 166, 206)), (1, (208, 222, 244))])
    FH = H - FLOOR
    ys = [0]
    g = 8.0
    while ys[-1] < FH:
        ys.append(ys[-1] + g)
        g *= 1.28

    def ffn(y, xa, xb):
        t = (y - FLOOR) / FH
        dn = drift.row(y)
        k = max(i for i, v in enumerate(ys) if v <= y - FLOOR)
        scale = 0.62 + 1.9 * t
        tw = 150.0
        rs, gs, bs = [], [], []
        for x in range(xa, xb):
            u = (x - 768) / scale / tw + 0.5 * (k % 2)
            j = math.floor(u)
            fu = u - j
            tone = hash01(j, k, 31)
            val = lerp(0.8, 0.3, t) + (dn[x] - 0.5) * 0.45 + (tone - 0.5) * 0.12
            c = snowr(val)
            jd = min(fu, 1 - fu) * tw * scale
            hd = min(y - FLOOR - ys[k], ys[k + 1] - (y - FLOOR))
            line = (1 - smoothstep(0.6, 2.4, jd)) * (0.4 if hd > 0 else 0) + (1 - smoothstep(0.4, 2.0, hd)) * 0.45
            cover = smoothstep(0.52, 0.68, dn[x])  # snow drifts hide joints
            c = lerpc(c, (52, 62, 104), line * (1 - cover * 0.8) * 0.8)
            rs.append(c[0]), gs.append(c[1]), bs.append(c[2])
        return rs, gs, bs
    L.draw(0, FLOOR, W, H, cov_rect(0, FLOOR, W, H), sh_rows(ffn))
    # torches: bracket, flame, wall glow, floor pool
    flame = Ramp([(0, (255, 252, 230)), (.35, (255, 214, 100)), (.7, (246, 124, 40)), (1, (150, 44, 20))])
    for tx in (250, 710, 1170):
        L.stroke(tx, 312, tx, 346, 6, (20, 18, 28), 1.0)
        L.draw(tx - 11, 298, tx + 11, 314,
               cov_sdf(lambda x, y, tx=tx: max(abs(x - tx) - 10, abs(y - 306) - 6) - 2),
               sh_px(lambda x, y: lerpc((58, 52, 70), (22, 20, 30), clamp((y - 298) / 16.0))))
        fy = 286
        L.draw(tx - 16, fy - 40, tx + 16, fy + 16,
               cov_sdf(lambda x, y, tx=tx, fy=fy: math.hypot((x - tx) * (1 + 0.5 * clamp((fy - y) / 36.0)), (y - fy) * 0.5) - 11),
               sh_px(lambda x, y, tx=tx, fy=fy: flame(clamp(math.hypot((x - tx) * 0.9, (y - fy + 4) * 0.55) / 12.0))))
        L.light(tx, 296, 190, 140, (255, 150, 60), 0.5)
        L.light(tx, 290, 80, 66, (255, 212, 120), 0.65)
        L.light(tx, FLOOR + 24, 230, 34, (255, 150, 70), 0.17)
    # snow sparkle
    rnd = random.Random(23)
    for _ in range(300):
        x, y = rnd.uniform(0, W), rnd.uniform(FLOOR + 3, H)
        L.sparkle(x, y, rnd.uniform(0.45, 0.95), (210, 230, 255), rnd.uniform(0.25, 0.75), flare=rnd.choice((0,) * 14 + (6, 9)))
    # floor line: dark contact edge + thin snow rim below it
    L.draw(0, FLOOR - 3, W, FLOOR + 1, cov_rect(0, FLOOR - 3, W, FLOOR + 1), sh_flat((46, 54, 88)))
    L.draw(0, FLOOR - 3, W, FLOOR - 2, lambda y, xa, xb: [0.4] * (xb - xa), sh_flat((14, 14, 30)))
    L.draw(0, FLOOR + 1, W, FLOOR + 3, cov_rect(0, FLOOR + 1, W, FLOOR + 3), sh_flat((226, 236, 252)))
    return L


# ================================================================== STAGE 2: Bell Tower Cloister


MOON = (300, 122)


def s2_sky():
    L = Layer()
    horizon = 330
    sky = Ramp([(0, (5, 7, 24)), (.3, (12, 18, 50)), (.55, (30, 36, 84)), (.78, (66, 62, 116)), (1, (120, 94, 132))])
    L.fill_rows(0, H, lambda y: sky(min(1.0, y / horizon)))
    L.light(MOON[0], MOON[1], 700, 520, (110, 130, 230), 0.34)
    L.light(MOON[0], MOON[1], 230, 230, (170, 190, 255), 0.4)
    rnd = random.Random(2)
    for i in range(380):
        x, y = rnd.uniform(0, W), 300 * rnd.random() ** 1.4
        if math.hypot(x - MOON[0], y - MOON[1]) < 70:
            continue
        b = rnd.uniform(0.2, 1.0) * (1 - smoothstep(150, 300, y))
        if b < 0.07:
            continue
        col = rnd.choice(((220, 228, 255), (255, 238, 220), (190, 205, 255)))
        L.sparkle(x, y, rnd.choice((0.7, 0.8, 0.9, 1.1, 1.5)), col, b, flare=rnd.choice((0,) * 6 + (8, 11)) if b > 0.75 else 0)
    # silver-edged clouds near the moon
    cl = FBM(33, [(380, 54, 0.6), (150, 24, 0.4)])
    for y in range(40, 290):
        n = cl.row(y)
        band = smoothstep(40, 90, y) * (1 - smoothstep(200, 290, y))
        al, rs, gs, bs = [], [], [], []
        for x in range(W):
            m = clamp(1 - math.hypot(x - MOON[0], (y - MOON[1]) * 1.4) / 700.0)
            a = 0.62 * smoothstep(0.5, 0.64, n[x]) * band
            c = lerpc((26, 30, 66), (180, 192, 238), m ** 1.3)
            al.append(a), rs.append(c[0]), gs.append(c[1]), bs.append(c[2])
        L.blend(y, 0, rs, gs, bs, al)
    # moon: limb-darkened disc with maria
    maria = FBM(34, [(34, 34, 0.55), (14, 14, 0.45)])
    mr = 42
    mrows = {y: maria.row(y) for y in range(MOON[1] - mr - 2, MOON[1] + mr + 3)}
    L.disc(MOON[0], MOON[1], mr, sh_px(lambda x, y: lerpc(
        lerpc((250, 250, 238), (186, 190, 182), smoothstep(0.35, 0.62, mrows[int(y)][int(x)])),
        (206, 210, 214), clamp(math.hypot(x - MOON[0], y - MOON[1]) / mr) ** 3 * 0.8)))
    L.light(MOON[0] - 8, MOON[1] - 8, 70, 70, (255, 255, 240), 0.35)

    # village ridge with lit windows
    v = profile(51, 260, 5)
    top = [316 - 46 * q for q in v]
    ridge = Ramp([(0, (30, 30, 66)), (1, (66, 60, 110))])

    def rfn(y, xa, xb):
        rs, gs, bs = [], [], []
        for x in range(xa, xb):
            d = y - top[x]
            c = lerpc(ridge(clamp((y - 270) / 120.0)), sky(min(1.0, y / horizon)), 0.25 + 0.6 * smoothstep(0, 70, d))
            c = lerpc(c, (190, 200, 255), clamp(1 - d / 5.0) * 0.35 * clamp((x - 400) / 900.0))
            rs.append(c[0]), gs.append(c[1]), bs.append(c[2])
        return rs, gs, bs
    L.draw(0, min(top) - 2, W, H, cov_below(top), sh_rows(rfn))
    rnd = random.Random(52)
    for _ in range(46):
        x = rnd.randrange(10, W - 10)
        y = top[x] + rnd.uniform(10, 46)
        L.light(x, y, 9, 9, (255, 190, 90), 0.8, 1.3)
        L.light(x, y, 2.4, 2.4, (255, 236, 170), 1.0, 1.0)
    L.light(768, 346, 980, 70, (170, 150, 200), 0.3)
    return L


def tower_geometry():
    return ((40, 140, 300, "spire"), (390, 180, 352, "spire"), (790, 140, 280, "hip"), (1180, 160, 320, "spire"))


def s2_bells():
    L = Layer()
    stone = Ramp([(0, (14, 14, 32)), (.4, (40, 40, 76)), (.75, (82, 82, 128)), (1, (150, 156, 204))])
    slate = Ramp([(0, (10, 12, 28)), (.5, (30, 34, 66)), (1, (80, 88, 136))])
    bronze = Ramp([(0, (96, 52, 18)), (.35, (186, 118, 40)), (.7, (252, 200, 100)), (1, (255, 240, 190))])
    # low monastery roofline joining the towers
    rnd = random.Random(53)
    xs, x = [0], 0
    while x < W:
        x += rnd.randint(150, 280)
        xs.append(x)
    base_top = [0.0] * W
    for a, b in zip(xs, xs[1:]):
        h = rnd.uniform(0.6, 1.0)
        for xx in range(a, min(b, W)):
            f = (xx - a) / (b - a)
            base_top[xx] = 318 - 30 * h * (1 - abs(2 * f - 1) ** 1.3) - 8
    L.draw(0, 270, W, H, cov_below(base_top),
           sh_px(lambda x, y: lerpc((20, 20, 44), (52, 54, 94), clamp(0.3 + (x - 700) / 2200.0 + (318 - y) / 120.0 * 0.3))))
    # towers
    ash = Courses(17, 18, 30, 52, H, 26)
    for tx, tw, th, kind in tower_geometry():
        top = H - th
        cx = tx + tw // 2

        def body(y, xa, xb, tx=tx, tw=tw, top=top):
            info = ash.row(y, xa, xb)
            rs, gs, bs = [], [], []
            for i, x in enumerate(range(xa, xb)):
                u = (x - tx) / tw
                tone, lt = (info[0][i], info[1][i]) if info else (0.5, 0.0)
                val = 0.12 + 0.55 * u ** 1.4 + (tone - 0.5) * 0.1 + (0.05 * lt if lt > -1 else -0.1)
                val += 0.18 * clamp(1 - (tx + tw - x) / 6.0)          # moon rim on the lit edge
                val -= 0.2 * clamp(1 - (x - tx) / 10.0)
                c = stone(val)
                rs.append(c[0]), gs.append(c[1]), bs.append(c[2])
            return rs, gs, bs
        L.draw(tx, top, tx + tw, H, cov_rect(tx, top, tx + tw, H), sh_rows(body))
        # cornices
        for cy_, hh in ((top, 8), (top + 188 if th > 200 else top + 150, 6)):
            L.draw(tx - 8, cy_, tx + tw + 8, cy_ + hh, cov_rect(tx - 8, cy_, tx + tw + 8, cy_ + hh),
                   sh_px(lambda x, y, tx=tx, tw=tw, cy_=cy_, hh=hh: stone(0.55 + 0.3 * (x - tx) / tw - 0.4 * (y - cy_) / hh)))
        # roof
        rh = 96 if kind == "spire" else 46
        pts = [(tx - 14, top), (cx, top - rh), (tx + tw + 14, top)]
        bb = poly_bbox(pts)
        L.draw(bb[0], bb[1], bb[2], bb[3], cov_poly(pts),
               sh_px(lambda x, y, cx=cx: slate(0.16 + (0.5 if x > cx else 0.0) + 0.14 * (hash01(int(y) // 7, 3) - .5)
                                               - 0.0006 * (x - cx) * (x - cx) / 100.0
                                               + (0.12 if (int(y) % 8) < 2 else 0.0))))
        L.stroke(cx, top - rh, tx + tw + 14, top, 2.2, (160, 170, 232), 0.5)
        if kind == "spire":
            L.stroke(cx, top - rh - 2, cx, top - rh - 22, 3, (30, 30, 58), 1.0)
            L.stroke(cx - 7, top - rh - 15, cx + 7, top - rh - 15, 2.4, (30, 30, 58), 1.0)
        # belfry opening and bell
        ow, oy = 28, top + 38
        oh = 76
        L.draw(cx - ow - 8, oy - ow - 8, cx + ow + 8, oy + oh + 6,
               cov_sdf(lambda x, y, cx=cx: (math.hypot(x - cx, y - oy) - ow - 7) if y < oy else (abs(x - cx) - ow - 7)),
               sh_px(lambda x, y, cx=cx: stone(0.5 + 0.3 * clamp((x - cx) / 40.0) - 0.25 * clamp(-(x - cx) / 40.0))))
        L.draw(cx - ow, oy - ow, cx + ow, oy + oh,
               cov_sdf(lambda x, y, cx=cx: (math.hypot(x - cx, y - oy) - ow) if y < oy else (abs(x - cx) - ow)),
               sh_px(lambda x, y, cx=cx: lerpc((6, 6, 20), (44, 28, 36), clamp((y - oy) / 70.0) ** 1.5)))
        by = oy + 30
        L.stroke(cx, oy - ow, cx, by - 20, 2.5, (10, 8, 18), 1.0)
        L.draw(cx - 24, by - 22, cx + 24, by + 28,
               cov_sdf(lambda x, y, cx=cx, by=by: (math.hypot(x - cx, y - by) - 17) if y < by else
                       (abs(x - cx) - (17 + (y - by) * 0.38)) if y < by + 24 else max(abs(x - cx) - 26, abs(y - by - 26) - 3)),
               sh_px(lambda x, y, cx=cx, by=by: bronze(0.2 + 0.7 * clamp(0.5 + (cx - x) / 60.0) ** 1.4 * (1 - clamp((y - by) / 90.0)) )))
        # slit windows
        for wy in (top + 128 if th > 200 else top + 112,):
            for wx in (cx - 22, cx + 22):
                L.draw(wx - 4, wy - 4, wx + 4, wy + 26,
                       cov_sdf(lambda x, y, wx=wx, wy=wy: (math.hypot(x - wx, y - wy) - 4) if y < wy else max(abs(x - wx) - 4, y - wy - 26)),
                       sh_flat((8, 8, 22)))
    # distance haze, then light so the glows stay punchy
    L.tint(0, H, (98, 92, 150), lambda y: 0.62 * smoothstep(230, 400, y))
    rnd = random.Random(54)
    for tx, tw, th, kind in tower_geometry():
        top, cx = H - th, tx + tw // 2
        oy = top + 38
        L.light(cx, oy + 30, 120, 120, (255, 168, 72), 0.42)
        L.light(cx, oy + 40, 50, 56, (255, 214, 130), 0.5)
        for wx in (cx - 22, cx + 22):
            wy = top + 128 if th > 200 else top + 112
            L.light(wx, wy + 10, 22, 30, (255, 180, 80), 0.55)
            L.light(wx, wy + 10, 5, 14, (255, 234, 170), 0.8, 1.0)
    for a, b in zip(xs, xs[1:]):
        for _ in range(3):
            x = rnd.uniform(a + 20, min(b, W) - 20)
            y = base_top[min(W - 1, int(x))] + rnd.uniform(16, 40)
            L.light(x, y, 9, 9, (255, 190, 90), 0.8, 1.3)
            L.light(x, y, 2.4, 2.4, (255, 236, 170), 1.0, 1.0)
    return L


ARC_P = 192          # arcade column spacing (texels)
CORN_T, CORN_B = 50, 84
SPRING = 168         # arch spring line
ARC_A, ARC_RY = 80, 70
COL_HW = 15
PARAPET_T = 332


def arch_open_dist(x, y):
    """Signed distance to the nearest arch opening (negative inside)."""
    dx = (x % ARC_P) - ARC_P / 2
    if y >= SPRING:
        return abs(dx) - ARC_A
    q = math.sqrt((dx / ARC_A) ** 2 + ((y - SPRING) / ARC_RY) ** 2)
    return (q - 1) * min(ARC_A, ARC_RY) * 0.92


def s2_floor():
    L = Layer()
    stone = Ramp([(0, (16, 16, 30)), (.3, (44, 42, 68)), (.62, (92, 90, 122)), (.85, (146, 146, 176)), (1, (206, 208, 232))])
    wall = Courses(41, 20, 40, 78, SPRING + 6, 11)
    grain = FBM(81, [(40, 40, 0.5), (14, 14, 0.3), (6, 6, 0.2)])
    # entablature + arch wall (everything except openings, columns and parapet)
    grn = {}

    def wfn(y, xa, xb, al):
        info = wall.row(y, xa, xb)
        gr = grn.setdefault(y, grain.row(y))
        rs, gs, bs = [], [], []
        for i, x in enumerate(range(xa, xb)):
            if y < CORN_B:
                # cornice: lit top moulding, dentils, deep shadow beneath
                t = (y - CORN_T) / (CORN_B - CORN_T)
                val = 0.62 - 0.25 * t + 0.07 * (1 if (x % 18) < 11 and y > CORN_B - 9 else -0.4 if y > CORN_B - 9 else 0)
                if y < CORN_T + 8:
                    val += 0.25 * (1 - (y - CORN_T) / 8.0)
                val += (gr[x] - 0.5) * 0.14
                c = stone(val * (0.75 + 0.35 * clamp((x % ARC_P) / ARC_P)))
            else:
                d = arch_open_dist(x + 0.5, y + 0.5)
                tone, lt = (info[0][i], info[1][i]) if info else (0.5, 0.0)
                dx = (x % ARC_P) - ARC_P / 2
                val = 0.34 + tone * 0.12 + (gr[x] - 0.5) * 0.2 + (0.1 * lt if lt > -1 else -0.16)
                val += 0.12 * clamp(dx / 90.0)                      # moonlight from the right
                shadow = 0.5 * (1 - smoothstep(CORN_B, CORN_B + 22, y))
                val -= shadow
                if d < 18:
                    # archivolt: voussoirs, shadowed soffit right against the opening
                    ang = math.atan2(SPRING - y, dx) if y < SPRING else (math.pi / 2 if dx > 0 else -math.pi / 2) * 0 + math.pi / 2
                    k = (ang * 15 / math.pi) % 1.0
                    ring = 0.2 + 0.05 * hash01(int(ang * 15 / math.pi), 3, 8)
                    joint = 1 - smoothstep(0.0, 0.07, min(k, 1 - k)) if y < SPRING else 0
                    val = 0.32 + ring + (gr[x] - 0.5) * 0.14 - joint * 0.22 + 0.1 * clamp(dx / 90.0)
                    val -= 0.34 * (1 - smoothstep(0, 6, d))
                    val += 0.12 * (1 - smoothstep(10, 18, d)) * 0
                c = stone(val)
            rs.append(c[0]), gs.append(c[1]), bs.append(c[2])
        return rs, gs, bs

    def wcov(y, xa, xb):
        if y < CORN_T or y >= PARAPET_T + 60:
            return [0.0] * (xb - xa)
        yy = y + 0.5
        if y < CORN_B:
            top = min(1.0, max(0.0, y + 1.0 - CORN_T))
            return [top] * (xb - xa)
        out = []
        for x in range(xa, xb):
            d = arch_open_dist(x + 0.5, yy)
            out.append(min(1.0, max(0.0, 0.5 + d)))
        return out
    L.draw(0, CORN_T, W, SPRING + 6, wcov, wfn)
    # cornice coping
    L.draw(0, CORN_T - 4, W, CORN_T + 4, cov_rect(0, CORN_T - 4, W, CORN_T + 4),
           sh_px(lambda x, y: stone(0.9 - 0.25 * (y - CORN_T + 4) / 8.0 + 0.0)))
    # columns: fluted shafts, capitals, bases
    for i in range(W // ARC_P + 2):
        cx = i * ARC_P
        L.draw(cx - COL_HW, SPRING, cx + COL_HW, FLOOR - 16, cov_rect(cx - COL_HW, SPRING, cx + COL_HW, FLOOR - 16),
               sh_px(lambda x, y, cx=cx: stone(0.08 + 0.78 * clamp(0.5 + (x - cx) / (2.0 * COL_HW) * 1.05) ** 1.5
                                               - 0.07 * (1 if int(x - cx + 100) % 7 < 2 else 0)
                                               + 0.05 * (hash01(int(x), int(y) // 9, 6) - .5)
                                               - 0.25 * (1 - smoothstep(SPRING, SPRING + 24, y)))))
        # capital: abacus + echinus
        L.draw(cx - 26, SPRING - 14, cx + 26, SPRING - 2, cov_rect(cx - 26, SPRING - 14, cx + 26, SPRING - 2),
               sh_px(lambda x, y, cx=cx: stone(0.78 - 0.22 * (y - SPRING + 14) / 12.0 + 0.1 * clamp((x - cx) / 26.0))))
        L.draw(cx - 22, SPRING - 2, cx + 22, SPRING + 16,
               cov_poly([(cx - 22, SPRING - 2), (cx + 22, SPRING - 2), (cx + COL_HW, SPRING + 16), (cx - COL_HW, SPRING + 16)]),
               sh_px(lambda x, y, cx=cx: stone(0.18 + 0.7 * clamp(0.5 + (x - cx) / 40.0) ** 1.4)))
        # base: torus + plinth
        L.draw(cx - 24, FLOOR - 16, cx + 24, FLOOR - 5, cov_rect(cx - 24, FLOOR - 16, cx + 24, FLOOR - 5),
               sh_px(lambda x, y, cx=cx: stone(0.1 + 0.7 * clamp(0.5 + (x - cx) / 48.0) ** 1.3 + 0.15 * (1 - abs((y - FLOOR + 10.5) / 5.5)))))
        L.draw(cx - 27, FLOOR - 5, cx + 27, FLOOR, cov_rect(cx - 27, FLOOR - 5, cx + 27, FLOOR),
               sh_px(lambda x, y, cx=cx: stone(0.14 + 0.6 * clamp(0.5 + (x - cx) / 54.0) ** 1.3)))
    # parapet between the columns
    for i in range(W // ARC_P + 1):
        x0, x1 = i * ARC_P + COL_HW, (i + 1) * ARC_P - COL_HW
        L.draw(x0, PARAPET_T, x1, FLOOR - 5, cov_rect(x0, PARAPET_T, x1, FLOOR - 5),
               sh_px(lambda x, y: stone(0.3 + 0.1 * (hash01(int(x) // 4, int(y) // 4, 9) - .5) + 0.14 * clamp((x - 96) % ARC_P / ARC_P)
                                        - (0.2 if y > FLOOR - 16 else 0.0))))
        L.draw(x0 - 4, PARAPET_T - 8, x1 + 4, PARAPET_T + 4, cov_rect(x0 - 4, PARAPET_T - 8, x1 + 4, PARAPET_T + 4),
               sh_px(lambda x, y: stone(0.72 - 0.4 * (y - PARAPET_T + 8) / 12.0)))
        px0, px1, py0, py1 = x0 + 16, x1 - 16, PARAPET_T + 10, FLOOR - 14
        L.draw(px0, py0, px1, py1, cov_rect(px0, py0, px1, py1),
               sh_px(lambda x, y: stone(0.2 + 0.18 * (1 if (x - px0 < 3 or y - py0 < 3) is False else 0)
                                        - (0.12 if (x - px0 < 3 or y - py0 < 3) else 0)
                                        + (0.18 if (px1 - x < 3 or py1 - y < 3) else 0))))
    # flagstone floor in perspective with moonlit sheen
    FH = H - FLOOR
    ys = [0]
    g = 8.0
    while ys[-1] < FH:
        ys.append(ys[-1] + g)
        g *= 1.28
    gran = FBM(82, [(90, 24, 0.5), (22, 8, 0.5)])

    def ffn(y, xa, xb):
        t = (y - FLOOR) / FH
        k = max(i for i, v in enumerate(ys) if v <= y - FLOOR)
        scale = 0.62 + 1.9 * t
        gr = gran.row(y)
        tw = 130.0
        rs, gs, bs = [], [], []
        for x in range(xa, xb):
            u = (x - 768) / scale / tw + 0.5 * (k % 2)
            j = math.floor(u)
            fu = u - j
            tone = hash01(j, k, 77)
            jd = min(fu, 1 - fu) * tw * scale
            hd = y - FLOOR - ys[k]
            val = lerp(0.62, 0.22, t) + (tone - 0.5) * 0.14 + (gr[x] - 0.5) * 0.22
            bev = (1 - smoothstep(0.5, 3.0, hd)) * 0.12 + (1 - smoothstep(0.5, 2.6, jd)) * 0.07 * (1 if fu < .5 else -1)
            c = stone(val + bev)
            line = max(1 - smoothstep(0.6, 2.0, jd), 1 - smoothstep(0.2, 1.4, ys[k + 1] - (y - FLOOR) if False else 9) )
            line = (1 - smoothstep(0.5, 2.0, jd))
            c = lerpc(c, (14, 14, 28), line * 0.7)
            rs.append(c[0]), gs.append(c[1]), bs.append(c[2])
        return rs, gs, bs
    L.draw(0, FLOOR, W, H, cov_rect(0, FLOOR, W, H), sh_rows(ffn))
    # hanging lanterns
    gold = Ramp([(0, (200, 120, 40)), (.5, (255, 200, 100)), (1, (255, 246, 210))])
    for i in (1, 3, 5, 7):
        lx = i * ARC_P + ARC_P // 2
        top_y = SPRING - ARC_RY + 6
        L.stroke(lx, top_y, lx, 196, 2.2, (12, 12, 24), 1.0)
        L.draw(lx - 12, 196, lx + 12, 236,
               cov_sdf(lambda x, y, lx=lx: max(abs(x - lx) - (12 - 5 * clamp((236 - y) / 40.0)), abs(y - 216) - 20)),
               sh_px(lambda x, y, lx=lx: gold(clamp(1 - math.hypot((x - lx) * 0.9, (y - 218) * 0.6) / 18.0))))
        for lyy in (196, 236):
            L.draw(lx - 14, lyy - 3, lx + 14, lyy + 3, cov_rect(lx - 14, lyy - 3, lx + 14, lyy + 3), sh_flat((16, 14, 28)))
        L.stroke(lx - 12, 196, lx - 12, 236, 1.6, (16, 14, 28), 0.9)
        L.stroke(lx + 12, 196, lx + 12, 236, 1.6, (16, 14, 28), 0.9)
        L.light(lx, 216, 190, 190, (255, 160, 70), 0.46)
        L.light(lx, 216, 60, 64, (255, 214, 130), 0.62)
        L.light(lx, FLOOR + 22, 210, 30, (255, 160, 80), 0.4)
    # floor edge: warm rim over a dark contact line
    L.draw(0, FLOOR - 1, W, FLOOR + 1, cov_rect(0, FLOOR - 1, W, FLOOR + 1), sh_flat((26, 24, 40)))
    L.draw(0, FLOOR + 1, W, FLOOR + 3, cov_rect(0, FLOOR + 1, W, FLOOR + 3), sh_flat((176, 166, 150)))
    return L


# ------------------------------------------------------------------ main


STAGES = (
    ("stage1", (("glacier_sky.png", s1_sky), ("glacier_forge.png", s1_glacier), ("glacier_quarry.png", s1_quarry))),
    ("stage2", (("cloister_sky.png", s2_sky), ("cloister_bells.png", s2_bells), ("cloister_floor.png", s2_floor))),
)

if __name__ == "__main__":
    root = sys.argv[1] if len(sys.argv) > 1 else os.path.abspath(
        os.path.join(os.path.dirname(__file__), "..", ".."))
    total = 0
    for stage, layers in STAGES:
        d = os.path.join(root, "Content", "Stages", stage, f"{stage}.contentbundle")
        for i, (name, build) in enumerate(layers):
            size, opaque = write_png(os.path.join(d, name), build(), seed=0x5EED + i)
            total += size
            print(f"{os.path.relpath(os.path.join(d, name), root)}: {W}x{H} {'RGB' if opaque else 'RGBA'}, {size} bytes")
    print(f"total {total} bytes")
