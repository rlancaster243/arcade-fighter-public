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

synth_wav() {
  local out="$1" freq="$2" dur="${3:-0.08}"
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

echo "L10 assets generated under Content/"