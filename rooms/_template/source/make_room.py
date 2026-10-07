"""The smallest possible room: an empty attic corridor piece with one
picture lamp – copy this folder to rooms/<your_name>/ and paint your own
room here (see rooms/rusty/source/make_room.py for a full example).

Rules of thumb (so all rooms fit together):
  - exactly 216 px high, 240-480 px wide, one pixel = one art pixel
  - ceiling beam y 16-24, wall down to y 145, baseboard 145-152, floor from y 153
  - a post at the left edge (x 0-8): the corridor continues there
  - furniture stands against the wall (bottom at y <= 158); Claude walks on y 160-212
  - gold frames (56 x 35) for your paintings are put up by the game at the
    slots in room.tres; leave space for them (top at y 58 is the attic's height)
  - few colours, dithering instead of smooth gradients, light from the lamps

Run from the repo root:  python3 rooms/_template/source/make_room.py
Writes rooms/_template/room.png
"""
import os
import sys
import cv2

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', '..', '..', 'tools'))
from make_attic import corridor, picture_lamp, draw_post   # the attic's own helpers

W = 256
img, light = corridor(W, [128], seed=5)   # ceiling, wall, baseboard, floor (lit by a lamp at x=128)
picture_lamp(img, 128)                    # brass lamp over the painting slot at x 100..156
draw_post(img, 0)                         # the post at the left edge
cv2.imwrite(os.path.join(HERE, '..', 'room.png'), img)
print('wrote room.png', img.shape)
