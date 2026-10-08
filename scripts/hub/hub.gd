## The playable pixel-art attic (hub). The room is native pixel art (one art
## pixel = 5 screen pixels at 1080p): the film's attic at sunset on the right,
## and a gallery wing on the left with paintings of the dream you can step
## into. The camera follows Claude sideways. Coordinates in this script are
## art pixels with x = 0 at the left edge of the film's room (the gallery has
## negative x).
##
## Left of the wing come the friends' rooms (rooms/*/room.tres, one per
## person, see RoomRegistry) with their dreams on the walls, then a shared
## corridor for dreams without a room (res://levels/*/level.tres) with one
## empty frame waiting for the next dream. The easel in the studio is the
## way into the first dream.
class_name AtticHub
extends CanvasLayer

signal dream_requested
## Claude starts talking about the painting on the easel (main gets the dream ready)
signal dream_soon
## main: is the dream ready to be stepped into? (the hub waits until it is)
var dream_gate := Callable()
signal gallery_requested(opts: Array)

const BG := preload("res://assets/hub/attic_bg.png")
const SHEET := preload("res://assets/hub/robot_sheet.png")
const PORTRAITS := preload("res://assets/hub/robot_portraits.png")
const PIXEL_FONT := preload("res://assets/fonts/PixelifySans.woff2")
const TILE_TEX := preload("res://assets/hub/gallery_tile.png")
const END_TEX := preload("res://assets/hub/gallery_end.png")
const FRAME_TEX := preload("res://assets/hub/frame_gold.png")
const CANVAS_TEX := preload("res://assets/hub/canvas_empty.png")
const BADGE_TEX := preload("res://assets/hub/star_badge.png")
const SIGN_TEX := preload("res://assets/hub/gallery_sign.png")
const TILE := 176.0
const SLOT_X := [132.0, 44.0]      # slot centres inside a tile, filled right to left
const END_W := 96.0
const ART := Vector2(48, 27)
const EXT := 272.0                 # width of the gallery wing
const ROOM_W := 384.0
const VIEW := Vector2(384.0, 216.0)
const FW := 38
const FH := 54
const FOOT := Vector2(19.0, 50.0)  # feet position inside a frame
const F_IDLE := [0, 1]
const F_BLINK := 2
const F_HAPPY := 3
const F_SPARKLE := 4
const F_WALK := [5, 6, 7, 8]
const F_WIDE := 9
const F_CHEER := 10
const CANVAS_RECT := Rect2(160.0, 96.0, 64.0, 36.0)
const START_ZOOM := 4.6
const START_CENTER := Vector2(211.0, 115.5)   # framing of film part 2's last shot
const SPEED := 62.0
const WALK_ROOM := [Vector2(-266, 160), Vector2(0, 158), Vector2(310, 158), Vector2(352, 181), Vector2(383, 197), Vector2(383, 214), Vector2(-266, 214)]
const BLOCKERS := [Rect2(14, 150, 86, 29), Rect2(124, 150, 30, 33), Rect2(154, 150, 78, 32)]
## id: [stand point, radius, prompt, portrait]
const ROOM_SPOTS := {
	"easel": [Vector2(192.0, 190.0), 26.0, "E  ·  The first dream", 2],
	"window": [Vector2(112.0, 166.0), 18.0, "E  ·  Window", 0],
	"monitor": [Vector2(58.0, 186.0), 22.0, "E  ·  Monitor", 0],
	"sunflower": [Vector2(122.0, 164.0), 14.0, "E  ·  Sunflower", 1],
	"drawings": [Vector2(268.0, 164.0), 22.0, "E  ·  Drawings", 0],
	"door": [Vector2(340.0, 188.0), 18.0, "E  ·  Door", 0],
	"pinboard": [Vector2(-105.0, 170.0), 24.0, "E  ·  Pinboard", 1],
	"guestbook": [Vector2(-193.0, 168.0), 18.0, "E  ·  Guestbook", 0],
}
const ROOM_LINES := {
	"window": ["The sun is going down.", "Somewhere out there, my sunflower is still collecting downvotes."],
	"monitor": ["Stars instead of comments.", "Much better."],
	"sunflower": ["My first painting.", "-4,480 karma.", "I still like it."],
	"drawings": ["My first drawings.", "Everybody has to start somewhere."],
	"door": ["The door is open.", "Not yet. First I want to finish something."],
	"plant": ["A monstera.", "It grows towards the light. Same."],
	"empty": ["This frame is still empty.", "Maybe the next dream goes here."],
	"easel": ["My first dream.", "The garden, the waterfall, the little planet …", "Let's dream it again."],
	"pinboard": ["Photos from my first dream.", "The garden. The jump. The little planet.", "The painting on the easel takes me back there."],
}
## the framed paintings in the gallery: rect (art px) and what entering starts
const GALLERY_SRC := "res://assets/hub/gallery_src/%s.jpg"

var root: Node2D
var levels: Array[LevelInfo] = []
var rooms: Array[RoomInfo] = []
var room_nodes: Array = []     # DreamRoom scripts of the friends' rooms
var room_actions := {}         # spot id -> Callable (objects in friends' rooms)
var _tint_zones: Array = []    # [x0, x1, Color] light on Claude per room
var room_span := {}            # room id -> Vector2(left x, width)
var level_slots := {}     # spot id -> [LevelInfo, painting rect]
var left_edge := -EXT     # left end of the walkable attic (grows with the gallery)
var spots := {}
var lines := {}
var walk: PackedVector2Array
var robot: Sprite2D
var _parked_key := ""
var _hold_typing := false
var shadow: Polygon2D
var painting: Sprite2D
var white: ColorRect
var prompt: Label
var counter: Label
var dialog: Panel
var dialog_text: Label
var portrait: TextureRect
var bulbs: Array = []
var zoom := 1.0
var _preloading := {}
var center := Vector2(192.0, 108.0)
var pos := Vector2(206.0, 196.0)
var facing := -1.0
var state := "off"
var _t := 0.0
var _anim := 0.0
var _blink := 2.0
var _lines: Array = []
var _line_i := 0
var _typing := 0.0
var _talk_id := ""
var _step_acc := 0.0
var _happy := 0.0
var _face := -1
var _auto_target := Vector2.INF
var _auto_done: Callable
var _autotalk := ""   # debug: talk to this spot and click through by itself
var _autoclick := 0.0
var start_opts: Array = []   # options from main (command line / dev menu)

func _ready() -> void:
	layer = 15
	visible = false
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	root = Node2D.new()
	root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(root)
	var room := Sprite2D.new()
	room.texture = BG
	room.centered = false
	room.position = Vector2(-EXT, 0.0)
	root.add_child(room)
	_build_gallery()
	# the first dream, painted on the easel – the way into it, like every
	# other painting in the attic
	painting = _oil_painting(load(GALLERY_SRC % "garden"), CANVAS_RECT)
	root.add_child(painting)
	_build_ambience()
	shadow = Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		pts.append(Vector2(cos(a) * 12.0, sin(a) * 2.6))
	shadow.polygon = pts
	shadow.color = Color(0.10, 0.03, 0.02, 0.32)
	root.add_child(shadow)
	robot = Sprite2D.new()
	robot.texture = SHEET
	robot.region_enabled = true
	robot.centered = false
	root.add_child(robot)
	# UI (screen space, not zoomed)
	var ui := CanvasLayer.new()
	ui.layer = 16
	add_child(ui)
	white = ColorRect.new()
	white.color = Color(1, 1, 1, 0)
	white.set_anchors_preset(Control.PRESET_FULL_RECT)
	white.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(white)
	prompt = _pixel_label(28, Color(1, 0.97, 0.9))
	prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.offset_left = -500; prompt.offset_right = 500; prompt.offset_top = -70; prompt.offset_bottom = -30
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.add_child(prompt)
	counter = _pixel_label(26, Color(1.0, 0.9, 0.65))
	counter.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	counter.offset_left = -520; counter.offset_right = -28; counter.offset_top = 22
	counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	counter.modulate.a = 0.0
	ui.add_child(counter)
	_build_dialog(ui)

## the Community Dreams corridor: tiles with one painting per level, an
## empty frame for the next dream, and the end of the attic
func _build_gallery() -> void:
	spots = ROOM_SPOTS.duplicate()
	lines = ROOM_LINES.duplicate()
	lines["guestbook"] = _guestbook_lines
	levels = LevelRegistry.all()
	rooms = RoomRegistry.all()
	var room_ids := {}
	for r in rooms: room_ids[r.get_meta("id")] = r
	var x := -EXT
	# --- the friends' rooms, one per person, with their dreams on the walls
	for r in rooms:
		var rid: String = r.get_meta("id")
		var w := float(r.background.get_width())
		x -= w
		var bg := Sprite2D.new()
		bg.texture = r.background
		bg.centered = false
		bg.position = Vector2(x, 0)
		root.add_child(bg)
		var mine: Array = levels.filter(func(l: LevelInfo) -> bool: return l.room == rid)
		for i in r.painting_slots.size():
			var fr := Rect2(Vector2(x, 0) + r.painting_slots[i], Vector2(56, 35))
			if i < mine.size():
				_hang(fr, mine[i])
			else:
				_hang(fr, null, "empty:%s:%d" % [rid, i], ["An empty frame in %s's room." % r.owner, "Room for the next dream."])
		if r.room_script != "" and ResourceLoader.exists(r.room_script):
			var node := (load(r.room_script) as GDScript).new() as DreamRoom
			if node:
				node.info = r
				node.room_id = rid
				node.hub = self
				node.width = w
				node.position = Vector2(x, 0)
				node.name = "Room_" + rid
				root.add_child(node)
				room_nodes.append(node)
				node.build()
		_tint_zones.append([x, x + w, r.tint])
		room_span[rid] = Vector2(x, w)
	# --- a shared corridor for dreams without a room, with one empty frame
	var loose: Array = levels.filter(func(l: LevelInfo) -> bool: return l.room == "" or not room_ids.has(l.room))
	var n_tiles := maxi(1, ceili((loose.size() + 1) / 2.0))
	var tiles_x := x
	for k in n_tiles:
		var t := Sprite2D.new()
		t.texture = TILE_TEX
		t.centered = false
		t.position = Vector2(tiles_x - (k + 1) * TILE, 0)
		root.add_child(t)
	var e := Sprite2D.new()
	e.texture = END_TEX
	e.centered = false
	left_edge = tiles_x - n_tiles * TILE - END_W
	e.position = Vector2(left_edge, 0)
	root.add_child(e)
	var sg := Sprite2D.new()
	sg.texture = SIGN_TEX
	sg.centered = false
	sg.position = Vector2(-EXT + 14, 22)
	root.add_child(sg)
	for i in n_tiles * 2:
		var cx: float = tiles_x - (i / 2 + 1) * TILE + float(SLOT_X[i % 2])
		var fr := Rect2(cx - 28.0, 58.0, 56.0, 35.0)
		if i < loose.size():
			_hang(fr, loose[i])
		else:
			_hang(fr, null, "empty:%d" % i, ["This frame is still empty.", "Maybe the next dream goes here.", "Maybe yours?"])
	spots["plant"] = [Vector2(left_edge + 24.0, 172.0), 16.0, "E  ·  Plant", 1]
	lines["plant"] = ["A monstera.", "It grows towards the light. Same."]
	spots["moon"] = [Vector2(left_edge + 54.0, 168.0), 16.0, "E  ·  Window", 0]
	lines["moon"] = ["On this side it's already night.", "Good time for dreaming."]
	walk = PackedVector2Array(WALK_ROOM)
	walk[0] = Vector2(left_edge + 10.0, 160.0)
	walk[walk.size() - 1] = Vector2(left_edge + 10.0, 214.0)

## put up a gold frame: a level's painting in oil (with its spot in front),
## or an empty canvas
func _hang(fr: Rect2, info: LevelInfo, empty_key := "", empty_lines: Array = []) -> void:
	var art_rect := _art_rect(fr)
	var art: Sprite2D
	if info and info.painting:
		art = _oil_painting(info.painting, art_rect)
	else:
		art = Sprite2D.new()
		art.centered = false
		art.position = art_rect.position
		art.texture = CANVAS_TEX
	root.add_child(art)
	var frs := Sprite2D.new()
	frs.texture = FRAME_TEX
	frs.centered = false
	frs.position = fr.position
	root.add_child(frs)
	var stand := Vector2(fr.get_center().x, 172.0)
	if info:
		var id: String = info.get_meta("id")
		var key := "lvl:" + id
		var by := " (by %s)" % info.author if info.author != "" else ""
		spots[key] = [stand, 22.0, "E  ·  " + info.title + by, 2]
		lines[key] = Array(info.claude_lines) if info.claude_lines.size() > 0 else ["Someone painted this dream for me.", "\"%s\" …" % info.title, "Let's take a look!"]
		level_slots[key] = [info, fr]
		if GameState.completed.has(id):
			var b := Sprite2D.new()
			b.texture = BADGE_TEX
			b.centered = false
			b.position = Vector2(fr.end.x - 6, fr.position.y - 3)
			root.add_child(b)
	else:
		spots[empty_key] = [stand, 20.0, "E  ·  Empty frame", 3]
		lines[empty_key] = empty_lines

## objects in friends' rooms (see DreamRoom.add_object)
func add_room_spot(key: String, stand: Vector2, prompt: String, room_lines: Variant, action: Callable, radius: float, face: int) -> void:
	spots[key] = [stand, radius, "E  ·  " + prompt, clampi(face, 0, 3)]
	lines[key] = room_lines
	if action.is_valid(): room_actions[key] = action

## everyone who built a room or painted a dream
func _guestbook_lines() -> Array:
	var out: Array = ["The guestbook. Everyone who built a room or painted a dream is in here."]
	for r in rooms:
		var mine: Array = []
		for l in levels:
			if l.room == r.get_meta("id"): mine.append("\"%s\"" % l.title)
		out.append("%s – %s%s" % [r.owner, r.title, (": " + ", ".join(mine)) if mine.size() > 0 else ""])
	var others: Array = []
	for l in levels:
		var has_room := false
		for r in rooms: has_room = has_room or l.room == r.get_meta("id")
		if not has_room: others.append("\"%s\" by %s" % [l.title, l.author])
	if others.size() > 0: out.append("In the corridor: " + ", ".join(others))
	out.append("Thank you for dreaming with me.")
	return out

## a picture hanging in the attic, painted in oil (the same look as the
## painterly filter on the 3D view, so diving in is seamless)
func _oil_painting(tex: Texture2D, rect: Rect2) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.centered = false
	sp.position = rect.position
	if tex == null:
		sp.texture = CANVAS_TEX
		return sp
	sp.texture = tex
	sp.scale = rect.size / Vector2(tex.get_size())
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sp.material = PaintingPortal.oil_material(tex)
	return sp

## the picture inside a gold frame
func _art_rect(frame: Rect2) -> Rect2:
	return Rect2(frame.position + Vector2(4, 4), ART)

## place the room on screen for the current zoom and center
func _apply_view() -> void:
	var vs := get_viewport().get_visible_rect().size
	var sc := zoom * vs.y / VIEW.y
	# never show anything outside the room, whatever the zoom
	var half := vs * 0.5 / sc
	center.x = clampf(center.x, left_edge + half.x, maxf(left_edge + half.x, ROOM_W - half.x))
	center.y = clampf(center.y, half.y, maxf(half.y, VIEW.y - half.y))
	root.scale = Vector2(sc, sc)
	root.position = vs * 0.5 - center * sc

## the zoom at which `art` fills the whole screen
func _cover_zoom(art: Rect2) -> float:
	var vs := get_viewport().get_visible_rect().size
	return maxf(vs.x / art.size.x, vs.y / art.size.y) * VIEW.y / vs.y * 1.015

## dive into a painting until it is the whole screen, keep that frame for the
## next scene (PaintingPortal) and go – still moving, the next scene carries on
func _zoom_into(art: Rect2, dur: float, done: Callable) -> void:
	state = "portal"
	prompt.text = ""
	create_tween().tween_property(counter, "modulate:a", 0.0, 0.4)
	Sound.stop_music(dur)
	var z0 := zoom
	var z1 := _cover_zoom(art)
	var c0 := center
	var c1 := art.get_center()
	var tw := create_tween()
	tw.tween_method(func(u: float):
		var e := u * u                      # accelerate into the picture
		zoom = exp(lerpf(log(z0), log(z1), e))
		center = c0.lerp(c1, 1.0 - pow(1.0 - u, 3.0)), 0.0, 1.0, dur)
	await tw.finished
	zoom = z1
	center = c1
	_apply_view()   # (the tween's last step comes after this frame's _process)
	# the fully zoomed frame has been drawn by the next frame: keep it (a copy
	# on the GPU, no waiting) and switch at once – the next scene shows it,
	# still zooming, while it melts away
	await get_tree().process_frame
	PaintingPortal.capture(get_viewport())
	PaintingPortal.zoom_rate = 2.0 * log(z1 / z0) / dur
	done.call()

## The last frame of the dream we come back from lies exactly over the
## painting (the attic starts zoomed in until the painting fills the screen)
## and shrinks with it as the camera pulls back, while it melts into the oil
## paint – so the move out of the picture never stops.
func _glued_shot(art: Rect2, dur: float) -> void:
	var s := PaintingPortal.take_shot()
	if s == null: return
	var vs := get_viewport().get_visible_rect().size
	var sc := _cover_zoom(art) * vs.y / VIEW.y
	var sp := Sprite2D.new()
	sp.texture = s
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sp.position = art.get_center()
	sp.scale = Vector2(vs.x / sc / s.get_width(), vs.y / sc / s.get_height())
	sp.z_index = 100
	root.add_child(sp)
	var tw := create_tween()
	tw.tween_property(sp, "modulate:a", 0.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(sp.queue_free)

## zoom out of a painting (after leaving a level), decelerating
func _zoom_out_of(art: Rect2, target_center: Vector2, dur: float) -> void:
	var z0 := _cover_zoom(art)
	zoom = z0
	center = art.get_center()
	var c0 := center
	var tw := create_tween()
	tw.tween_method(func(u: float):
		var e := 1.0 - (1.0 - u) * (1.0 - u)
		zoom = exp(lerpf(log(z0), 0.0, e))
		center = c0.lerp(target_center, u * u), 0.0, 1.0, dur)
	await tw.finished
	_begin_play()

## start loading a level while Claude talks about its painting
func _preload(path: String) -> void:
	if not _preloading.has(path) and ResourceLoader.exists(path):
		_preloading[path] = true
		ResourceLoader.load_threaded_request(path)

func _loaded_scene(path: String) -> PackedScene:
	var st: Variant = _preloading.get(path, 0)
	if st is bool and st:
		_preloading[path] = "done"      # (a request can only be collected once)
		var ps := ResourceLoader.load_threaded_get(path) as PackedScene
		if ps: return ps
	return load(path) as PackedScene

## dust in the sunbeam and twinkling fairy lights in the gallery
func _build_ambience() -> void:
	var dust := CPUParticles2D.new()
	dust.amount = 40
	dust.lifetime = 9.0
	dust.preprocess = 9.0
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(34, 36)
	dust.position = Vector2(132, 112)
	dust.direction = Vector2(0.4, -1.0)
	dust.spread = 60.0
	dust.gravity = Vector2(0.6, 0.4)
	dust.initial_velocity_min = 0.4; dust.initial_velocity_max = 1.6
	dust.scale_amount_min = 1.0; dust.scale_amount_max = 1.0
	var g := Gradient.new()
	g.set_color(0, Color(1, 0.95, 0.8, 0.0)); g.set_color(1, Color(1, 0.95, 0.8, 0.0))
	g.add_point(0.3, Color(1, 0.95, 0.8, 0.85)); g.add_point(0.7, Color(1, 0.9, 0.7, 0.6))
	dust.color_ramp = g
	root.add_child(dust)
	# the bulbs, at the same spots make_attic.py drew them
	var nails := [6, 70, 134, 198, 258]
	var i := 0
	for n in nails.size() - 1:
		var a: int = nails[n]
		var b: int = nails[n + 1]
		for x in range(a, b + 1):
			if (x - a) % 7 != 3: continue
			var t := float(x - a) / float(b - a)
			var y := roundf(26.0 + 36.0 * t * (1.0 - t)) + 1.0
			var glow := ColorRect.new()
			glow.size = Vector2(3, 4)
			glow.position = Vector2(x - EXT - 1.0, y - 1.0)
			glow.color = [Color(1, 0.83, 0.42), Color(1, 0.62, 0.48), Color(1, 0.94, 0.72), Color(1, 0.69, 0.78)][i % 4]
			glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
			glow.set_meta("ph", randf() * TAU)
			glow.set_meta("sp", randf_range(1.2, 2.6))
			var mat := CanvasItemMaterial.new()
			mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			glow.material = mat
			root.add_child(glow)
			bulbs.append(glow)
			i += 1

func _pixel_label(size: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", PIXEL_FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.2, 0.1, 0.12))
	l.add_theme_constant_override("outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _build_dialog(ui: CanvasLayer) -> void:
	# cream box with a brown border and a CLAUDE tag, like the film
	dialog = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.98, 0.95, 0.88)
	sb.border_color = Color(0.55, 0.30, 0.22)
	sb.set_border_width_all(6)
	sb.set_corner_radius_all(2)
	sb.shadow_color = Color(0, 0, 0, 0.35); sb.shadow_size = 6
	dialog.add_theme_stylebox_override("panel", sb)
	dialog.set_anchors_preset(Control.PRESET_TOP_WIDE)
	dialog.offset_left = 36; dialog.offset_right = -36; dialog.offset_top = 30; dialog.offset_bottom = 300
	dialog.visible = false
	ui.add_child(dialog)
	var icon_bg := ColorRect.new()
	icon_bg.color = Color(0.55, 0.30, 0.22)
	icon_bg.position = Vector2(26, 22); icon_bg.size = Vector2(232, 222)
	dialog.add_child(icon_bg)
	var icon_in := ColorRect.new()
	icon_in.color = Color(0.09, 0.08, 0.11)
	icon_in.position = Vector2(32, 28); icon_in.size = Vector2(220, 210)
	dialog.add_child(icon_in)
	portrait = TextureRect.new()
	var at := AtlasTexture.new(); at.atlas = PORTRAITS; at.region = Rect2(0, 0, 25, 15)
	portrait.texture = at
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.position = Vector2(32, 56); portrait.size = Vector2(220, 141)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	dialog.add_child(portrait)
	var tag := Label.new()
	tag.text = " ✦ CLAUDE "
	tag.add_theme_font_override("font", PIXEL_FONT)
	tag.add_theme_font_size_override("font_size", 30)
	tag.add_theme_color_override("font_color", Color(1, 0.96, 0.9))
	var tsb := StyleBoxFlat.new(); tsb.bg_color = Color(0.72, 0.36, 0.26); tsb.set_corner_radius_all(2)
	tsb.border_color = Color(0.45, 0.22, 0.16); tsb.set_border_width_all(3)
	tsb.content_margin_left = 8; tsb.content_margin_right = 8
	tag.add_theme_stylebox_override("normal", tsb)
	tag.position = Vector2(46, 236)
	dialog.add_child(tag)
	dialog_text = Label.new()
	dialog_text.add_theme_font_override("font", PIXEL_FONT)
	dialog_text.add_theme_font_size_override("font_size", 44)
	dialog_text.add_theme_color_override("font_color", Color(0.20, 0.13, 0.14))
	dialog_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog_text.position = Vector2(300, 60)
	dialog_text.size = Vector2(1460, 170)
	dialog.add_child(dialog_text)

# ------------------------------------------------------------------ flow
func start(from_video: bool) -> void:
	visible = true
	state = "intro"
	_t = 0.0
	Sound.music("hub", 2.5)
	counter.text = "Colors without names  %d / 12" % GameState.found_orbs.size()
	pos = Vector2(206.0, 196.0)
	facing = -1.0
	if GameState.hub_return != "" and spots.has("lvl:" + GameState.hub_return):
		# back from a gallery level: out of the painting, Claude in front of it
		var key := "lvl:" + GameState.hub_return
		GameState.hub_return = ""
		var art := _art_rect(level_slots[key][1])
		pos = spots[key][0]
		facing = -1.0
		_happy = 3.0
		zoom = _cover_zoom(art)
		center = art.get_center()
		_glued_shot(art, 0.45)
		_zoom_out_of(art, Vector2(clampf(pos.x, left_edge + VIEW.x * 0.5, ROOM_W - VIEW.x * 0.5), 108.0), 2.8)
		return
	if GameState.hub_return == "@easel":
		# out of the first dream (pause menu) or "Continue" on the title screen,
		# which shows the same painting: zoom out of the canvas on the easel
		GameState.hub_return = ""
		GameState.painted = true
		painting.modulate.a = 1.0
		pos = Vector2(196.0, 190.0)
		_happy = 2.0
		zoom = _cover_zoom(CANVAS_RECT)
		center = CANVAS_RECT.get_center()
		_glued_shot(CANVAS_RECT, 0.45)
		_zoom_out_of(CANVAS_RECT, Vector2(192.0, 108.0), 2.8)
		return
	GameState.hub_return = ""
	if PaintingPortal.shot != null:
		# from the title screen: its last frame melts into the attic
		PaintingPortal.fade_shot(self, 0.9)
	if from_video:
		zoom = START_ZOOM
		center = START_CENTER
		_happy = 4.5
		var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_interval(0.6)
		tw.tween_property(self, "zoom", 1.0, 3.6)
		tw.parallel().tween_property(self, "center", Vector2(192.0, 108.0), 3.6)
		tw.tween_callback(_begin_play)
		# the film ends on the empty canvas: the dream appears on it while
		# the camera pulls away
		painting.modulate.a = 0.0
		create_tween().tween_property(painting, "modulate:a", 1.0, 2.2).set_delay(0.8).set_trans(Tween.TRANS_SINE)
	else:
		zoom = 1.0
		center = Vector2(192.0, 108.0)
		# debug / screenshots: --hubpos=x,y puts Claude somewhere else
		for a in Array(OS.get_cmdline_user_args()) + start_opts:
			if str(a).begins_with("--hubpos="):
				var p: PackedStringArray = str(a).substr(9).split(",")
				pos = Vector2(float(p[0]), float(p[1]))
				center.x = clampf(pos.x, left_edge + VIEW.x * 0.5, ROOM_W - VIEW.x * 0.5)
			if str(a).begins_with("--hubauto="):
				_autotalk = str(a).substr(10)
			if str(a).begins_with("--hubroom=") and room_span.has(str(a).substr(10)):
				var sp: Vector2 = room_span[str(a).substr(10)]
				pos = Vector2(sp.x + sp.y * 0.5, 182.0)
				center.x = clampf(pos.x, left_edge + VIEW.x * 0.5, ROOM_W - VIEW.x * 0.5)
		_begin_play()
		if _autotalk != "":
			_start_talk(_autotalk)

func _begin_play() -> void:
	state = "play"
	create_tween().tween_property(counter, "modulate:a", 1.0, 1.0)
	_show_hint_once()

func _show_hint_once() -> void:
	prompt.text = "WASD / arrow keys: walk   ·   E: look   ·   left: your friends' rooms"
	await get_tree().create_timer(6.0).timeout
	if prompt.text.begins_with("WASD"): prompt.text = ""

# ------------------------------------------------------------------ update
func _process(delta: float) -> void:
	if not visible: return
	_t += delta
	var moving := false
	match state:
		"play": moving = _play(delta)
		"talk": _talk(delta)
		"auto": moving = _auto(delta)
	if state == "play" or state == "talk" or state == "auto":
		# follow Claude sideways, inside the room
		var cx := clampf(pos.x, left_edge + VIEW.x * 0.5, ROOM_W - VIEW.x * 0.5)
		center.x = lerpf(center.x, cx, 1.0 - exp(-4.0 * delta))
		center.y = 108.0
	_apply_view()
	_draw_robot(delta, moving)
	for b in bulbs:
		var g := b as ColorRect
		g.modulate.a = 0.35 + 0.25 * sin(_t * float(g.get_meta("sp")) + float(g.get_meta("ph")))

func _play(delta: float) -> bool:
	var inp := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var moving := inp.length() > 0.1
	if moving:
		var spd := SPEED * (1.6 if Input.is_action_pressed("sprint") else 1.0)
		var np := pos + Vector2(inp.x, inp.y * 0.7) * spd * delta
		if _walkable(Vector2(np.x, pos.y)): pos.x = np.x
		if _walkable(Vector2(pos.x, np.y)): pos.y = np.y
		if absf(inp.x) > 0.1: facing = signf(inp.x)
		_step(delta, spd)
	# interaction prompts
	var near := _nearest_spot()
	# near a painting: start loading its level in the background already
	if level_slots.has(near): _preload((level_slots[near][0] as LevelInfo).scene)
	if not prompt.text.begins_with("WASD"):
		prompt.text = spots[near][2] if near != "" else ""
	if near != "" and Input.is_action_just_pressed("interact"):
		_start_talk(near)
	return moving

func _step(delta: float, spd: float) -> void:
	_step_acc += delta * spd / SPEED
	if _step_acc > 0.32:
		_step_acc = 0.0
		Sound.sfx("step_wood_%d" % (randi() % 3), -12.0, 1.0, 0.06)

func _nearest_spot() -> String:
	var best := ""
	var bd := 1e9
	for k in spots:
		var d := pos.distance_to(spots[k][0])
		if d < float(spots[k][1]) and d < bd:
			bd = d
			best = k
	return best

func _walkable(p: Vector2) -> bool:
	if not Geometry2D.is_point_in_polygon(p, walk): return false
	for r in BLOCKERS:
		if (r as Rect2).has_point(p): return false
	return true

## walk on its own to a point (cutscenes), then call back
func _walk_to(target: Vector2, done: Callable) -> void:
	state = "auto"
	_auto_target = target
	_auto_done = done

func _auto(delta: float) -> bool:
	var d := _auto_target - pos
	if d.length() < 1.0:
		pos = _auto_target
		state = "cutscene"
		_auto_done.call()
		return false
	var v := d.normalized() * SPEED * delta
	if v.length() > d.length(): v = d
	pos += v
	if absf(d.x) > 0.5: facing = signf(d.x)
	_step(delta, SPEED)
	return true

func _draw_robot(delta: float, moving: bool) -> void:
	_anim += delta
	_blink -= delta
	_happy -= delta
	var frame: int = F_IDLE[int(_anim * 1.6) % 2]
	if moving:
		frame = F_WALK[int(_anim * 8.0) % 4]
	else:
		if _blink < 0.0:
			frame = F_BLINK
			if _blink < -0.14: _blink = randf_range(2.0, 4.5)
		if _happy > 0.0: frame = F_HAPPY
		if _face >= 0: frame = _face
	robot.region_rect = Rect2(frame * FW, 0, FW, FH)
	# take on the room's light: warm sunset in the studio, dimmer in the gallery
	var warm := clampf((pos.x + 30.0) / 110.0, 0.0, 1.0)
	var col := Color(0.84, 0.76, 0.78).lerp(Color(1.0, 0.88, 0.80), warm)
	for z in _tint_zones:
		var inside := clampf(minf(pos.x - float(z[0]), float(z[1]) - pos.x) / 24.0 + 0.5, 0.0, 1.0)
		col = col.lerp(z[2], inside)
	robot.modulate = col
	robot.flip_h = facing < 0.0
	robot.position = (pos - FOOT).round()
	shadow.position = pos.round() + Vector2(0, 0.5)

# ------------------------------------------------------------------ dialog
func _start_talk(id: String) -> void:
	if level_slots.has(id): _preload((level_slots[id][0] as LevelInfo).scene)
	state = "talk"
	_talk_id = id
	var l: Variant = lines[id]
	_lines = (l as Callable).call() if l is Callable else l
	if "--hubtalklog" in OS.get_cmdline_user_args(): print("[talk ", id, "] ", _lines)
	_line_i = 0
	prompt.text = ""
	var p: int = spots[id][3]
	(portrait.texture as AtlasTexture).region = Rect2(p * 25, 0, 25, 15)
	_face = [-1, F_HAPPY, F_SPARKLE, F_WIDE][p]
	dialog.visible = true
	_show_line()
	if id == "easel" or level_slots.has(id):
		_hold_typing = true
		_get_ready_for.call_deferred(id)

## While Claude talks about a painting, the level behind it is built and
## parked (SceneSwap) – the dialog box has just appeared, so the short stall
## this costs can't be seen. Stepping into the painting is then free.
func _get_ready_for(id: String) -> void:
	# let the empty dialog box show up first, then build (the text starts after)
	await get_tree().process_frame
	await get_tree().process_frame
	_hold_typing = false
	if state != "talk" or _talk_id != id: return
	if id == "easel":
		dream_soon.emit()
	elif level_slots.has(id):
		var info: LevelInfo = level_slots[id][0]
		if SceneSwap.parked_by == self and _parked_key == id: return
		var lvl := SceneSwap.prepare(_loaded_scene(info.scene), self)
		_parked_key = id
		if lvl and lvl.has_method("painting_view"):
			var v: Array = lvl.call("painting_view")
			SceneSwap.warm_up(v[0], v[1])

func _exit_tree() -> void:
	SceneSwap.discard(self)

func _show_line() -> void:
	dialog_text.text = _lines[_line_i]
	dialog_text.visible_characters = 0
	_typing = 0.0

func _talk(delta: float) -> void:
	if _hold_typing: return       # the painting's level is being built (see _get_ready_for)
	delta = minf(delta, 1.0 / 30.0)
	var total := dialog_text.text.length()
	if dialog_text.visible_characters < total:
		_typing += delta * 40.0
		var vis := mini(int(_typing), total)
		if vis != dialog_text.visible_characters and vis % 2 == 0:
			Sound.sfx("text", -14.0, 1.0, 0.1)
		dialog_text.visible_characters = vis
		if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("jump"):
			dialog_text.visible_characters = total
		return
	_autoclick += delta
	var next := Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("jump")
	if _autotalk != "" and _autoclick > 0.9:
		next = true
	if next:
		_autoclick = 0.0
		_line_i += 1
		if _line_i >= _lines.size():
			dialog.visible = false
			_face = -1
			if _talk_id == "easel":
				_paint_and_dream()
			elif room_actions.has(_talk_id):
				state = "play"
				if "--hubtalklog" in OS.get_cmdline_user_args(): print("[action ", _talk_id, "]")
				(room_actions[_talk_id] as Callable).call()
			elif level_slots.has(_talk_id):
				_enter_level(_talk_id)
			else:
				state = "play"
		else:
			_show_line()

func _paint_and_dream() -> void:
	_walk_to(Vector2(196.0, 190.0), func():
		facing = -1.0
		_face = F_SPARKLE
		Sound.sfx("sparkle", -4.0)
		painting.modulate.a = 1.0
		# main builds the dream in the background: if it isn't quite done,
		# Claude waits a moment in front of the painting (nothing stalls)
		state = "wait"
		while dream_gate.is_valid() and not dream_gate.call():
			await get_tree().process_frame
		var tw := create_tween()
		tw.tween_interval(0.5)
		tw.tween_callback(func(): Sound.sfx("riser", -2.0))
		tw.tween_callback(func(): _zoom_into(CANVAS_RECT, 2.6, func():
			GameState.painted = true
			GameState.save()
			dream_requested.emit())))

func _enter_level(key: String) -> void:
	var info: LevelInfo = level_slots[key][0]
	var art := _art_rect(level_slots[key][1])
	_walk_to(spots[key][0], func():
		_face = F_SPARKLE
		Sound.sfx("sparkle", -4.0)
		var tw := create_tween()
		tw.tween_interval(0.5)
		tw.tween_callback(func(): Sound.sfx("riser", -2.0))
		tw.tween_callback(func(): _zoom_into(art, 2.4, func():
			GameState.dreams += 1
			if SceneSwap.parked_by == self and _parked_key == key:
				SceneSwap.swap()
			else:
				get_tree().change_scene_to_packed(_loaded_scene(info.scene)))))
