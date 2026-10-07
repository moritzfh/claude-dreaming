## A kart in track space – used for Claude and for the seven rivals.
##
## State: s (metres along the track), x (metres to the right of the centre),
## h (height above the road), v (speed), psi (direction of travel relative to
## the road, + = to the right). Every frame the track's curvature turns the
## road under the kart, so you have to steer through the bends; the road's
## "up" is always the kart's up (loops, corkscrews, upside-down – all free).
##
## Drifting: hop (Space/Shift) while steering, keep holding – sparks turn
## blue, orange, pink; let go for a mini-turbo. Ramps: press hop/E in the air
## for a trick, it gives a boost on landing.
extends Node3D

const DIR := "res://levels/prism_boulevard/"
const KART_PAINT := preload("res://levels/prism_boulevard/shaders/kart_paint.gdshader")
const FLAME := preload("res://levels/prism_boulevard/shaders/flame.gdshader")
const SPARK := preload("res://levels/prism_boulevard/shaders/spark.gdshader")
const WING := preload("res://levels/prism_boulevard/shaders/wing.gdshader")
const FLAME_CONE := preload("res://levels/prism_boulevard/shaders/flame_cone.gdshader")

# tuning
const V_MAX := 31.0
const V_BIT := 0.28          # top speed per star bit (max 10)
const ACCEL := 17.0
const BRAKE := 28.0
const BOOST_MULT := 1.34
const HYPER_MULT := 1.55
const G := 34.0
const G_GLIDE := 3.2
const HALF_W := 0.72         # kart half width (for walls)
const WALL_T := 0.35
const MT_TIMES := [0.0, 0.7, 1.55, 2.6]
const MT_BOOST := [0.0, 0.5, 0.95, 1.5]
const MT_COLORS := [Color(1, 1, 1), Color(0.35, 0.75, 1.0), Color(1.0, 0.6, 0.15), Color(1.0, 0.35, 0.95)]

var tr                       # the track
var level                    # the level (sounds, effects, other karts)
var is_player := false
var racer_name := ""
var paint := Color(1, 0.5, 0.3)
var trim := Color(1, 1, 1)
var skill := 1.0             # AI: share of the top speed
var lane := 0.0              # AI: preferred offset from the racing line
var face_mood := 0

# --- state
var s := 0.0
var x := 0.0
var h := 0.0
var vh := 0.0
var v := 0.0
var psi := 0.0
var steer := 0.0
var air := false
var gliding := false
var drift_dir := 0
var drift_t := 0.0
var mt_level := 0
var hopping := false
var boost_t := 0.0
var boost_mult := 1.0
var trick_window := 0.0
var tricked := false
var trick_spin := 0.0
var bits := 0
var lap := 0                 # laps completed
var halfway := false         # passed the far side of the lap (no shortcuts)
var progress := 0.0
var finished := false
var finish_time := 0.0
var place := 1
var falling := false
var fall_t := 0.0
var world_pos := Vector3.ZERO
var world_vel := Vector3.ZERO
var safe_s := 0.0
var controls := false        # player input / AI driving on
var bump_cool := 0.0
var stun := 0.0
var last_pad := -1
var _prev_s := 0.0
var _ai_drift_cool := 0.0
var _land_squash := 0.0
var _lean := 0.0
var _vis_yaw := 0.0
var _wheel_rot := 0.0
var _t := 0.0
var _ai_wobble := 0.0
var _last_v := 0.0

# --- visuals
var body: Node3D             # tilts / squashes
var rig: RobotRig
var claude_node: Node3D      # the Player (for Claude) parked in the seat
var wheels: Array = []
var flames: Array = []
var cones: Array = []
var sparks: Array = []
var wings: Node3D
var trail: GPUParticles3D
var engine: Node             # AudioStreamPlayer(3D)
var drift_snd: AudioStreamPlayer

func setup(track, lvl, player: bool, name_: String, col: Color, trim_col: Color) -> void:
	tr = track
	level = lvl
	is_player = player
	racer_name = name_
	paint = col
	trim = trim_col
	_build_model()

# =================================================================== model
func _m(mesh: Mesh, col: Color, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE, parent: Node3D = null, metal := 0.3, rough := 0.35, emit := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := ShaderMaterial.new()
	m.shader = KART_PAINT
	m.set_shader_parameter("base", col)
	m.set_shader_parameter("metal", metal)
	m.set_shader_parameter("rough", rough)
	m.set_shader_parameter("emit", emit)
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	(parent if parent else body).add_child(mi)
	return mi

func _build_model() -> void:
	body = Node3D.new()
	body.name = "Body"
	add_child(body)
	var dark := Color(0.13, 0.1, 0.2)
	var silver := Color(0.86, 0.86, 0.95)
	# main pod
	var cap := CapsuleMesh.new(); cap.radius = 0.5; cap.height = 2.1; cap.radial_segments = 24; cap.rings = 8
	_m(cap, paint, Vector3(0, 0.42, 0.05), Vector3(PI * 0.5, 0, 0), Vector3(1.05, 0.62, 1.0), null, 0.35, 0.22)
	# nose, front bumper, headlights and a racing stripe
	var sph := SphereMesh.new(); sph.radius = 0.5; sph.height = 1.0; sph.radial_segments = 20; sph.rings = 10
	_m(sph, paint, Vector3(0, 0.38, -0.9), Vector3.ZERO, Vector3(0.9, 0.5, 0.6), null, 0.35, 0.22)
	var bumper := CapsuleMesh.new(); bumper.radius = 0.11; bumper.height = 1.5
	_m(bumper, dark, Vector3(0, 0.22, -1.18), Vector3(0, 0, PI * 0.5), Vector3.ONE, null, 0.5, 0.3)
	var lamp := SphereMesh.new(); lamp.radius = 0.09; lamp.height = 0.18
	for sd in [-1.0, 1.0]:
		_m(lamp, Color(1.0, 0.95, 0.8), Vector3(sd * 0.28, 0.45, -1.13), Vector3.ZERO, Vector3.ONE, null, 0.0, 0.2, 3.0)
	var stripe := BoxMesh.new(); stripe.size = Vector3(0.16, 0.04, 1.3)
	_m(stripe, trim, Vector3(0, 0.735, -0.45), Vector3(0.12, 0, 0), Vector3.ONE, null, 0.3, 0.3, 0.4)
	# side pods
	for sd in [-1.0, 1.0]:
		_m(cap, paint.lightened(0.12), Vector3(sd * 0.62, 0.33, 0.15), Vector3(PI * 0.5, 0, 0), Vector3(0.42, 0.34, 0.62), null, 0.35, 0.25)
	# seat back
	var box := BoxMesh.new(); box.size = Vector3(0.62, 0.5, 0.14)
	_m(box, dark, Vector3(0, 0.75, 0.62), Vector3(-0.25, 0, 0))
	# steering column + wheel
	var cyl := CylinderMesh.new(); cyl.top_radius = 0.03; cyl.bottom_radius = 0.03; cyl.height = 0.5
	_m(cyl, dark, Vector3(0, 0.62, -0.32), Vector3(-0.9, 0, 0))
	var tor := TorusMesh.new(); tor.inner_radius = 0.1; tor.outer_radius = 0.15; tor.rings = 16; tor.ring_segments = 6
	_m(tor, dark, Vector3(0, 0.82, -0.18), Vector3(PI * 0.5 - 0.6, 0, 0))
	# rear engine with two exhaust pipes
	_m(box, silver, Vector3(0, 0.55, 1.0), Vector3.ZERO, Vector3(1.4, 0.8, 2.2), null, 0.8, 0.2)
	var pipe := CylinderMesh.new(); pipe.top_radius = 0.1; pipe.bottom_radius = 0.13; pipe.height = 0.45; pipe.radial_segments = 12
	for sd in [-1.0, 1.0]:
		_m(pipe, silver, Vector3(sd * 0.26, 0.62, 1.22), Vector3(PI * 0.5, 0, 0), Vector3.ONE, null, 0.9, 0.15)
		var ring := TorusMesh.new(); ring.inner_radius = 0.085; ring.outer_radius = 0.125
		_m(ring, trim, Vector3(sd * 0.26, 0.62, 1.45), Vector3(PI * 0.5, 0, 0), Vector3.ONE, null, 0.2, 0.3, 2.5)
		var fl := _flame()
		fl.position = Vector3(sd * 0.26, 0.62, 1.5)
		body.add_child(fl)
		flames.append(fl)
		var cone := CylinderMesh.new(); cone.top_radius = 0.0; cone.bottom_radius = 0.13; cone.height = 1.0; cone.radial_segments = 10; cone.rings = 1
		var cm := MeshInstance3D.new()
		cm.mesh = cone
		var fm := ShaderMaterial.new(); fm.shader = FLAME_CONE
		cm.material_override = fm
		cm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cm.position = Vector3(sd * 0.26, 0.62, 1.95)
		cm.rotation = Vector3(PI * 0.5, 0, 0)      # the cone's tip points backwards
		body.add_child(cm)
		cones.append(cm)
	# spoiler
	var sp := BoxMesh.new(); sp.size = Vector3(1.5, 0.06, 0.38)
	_m(sp, paint, Vector3(0, 1.02, 1.12), Vector3(-0.12, 0, 0), Vector3.ONE, null, 0.4, 0.2)
	var stalk := BoxMesh.new(); stalk.size = Vector3(0.05, 0.36, 0.12)
	for sd in [-1.0, 1.0]:
		_m(stalk, dark, Vector3(sd * 0.45, 0.85, 1.12))
		_m(BoxMesh.new(), trim, Vector3(sd * 0.76, 1.02, 1.12), Vector3.ZERO, Vector3(0.05, 0.16, 0.42), null, 0.3, 0.3, 1.5)
	# wheels
	var tire := CylinderMesh.new(); tire.top_radius = 0.3; tire.bottom_radius = 0.3; tire.height = 0.28; tire.radial_segments = 18
	var hub := TorusMesh.new(); hub.inner_radius = 0.12; hub.outer_radius = 0.2; hub.rings = 18; hub.ring_segments = 6
	for wz in [-0.72, 0.78]:
		for sd in [-1.0, 1.0]:
			var w := Node3D.new()
			w.position = Vector3(sd * 0.74, 0.3, wz)
			body.add_child(w)
			var spin := Node3D.new()
			w.add_child(spin)
			_m(tire, dark, Vector3.ZERO, Vector3(0, 0, PI * 0.5), Vector3.ONE, spin, 0.0, 0.8)
			_m(hub, trim, Vector3(sd * 0.13, 0, 0), Vector3(0, 0, PI * 0.5), Vector3.ONE, spin, 0.2, 0.3, 2.2)
			# a spoke so the rolling shows
			_m(BoxMesh.new(), silver, Vector3(sd * 0.14, 0, 0), Vector3.ZERO, Vector3(0.02, 0.36, 0.06), spin, 0.8, 0.2)
			wheels.append([w, spin, wz < 0.0])
	# number / star decal on the nose: a small emissive star
	var star := _star_mesh(0.16, 0.07, 0.03)
	_m(star, trim, Vector3(0, 0.56, -1.02), Vector3(-0.7, 0, 0), Vector3.ONE, null, 0.2, 0.3, 1.8)
	# glider wings (folded away until a glide)
	wings = Node3D.new()
	wings.position = Vector3(0, 0.95, 0.35)
	wings.scale = Vector3(0.01, 0.01, 0.01)
	wings.visible = false
	body.add_child(wings)
	for sd in [-1.0, 1.0]:
		var wm := MeshInstance3D.new()
		wm.mesh = _wing_mesh(sd)
		var wmat := ShaderMaterial.new()
		wmat.shader = WING
		wmat.set_shader_parameter("tint", paint.lightened(0.35))
		wm.material_override = wmat
		wm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		wings.add_child(wm)
	# drift sparks at the rear wheels
	for sd in [-1.0, 1.0]:
		var sp2 := _sparks()
		sp2.position = Vector3(sd * 0.74, 0.08, 0.95)
		body.add_child(sp2)
		sparks.append(sp2)
	# the driver: a robot of its own for the rivals (Claude's is parked in later)
	if not is_player:
		rig = RobotRig.new()
		rig.name = "Driver"
		body.add_child(rig)
		rig.position = Vector3(0, 0.34, 0.2)
		rig.scale = Vector3.ONE * 0.95

## park Claude (the Player node) in the seat
func seat_claude(c: Node3D, r: RobotRig) -> void:
	claude_node = c
	rig = r

func _star_mesh(r_out: float, r_in: float, depth: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array = []
	for i in 10:
		var a := -PI * 0.5 + TAU * i / 10.0
		var r := r_out if i % 2 == 0 else r_in
		pts.append(Vector3(cos(a) * r, -sin(a) * r, 0))
	for i in 10:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[(i + 1) % 10]
		st.set_normal(Vector3(0, 0, -1)); st.add_vertex(Vector3(0, 0, -depth))
		st.set_normal(Vector3(0, 0, -1)); st.add_vertex(b)
		st.set_normal(Vector3(0, 0, -1)); st.add_vertex(a)
	return st.commit()

func _wing_mesh(sd: float) -> ArrayMesh:
	# a swept, star-tipped sail, double sided via the material
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var root_f := Vector3(sd * 0.2, 0, -0.35)
	var root_b := Vector3(sd * 0.2, 0, 0.45)
	var tip_f := Vector3(sd * 2.1, 0.25, 0.25)
	var tip_b := Vector3(sd * 1.9, 0.22, 0.75)
	var mid := Vector3(sd * 1.2, 0.05, 0.85)
	var tris := [[root_f, tip_f, root_b], [root_b, tip_f, tip_b], [root_b, tip_b, mid]]
	for t in tris:
		for p in t:
			st.set_uv(Vector2(absf(p.x) / 2.1, p.z))
			st.set_normal(Vector3.UP)
			st.add_vertex(p)
	return st.commit()

func _flame() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 24
	p.lifetime = 0.22
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-8, -8, -8), Vector3(16, 16, 16))
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0, 1)
	pm.spread = 8.0
	pm.initial_velocity_min = 3.0
	pm.initial_velocity_max = 6.0
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.5
	pm.scale_max = 0.9
	var sc := Curve.new(); sc.add_point(Vector2(0, 1)); sc.add_point(Vector2(1, 0.1))
	var sct := CurveTexture.new(); sct.curve = sc
	pm.scale_curve = sct
	p.process_material = pm
	var q := QuadMesh.new(); q.size = Vector2(0.38, 0.38)
	var m := ShaderMaterial.new(); m.shader = FLAME
	q.material = m
	p.draw_pass_1 = q
	return p

func _sparks() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 40
	p.lifetime = 0.35
	p.local_coords = false
	p.emitting = false
	p.visibility_aabb = AABB(Vector3(-8, -8, -8), Vector3(16, 16, 16))
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 1)
	pm.spread = 40.0
	pm.initial_velocity_min = 2.5
	pm.initial_velocity_max = 5.0
	pm.gravity = Vector3(0, -14, 0)
	pm.scale_min = 0.4
	pm.scale_max = 1.0
	p.process_material = pm
	var q := QuadMesh.new(); q.size = Vector2(0.16, 0.16)
	var m := ShaderMaterial.new(); m.shader = SPARK
	q.material = m
	p.draw_pass_1 = q
	return p

# =================================================================== driving
func vmax() -> float:
	var b := V_MAX + V_BIT * float(bits)
	if not is_player: b = V_MAX * skill * level.rubber_band(self)
	return b

## inp: {steer, brake, hop_pressed, hop_held, trick}
func step(dt: float, inp: Dictionary) -> void:
	_t += dt
	bump_cool -= dt
	stun = maxf(stun - dt, 0.0)
	if falling:
		_fall_step(dt)
		return
	var w: float = tr.width(s)
	var kgv: float = tr.kg(s)
	var knv: float = tr.kn(s)
	var surf: int = tr.surf(s)
	var vm := vmax()
	# --- speed
	var target := vm
	var acc := ACCEL * clampf(1.15 - v / maxf(vm, 1.0), 0.15, 1.0) + 2.0
	if tr.is_hyper(s):
		boost_t = maxf(boost_t, 0.35)
		boost_mult = maxf(boost_mult, HYPER_MULT)
	if boost_t > 0.0:
		boost_t -= dt
		target = vm * boost_mult
		acc = 46.0
		if boost_t <= 0.0: boost_mult = 1.0
	if surf == tr.RIVER and not air: target += 2.5
	var braking: bool = inp.get("brake", false)
	if not controls:
		target = 0.0 if not finished else vm * 0.55
		braking = false
	if stun > 0.0: target *= 0.4
	if braking:
		v = move_toward(v, -7.0, BRAKE * dt)
	elif v < target:
		v = minf(v + acc * dt, target)
	else:
		v = move_toward(v, target, (9.0 if not air else 2.0) * dt)
	# --- steering
	var st_in: float = clampf(inp.get("steer", 0.0), -1.0, 1.0)
	steer = move_toward(steer, st_in, dt * 7.0)
	var om_max := lerpf(2.3, 1.35, clampf(absf(v) / V_MAX, 0.0, 1.0)) * clampf(absf(v) / 4.0, 0.0, 1.0)
	var omega := steer * om_max
	if drift_dir != 0:
		omega = float(drift_dir) * om_max * lerpf(0.42, 1.3, (steer * drift_dir + 1.0) * 0.5)
	if air and not gliding: omega *= 0.35
	if v < 0.0: omega = -omega
	# --- drift & hop
	var hop_p: bool = inp.get("hop_pressed", false)
	var hop_h: bool = inp.get("hop_held", false)
	if controls and hop_p:
		if air and trick_window > 0.0 and not tricked:
			_trick()
		elif not air and v > 7.0:
			vh = 4.4
			air = true
			hopping = true
			if is_player: level.sfx("hop", -8.0, 1.0, 0.05)
	if hopping and drift_dir == 0 and absf(st_in) > 0.25:
		drift_dir = int(signf(st_in))
	if drift_dir != 0:
		if not hop_h or v < 9.0 or not controls:
			_end_drift()
		elif not air:
			drift_t += dt * (1.0 + 0.7 * maxf(0.0, steer * drift_dir))
			var lvl := 0
			for k in range(1, 4):
				if drift_t >= MT_TIMES[k]: lvl = k
			if lvl != mt_level:
				mt_level = lvl
				if is_player and lvl > 0: level.sfx("mt_%d" % lvl, -6.0)
	# --- move in track space
	var denom := maxf(1.0 - kgv * x, 0.2)
	var ds := v * cos(psi) / denom * dt
	var dx := v * sin(psi) * dt
	psi += omega * dt - kgv * ds
	psi = wrapf(psi, -PI, PI)
	# without a drift the kart straightens out a little on its own (arcade grip)
	if drift_dir == 0 and absf(st_in) < 0.05 and not air:
		psi = move_toward(psi, 0.0, dt * 0.12 * absf(psi))
	_prev_s = s
	s = tr.wrap_s(s + ds)
	x += dx
	_progress(ds)
	# --- walls / edges
	var inner := w * 0.5 - WALL_T - HALF_W
	var side := 1 if x > 0.0 else -1
	if absf(x) > inner and tr.rail(s, side):
		x = float(side) * inner
		if signf(sin(psi)) == float(side):
			var impact := absf(sin(psi)) * absf(v)
			psi = -psi * 0.35
			v *= 1.0 - 0.3 * clampf(impact / 12.0, 0.0, 1.0)
			if impact > 3.0 and bump_cool <= 0.0:
				bump_cool = 0.25
				level.wall_hit(self, impact)
	elif absf(x) > w * 0.5 + 0.35 and not air:
		_start_fall()
		return
	# --- height: kicks, jumps, gliding, landing
	trick_window = maxf(trick_window - dt, 0.0)
	for k in tr.kicks:
		var ks: float = k["s"]
		if _crossed(ks) and not air and v > 8.0:
			var pw: float = k["power"] * clampf(v / V_MAX, 0.55, 1.15)
			vh = pw
			air = true
			hopping = false
			trick_window = 0.5
			tricked = false
			if k["glide"]:
				gliding = true
				_open_wings(true)
				if is_player: level.sfx("glider", -4.0)
			elif is_player:
				level.sfx("ramp", -6.0)
	if air:
		var vs := v * cos(psi)
		if gliding:
			vh -= G_GLIDE * dt          # a glide ignores the curve of the flight path
		else:
			vh += (-G - vs * vs * knv) * dt
		if gliding:
			vh = maxf(vh, -5.5)
			if is_player and controls:
				# forward = dive (faster), back = hold the height
				var pitch_in := Input.get_axis("move_forward", "move_back")
				if pitch_in < -0.2:
					vh -= 7.0 * dt
					v += 5.0 * dt
				elif pitch_in > 0.2:
					vh = maxf(vh, -2.2)
		h += vh * dt
		if h <= 0.0:
			if surf == tr.GAP:
				if h < -7.0:
					_start_fall()
					return
			else:
				_land()
	else:
		# crest: fast enough to fly off the top?
		var vs2 := v * cos(psi)
		if -G - vs2 * vs2 * knv > 0.0:
			air = true
			vh = 0.0
		h = 0.0
		vh = 0.0
		if surf != tr.GAP and absf(x) < w * 0.5 - 1.0: safe_s = s
	# --- boost pads
	if not air:
		for i in tr.pads.size():
			var pd: Dictionary = tr.pads[i]
			var dsp: float = absf(wrapf(s - float(pd["s"]), -tr.length * 0.5, tr.length * 0.5))
			if dsp < 2.2 and absf(x - float(pd["x"])) < 2.1:
				if last_pad != i:
					last_pad = i
					boost(1.0, BOOST_MULT)
					if is_player: level.sfx("pad", -3.0)
			elif last_pad == i and dsp > 6.0:
				last_pad = -1
	# --- glide rings
	if gliding:
		for rg in tr.rings:
			if _crossed(float(rg["s"])) and Vector2(x - float(rg["x"]), h - float(rg["h"])).length() < 3.0:
				boost(0.7, BOOST_MULT)
				if is_player: level.sfx("ring", -3.0)
				level.ring_passed(self, rg)
	trick_spin = maxf(trick_spin - dt * 2.4, 0.0)
	_place_visual(dt)

func _crossed(ks: float) -> bool:
	var a := _prev_s
	var b := s
	if b < a - tr.length * 0.5: b += tr.length          # wrapped forward
	return a < ks and b >= ks

func _progress(ds: float) -> void:
	# laps: the line is at s = 0; "halfway" has to be passed first
	var L: float = tr.length
	if _prev_s > L * 0.45 and _prev_s < L * 0.6 and s >= L * 0.6: halfway = true
	if ds > 0.0 and _prev_s > L * 0.8 and s < L * 0.2:
		if halfway:
			lap += 1
			halfway = false
			level.lap_done(self)
	elif ds < 0.0 and _prev_s < L * 0.2 and s > L * 0.8:
		pass   # driving backwards over the line doesn't count
	progress = lap * L + s

func boost(t: float, mult: float) -> void:
	boost_t = maxf(boost_t, t)
	boost_mult = maxf(boost_mult if boost_t > 0.0 else 1.0, mult)
	if is_player: level.boost_fx(t)

func _trick() -> void:
	tricked = true
	trick_spin = 1.0
	if is_player:
		level.sfx("trick", -4.0, randf_range(0.95, 1.1))
		level.trick_fx()

func _end_drift() -> void:
	if mt_level > 0 and controls:
		boost(MT_BOOST[mt_level], BOOST_MULT)
		if is_player: level.sfx("turbo", -2.0, 0.9 + 0.1 * mt_level)
	drift_dir = 0
	drift_t = 0.0
	mt_level = 0

func _land() -> void:
	var hard := -vh
	h = 0.0
	vh = 0.0
	air = false
	hopping = false
	if gliding:
		gliding = false
		_open_wings(false)
	if tricked:
		tricked = false
		boost(0.85, BOOST_MULT)
	if hard > 6.0:
		_land_squash = clampf(hard / 20.0, 0.1, 0.5)
		if is_player: level.sfx("land", -6.0 + clampf(hard * 0.3, 0.0, 6.0))

func _start_fall() -> void:
	falling = true
	fall_t = 0.0
	_end_drift()
	gliding = false
	_open_wings(false)
	var fr: Transform3D = tr.frame(s)
	world_pos = global_position
	var fwd: Vector3 = -fr.basis.z.rotated(fr.basis.y, -psi)
	world_vel = fwd * v + fr.basis.y * vh
	if is_player: level.sfx("fall", -4.0)

func _fall_step(dt: float) -> void:
	fall_t += dt
	world_vel += Vector3(0, -30.0, 0) * dt
	world_pos += world_vel * dt
	global_position = world_pos
	body.rotation.x += dt * 1.5
	if fall_t > 1.5:
		rescue()

## back on the road (after falling off or pressing R)
func rescue() -> void:
	falling = false
	s = tr.wrap_s(safe_s - 4.0)
	_prev_s = s
	x = clampf(x, -tr.width(s) * 0.25, tr.width(s) * 0.25)
	h = 3.0
	vh = 0.0
	air = true
	v = 0.0
	psi = 0.0
	boost_t = 0.0
	stun = 0.6
	body.rotation = Vector3.ZERO
	bits = maxi(bits - 3, 0)
	level.rescued(self)
	_place_visual(0.016)

func _open_wings(on: bool) -> void:
	if wings == null: return
	var tw := create_tween()
	if on:
		wings.visible = true
		tw.tween_property(wings, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		tw.tween_property(wings, "scale", Vector3.ONE * 0.01, 0.25)
		tw.tween_callback(func(): wings.visible = false)

# =================================================================== AI
func ai_input(dt: float, others: Array) -> Dictionary:
	_ai_wobble += dt
	var la := clampf(absf(v) * 0.55, 7.0, 20.0)
	var w: float = tr.width(s)
	var xt: float = tr.line(s + la) + lane + sin(_ai_wobble * 0.37 + lane) * 1.2
	# keep away from karts right ahead
	for o in others:
		if o == self: continue
		var d: float = wrapf(o.s - s, -tr.length * 0.5, tr.length * 0.5)
		if d > 0.0 and d < 14.0 and absf(o.x - xt) < 2.2:
			xt += 2.6 if o.x < x else -2.6
	var lim := w * 0.5 - 2.0
	xt = clampf(xt, -lim, lim)
	var psi_d := atan2(xt - x, la)
	var kgv: float = tr.kg(s)
	var ff := kgv * v       # follow the curve
	var om_max := lerpf(2.3, 1.35, clampf(absf(v) / V_MAX, 0.0, 1.0))
	var om_want := (psi_d - psi) * 3.2 + ff
	var st := clampf(om_want / om_max, -1.0, 1.0)
	# fake drifts in long bends (a mini-turbo on the way out)
	_ai_drift_cool -= dt
	var bend: float = absf(tr.kg(s + 15.0))
	var inp := {"steer": st, "brake": false, "hop_pressed": false, "hop_held": false}
	if drift_dir == 0 and bend > 0.012 and _ai_drift_cool <= 0.0 and v > 20.0 and not air and randf() < dt * 2.0:
		inp["hop_pressed"] = true
		inp["hop_held"] = true
		_ai_drift_cool = 2.5
		drift_dir = int(signf(tr.kg(s + 15.0)))
	elif drift_dir != 0:
		inp["hop_held"] = bend > 0.006 or drift_t < 0.8
		# while drifting the turn rate is om_max * lerp(0.42, 1.3, (steer*dir+1)/2)
		var k := om_want / (float(drift_dir) * om_max)
		inp["steer"] = clampf(2.0 * (k - 0.42) / 0.88 - 1.0, -1.0, 1.0) * float(drift_dir)
	# tricks on ramps
	if air and trick_window > 0.0 and trick_window < 0.35 and not tricked and randf() < 0.5:
		inp["hop_pressed"] = true
	return inp

# =================================================================== visuals
func _place_visual(dt: float) -> void:
	var fr: Transform3D = tr.frame(s)
	var up := fr.basis.y
	var pos := fr.origin + fr.basis.x * x + up * h
	# the kart faces its direction of travel, a drift turns the nose inwards
	var drift_yaw := -float(drift_dir) * 0.42 if drift_dir != 0 else 0.0
	_vis_yaw = lerp_angle(_vis_yaw, -psi + drift_yaw, 1.0 - exp(-12.0 * dt))
	var b := fr.basis * Basis(Vector3.UP, _vis_yaw)
	global_transform = Transform3D(b, pos)
	world_pos = pos
	# body: lean into turns, pitch in the air, squash on landing, trick spin
	_lean = lerpf(_lean, -steer * 0.09 * clampf(v / 20.0, 0.0, 1.0) + float(drift_dir) * 0.1, 1.0 - exp(-8.0 * dt))
	_land_squash = maxf(_land_squash - dt * 2.5, 0.0)
	var pitch := clampf(vh * 0.02, -0.25, 0.3) if air else 0.0
	var spin := TAU * (1.0 - pow(1.0 - (1.0 - trick_spin), 2.0)) if trick_spin > 0.0 else 0.0
	var bob := sin(_t * 30.0) * 0.012 * clampf(v / V_MAX, 0.0, 1.0) if not air else 0.0
	body.rotation = Vector3(pitch, spin, _lean)
	body.position = Vector3(0, bob - _land_squash * 0.1, 0)
	body.scale = Vector3(1.0 + _land_squash * 0.3, 1.0 - _land_squash * 0.5, 1.0 + _land_squash * 0.2)
	# wheels: roll, front ones steer
	_wheel_rot += v * dt / 0.3
	for wd in wheels:
		var wn: Node3D = wd[0]
		var sp: Node3D = wd[1]
		sp.rotation.x = -_wheel_rot
		if wd[2]: wn.rotation.y = -steer * 0.4
	# flames: bigger and pinker with a boost
	var boosting := boost_t > 0.0
	for f in flames:
		var fm := (f as GPUParticles3D).draw_pass_1.surface_get_material(0) as ShaderMaterial
		fm.set_shader_parameter("hot", 1.0 if boosting else 0.0)
		f.amount_ratio = 1.0 if boosting else clampf(0.25 + v / V_MAX * 0.4, 0.2, 0.7)
		(f as GPUParticles3D).speed_scale = 1.6 if boosting else 1.0
	var pw := clampf(v / V_MAX, 0.0, 1.3)
	for c in cones:
		var cm := c as MeshInstance3D
		var len := (1.6 if boosting else 0.45 + pw * 0.5) * (0.9 + 0.1 * sin(_t * 37.0))
		cm.scale = Vector3(1.0 + (0.5 if boosting else 0.0), len, 1.0 + (0.5 if boosting else 0.0))
		cm.position.z = 1.45 + len * 0.5
		var m := cm.material_override as ShaderMaterial
		m.set_shader_parameter("hot", 1.0 if boosting else 0.0)
		m.set_shader_parameter("power", pw)
	# drift sparks
	for spk in sparks:
		var p := spk as GPUParticles3D
		p.emitting = drift_dir != 0 and not air and mt_level > 0
		if p.emitting:
			var m := p.draw_pass_1.surface_get_material(0) as ShaderMaterial
			m.set_shader_parameter("color", MT_COLORS[mt_level])
	# the driver
	if rig:
		rig.animate(dt, Vector3.ZERO, true)
		_sit_pose()
		# the antenna wobbles with the kart's moves
		var acc := (v - _last_v) / maxf(dt, 0.001)
		_last_v = v
		rig._ant_v += Vector2(clampf(-acc * 0.012, -0.8, 0.8), steer * 0.25 * clampf(v / 15.0, 0.0, 1.0)) * dt * 20.0
		if air: rig._ant_v += Vector2(-vh * 0.02, 0) * dt * 20.0
		rig.mood = (RobotRig.Mood.DETERMINED if boost_t > 0.0 else (RobotRig.Mood.SPARKLE if gliding or trick_spin > 0.0 else face_mood))
	if claude_node:
		claude_node.global_transform = body.global_transform * Transform3D(Basis(), Vector3(0, 0.34, 0.2))

func _sit_pose() -> void:
	var sw := steer * 0.25
	rig._pose(rig.leg_l, Vector3(1.45, 0, 0.08))
	rig._pose(rig.leg_r, Vector3(1.45, 0, -0.08))
	rig._pose(rig.arm_l, Vector3(1.15 + sw, 0, 0.18))
	rig._pose(rig.arm_r, Vector3(1.15 - sw, 0, -0.18))
	rig._pose(rig.body, Vector3(-0.05, 0, -steer * 0.12))
	rig.head_extra = Vector3(0.05, -steer * 0.35, 0)
