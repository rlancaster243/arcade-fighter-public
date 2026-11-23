#!/usr/bin/env python3
"""Rebuild the recorded CC0 impact clips in Content/Audio/ (see Content/Audio/CREDITS.md).

Usage:
  python3 -I scripts/audio/build_cc0_sfx.py <hits_dir> <towel_dir> <out_dir>

  hits_dir   extracted "37 hits/punches" pack (hit01.mp3.flac ... hit37.mp3.flac)
  towel_dir  extracted "12 wet towel ..." pack (wet_towel_on_floor-01.flac ...)
  out_dir    Content/Audio

Needs macOS `afconvert` (FLAC -> 44.1 kHz mono 16-bit WAV). Pure standard library otherwise.
Per clip: find the first sample above `thr` of the source peak, back off 1 ms, trim so the impact
is instant, cut to `ms`, fade the tail over `fade_ms`, optionally low-pass (padded feel), and
peak-normalise to 0.9. Playback level is set by gainQ8 in manifest.json, not baked in here.
"""
import math, os, struct, subprocess, sys, tempfile, wave

SR = 44100

# id: (pack, source stem, threshold, search_from_ms, length_ms, fade_ms, lowpass_hz or None)
CLIPS = {
    "hit_light": ("hits", "hit10.mp3", 0.03, 0, 150, 50, None),
    "hit_heavy": ("hits", "hit22.mp3", 0.03, 0, 320, 90, None),
    "block": ("towel", "wet_towel_on_floor-03", 0.03, 0, 150, 60, 1800),
    "throw": ("towel", "wet_towel_on_floor-07", 0.03, 0, 240, 90, None),
    "ko": ("towel", "wet_towel_on_floor-12", 0.10, 100, 520, 160, None),
}


def read_wav(path):
    with wave.open(path) as w:
        assert (w.getframerate(), w.getnchannels(), w.getsampwidth()) == (SR, 1, 2)
        n = w.getnframes()
        return [v / 32768 for v in struct.unpack("<%dh" % n, w.readframes(n))]


def lowpass(x, fc):
    a = 1 - math.exp(-2 * math.pi * fc / SR)
    for _ in range(2):  # two cascaded one-pole stages
        y, out = 0.0, []
        for v in x:
            y += a * (v - y)
            out.append(y)
        x = out
    return x


def process(x, thr, search_ms, length_ms, fade_ms, lp):
    peak = max(abs(v) for v in x)
    s0 = int(SR * search_ms / 1000)
    on = next(i for i in range(s0, len(x)) if abs(x[i]) >= thr * peak)
    start = max(0, on - int(SR * 0.001))
    seg = x[start:start + int(SR * length_ms / 1000)]
    if lp:
        seg = lowpass(seg, lp)
    n, nf = len(seg), int(SR * fade_ms / 1000)
    ni = int(SR * 0.0003)
    for i in range(ni):
        seg[i] *= i / ni
    for i in range(nf):
        seg[n - 1 - i] *= (i / nf) ** 2
    pk = max(abs(v) for v in seg)
    return [v * 0.9 / pk for v in seg]


def write_wav(path, x):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", max(-32768, min(32767, round(v * 32767)))) for v in x))


def main(hits_dir, towel_dir, out_dir):
    dirs = {"hits": hits_dir, "towel": towel_dir}
    with tempfile.TemporaryDirectory() as tmp:
        for cid, (pack, stem, thr, search_ms, length_ms, fade_ms, lp) in CLIPS.items():
            src = os.path.join(dirs[pack], stem + ".flac")
            conv = os.path.join(tmp, cid + ".wav")
            subprocess.run(["afconvert", "-f", "WAVE", "-d", "LEI16@44100", "-c", "1", src, conv], check=True)
            out = process(read_wav(conv), thr, search_ms, length_ms, fade_ms, lp)
            write_wav(os.path.join(out_dir, cid + ".wav"), out)
            print("%-10s <- %s  %d ms" % (cid, stem, round(len(out) * 1000 / SR)))


if __name__ == "__main__":
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    main(*sys.argv[1:])
