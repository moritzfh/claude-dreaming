## Finds every room in res://rooms/*/room.tres (folders starting with "_" are
## templates and skipped).
class_name RoomRegistry
extends RefCounted

const ROOT := "res://rooms"

static func all() -> Array[RoomInfo]:
	var out: Array[RoomInfo] = []
	if not DirAccess.dir_exists_absolute(ROOT): return out
	for dir in DirAccess.get_directories_at(ROOT):
		if dir.begins_with("_") or dir.begins_with("."): continue
		var path := "%s/%s/room.tres" % [ROOT, dir]
		if not ResourceLoader.exists(path):
			push_warning("room folder without room.tres: " + dir)
			continue
		var info := load(path) as RoomInfo
		if info == null or info.background == null:
			push_warning("room.tres is not a RoomInfo or has no background: " + path)
			continue
		info.set_meta("id", dir)
		out.append(info)
	out.sort_custom(func(a: RoomInfo, b: RoomInfo) -> bool:
		return a.order < b.order if a.order != b.order else a.title < b.title)
	return out
