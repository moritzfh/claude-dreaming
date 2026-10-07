## State that survives scene reloads (dreaming again from the hub).
class_name GameState
extends RefCounted

## "full" = start with the film's pixel intro; "dream" = straight into the painting;
## "hub" = attic; "" = decided by command line
static var next_mode := ""
## extra start options for the next run (stepping into a gallery painting)
static var next_opts: Array = []
static var found_orbs := {}      # orb id -> true
static var dreams := 0
## the level that was just played (the hub starts in front of its painting)
static var hub_return := ""
## level id -> true once its goal was reached
static var completed := {}
## the first dream has been painted on the easel in the attic
static var painted := false
## per level notes a level wants to remember (e.g. best star bit count)
static var stats := {}
## the whole film was watched (or skipped) once – later starts go to the attic
static var intro_seen := false

const SAVE_PATH := "user://save.cfg"

## Progress survives quitting the game (user://save.cfg).
static func save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("progress", "intro_seen", intro_seen)
	cf.set_value("progress", "painted", painted)
	cf.set_value("progress", "dreams", dreams)
	cf.set_value("progress", "found_orbs", found_orbs.keys())
	cf.set_value("progress", "completed", completed.keys())
	cf.set_value("progress", "stats", stats)
	cf.save(SAVE_PATH)

static func load_save() -> bool:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK: return false
	intro_seen = cf.get_value("progress", "intro_seen", false)
	painted = cf.get_value("progress", "painted", false)
	dreams = cf.get_value("progress", "dreams", 0)
	found_orbs = {}
	for k in cf.get_value("progress", "found_orbs", []): found_orbs[int(k)] = true
	completed = {}
	for k in cf.get_value("progress", "completed", []): completed[str(k)] = true
	stats = cf.get_value("progress", "stats", {})
	return true

static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

## start over (keeps the settings)
static func reset() -> void:
	intro_seen = false
	painted = false
	dreams = 0
	found_orbs = {}
	completed = {}
	stats = {}
	hub_return = ""
	if FileAccess.file_exists(SAVE_PATH): DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
