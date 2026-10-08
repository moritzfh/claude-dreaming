## Base class for a friend's room in the attic (rooms/<id>/room.gd).
##
## The room's picture (room.png) and its paintings are put up by the attic.
## Use build() for everything that moves, glows or can be used with E.
## Coordinates are room pixels: x = 0 at the room's left edge, y = 0 at the
## top; the wall ends at y = 145, the floor Claude walks on is y = 160..212.
##
##   func build() -> void:
##       add_object("lamp", Vector2(120, 170), "Lamp", ["A lamp."], func(): _lamp_on = not _lamp_on)
class_name DreamRoom
extends Node2D

var info: RoomInfo
var room_id := ""
var hub: AtticHub
var width := 0.0
var t := 0.0          # seconds since the attic opened (handy for animation)

## override: add sprites, lights, objects
func build() -> void:
	pass

## Something Claude can walk up to and use with E.
##   stand: where Claude stands (room pixels, on the floor)
##   prompt: shown at the bottom ("E · <prompt>")
##   lines: what Claude says – an Array of Strings, or a Callable returning one
##   action: called after the last line (optional)
##   face: Claude's portrait: 0 normal, 1 happy, 2 sparkle, 3 surprised
func add_object(id: String, stand: Vector2, prompt: String, lines: Variant, action := Callable(), radius := 18.0, face := 0) -> void:
	hub.add_room_spot(room_id + "/" + id, stand + position, prompt, lines, action, radius, face)

## Claude's feet in room pixels
func claude_pos() -> Vector2:
	return hub.pos - position

func is_claude_inside() -> bool:
	var p := claude_pos()
	return p.x >= 0.0 and p.x <= width

## a texture drawn at a pixel position (top-left)
func add_sprite(tex: Texture2D, pos: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.position = pos
	add_child(s)
	return s

## a soft additive glow (for lamps, stars, windows)
func add_glow(pos: Vector2, radius: float, color: Color) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _glow_tex()
	s.position = pos
	s.scale = Vector2.ONE * radius / 32.0
	s.modulate = color
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	s.material = m
	add_child(s)
	return s

## a tiny image from rows of characters, e.g. ["..#..", ".###."] with
## {"#": Color(...)} – quick pixel sprites without a file
static func pixels(rows: Array, palette: Dictionary) -> ImageTexture:
	var h := rows.size()
	var w := 0
	for r in rows: w = maxi(w, (r as String).length())
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var r: String = rows[y]
		for x in r.length():
			var ch := r[x]
			if palette.has(ch): img.set_pixel(x, y, palette[ch])
	return ImageTexture.create_from_image(img)

static var _glow: Texture2D
static func _glow_tex() -> Texture2D:
	if _glow: return _glow
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 64
	gt.height = 64
	_glow = gt
	return _glow
