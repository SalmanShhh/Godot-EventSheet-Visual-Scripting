# Godot EventSheets - the data-and-settings slice: settings that declare themselves (the Game
# Settings pack), a spawn you can name and talk to afterwards, and live data (watch a file, validate
# a folder).
#
# Every verb here is pinned TWICE: once on the code it emits, and once on what that code DOES when
# it runs. The runtime half matters more than usual in this slice, because all three families lean
# on things a template test cannot see - a signal's payload arriving at a handler, node metadata
# surviving between two rows, and a folder walk that has to answer correctly for a folder that is
# not there.
#
# Three traps this file is written around:
#   1. A file's modification time has ONE SECOND of resolution, so "write it twice quickly" is not a
#      detectable change. The watch test therefore uses a real change with no clock in it: seed the
#      stamp while the file is absent, then create it.
#   2. The pack declares a NEW class_name, which a headless --script run cannot resolve until the
#      editor's class cache is regenerated - so the pack is reached by load(path), never by name.
#   3. A trigger is only proven by connecting to it: every signal assertion below reads the ARGUMENTS
#      the handler received, not merely that an emit line was emitted.
@tool
class_name DataAndSettingsTest
extends RefCounted

const PACK_PATH := "res://eventsheet_addons/game_settings/game_settings_addon.gd"
const WORK_DIR := "user://data_and_settings_test"

## The item script the folder-validation fixtures use: a data asset with an id, which is what the
## folder report reads. It is written to disk because a GDScript built from a source string has no
## resource_path, and a .tres saved against one cannot be loaded back.
const ITEM_SCRIPT_SOURCE := "extends Resource\n\n\n@export var id: String = \"\"\n"


static func run() -> bool:
	var ok: bool = true
	ok = _test_settings_pack_shape() and ok
	ok = _test_settings_runtime() and ok
	ok = _test_settings_persistence() and ok
	ok = _test_spawn_templates() and ok
	ok = _test_spawn_runtime() and ok
	ok = _test_spawn_trigger_compiles() and ok
	ok = _test_live_data_templates() and ok
	ok = _test_live_data_trigger_compiles() and ok
	ok = _test_watch_data_file_runtime() and ok
	ok = _test_data_folder_runtime() and ok
	return ok


# ── #22 Settings that declare themselves ────────────────────────────────────────────────


## The trigger is a REAL signal with both payload arguments on the signal line, and the four kinds
## are annotated as the four kinds (an expression published as an action is the failure this catches).
static func _test_settings_pack_shape() -> bool:
	var ok: bool = true
	var source: String = FileAccess.get_file_as_string(PACK_PATH)
	ok = _pin(ok, source.contains("signal setting_changed(setting_name: String, value: Variant)"),
		true, "the trigger is a declared signal carrying the name AND the new value")
	ok = _pin(ok, source.contains("## @ace_trigger\n## @ace_name(\"On Setting Changed\")"),
		true, "the signal is published as the On Setting Changed trigger")
	ok = _pin(ok, source.contains("## @ace_expression\n## @ace_name(\"Setting Value\")"),
		true, "Setting Value publishes as an expression, not an action")
	ok = _pin(ok, source.contains("## @ace_condition\n## @ace_name(\"Changed Setting Is\")"),
		true, "Changed Setting Is publishes as a condition")
	ok = _pin(ok, source.contains("## @ace_condition\n## @ace_name(\"Setting Is\")"),
		true, "Setting Is publishes as a condition")
	ok = _pin(ok, source.contains("## @ace_action\n## @ace_featured\n## @ace_name(\"Declare Setting\")"),
		true, "Declare Setting publishes as a featured action")
	ok = _pin(ok, source.contains("const SETTINGS_FILE: String = \"user://settings.cfg\""),
		true, "settings persist in the same file the built-in Save Setting writes")
	return ok


## The whole reaction loop, end to end: declare, read the default before anything is saved, change
## one and receive the trigger with its payload, branch on it, and re-apply them all.
static func _test_settings_runtime() -> bool:
	var ok: bool = true
	var settings: Node = _new_settings()
	var watcher: SettingsWatcher = SettingsWatcher.new()
	settings.connect("setting_changed", Callable(watcher, "on_changed"))

	settings.call("declare_setting", "master_volume", 80, "percent", "")
	settings.call("declare_setting", "difficulty", "normal", "choice", "easy|normal|hard")
	settings.call("declare_setting", "screen_shake", true, "toggle", "")

	# The point of declaring: the default is in force before anything was ever saved.
	ok = _pin(ok, settings.call("setting_value", "master_volume"), 80,
		"an unsaved setting reads its declared default")
	ok = _pin(ok, settings.call("setting_value", "nothing_here"), null,
		"an undeclared name reads as nothing at all")
	ok = _pin(ok, settings.call("setting_is", "difficulty", "normal"), true,
		"Setting Is compares against the default too")

	# Changing one fires the trigger, and the PAYLOAD is what the handler receives.
	settings.call("set_setting", "master_volume", 35)
	ok = _pin(ok, watcher.calls, 1, "changing a setting fires On Setting Changed exactly once")
	ok = _pin(ok, watcher.last_name, "master_volume", "the trigger carries the setting's name")
	ok = _pin(ok, watcher.last_value, 35, "the trigger carries the NEW value")
	ok = _pin(ok, settings.call("setting_value", "master_volume"), 35, "and the value is in force")

	# The edge case the blurb promises: setting it to what it already holds is not a change.
	settings.call("set_setting", "master_volume", 35)
	ok = _pin(ok, watcher.calls, 1, "setting a value it already holds fires nothing")

	# An undeclared name is refused rather than quietly stored.
	settings.call("set_setting", "not_declared", 1)
	ok = _pin(ok, settings.call("setting_value", "not_declared"), null,
		"setting an undeclared name stores nothing")
	ok = _pin(ok, watcher.calls, 1, "and fires nothing")

	# Changed Setting Is answers about the setting being announced, and KEEPS answering once the
	# announcement is over. That second half is load-bearing: setting_changed.emit() returns at the
	# first suspension point of any handler that waits, so a reaction with a Wait row in it resumes
	# long after the announcing stack has been popped - and used to find this condition gone false
	# halfway through its own event, silently skipping the rest of the reaction.
	ok = _pin(ok, settings.call("changed_setting_is", "master_volume"), true,
		"after the announcement it still names the setting that changed")
	ok = _pin(ok, settings.call("changed_setting_is", "difficulty"), false,
		"and answers false for any other setting")
	ok = _pin(ok, _asks_after_resuming(settings, "master_volume"), true,
		"so a reaction that resumes after waiting can still branch on it")
	watcher.ask_settings = settings
	watcher.ask_name = "difficulty"
	settings.call("set_setting", "difficulty", "hard")
	ok = _pin(ok, watcher.asked_answer, true,
		"inside the reaction, Changed Setting Is names the setting that changed")
	ok = _pin(ok, watcher.asked_other, false, "and is false for every other setting")
	watcher.ask_settings = null

	# Apply All Settings replays every declared setting - boot and the options screen, one path.
	watcher.calls = 0
	settings.call("apply_all_settings")
	ok = _pin(ok, watcher.calls, 3, "Apply All Settings re-fires the trigger once per declared setting")

	# Reset puts the defaults back and announces them.
	watcher.calls = 0
	settings.call("reset_settings_to_defaults")
	ok = _pin(ok, settings.call("setting_value", "master_volume"), 80, "Reset To Defaults restores the default")
	ok = _pin(ok, watcher.calls, 3, "and re-applies every setting")

	# The declaration is readable, which is what lets a menu build itself from it.
	ok = _pin(ok, settings.call("setting_kind", "difficulty"), "choice", "Setting Kind reads the declared kind")
	ok = _pin(ok, str(settings.call("setting_choices", "difficulty")), "[\"easy\", \"normal\", \"hard\"]",
		"Setting Choices splits the declared options")
	ok = _pin(ok, str(settings.call("setting_choices", "master_volume")), "[]",
		"a non-choice setting has no choices")
	ok = _pin(ok, settings.call("declared_setting_names").size(), 3, "every declared name is listed")
	ok = _pin(ok, settings.call("settings_report").contains("difficulty (choice): normal [default normal]"), true,
		"the report says kind, value in force and default")
	settings.free()
	return ok


## Settings survive a run through the same user://settings.cfg the built-in Save Setting writes -
## including a value written by that action rather than by this pack.
static func _test_settings_persistence() -> bool:
	var ok: bool = true
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://settings.cfg"))
	var first: Node = _new_settings()
	first.call("declare_setting", "master_volume", 80, "percent", "")
	first.call("set_setting", "master_volume", 12)
	first.call("save_all_settings")
	first.free()

	# What the built-in Save Setting action emits, written by hand: the same file, the same section.
	var config: ConfigFile = ConfigFile.new()
	config.load("user://settings.cfg")
	config.set_value("settings", "difficulty", "hard")
	config.save("user://settings.cfg")

	var second: Node = _new_settings()
	second.call("declare_setting", "master_volume", 80, "percent", "")
	second.call("declare_setting", "difficulty", "normal", "choice", "easy|normal|hard")
	ok = _pin(ok, second.call("setting_value", "master_volume"), 80,
		"before loading, the declared default is what is in force")
	second.call("load_all_settings")
	ok = _pin(ok, second.call("setting_value", "master_volume"), 12, "a saved value is restored")
	ok = _pin(ok, second.call("setting_value", "difficulty"), "hard",
		"and a value written by the built-in Save Setting is picked up too")
	second.free()
	return ok


# ── #23 Spawn And Configure ─────────────────────────────────────────────────────────────


static func _test_spawn_templates() -> bool:
	var ok: bool = true
	var spawn: ACEDescriptor = _descriptor(EventForgeSystemACEs.get_descriptors(), "SpawnSceneAs")
	ok = _pin(ok, spawn != null, true, "Spawn Scene As ships")
	if spawn == null:
		return false
	ok = _pin(ok, spawn.display_name, "Spawn Scene As", "its display name")
	ok = _pin(ok, spawn.ace_type, ACEDescriptor.ACEType.ACTION, "a spawn is an action")
	ok = _pin(ok, spawn.codegen_template.contains("set_meta(&\"__ef_spawn_\" + str({spawn_name}).to_utf8_buffer().hex_encode(), __spawn_{uid})"),
		true, "the name is the address: the node is remembered under it")
	ok = _pin(ok, spawn.codegen_template.contains("if has_signal(&\"scene_spawned\"):\n\temit_signal(&\"scene_spawned\", {spawn_name}, __spawn_{uid})"),
		true, "the spawn is handed on as a signal carrying the name AND the node")
	ok = _pin(ok, spawn.codegen_template.contains("__spawn_{uid}.set(__field_{uid}, __values_{uid}[__field_{uid}])"),
		true, "the with-record is applied field by field")
	var the_spawned: ACEDescriptor = _descriptor(EventForgeSystemACEs.get_descriptors(), "TheSpawned")
	ok = _pin(ok, the_spawned.ace_type, ACEDescriptor.ACEType.EXPRESSION, "The Spawned is an expression")
	ok = _pin(ok, the_spawned.display_name, "The Spawned", "its display name")
	var alive: ACEDescriptor = _descriptor(EventForgeSystemACEs.get_descriptors(), "SpawnIsAlive")
	ok = _pin(ok, alive.ace_type, ACEDescriptor.ACEType.CONDITION, "Spawn Is Alive is a condition")
	ok = _pin(ok, alive.codegen_template, "(has_meta(&\"__ef_spawn_\" + str({spawn_name}).to_utf8_buffer().hex_encode()) and is_instance_valid(get_meta(&\"__ef_spawn_\" + str({spawn_name}).to_utf8_buffer().hex_encode())))",
		"and it reads the same metadata the spawn wrote")
	# The read is guarded by has_meta and NEVER by get_meta's default argument: Object.get_meta
	# treats a null default as "no default given" and pushes an engine error, which would fire on
	# every row asking about a name that was never spawned - the exact case these two answer.
	ok = _pin(ok, the_spawned.codegen_template.contains("has_meta("), true,
		"The Spawned asks has_meta before reading")
	ok = _pin(ok, the_spawned.codegen_template.contains(", null)"), false,
		"and never leans on get_meta's null default, which would print an error each time")

	# The trigger half: a real signal, named on the descriptor, with BOTH payload arguments.
	var trigger: ACEDescriptor = _descriptor(EventForgeSystemACEs.get_descriptors(), "signal:scene_spawned")
	ok = _pin(ok, trigger != null, true, "On Scene Spawned ships as a trigger descriptor")
	if trigger == null:
		return false
	ok = _pin(ok, trigger.display_name, "On Scene Spawned", "its display name")
	ok = _pin(ok, trigger.ace_type, ACEDescriptor.ACEType.TRIGGER, "a spawn happening is a trigger")
	ok = _pin(ok, trigger.signal_name, "scene_spawned", "backed by the signal the action emits")
	ok = _pin(ok, trigger.codegen_template, "", "a trigger has no template - the compiler wires it")
	ok = _pin(ok, trigger.params.size(), 2, "it carries two payload parameters")
	ok = _pin(ok, trigger.params[0].id, "spawn_name", "the name that was spawned")
	ok = _pin(ok, trigger.params[1].id, "node", "and the node itself, never a Last Spawned lookup")
	return ok


## The trigger compiles to a connected handler whose signature is the signal's own arguments - the
## half a descriptor pin cannot see, because the compiler, not the descriptor, writes the connection.
static func _test_spawn_trigger_compiles() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = EventSheetResource.new()
	var declaration: RawCodeRow = RawCodeRow.new()
	declaration.code = "signal scene_spawned(spawn_name: String, node: Node)"
	sheet.events.append(declaration)
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "signal:scene_spawned"
	event.trigger_args = "spawn_name: String, node: Node"
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "CallMethod"
	action.codegen_template = "show_boss_bar(node)"
	event.actions.append(action)
	sheet.events.append(event)
	var output: String = str(SheetCompiler.compile(sheet, "user://eventforge_spawn_trigger.gd").get("output", ""))
	ok = _pin(ok, output.contains("func _on_scene_spawned(spawn_name: String, node: Node) -> void:"), true,
		"the handler is emitted with the signal's own arguments as its parameters")
	ok = _pin(ok, output.contains("scene_spawned.connect(_on_scene_spawned)"), true,
		"and it is actually connected, so the row runs")
	ok = _pin(ok, output.contains("show_boss_bar(node)"), true,
		"the reaction reads the node straight off the row's payload")
	return ok


## Compiles the three verbs into one host that declares the scene_spawned signal, then runs them:
## the record lands, the payload arrives, the name addresses the node, and a freed spawn reads as
## nothing rather than as a dangling reference.
static func _test_spawn_runtime() -> bool:
	var ok: bool = true
	_reset_work_dir()
	var scene_path: String = WORK_DIR + "/spawned.tscn"
	var template_node: Node2D = Node2D.new()
	var packed: PackedScene = PackedScene.new()
	packed.pack(template_node)
	ResourceSaver.save(packed, scene_path)
	template_node.free()

	var spawn: ACEDescriptor = _descriptor(EventForgeSystemACEs.get_descriptors(), "SpawnSceneAs")
	var the_spawned: ACEDescriptor = _descriptor(EventForgeSystemACEs.get_descriptors(), "TheSpawned")
	var alive: ACEDescriptor = _descriptor(EventForgeSystemACEs.get_descriptors(), "SpawnIsAlive")
	var body: String = _substitute(spawn.codegen_template, {
		"uid": "1", "path": "path", "spawn_name": "\"boss\"", "values": "{\"visible\": false}",
		"parent": "null", "position": "Vector2(10, 20)"
	})
	# Two more shapes of the same row: one inside a LOOP (six spawns in a frame, each addressed by
	# its own name) and one with an explicit parent, which is the branch the null default skips.
	var loop_body: String = _substitute(spawn.codegen_template, {
		"uid": "2", "path": "path", "spawn_name": "\"enemy_\" + str(index)", "values": "{}",
		"parent": "null", "position": "Vector2(index, 0)"
	})
	var into_body: String = _substitute(spawn.codegen_template, {
		"uid": "3", "path": "path", "spawn_name": "\"pickup\"", "values": "{}",
		"parent": "into", "position": "Vector2.ZERO"
	})
	var source: String = "extends Node\n\nsignal scene_spawned(spawn_name: String, node: Node)\n\n\nfunc spawn(path: String) -> void:\n%s\n\n\nfunc the_spawned() -> Variant:\n\treturn %s\n\n\nfunc is_alive() -> bool:\n\treturn %s\n\n\nfunc spawn_many(path: String, count: int) -> void:\n\tfor index: int in count:\n%s\n\n\nfunc spawned_named(wanted: String) -> Variant:\n\treturn %s\n\n\nfunc spawn_into(path: String, into: Node) -> void:\n%s\n" % [
		_indent(body),
		_substitute(the_spawned.codegen_template, {"spawn_name": "\"boss\""}),
		_substitute(alive.codegen_template, {"spawn_name": "\"boss\""}),
		_indent(_indent(loop_body)),
		_substitute(the_spawned.codegen_template, {"spawn_name": "wanted"}),
		_indent(into_body)
	]
	var host: Node = _node_from_source(source)
	if host == null:
		return false
	var watcher: SpawnWatcher = SpawnWatcher.new()
	host.connect("scene_spawned", Callable(watcher, "on_spawned"))

	ok = _pin(ok, host.call("is_alive"), false, "nothing is spawned under the name yet")
	ok = _pin(ok, host.call("the_spawned"), null,
		"and a name never spawned reads as nothing, quietly - no metadata, no engine error")
	host.call("spawn", scene_path)
	ok = _pin(ok, watcher.calls, 1, "spawning fires the trigger once")
	ok = _pin(ok, watcher.last_name, "boss", "the trigger carries the name the row typed")
	ok = _pin(ok, watcher.last_node is Node2D, true, "and the NODE itself, not a lookup key")
	ok = _pin(ok, host.call("the_spawned") == watcher.last_node, true,
		"The Spawned answers the very same node the trigger carried")
	ok = _pin(ok, (host.call("the_spawned") as Node2D).position, Vector2(10, 20), "it was placed")
	ok = _pin(ok, (host.call("the_spawned") as Node2D).visible, false,
		"and the with-record was applied on the way in")
	ok = _pin(ok, (host.call("the_spawned") as Node).get_parent() == host, true,
		"with no parent given it lands under the sheet's own node")
	ok = _pin(ok, host.call("is_alive"), true, "Spawn Is Alive reads true while it exists")

	# The edge case: a freed spawn reads as nothing, never as a dangling object.
	var spawned: Node = host.call("the_spawned")
	host.remove_child(spawned)
	spawned.free()
	ok = _pin(ok, host.call("is_alive"), false, "a freed spawn is not alive")
	ok = _pin(ok, host.call("the_spawned"), null, "and The Spawned gives nothing rather than a dead node")

	# Six spawns in one frame, the case a "last spawned node" expression would get wrong five times.
	watcher.calls = 0
	watcher.seen_names.clear()
	host.call("spawn_many", scene_path, 6)
	ok = _pin(ok, watcher.calls, 6, "a loop spawning six things fires the trigger six times")
	ok = _pin(ok, str(watcher.seen_names), "[\"enemy_0\", \"enemy_1\", \"enemy_2\", \"enemy_3\", \"enemy_4\", \"enemy_5\"]",
		"and each one carries its OWN name, in order")
	ok = _pin(ok, (host.call("spawned_named", "enemy_0") as Node2D).position, Vector2(0, 0),
		"the first name still addresses the first node afterwards")
	ok = _pin(ok, (host.call("spawned_named", "enemy_5") as Node2D).position, Vector2(5, 0),
		"and the last name addresses the last one - six live names, not one slot")
	ok = _pin(ok, host.call("spawned_named", "enemy_9"), null, "a name nobody spawned still reads as nothing")

	# The "Into" cell: with a parent given, the new node lands under THAT node, not under the sheet.
	var elsewhere: Node = Node.new()
	host.call("spawn_into", scene_path, elsewhere)
	ok = _pin(ok, (host.call("spawned_named", "pickup") as Node).get_parent() == elsewhere, true,
		"a spawn with an Into node lands under it instead of under the sheet")
	host.free()
	elsewhere.free()
	return ok


# ── #24 Live Data ───────────────────────────────────────────────────────────────────────


static func _test_live_data_templates() -> bool:
	var ok: bool = true
	var descriptors: Array[ACEDescriptor] = EventForgeResourceACEs.get_descriptors()
	var watch: ACEDescriptor = _descriptor(descriptors, "WatchDataFile")
	ok = _pin(ok, watch != null, true, "Watch Data File ships")
	if watch == null:
		return false
	ok = _pin(ok, watch.ace_type, ACEDescriptor.ACEType.ACTION, "watching is an action")
	ok = _pin(ok, watch.codegen_template.contains("if has_signal(&\"data_file_changed\"):\n\t\temit_signal(&\"data_file_changed\", {path})"),
		true, "a change is handed on as a signal carrying the path")
	ok = _pin(ok, watch.codegen_template.contains("get_meta(&\"__ef_watch_\" + str({path}).to_utf8_buffer().hex_encode(), __stamp_{uid})"),
		true, "the last stamp defaults to the current one, so the first check only takes a reading")
	var reload: ACEDescriptor = _descriptor(descriptors, "ReloadDataAsset")
	ok = _pin(ok, reload.codegen_template.contains("ResourceLoader.CACHE_MODE_REPLACE"),
		true, "reloading replaces the data in the copy everyone is holding")
	ok = _pin(ok, _descriptor(descriptors, "DataFolderIsValid").ace_type, ACEDescriptor.ACEType.CONDITION,
		"Data Folder Is Valid is a condition")
	ok = _pin(ok, _descriptor(descriptors, "DataFolderProblems").ace_type, ACEDescriptor.ACEType.EXPRESSION,
		"Data Folder Problems is an expression")
	ok = _pin(ok, _descriptor(descriptors, "ValidateDataFolder").ace_type, ACEDescriptor.ACEType.ACTION,
		"Validate Data Folder is an action")

	var trigger: ACEDescriptor = _descriptor(descriptors, "signal:data_file_changed")
	ok = _pin(ok, trigger != null, true, "On Data File Changed ships as a trigger descriptor")
	if trigger == null:
		return false
	ok = _pin(ok, trigger.display_name, "On Data File Changed", "its display name")
	ok = _pin(ok, trigger.ace_type, ACEDescriptor.ACEType.TRIGGER, "a file changing is a trigger")
	ok = _pin(ok, trigger.signal_name, "data_file_changed", "backed by the signal the watch action emits")
	ok = _pin(ok, trigger.params.size(), 1, "it carries one payload parameter")
	ok = _pin(ok, trigger.params[0].id, "path", "the path that changed - not a side expression")
	return ok


## The same compile proof for the data trigger: the handler takes the path as its parameter, which
## is what makes two files landing in one check reload the right two files.
static func _test_live_data_trigger_compiles() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = EventSheetResource.new()
	var declaration: RawCodeRow = RawCodeRow.new()
	declaration.code = "signal data_file_changed(path: String)"
	sheet.events.append(declaration)
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "signal:data_file_changed"
	event.trigger_args = "path: String"
	var reload: ACEDescriptor = _descriptor(EventForgeResourceACEs.get_descriptors(), "ReloadDataAsset")
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "ReloadDataAsset"
	action.codegen_template = _substitute(reload.codegen_template, {"path": "path"})
	event.actions.append(action)
	sheet.events.append(event)
	var output: String = str(SheetCompiler.compile(sheet, "user://eventforge_live_data_trigger.gd").get("output", ""))
	ok = _pin(ok, output.contains("func _on_data_file_changed(path: String) -> void:"), true,
		"the handler takes the changed path as its own parameter")
	ok = _pin(ok, output.contains("data_file_changed.connect(_on_data_file_changed)"), true,
		"and it is connected, so the reaction actually runs")
	ok = _pin(ok, output.contains("ResourceLoader.load(path, \"\", ResourceLoader.CACHE_MODE_REPLACE)"), true,
		"and the reload reloads exactly that path")
	return ok


## The watch loop for real. No clock is involved: a file's modification time has one-second
## resolution, so the change under test is the file APPEARING, which is unambiguous.
static func _test_watch_data_file_runtime() -> bool:
	var ok: bool = true
	_reset_work_dir()
	var watched: String = WORK_DIR + "/live.json"
	var watch: ACEDescriptor = _descriptor(EventForgeResourceACEs.get_descriptors(), "WatchDataFile")
	var body: String = _substitute(watch.codegen_template, {"uid": "1", "path": "path"})
	var host: Node = _node_from_source("extends Node\n\nsignal data_file_changed(path: String)\n\n\nfunc check(path: String) -> void:\n%s\n" % _indent(body))
	if host == null:
		return false
	var watcher: PathWatcher = PathWatcher.new()
	host.connect("data_file_changed", Callable(watcher, "on_changed"))

	host.call("check", watched)
	ok = _pin(ok, watcher.calls, 0, "the first check only takes a reading - nothing fires")
	host.call("check", watched)
	ok = _pin(ok, watcher.calls, 0, "and an unchanged file keeps quiet")

	var file: FileAccess = FileAccess.open(watched, FileAccess.WRITE)
	file.store_string("{\"damage\": 12}")
	file.close()
	host.call("check", watched)
	ok = _pin(ok, watcher.calls, 1, "a file that was written fires the trigger once")
	ok = _pin(ok, watcher.last_path, watched, "and the trigger carries the path that changed")
	host.call("check", watched)
	ok = _pin(ok, watcher.calls, 1, "the same file, unchanged since, fires nothing more")

	# The reload half: the copy every node is already holding picks up the new numbers.
	var gradient_path: String = WORK_DIR + "/curve.tres"
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	ResourceSaver.save(gradient, gradient_path)
	var held: Gradient = load(gradient_path)
	var edited: Gradient = Gradient.new()
	edited.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	ResourceSaver.save(edited, gradient_path)
	var reload: ACEDescriptor = _descriptor(EventForgeResourceACEs.get_descriptors(), "ReloadDataAsset")
	var reloader: Node = _node_from_source("extends Node\n\n\nfunc reload(path: String) -> void:\n%s\n" % _indent(_substitute(reload.codegen_template, {"path": "path"})))
	reloader.call("reload", gradient_path)
	ok = _pin(ok, held.offsets.size(), 3, "the resource everyone is holding now has the edited data")
	reloader.free()
	host.free()
	return ok


## The folder report: a file that cannot be loaded, one with no id, and two claiming the same id -
## and the empty-means-clean convention the condition rides on.
static func _test_data_folder_runtime() -> bool:
	var ok: bool = true
	_reset_work_dir()
	var script_path: String = WORK_DIR + "/item.gd"
	var script_file: FileAccess = FileAccess.open(script_path, FileAccess.WRITE)
	script_file.store_string(ITEM_SCRIPT_SOURCE)
	script_file.close()
	var item_script: GDScript = load(script_path)

	var descriptors: Array[ACEDescriptor] = EventForgeResourceACEs.get_descriptors()
	var problems: ACEDescriptor = _descriptor(descriptors, "DataFolderProblems")
	var valid: ACEDescriptor = _descriptor(descriptors, "DataFolderIsValid")
	var reader: Node = _node_from_source("extends Node\n\n\nfunc report(folder: String) -> String:\n\treturn %s\n\n\nfunc is_valid(folder: String) -> bool:\n\treturn %s\n" % [
		_substitute(problems.codegen_template, {"folder": "folder"}),
		_substitute(valid.codegen_template, {"folder": "folder"})
	])
	if reader == null:
		return false

	var clean_dir: String = WORK_DIR + "/clean"
	DirAccess.make_dir_recursive_absolute(clean_dir)
	_save_item(item_script, clean_dir + "/sword.tres", "sword")
	_save_item(item_script, clean_dir + "/shield.tres", "shield")
	ok = _pin(ok, reader.call("report", clean_dir), "", "a clean folder reports nothing at all")
	ok = _pin(ok, reader.call("is_valid", clean_dir), true, "and reads as valid")
	ok = _pin(ok, reader.call("report", WORK_DIR + "/not_there"), "",
		"a folder that is not there is not a problem, it is empty")

	var broken_dir: String = WORK_DIR + "/broken"
	DirAccess.make_dir_recursive_absolute(broken_dir)
	_save_item(item_script, broken_dir + "/axe.tres", "axe")
	_save_item(item_script, broken_dir + "/axe_copy.tres", "axe")
	_save_item(item_script, broken_dir + "/nameless.tres", "")
	ResourceSaver.save(Gradient.new(), broken_dir + "/not_an_item.tres")
	var report: String = reader.call("report", broken_dir)
	ok = _pin(ok, report.contains("axe.tres: shares its id with another file"), true,
		"a duplicated id is named, file by file")
	ok = _pin(ok, report.contains("axe_copy.tres: shares its id with another file"), true,
		"including the file that would silently win the lookup")
	ok = _pin(ok, report.contains("nameless.tres: has no id"), true, "a blank id is a problem")
	ok = _pin(ok, report.contains("not_an_item.tres: has no id"), true,
		"and so is an asset with no id field at all")
	ok = _pin(ok, reader.call("is_valid", broken_dir), false, "the condition reads false for that folder")
	ok = _pin(ok, report.split("\n").size(), 4, "one line per problem, nothing else")
	reader.free()
	return ok


# ── Fixtures ────────────────────────────────────────────────────────────────────────────


static func _save_item(item_script: GDScript, path: String, id: String) -> void:
	var item: Resource = Resource.new()
	item.set_script(item_script)
	item.set("id", id)
	ResourceSaver.save(item, path)


## The pack is reached by PATH: its class_name is new, and a headless --script run cannot resolve a
## global class until the editor regenerates the class cache.
static func _new_settings() -> Node:
	var node: Node = Node.new()
	node.set_script(load(PACK_PATH))
	return node


static func _node_from_source(source: String) -> Node:
	var script: GDScript = GDScript.new()
	script.source_code = source
	if script.reload() != OK:
		print("  [FAIL] generated source does not parse:\n", source)
		return null
	var node: Node = Node.new()
	node.set_script(script)
	return node


static func _substitute(template: String, params: Dictionary) -> String:
	var output: String = template
	for key: String in params:
		output = output.replace("{%s}" % key, str(params[key]))
	return output


static func _indent(body: String) -> String:
	var lines: PackedStringArray = PackedStringArray()
	for line: String in body.split("\n"):
		lines.append("\t" + line)
	return "\n".join(lines)


static func _descriptor(descriptors: Array[ACEDescriptor], ace_id: String) -> ACEDescriptor:
	for descriptor: ACEDescriptor in descriptors:
		if descriptor.ace_id == ace_id:
			return descriptor
	return null


static func _reset_work_dir() -> void:
	var dir: DirAccess = DirAccess.open("user://")
	if dir != null and dir.dir_exists(WORK_DIR.trim_prefix("user://")):
		_remove_tree(WORK_DIR)
	DirAccess.make_dir_recursive_absolute(WORK_DIR)


static func _remove_tree(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while not entry.is_empty():
		if dir.current_is_dir():
			_remove_tree(path.path_join(entry))
		else:
			DirAccess.remove_absolute(path.path_join(entry))
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)


## One VALUE per check - never a boolean-and chain, which would compare a bool with a String and
## take the whole suite down silently.
## Stands in for a reaction that WAITS: it is subscribed to the trigger like any other listener, but
## asks its question only after the announcement has fully returned - which is exactly where an
## awaiting event's later rows run, and where the announcing stack has already been popped.
static func _asks_after_resuming(settings: Node, setting_name: String) -> bool:
	var reached: Array = []
	var handler: Callable = func(_changed: String, _value: Variant) -> void:
		reached.append(true)
	settings.connect("setting_changed", handler)
	settings.call("set_setting", setting_name, 41)
	settings.disconnect("setting_changed", handler)
	if reached.is_empty():
		return false
	return bool(settings.call("changed_setting_is", setting_name))


## Prints on BOTH outcomes on purpose: a test that printed only on failure left no trace in the
## suite log, so a run that crashed halfway looked exactly like a run that passed everything.
static func _pin(ok: bool, actual: Variant, expected: Variant, label: String) -> bool:
	if actual != expected:
		print("  [FAIL] %s (expected %s, got %s)" % [label, str(expected), str(actual)])
		return false
	print("[PASS] data_and_settings_test: %s" % label)
	return ok


## Receives the setting_changed trigger and records its payload - a trigger is only proven by
## connecting to it and reading the arguments the handler was handed.
class SettingsWatcher extends RefCounted:

	var calls: int = 0
	var last_name: String = ""
	var last_value: Variant = null
	## When set, the handler asks the pack the Changed Setting Is question from INSIDE the reaction,
	## which is the only place it is meaningful.
	var ask_settings: Node = null
	var ask_name: String = ""
	var asked_answer: bool = false
	var asked_other: bool = true


	func on_changed(setting_name: String, value: Variant) -> void:
		calls += 1
		last_name = setting_name
		last_value = value
		if ask_settings != null:
			asked_answer = ask_settings.call("changed_setting_is", ask_name)
			asked_other = ask_settings.call("changed_setting_is", "master_volume")


class SpawnWatcher extends RefCounted:

	var calls: int = 0
	var last_name: String = ""
	var last_node: Node = null
	## Every name in arrival order, which is how a loop spawning several things in one frame is
	## told apart from a single "last spawned" slot answering the same node six times.
	var seen_names: Array[String] = []


	func on_spawned(spawn_name: String, node: Node) -> void:
		calls += 1
		last_name = spawn_name
		last_node = node
		seen_names.append(spawn_name)


class PathWatcher extends RefCounted:

	var calls: int = 0
	var last_path: String = ""


	func on_changed(path: String) -> void:
		calls += 1
		last_path = path
