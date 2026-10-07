## The seamless way into and out of paintings – no white flash, no cut.
##
## The paintings in the attic are painted in oil (oil_material): the same look
## as the painterly filter on the 3D view. Stepping in, the attic dives into a
## painting until it fills the screen – which then looks just like the 3D
## world seen from the painting's camera through the painterly filter. The
## attic's very last frame is kept (capture()); the level shows it on top for
## a moment and lets it melt away while its camera is already moving
## (fade_shot()). Leaving works the same way backwards.
class_name PaintingPortal
extends CanvasLayer

const OIL := preload("res://shaders/oil_paint.gdshader")

## the last frame before a scene change (null = we didn't come through a painting)
static var shot: Texture2D
static var _mipmapped := {}

static func capture(vp: Viewport) -> void:
	if DisplayServer.get_name() == "headless":   # nothing is drawn (tests)
		shot = null
		return
	# copy the frame on the graphics card: reading it back to the CPU would
	# make the CPU wait for the GPU – a hitch right at the moment of the switch
	shot = _gpu_copy(vp)
	if shot: return
	var img := vp.get_texture().get_image() if vp.get_texture() else null
	shot = ImageTexture.create_from_image(img) if img and not img.is_empty() else null

static var _rids: Array[RID] = []

static func _gpu_copy(vp: Viewport) -> Texture2D:
	var rd := RenderingServer.get_rendering_device()
	if rd == null or vp.get_texture() == null: return null   # (Compatibility renderer)
	var src := RenderingServer.texture_get_rd_texture(vp.get_texture().get_rid())
	if not src.is_valid(): return null
	var f: RDTextureFormat = rd.texture_get_format(src)
	var fmt := RDTextureFormat.new()
	fmt.width = f.width
	fmt.height = f.height
	fmt.format = f.format
	fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT
	var dst := rd.texture_create(fmt, RDTextureView.new())
	if not dst.is_valid(): return null
	if rd.texture_copy(src, dst, Vector3.ZERO, Vector3.ZERO, Vector3(f.width, f.height, 1), 0, 0, 0, 0) != OK:
		rd.free_rid(dst)
		return null
	# the copies of earlier switches aren't shown any more
	for r in _rids: rd.free_rid(r)
	_rids = [dst]
	var t := Texture2DRD.new()
	t.texture_rd_rid = dst
	return t

static func take_shot() -> Texture2D:
	var s := shot
	shot = null
	return s

## how fast the attic was zooming into the painting when the frame was kept
## (log scale per second) – the kept frame carries the motion on
static var zoom_rate := 0.0

## Show the previous scene's last frame on top of `parent` and let it melt
## into what's behind it over `dur` seconds. With `zoom` (log scale per
## second) it keeps zooming in while it melts, slowing down – so the camera
## move into the painting doesn't stop for a moment at the switch.
static func fade_shot(parent: Node, dur := 0.45, zoom := 0.0) -> void:
	var s := take_shot()
	if s == null: return
	var p := PaintingPortal.new()
	parent.add_child(p)
	var r := TextureRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.texture = s
	p.add_child(r)
	var tw := p.create_tween()
	tw.tween_property(r, "modulate:a", 0.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if zoom > 0.0:
		r.pivot_offset = parent.get_viewport().get_visible_rect().size * 0.5
		var end := exp(zoom * dur * 0.5)    # ease-out: starts at `zoom`, ends at rest
		tw.parallel().tween_property(r, "scale", Vector2(end, end), dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(p.queue_free)

## Like fade_shot, but the kept frame moves with the 3D camera that starts
## where the picture was taken: the point the camera looks at stays where it
## is in the picture, and the picture grows as the camera comes closer. So the
## picture and the world behind it don't drift apart while they cross-fade.
static func follow_shot(parent: Node, dur: float, cam: Camera3D, look: Vector3) -> void:
	var s := take_shot()
	if s == null or cam == null: return
	var p := PaintingPortal.new()
	parent.add_child(p)
	var r := TextureRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.texture = s
	p.add_child(r)
	p._rect = r
	p._cam = cam
	p._look = look
	p._d0 = maxf(cam.global_position.distance_to(look), 0.01)
	p._f0 = cam.fov
	var tw := p.create_tween()
	tw.tween_property(r, "modulate:a", 0.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(p.queue_free)

var _rect: TextureRect
var _cam: Camera3D
var _look := Vector3.ZERO
var _d0 := 1.0
var _f0 := 60.0

func _process(_delta: float) -> void:
	if _rect == null or _cam == null or not is_instance_valid(_cam): return
	var vs := get_viewport().get_visible_rect().size
	var c := vs * 0.5
	var d := maxf(_cam.global_position.distance_to(_look), 0.01)
	var k := (_d0 / d) * tan(deg_to_rad(_f0) * 0.5) / tan(deg_to_rad(_cam.fov) * 0.5)
	_rect.pivot_offset = c
	_rect.scale = Vector2(k, k)
	if not _cam.is_position_behind(_look):
		_rect.position = _cam.unproject_position(_look) - c

## A material that paints `tex` in oil (for a Sprite2D or TextureRect showing it).
static func oil_material(tex: Texture2D) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = OIL
	var t := _with_mipmaps(tex)
	m.set_shader_parameter("src", t)
	m.set_shader_parameter("src_size", Vector2(t.get_size()) if t else Vector2(1280, 720))
	# the same noise as the screen filter (GameHUD), so both look identical
	m.set_shader_parameter("canvas_noise", Tex.noise(77, 0.05, 256, 3))
	m.set_shader_parameter("stroke_noise", Tex.white(5))
	return m

## the oil look needs blurred versions of the picture (mipmaps)
static func _with_mipmaps(tex: Texture2D) -> Texture2D:
	if tex == null: return null
	if _mipmapped.has(tex): return _mipmapped[tex]
	var img := tex.get_image()
	if img == null: return tex
	if img.is_compressed(): img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_mipmapped[tex] = t
	return t

func _init() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 100      # after the camera has moved this frame
