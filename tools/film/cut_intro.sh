#!/usr/bin/env bash
# Cuts the pieces of the original film that the game needs for its intro
# (the whole film plays once on the first start, then you are in the attic).
#   bash tools/film/cut_intro.sh "<path to the original video file>"
# Part A (pixel, 0-91.6 s) is assets/video/part_a1..6, part B (pixel, from
# 210.98 s) is assets/video/part_b. This script makes the film's 3D middle
# (part_m1..8, 720p) and the soundtrack of the whole film up to the attic.
set -e
SRC="$1"
OUT="$(dirname "$0")/../../assets"
fr() { python3 -c "print(f'{$1/30:.6f}')"; }
# part A, last chunk: the unaltered film (the game's own dream uses its own transition)
ffmpeg -v error -y -ss "$(fr 2290)" -i "$SRC" -frames:v 458 -an -vf "fps=30,scale=1920:1080:flags=lanczos" -c:v libtheora -q:v 7 "$OUT/video/part_a6.ogv"
# the 3D middle: frames 2748 .. 6329 at 30 fps, in chunks of 448 frames
start=2748; end=6329; i=1
while (( start < end )); do
  n=$(( end - start < 448 ? end - start : 448 ))
  ffmpeg -v error -y -ss "$(fr $start)" -i "$SRC" -frames:v $n -an -vf "fps=30,scale=1280:720:flags=lanczos" -c:v libtheora -q:v 5 "$OUT/video/part_m$i.ogv"
  # the warp is pure noise for the encoder: cap its bitrate (else ~45 MB)
  if (( $(stat -c %s "$OUT/video/part_m$i.ogv") > 20000000 )); then
    ffmpeg -v error -y -ss "$(fr $start)" -i "$SRC" -frames:v $n -an -vf "fps=30,scale=1280:720:flags=lanczos" -c:v libtheora -b:v 9M "$OUT/video/part_m$i.ogv"
  fi
  echo "part_m$i: $n frames"
  start=$(( start + n )); i=$(( i + 1 ))
done
# the soundtrack from the first frame to the end of part B
ffmpeg -v error -y -i "$SRC" -t 237.983 -vn -ac 2 -ar 44100 -c:a libvorbis -q:a 4 "$OUT/audio/film/film_full.ogg"
echo done
