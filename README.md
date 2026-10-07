# Claude Dreaming – a playable dream

A fan game in **Godot 4.7** based on a short film about Claude dreaming
([original video](https://youtu.be/8BtSRB_LieE)). On the first start the whole film plays
as the intro. Then you are Claude, in the pixel-art attic: step into the painting on the
easel and play the dream in 3D, or visit the **friends' rooms** – every painting there is a level made
by someone with their own Claude.

[![Claude Dreaming – watch the trailer on YouTube](docs/trailer/thumbnail_trailer_A.jpg)](https://youtu.be/WpGvvH7Z8mk)

▶ **[Watch the trailer on YouTube (1:37)](https://youtu.be/WpGvvH7Z8mk)** · [mp4](docs/trailer/trailer_a.mp4) · [the 40-second cut](docs/trailer/trailer_b.mp4) ·
Shorts: [how to add your own dream](docs/trailer/short_explainer.mp4) · [“She's fine.”](docs/trailer/short_error.mp4)

> 🇩🇪 **Kurz auf Deutsch:** Ein Fan-Spiel zum Kurzfilm über Claude, der träumt. Beim
> ersten Start läuft der ganze Film als Intro (überspringbar), danach bist du auf dem
> Pixel-Dachboden. Von dort steigst du in Gemälde: in Claudes ersten Traum (in 3D) und in
> die Zimmer der Freunde – jedes Gemälde ist ein Level von jemandem aus der Community. **Bau dein eigenes Level mit deinem Claude** – wie das geht, steht in
> [CONTRIBUTING.md](CONTRIBUTING.md).

## Play

1. Download **Godot 4.7.2** (standard version, not .NET) from
   [godotengine.org](https://godotengine.org/download). There is nothing to install.
2. In Godot, choose **Import** and select this folder's `project.godot`. The first import
   takes a moment because of the film clips.
3. Press **F5**.

### What happens
1. **The title screen.** *Spielen* on the first start, *Weiter* after that. Settings,
   controls and credits are there too (and in the pause menu).
2. **The intro: the whole film** (about 4 minutes) – the pixel opening, the dream in 3D,
   waking up. Hold **Enter** to skip it, or press **Esc** → *Film überspringen*. You can
   watch it again from the title screen.
3. **The attic (hub).** The film ends here and you play on. The dream hangs on the
   **easel** as a painting – step into it: the playable 3D dream – the garden with the glowing flower
   and the mirror pool, the canal wall, the rocket flight synced to the film's music,
   space and the warp. Walk left through the hallway into the **friends' rooms** – every
   contributor has one, with their dreams on the walls. Step into a painting with **E**:
   the camera dives into the picture and it comes alive. Finished dreams get a gold star.
4. **Esc** opens the pause menu everywhere: *Zurück in den Dachboden* takes you from any
   dream back into the attic. Progress is saved automatically.

Every level can have its own controls – a level tells you how it is played when you step
into it. **F1** opens the dev menu (jump to any part of the game or any level).

## Make your own dream

Read **[CONTRIBUTING.md](CONTRIBUTING.md)**. In short: fork the repo, open it with Claude
Code, and ask for a level ("follow CLAUDE.md"). Then play it, polish it, take a nice
screenshot as the painting, and open a pull request with your `levels/<id>/` folder.
**[CLAUDE.md](CLAUDE.md)** has the recipe, the rules and the API, written so that your
Claude can follow it.

```
levels/
  _template/        the smallest possible level – copy this
  stardust/         "Stardust Islands" – a Mario-Galaxy-flavoured showcase
  wip/              "Work in Progress" – not a platformer: Claude walks on her own,
                    you are the level editor (and the level isn't finished …)
  prism_boulevard/  "Prism Boulevard" – a kart race on a road of rainbow glass against
                    seven rivals: drifts, a loop, a corkscrew, hyperspace, a glider jump
  <your_id>/        your dream ✨
rooms/
  _template/        the smallest possible room
  rusty/            "Rustys Sternwarte" – an observatory full of stars
  werkstatt/        "Die Werkstatt" – where the game gets built (half of it is only sketched)
  <you>/            your room in the attic
```

## Project layout

- `scripts/ui/` – title screen, pause menu (`Menus` autoload), settings
- `scripts/main.gd` – game flow (intro film → attic; the easel → 3D dream → attic) and test start options
- `scripts/story/` – the 3D dream: intro, story moments, rocket flight, space, HUD, film playback
- `scripts/world/` – terrain, garden, trees, cliffs, town, islands, clouds
- `scripts/hub/hub.gd` – the 2D attic and the gallery
- `scripts/levels/` – the level system (`DreamLevel`, `LevelInfo`, `LevelRegistry`, `GravityField`)
- `scripts/player.gd`, `scripts/robot_rig.gd` – Claude (controller and animated robot)
- `shaders/` – materials and screen effects
- `tools/` – asset generators (pixel art, music and sound synth in Python), playtests, CI checks
- `docs/trailer/` – the trailers and shorts (small copies; not part of the game)

### Exporting a build
`export_presets.cfg` has two presets: **Windows Desktop** (`Builds/ClaudeDreaming.exe`) and
**Web** (`Builds/Web/index.html`, for itch.io). In **Project → Export** pick one and press
*Export Project* (Godot offers to download the export templates the first time).

The web build uses the smaller copies of the film in `assets/video_web/`
(`bash tools/make_web_video.sh`), because itch.io allows at most 200 MB per file in a web
game. It runs with the Compatibility renderer and starts with *Grafik: niedrig*. To put it
on itch.io: zip the *contents* of `Builds/Web` (index.html at the top of the zip), upload it
as an HTML project and tick *This file will be played in the browser*.

## Licenses

Code: **MIT**. Our own assets: **CC BY 4.0**. Fonts: **OFL**. The film clips, the film's
music and the art derived from the film belong to the film's creator. They are included
with permission, for this game only. Details are in **[NOTICE.md](NOTICE.md)**.

This is an unofficial fan project and is not affiliated with Anthropic.
