## Stepping into a painting (and back out) without a hitch.
##
## Building a scene costs time – a level's build(), the attic, the dream world –
## and while it runs, nothing on screen moves. If that happened in the middle
## of the camera move into a painting, the move would jerk. So the next scene
## is built ahead of time, at a moment where a short stall can't be seen (when
## Claude starts talking about the painting, or when the camera is still at
## rest), and parked: hidden, paused and silent. When the camera move reaches
## the painting, swap() only has to switch it on. The old scene is taken apart
## a few nodes per frame afterwards (dispose()).
##
## A scene being parked sees `SceneSwap.parking == true` in its _ready() and
## must not start yet; swap() calls its `_unparked()`.
class_name SceneSwap
extends RefCounted

static var parked: Node = null
static var parked_by: Object = null
static var parking := false
static var _helper: _Helper
static var _gen := 0      # bumped by swap(): a warm-up that is still running must not undo it

## Instantiate `ps` now, hidden and paused, ready for swap().
static func prepare(ps: PackedScene, by: Object = null) -> Node:
	discard()
	if ps == null: return null
	var tree := Engine.get_main_loop() as SceneTree
	var mouse := Input.mouse_mode
	parking = true
	Sound.capture(true)
	var n := ps.instantiate()
	n.set_meta("swap_name", n.name)      # (renamed while the old scene has its name)
	n.process_mode = Node.PROCESS_MODE_DISABLED
	tree.root.add_child(n)          # its _ready runs (and builds) now
	n.set_meta("swap_sound", Sound.capture(false))
	parking = false
	n.set_meta("swap_mouse", Input.mouse_mode)
	Input.mouse_mode = mouse
	var hidden: Array = []
	for c in n.find_children("*", "CanvasLayer", true, false):
		if (c as CanvasLayer).visible:
			(c as CanvasLayer).visible = false
			hidden.append(c)
	n.set_meta("swap_layers", hidden)
	parked = n
	parked_by = by
	return n

## Let the GPU see the parked scene for a few frames, from `xf`, before it is
## really shown (shaders and render pipelines get compiled now, not in the
## middle of the camera move). The 3D view is drawn behind the attic, which
## covers the whole screen, so nothing of it can be seen yet.
static func warm_up(xf: Transform3D, fov := 60.0, frames := 8, layers: Array = []) -> void:
	if DisplayServer.get_name() == "headless": return
	# its UI layers below the attic (the painterly filter, a level's own UI)
	# are drawn too – the attic (layer 15) still covers them
	var shown: Array = []
	var scene := parked
	for c in layers + (scene.get_meta("swap_layers", []) if scene else []):
		if is_instance_valid(c) and (c as CanvasLayer).layer < 15 and not (c as CanvasLayer).visible:
			(c as CanvasLayer).visible = true
			shown.append(c)
	if scene and scene.has_method("_warming_up"): scene.call("_warming_up", true)
	var root := (Engine.get_main_loop() as SceneTree).root
	var prev := root.get_camera_3d()
	var cam := Camera3D.new()
	cam.fov = fov
	cam.far = 8000.0
	cam.near = 0.05
	root.add_child(cam)
	cam.global_transform = xf
	cam.current = true
	var was_3d_off := root.disable_3d
	root.disable_3d = false
	var gen := _gen
	_ensure_helper()
	_helper.after(frames, func():
		if is_instance_valid(cam): cam.queue_free()
		if gen != _gen: return          # already switched over: leave it as it is
		for c in shown:
			if is_instance_valid(c): (c as CanvasLayer).visible = false
		if is_instance_valid(scene) and scene.has_method("_warming_up"): scene.call("_warming_up", false)
		if is_instance_valid(prev): prev.current = true
		root.disable_3d = was_3d_off)

## Make the parked scene the current one; the old one is taken apart bit by bit.
static func swap() -> Node:
	var n := parked
	if n == null or not is_instance_valid(n): return null
	parked = null
	parked_by = null
	_gen += 1
	var tree := Engine.get_main_loop() as SceneTree
	var old := tree.current_scene
	if old:
		old.name = "Disposing%d" % old.get_instance_id()
		dispose(old)
	n.name = n.get_meta("swap_name", n.name)
	n.process_mode = Node.PROCESS_MODE_INHERIT
	for c in n.get_meta("swap_layers", []):
		if is_instance_valid(c): (c as CanvasLayer).visible = true
	tree.current_scene = n
	Input.mouse_mode = n.get_meta("swap_mouse", Input.mouse_mode)
	Sound.replay(n.get_meta("swap_sound", []))
	if n.has_method("_unparked"): n.call("_unparked")
	return n

## Throw away a parked scene that isn't needed any more.
static func discard(by: Object = null) -> void:
	if parked and is_instance_valid(parked) and (by == null or by == parked_by):
		parked.queue_free()
	if by == null or by == parked_by:
		parked = null
		parked_by = null

## Switch a scene off at once (hidden, paused, its environment gone) and free
## it a few nodes per frame, so even a big scene costs no visible frame.
static func dispose(old: Node) -> void:
	if old.has_method("_disposing"): old.call("_disposing")
	old.process_mode = Node.PROCESS_MODE_DISABLED
	if old is Node3D: (old as Node3D).visible = false
	if old is CanvasItem: (old as CanvasItem).visible = false
	if old is CanvasLayer: (old as CanvasLayer).visible = false
	for c in old.find_children("*", "CanvasLayer", true, false): (c as CanvasLayer).visible = false
	for c in old.find_children("*", "Node", true, false):
		if c is WorldEnvironment:
			c.queue_free()
		elif c is Camera3D:
			(c as Camera3D).current = false
	_ensure_helper()
	_helper.dispose(old)

## A worker thread is still building `node` for a scene that is gone: wait
## for it (without blocking) and throw the result away.
static func adopt(task_id: int, node: Node) -> void:
	_ensure_helper()
	_helper.tasks.append([task_id, node])

static func _ensure_helper() -> void:
	if _helper and is_instance_valid(_helper): return
	_helper = _Helper.new()
	_helper.name = "SceneSwapHelper"
	(Engine.get_main_loop() as SceneTree).root.add_child.call_deferred(_helper)


class _Helper extends Node:
	var _queue: Array = []
	var _later: Array = []
	var tasks: Array = []

	func _init() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS

	func dispose(n: Node) -> void:
		# children before their parents
		var order: Array = []
		_post_order(n, order)
		_queue.append_array(order)

	func _post_order(n: Node, out: Array) -> void:
		for c in n.get_children(): _post_order(c, out)
		out.append(n)

	func _exit_tree() -> void:
		# the game is closing: finish everything now
		for e in tasks:
			WorkerThreadPool.wait_for_task_completion(e[0])
			if is_instance_valid(e[1]): (e[1] as Node).free()
		tasks.clear()
		for n in _queue:
			if is_instance_valid(n) and not (n as Node).is_inside_tree(): (n as Node).free()
		_queue.clear()

	func free_later(n: Node, frames: int) -> void:
		_later.append([n, frames])

	func after(frames: int, f: Callable) -> void:
		_later.append([f, frames])

	func _process(_d: float) -> void:
		for e in tasks.duplicate():
			if WorkerThreadPool.is_task_completed(e[0]):
				WorkerThreadPool.wait_for_task_completion(e[0])
				tasks.erase(e)
				if is_instance_valid(e[1]): dispose(e[1])
		for e in _later.duplicate():
			e[1] -= 1
			if e[1] <= 0:
				_later.erase(e)
				if e[0] is Callable: (e[0] as Callable).call()
				elif is_instance_valid(e[0]): (e[0] as Node).queue_free()
		var t0 := Time.get_ticks_usec()
		while not _queue.is_empty() and Time.get_ticks_usec() - t0 < 2500:
			var n: Variant = _queue.pop_front()
			if is_instance_valid(n): (n as Node).free()
