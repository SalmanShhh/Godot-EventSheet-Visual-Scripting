# EventForge - the project-wide fact caches must be droppable, and the dock must drop them.
#
# THE CONTRACT: several reads behind what a row SAYS are project-wide and were kept for the whole
# session - the .tscn index that names the object a script drives (object labels, sheet titles,
# thumbnails), the Input Map read out of project.godot (every row that names an action), and what
# the scene says about its lighting (the head's bands, the picker's shelf, and the gate the lift
# asks before claiming a line as a light row). A scene saved or an action added mid-session left
# every one of them answering for a project that no longer exists.
#
# They are now dropped from the dock's editor hooks: the filesystem ping drops the scene index, the
# Input Map and the lighting reads, and Project Settings changing drops the Input Map (adding an
# action there never touches the filesystem scan, so the file hook alone could not see it). This
# pins the droppers themselves AND the wiring, because a working clear that nothing calls is the bug
# it was - and it is the bug each of these was, one at a time.
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

	# ── The scene's LIGHTING drops and rebuilds ─────────────────────────────────────────────
	# The same shape again, and the sharpest case of it: what class a node reference is, which is the
	# gate the lift asks before claiming a line as a light row. Held for the session, a light added to
	# the scene stayed invisible and a deleted one went on being claimed until the editor restarted.
	var lit_script: String = "res://tests/fixtures/lighting_scene_room.gd"
	var warm_lights: int = EventSheetSceneLights.for_script(lit_script).size()
	all_passed = _check("the room's lights are read off its scene", warm_lights, 3) and all_passed
	EventSheetSceneLights.clear_cache()
	all_passed = _check("clear_cache() empties the scene read",
		EventSheetSceneLights._cache.size(), 0) and all_passed
	all_passed = _check("the next question re-reads the scene and answers the same",
		EventSheetSceneLights.for_script(lit_script).size(), warm_lights) and all_passed
	all_passed = _check("the class behind a node reference comes back too",
		str(EventSheetSceneLights.classes_for_script(lit_script).get(
			EventSheetSceneLights.reference_key("$Torch"), "")), "PointLight2D") and all_passed

	# ── What the scene says about its EFFECTS drops and rebuilds ───────────────────────────
	# Three reads, one chain: which node wears which material, which shader is at the end of it, and
	# which nodes of the whole project wear the same file. A uniform renamed in the shader has to
	# reach the rows naming it, and a scene saved has to restart the project-wide count.
	var worn_script: String = "res://tests/fixtures/effect_scene_goblin.gd"
	var warm_wearers: int = EventSheetSceneEffects.for_script(worn_script).size()
	all_passed = _check("the goblin's wearing nodes are read off its scene",
		warm_wearers, 2) and all_passed
	var warm_dials: int = EventForgeShaderUniforms.names_of(
		"res://tests/fixtures/effect_dissolve.gdshader").size()
	EventSheetProjectShareIndex.build_now()
	var warm_shared: int = EventSheetProjectShareIndex.wearers_of(
		"res://tests/fixtures/effect_shared_material.tres").size()
	all_passed = _check("and every node of the project wearing the shared material",
		warm_shared, 3) and all_passed
	EventSheetSceneEffects.clear_cache()
	EventForgeShaderUniforms.clear_cache()
	EventSheetProjectShareIndex.clear_cache()
	all_passed = _check("clear_cache() empties all three", PackedStringArray([
		str(EventSheetSceneEffects._cache.size()), str(EventForgeShaderUniforms._cache.size()),
		str(EventSheetProjectShareIndex.is_ready())]),
		PackedStringArray(["0", "0", "false"])) and all_passed
	EventSheetProjectShareIndex.build_now()
	all_passed = _check("the next question re-reads the files and answers the same",
		PackedStringArray([str(EventSheetSceneEffects.for_script(worn_script).size()),
			str(EventForgeShaderUniforms.names_of(
				"res://tests/fixtures/effect_dissolve.gdshader").size()),
			str(EventSheetProjectShareIndex.wearers_of(
				"res://tests/fixtures/effect_shared_material.tres").size())]),
		PackedStringArray([str(warm_wearers), str(warm_dials), str(warm_shared)])) and all_passed

	# ── The parse UNDER all of those, and the file identity under that ──────────────────────
	# Every scene reader in the plugin walks one shared node list per file, and every by-file reader
	# asks one shared place what a file's cache identity is. Both are what make a warm read cost
	# nothing at all; both would serve a saved answer for a changed file if the clear did not reach
	# them, which is why the two pins below are IDENTITY pins - the same array back, not an equal one.
	var scene_path: String = "res://tests/fixtures/lighting_scene_room.tscn"
	var parsed: Array = EventSheetSceneConnections.nodes_of_scene(scene_path)
	all_passed = _check("the scene's nodes are read", parsed.size() > 1, true) and all_passed
	all_passed = _check("asking again hands back the SAME parse, not another one",
		is_same(parsed, EventSheetSceneConnections.nodes_of_scene(scene_path)), true) and all_passed
	var stamp: String = EventForgeFileStamp.of(scene_path)
	all_passed = _check("a file's identity carries its path, its mtime and its length",
		stamp.split("|").size(), 3) and all_passed
	all_passed = _check("and is held, so asking twice is the same answer",
		EventForgeFileStamp.of(scene_path), stamp) and all_passed
	EventSheetSceneConnections.clear_cache()
	all_passed = _check("clear_cache() drops the parse and its stamps", PackedStringArray([
		str(EventSheetSceneConnections._nodes_cache.size()),
		str(EventForgeFileStamp._stamps.size())]),
		PackedStringArray(["0", "0"])) and all_passed
	var reparsed: Array = EventSheetSceneConnections.nodes_of_scene(scene_path)
	all_passed = _check("the next question parses the file again and answers the same",
		reparsed.size(), parsed.size()) and all_passed
	all_passed = _check("and it really is a fresh parse, not the dropped one",
		is_same(reparsed, parsed), false) and all_passed
	# Which scenes load a script is an INDEX now, built in one pass. It used to be a read of every
	# scene in the project per script asked about, which is what made opening a twelve-line file cost
	# a tenth of a second for no reason the file could explain.
	all_passed = _check("the scene that loads a script is found through the index",
		", ".join(EventSheetSceneConnections.scenes_using_script(
			"res://tests/fixtures/lighting_scene_room.gd")),
		"res://tests/fixtures/lighting_scene_room.tscn") and all_passed
	all_passed = _check("and a script no scene loads is named by none",
		EventSheetSceneConnections.scenes_using_script(DOCK_PATH).size(), 0) and all_passed

	# ── The project's own script list ───────────────────────────────────────────────────────
	# Around forty health checks ask for it, so it is walked once and handed out; an audit drops it
	# first, and so does the filesystem hook, or a file added since the last audit would be invisible.
	var listed: PackedStringArray = EventSheetProjectDoctor._project_scripts()
	all_passed = _check("the project's scripts are listed", listed.size() > 100, true) and all_passed
	EventSheetProjectDoctor.clear_project_scripts()
	all_passed = _check("clear_project_scripts() puts it back to unwalked",
		EventSheetProjectDoctor._project_scripts_walked, false) and all_passed
	all_passed = _check("and the next ask walks again and finds the same files",
		EventSheetProjectDoctor._project_scripts().size(), listed.size()) and all_passed

	# ── The dock actually calls both ────────────────────────────────────────────────────────
	# Source lint, not a live dock: constructing the dock needs a display server. What matters is
	# that the two hooks name the droppers, and that both hooks are connected at all.
	var dock_source: String = _read(DOCK_PATH)
	var filesystem_hook: String = _function_body(dock_source, "func _on_translations_maybe_changed()")
	all_passed = _check("the filesystem hook drops the scene index",
		filesystem_hook.contains("ViewportRowBuilder.clear_scene_script_index()"), true) and all_passed
	all_passed = _check("the filesystem hook drops the Input Map read",
		filesystem_hook.contains("EventSheetInputMapFacts.clear_cache()"), true) and all_passed
	all_passed = _check("the filesystem hook drops what the scene said about its lights",
		filesystem_hook.contains("EventSheetSceneLights.clear_cache()"), true) and all_passed
	all_passed = _check("and the environment-sharing scan behind the head's band",
		filesystem_hook.contains("EventSheetSceneLightingFacts.clear_cache()"), true) and all_passed
	all_passed = _check("the filesystem hook drops what the scene said about its effects",
		filesystem_hook.contains("EventSheetSceneEffects.clear_cache()"), true) and all_passed
	all_passed = _check("and the shader files' own dials",
		filesystem_hook.contains("EventForgeShaderUniforms.clear_cache()"), true) and all_passed
	all_passed = _check("and the project-wide scan behind every sharing count",
		filesystem_hook.contains("EventSheetProjectShareIndex.clear_cache()"), true) and all_passed
	all_passed = _check("and the shared scene parse the lighting and effect reads sit on",
		filesystem_hook.contains("EventSheetSceneConnections.clear_cache()"), true) and all_passed
	all_passed = _check("and the listing of the project's own scripts",
		filesystem_hook.contains("EventSheetProjectDoctor.clear_project_scripts()"), true) and all_passed
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
