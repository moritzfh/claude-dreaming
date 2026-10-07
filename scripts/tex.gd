## Synchronous procedural textures (so the first rendered frame is complete).
## Safe to call from a worker thread (the dream world is built on one while
## the attic is shown).
class_name Tex
extends RefCounted

static var _cache := {}
static var _m := Mutex.new()

static func _cget(key: String) -> ImageTexture:
	_m.lock()
	var t: ImageTexture = _cache.get(key)
	_m.unlock()
	return t

static func _cput(key: String, t: ImageTexture) -> ImageTexture:
	_m.lock()
	if _cache.has(key): t = _cache[key]
	else: _cache[key] = t
	_m.unlock()
	return t

static func noise(seed_v: int, freq: float, size := 512, octaves := 4, kind := FastNoiseLite.TYPE_SIMPLEX_SMOOTH) -> ImageTexture:
	var key := "n%d_%f_%d_%d_%d" % [seed_v, freq, size, octaves, kind]
	var hit := _cget(key)
	if hit: return hit
	var fn := FastNoiseLite.new()
	fn.seed = seed_v; fn.frequency = freq; fn.fractal_octaves = octaves; fn.noise_type = kind
	var img := fn.get_seamless_image(size, size)
	img.convert(Image.FORMAT_RGBA8)
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	return _cput(key, t)

## per-texel white noise (no mipmaps) — the raw material for brush strokes
static func white(seed_v: int, size := 256) -> ImageTexture:
	var key := "w%d_%d" % [seed_v, size]
	var hit := _cget(key)
	if hit: return hit
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var data := PackedByteArray()
	data.resize(size * size)
	for i in size * size: data[i] = rng.randi() & 255
	var t := ImageTexture.create_from_image(Image.create_from_data(size, size, false, Image.FORMAT_L8, data))
	return _cput(key, t)

## noise remapped into [lo, hi] — for subtle albedo variation
static func soft_noise(seed_v: int, freq: float, lo := 0.8, hi := 1.0, size := 256) -> ImageTexture:
	var key := "sn%d_%f_%f_%f" % [seed_v, freq, lo, hi]
	var hit := _cget(key)
	if hit: return hit
	var fn := FastNoiseLite.new()
	fn.seed = seed_v; fn.frequency = freq; fn.fractal_octaves = 4
	var img := fn.get_seamless_image(size, size)
	img.convert(Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var v := lerpf(lo, hi, img.get_pixel(x, y).r)
			img.set_pixel(x, y, Color(v, v, v))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	return _cput(key, t)

static func normal(seed_v: int, freq: float, size := 512, strength := 4.0) -> ImageTexture:
	var key := "nm%d_%f_%d_%f" % [seed_v, freq, size, strength]
	var hit := _cget(key)
	if hit: return hit
	var fn := FastNoiseLite.new()
	fn.seed = seed_v; fn.frequency = freq; fn.fractal_octaves = 3
	var img := fn.get_seamless_image(size, size)
	img.convert(Image.FORMAT_RGBA8)
	img.bump_map_to_normal_map(strength)
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	return _cput(key, t)
