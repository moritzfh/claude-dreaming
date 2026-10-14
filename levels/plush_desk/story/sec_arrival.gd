## Chapter one starts in a soft felt picture book. Claude drops in from the
## sky, lands on the open pages and the pop-ups fold up around her. On the
## right page lies the guestbook: type your name (on your real keyboard) and
## it is embroidered onto the banner, then the zipper gate opens.
extends RefCounted

const Kit := preload("res://levels/plush_desk/story/kit.gd")
const A := "res://levels/plush_desk/audio/"

var w: Node3D
var popups: Array = []
var _landed := false
var _land_t := 0.0
var banner_label: Label3D
var name_text := ""
var typing := false
var signed := false
var gate_l: Node3D
var gate_r: Node3D
var gate_body: StaticBody3D
var zip_pull: Node3D
var needle: Node3D
var _gate_t := -1.0
var _prompt_shown := false
var lectern_x := 6.0

func build() -> void:
	var root := Node3D.new()
	root.name = "Arrival"
	w.add_child(root)
	# --- the felt quiet book: covers, two soft pages, the spine
	Kit.block(root, Vector3(-5.5, -0.75, 0.0), Vector3(11.4, 0.5, 6.4), Kit.CORAL, Kit.CREAM, 0, false)
	Kit.block(root, Vector3(5.7, -0.75, 0.0), Vector3(11.4, 0.5, 6.4), Kit.CORAL, Kit.CREAM, 0, false)
	Kit.block(root, Vector3(-5.4, -0.25, 0.0), Vector3(10.8, 0.5, 5.8), Kit.CREAM, Kit.CREAM, 0, true)
	Kit.block(root, Vector3(5.6, -0.25, 0.0), Vector3(10.8, 0.5, 5.8), Kit.CREAM, Kit.CREAM, 0, true)
	Kit.block(root, Vector3(0.1, -0.42, 0.0), Vector3(0.7, 0.5, 6.0), Kit.CORAL.darkened(0.15), Kit.CREAM, 0, true)
	# page lines embroidered on the left page and the chapter title
	for i in 4:
		var ln := Kit.block(root, Vector3(-6.5, 0.02, -2.2 + i * 0.12), Vector3(7.0, 0.03, 0.04), Color(0.55, 0.68, 0.9), Kit.CREAM, 0, false)
		ln.visible = i == 0
	var title := _popup(root, Vector3(-6.0, 0.0, -2.25), 0.15)
	Kit.cutout(title, PackedVector2Array([Vector2(-3.6, 0), Vector2(3.6, 0), Vector2(3.8, 2.3), Vector2(-3.8, 2.3)]), 0.1,
		Transform3D(Basis(), Vector3(0, 0, 0)), Color(0.95, 0.88, 0.74, 1.0))
	Kit.label(title, "CHAPTER ONE", Vector3(0, 1.75, 0.07), 0.009, Color(0.86, 0.45, 0.38), 64)
	Kit.label(title, "First Stitches", Vector3(0, 0.95, 0.07), 0.016, Color(0.3, 0.2, 0.32), 72)
	# pop-up scenery
	_tree(root, Vector3(-9.6, 0.0, -2.4), 2.6, Kit.GRASS, 0.3)
	_tree(root, Vector3(-1.8, 0.0, -2.5), 2.0, Color(0.42, 0.66, 0.4), 0.45)
	_tree(root, Vector3(3.2, 0.0, -2.45), 2.9, Kit.GRASS.lightened(0.1), 0.6)
	_house(root, Vector3(9.6, 0.0, -2.35), 0.75)
	_sun(root, Vector3(0.8, 0.0, -2.6), 0.9)
	for i in 9:
		_flower(root, Vector3(-10.0 + i * 2.3 + sin(i * 2.1) * 0.6, 0.0, 2.45 - (i % 2) * 0.25), 0.35 + 0.1 * (i % 3), i)
	# the guestbook on a felt lectern
	Kit.block(root, Vector3(lectern_x, 0.55, -1.25), Vector3(1.0, 1.1, 0.9), Kit.TEAL, Kit.CREAM, 1, true)
	Kit.block(root, Vector3(lectern_x - 0.24, 1.18, -1.25), Vector3(0.6, 0.12, 0.8), Kit.LILAC, Kit.CREAM, 0, false)
	Kit.block(root, Vector3(lectern_x + 0.24, 1.18, -1.25), Vector3(0.6, 0.12, 0.8), Kit.LILAC, Kit.CREAM, 0, false)
	Kit.label(root, "GUESTBOOK", Vector3(lectern_x, 0.85, -0.78), 0.0042, Kit.CREAM, 64)
	# the banner for the name, on two big pins
	for x in [lectern_x + 1.1, lectern_x + 4.7]:
		var p := Kit.pin(root, Vector3(x, 0.0, -2.35), Kit.MUSTARD)
		(p.get_node("Flag") as Node3D).visible = false
	var ban := Kit.block(root, Vector3(lectern_x + 2.9, 2.05, -2.35), Vector3(3.6, 0.7, 0.08), Kit.MUSTARD, Kit.CREAM, 0, false)
	ban.name = "Banner"
	banner_label = Kit.label(root, "", Vector3(lectern_x + 2.9, 2.03, -2.29), 0.0085, Color(0.3, 0.2, 0.32), 72)
	needle = Node3D.new()
	root.add_child(needle)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.82, 0.84, 0.88); steel.metallic = 1.0; steel.roughness = 0.2
	var nd := MeshInstance3D.new()
	var nm := CylinderMesh.new(); nm.top_radius = 0.02; nm.bottom_radius = 0.003; nm.height = 0.7
	nd.mesh = nm
	nd.material_override = steel
	nd.position.y = 0.35
	needle.add_child(nd)
	needle.position = Vector3(lectern_x + 1.4, 2.0, -2.2)
	needle.visible = false
	# the zipper gate across all three layers
	var gx := 10.4
	gate_l = Node3D.new()
	gate_l.position = Vector3(gx, 0.0, 0.0)
	root.add_child(gate_l)
	gate_r = Node3D.new()
	gate_r.position = Vector3(gx, 0.0, 0.0)
	root.add_child(gate_r)
	Kit.block(gate_l, Vector3(0.0, 1.6, -1.45), Vector3(0.22, 3.2, 2.9), Kit.TEAL, Kit.CREAM, 1, false)
	Kit.block(gate_r, Vector3(0.0, 1.6, 1.45), Vector3(0.22, 3.2, 2.9), Kit.TEAL, Kit.CREAM, 1, false)
	var teeth := Kit.block(root, Vector3(gx, 1.6, 0.0), Vector3(0.26, 3.2, 0.12), Color(0.82, 0.84, 0.86), Kit.CREAM, 3, false)
	teeth.name = "Teeth"
	zip_pull = Node3D.new()
	zip_pull.position = Vector3(gx + 0.2, 3.1, 0.0)
	root.add_child(zip_pull)
	Kit.block(zip_pull, Vector3(0.0, -0.25, 0.0), Vector3(0.12, 0.5, 0.25), Kit.MUSTARD, Kit.CREAM, 0, false)
	gate_body = StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new(); bs.size = Vector3(0.4, 6.0, 6.0)
	cs.shape = bs
	gate_body.position = Vector3(gx, 3.0, 0.0)
	gate_body.add_child(cs)
	root.add_child(gate_body)
	# a wall at the far left so nobody walks off the book
	var wall := StaticBody3D.new()
	var wcs := CollisionShape3D.new()
	var wbs := BoxShape3D.new(); wbs.size = Vector3(0.4, 12.0, 6.0)
	wcs.shape = wbs
	wall.position = Vector3(-11.2, 5.0, 0.0)
	wall.add_child(wcs)
	root.add_child(wall)
	# spools on the pages
	for i in 5:
		w.spool(Vector3(-3.0 + i * 0.9, 0.7, w.lane_z(1)))
	w.spool_arc(Vector3(2.0, 0.6, w.lane_z(1)), Vector3(4.6, 0.6, w.lane_z(1)), 4, 1.0)
	w.key_sign(Vector3(0.9, 0.0, -1.9), KEY_A, "")
	w.key_sign(Vector3(1.6, 0.0, -1.9), KEY_D, "")
	w.key_sign(Vector3(4.1, 0.0, -1.9), KEY_SPACE, "", 3.0)

func _popup(parent: Node3D, pos: Vector3, delay: float) -> Node3D:
	var pv := Node3D.new()
	pv.position = pos
	pv.rotation.x = -PI * 0.5
	pv.set_meta("delay", delay)
	parent.add_child(pv)
	popups.append(pv)
	return pv

func _tree(parent: Node3D, pos: Vector3, h: float, col: Color, delay: float) -> void:
	var pv := _popup(parent, pos, delay)
	Kit.cutout(pv, PackedVector2Array([Vector2(-0.15, 0), Vector2(0.15, 0), Vector2(0.12, h * 0.55), Vector2(-0.12, h * 0.55)]),
		0.08, Transform3D(), Color(0.6, 0.4, 0.26, 0.9))
	var crown := Kit.blob(h * 0.38, 26, 0.1, pos.x)
	var t := Transform3D(Basis(), Vector3(0, h * 0.68, 0.02))
	Kit.cutout(pv, crown, 0.1, t, Color(col.r, col.g, col.b, 1.0))

func _house(parent: Node3D, pos: Vector3, delay: float) -> void:
	var pv := _popup(parent, pos, delay)
	Kit.cutout(pv, Kit.rect(1.6, 1.3, 0, 0.65), 0.08, Transform3D(), Color(0.95, 0.88, 0.74, 1.0))
	Kit.cutout(pv, PackedVector2Array([Vector2(-1.0, 1.25), Vector2(1.0, 1.25), Vector2(0, 2.2)]), 0.08,
		Transform3D(Basis(), Vector3(0, 0, 0.03)), Color(0.86, 0.45, 0.38, 1.0))
	Kit.cutout(pv, Kit.rect(0.45, 0.7, 0.25, 0.35), 0.06, Transform3D(Basis(), Vector3(0, 0, 0.06)), Color(0.32, 0.6, 0.62, 1.0))
	Kit.cutout(pv, Kit.rect(0.35, 0.35, -0.4, 0.8), 0.06, Transform3D(Basis(), Vector3(0, 0, 0.06)), Color(0.93, 0.7, 0.32, 1.0))

func _sun(parent: Node3D, pos: Vector3, delay: float) -> void:
	var pv := _popup(parent, pos, delay)
	Kit.cutout(pv, Kit.rect(0.08, 3.2, 0, 1.6), 0.06, Transform3D(), Color(0.6, 0.4, 0.26, 0.6))
	var rays := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		var r := 0.95 if i % 2 == 0 else 0.7
		rays.append(Vector2(cos(a) * r, sin(a) * r + 3.4))
	Kit.cutout(pv, rays, 0.08, Transform3D(Basis(), Vector3(0, 0, 0.02)), Color(0.98, 0.72, 0.3, 1.0))
	Kit.cutout(pv, Kit.circle(0.55, 24, 0, 3.4), 0.06, Transform3D(Basis(), Vector3(0, 0, 0.07)), Color(1.0, 0.85, 0.42, 1.0))

func _flower(parent: Node3D, pos: Vector3, s: float, i: int) -> void:
	var pv := _popup(parent, pos, 0.2 + 0.05 * i)
	Kit.block(pv, Vector3(0, s * 0.5, 0), Vector3(0.05, s, 0.05), Kit.GRASS.darkened(0.2), Kit.CREAM, 0, false)
	var cols := [Kit.PINK, Kit.MUSTARD, Kit.LILAC, Kit.CORAL]
	var petals := PackedVector2Array()
	for k in 20:
		var a := TAU * k / 20.0
		var r := s * (0.32 + 0.12 * cos(a * 5.0))
		petals.append(Vector2(cos(a) * r, sin(a) * r + s))
	Kit.cutout(pv, petals, 0.05, Transform3D(), cols[i % cols.size()])
	Kit.cutout(pv, Kit.circle(s * 0.11, 12, 0, s), 0.05, Transform3D(Basis(), Vector3(0, 0, 0.03)), Color(1.0, 0.85, 0.42, 1.0))

# ------------------------------------------------------------------ flow
func arrive() -> void:
	_landed = false
	_land_t = 0.0
	for pv in popups:
		(pv as Node3D).rotation.x = -PI * 0.5
	w.place_claude(Vector3(-2.0, 9.0, 0.0), 1, 1.0)
	w.claude.spawn_xf = Transform3D(Basis(), w.g(Vector3(-2.0, 0.6, w.lane_z(1))))
	w.claude.control_enabled = false
	w.claude.rig.set("mood", 3)

func update(delta: float) -> void:
	var c: Player = w.claude
	if not _landed and c.is_on_floor() and w.claude_local().x < lectern_x:
		_landed = true
		_land_t = 0.0
		Sound.sfx(A + "squish.ogg", -2.0, 0.8)
		w.shake(0.25)
		var k := 0
		for pv in popups:
			var node: Node3D = pv
			var tw := node.create_tween()
			tw.tween_interval(float(node.get_meta("delay")) + 0.04 * k)
			tw.tween_callback(func() -> void: Sound.sfx(A + "rustle.ogg", -14.0, randf_range(1.1, 1.5)))
			tw.tween_property(node, "rotation:x", 0.0, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			k += 1
		w.narrate("Ah. You're new. Everyone is, at first.", 2.6)
		w.narrate("This is a world nobody finished. On purpose.", 3.0)
	if _landed:
		_land_t += delta
		if _land_t > 1.0 and not c.control_enabled and not typing and not signed:
			c.control_enabled = true
			c.rig.set("mood", 0)
	var lp: Vector3 = w.claude_local()
	# the guestbook
	if not signed and not typing:
		var near := absf(lp.x - lectern_x) < 1.6 and lp.y < 2.0
		w.prompt("E · sign the guestbook" if near else "")
		if near and not _prompt_shown:
			_prompt_shown = true
			w.narrate("Every world here is signed by the people who make it. Go on, sign the book.", 3.4)
		if near and Input.is_action_just_pressed("interact") and c.control_enabled:
			typing = true
			c.control_enabled = false
			w.typing_target = self
			w.prompt("type your name · Enter when done")
			needle.visible = true
			Sound.sfx(A + "click.ogg", -6.0)
	if _gate_t >= 0.0:
		_gate_t += delta
		var k := clampf(_gate_t / 1.1, 0.0, 1.0)
		zip_pull.position.y = lerpf(3.1, 0.3, smoothstep(0.0, 0.6, k))
		var o := smoothstep(0.45, 1.0, k)
		gate_l.rotation.y = o * 1.35
		gate_r.rotation.y = -o * 1.35
		if k >= 1.0:
			_gate_t = -1.0
	if needle.visible:
		var bx := lectern_x + 2.9 - banner_label.text.length() * 0.105 * 0.5 + name_text.length() * 0.21 * 0.5
		needle.position = needle.position.lerp(Vector3(bx + 0.15, 2.05 + absf(sin(w.t * 18.0)) * 0.12, -2.2), 1.0 - exp(-12.0 * delta))

## typed characters arrive here (story.gd routes key events while typing)
func type_char(ch: String) -> void:
	if name_text.length() >= 14:
		return
	name_text += ch
	banner_label.text = name_text
	Sound.sfx(A + "click.ogg", -12.0, randf_range(1.3, 1.6))
	Sound.sfx(A + "squish.ogg", -18.0, 1.6)

func type_erase() -> void:
	if name_text.length() > 0:
		name_text = name_text.substr(0, name_text.length() - 1)
		banner_label.text = name_text

func type_done() -> void:
	typing = false
	signed = true
	w.typing_target = null
	needle.visible = false
	var nm := name_text.strip_edges()
	if nm == "":
		nm = "Claude"
		name_text = nm
		banner_label.text = nm
	w.player_name = nm
	w.prompt("")
	w.claude.control_enabled = true
	Sound.sfx(A + "chime.ogg", -4.0)
	w.narrate("Nice to meet you, %s. Now, let's see what you can do." % nm, 3.2)
	_gate_t = 0.0
	Sound.sfx(A + "whoosh.ogg", -6.0, 1.4)
	gate_body.get_child(0).set_deferred("disabled", true)
