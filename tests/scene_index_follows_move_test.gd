# The project's two scene indexes (which scene a script is the root of, which scenes load a script) follow a
# rename or a move in place instead of being dropped and read again from every scene in the project. What the
# user sees - a tab's title, a scene mark, anything that asks the index - has to be exactly what a fresh read
# of the project after the same move would say, so each case below moves files on disk the way the editor
# does (the file, and the scenes rewritten for its new path), reads the project afresh, and holds the index
# that followed the move up against it.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME := "scene_index_follows_move_test"
const FOLLOW := preload("res://addons/eventforge/importer/scene_index_follow.gd")


static func run() -> bool:
	var passed: bool = true
	passed = _a_script_renamed(true) and passed
	passed = _a_script_renamed(false) and passed
	passed = _a_folder_of_scripts_moved() and passed
	passed = _several_files_moved_together() and passed
	passed = _a_script_two_scenes_use() and passed
	passed = _a_folder_of_scenes_moved_across_the_walk_order() and passed
	passed = _chained_moves_land_on_the_last_name() and passed
	passed = _a_move_nothing_names_changes_nothing() and passed
	passed = _a_scene_saved_by_the_editor_is_read() and passed
	passed = _the_held_index_follows_a_move_and_a_re_read_confirms_it() and passed
	passed = _the_held_index_answers_while_the_re_read_runs() and passed
	passed = _a_read_begun_before_a_move_does_not_undo_it() and passed
	passed = _a_re_read_that_brings_news_is_announced() and passed
	passed = _dropping_the_index_ends_a_re_read() and passed
	return passed


# ── A small project on disk ──────────────────────────────────────────────────────────────────────────


## One scene: its root carries `root_script`, and each child carries one of `child_scripts`.
static func _scene_text(root_name: String, root_script: String, child_scripts: Array = []) -> String:
	# The editor writes a uid before the path on every ext_resource line, so these do too.
	var text: String = "[gd_scene load_steps=3 format=3]\n\n[ext_resource type=\"Script\" uid=\"uid://cs%d\" path=\"%s\" id=\"1_a\"]\n" % [root_script.hash() % 1000, root_script]
	for at: int in range(child_scripts.size()):
		text += "[ext_resource type=\"Script\" uid=\"uid://ck%d\" path=\"%s\" id=\"2_%d\"]\n" % [str(child_scripts[at]).hash() % 1000, child_scripts[at], at]
	text += "\n[node name=\"%s\" type=\"Node2D\"]\nscript = ExtResource(\"1_a\")\n" % root_name
	for at: int in range(child_scripts.size()):
		text += "\n[node name=\"Kid%d\" type=\"Node\" parent=\".\"]\nscript = ExtResource(\"2_%d\")\n" % [at, at]
	return text


static func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


## Replaces `from` with `to` in a scene file, the way the editor rewrites the scenes that name a moved script.
static func _respell(path: String, from: String, to: String) -> void:
	_write(path, FileAccess.get_file_as_string(path).replace(from, to))


## A project of scenes under `root`. Scripts are only names in the scenes (nothing needs to exist for the
## index to read them), so the project is a handful of small files.
static func _project(name: String) -> String:
	var root: String = SUPPORT.own_folder("scene_index_" + name)
	_write(root + "/scenes/hero.tscn", _scene_text("Hero", "res://scripts/hero.gd", ["res://scripts/arm.gd"]))
	_write(root + "/scenes/hero_ghost.tscn", _scene_text("Ghost", "res://scripts/hero.gd"))
	_write(root + "/scenes/zed.tscn", _scene_text("Zed", "res://scripts/zed.gd", ["res://scripts/hero.gd"]))
	_write(root + "/scenes/deep/foe.tscn", _scene_text("Foe", "res://scripts/foe.gd", ["res://scripts/arm.gd"]))
	_write(root + "/scenes/deep/foe_two.tscn", _scene_text("FoeTwo", "res://scripts/foe.gd"))
	_write(root + "/other/door.tscn", _scene_text("Door", "res://scripts/door.gd"))
	return root


static func _scenes_of(root: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	EventSheetSceneConnections._walk_scene_paths(root, found)
	found.sort()
	return found


## Both indexes, read afresh from `root`.
static func _fresh(root: String) -> Array:
	return [EventSheetViewportRowBuilder.sweep_scenes_under(root), EventSheetSceneConnections.index_scenes(_scenes_of(root))]


## Both indexes after the move, taken from `before` without reading a file.
static func _followed(before: Array, old_path: String, new_path: String, is_folder: bool) -> Array:
	return [
		FOLLOW.rows_after_move(before[0], old_path, new_path, is_folder),
		FOLLOW.scenes_after_move(before[1], old_path, new_path, is_folder),
	]


## The rows that pin one case: the followed index equals the fresh one, for both indexes.
static func _agree(label: String, followed: Array, fresh: Array) -> bool:
	var passed: bool = true
	passed = SUPPORT.pin_value(TEST_NAME, label + ": the root index", _readable(followed[0]), _readable(fresh[0])) and passed
	passed = SUPPORT.pin_value(TEST_NAME, label + ": the scenes-by-script index", _readable(followed[1]), _readable(fresh[1])) and passed
	return passed


## An index as text with its keys in order, so two that hold the same answers compare equal whatever order
## their keys were added in, while the order INSIDE each list (which is an answer) is kept.
static func _readable(index: Dictionary) -> String:
	var keys: Array = index.keys()
	keys.sort()
	var lines: PackedStringArray = PackedStringArray()
	for key: Variant in keys:
		lines.append("%s => %s" % [key, str(index[key])])
	return "\n".join(lines)


# ── What a move does ─────────────────────────────────────────────────────────────────────────────────


## One script renamed, in its folder or into another: the scenes that name it are rewritten, and the index
## answers for the new path exactly as a fresh read does.
static func _a_script_renamed(stays_in_folder: bool) -> bool:
	var root: String = _project("rename_%s" % stays_in_folder)
	var before: Array = _fresh(root)
	var old_path: String = "res://scripts/hero.gd"
	var new_path: String = "res://scripts/hero_brain.gd" if stays_in_folder else "res://actors/hero.gd"
	for scene: String in _scenes_of(root):
		_respell(scene, old_path, new_path)
	return _agree("a script renamed" if stays_in_folder else "a script moved to another folder",
		_followed(before, old_path, new_path, false), _fresh(root))


static func _a_folder_of_scripts_moved() -> bool:
	var root: String = _project("script_folder")
	var before: Array = _fresh(root)
	for scene: String in _scenes_of(root):
		_respell(scene, "res://scripts/", "res://gameplay/")
	return _agree("a folder of scripts moved", _followed(before, "res://scripts", "res://gameplay", true), _fresh(root))


## The FileSystem dock reports a selection of many files as many moves in the same moment: each one follows
## the one before it.
static func _several_files_moved_together() -> bool:
	var root: String = _project("several")
	var before: Array = _fresh(root)
	var followed: Array = before
	for pair: Array in [["res://scripts/hero.gd", "res://scripts/knight.gd"], ["res://scripts/foe.gd", "res://scripts/boss.gd"], ["res://scripts/door.gd", "res://scripts/gate.gd"]]:
		for scene: String in _scenes_of(root):
			_respell(scene, str(pair[0]), str(pair[1]))
		followed = _followed(followed, str(pair[0]), str(pair[1]), false)
	return _agree("three scripts renamed in one batch", followed, _fresh(root))


## A script two scenes use as their root: the first the sweep meets names the object, and it stays the first
## whichever of the two is renamed.
static func _a_script_two_scenes_use() -> bool:
	var root: String = _project("shared")
	var before: Array = _fresh(root)
	var shared: Array = (before[0] as Dictionary)["res://scripts/hero.gd"]
	var passed: bool = SUPPORT.pin_value(TEST_NAME, "two scenes root the script, in the order the sweep meets them",
		[shared.size(), str(shared[0]["root_name"]), str(shared[1]["root_name"])], [2, "Hero", "Ghost"])
	var old_scene: String = root + "/scenes/hero.tscn"
	var new_scene: String = root + "/scenes/zz_hero.tscn"
	DirAccess.rename_absolute(old_scene, new_scene)
	passed = _agree("the scene that names the object renamed so the other comes first",
		_followed(before, old_scene, new_scene, false), _fresh(root)) and passed
	var after: Array = _followed(before, old_scene, new_scene, false)
	passed = SUPPORT.pin_value(TEST_NAME, "and the other scene now names the object",
		str((after[0] as Dictionary)["res://scripts/hero.gd"][0]["root_name"]), "Ghost") and passed
	return passed


## A folder of scenes moved to a place the sweep meets earlier or later: the entries that share a script
## are put back in the order a sweep meets them, and the list of scenes in path order.
static func _a_folder_of_scenes_moved_across_the_walk_order() -> bool:
	var root: String = _project("scene_folder")
	_write(root + "/scenes/deep/hero_deep.tscn", _scene_text("HeroDeep", "res://scripts/foe.gd"))
	var before: Array = _fresh(root)
	var old_folder: String = root + "/scenes/deep"
	var new_folder: String = root + "/aaa/inner"
	DirAccess.make_dir_recursive_absolute(root + "/aaa")
	DirAccess.rename_absolute(old_folder, new_folder)
	var passed: bool = _agree("a folder of scenes moved ahead of the others", _followed(before, old_folder, new_folder, true), _fresh(root))
	var back: Array = _followed(_followed(before, old_folder, new_folder, true), new_folder, old_folder, true)
	passed = SUPPORT.pin_value(TEST_NAME, "and moved back it reads as it did", _readable(back[0]) + _readable(back[1]), _readable(before[0]) + _readable(before[1])) and passed
	return passed


## A to B, then B to C, in one batch: the index lands on C, and nothing is left under A or B.
static func _chained_moves_land_on_the_last_name() -> bool:
	var root: String = _project("chain")
	var before: Array = _fresh(root)
	var followed: Array = before
	for pair: Array in [["res://scripts/hero.gd", "res://scripts/knight.gd"], ["res://scripts/knight.gd", "res://scripts/paladin.gd"]]:
		for scene: String in _scenes_of(root):
			_respell(scene, str(pair[0]), str(pair[1]))
		followed = _followed(followed, str(pair[0]), str(pair[1]), false)
	var passed: bool = _agree("a script renamed twice in one batch", followed, _fresh(root))
	passed = SUPPORT.pin_value(TEST_NAME, "nothing is left under the names it passed through",
		[(followed[0] as Dictionary).has("res://scripts/hero.gd"), (followed[0] as Dictionary).has("res://scripts/knight.gd"), (followed[1] as Dictionary).has("res://scripts/knight.gd")],
		[false, false, false]) and passed
	return passed


## A scene the editor saved names its scripts with a uid before the path, and its root object is still read.
static func _a_scene_saved_by_the_editor_is_read() -> bool:
	var root: String = _project("saved")
	var found: Dictionary = EventSheetViewportRowBuilder.sweep_scenes_under(root)
	return SUPPORT.pin_value(TEST_NAME, "a script on the root of a scene with uid lines names that scene's object",
		[str(found["res://scripts/door.gd"][0]["root_name"]), (found["res://scripts/foe.gd"] as Array).size()], ["Door", 2])


static func _a_move_nothing_names_changes_nothing() -> bool:
	var root: String = _project("untouched")
	var before: Array = _fresh(root)
	var followed: Array = _followed(before, "res://scripts/loner.gd", "res://scripts/lone.gd", false)
	return _agree("a move no scene names", followed, before)


# ── The held indexes of the running editor ───────────────────────────────────────────────────────────


## The script a showcase scene uses as its root: a real entry to follow.
const PROBE_SCRIPT := "res://demo/showcase/family_arena/enemy.gd"
const PROBE_MOVED := "res://demo/showcase/family_arena/enemy_moved.gd"


static func _the_held_index_follows_a_move_and_a_re_read_confirms_it() -> bool:
	EventSheetViewportRowBuilder.clear_scene_script_index()
	EventSheetSceneConnections.clear_cache()
	var entry: Dictionary = EventSheetViewportRowBuilder.scene_using_script(PROBE_SCRIPT)
	var scenes: PackedStringArray = EventSheetSceneConnections.scenes_using_script(PROBE_SCRIPT)
	EventSheetViewportRowBuilder.note_path_moved(PROBE_SCRIPT, PROBE_MOVED, false)
	EventSheetSceneConnections.note_path_moved(PROBE_SCRIPT, PROBE_MOVED, false)
	var passed: bool = SUPPORT.pins(TEST_NAME, [
		["the probe script is the root of a scene", entry.is_empty(), false],
		["the moved script is named by the scene the old one was", EventSheetViewportRowBuilder.scene_using_script(PROBE_MOVED), entry],
		["the old name names nothing", EventSheetViewportRowBuilder.scene_using_script(PROBE_SCRIPT), {}],
		["the scenes that load the moved script are the ones that loaded the old", EventSheetSceneConnections.scenes_using_script(PROBE_MOVED), scenes],
		["and the old name loads in no scene", EventSheetSceneConnections.scenes_using_script(PROBE_SCRIPT).size(), 0],
	])
	# The project's files were not touched, so a re-read puts the old name back: the index that followed
	# the move is replaced by what the files say.
	EventSheetViewportRowBuilder.start_scene_script_refresh()
	EventSheetViewportRowBuilder.finish_scene_script_refresh()
	EventSheetSceneConnections.start_index_refresh()
	EventSheetSceneConnections.finish_index_refresh()
	passed = SUPPORT.pins(TEST_NAME, [
		["a re-read says what the files say", EventSheetViewportRowBuilder.scene_using_script(PROBE_SCRIPT), entry],
		["and nothing is left under the name the move gave", EventSheetViewportRowBuilder.scene_using_script(PROBE_MOVED), {}],
		["the scenes-by-script index likewise", [EventSheetSceneConnections.scenes_using_script(PROBE_SCRIPT), EventSheetSceneConnections.scenes_using_script(PROBE_MOVED).size()], [scenes, 0]],
	]) and passed
	return passed


## While the project is read again the index that is held goes on answering: a rename, or a save, never
## leaves a question waiting for the whole project to be read.
static func _the_held_index_answers_while_the_re_read_runs() -> bool:
	EventSheetViewportRowBuilder.clear_scene_script_index()
	EventSheetSceneConnections.clear_cache()
	var entry: Dictionary = EventSheetViewportRowBuilder.scene_using_script(PROBE_SCRIPT)
	var scenes: PackedStringArray = EventSheetSceneConnections.scenes_using_script(PROBE_SCRIPT)
	EventSheetViewportRowBuilder.start_scene_script_refresh()
	EventSheetSceneConnections.start_index_refresh()
	var running: Array = [EventSheetViewportRowBuilder.scene_refresh_running(), EventSheetSceneConnections.index_refresh_running()]
	var while_reading: Array = [EventSheetViewportRowBuilder.scene_using_script(PROBE_SCRIPT), EventSheetSceneConnections.scenes_using_script(PROBE_SCRIPT)]
	EventSheetViewportRowBuilder.finish_scene_script_refresh()
	EventSheetSceneConnections.finish_index_refresh()
	return SUPPORT.pins(TEST_NAME, [
		["both re-reads were under way", running, [true, true]],
		["the index held answers while they ran", while_reading, [entry, scenes]],
		["and both have arrived", [EventSheetViewportRowBuilder.scene_refresh_running(), EventSheetSceneConnections.index_refresh_running()], [false, false]],
		["with the same answers, the files being the same", [EventSheetViewportRowBuilder.scene_using_script(PROBE_SCRIPT), EventSheetSceneConnections.scenes_using_script(PROBE_SCRIPT)], [entry, scenes]],
	])


## A read that began before a move names the files as they were. When it arrives after the move it is
## dropped, so the index that followed the move is not put back to the old names.
static func _a_read_begun_before_a_move_does_not_undo_it() -> bool:
	EventSheetViewportRowBuilder.clear_scene_script_index()
	EventSheetSceneConnections.clear_cache()
	var entry: Dictionary = EventSheetViewportRowBuilder.scene_using_script(PROBE_SCRIPT)
	var scenes: PackedStringArray = EventSheetSceneConnections.scenes_using_script(PROBE_SCRIPT)
	EventSheetViewportRowBuilder.start_scene_script_refresh()
	EventSheetSceneConnections.start_index_refresh()
	EventSheetViewportRowBuilder.note_path_moved(PROBE_SCRIPT, PROBE_MOVED, false)
	EventSheetSceneConnections.note_path_moved(PROBE_SCRIPT, PROBE_MOVED, false)
	EventSheetViewportRowBuilder.finish_scene_script_refresh()
	EventSheetSceneConnections.finish_index_refresh()
	var passed: bool = SUPPORT.pins(TEST_NAME, [
		["the moved script keeps the scene the old one named", EventSheetViewportRowBuilder.scene_using_script(PROBE_MOVED), entry],
		["and the old name stays empty", EventSheetViewportRowBuilder.scene_using_script(PROBE_SCRIPT), {}],
		["the scenes-by-script index likewise", [EventSheetSceneConnections.scenes_using_script(PROBE_MOVED), EventSheetSceneConnections.scenes_using_script(PROBE_SCRIPT).size()], [scenes, 0]],
	])
	# The next read, begun after the move, is the one that counts.
	EventSheetViewportRowBuilder.start_scene_script_refresh()
	EventSheetViewportRowBuilder.finish_scene_script_refresh()
	EventSheetSceneConnections.start_index_refresh()
	EventSheetSceneConnections.finish_index_refresh()
	passed = SUPPORT.pin_value(TEST_NAME, "and a read begun after the move is taken",
		EventSheetViewportRowBuilder.scene_using_script(PROBE_SCRIPT), entry) and passed
	return passed


## An index that arrives different from the one it replaces is announced, so what was built from the old
## one is built again; one that arrives the same is not.
static func _a_re_read_that_brings_news_is_announced() -> bool:
	EventSheetViewportRowBuilder.clear_scene_script_index()
	EventSheetSceneConnections.clear_cache()
	EventSheetViewportRowBuilder.scene_using_script(PROBE_SCRIPT)
	EventSheetSceneConnections.scenes_using_script(PROBE_SCRIPT)
	var heard: Array = [0, 0]
	EventSheetViewportRowBuilder.scene_index_changed = func() -> void: heard[0] += 1
	EventSheetSceneConnections.index_changed = func() -> void: heard[1] += 1
	EventSheetViewportRowBuilder.start_scene_script_refresh()
	EventSheetViewportRowBuilder.finish_scene_script_refresh()
	EventSheetSceneConnections.start_index_refresh()
	EventSheetSceneConnections.finish_index_refresh()
	var after_same: Array = heard.duplicate()
	# A held index that the files do not agree with: the project gained a scene since it was read.
	EventSheetViewportRowBuilder.note_path_moved(PROBE_SCRIPT, PROBE_MOVED, false)
	EventSheetSceneConnections.note_path_moved(PROBE_SCRIPT, PROBE_MOVED, false)
	EventSheetViewportRowBuilder.start_scene_script_refresh()
	EventSheetViewportRowBuilder.finish_scene_script_refresh()
	EventSheetSceneConnections.start_index_refresh()
	EventSheetSceneConnections.finish_index_refresh()
	var after_news: Array = heard.duplicate()
	EventSheetViewportRowBuilder.scene_index_changed = Callable()
	EventSheetSceneConnections.index_changed = Callable()
	return SUPPORT.pins(TEST_NAME, [
		["a re-read that agrees with the held index is not announced", after_same, [0, 0]],
		["one that disagrees is, once for each index", after_news, [1, 1]],
	])


## Dropping the index outright (what a test does between fixtures) ends a re-read in flight: what it brings
## would answer for files from before the drop.
static func _dropping_the_index_ends_a_re_read() -> bool:
	EventSheetViewportRowBuilder.clear_scene_script_index()
	EventSheetSceneConnections.clear_cache()
	EventSheetViewportRowBuilder.scene_using_script(PROBE_SCRIPT)
	EventSheetSceneConnections.scenes_using_script(PROBE_SCRIPT)
	EventSheetViewportRowBuilder.start_scene_script_refresh()
	EventSheetSceneConnections.start_index_refresh()
	EventSheetViewportRowBuilder.clear_scene_script_index()
	EventSheetSceneConnections.clear_cache()
	var passed: bool = SUPPORT.pins(TEST_NAME, [
		["no re-read is left running", [EventSheetViewportRowBuilder.scene_refresh_running(), EventSheetSceneConnections.index_refresh_running()], [false, false]],
		["and neither index is held", [EventSheetViewportRowBuilder._script_scene_scanned, EventSheetSceneConnections._scenes_by_script_built], [false, false]],
	])
	EventSheetViewportRowBuilder.finish_scene_script_refresh()
	EventSheetSceneConnections.finish_index_refresh()
	return SUPPORT.pin_value(TEST_NAME, "and finishing one that is gone changes nothing",
		[EventSheetViewportRowBuilder._script_scene_scanned, EventSheetSceneConnections._scenes_by_script_built], [false, false]) and passed
