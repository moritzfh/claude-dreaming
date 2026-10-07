## Height function for the whole valley + mesh/collision generation.
## Layout (Godot axes, -Z = towards the sunset):
##   garden plateau y=30 around the origin, edge at z≈-56
##   valley floor y≈2 below, lake around (15,-255), rivers
##   terraced city hill on the right (x>110)
class_name Terrain
extends RefCounted

const PLATEAU_Y := 20.0
const WATER_Y := 0.4
const NEAR_MIN := Vector2(-340.0, -650.0)
const NEAR_MAX := Vector2(460.0, 210.0)
const NEAR_STEP := 2.5

static var _n1: FastNoiseLite
static var _n2: FastNoiseLite
static var _n3: FastNoiseLite
static var rivers: Array = []

static func init() -> void:
	if _n1: return
	_n1 = FastNoiseLite.new(); _n1.seed = 11; _n1.frequency = 0.0035; _n1.fractal_octaves = 4
	_n2 = FastNoiseLite.new(); _n2.seed = 23; _n2.frequency = 0.03; _n2.fractal_octaves = 2
	_n3 = FastNoiseLite.new(); _n3.seed = 5; _n3.frequency = 0.0009; _n3.fractal_octaves = 3
	# waterfall from the garden channel down into the lake
	rivers.append(PackedVector2Array([Vector2(65, -70), Vector2(66, -95), Vector2(56, -120), Vector2(62, -145), Vector2(48, -170), Vector2(40, -195)]))
	# far river from the lake towards the big cliff waterfalls
	rivers.append(PackedVector2Array([Vector2(0, -340), Vector2(-25, -380), Vector2(5, -420), Vector2(-15, -470), Vector2(20, -520), Vector2(25, -575)]))
	# a winding stream across the left meadows (seen in the flyover)
	rivers.append(PackedVector2Array([Vector2(-60, -200), Vector2(-95, -170), Vector2(-80, -135), Vector2(-120, -110), Vector2(-170, -125), Vector2(-230, -100)]))

static func ss(a: float, b: float, x: float) -> float:
	var t := clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

static func seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)

static func river_dist(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var d := 1e9
	for r in rivers:
		var pts: PackedVector2Array = r
		for i in pts.size() - 1:
			d = minf(d, seg_dist(p, pts[i], pts[i + 1]))
	return d

static func lake_e(x: float, z: float) -> float:
	var wob := _n2.get_noise_2d(x * 0.3, z * 0.3) * 0.12
	return pow((x - 15.0) / 125.0, 2.0) + pow((z + 258.0) / 92.0, 2.0) + wob

## x position of the front edge of the city hill for a given z
static func city_front(z: float) -> float:
	return 122.0 - maxf(0.0, -z - 120.0) * 0.09

static func city_height(x: float, z: float) -> float:
	var cd := x - city_front(z)
	if cd < -12.0: return -100.0
	var ch := 178.0 * ss(-12.0, 230.0, cd) * (1.0 - ss(-600.0, -660.0, z)) * ss(-40.0, -90.0, z)
	# terraces: flat treads + steep risers
	var t := ch / 9.0
	var fl := floorf(t)
	ch = (fl + ss(0.78, 1.0, t - fl)) * 9.0
	return ch + 2.0 + _n2.get_noise_2d(x, z) * 0.6

static func plateau_mask(x: float, z: float) -> float:
	var edge := -57.0 + _n2.get_noise_2d(x * 0.5, 0.0) * 2.0
	return ss(edge - 20.0, edge, z) * (1.0 - ss(106.0, 124.0, x)) * ss(-185.0, -160.0, x)

static func height(x: float, z: float) -> float:
	var n := _n1.get_noise_2d(x, z)
	var n2 := _n2.get_noise_2d(x, z)
	var far := _n3.get_noise_2d(x, z) * 0.5 + 0.5
	# rolling valley floor
	var v := 4.5 + n * 4.0 + n2 * 0.6
	# big soft hills towards the left horizon and behind us
	v += ss(-250.0, -900.0, x) * 70.0 * far + ss(250.0, 900.0, z) * 60.0 * far
	# lake
	v = lerpf(v, -5.0, ss(1.15, 0.8, lake_e(x, z)))
	# rivers with soft banks
	var rd := river_dist(x, z)
	v = lerpf(v, -3.5, 1.0 - ss(5.0, 14.0, rd))
	# plateau
	var garden := 1.0 - ss(90.0, 130.0, Vector2(x, z + 5.0).length())
	var ph := PLATEAU_Y + (n * 4.0 + n2 * 0.8) * (1.0 - garden)
	var pm := plateau_mask(x, z)
	var h := lerpf(v, ph, pm)
	# city hill
	h = maxf(h, city_height(x, z))
	return h

## Builds near (detailed, with collision) and far (horizon) terrain.
static func build(parent: Node3D, mat: Material) -> Dictionary:
	init()
	var w := int((NEAR_MAX.x - NEAR_MIN.x) / NEAR_STEP) + 1
	var d := int((NEAR_MAX.y - NEAR_MIN.y) / NEAR_STEP) + 1
	var heights := PackedFloat32Array()
	heights.resize(w * d)
	for j in d:
		var z := NEAR_MIN.y + j * NEAR_STEP
		for i in w:
			heights[j * w + i] = height(NEAR_MIN.x + i * NEAR_STEP, z)
	var mesh := _grid_mesh(heights, w, d, NEAR_MIN, NEAR_STEP)
	var mi := MeshInstance3D.new()
	mi.name = "TerrainNear"
	mi.mesh = mesh
	mi.material_override = mat
	parent.add_child(mi)

	# collision
	var body := StaticBody3D.new()
	body.name = "TerrainCollision"
	var cs := CollisionShape3D.new()
	var hm := HeightMapShape3D.new()
	hm.map_width = w
	hm.map_depth = d
	hm.map_data = heights
	cs.shape = hm
	cs.position = Vector3((NEAR_MIN.x + NEAR_MAX.x) * 0.5, 0.0, (NEAR_MIN.y + NEAR_MAX.y) * 0.5)
	cs.scale = Vector3(NEAR_STEP, 1.0, NEAR_STEP)
	body.add_child(cs)
	parent.add_child(body)

	# far terrain out to the horizon (slightly sunk where the near terrain is)
	var fstep := 60.0
	var fmin := Vector2(-3600, -3600)
	var fw := int(7200.0 / fstep) + 1
	var fh := PackedFloat32Array(); fh.resize(fw * fw)
	for j in fw:
		var z := fmin.y + j * fstep
		for i in fw:
			var x := fmin.x + i * fstep
			var inside := x > NEAR_MIN.x + 5 and x < NEAR_MAX.x - 5 and z > NEAR_MIN.y + 5 and z < NEAR_MAX.y - 5
			var hh := height(x, z)
			# distant hills/mountains ring
			var r := Vector2(x, z).length()
			hh += ss(900.0, 2600.0, r) * (_n3.get_noise_2d(x * 2.0, z * 2.0) * 0.5 + 0.5) * 260.0
			fh[j * fw + i] = hh - (8.0 if inside else 0.0)
	var fmesh := _grid_mesh(fh, fw, fw, fmin, fstep)
	var fmi := MeshInstance3D.new()
	fmi.name = "TerrainFar"
	fmi.mesh = fmesh
	fmi.material_override = mat
	fmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(fmi)

	# height texture for water depth / shading
	var img := Image.create(w, d, false, Image.FORMAT_RF)
	for j in d:
		for i in w:
			img.set_pixel(i, j, Color(heights[j * w + i], 0, 0))
	var htex := ImageTexture.create_from_image(img)
	return {"heights": heights, "w": w, "d": d, "htex": htex}

static func _grid_mesh(h: PackedFloat32Array, w: int, d: int, origin: Vector2, step: float) -> ArrayMesh:
	var verts := PackedVector3Array(); verts.resize(w * d)
	var norms := PackedVector3Array(); norms.resize(w * d)
	var idx := PackedInt32Array(); idx.resize((w - 1) * (d - 1) * 6)
	for j in d:
		for i in w:
			var k := j * w + i
			verts[k] = Vector3(origin.x + i * step, h[k], origin.y + j * step)
			var hl := h[j * w + maxi(i - 1, 0)]
			var hr := h[j * w + mini(i + 1, w - 1)]
			var hd := h[maxi(j - 1, 0) * w + i]
			var hu := h[mini(j + 1, d - 1) * w + i]
			norms[k] = Vector3(hl - hr, 2.0 * step, hd - hu).normalized()
	var t := 0
	for j in d - 1:
		for i in w - 1:
			var a := j * w + i
			idx[t] = a; idx[t + 1] = a + 1; idx[t + 2] = a + w
			idx[t + 3] = a + 1; idx[t + 4] = a + w + 1; idx[t + 5] = a + w
			t += 6
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m
