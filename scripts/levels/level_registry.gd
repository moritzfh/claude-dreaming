## Finds every level in res://levels/*/level.tres (folders starting with "_"
## are templates and skipped).
class_name LevelRegistry
extends RefCounted

const ROOT := "res://levels"

static func all() -> Array[LevelInfo]:
	var out: Array[LevelInfo] = []
	for dir in DirAccess.get_directories_at(ROOT):
		if dir.begins_with("_") or dir.begins_with("."): continue
		var path := "%s/%s/level.tres" % [ROOT, dir]
		if not ResourceLoader.exists(path):
			push_warning("level folder without level.tres: " + dir)
			continue
		var info := load(path) as LevelInfo
		if info == null or info.scene == "":
			push_warning("level.tres is not a LevelInfo or has no scene: " + path)
			continue
		info.set_meta("id", dir)
		out.append(info)
	out.sort_custom(func(a: LevelInfo, b: LevelInfo) -> bool:
		return a.order < b.order if a.order != b.order else a.title < b.title)
	return out

static func by_id(id: String) -> LevelInfo:
	for l in all():
		if l.get_meta("id") == id: return l
	# templates ("_" folders) aren't in the gallery but can still be started
	var path := "%s/%s/level.tres" % [ROOT, id]
	if ResourceLoader.exists(path):
		var info := load(path) as LevelInfo
		if info:
			info.set_meta("id", id)
			return info
	return null
