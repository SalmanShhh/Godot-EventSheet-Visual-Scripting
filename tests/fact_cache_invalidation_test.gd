# EventForge - the project-wide fact caches must be droppable, and the dock must drop them.
#
# THE CONTRACT: two reads behind what a row SAYS are project-wide and were kept for the whole
# session - the .tscn index that names the object a script drives (object labels, sheet titles,
# thumbnails) and the Input Map read out of project.godot (every row that names an action). A scene
# saved or an action added mid-session left both answering for a project that no longer exists.
#
# Both are now dropped from the dock's editor hooks: the filesystem ping drops the scene index and
# the Input Map, and Project Settings changing drops the Input Map (adding an action there never
# touches the filesystem scan, so the file hook alone could not see it). This pins the droppers
# themselves AND the wiring, because a working clear that nothing calls is the bug it was.
@tool
class_name FactCacheInvalidationTest
extends RefCounted

const DOCK_PATH := "res://addons/eventsheet/editor/event_sheet_dock.gd"


static func run() -> bool:
	var all_passed: bool = true

	# ── The scene index drops and rebuilds ──────────────────────────────────────────────────
	# Warm it on a real project script, then drop it: the flag must go back to unscanned, and the
	# very next question must answer the same thing again (a drop that broke the rebuild would
	# silently blank every object label).
	var probe_script: String = "res://demo/showcase/family_arena/enemy.gd"
	var warm_answer: Dictionary = ViewportRowBuilder.scene_using_script(probe_script)
	all_passed = _check("the index is marked scanned once it has answered",
		ViewportRowBuilder._script_scene_scanned, true) and all_passed
	ViewportRowBuilder.clear_scene_script_index()
	all_passed = _check("clear_scene_script_index() puts it back to unscanned",
		ViewportRowBuilder._script_scene_scanned, false) and all_passed
	all_passed = _check("clear_scene_script_index() empties the index",
		ViewportRowBuilder._script_scene_cache.size(), 0) and all_passed
	var rebuilt_answer: Dictionary = ViewportRowBuilder.scene_using_script(probe_script)
	all_passed = _check("the next question re-sweeps and answers the same",
		str(rebuilt_answer), str(warm_answer)) and all_passed

	# ── The Input Map read drops and rebuilds ───────────────────────────────────────────────
	var warm_actions: PackedStringArray = EventSheetInputMapFacts.project_action_names()
	all_passed = _check("the project's own actions are read",
		warm_actions.size() > 0, true) and all_passed
	EventSheetInputMapFacts.clear_cache()
	all_passed = _check("clear_cache() empties the read",
		EventSheetInputMapFacts._cache.size(), 0) and all_passed
	all_passed = _check("the next question re-reads project.godot and answers the same",
		", ".join(EventSheetInputMapFacts.project_action_names()),
		", ".join(warm_actions)) and all_passed

	# ── The dock actually calls both ────────────────────────────────────────────────────────
	# Source lint, not a live dock: constructing the dock needs a display server. What matters is
	# that the two hooks name the droppers, and that both hooks are connected at all.
	var dock_source: String = _read(DOCK_PATH)
	var filesystem_hook: String = _function_body(dock_source, "func _on_translations_maybe_changed()")
	all_passed = _check("the filesystem hook drops the scene index",
		filesystem_hook.contains("ViewportRowBuilder.clear_scene_script_index()"), true) and all_passed
	all_passed = _check("the filesystem hook drops the Input Map read",
		filesystem_hook.contains("EventSheetInputMapFacts.clear_cache()"), true) and all_passed
	var settings_hook: String = _function_body(dock_source, "func _on_project_settings_changed()")
	all_passed = _check("the settings hook drops the Input Map read",
		settings_hook.contains("EventSheetInputMapFacts.clear_cache()"), true) and all_passed
	all_passed = _check("the filesystem hook is connected",
		dock_source.contains("filesystem.connect(\"filesystem_changed\", _on_translations_maybe_changed)"),
		true) and all_passed
	all_passed = _check("the Project Settings hook is connected",
		dock_source.contains("ProjectSettings.connect(\"settings_changed\", _on_project_settings_changed)"),
		true) and all_passed
	return all_passed


## One function's body, from its `func` line to the next top-level `func` (or the end).
static func _function_body(source: String, signature: String) -> String:
	var start: int = source.find(signature)
	if start < 0:
		return ""
	var rest: String = source.substr(start + signature.length())
	var end: int = rest.find("\nfunc ")
	return rest if end < 0 else rest.substr(0, end)


static func _read(path: String) -> String:
	var handle: FileAccess = FileAccess.open(path, FileAccess.READ)
	if handle == null:
		return ""
	var text: String = handle.get_as_text()
	handle.close()
	return text


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] fact_cache_invalidation_test: %s" % label)
		return true
	print("[FAIL] fact_cache_invalidation_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
