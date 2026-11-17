# Godot EventSheets - a spawn row takes a scene the sheet holds by name.
#
# The Instantiate rows write `{scene}.instantiate()`, so their Scene field takes a PackedScene variable as well
# as a `load()` of a path. This pins what the field offers first (the sheet's own scene variables and
# constants), the line a row writes for one (the line a Godot user would write, which opens again and writes
# back byte for byte and parses), the Variable window's Scene door (one pick makes a typed Inspector slot), and
# the Doctor's quiet note for a slot that is still empty where it is spawned from.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const SLOTS := preload("res://addons/eventsheet/editor/autocomplete/scene_slots.gd")
const DOCTOR := preload("res://addons/eventforge/scene_slot_doctor.gd")
const P := "spawn_scene_slot_test"
const SHEET_SOURCE := "extends Node2D

@export var lives: int = 3
@export var enemy_scene: PackedScene
const BULLET: PackedScene = preload(\"res://bullet.tscn\")
var cached = load(\"res://pickup.tscn\")
"
const SPAWNER_SCRIPT := "extends Node2D

@export var star_scene: PackedScene
@export var gem_scene: PackedScene = preload(\"res://gem.tscn\")
@export var unused_scene: PackedScene


func _ready() -> void:
	var star := star_scene.instantiate()
	add_child(star)
	add_child(gem_scene.instantiate())
"
const SCENE_TEXT := "[gd_scene load_steps=2 format=3]

[ext_resource type=\"Script\" path=\"res://spawner.gd\" id=\"1_abc\"]

[node name=\"Level\" type=\"Node2D\"]
script = ExtResource(\"1_abc\")
"
const SCENE_TEXT_FILLED := "[gd_scene load_steps=3 format=3]

[ext_resource type=\"Script\" path=\"res://spawner.gd\" id=\"1_abc\"]
[ext_resource type=\"PackedScene\" path=\"res://star.tscn\" id=\"2_def\"]

[node name=\"Level\" type=\"Node2D\"]
script = ExtResource(\"1_abc\")
star_scene = ExtResource(\"2_def\")
"


static func run() -> bool:
	var ok: bool = true
	ok = _test_the_field_offers_the_sheets_scenes_first(ok)
	ok = _test_the_row_writes_the_line_a_godot_user_would(ok)
	ok = _test_the_variable_window_has_a_scene_door(ok)
	ok = _test_the_doctor_note(ok)
	return ok


static func _test_the_field_offers_the_sheets_scenes_first(ok: bool) -> bool:
	var instantiate: String = "var {name} = {scene}.instantiate()\n{parent}.add_child({name})"
	ok = SUPPORT.check(P, "a parameter the template runs instantiate() on is a scene slot", SLOTS.is_scene_slot(instantiate, "scene"), true) and ok
	ok = SUPPORT.check(P, "a parameter the template loads from is not", SLOTS.is_scene_slot("add_child(load({path}).instantiate())", "path"), false) and ok
	var sheet: EventSheetResource = SUPPORT.reopen(SHEET_SOURCE, true)
	var names: Array = SLOTS.entries(sheet).map(func(entry: Dictionary) -> String: return str(entry["text"]))
	ok = SUPPORT.check(P, "the sheet's scene variables and constants, in the order it declares them", names, ["enemy_scene", "BULLET", "cached"]) and ok
	var assist_field: CodeEdit = CodeEdit.new()
	var assist: EventSheetExpressionAssist = EventSheetExpressionAssist.attach(assist_field,
		func() -> Resource: return sheet, Callable(), Callable(), Callable(SLOTS, "in_front"))
	var listed: Array = assist.popup._entries_provider.call("").map(func(entry: Dictionary) -> String: return str(entry["text"]))
	ok = SUPPORT.check(P, "an empty Scene field lists them before anything else", listed.slice(0, 3), ["enemy_scene", "BULLET", "cached"]) and ok
	var typed: Array = assist.popup._entries_provider.call("bul").map(func(entry: Dictionary) -> String: return str(entry["text"]))
	ok = SUPPORT.check(P, "typing narrows the list and the scene stays first", typed.slice(0, 1), ["BULLET"]) and ok
	ok = SUPPORT.check(P, "nothing is said twice", listed.count("enemy_scene"), 1) and ok
	var plain_field: CodeEdit = CodeEdit.new()
	var plain: Array = EventSheetExpressionAssist.attach(plain_field, func() -> Resource: return sheet).popup._entries_provider.call("").map(
		func(entry: Dictionary) -> String: return str(entry["text"]))
	ok = SUPPORT.check(P, "a field that is not a scene slot keeps its own order", plain.slice(0, 1) == ["enemy_scene"], false) and ok
	assist_field.free()
	plain_field.free()
	return ok


static func _test_the_row_writes_the_line_a_godot_user_would(ok: bool) -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var scene_variable: LocalVariable = LocalVariable.new()
	scene_variable.name = "enemy_scene"
	scene_variable.type_name = "PackedScene"
	scene_variable.exported = true
	scene_variable.no_default = true
	sheet.events.append(scene_variable)
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "SpawnNewCopy"
	action.params = {"scene": "enemy_scene", "name": "enemy", "at": "global_position", "parent": "get_tree().current_scene"}
	event.actions.append(action)
	sheet.events.append(event)
	var path: String = SUPPORT.own_path("scene_slot_row.gd")
	var output: String = SUPPORT.compile_output(sheet, path)
	ok = SUPPORT.check(P, "the row writes the scene slot's own instantiate()", output.contains("\tvar enemy = enemy_scene.instantiate()\n"), true) and ok
	ok = SUPPORT.check(P, "and never a load() or a preload() on its own", output.contains("load("), false) and ok
	ok = SUPPORT.check(P, "the slot is a typed Inspector variable", output.contains("@export var enemy_scene: PackedScene\n"), true) and ok
	var script: GDScript = GDScript.new()
	script.source_code = output
	ok = SUPPORT.check(P, "the script parses", script.reload(), OK) and ok
	ok = SUPPORT.check(P, "it opens again and writes back byte for byte", SUPPORT.reemit(output, SUPPORT.own_path("scene_slot_row_again.gd")), output) and ok
	return ok


static func _test_the_variable_window_has_a_scene_door(ok: bool) -> bool:
	var host: Node = Node.new()
	var dialog: EventSheetVariableDialog = EventSheetVariableDialog.new()
	dialog.init_dialog(host)
	dialog.set_sheet_provider(func() -> Variant: return null)
	dialog.open_for_edit("tree", {}, "enemy_scene", "int", "", false, "Add", false, false)
	var found: Array = dialog.type_search_entries("scene").map(func(entry: Dictionary) -> String: return str(entry["text"]))
	ok = SUPPORT.check(P, "Search types finds the Scene door", found.has("PackedScene · A scene"), true) and ok
	dialog.pick_type("PackedScene")
	ok = SUPPORT.check(P, "picking it types the variable as a scene slot", dialog._selected_stored_type(), "PackedScene") and ok
	ok = SUPPORT.check(P, "and puts it in the Inspector in the same step", dialog._exported_check.button_pressed, true) and ok
	ok = SUPPORT.check(P, "the line it writes is a Godot user's", dialog.code_line_text(), "@export var enemy_scene: PackedScene") and ok
	host.free()
	return ok


static func _test_the_doctor_note(ok: bool) -> bool:
	var slots: Dictionary = DOCTOR.empty_slots(SPAWNER_SCRIPT)
	ok = SUPPORT.check(P, "a slot with no value that the script spawns from is the one it names", slots.keys(), ["star_scene"]) and ok
	ok = SUPPORT.check(P, "a slot with a value, and a slot nothing spawns from, are quiet",
		[slots.has("gem_scene"), slots.has("unused_scene")], [false, false]) and ok
	var gaps: Array = DOCTOR.gaps_in_scene(SCENE_TEXT, "res://spawner.gd", ["star_scene"])
	ok = SUPPORT.check(P, "a scene that leaves the slot empty is named", gaps, ["star_scene"]) and ok
	ok = SUPPORT.check(P, "a scene that fills it is quiet", DOCTOR.gaps_in_scene(SCENE_TEXT_FILLED, "res://spawner.gd", ["star_scene"]), []) and ok
	var finding: Dictionary = DOCTOR.report("res://spawner.gd", "star_scene", "res://level.tscn")
	ok = SUPPORT.check(P, "it is a note, never a warning", str(finding["severity"]), "info") and ok
	ok = SUPPORT.check(P, "two short sentences naming the slot and the scene, short enough for the inbox column", str(finding["message"]),
		"star_scene is empty in level.tscn. Pick a scene for it in the Inspector.") and ok
	ok = SUPPORT.check(P, "it files under the script it is about", [str(finding["path"]), str(finding["check"])], ["res://spawner.gd", "scene-slot-empty"]) and ok
	return ok
