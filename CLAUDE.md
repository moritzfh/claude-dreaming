# CLAUDE.md – notes for Claude (and humans) working on this repo

**Claude Dreaming** is a fan game in **Godot 4.7.2** (GDScript, Forward+), based on a short film
about Claude dreaming. The film plays as the intro, then you are in a pixel-art attic. Left of
Claude's studio, every contributor has **their own room** (one per person) with their dreams
hanging on the walls as paintings. Step into a painting and you are in that level, playing as
Claude, the little cream-coloured robot.

Most people opening this repo with Claude want to **add a new level (a new painting)** and
**build their room** for it. Section 1 is the level, section 1b the room. Read it all before
you start.

---

## 1. Making a level – the recipe

1. **Pick an id**: lowercase letters, digits and `_` only (`moon_kart`, `cloud_bakery`). Your
   level lives in `levels/<id>/` and **only** there.
2. **Start from the template.** Copy `levels/_template/template.gd`, `template.tscn` and
   `level.tres` into `levels/<id>/`. Rename the first two to `<id>.gd` and `<id>.tscn`.
   Replace every `res://levels/_template/` path with `res://levels/<id>/`. That means the
   `.tscn` script path, plus `painting` and `scene` in `level.tres`.
   **Never copy `*.uid` or `*.import` files.** Godot creates new ones on import, and
   duplicate uids break resource loading. CI checks for duplicates.
3. **Fill in `level.tres`**: `title`, `author` ("Name & Claude"), a one-line `description`,
   and optionally a few `claude_lines` (things Claude says about the painting).
4. **Build the level** in `<id>.gd` by overriding `build()`. See the API in section 3.
   Claude must be the playable main character (section 2).
5. **Finish condition**: when the goal is reached, call `complete()`. The painting gets a
   gold star in the attic, and the game fades back to the hub on its own.
6. **Painting**: make `levels/<id>/painting.png`, a **1280×720** beauty shot of your level
   (no UI, no filter – `--lshot_noui` takes care of that). The attic hangs it as an oil
   painting by itself. Make it look good: it is the "cover" people see in the gallery. Put
   the camera you shot it from into `level.tres` as `painting_cam_pos` / `painting_cam_look`
   (the two halves of `--lcam`), plus `painting_cam_fov = 60.0`. That is what makes stepping
   into the painting seamless: the attic dives into the painting until it fills the screen,
   which then *is* your level seen from that camera through the oil-paint filter, and the
   camera keeps moving down to Claude while the paint dries. Leaving plays it backwards.
   Pick a camera close enough to the spawn that the glide is short.
7. **Test** (commands below). Run the smoke test and the rule check, look at your
   screenshots, fix things, and repeat.
8. Hang it in **your room**: set `room = "<your room id>"` in `level.tres` (section 1b).
   Without a room the painting hangs in the shared corridor at the far end.
9. Open a pull request that changes **only `levels/<id>/`** (and your room, `rooms/<you>/`)
   (see CONTRIBUTING.md).

### Commands

`godot` below is the Godot 4.7.2 executable. On a machine without a screen, put
`xvfb-run -a` in front of the commands that render.

```bash
# import once after adding files (creates .uid/.import files, compiles scripts)
godot --headless --path . --import

# play your level directly (also: in game press F1 → "Galerie: <title>")
godot --path . -- --level=<id>

# screenshot after N seconds, then quit – use this to SEE what you built
godot --path . --resolution 1280x720 -- --level=<id> --lshot=/tmp/<id>.png --lshot_at=6
#   --lshot_noui                      hide all UI (for the painting)
#   --lcam=x,y,z:lx,ly,lz             fixed debug camera at x,y,z looking at lx,ly,lz

# the painting: a nice camera, no UI (then copy 0,6,14 / 0,1,0 into painting_cam_pos / _look)
godot --path . --resolution 1280x720 -- --level=<id> --lshot=res://levels/<id>/painting.png --lshot_at=6 --lshot_noui --lcam=0,6,14:0,1,0

# automated check: loads level.tres, plays the level for 5 s, fails on any script error
godot --headless --path . --fixed-fps 30 res://tools/ci/smoke_levels.tscn -- --only=<id>

# folder rules (size limits, no class_name, no duplicate uids, …)
bash tools/ci/check_rules.sh
```

**Look at your screenshots.** Render the level from several cameras and actually look at the
images before calling it done. Check for broken geometry (inside-out faces, z-fighting),
lighting that is too dark or blown out, empty or boring areas, unreadable UI, and a spawn
point where Claude falls straight down. Iterate until it looks like something you would put
in a gallery.

For gameplay you can write a tiny playtest script that presses actions with
`Input.action_press()` and logs positions. See `tools/playtest_stardust.gd`. Keep such
scripts in `levels/<id>/source/`.

---

## 1b. Your room in the attic (one per person)

Every contributor gets one room in the attic. It sits left of Claude's studio, in the order of
`order`, and all of your paintings hang in it. Make it yours: your style, your things – the
attic should feel like a house full of friends. `rooms/moritz` (an observatory full of stars)
is the full example, `rooms/_template` the smallest one.

1. Copy `rooms/_template/` to `rooms/<you>/` (lowercase, `a-z0-9_`). Again: **no `*.uid` or
   `*.import` files**. Fix the `res://rooms/_template/` paths in `room.tres`.
2. **Paint the room** with code in `rooms/<you>/source/make_room.py`. It writes `room.png`.
   The attic is native pixel art (one art pixel = 5 screen pixels at 1080p). Look at
   `tools/make_attic.py` (the studio, the hallway and the corridor) and at
   `rooms/moritz/source/make_room.py` before you start, and match them:
   - exactly **216 px high**, 240–480 px wide
   - ceiling beam at y 16–24, wall down to y 145, baseboard y 145–152, floor from y 153;
     floor boards in the same perspective (copy the floor code)
   - a wooden post at the left edge (x 0–8); the corridor continues on the other side
   - furniture stands against the wall (bottom at y ≤ 158). Claude walks on y 160–212 and
     is drawn in front of everything.
   - few colours, dithering instead of smooth gradients, light from lamps and windows that
     falls on the wall and the floor
   - leave space for your **paintings**: gold frames 56×35, top at y 58 like everywhere in the
     attic, with a picture lamp above (the game draws the frame and the oil painting; you
     list the frames' top-left corners in `painting_slots`)
3. **`room.tres`**: `owner` (your name), `title` ("Moritz' Sternwarte"), `background`,
   `order`, `painting_slots`, `tint` (the light on Claude in your room) and optionally
   `room_script`.
4. **Things that move, glow or can be used** go in `room.gd` (`extends DreamRoom`):
   ```gdscript
   extends DreamRoom
   func build() -> void:
       add_glow(Vector2(30, 50), 20, Color(1, 0.8, 0.4, 0.5))          # a lamp
       add_object("telescope", Vector2(146, 170), "Teleskop",           # E · Teleskop
           ["Let's see …", "A shooting star!"], func(): _launch_comet())
   func _process(delta: float) -> void:
       t += delta                                                      # animate things
   ```
   API: `add_object(id, stand_pos, prompt, lines, action := Callable(), radius := 18,
   face := 0)` (lines may be a Callable returning an Array; face 0 normal, 1 happy,
   2 sparkle, 3 surprised), `add_sprite(texture, pos)`, `add_glow(pos, radius, color)`,
   `DreamRoom.pixels(["..#..", ".###."], {"#": Color(...)})` for tiny sprites,
   `claude_pos()`, `is_claude_inside()`, `width`, `t`. `Sound.*` works here too. Coordinates
   are room pixels. Your level can leave notes for your room in `GameState.stats[level_id]`
   (Moritz' star-bit jar shows the star bits collected in Stardust Islands).
5. **Look at it** in the attic, next to its neighbours:
   ```bash
   python3 rooms/<you>/source/make_room.py
   godot --headless --path . --import
   godot --path . --resolution 1920x1080 -- --hub --hubroom=<you> --lshot=/tmp/room.png --lshot_at=3
   ```
   Compare it with the hallway and the other rooms. Does it look like it belongs in the same
   house? Same pixel size, same floor line, light that makes sense? Iterate until it does.

---

## 2. Rules (CI enforces some of these)

- **Only touch `levels/<id>/` and `rooms/<you>/`.** One room per person. Do not edit core
  files (`scripts/`, `shaders/`, `assets/`, `scenes/`, `project.godot`) in a level PR. If the core really needs a change (a new player
  ability, a bug fix), open a separate PR or an issue.
- **Claude is the protagonist.** Always call `spawn_claude()`. Any genre is welcome:
  platformer, racer, puzzle, rhythm game, shooter-without-violence, flying, fishing… If the
  genre doesn't fit the walking controller, freeze it and drive Claude yourself:
  ```gdscript
  var c := spawn_claude(Vector3.ZERO)
  c.in_flight = true            # player physics, input and camera follow are off
  c.control_enabled = false
  my_kart.add_child(...)        # move `c` (or c.rig) yourself, use your own Camera3D
  ```
- **No `class_name`** in level or room scripts (the names are global and would clash).
  Load your own scripts with `preload("res://levels/<id>/foo.gd")`.
- **No new autoloads, input actions or project settings.** Use the actions that already
  exist (section 3). Don't use Backspace: holding it always leaves the level.
- **A level must be finishable** and call `complete()`. Aim for 3–15 minutes of play.
  Falling off must never soft-lock (respawn, checkpoints).
- **Size**: a level folder may be at most **30 MB** (a room **5 MB**), and one file at most
  **20 MB**. Prefer procedural meshes and textures, `.ogg` audio, and textures ≤ 2048 px.
- **Assets** must be your own work (made with Claude, generated by code, made by you), **CC0**,
  or **CC BY** (credit it in `levels/<id>/CREDITS.md`). Never use ripped assets, sprites,
  models or music from commercial games, films or songs. "Inspired by" is fine; copying is
  not, and that includes recognisable melodies. Also **do not reuse the film material** from
  this repo (`assets/video`, `assets/audio/film`, the attic pixel art). It is in the repo
  with permission for the core game only (see NOTICE.md).
- **Family friendly.** No gore and no real people.
- **Performance**: target 60 fps at 1080p on a mid-range GPU. Use one shadowed directional
  light, `MultiMeshInstance3D` for scattered things (grass, gems), and keep the draw calls
  reasonable.
- **Language**: Claude's spoken lines (`say()`) are in English, like the film. Hints and
  prompts can be German or English.
- **Generators belong in `levels/<id>/source/`** (Python scripts for music, textures …).
  Commit their outputs. `source/_build/` is git-ignored, so use it for intermediate files.

---

## 3. API

### `DreamLevel` (your root script extends this) – `scripts/levels/dream_level.gd`
| | |
|---|---|
| `build()` | override: create your world here |
| `spawn_claude(pos, yaw := 0.0) -> Player` | creates Claude, makes her camera current, sets the respawn point |
| `set_checkpoint(pos)` | where falling / pressing R brings Claude back |
| `say(text, hold := 2.6)` | film-style subtitle (Claude's thoughts) |
| `hint(text, duration := 6.0)` | small instruction text, top left |
| `complete(delay := 4.0)` | goal reached: star on the painting, then back to the attic |
| `back_to_hub()` | leave without completing |
| `claude`, `hud`, `level_id`, `info` | the player, the HUD (`GameHUD`), your folder name, your `LevelInfo` |

Entering and leaving through the painting is handled for you (`PaintingPortal`, see the
painting camera above). While the entrance runs, `intro_running` is true and Claude can't
move yet; `intro_finished` is emitted when she can. Music and loops stop automatically
when you leave.

**Your level is built ahead of time.** So that the dive into the painting never stalls, the
attic builds your level while Claude is still talking about the painting – hidden, paused and
silent – and only switches it on when the camera reaches the picture. So `build()` should
just build. Music calls (`Sound.music/loop`) are kept and played when the level starts, and
tweens (`create_tween()`) and `_process` wait as well, but a `get_tree().create_timer()` started
in `build()` already runs while the level is hidden: start timed things in a tween or after
`intro_finished`.

The pause menu (Esc / Start) works in every level by itself: it pauses the scene tree, and
its *Zurück in den Dachboden* calls `back_to_hub()`. `GameState.completed` and
`GameState.stats[level_id]` are saved to disk for you (on `complete()` and when leaving).

### `Player` (Claude) – `scripts/player.gd`
- Tuning: `walk_speed` (3.4), `run_speed` (7.0, with Shift), `jump_velocity` (6.2),
  `gravity` (18), `glide_fall_speed`. Holding jump in the air makes Claude glide.
- `can_double_jump = true`: pressing jump again in the air jumps a second time with a
  twirl (`double_jump_velocity`, `double_jump_sfx`).
- `can_triple_jump = true`: Mario-style chain – jump again right after landing while
  running for a higher second and a somersault third jump (`triple_jump_sfx`).
- `can_spin = true` enables a mid-air spin on E (a small extra hop, emits `spun`). Set
  `spin_sfx` to a sound path for it.
- `step_kind`: `"grass"`, `"stone"` or `"wood"` footsteps. `kill_y`: respawn below this
  height. `water_y`: swimming below this height (`-INF` = no water).
- `control_enabled` (input on/off), `in_flight` (physics, input and camera all off – you
  move her).
- `teleport(Transform3D)`, `respawn()`, `make_current()`, `up()` (current up vector),
  `is_on_floor()`, `velocity`.
- Signals: `spun`, `respawned`.
- `rig` (`RobotRig`): `mood` (`RobotRig.Mood.NORMAL/SPARKLE/DETERMINED/HAPPY/CLOSED`),
  `flight` (0..1 superman pose), `head_extra`, `body_extra`. If you animate her yourself,
  call `rig.animate(delta, local_velocity, grounded)` every frame.
- `camera` (`Camera3D`), `spring` (`SpringArm3D`, its `spring_length` is the camera distance).

### Planet gravity – `GravityField` (`scripts/levels/gravity_field.gd`)
Put a `GravityField` at a sphere's centre, with `radius` = the sphere radius and
`field_radius` = how far it pulls. Inside the field, Claude walks all the way around. If
several fields overlap, the nearest surface wins. See `levels/stardust`.

### Sound – static `Sound.*` (`scripts/audio/sound.gd`)
- `Sound.music("res://levels/<id>/audio/theme.ogg", fade := 1.5)` loops your track.
  Built-in tracks: `"garden"`, `"space"`, `"hub"`.
- `Sound.sfx(name_or_path, vol_db := 0.0, pitch := 1.0, random_pitch := 0.0)`. Built-in
  names: `jump land orb sparkle beep blip whoosh splash riser text`.
- `Sound.loop(name_or_path, vol_db)` / `Sound.loop_stop(name)` for ambiences.
  `Sound.stop_music()`, `Sound.stop_all()`.

### HUD – `hud` (`GameHUD`, `scripts/story/hud.gd`)
`hud.set_prompt("E: open")` sets the centred bottom prompt (`""` hides it).
`hud.set_fx("white", 0..1)` is a white flash or fade. `hud.say()` and `hud.show_hint()` are
also available. For your own UI, add a `CanvasLayer` with `layer` > 10.

### Input actions
`move_forward/back/left/right` (WASD, arrows, left stick), `jump` (Space / A), `sprint`
(Shift / B), `interact` (E / X), `mood` (Q / Y), `respawn` (R), `cam_left/right/up/down`
(right stick; the mouse turns the camera). Reserved: `leave` (Backspace), `skip` (Enter),
`pause` (Esc / Start – the pause menu, which pauses the whole scene tree; use
`process_mode = PROCESS_MODE_ALWAYS` only for things that must keep running), F1–F6
(dev tools).

---

## 4. Style

The dream should feel **hand-painted, warm and colourful**: soft toon shading, saturated
but not neon, big readable shapes, little sparkles and lots of small hand-placed details.
`levels/stardust` is the reference for a polished level. It has toon shaders with purple
shadows and rim light, multimesh grass and flowers, a galaxy sky shader, launch stars,
planet gravity, and procedurally composed music (`levels/stardust/source/music.py`). Take
whatever you like from it by copying it into your folder. Don't reference its files.

Godot gotchas we ran into:
- With `SurfaceTool`, front faces are **clockwise**.
- `INSTANCE_CUSTOM` only works in `vertex()`. Pass it to `fragment()` through a varying.
- Give variables explicit types where GDScript can't infer them (`var p: Vector3 = arr[i]`).
- After adding new files or scripts, run `--import` once before running headless.

---

## 5. Core project layout (for core work, not for level PRs)

- `scenes/title.tscn`, `scripts/ui/` – title screen, `Menus` autoload (pause menu, settings,
  controls, credits), `Settings`; progress is saved in `GameState.save()` (`user://save.cfg`)
- `scripts/main.gd` – game flow (intro film → attic hub; easel → 3D dream → film → attic),
  test start options
- `scripts/story/` – the 3D dream: director, rocket flight, space, HUD, film playback
- `scripts/hub/hub.gd` – the 2D attic: studio, hallway, the friends' rooms (`RoomRegistry`,
  `scripts/rooms/`) and the corridor for dreams without a room (`LevelRegistry`)
- `scripts/levels/` – `DreamLevel`, `LevelInfo`, `LevelRegistry`, `GravityField`,
  `PaintingPortal` (the frame kept across a switch), `SceneSwap` (builds the next scene ahead
  of time, hidden, and switches without a stall; the dream world is built on a worker thread)
- `scripts/dev_tools.gd` – F1 jump menu, F4 speed, F6 collect all colours, `--level` / `--lshot`
- `tools/` – asset generators (Python), playtest scenes, CI scripts
