# Godot EventSheets - the first read of the scene indexes, made in the editor's idle time.
#
# Four promises:
#   1. IT IS THE SAME ANSWER. What the idle read brings - the scene list, which scenes load a script, which
#      script each scene's root carries - is exactly what the two synchronous builds return over the same
#      project, in the same order.
#   2. IT IS TAKEN ONCE, AND NEVER TWICE READ. A question asked while the read is under way waits for it and
#      gets it; a second question finds nothing left to take and falls back to the ordinary build.
#   3. A CHANGE DROPS IT. A file changed, moved or removed while it is held or being read means it is never
#      handed over: the questions that follow read the project as it is.
#   4. THE READERS TAKE IT. The scene reader and the row builder answer from it when it is there, and answer
#      the same either way.
@tool
class_name SceneIndexPrepTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "scene_index_prep_test"
const PREP := preload("res://addons/eventforge/importer/scene_index_prep.gd")
const ROOTS := preload("res://addons/eventforge/importer/scene_root_sweep.gd")


static func run() -> bool:
	_reset()
	var ok: bool = _the_same_answer()
	ok = _taken_once() and ok
	ok = _a_change_drops_it() and ok
	ok = _the_readers_take_it() and ok
	_reset()
	return ok


## What the two synchronous builds return, read straight from the project.
static func _sync_paths() -> PackedStringArray:
	var paths: PackedStringArray = PackedStringArray()
	EventSheetSceneConnections._walk_scene_paths("res://", paths)
	paths.sort()
	return paths


## A read started afresh.
static func _fresh() -> void:
	PREP.stop()
	PREP.start()


## Until the thread has finished reading, so what follows does not depend on how fast it was.
static func _wait() -> void:
	while PREP.running():
		OS.delay_msec(2)


static func _reset() -> void:
	PREP.stop()
	EventSheetSceneConnections.clear_cache()
	EventSheetViewportRowBuilder.clear_scene_script_index()


static func _the_same_answer() -> bool:
	var expected_paths: PackedStringArray = _sync_paths()
	var expected_index: Dictionary = EventSheetSceneConnections.index_scenes(expected_paths)
	var expected_roots: Dictionary = ROOTS.sweep_scenes_under("res://")
	var started: bool = PREP.start()
	var connections: Variant = PREP.take_connections()
	var roots: Variant = PREP.take_roots()
	var rows: Array = [
		["a read starts", started, true],
		["the project has scenes to read", expected_paths.size() > 0, true],
		["the scene list is the sorted walk", (connections as Dictionary)["paths"] if connections != null else null, expected_paths],
		["the index of scenes by script is the synchronous one", (connections as Dictionary)["index"] if connections != null else null, expected_index],
		["the roots are the synchronous ones", roots, expected_roots],
		["the row builder's own sweep is that same sweep", EventSheetViewportRowBuilder.sweep_scenes_under("res://"), expected_roots],
	]
	return SUPPORT.pins(P, rows)


static func _taken_once() -> bool:
	_reset()
	PREP.start()
	var first: Variant = PREP.take_connections()
	var second: Variant = PREP.take_connections()
	var roots_first: Variant = PREP.take_roots()
	var roots_second: Variant = PREP.take_roots()
	var rows: Array = [
		["the first ask gets the connections", first != null, true],
		["the second finds none left", second, null],
		["the first ask gets the roots", roots_first != null, true],
		["the second finds none left", roots_second, null],
		["nothing is pending after both were taken", PREP.pending(), false],
	]
	# Both first reads were asked for: a change after that starts nothing, the readers keep their own indexes current.
	var reads: int = PREP.reads_started
	PREP.invalidate()
	rows.append(["nothing is read again for an index that was asked for", [PREP.start(), PREP.reads_started], [false, reads]])
	rows.append(["a started read is waited for, not raced: ask at once, get the whole answer", _asks_at_once(), true])
	_reset()
	return SUPPORT.pins(P, rows)


## Starts a read and asks in the same breath, before the thread can have finished: the answer must be whole.
static func _asks_at_once() -> bool:
	PREP.stop()
	PREP.start()
	var connections: Variant = PREP.take_connections()
	var whole: bool = connections != null and (connections as Dictionary)["paths"] == _sync_paths()
	PREP.stop()
	return whole


static func _a_change_drops_it() -> bool:
	_reset()
	var rows: Array = []
	# A change while the read is under way: it is thrown away when it arrives.
	_fresh()
	PREP.invalidate()
	rows.append(["a change during the read leaves nothing to take", [PREP.take_connections(), PREP.take_roots()], [null, null]])
	# A change after the read finished, before anything took it.
	_fresh()
	_wait()
	var finished: Variant = PREP.take_connections()
	rows.append(["a finished read is there to take", finished != null, true])
	_fresh()
	_wait()
	PREP.invalidate()
	rows.append(["a finished read a change made stale is dropped", [PREP.take_connections(), PREP.take_roots()], [null, null]])
	# The reader's own change notices reach it.
	_fresh()
	EventSheetSceneConnections.files_changed()
	rows.append(["the editor's filesystem change drops it", PREP.take_connections(), null])
	_fresh()
	EventSheetSceneConnections.note_path_moved("res://no_such_scene_a.tscn", "res://no_such_scene_b.tscn", false)
	rows.append(["a move drops it", PREP.take_connections(), null])
	_fresh()
	EventSheetViewportRowBuilder.refresh_scene_script_index()
	rows.append(["the row builder's change notice drops it", PREP.take_roots(), null])
	# After a drop a new read is made, and it is whole again.
	PREP.stop()
	var restarted: bool = PREP.start()
	var again: Variant = PREP.take_connections()
	rows.append(["a new read after a drop is made and is whole", [restarted, again != null and (again as Dictionary)["paths"] == _sync_paths()], [true, true]])
	# A stale finished read lets go on start, and stop joins a running one.
	_fresh()
	PREP.invalidate()
	_wait()
	rows.append(["a read a change made stale makes way for a new one", PREP.start(), true])
	PREP.stop()
	rows.append(["stop leaves nothing pending", PREP.pending(), false])
	_reset()
	return SUPPORT.pins(P, rows)


static func _the_readers_take_it() -> bool:
	_reset()
	var rows: Array = []
	var scenes: PackedStringArray = _sync_paths()
	var expected_index: Dictionary = EventSheetSceneConnections.index_scenes(scenes)
	var expected_roots: Dictionary = ROOTS.sweep_scenes_under("res://")
	var script_path: String = ""
	for candidate: Variant in expected_index:
		script_path = str(candidate)
		break
	var root_script: String = ""
	for candidate: Variant in expected_roots:
		root_script = str(candidate)
		break
	rows.append(["the project has a script some scene loads", script_path.is_empty(), false])
	rows.append(["the project has a script some scene roots", root_script.is_empty(), false])
	# The scene reader answers from the read and answers what a synchronous build would.
	PREP.start()
	rows.append(["the scene reader answers the scenes of a script", EventSheetSceneConnections.scenes_using_script(script_path), expected_index.get(script_path, PackedStringArray())])
	rows.append(["and the scene list", EventSheetSceneConnections.scene_paths(), scenes])
	rows.append(["and the read has been taken from", PREP.take_connections(), null])
	_reset()
	# The scene list asked first adopts the whole read, and the index after it is the same.
	PREP.start()
	rows.append(["the scene list asked first is the sorted walk", EventSheetSceneConnections.scene_paths(), scenes])
	rows.append(["and the index asked after it is the synchronous one", EventSheetSceneConnections.scenes_using_script(script_path), expected_index.get(script_path, PackedStringArray())])
	_reset()
	# The row builder answers from the read as well.
	PREP.start()
	rows.append(["the row builder answers the scene a script roots", EventSheetViewportRowBuilder.scene_using_script(root_script), (expected_roots[root_script] as Array)[0] if expected_roots.has(root_script) else {}])
	rows.append(["and the read's roots have been taken", PREP.take_roots(), null])
	# An index a reader built for itself needs no read: only the other one is started.
	_reset()
	EventSheetSceneConnections.scenes_using_script(script_path)
	PREP.stop()
	EventSheetSceneConnections.scenes_using_script(script_path)
	rows.append(["a read for an index that is already held is not started", PREP.start(), true])
	var only_roots: Variant = PREP.take_connections()
	rows.append(["and what it read does not include that index", only_roots, null])
	# With nothing read, both readers build as they always did.
	_reset()
	rows.append(["without a read the scene reader builds the same index", EventSheetSceneConnections.scenes_using_script(script_path), expected_index.get(script_path, PackedStringArray())])
	rows.append(["and the row builder the same roots", EventSheetViewportRowBuilder.scene_using_script(root_script), (expected_roots[root_script] as Array)[0] if expected_roots.has(root_script) else {}])
	# A change after a read began makes the readers build for themselves, and they get the project as it is.
	_reset()
	PREP.start()
	EventSheetSceneConnections.files_changed()
	rows.append(["after a change the scene reader still answers the synchronous index", EventSheetSceneConnections.scenes_using_script(script_path), expected_index.get(script_path, PackedStringArray())])
	_reset()
	return SUPPORT.pins(P, rows)
