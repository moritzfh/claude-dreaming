## The felt meadow: first jumps, a pit, the hedge that teaches the three
## layers, a kitchen sponge to bounce on, bobbing buttons over a gap, and the
## first keepsake (a level drawn on paper) high up in the back layer.
extends RefCounted

const Kit := preload("res://levels/plush_desk/story/kit.gd")
const A := "res://levels/plush_desk/audio/"

var w: Node3D
var root: Node3D
var stones: Array = []        # bobbing buttons [body, base]
var keep: Node3D
var keep_pos := Vector3()
var _got := false

func _ground(x0: float, x1: float, top: float, pattern := 4, col := Kit.SOIL, col2 := Kit.GRASS) -> void:
	var h := 3.0
	Kit.block(root, Vector3((x0 + x1) * 0.5, top - h * 0.5, 0.0), Vector3(x1 - x0, h, 4.2), col, col2, pattern, true)
	Kit.trim(root, x0 + 0.05, x1 - 0.05, top, 2.2, col2.darkened(0.12), "pinking")
	Kit.dress_front(root, x0, x1, top, 2.19, [col.darkened(0.12), col.lightened(0.1), Kit.MUSTARD.darkened(0.1), col2.darkened(0.2)], x0)

func build() -> void:
	root = Node3D.new()
	root.name = "Meadow"
	w.add_child(root)
	var M: float = w.lane_z(1)
	var B: float = w.lane_z(2)
	var F: float = w.lane_z(0)
	# --- ground with a few steps and a pit
	_ground(11.0, 25.5, 0.0)
	Kit.block(root, Vector3(20.6, 0.45, 0.0), Vector3(1.8, 0.9, 3.9), Kit.MUSTARD, Kit.CREAM, 2, true)
	Kit.block(root, Vector3(22.6, 0.9, 0.0), Vector3(1.8, 1.8, 3.9), Kit.CORAL, Kit.CREAM, 1, true)
	for i in 6:
		w.spool(Vector3(12.0 + i * 1.0, 0.75 + 0.25 * sin(i * 0.9), M))
	w.spool_arc(Vector3(20.6, 1.5, M), Vector3(22.6, 2.4, M), 3, 0.4)
	w.spool_arc(Vector3(24.2, 2.2, M), Vector3(29.6, 0.8, M), 6, 1.0)
	w.narrate_at(19.0, "Left, right, up. You know the basics. The rest, you'll make up as you go.", 3.4)
	_ground(28.5, 44.0, 0.0)
	w.checkpoint(Vector3(30.0, 0.0, 0.0), 1, Kit.CORAL)
	w.section_sign(Vector3(12.6, 0.0, -1.6), "FELT MEADOW", Kit.GRASS.darkened(0.25))
	# --- the hedge: front and middle layers are blocked, the back one is free
	Kit.block(root, Vector3(36.0, 1.3, 0.62), Vector3(5.6, 2.6, 2.5), Color(0.3, 0.52, 0.32), Kit.GRASS, 0, true)
	# the hedge's face: rows of round felt bushes, lighter at the top
	for row in 3:
		for i in 7:
			var bx := 33.5 + i * 0.85 + (0.4 if row % 2 == 1 else 0.0)
			if bx > 38.6:
				continue
			var col := Color(0.32, 0.56, 0.34).lightened(0.07 * row + 0.03 * (i % 2))
			Kit.bush(root, Vector3(bx, -0.2 + row * 0.95, 1.95 + row * 0.04), 0.62 + 0.1 * sin(i * 1.7 + row), col, i * 1.3 + row)
	for i in 4:
		Kit.flower(root, Vector3(33.9 + i * 1.5, 2.55, 0.9), 0.4, [Kit.PINK, Kit.MUSTARD, Kit.CREAM, Kit.LILAC][i])
	w.key_sign(Vector3(31.4, 0.0, B - 0.65), KEY_W, "")
	w.key_sign(Vector3(40.4, 0.0, B - 0.65), KEY_S, "")
	w.narrate_at(31.0, "A hedge. The world is deeper than it looks: W steps back, S steps forward.", 3.6)
	for i in 5:
		w.spool(Vector3(34.0 + i * 1.0, 0.75, B))
	# --- the sponge
	_ground(44.0, 61.0, 0.0, 4, Kit.SOIL, Kit.GRASS.lightened(0.08))
	var sp := Kit.block(root, Vector3(0.0, 0.3, 0.0), Vector3(2.2, 0.6, 3.9), Color(0.98, 0.84, 0.32), Kit.CREAM, 6, false)
	var sp_node := Node3D.new()
	sp_node.position = Vector3(45.6, 0.0, 0.0)
	root.add_child(sp_node)
	sp.reparent(sp_node, false)
	# green scouring layer on the bottom, like a real kitchen sponge
	Kit.block(sp_node, Vector3(0.0, 0.08, 0.0), Vector3(2.25, 0.16, 3.95), Color(0.3, 0.55, 0.32), Kit.CREAM, 6, false)
	var spb := StaticBody3D.new()
	var spc := CollisionShape3D.new()
	var spbs := BoxShape3D.new(); spbs.size = Vector3(2.2, 0.6, 3.9)
	spc.shape = spbs
	spb.position = Vector3(45.6, 0.3, 0.0)
	spb.add_child(spc)
	root.add_child(spb)
	w.add_bounce(Vector3(45.6, 0.6, 0.0), Vector3(2.2, 0.6, 3.9), 12.5, sp_node)
	w.narrate_at(43.0, "Sponges. Wonderfully bouncy. Terribly hard to clean.", 3.0)
	# the high ledge it throws you onto (flower print cotton)
	Kit.block(root, Vector3(52.0, 3.0, 0.0), Vector3(8.0, 0.8, 3.9), Kit.PINK, Kit.CREAM, 5, true)
	for i in 6:
		w.spool(Vector3(48.6 + i * 1.1, 4.15, M))
	for i in 5:
		w.spool(Vector3(45.6, 2.0 + i * 0.7, M))
	# --- keepsake 1, high up in the back: a small sponge on the ledge throws you there
	var sp2_node := Node3D.new()
	sp2_node.position = Vector3(55.2, 2.95, B)
	root.add_child(sp2_node)
	Kit.block(sp2_node, Vector3(0.0, 0.25, 0.0), Vector3(1.2, 0.5, 1.2), Color(0.98, 0.84, 0.32), Kit.CREAM, 6, false)
	var sb2 := StaticBody3D.new()
	var sc2 := CollisionShape3D.new()
	var sbs2 := BoxShape3D.new(); sbs2.size = Vector3(1.2, 0.5, 1.2)
	sc2.shape = sbs2
	sb2.position = Vector3(55.2, 3.2, B)
	sb2.add_child(sc2)
	root.add_child(sb2)
	w.add_bounce(Vector3(55.2, 3.45, B), Vector3(1.3, 0.5, 1.2), 11.5, sp2_node)
	Kit.block(root, Vector3(58.4, 6.4, B), Vector3(3.2, 0.5, 1.2), Kit.LILAC, Kit.CREAM, 2, true)
	keep_pos = Vector3(59.2, 7.4, B)
	keep = _paper_keepsake(keep_pos)
	# --- bobbing buttons over a gap
	for i in 4:
		var x := 62.6 + i * 2.5
		var body := AnimatableBody3D.new()
		body.position = Vector3(x, -0.1, M)
		root.add_child(body)
		var cols := [Kit.MUSTARD, Kit.TEAL, Kit.CORAL, Kit.LILAC]
		Kit.button(body, Vector3.ZERO, 0.85, cols[i], i * 0.7, false)
		var cs := CollisionShape3D.new()
		var cy := CylinderShape3D.new(); cy.radius = 0.85; cy.height = 0.26
		cs.shape = cy
		cs.position.y = 0.13
		body.add_child(cs)
		stones.append([body, body.position, i * 1.3])
		w.spool(Vector3(x, 1.3, M))
	_ground(72.4, 80.0, 0.0)
	w.checkpoint(Vector3(74.0, 0.0, 0.0), 1, Kit.TEAL)
	# --- dressing: flowers along the front edge, bushes in the back
	var cols2 := [Kit.PINK, Kit.MUSTARD, Kit.LILAC, Kit.CORAL, Color(0.95, 0.95, 0.9)]
	var x2 := 11.5
	var k := 0
	while x2 < 80.0:
		if not (x2 > 25.5 and x2 < 28.5) and not (x2 > 61.0 and x2 < 72.4):
			Kit.flower(root, Vector3(x2, 0.0, 2.05), 0.38 + 0.12 * (k % 3), cols2[k % cols2.size()])
			if k % 3 == 0:
				Kit.bush(root, Vector3(x2 + 0.6, 0.0, -2.05), 0.55 + 0.2 * (k % 2), Color(0.42, 0.66, 0.4), k)
		x2 += 1.3 + 0.7 * absf(sin(k * 1.9))
		k += 1

func _paper_keepsake(p: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = p
	root.add_child(n)
	# a folded sheet of paper with a pencil drawing of a level on it
	var a := Kit.cutout(n, Kit.rect(0.7, 0.9), 0.02, Transform3D(Basis(Vector3.UP, 0.35), Vector3(-0.17, 0, 0)), Color(0.98, 0.97, 0.94, 1.0))
	var b := Kit.cutout(n, Kit.rect(0.7, 0.9), 0.02, Transform3D(Basis(Vector3.UP, -0.35), Vector3(0.17, 0, 0.12)), Color(0.98, 0.97, 0.94, 1.0))
	var pencil := Color(0.25, 0.25, 0.3)
	for seg in [[Vector3(-0.42, -0.25, 0.03), Vector3(0.35, 0.02, 0.0)], [Vector3(-0.3, 0.05, 0.05), Vector3(0.25, 0.02, 0.0)], [Vector3(0.05, 0.25, 0.14), Vector3(0.3, 0.02, 0.0)]]:
		Kit.block(n, seg[0], seg[1] + Vector3(0, 0, 0.02), pencil, Kit.CREAM, 0, false)
	var star := Kit.label(n, "★", Vector3(0.2, -0.1, 0.16), 0.006, Color(0.86, 0.45, 0.38), 64)
	star.no_depth_test = false
	a.set_meta("x", 0)
	b.set_meta("x", 0)
	return n

func update(delta: float) -> void:
	for s in stones:
		var body: AnimatableBody3D = s[0]
		var base: Vector3 = s[1]
		var ph: float = s[2]
		body.position = base + Vector3(0, sin(w.t * 1.6 + ph) * 0.45, 0)
	if keep and not _got:
		keep.rotation.y = sin(w.t * 1.3) * 0.4
		keep.position.y = keep_pos.y + sin(w.t * 2.0) * 0.1
		var lp: Vector3 = w.claude_local()
		if lp.distance_to(keep_pos - Vector3(0, 0.6, 0)) < 1.1:
			_got = true
			w.got_keepsake(0)
			w.narrate("A level, drawn on paper. Somebody drew this for a friend. Keep it safe.", 3.4)
			var tw := keep.create_tween()
			tw.tween_property(keep, "scale", Vector3.ZERO, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
