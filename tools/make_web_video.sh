#!/usr/bin/env bash
# Smaller copies of the intro film for the browser build (itch.io allows at
# most 200 MB per file in a web game, the 1080p film alone is ~205 MB).
# The game picks assets/video_web/ when it runs in a browser (main.gd film()).
#   bash tools/make_web_video.sh        (needs ffmpeg with libtheora)
set -e
cd "$(dirname "$0")/.."
mkdir -p assets/video_web
for f in assets/video/*.ogv; do
  ffmpeg -hide_banner -loglevel error -y -i "$f" -map 0 -vf "scale=1280:720:flags=lanczos" \
    -c:v libtheora -b:v 2200k -c:a copy "assets/video_web/$(basename "$f")"
  echo "$(basename "$f")"
done
