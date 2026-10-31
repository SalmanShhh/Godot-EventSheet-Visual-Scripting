# EventForge - class names and kinds of a class. A sheet that names itself (class_name Enemy) is an
# object the whole project can pick; a sheet that extends it is a kind of it. This pins the System
# condition "Is a kind of..." (the GDScript `is`), which must write the line a hand-written file
# has, lift back from it, and re-emit it byte for byte.
@tool
class_name ClassKindsTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")


static func run() -> bool:
	var ok: bool = true
	var by_id: Dictionary = {}
	for descriptor: ACEDescriptor in EventForgeBuiltinACEs.get_descriptors():
		by_id[descriptor.ace_id] = descriptor
	var is_a: ACEDescriptor = by_id.get("IsAKindOf") as ACEDescriptor
	ok = SUPPORT.check("class_kinds_test", "Is a kind of is registered", is_a != null, true) and ok
	if is_a == null:
		return false
	ok = SUPPORT.pins("class_kinds_test", [
		["the template is the GDScript type test", is_a.codegen_template, "{value} is {kind}"],
		["it is a condition", is_a.ace_type, ACEDescriptor.ACEType.CONDITION],
	]) and ok

	var authored: EventSheetResource = EventSheetResource.new()
	authored.host_class = "Area2D"
	authored.custom_class_name = "Hazard"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnBodyEntered"
	var asks: ACECondition = ACECondition.new()
	asks.provider_id = "Core"
	asks.ace_id = "IsAKindOf"
	asks.params = {"value": "body", "kind": "Enemy"}
	event.conditions.append(asks)
	authored.events.append(event)
	var source: String = SUPPORT.compile_output(authored, "user://class_kinds_a.gd")
	ok = SUPPORT.check("class_kinds_test", "the condition writes the type test",
		source.contains("if body is Enemy:"), true) and ok
	var again: String = SUPPORT.reemit(source, "user://class_kinds_a.gd")
	ok = SUPPORT.check("class_kinds_test", "a sheet using it round-trips byte for byte", again == source, true) and ok
	var reopened: EventSheetResource = SUPPORT.reopen(source, true, "user://class_kinds_a.gd")
	var lifted: String = ""
	for row: Variant in reopened.events:
		if row is EventRow and not (row as EventRow).conditions.is_empty():
			lifted = str((row as EventRow).conditions[0].ace_id)
	ok = SUPPORT.check("class_kinds_test", "a reopened file keeps the type test in its own reading, not as this verb", lifted != "IsAKindOf", true) and ok
	ok = run_kinds() and ok
	ok = SUPPORT.pins("class_kinds_test", [
		["an empty kind-of field is fine", EventSheetNewSheetDialog.kind_problem_text(""), ""],
		["a Godot class is fine", EventSheetNewSheetDialog.kind_problem_text("CharacterBody2D"), ""],
		["a class of the project is fine", EventSheetNewSheetDialog.kind_problem_text("EventSheetResource"), ""],
		["a name that is no class is warned", EventSheetNewSheetDialog.kind_problem_text("Nonsuch"), "No class or node by that name."],
		# The warning waits while the field still completes what is typed: a prefix on its way to a
		# class is not a mistake yet.
		["a prefix of a project class still completes", EventSheetNewSheetDialog.kind_has_completion("EventSheetRes"), true],
		["a prefix of a Godot class still completes, any case", EventSheetNewSheetDialog.kind_has_completion("characterbo"), true],
		["a name nothing begins with completes nothing", EventSheetNewSheetDialog.kind_has_completion("Nonsuchxyz"), false],
		# Only a kind of the project's own class is named as a class; extending a Godot class names nothing.
		["a kind of a project class names the new sheet", EventSheetNewSheetDialog.names_new_class("EventSheetResource"), true],
		["extending a Godot class names nothing", EventSheetNewSheetDialog.names_new_class("CharacterBody2D"), false],
		["an empty field names nothing", EventSheetNewSheetDialog.names_new_class(""), false],
		# The completion list floats in a window that is never a popup and never focused: while a popup
		# window is open the keyboard goes to it, and Backspace and every letter after it were lost.
		["the completion list is not a popup window and takes no focus", _list_window_facts(), [false, true, true]],
		["right-clicking a script that names a class offers its kind", EventSheetContextMenu.class_declared_in(
			PackedStringArray(["res://addons/eventforge/resources/event_sheet.gd"])), "EventSheetResource"],
		["two scripts offer none", EventSheetContextMenu.class_declared_in(PackedStringArray(["res://a.gd", "res://b.gd"])), ""],
		["a script naming no class offers none", EventSheetContextMenu.class_declared_in(PackedStringArray(["res://not_a_class_anywhere.gd"])), ""],
		["the menu words in Godot's vocabulary", EventSheetContextMenu.kind_menu_text("Enemy"), "New script extending Enemy..."],
	]) and ok
	return ok


const KINDS_PATH := "res://addons/eventsheet/editor/dock/class_kinds.gd"
const ENEMY_SOURCE := "class_name Enemy\nextends CharacterBody2D\n\n@export var health: int = 3\nvar speed := 120.0\nvar touch_damage: int = 1\n\n\nfunc take_damage(amount: int) -> void:\n\thealth -= amount\n\n\nfunc score_for(kind: String, bonus: int = 0) -> int:\n\treturn bonus\n"


## What a class hands down, and what a kind writes: read off a parent's source, replaced with super,
## started at another value, and the whole thing a plain GDScript file that opens and saves untouched.
static func run_kinds() -> bool:
	var kinds: GDScript = load(KINDS_PATH)
	var ok: bool = true
	var members: Dictionary = kinds.inherited("Enemy", _classes())
	var variable_names: Array = []
	for entry: Dictionary in members["variables"]:
		variable_names.append("%s:%s" % [entry["name"], entry["owner"]])
	var function_names: Array = []
	for entry: Dictionary in members["functions"]:
		function_names.append(str(entry["name"]))
	ok = SUPPORT.pins("class_kinds_test", [
		["the variables a parent hands down, with their owner", variable_names, ["health:Enemy", "speed:Enemy", "touch_damage:Enemy"]],
		["the functions a parent hands down", function_names, ["take_damage", "score_for"]],
		["a typed variable keeps its default", (members["variables"][0] as Dictionary)["value"], "3"],
		["an inferred variable keeps its default", (members["variables"][1] as Dictionary)["value"], "120.0"],
		["a parameter keeps its type", ((members["functions"][1] as Dictionary)["params"][0] as Dictionary)["type"], "String"],
		["a default value is not part of the parameter", ((members["functions"][1] as Dictionary)["params"][1] as Dictionary)["name"], "bonus"],
		["the head in Familiar words", kinds.head_reading("Slime", "Enemy", true), "Slime a kind of Enemy"],
		["the head in Godot words", kinds.head_reading("Slime", "Enemy", false), "Slime extends Enemy"],
		["replaces, Familiar", kinds.word("replaces", true), "Replaces"],
		["replaces, Godot", kinds.word("replaces", false), "Overrides"],
		["a class name from a file stem", kinds.class_name_from("big_slime.gd"), "BigSlime"],
		["an engine class name is taken", kinds.name_is_taken("Node2D", "", _classes()), true],
		["another project class's name is taken", kinds.name_is_taken("Enemy", "res://slime.gd", _classes()), true],
		["the class's own file does not take its own name", kinds.name_is_taken("Enemy", "user://class_kinds_enemy.gd", _classes()), false],
	]) and ok

	var slime: EventSheetResource = kinds.new_kind_sheet("Slime", "Enemy")
	var replaced: EventFunction = kinds.replace_function(members["functions"][0])
	slime.functions.append(replaced)
	kinds.start_variable_at(slime, "speed", "60.0")
	var source: String = SUPPORT.compile_output(slime, "user://class_kinds_slime.gd")
	ok = SUPPORT.pins("class_kinds_test", [
		["the kind names itself and extends its parent", source.contains("class_name Slime\nextends Enemy"), true],
		["Replace writes the function with the parent's parameters", source.contains("func take_damage(amount: int) -> void:"), true],
		["and runs the parent's version first", source.contains("\tsuper(amount)"), true],
		["Start it at writes _init", source.contains("func _init() -> void:\n\tspeed = 60.0"), true],
	]) and ok
	kinds.start_variable_at(slime, "speed", "75.0")
	var restarted: String = SUPPORT.compile_output(slime, "user://class_kinds_slime.gd")
	ok = SUPPORT.pins("class_kinds_test", [
		["starting the same variable again replaces, never doubles", restarted.count("speed ="), 1],
		["the new value is the one written", restarted.contains("speed = 75.0"), true],
		["the file opens and saves untouched, byte for byte", SUPPORT.reemit(source, "user://class_kinds_slime.gd") == source, true],
	]) and ok
	var answering: EventFunction = kinds.replace_function(members["functions"][1])
	var answering_sheet: EventSheetResource = kinds.new_kind_sheet("Boss", "Enemy")
	answering_sheet.functions.append(answering)
	var answering_source: String = SUPPORT.compile_output(answering_sheet, "user://class_kinds_boss.gd")
	ok = SUPPORT.check("class_kinds_test", "a replaced function that answers hands the parent's answer on",
		answering_source.contains("return super(kind, bonus)"), true) and ok
	return ok


static func _list_window_facts() -> Array:
	var window: Window = EventSheetCompletionPopup.new_list_window()
	var facts: Array = [window is Popup or window.get_flag(Window.FLAG_POPUP), window.get_flag(Window.FLAG_NO_FOCUS), window.transient]
	window.free()
	return facts


static func _classes() -> Dictionary:
	var file: FileAccess = FileAccess.open("user://class_kinds_enemy.gd", FileAccess.WRITE)
	file.store_string(ENEMY_SOURCE)
	file.close()
	return {"Enemy": {"path": "user://class_kinds_enemy.gd", "base": "CharacterBody2D"}}
