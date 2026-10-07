## Player settings (volume, display, camera), saved to user://settings.cfg
## and applied at start (by the Menus autoload).
class_name Settings
extends RefCounted

const PATH := "user://settings.cfg"

static var master := 0.9        # 0..1
static var music := 0.8
static var sfx := 0.9
static var fullscreen := false
static var low_quality := false
static var mouse_sens := 1.0    # multiplier
static var invert_y := false

static func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		master = cf.get_value("audio", "master", master)
		music = cf.get_value("audio", "music", music)
		sfx = cf.get_value("audio", "sfx", sfx)
		fullscreen = cf.get_value("display", "fullscreen", fullscreen)
		low_quality = cf.get_value("display", "low_quality", low_quality)
		mouse_sens = cf.get_value("controls", "mouse_sens", mouse_sens)
		invert_y = cf.get_value("controls", "invert_y", invert_y)
	apply()

static func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("audio", "master", master)
	cf.set_value("audio", "music", music)
	cf.set_value("audio", "sfx", sfx)
	cf.set_value("display", "fullscreen", fullscreen)
	cf.set_value("display", "low_quality", low_quality)
	cf.set_value("controls", "mouse_sens", mouse_sens)
	cf.set_value("controls", "invert_y", invert_y)
	cf.save(PATH)

static func apply() -> void:
	_ensure_buses()
	_set_bus("Master", master)
	_set_bus("Music", music)
	_set_bus("SFX", sfx)
	# low quality: the 3D view renders at 75 % and without MSAA (the scenes
	# switch off their expensive effects themselves: set_low_quality())
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		tree.root.scaling_3d_scale = 0.75 if low_quality else 1.0
		tree.root.msaa_3d = Viewport.MSAA_DISABLED if low_quality else int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_3d", 0)) as Viewport.MSAA
	if DisplayServer.get_name() != "headless":
		var want := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != want and not (not fullscreen and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MAXIMIZED):
			DisplayServer.window_set_mode(want)

static func _ensure_buses() -> void:
	for n in ["Music", "SFX"]:
		if AudioServer.get_bus_index(n) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, n)
			AudioServer.set_bus_send(i, "Master")

static func _set_bus(n: String, v: float) -> void:
	var i := AudioServer.get_bus_index(n)
	if i < 0: return
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.0001)))
	AudioServer.set_bus_mute(i, v <= 0.001)
