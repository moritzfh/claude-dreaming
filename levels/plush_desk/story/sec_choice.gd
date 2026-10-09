## "You choose what comes next." Three embroidered cards on a felt workbench:
## a bouncy castle, a ribbon river or a windy cliff. The camera swings out,
## the chosen part flies in piece by piece and is sewn into the gap, then you
## play it. Every run can be a different one.
extends RefCounted

const Kit := preload("res://levels/plush_desk/story/kit.gd")
const A := "res://levels/plush_desk/audio/"

const GAP0 := 288.0
const GAP1 := 318.0

var w: Node3D
var root: Node3D
var cards: Array = []          # {"id", "node", "x"}
var variants := {}             # id -> {"node", "pieces": [[pivot, final_xf]]}
var chosen := ""
var _build_t := -1.0
var _cut_from := Transform3D()
var river: MeshInstance3D
var leaves: Array = []         # [body, base, amp, speed, phase]
var gusts := false
var _gust_t := 0.0
var _gust_on := false
var rocks: Array = []          # [x, lane]
var gust_fx: GPUParticles3D
var outline: MeshInstance3D
var forces: Array = []         # [variant id, bounce/updraft dict]

func build() -> void:
	root = Node3D.new()
	root.name = "Choice"
	w.add_child(root)
	var M: float = w.lane_z(1)
	Kit.block(root, Vector3(279.5, -1.5, 0.0), Vector3(17.0, 3.0, 4.2), Kit.LILAC, Kit.CREAM, 5, true)
	Kit.block(root, Vector3(322.0, -1.5, 0.0), Vector3(8.0, 3.0, 4.2), Kit.LILAC, Kit.CREAM, 5, true)
	w.checkpoint(Vector3(274.6, 0.0, 0.0), 1, Kit.PINK)
	w.narrate_at(275.4, "Now the best part. You choose what comes next. And we sew it in. Right now.", 4.0)
	# the workbench behind the cards
	Kit.block(root, Vector3(281.6, 1.3, -1.7), Vector3(7.4, 0.35, 1.5), Color(0.62, 0.42, 0.3), Kit.CREAM, 3, true)
	for lx in [278.3, 284.9]:
		Kit.block(root, Vector3(lx, 0.55, -1.7), Vector3(0.35, 1.1, 1.2), Color(0.55, 0.37, 0.26), Kit.CREAM, 0, false)
	# scissors, a tape measure and pins on the bench (decoration)
	Kit.button(root, Vector3(279.0, 1.48, -1.9), 0.3, Kit.CORAL, 0.3, false)
	Kit.button(root, Vector3(283.8, 1.48, -1.6), 0.24, Kit.TEAL, 1.2, false)
	var tape := MeshInstance3D.new()
	var cm := CylinderMesh.new(); cm.top_radius = 0.38; cm.bottom_radius = 0.38; cm.height = 0.2
	tape.mesh = cm
	tape.position = Vector3(282.3, 1.58, -1.9)
	tape.material_override = Kit.fabric(Kit.MUSTARD, Kit.T_FELT, 4.0, 1.0)
	root.add_child(tape)
	_card("castle", 279.4, "BOUNCY\nCASTLE", Kit.PINK)
	_card("river", 281.7, "RIBBON\nRIVER", Kit.SKY)
	_card("cliff", 284.0, "WINDY\nCLIFF", Kit.MUSTARD)
	# the empty gap, with a big "sew here" outline
	var om := ShaderMaterial.new()
	om.shader = load("res://levels/plush_desk/shaders/sew_outline.gdshader")
	outline = MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = Vector3(GAP1 - GAP0, 6.0, 4.0)
	outline.mesh = bm
	outline.material_override = om
	outline.set_instance_shader_parameter("half_size", bm.size * 0.5)
	outline.position = Vector3((GAP0 + GAP1) * 0.5, 2.0, 0.0)
	outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(outline)
	_build_castle()
	_build_river()
	_build_cliff()
	for id in variants:
		_set_variant(id, false)

func _card(id: String, x: float, title: String, col: Color) -> void:
	var n := Node3D.new()
	n.position = Vector3(x, 0.0, -0.75)
	root.add_child(n)
	Kit.cutout(n, PackedVector2Array([Vector2(-0.75, 0), Vector2(0.75, 0), Vector2(0.7, 2.0), Vector2(-0.7, 2.0)]), 0.07,
		Transform3D(Basis(Vector3.RIGHT, -0.12), Vector3.ZERO), Color(0.97, 0.92, 0.8, 1.0))
	Kit.felt_cutout(n, Kit.rect(1.25, 0.08, 0, 1.7), 0.02, Transform3D(Basis(Vector3.RIGHT, -0.12), Vector3(0, 0, 0.05)), col, 4.0)
	var l := Kit.label(n, title, Vector3(0, 0.55, 0.12), 0.0055, Color(0.3, 0.2, 0.32), 64)
	l.rotation.x = -0.12
	var icon := Node3D.new()
	icon.position = Vector3(0, 1.25, 0.1)
	icon.rotation.x = -0.12
	n.add_child(icon)
	match id:
		"castle":
			var c := PackedVector2Array([Vector2(-0.45, -0.25), Vector2(0.45, -0.25), Vector2(0.45, 0.2), Vector2(0.3, 0.2),
				Vector2(0.3, 0.1), Vector2(0.15, 0.1), Vector2(0.15, 0.2), Vector2(-0.15, 0.2), Vector2(-0.15, 0.1),
				Vector2(-0.3, 0.1), Vector2(-0.3, 0.2), Vector2(-0.45, 0.2)])
			Kit.felt_cutout(icon, c, 0.04, Transform3D(), Kit.PINK, 5.0)
		"river":
			for k in 3:
				var wv := PackedVector2Array()
				for i in 13:
					wv.append(Vector2(-0.45 + i * 0.075, 0.15 - k * 0.15 + sin(i * 0.9) * 0.04))
				for i in range(12, -1, -1):
					wv.append(Vector2(-0.45 + i * 0.075, 0.1 - k * 0.15 + sin(i * 0.9) * 0.04))
				Kit.felt_cutout(icon, wv, 0.04, Transform3D(), Kit.SKY.darkened(0.1 * k), 5.0)
		"cliff":
			var c2 := PackedVector2Array([Vector2(-0.45, -0.25), Vector2(0.45, -0.25), Vector2(0.45, 0.3), Vector2(0.1, 0.1), Vector2(-0.2, 0.0)])
			Kit.felt_cutout(icon, c2, 0.04, Transform3D(), Color(0.62, 0.42, 0.3), 5.0)
			for i in 3:
				Kit.felt_cutout(icon, Kit.rect(0.35, 0.03, -0.1 + i * 0.05, 0.2 + i * 0.08), 0.02, Transform3D(Basis(), Vector3(0, 0, 0.03)), Kit.CREAM, 5.0)
	cards.append({"id": id, "node": n, "x": x})

## a piece of a variant: everything under `pivot` flies in when the variant is chosen
func _piece(id: String, pos: Vector3) -> Node3D:
	if not variants.has(id):
		var vn := Node3D.new()
		vn.name = "Variant_" + id
		root.add_child(vn)
		variants[id] = {"node": vn, "pieces": []}
	var pv := Node3D.new()
	pv.position = pos
	(variants[id].node as Node3D).add_child(pv)
	(variants[id].pieces as Array).append([pv, pv.transform])
	return pv

func _set_variant(id: String, on: bool) -> void:
	for f in forces:
		if f[0] == id:
			(f[1] as Dictionary).on = on
	var v: Dictionary = variants[id]
	(v.node as Node3D).visible = on
	for cs in (v.node as Node3D).find_children("*", "CollisionShape3D", true, false):
		(cs as CollisionShape3D).set_deferred("disabled", not on)

func _build_castle() -> void:
	var tr := [[292.0, 6.0, 11.0], [300.25, 5.5, 12.5], [308.25, 5.5, 13.2]]
	for t in tr:
		var pv := _piece("castle", Vector3(t[0], 0.0, 0.0))
		Kit.block(pv, Vector3(0, -1.0, 0), Vector3(t[1], 3.0, 4.2), Color(0.55, 0.75, 0.85), Kit.CREAM, 1, true)
		Kit.block(pv, Vector3(0, 0.75, 0), Vector3(t[1] - 0.3, 0.5, 3.9), Kit.PINK, Kit.CREAM, 2, true)
		var bd: Dictionary = w.add_bounce(Vector3(float(t[0]), 1.0, 0.0), Vector3(float(t[1]) - 0.3, 0.5, 3.9), float(t[2]), null)
		forces.append(["castle", bd])
		for k in 4:
			w.spool(Vector3(float(t[0]) - 1.5 + k, 2.4 + k * 0.6, w.lane_z(k % 3)))
	var walls := [[296.25, 3.0], [303.75, 4.0], [311.75, 4.6]]
	for wl in walls:
		var pv := _piece("castle", Vector3(wl[0], 0.0, 0.0))
		var h: float = wl[1]
		Kit.block(pv, Vector3(0, h * 0.5, 0), Vector3(1.4, h, 4.2), Color(0.95, 0.72, 0.78), Kit.CREAM, 0, true)
		for k in 3:
			Kit.block(pv, Vector3(0, h + 0.25, -1.4 + k * 1.4), Vector3(1.4, 0.5, 0.8), Color(0.95, 0.72, 0.78), Kit.CREAM, 0, false)
		var flag := Kit.pin(pv, Vector3(0, h + 0.4, -1.6), Kit.TEAL)
		flag.scale = Vector3.ONE * 0.8
	var ex := _piece("castle", Vector3(315.5, 0.0, 0.0))
	Kit.block(ex, Vector3(0, 2.1, 0), Vector3(5.0, 4.2, 4.2), Kit.TEAL, Kit.CREAM, 1, true)
	for k in 5:
		w.spool(Vector3(313.6 + k * 0.9, 4.9, w.lane_z(1)))

func _build_river() -> void:
	var pv := _piece("river", Vector3((GAP0 + GAP1) * 0.5, -0.6, 0.0))
	river = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(GAP1 - GAP0 + 0.5, 4.6)
	pm.subdivide_width = 90
	pm.subdivide_depth = 12
	river.mesh = pm
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode cull_disabled;
uniform sampler2D weave : filter_linear_mipmap, repeat_enable;
varying vec3 lp;
void vertex() {
	lp = VERTEX;
	VERTEX.y += sin(VERTEX.x * 1.6 + TIME * 2.2) * 0.08 + sin(VERTEX.z * 2.4 + TIME * 1.5) * 0.05;
}
void fragment() {
	float s = 0.5 + 0.5 * sin((lp.x + TIME * 1.2) * 3.0 + sin(lp.z * 2.0));
	vec3 c = mix(vec3(0.3, 0.55, 0.85), vec3(0.55, 0.78, 0.95), s * 0.6);
	float stripe = step(0.85, fract((lp.x - TIME * 0.8) * 0.7 + lp.z * 0.2));
	c = mix(c, vec3(0.95, 0.97, 1.0), stripe * 0.5);
	c *= 0.9 + 0.12 * texture(weave, lp.xz * 1.5).b;
	ALBEDO = c;
	ROUGHNESS = 0.35;
	SPECULAR = 0.6;
}"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("weave", Kit.T_WEAVE)
	river.material_override = m
	pv.add_child(river)
	# felt leaves drifting on the ribbon, in all three layers
	var spec := [[290.5, 1, 1.4, 0.7, 0.0], [294.0, 0, 1.6, 0.8, 1.0], [297.5, 2, 1.2, 0.9, 2.0], [301.0, 1, 1.8, 0.6, 0.5],
		[304.5, 0, 1.5, 0.75, 1.7], [308.0, 2, 1.4, 0.85, 2.6], [311.5, 1, 1.6, 0.7, 0.9], [315.0, 0, 1.0, 0.6, 1.4]]
	for s in spec:
		var lpv := _piece("river", Vector3.ZERO)
		var body := AnimatableBody3D.new()
		body.position = Vector3(s[0], -0.35, w.lane_z(s[1]))
		lpv.add_child(body)
		var leaf := PackedVector2Array()
		for i in 24:
			var a := TAU * i / 24.0
			leaf.append(Vector2(cos(a) * 0.95, sin(a) * 0.55 * (1.0 - 0.3 * cos(a))))
		Kit.felt_cutout(body, leaf, 0.16, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0.08, 0)), Color(0.42, 0.68, 0.38), 3.0)
		Kit.felt_cutout(body, Kit.rect(1.6, 0.04), 0.02, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0.17, 0)), Color(0.3, 0.52, 0.3), 3.0)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new(); bs.size = Vector3(1.8, 0.3, 1.1)
		cs.shape = bs
		body.add_child(cs)
		leaves.append([body, body.position, s[2], s[3], s[4]])
		w.spool(Vector3(s[0], 1.0, w.lane_z(s[1])))

func _build_cliff() -> void:
	var steps := [[291.0, 1.0, 4.0], [295.5, 2.0, 3.0], [299.5, 3.2, 3.0], [303.8, 4.4, 3.4], [308.5, 5.4, 3.0]]
	for st in steps:
		var pv := _piece("cliff", Vector3(st[0], 0.0, 0.0))
		var h: float = st[1]
		Kit.block(pv, Vector3(0, h - 1.5, 0), Vector3(st[2], 3.0 + 0.0, 4.2), Color(0.66, 0.46, 0.32), Kit.GRASS, 4, true)
		Kit.block(pv, Vector3(0, (h - 3.0) * 0.5 - 1.5, 0), Vector3(float(st[2]) - 0.2, maxf(h, 0.1) + 0.01, 4.0), Color(0.6, 0.4, 0.28), Kit.CREAM, 0, false)
		w.spool(Vector3(float(st[0]), h + 0.8, w.lane_z(1)))
	# felt rocks to hide behind when the wind blows
	var rk := [[293.6, 1, 1.0], [297.6, 0, 2.0], [301.8, 2, 3.2], [306.2, 1, 4.4]]
	for r in rk:
		var pv := _piece("cliff", Vector3(r[0], r[2], w.lane_z(r[1])))
		Kit.bush(pv, Vector3(0, 0, 0), 0.55, Color(0.55, 0.52, 0.5), float(r[0]))
		Kit.block(pv, Vector3(0, 0.45, 0), Vector3(0.9, 0.9, 0.9), Color(0.55, 0.52, 0.5), Kit.CREAM, 0, true)
		rocks.append([r[0], r[1]])
	# the last chasm: a tailwind at the top carries a glide over it
	var top := _piece("cliff", Vector3(315.5, 0.0, 0.0))
	Kit.block(top, Vector3(0, 2.1, 0), Vector3(5.0, 4.2, 4.2), Color(0.66, 0.46, 0.32), Kit.GRASS, 4, true)
	var ud: Dictionary = w.add_updraft(Vector3(312.0, 5.5, 0.0), Vector3(3.0, 4.0, 4.0), 2.0)
	forces.append(["cliff", ud])
	gust_fx = GPUParticles3D.new()
	gust_fx.amount = 40
	gust_fx.lifetime = 1.2
	gust_fx.emitting = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(1.0, 3.0, 2.0)
	pm.direction = Vector3(-1, 0, 0)
	pm.spread = 6.0
	pm.initial_velocity_min = 12.0
	pm.initial_velocity_max = 16.0
	pm.gravity = Vector3.ZERO
	gust_fx.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.6, 0.03)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.albedo_color = Color(1, 1, 1, 0.5)
	q.material = qm
	gust_fx.draw_pass_1 = q
	gust_fx.visibility_aabb = AABB(Vector3(-30, -5, -5), Vector3(40, 15, 10))
	gust_fx.position = Vector3(318.0, 4.0, 0.0)
	root.add_child(gust_fx)

# ------------------------------------------------------------------ flow
func update(delta: float) -> void:
	var lp: Vector3 = w.claude_local()
	if chosen == "":
		var near := -1
		for i in cards.size():
			if absf(lp.x - float(cards[i].x)) < 0.9 and lp.y < 1.5 and lp.x > 276.0:
				near = i
		if near >= 0:
			w.prompt("E · choose this one")
			if Input.is_action_just_pressed("interact"):
				_choose(cards[near].id)
		elif lp.x > 276.0 and lp.x < 287.0:
			w.prompt("")
	if _build_t >= 0.0:
		_building(delta)
	for l in leaves:
		var body: AnimatableBody3D = l[0]
		var base: Vector3 = l[1]
		body.position = base + Vector3(sin(w.t * float(l[3]) + float(l[4])) * float(l[2]), sin(w.t * 2.0 + float(l[4])) * 0.05, 0)
	if chosen == "river" and lp.x > GAP0 and lp.x < GAP1 and lp.y < -0.45:
		w.hurt()
	if chosen == "cliff" and lp.x > GAP0 + 2.0 and lp.x < GAP1 - 3.0:
		_wind(delta, lp)

func _choose(id: String) -> void:
	chosen = id
	w.set("choice", id)
	w.prompt("")
	Sound.sfx(A + "chime.ogg", -3.0)
	for c in cards:
		var n: Node3D = c.node
		if c.id == id:
			var tw := n.create_tween()
			tw.tween_property(n, "position:y", 0.4, 0.2).set_trans(Tween.TRANS_BACK)
			tw.tween_property(n, "position:y", 0.0, 0.25)
		else:
			var tw2 := n.create_tween()
			tw2.tween_property(n, "rotation:x", -PI * 0.5, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_set_variant(id, true)
	outline.visible = false
	var pieces: Array = variants[id].pieces
	for p in pieces:
		var pv: Node3D = p[0]
		pv.position = (p[1] as Transform3D).origin + Vector3(randf_range(-2, 2), 14.0 + randf() * 6.0, randf_range(-3, 3))
		pv.rotation = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1))
	w.claude.control_enabled = false
	_build_t = 0.0
	_cut_from = (w.get("cam") as Camera3D).global_transform
	w.set("cam_mode", "custom")
	w.set("cam_custom", _cutscene_cam)
	w.narrate({"castle": "A bouncy castle. Of course. Hold on to your antenna.",
		"river": "A river made of ribbon. Hop the leaves, keep your feet dry.",
		"cliff": "A windy cliff. Hide behind the rocks when it gusts."}[id], 3.4)

func _building(delta: float) -> void:
	_build_t += delta
	var pieces: Array = variants[chosen].pieces
	var n := pieces.size()
	for i in n:
		var pv: Node3D = pieces[i][0]
		var final: Transform3D = pieces[i][1]
		var start := 0.6 + 2.6 * float(i) / maxf(n, 1)
		if _build_t > start:
			pv.position = pv.position.lerp(final.origin, 1.0 - exp(-9.0 * delta))
			pv.rotation = pv.rotation.lerp(Vector3.ZERO, 1.0 - exp(-9.0 * delta))
			if not pv.has_meta("landed") and pv.position.distance_to(final.origin) < 0.3:
				pv.set_meta("landed", true)
				pv.transform = final
				Sound.sfx(A + "thunk.ogg", -14.0, randf_range(1.2, 1.6))
				Sound.sfx(A + "click.ogg", -14.0, randf_range(1.5, 2.0))
	if _build_t > 4.6:
		for p in pieces:
			(p[0] as Node3D).transform = p[1]
		_build_t = -1.0
		w.claude.control_enabled = true
		w.set("cam_mode", "follow")
		w.narrate("See? That's how this whole world was made. One idea at a time.", 3.2)
		w.checkpoint(Vector3(286.4, 0.0, 0.0), 1, Kit.TEAL)

func _cutscene_cam(delta: float) -> Array:
	var k := smoothstep(0.0, 1.0, clampf(_build_t / 1.2, 0.0, 1.0))
	var back := smoothstep(3.8, 4.6, _build_t)
	var wide_pos: Vector3 = w.g(Vector3(296.0, 9.5, 15.0))
	var wide := Transform3D(Basis.looking_at(w.g(Vector3(303.0, 1.0, -1.0)) - wide_pos, Vector3.UP), wide_pos)
	var xf := _cut_from.interpolate_with(wide, k)
	xf = xf.interpolate_with(_cut_from, back)
	return [xf, 16.0]

func _wind(delta: float, lp: Vector3) -> void:
	_gust_t -= delta
	if _gust_t <= 0.0:
		_gust_on = not _gust_on
		_gust_t = 1.4 if _gust_on else 2.2
		gust_fx.emitting = _gust_on
		if _gust_on:
			Sound.sfx(A + "dive.ogg", -10.0, 1.3)
	if not _gust_on:
		return
	var lane: int = w.get("lane")
	for r in rocks:
		var rx: float = r[0]
		if int(r[1]) == lane and rx > lp.x and rx - lp.x < 1.6:
			return
	w.claude.velocity.x -= 9.0 * delta * (1.0 if w.claude.is_on_floor() else 1.6)
	w.claude.global_position.x -= 2.4 * delta

func skip_to(at: float) -> void:
	if at > 290.0 and chosen == "":
		chosen = "castle"
		w.set("choice", chosen)
		_set_variant(chosen, true)
		outline.visible = false
