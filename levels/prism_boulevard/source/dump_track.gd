## Dev tool: writes the baked track to JSON (for plotting the layout).
##   godot --headless --path . --script res://levels/prism_boulevard/source/dump_track.gd -- out.json
extends SceneTree

func _init() -> void:
	var TrackScript := load("res://levels/prism_boulevard/track.gd")
	var Course := load("res://levels/prism_boulevard/course.gd")
	if not TrackScript.can_instantiate():
		printerr("track.gd does not compile")
		quit(1)
		return
	var tr = TrackScript.new()
	tr.build(Course.commands())
	var out := "/tmp/track.json"
	for a in OS.get_cmdline_user_args(): out = a
	var pts := []
	for i in tr.n:
		pts.append([tr.P[i].x, tr.P[i].y, tr.P[i].z, tr.U[i].x, tr.U[i].y, tr.U[i].z, tr.W[i], tr.SURF[i], tr.SEC[i], tr.KG[i], tr.KN[i], tr.LINE[i], tr.R[i].x, tr.R[i].y, tr.R[i].z])
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(JSON.stringify({"pts": pts, "sections": tr.sections, "length": tr.length, "kicks": tr.kicks, "pads": tr.pads}))
	f.close()
	print("track length %.0f m, %d samples -> %s" % [tr.length, tr.n, out])
	quit()
