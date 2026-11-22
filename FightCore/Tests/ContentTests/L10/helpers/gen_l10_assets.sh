#!/usr/bin/env bash
# One-shot asset synthesis for L10 (fighters, stage, SFX). Re-run from repo root.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../../.." && pwd)"
cd "$ROOT"

mk_sprite() {
  local out="$1" color="$2"
  ffmpeg -y -loglevel error -f lavfi -i "color=c=${color}:s=112x112" -frames:v 1 -pix_fmt pal8 "$out"
}

mk_sheet_pair() {
  local dir="$1" name="$2" c1="$3" c2="$4"
  mkdir -p "$dir"
  mk_sprite "/tmp/${name}_a.png" "$c1"
  mk_sprite "/tmp/${name}_b.png" "$c2"
  ffmpeg -y -loglevel error -i "/tmp/${name}_a.png" -i "/tmp/${name}_b.png" \
    -filter_complex "[0][1]hstack=inputs=2" -frames:v 1 "${dir}/${name}.png"
}

mkdir -p Content/Fighters/ilse/ilse.contentbundle Content/Fighters/rook/rook.contentbundle \
  Content/Stages/stage2/stage2.contentbundle Content/Audio

mk_sheet_pair "Content/Fighters/ilse/ilse.contentbundle" "ilse" "0xE8E0D0" "0xC8B890"
mk_sheet_pair "Content/Fighters/rook/rook.contentbundle" "rook" "0x707880" "0x505860"

for layer in sky bells floor; do
  case "$layer" in
    sky) c=0x1a2030; s=384x216 ;;
    bells) c=0x3a4555; s=384x216 ;;
    floor) c=0x4a4038; s=384x96 ;;
  esac
  ffmpeg -y -loglevel error -f lavfi -i "color=c=${c}:s=${s}" \
    -frames:v 1 -pix_fmt pal8 "Content/Stages/stage2/stage2.contentbundle/cloister_${layer}.png"
done

mkdir -p Content/Audio

# hit_light, hit_heavy, block, throw and ko are recorded CC0 clips (Content/Audio/CREDITS.md,
# rebuilt by scripts/audio/build_cc0_sfx.py); never overwrite them with sine placeholders.
RECORDED_SFX="hit_light hit_heavy block throw ko"

synth_wav() {
  local out="$1" freq="$2" dur="${3:-0.08}" id
  id="$(basename "$out" .wav)"
  case " $RECORDED_SFX " in *" $id "*) echo "skip recorded clip: $id"; return 0 ;; esac
  ffmpeg -y -loglevel error -f lavfi -i "sine=frequency=${freq}:duration=${dur}" \
    -ar 44100 -ac 1 "$out"
}

synth_wav Content/Audio/hit_light.wav 880
synth_wav Content/Audio/hit_heavy.wav 440 0.12
synth_wav Content/Audio/block.wav 220 0.06
synth_wav Content/Audio/special.wav 660 0.15
synth_wav Content/Audio/super.wav 523 0.25
synth_wav Content/Audio/throw.wav 330 0.1
synth_wav Content/Audio/ko.wav 196 0.4
synth_wav Content/Audio/round_start.wav 784 0.2
synth_wav Content/Audio/ambient_bells.wav 392 2.0

# Whiff is a short filtered noise whoosh so it is not another sine hit.
ffmpeg -y -loglevel error -f lavfi \
  -i "anoisesrc=color=white:duration=0.07:sample_rate=44100,highpass=f=1800,lowpass=f=7000,volume=0.14,afade=t=in:st=0:d=0.008,afade=t=out:st=0.02:d=0.05" \
  -ar 44100 -ac 1 -c:a pcm_s16le Content/Audio/whiff.wav

# Time-over is a two-note descending tone, distinct from round_start and ko.
ffmpeg -y -loglevel error \
  -f lavfi -i "sine=frequency=311:duration=0.16:sample_rate=44100" \
  -f lavfi -i "sine=frequency=155:duration=0.28:sample_rate=44100" \
  -filter_complex "[0][1]concat=n=2:v=0:a=1" \
  -ar 44100 -ac 1 -c:a pcm_s16le Content/Audio/time_over.wav

echo "L10 assets generated under Content/"