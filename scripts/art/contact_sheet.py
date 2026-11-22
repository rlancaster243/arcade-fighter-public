#!/usr/bin/env python3
"""Contact sheets for the fighter sprites: every frame of both costumes, labelled, in sheet order.

Renders straight from the generator (not from the shipped PNGs), so it shows what
gen_fighters.py would write. Each cell is drawn over a flat backdrop with its border, the ground
line at the anchor row and a tick at the anchor column, which makes clipped parts and floating or
buried feet easy to see. Also reports, per frame:
  - border: opaque texels on the cell's outermost rows / columns (the sprite is cut off there)
  - shift:  how far fit_figure moved the pose to keep it inside the cell
  - overflow: texels that still stick out because the pose is larger than the cell
Exit status is 1 if any frame touches its border or overflows.

Usage: python3 -I scripts/art/contact_sheet.py <out_dir> [--per-page N] [--zoom Z] [--frames a,b,...] [fighter ...]
Writes <out_dir>/<id>_p1.png and <id>_p2.png (or <id>_p1_01.png ... with --per-page).
--frames keeps only the frames whose names match (shell wildcards: `walk_*`); --zoom enlarges cells Z times.
"""
import fnmatch
import os
import sys
from concurrent.futures import ProcessPoolExecutor

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))   # sibling modules, also under `python3 -I`

import gen_fighters as gen  # noqa: E402
import raster as rs  # noqa: E402
from raster import ANCHOR_X, ANCHOR_Y, CELL  # noqa: E402

COLS = gen.COLS
LABEL_H = 16
PAD = 6
BG = (58, 62, 82)
BG_CELL = (72, 78, 100)
LINE = (112, 120, 148)
TEXT = (236, 238, 246)
BAD = (255, 96, 96)

# 3x5 pixel font for frame names
FONT = {
    "a": "010101111101101", "b": "110101110101110", "c": "011100100100011", "d": "110101101101110",
    "e": "111100110100111", "f": "111100110100100", "g": "011100101101011", "h": "101101111101101",
    "i": "111010010010111", "j": "001001001101010", "k": "101101110101101", "l": "100100100100111",
    "m": "101111111101101", "n": "110101101101101", "o": "010101101101010", "p": "110101110100100",
    "q": "010101101111011", "r": "110101110101101", "s": "011100010001110", "t": "111010010010010",
    "u": "101101101101111", "v": "101101101101010", "w": "101101111111101", "x": "101101010101101",
    "y": "101101010010010", "z": "111001010100111", "0": "111101101101111", "1": "010110010010111",
    "2": "110001010100111", "3": "110001010001110", "4": "101101111001001", "5": "111100110001110",
    "6": "011100110101010", "7": "111001010010010", "8": "010101010101010", "9": "010101011001110",
    "_": "000000000000111", "-": "000000111000000", ".": "000000000000010", " ": "000000000000000",
    "+": "000010111010000", "!": "010010010000010",
}


def draw_text(rows, x, y, text, colour, scale=2):
    for ch in text.lower():
        bits = FONT.get(ch, FONT["-"])
        for i, bit in enumerate(bits):
            if bit == "1":
                for sy in range(scale):
                    row = rows[y + (i // 3) * scale + sy]
                    for sx in range(scale):
                        o = (x + (i % 3) * scale + sx) * 3
                        row[o:o + 3] = bytes(colour)
        x += 4 * scale


def border_texels(px):
    """Number of non-transparent texels on the outermost rows and columns of a rendered cell."""
    n = 0
    for i in range(CELL):
        for x, y in ((i, 0), (i, CELL - 1), (0, i), (CELL - 1, i)):
            if px[(y * CELL + x) * 4 + 3]:
                n += 1
    return n


def wanted(name, only):
    return not only or any(fnmatch.fnmatchcase(name, pattern) for pattern in only)


def render_costume(args):
    """Render one costume's frames; returns (fid, p2, [(name, rgba, fit, border)])."""
    root, fid, p2, only = args
    fighter = gen.load_fighter(root, fid)
    out = []
    for name, fig, fit in gen.frames_for(fid, fighter, p2):
        if not wanted(name, only):
            continue
        px = gen.render_frame(name, fig)
        out.append((name, px, fit, border_texels(px)))
    return fid, p2, out


def compose(cells, zoom=1):
    """RGB rows for a page of (name, rgba, fit, border) cells laid out up to COLS wide."""
    cols = min(COLS, len(cells))
    rows_n = (len(cells) + cols - 1) // cols
    Z = CELL * zoom
    cw, chh = Z + PAD, Z + LABEL_H + PAD
    W, H = PAD + cols * cw, PAD + rows_n * chh
    rows = [bytearray(bytes(BG) * W) for _ in range(H)]
    for i, (name, px, fit, border) in enumerate(cells):
        x0, y0 = PAD + (i % cols) * cw, PAD + (i // cols) * chh
        bad = border or fit[2] > 0
        label = name + (" !" if bad else "") + (" %+d,%+d" % (round(fit[0]), round(fit[1])) if fit[0] or fit[1] else "")
        draw_text(rows, x0 + 2, y0 + 3, label, BAD if bad else TEXT)
        y0 += LABEL_H
        for y in range(CELL):
            line = bytearray()
            edge_y = y in (0, CELL - 1)
            for x in range(CELL):
                if edge_y or x in (0, CELL - 1) or y == ANCHOR_Y or (x == ANCHOR_X and y > ANCHOR_Y):
                    bg = BAD if (bad and (edge_y or x in (0, CELL - 1))) else LINE
                else:
                    bg = BG_CELL
                j = (y * CELL + x) * 4
                a = px[j + 3]
                line += bytes((bg[c] * (255 - a) + px[j + c] * a + 127) // 255 for c in range(3)) * zoom
            for zy in range(zoom):
                rows[y0 + y * zoom + zy][x0 * 3:(x0 + Z) * 3] = line
    return W, H, rows


def main(argv):
    opts = {"--per-page": "0", "--zoom": "1", "--frames": ""}
    args = []
    it = iter(argv)
    for a in it:
        if a in opts:
            opts[a] = next(it)
        else:
            args.append(a)
    per_page, zoom = int(opts["--per-page"]), int(opts["--zoom"])
    only = [f for f in opts["--frames"].split(",") if f]
    if not args:
        sys.exit(__doc__)
    out_dir = args[0]
    fighters = args[1:] or list(gen.FIGHTERS)
    os.makedirs(out_dir, exist_ok=True)
    root = gen.repo_root()
    jobs = [(root, fid, p2, only) for fid in fighters for p2 in (False, True)]
    failures = 0
    with ProcessPoolExecutor() as pool:
        for fid, p2, cells in pool.map(render_costume, jobs):
            tag = f"{fid}_{'p2' if p2 else 'p1'}"
            pages = [cells[i:i + per_page] for i in range(0, len(cells), per_page)] if per_page else [cells]
            for n, page in enumerate(pages):
                W, H, rows = compose(page, zoom)
                path = os.path.join(out_dir, tag + (f"_{n + 1:02d}" if per_page else "") + ".png")
                with open(path, "wb") as f:
                    f.write(rs.png_bytes(W, H, rows, 2))
            shifted = [(name, fit) for name, _, fit, _ in cells if fit[0] or fit[1]]
            touching = [(name, b) for name, _, _, b in cells if b]
            over = [(name, fit[2]) for name, _, fit, _ in cells if fit[2] > 0]
            failures += len(touching) + len(over)
            print(f"{tag}: {len(cells)} frames, {len(pages)} page(s); border-touching {len(touching)}, "
                  f"overflowing {len(over)}, shifted {len(shifted)}")
            for name, b in touching:
                print(f"  BORDER   {name}: {b} texels on the cell border")
            for name, o in over:
                print(f"  OVERFLOW {name}: {o:.1f} texels larger than the cell")
            for name, fit in shifted:
                print(f"  shift    {name}: dx {fit[0]:+.1f} dy {fit[1]:+.1f}")
    print("contact sheets in", out_dir)
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
