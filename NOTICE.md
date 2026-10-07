# Credits & licenses

**Claude Dreaming** is an unofficial fan project. It is not affiliated with, endorsed by
or sponsored by Anthropic. "Claude" is a trademark of Anthropic, PBC.

The game is based on a short animated film about Claude dreaming, made by another
YouTuber with Claude: **https://youtu.be/8BtSRB_LieE**. All rights to the film, its
images, its music and its character design belong to its creator. They kindly allowed
this project to use the film material.

## What is under which license

| What | Where | License |
|---|---|---|
| Source code | `*.gd`, `*.gdshader`, `*.py`, `*.sh`, `*.tscn`, `*.tres`, `.github/` | **MIT** (see `LICENSE`) |
| Our own assets: music, sound effects, the 3D dream world, the Stardust Islands and Work in Progress levels, Rusty's room, the Werkstatt | `assets/audio/music/`, `assets/audio/sfx/`, `levels/stardust/`, `levels/wip/` (except the fonts), `rooms/rusty/`, `rooms/werkstatt/` | **CC BY 4.0** – credit "Claude Dreaming contributors" |
| Fonts | `assets/fonts/` (EB Garamond, Pixelify Sans), `levels/stardust/fonts/` (Fredoka), `levels/wip/fonts/` (JetBrains Mono) | **SIL Open Font License 1.1** (see the `OFL.txt` next to them) |
| **Film material** – pieces of the film | `assets/video/`, `assets/audio/film/` | **© the film's creator. Not licensed for reuse** |
| **Film-derived art** – the attic reconstructed from film frames, the film's painting, Claude's character design (pixel sprite and 3D robot) | `assets/hub/attic_bg.png`, `assets/hub/attic_plate.png`, `assets/hub/painting_pixel.png`, `assets/hub/robot_*.png`, `assets/models/robot.glb`, `tools/attic_src/`, `tools/robot_src/` (Claude's head, taken from film frames) | Character design and film imagery © the film's creator. Our redrawings may only be used inside this project. |
| Community levels and rooms | `levels/<id>/`, `rooms/<id>/` | Code MIT, assets CC BY 4.0, unless the folder's `CREDITS.md` says otherwise |

The game plays the whole film once as its intro (`assets/video/part_a*.ogv` the pixel
opening, `part_m*.ogv` the 3D middle, `part_b.ogv` waking up, with the soundtrack
`assets/audio/film/film_full.ogg`). `tools/film/cut_intro.sh` cuts these pieces from the
original video file.

The film material is in this repository so that the game works out of the box. If you fork
the project, keep it inside the game. **Don't reuse it anywhere else** (videos, other games,
merch …) without asking the film's creator.

Community levels may use the Claude robot (`spawn_claude()`, `RobotRig`). That is the
point of the gallery. They must not use the film material listed above (see `CLAUDE.md`).

## Tools

- [Godot Engine](https://godotengine.org) 4.7 (MIT)
- The music and sound effects are synthesised with small Python programs in this repo
  (`tools/audio/`, `levels/*/source/`), using numpy and ffmpeg/libvorbis.
