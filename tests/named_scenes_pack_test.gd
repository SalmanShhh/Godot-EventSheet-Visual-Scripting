# Godot EventSheets - Named Scenes pack runtime behaviour.
#
# Loads the COMPILED NamedScenes autoload pack and drives it treeless (signals still emit on a bare
# instance, so the On Scene Ready trigger is proved for real): the name registry, the folder sweep
# over real .tscn files written to user://, preloading, the handoff record that belongs to the scene
# you arrive in, the addressing conditions, and the save-state round-trip.
#
# Go To Named Scene is the one verb that needs a scene tree, which the suite has none of
# (run_tests.gd works inside SceneTree._init, where Engine.get_main_loop() is still null). It is run
# against the SHIPPED source with `get_tree()` and `is_inside_tree()` redirected at a stand-in that
# records the change and hands back a current_scene, so the ORDER the verb promises - change first,
# announce only once the new scene exists - is what gets asserted. What those two names emit is
# pinned separately, off the file.
@tool
class_name NamedScenesPackTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const PACK := "res://eventsheet_addons/named_scenes/named_scenes_addon.gd"
const SCENE_DIR := "user://named_scenes_test"


static func run() -> bool:
	var all_passed: bool = true
	var script: GDScript = load(PACK)
	all_passed = _check("named scenes pack loads + parses", script != null, true) and all_passed
	if script == null:
		return all_passed
	all_passed = _test_annotations() and all_passed
	all_passed = _test_registry(script) and all_passed
	all_passed = _test_handoff_and_trigger(script) and all_passed
	all_passed = _test_go_to_named_scene() and all_passed
	all_passed = _test_persistence(script) and all_passed
	return all_passed


## The published contract, read off the shipped file.
static func _test_annotations() -> bool:
	var all_passed: bool = true
	var source: String = FileAccess.get_file_as_string(PACK)
	all_passed = _check("the trigger's signal carries the scene name",
		source.contains("signal scene_ready(scene_name: String)"), true) and all_passed
	all_passed = _check("and is published as On Scene Ready",
		source.contains("## @ace_trigger\n## @ace_name(\"On Scene Ready\")"), true) and all_passed
	all_passed = _check("Go To Named Scene emits an autoload call",
		source.contains("## @ace_codegen_template(\"NamedScenes.go_to_named_scene({scene_name})\")"), true) and all_passed
	all_passed = _check("and really changes the scene by the registered path",
		source.contains("get_tree().change_scene_to_file(path)"), true) and all_passed
	all_passed = _check("Current Scene Is is published as a condition",
		source.contains("## @ace_condition\n## @ace_name(\"Current Scene Is\")"), true) and all_passed
	all_passed = _check("the scene path field opens the scene picker",
		source.contains("## @ace_param_hint(scene_path scene_path)"), true) and all_passed
	return all_passed


## Register Scene, the folder sweep, Preload, and the reading verbs.
static func _test_registry(script: GDScript) -> bool:
	var all_passed: bool = true
	var scenes: Node = script.new()

	all_passed = _check("nothing is registered to begin with", scenes.scene_is_registered("arena"), false) and all_passed
	all_passed = _check("an unknown name has no path", scenes.path_of_named_scene("arena"), "") and all_passed
	scenes.register_scene("arena", "res://levels/arena.tscn")
	all_passed = _check("a registered name is known", scenes.scene_is_registered("arena"), true) and all_passed
	all_passed = _check("and answers with its path", scenes.path_of_named_scene("arena"), "res://levels/arena.tscn") and all_passed
	scenes.register_scene("arena", "res://levels/moved/arena.tscn")
	all_passed = _check("registering again replaces the path, so a boot sheet can re-run",
		scenes.path_of_named_scene("arena"), "res://levels/moved/arena.tscn") and all_passed
	scenes.register_scene("", "res://levels/nameless.tscn")
	all_passed = _check("a blank name is refused rather than stored", scenes.scene_is_registered(""), false) and all_passed

	# The folder sweep, over real files.
	_write_scene_folder()
	scenes.register_scenes_in_folder(SCENE_DIR)
	all_passed = _check("every .tscn in the folder registered under its file name",
		scenes.scene_is_registered("box"), true) and all_passed
	all_passed = _check("with its full path", scenes.path_of_named_scene("box"), SCENE_DIR + "/box.tscn") and all_passed
	all_passed = _check("a second scene in the same folder too", scenes.scene_is_registered("hub"), true) and all_passed
	all_passed = _check("and a file that is not a .tscn is left alone", scenes.scene_is_registered("notes"), false) and all_passed
	scenes.register_scenes_in_folder("user://no_such_folder_here")
	all_passed = _check("a missing folder warns and registers nothing", scenes.scene_is_registered("box"), true) and all_passed
	all_passed = _check("the names come back sorted", scenes.registered_scene_names(), ["arena", "box", "hub"]) and all_passed

	# Preloading.
	all_passed = _check("nothing is warmed yet", scenes.named_scene_is_preloaded("box"), false) and all_passed
	scenes.preload_named_scene("box")
	all_passed = _check("a preloaded scene reads as warmed", scenes.named_scene_is_preloaded("box"), true) and all_passed
	scenes.preload_named_scene("box")
	all_passed = _check("preloading twice is harmless", scenes.named_scene_is_preloaded("box"), true) and all_passed
	# A registered name whose file is not really there warns and warms nothing (the load errors
	# printed around here are that deliberate miss, not a failure).
	scenes.preload_named_scene("arena")
	all_passed = _check("a name whose .tscn is gone is not warmed", scenes.named_scene_is_preloaded("arena"), false) and all_passed
	scenes.preload_named_scene("nope")
	all_passed = _check("and an unregistered name cannot be warmed at all", scenes.named_scene_is_preloaded("nope"), false) and all_passed

	scenes.forget_named_scene("box")
	all_passed = _check("forgetting drops the name", scenes.scene_is_registered("box"), false) and all_passed
	all_passed = _check("and drops what was warmed for it", scenes.named_scene_is_preloaded("box"), false) and all_passed

	scenes.free()
	_clear_scene_folder()
	return all_passed


## Carry Into Next Scene, the On Scene Ready trigger, and the addressing family.
static func _test_handoff_and_trigger(script: GDScript) -> bool:
	var all_passed: bool = true
	var scenes: Node = script.new()
	var announced: Array = []
	scenes.scene_ready.connect(func(scene_name: String) -> void: announced.append(scene_name))

	all_passed = _check("before the first scene, no name is current", scenes.current_scene_name(), "") and all_passed
	all_passed = _check("and Current Scene Is answers no", scenes.current_scene_is("hub"), false) and all_passed

	scenes.carry_into_next_scene({"from": "hub", "door": "east", "attempt": 3})
	all_passed = _check("the record belongs to the NEXT scene, not this one",
		scenes.has_scene_argument("door"), false) and all_passed
	scenes.announce_scene_ready("arena")
	all_passed = _check("the trigger fired once", announced.size(), 1) and all_passed
	all_passed = _check("carrying the scene name as its argument", str(announced[0]), "arena") and all_passed
	all_passed = _check("the arrival scene is now current", scenes.current_scene_name(), "arena") and all_passed
	all_passed = _check("Current Scene Is answers the name", scenes.current_scene_is("arena"), true) and all_passed
	all_passed = _check("and no other", scenes.current_scene_is("hub"), false) and all_passed
	all_passed = _check("the carried record is readable now", scenes.has_scene_argument("door"), true) and all_passed
	all_passed = _check("Scene Argument reads it as text", scenes.scene_argument("door", ""), "east") and all_passed
	all_passed = _check("Scene Argument Number reads it as a number", scenes.scene_argument_number("attempt", 0.0), 3.0) and all_passed
	all_passed = _check("a key nobody carried answers the fallback", scenes.scene_argument("colour", "grey"), "grey") and all_passed
	all_passed = _check("and the numeric fallback too", scenes.scene_argument_number("speed", 2.5), 2.5) and all_passed
	all_passed = _check("Has Scene Argument tells a missing key apart from a default",
		scenes.has_scene_argument("colour"), false) and all_passed

	# Arriving somewhere with nothing carried clears the previous scene's record, so a level can
	# never read the arguments of the one before it.
	scenes.announce_scene_ready("hub")
	all_passed = _check("the second arrival fired too", announced.size(), 2) and all_passed
	all_passed = _check("with its own name", str(announced[1]), "hub") and all_passed
	all_passed = _check("and the old record did not follow it", scenes.has_scene_argument("door"), false) and all_passed
	scenes.free()
	return all_passed


## Go To Named Scene, against the shipped source with the tree redirected at a stand-in.
static func _test_go_to_named_scene() -> bool:
	var all_passed: bool = true
	var script: GDScript = _harness_script()
	all_passed = _check("the stand-in harness parses", script != null, true) and all_passed
	if script == null:
		return all_passed

	var fake_script: GDScript = GDScript.new()
	fake_script.source_code = "extends Node\n\nsignal process_frame\n\nvar current_scene: Node = null\nvar changed_to: String = \"\"\nvar change_result: int = OK\n\nfunc change_scene_to_file(path: String) -> int:\n\tchanged_to = path\n\treturn change_result\n"
	all_passed = _check("the tree stand-in parses", fake_script.reload(), OK) and all_passed
	var fake: Node = Node.new()
	fake.set_script(fake_script)

	var scenes: Node = script.new()
	scenes.fake_tree = fake
	scenes.in_tree = true
	var announced: Array = []
	scenes.scene_ready.connect(func(scene_name: String) -> void: announced.append(scene_name))

	scenes.go_to_named_scene("nowhere")
	all_passed = _check("an unregistered name changes nothing", fake.changed_to, "") and all_passed
	all_passed = _check("and announces nothing", announced.size(), 0) and all_passed

	scenes.register_scene("arena", "res://levels/arena.tscn")
	scenes.carry_into_next_scene({"door": "east"})
	scenes.go_to_named_scene("arena")
	all_passed = _check("the change is asked for by the registered path", fake.changed_to, "res://levels/arena.tscn") and all_passed
	all_passed = _check("but nothing is announced while the new scene is not there yet", announced.size(), 0) and all_passed

	# Still nothing: a frame passed but current_scene has not come back.
	fake.process_frame.emit()
	all_passed = _check("a frame on its own is not enough", announced.size(), 0) and all_passed

	fake.current_scene = Node.new()
	fake.process_frame.emit()
	all_passed = _check("once the new scene exists, On Scene Ready fires", announced.size(), 1) and all_passed
	all_passed = _check("with the name that was asked for", str(announced[0]), "arena") and all_passed
	all_passed = _check("the handoff arrives with it", scenes.scene_argument("door", ""), "east") and all_passed
	all_passed = _check("and Current Scene Is now answers it", scenes.current_scene_is("arena"), true) and all_passed

	# A registered name whose .tscn has since been moved or broken: change_scene_to_file refuses, the
	# outgoing scene stays on screen, and announcing readiness here would run the new level's setup
	# rows against the OLD scene. Nothing may be announced, and the current name must not move.
	fake.change_result = ERR_CANT_OPEN
	scenes.register_scene("vault", "res://levels/vault.tscn")
	scenes.go_to_named_scene("vault")
	fake.process_frame.emit()
	fake.process_frame.emit()
	all_passed = _check("a scene that cannot be opened announces nothing", announced.size(), 1) and all_passed
	all_passed = _check("and leaves the scene you are in as the current one",
		scenes.current_scene_is("arena"), true) and all_passed

	fake.current_scene.free()
	scenes.free()
	fake.free()
	return all_passed


## Save state carries the registry, the current name and the handoff.
static func _test_persistence(script: GDScript) -> bool:
	var all_passed: bool = true
	var scenes: Node = script.new()
	scenes.register_scene("arena", "res://levels/arena.tscn")
	scenes.carry_into_next_scene({"door": "east"})
	scenes.announce_scene_ready("arena")
	var state: Dictionary = scenes.save_state()
	var restored: Node = script.new()
	restored.load_state(state)
	all_passed = _check("the registry survives a save round-trip",
		restored.path_of_named_scene("arena"), "res://levels/arena.tscn") and all_passed
	all_passed = _check("the current scene name too", restored.current_scene_name(), "arena") and all_passed
	all_passed = _check("and the handoff the scene arrived with", restored.scene_argument("door", ""), "east") and all_passed
	restored.load_state({})
	all_passed = _check("an empty state changes nothing", restored.current_scene_name(), "arena") and all_passed
	scenes.free()
	restored.free()
	return all_passed


## Two real .tscn files plus one that is not, so the folder sweep is proved to filter.
static func _write_scene_folder() -> void:
	DirAccess.make_dir_recursive_absolute(SCENE_DIR)
	for scene_name: String in ["box", "hub"]:
		var root: Node = Node.new()
		root.name = scene_name
		var packed: PackedScene = PackedScene.new()
		packed.pack(root)
		ResourceSaver.save(packed, "%s/%s.tscn" % [SCENE_DIR, scene_name])
		root.free()
	var notes: FileAccess = FileAccess.open(SCENE_DIR + "/notes.txt", FileAccess.WRITE)
	notes.store_string("not a scene")
	notes.close()


static func _clear_scene_folder() -> void:
	for file_name: String in DirAccess.get_files_at(SCENE_DIR):
		DirAccess.remove_absolute(SCENE_DIR.path_join(file_name))
	DirAccess.remove_absolute(SCENE_DIR)


## The shipped pack source with its class_name and icon dropped (an in-memory script cannot claim a
## global class name that is already registered) and the two tree names redirected at stand-ins.
static func _harness_script() -> GDScript:
	var kept: PackedStringArray = PackedStringArray()
	for line: String in FileAccess.get_file_as_string(PACK).split("\n"):
		if line.begins_with("class_name ") or line.begins_with("@icon("):
			continue
		kept.append(line)
	var text: String = "\n".join(kept).replace("get_tree()", "_tree()").replace("is_inside_tree()", "_in_tree()")
	text += "\n\nvar fake_tree: Object = null\nvar in_tree: bool = false\n\nfunc _tree() -> Object:\n\treturn fake_tree\n\nfunc _in_tree() -> bool:\n\treturn in_tree\n"
	var script: GDScript = GDScript.new()
	script.source_code = text
	return script if script.reload() == OK else null


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("named_scenes_pack_test", label, actual, expected)
