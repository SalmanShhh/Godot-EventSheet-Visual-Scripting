# Godot EventSheets - the files the New behaviour and New global windows write.
#
# A new behaviour is the sheet a behaviour has (host typed as Works on, marked as yours, shelved) compiled
# to plain GDScript, so it has the shape every shipped pack has and reopens as that sheet byte for byte.
# A global is a plain Node script with no class_name. A copy keeps the source below its header and
# rewrites only the header. Pins the text each one writes, that it parses, and the two readings the Add
# behaviour list makes of a source (the host it works on, whether it is yours).
@tool
class_name BehaviourAddonScaffoldTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const Scaffold := preload("res://addons/eventsheet/editor/behaviour_addon_scaffold.gd")
const PROBE_PATH := "user://behaviour_scaffold_probe.gd"


static func run() -> bool:
	var ok: bool = true
	ok = SUPPORT.pins("behaviour_addon_scaffold_test", [
		["accepts a plain name", Scaffold.is_valid_class_name("Patrol"), true],
		["rejects an empty name", Scaffold.is_valid_class_name(""), false],
		["rejects a leading digit", Scaffold.is_valid_class_name("3Lives"), false],
		["rejects a reserved word", Scaffold.is_valid_class_name("func"), false],
		["rejects an engine class", Scaffold.is_valid_class_name("Node"), false],
		["rejects a global script class", Scaffold.is_valid_class_name("ACEAction"), false],
		["a behaviour lives in its own folder", Scaffold.script_path_for("PlayerCombat"),
			"res://eventsheet_addons/player_combat/player_combat.gd"],
		["a scene global sits beside its script", Scaffold.scene_path_for("GameState"),
			"res://eventsheet_addons/game_state/game_state.tscn"],
	]) and ok

	var behaviour: String = Scaffold.source_of(Scaffold.behaviour_sheet("Patrol", "CharacterBody2D", "Movement",
		"Walks between points,\nwaits at each, and says \"arrived\"."))
	ok = _check("a new behaviour is the pack shape, typed as what it works on", behaviour, "\n".join(PackedStringArray([
		"## @ace_tags(custom)",
		"## @ace_category(\"Movement\")",
		"class_name Patrol",
		"extends Node",
		"## Walks between points, waits at each, and says 'arrived'.",
		"",
		"## The node this behavior acts on (its parent). Required host: CharacterBody2D.",
		"var host: CharacterBody2D = null",
		"",
		"func _enter_tree() -> void:",
		"\thost = get_parent() as CharacterBody2D",
		"\tif host == null:",
		"\t\tpush_warning(\"Patrol behavior requires a CharacterBody2D parent.\")",
		"",
	]))) and ok
	ok = _check("it parses", _parses(behaviour), OK) and ok
	ok = _check("a kind of object Godot does not have works on any node",
		Scaffold.host_class_of(Scaffold.source_of(Scaffold.behaviour_sheet("Odd", "NoSuchClass", "", ""))), "Node") and ok

	# It reopens as the sheet it was made from, and saves back byte for byte.
	var file: FileAccess = FileAccess.open(PROBE_PATH, FileAccess.WRITE)
	file.store_string(behaviour)
	file.close()
	var reopened: EventSheetResource = GDScriptImporter.new().import_external(PROBE_PATH)
	ok = SUPPORT.pins("behaviour_addon_scaffold_test", [
		["reopens as a behaviour", reopened.behavior_mode, true],
		["working on what it was made for", reopened.host_class, "CharacterBody2D"],
		["marked as yours", Array(reopened.addon_tags), ["custom"]],
		["saves back byte for byte", str(SheetCompiler.compile(reopened, "").get("output")), behaviour],
	]) and ok
	DirAccess.remove_absolute(PROBE_PATH)

	var global_source: String = Scaffold.source_of(Scaffold.global_sheet("Score and lives."))
	ok = _check("a new global is a plain Node script with no class_name", global_source,
		"extends Node\n## Score and lives.\n") and ok

	# A copy rewrites the header only: renamed, marked as yours (beside its own tags), reshelved, its
	# version dropped, and the description you wrote in place of its own.
	var pack: String = "\n".join(PackedStringArray([
		"## @ace_tags(events, messaging)",
		"## @ace_category(\"Events\")",
		"## @ace_version(1.0.0)",
		"@icon(\"res://eventsheet_addons/event_bus/icon.svg\")",
		"class_name EventBusPackAddon",
		"extends Node",
		"## A game-wide message board.",
		"## Second line of its own words.",
		"",
		"signal event_raised(channel: String)",
	]))
	ok = _check("a copied behaviour keeps everything below its header", Scaffold.copied_source(pack, "Messages", "AI", "Mine now.", true),
		"\n".join(PackedStringArray([
			"## @ace_tags(events, messaging, custom)",
			"## @ace_category(\"AI\")",
			"@icon(\"res://eventsheet_addons/event_bus/icon.svg\")",
			"class_name Messages",
			"extends Node",
			"## Mine now.",
			"",
			"signal event_raised(channel: String)",
		]))) and ok
	ok = _check("a copied global drops the class, so it cannot clash with the pack or the autoload",
		Scaffold.copied_source(pack, "Messages", "", "", false).contains("class_name"), false) and ok
	ok = _check("and keeps the words it came with when none are written", Scaffold.copied_source(pack, "Messages", "", "", false).contains(
		"extends Node\n## A game-wide message board.\n## Second line of its own words."), true) and ok
	ok = _check("a copy parses", _parses(Scaffold.copied_source(pack, "Messages", "AI", "", true)), OK) and ok

	ok = SUPPORT.pins("behaviour_addon_scaffold_test", [
		["the host a shipped pack works on", Scaffold.host_class_of(FileAccess.get_file_as_string(
			"res://eventsheet_addons/bullet/bullet_behavior.gd")), "Node2D"],
		["an @onready host reads the same", Scaffold.host_class_of("@onready var host: Control = get_parent()"), "Control"],
		["no host, no kind", Scaffold.host_class_of("extends Node"), ""],
		["a new behaviour is yours", Scaffold.is_yours(behaviour), true],
		["a shipped pack is not", Scaffold.is_yours(pack), false],
		["a copy is", Scaffold.is_yours(Scaffold.copied_source(pack, "Messages", "", "", true)), true],
	]) and ok

	# What a script I wrote hands a behaviour: its exported variables, never its constants or state.
	var mine: String = "extends CharacterBody2D\n\n@export var speed: float = 120.0\nconst LIMIT: int = 3\nvar _timer: float = 0.0\n@export var loop: bool = true\n"
	file = FileAccess.open(PROBE_PATH, FileAccess.WRITE)
	file.store_string(mine)
	file.close()
	ok = SUPPORT.pins("behaviour_addon_scaffold_test", [
		["a behaviour takes the exported variables", _names(Scaffold.carried_variables(PROBE_PATH, true)), ["speed", "loop"]],
		["a global takes every variable but the constants", _names(Scaffold.carried_variables(PROBE_PATH, false)), ["speed", "_timer", "loop"]],
		["a missing script hands over nothing", Scaffold.carried_variables("res://no/such.gd", true).size(), 0],
	]) and ok
	var carried: String = Scaffold.source_of(Scaffold.with_variables(Scaffold.behaviour_sheet("Walker", "CharacterBody2D", "", ""),
		Scaffold.carried_variables(PROBE_PATH, true)))
	ok = _check("the carried properties are written as @export lines", carried.contains(
		"@export var speed: float = 120.0\n@export var loop: bool = true"), true) and ok
	ok = _check("and the result parses", _parses(carried), OK) and ok
	DirAccess.remove_absolute(PROBE_PATH)

	var scene: PackedScene = Scaffold.global_scene("GameState", GDScript.new())
	var root: Node = scene.instantiate()
	ok = _check("a scene global's root is named for it", str(root.name), "GameState") and ok
	root.free()
	return ok


static func _parses(source: String) -> int:
	var script: GDScript = GDScript.new()
	script.source_code = source
	return script.reload()


static func _names(variables: Array[LocalVariable]) -> Array:
	var out: Array = []
	for variable: LocalVariable in variables:
		out.append(variable.name)
	return out


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("behaviour_addon_scaffold_test", label, actual, expected)
