# Godot EventSheets - every Inspector export option compiles from a variable and lifts back onto one.
#
# THE CONTRACT: each export spelling Godot 4.7 offers is a property of the variable row. Written by
# hand in a script (res://tests/fixtures/existing_project/turret.gd), it opens as that variable with
# the option on its attributes - never as a stray code block - and the file saves back byte for byte.
# Set on a row (the way the variable dialog sets it), it compiles to exactly that spelling, through
# the tree-row path and the Properties-table (dictionary) path alike.
#
# The shapes pinned here are the ones the plain `@export_*` lift could not carry: a group or subgroup
# with a name PREFIX, the group END line, an untyped export whose type the value implies, a raw-path
# file picker, and a free-form @export_custom. The others in the fixture (category, NodePath, the
# range extras, both easing flags) shipped earlier and ride along so a regression in them shows here.
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME := "export_options_lift_test"
const FIXTURE_PATH: String = "res://tests/fixtures/existing_project/turret.gd"
const VERIFY_PATH: String = "user://export_options_lift_test.gd"


static func run() -> bool:
	var source: String = FileAccess.get_file_as_string(FIXTURE_PATH)
	var sheet: EventSheetResource = SUPPORT.reopen(source, true, FIXTURE_PATH)
	var by_name: Dictionary = {}
	var stray_exports: PackedStringArray = PackedStringArray()
	for row: Variant in sheet.events:
		if row is LocalVariable:
			by_name[(row as LocalVariable).name] = row
		elif row is RawCodeRow and (row as RawCodeRow).code.contains("@export"):
			stray_exports.append((row as RawCodeRow).code)
	var all_passed: bool = SUPPORT.pins(TEST_NAME, [
		["no export line is left behind as a code block", stray_exports, PackedStringArray()],
		["the file saves back byte for byte", SUPPORT.reemit(source, VERIFY_PATH), source],
		["a prefixed group carries its name and its prefix",
			_attributes(by_name, "bullet_speed", ["category", "group", "group_prefix"]),
			{"category": "Firing", "group": "Bullet", "group_prefix": "bullet_"}],
		["the group end is a fact of the variable after it",
			_attributes(by_name, "burst_delay", ["group", "group_end"]), {"group_end": true}],
		["a prefixed subgroup carries its name and its prefix",
			_attributes(by_name, "shot_sound", ["group", "subgroup", "subgroup_prefix", "file"]),
			{"group": "Sound", "subgroup": "Shot", "subgroup_prefix": "shot_",
				"file": {"mode": "file", "global": false, "plain_path": true, "filters": ["*.wav", "*.ogg"]}}],
		["an untyped export keeps no type in code and the type its value implies on the row",
			_declaration(by_name, "bullet_speed"), {"untyped": true, "type_name": "float", "exported": true}],
		["an untyped whole number reads as int",
			_declaration(by_name, "bullet_damage"), {"untyped": true, "type_name": "int", "exported": true}],
		["an untyped private member lifts too",
			_declaration(by_name, "_cooldown"), {"untyped": true, "type_name": "float", "exported": false}],
		["a free-form @export_custom carries hint, text and usage",
			_attributes(by_name, "shot_pitch_steps", ["custom_hint"]),
			{"custom_hint": {"hint": "PROPERTY_HINT_RANGE", "text": "0,24,0.5,or_greater", "usage": "PROPERTY_USAGE_DEFAULT"}}],
		["the category rides the first knob under it", _attributes(by_name, "target", ["category"]), {"category": "Aiming"}],
		["a filtered node path stays structured", _attributes(by_name, "muzzle", ["node_path_types"]),
			{"node_path_types": ["Marker2D"]}],
		["the range extras stay structured", _attributes(by_name, "aim_smoothing", ["range"]),
			{"range": {"min": "0", "max": "1", "step": "0.01", "exp": true, "hide_slider": true}}],
		["both easing flags at once stay structured", _attributes(by_name, "shot_falloff", ["exp_easing_flags"]),
			{"exp_easing_flags": ["attenuation", "positive_only"]}],
		["no option is left as a verbatim hint", _verbatim_hints(by_name), {}],
	])
	all_passed = _authoring_spellings() and all_passed
	return _ends_and_untyped_nodes() and all_passed


## Two spellings that stayed code lines: `@export_subgroup("")`, which ends only the subgroup, and an
## @onready written with no type, whose node lookup implies nothing and so reads as Variant.
static func _ends_and_untyped_nodes() -> bool:
	var source: String = "\n".join([
		"extends Node2D",
		"",
		"@export_group(\"Movement\")",
		"@export var speed: float = 2.0",
		"@export_subgroup(\"Jump\")",
		"@export var jump_height: float = 3.0",
		"@export_subgroup(\"\")",
		"@export var run_boost: float = 1.5",
		"@onready var label = $Label",
		"@onready var sprite = get_node(\"Sprite2D\")",
		"",
	])
	var by_name: Dictionary = {}
	var code_rows: PackedStringArray = PackedStringArray()
	for row: Variant in SUPPORT.reopen(source).events:
		if row is LocalVariable:
			by_name[(row as LocalVariable).name] = row
		elif row is RawCodeRow and (row as RawCodeRow).code.contains("@"):
			code_rows.append((row as RawCodeRow).code)
	var label: LocalVariable = by_name.get("label") as LocalVariable
	return SUPPORT.pins(TEST_NAME, [
		["neither spelling is left as a code line", code_rows, PackedStringArray()],
		["the subgroup end is a fact of the variable after it",
			_attributes(by_name, "run_boost", ["group", "subgroup", "subgroup_end"]), {"subgroup_end": true}],
		["an untyped @onready reads as Variant and keeps no type in code",
			[label.onready, label.untyped, label.type_name, str(label.default_value)] if label != null else [],
			[true, true, "Variant", "$Label"]],
		["the file saves back byte for byte", SUPPORT.reemit(source, VERIFY_PATH), source],
	]) and _untyped_onready_survives_the_window()


## The variable window has no "Write the type in code" tick for an @onready, so it always sends
## "untyped": false. Saving the row untouched must not write a `: Variant` the file never had, and
## picking a type must write that type.
static func _untyped_onready_survives_the_window() -> bool:
	var written: PackedStringArray = PackedStringArray()
	for picked_type: String in ["Variant", "Label"]:
		var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
		dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
		dock.setup(SUPPORT.reopen("extends Node\n\n@onready var label = $Label\n"))
		var label: LocalVariable = null
		for row: Variant in dock._current_sheet.events:
			if row is LocalVariable and (row as LocalVariable).name == "label":
				label = row as LocalVariable
		dock._variables._on_variable_dialog_confirmed("label", picked_type, "$Label", "tree",
			{"editing": true, "variable_resource": label, "untyped": false, "default_text": "$Label"},
			false, false, PackedStringArray(), {}, true)
		var output: String = SUPPORT.compile_output(dock._current_sheet, "user://export_options_lift_window.gd")
		written.append(output.substr(output.find("@onready")).get_slice("\n", 0))
		dock.free()
	return SUPPORT.check(TEST_NAME, "the window keeps an untyped @onready untyped, and writes a picked type",
		written, PackedStringArray(["@onready var label = $Label", "@onready var label: Label = $Label"]))


## What each option compiles to when a row is given it, the way the variable dialog gives it: the
## tree-row emitter and the Properties-table (dictionary) emitter must spell every one the same.
static func _authoring_spellings() -> bool:
	var rows: Array = [
		["prefix group", {"group": "Bullet", "group_prefix": "bullet"}, "int", false,
			"@export_group(\"Bullet\", \"bullet\")\n@export var bullet_count: int = 3"],
		["prefix subgroup", {"group": "Movement", "subgroup": "Jump", "subgroup_prefix": "jump_"}, "int", false,
			"@export_group(\"Movement\")\n@export_subgroup(\"Jump\", \"jump_\")\n@export var bullet_count: int = 3"],
		["group end", {"group_end": true}, "int", false, "@export_group(\"\")\n@export var bullet_count: int = 3"],
		["subgroup end", {"subgroup_end": true}, "int", false, "@export_subgroup(\"\")\n@export var bullet_count: int = 3"],
		["untyped", {}, "int", true, "@export var bullet_count = 3"],
		["raw-path file picker", {"file": {"mode": "file", "plain_path": true, "filters": ["*.png"]}}, "String", false,
			"@export_file_path(\"*.png\") var bullet_count: String = 3"],
		["free-form custom with usage", {"custom_hint": {"hint": "PROPERTY_HINT_RANGE", "text": "0,9", "usage": "PROPERTY_USAGE_STORAGE"}},
			"int", false, "@export_custom(PROPERTY_HINT_RANGE, \"0,9\", PROPERTY_USAGE_STORAGE) var bullet_count: int = 3"],
		["free-form custom without usage", {"custom_hint": {"hint": "PROPERTY_HINT_NONE", "text": ""}},
			"int", false, "@export_custom(PROPERTY_HINT_NONE, \"\") var bullet_count: int = 3"],
	]
	var pins: Array = []
	for row: Array in rows:
		var variable: LocalVariable = LocalVariable.new()
		variable.name = "bullet_count"
		variable.exported = true
		variable.type_name = str(row[2])
		variable.default_value = 3
		variable.attributes = row[1]
		variable.untyped = bool(row[3])
		pins.append(["%s compiles from a row" % row[0], SheetCompiler._emit_tree_variable_line(variable), row[4]])
		# The dictionary path writes no type-less spelling (a Properties-table variable always has its
		# type column), so only the attribute-driven rows are asked of it.
		if not bool(row[3]):
			var descriptor: Dictionary = {"type": row[2], "default": 3, "exported": true, "attributes": row[1]}
			pins.append(["%s compiles from the Properties table" % row[0],
				"\n".join(SheetCompiler._emit_variables({"bullet_count": descriptor})), row[4]])
	return SUPPORT.pins(TEST_NAME, pins)


## The named attributes one variable carries, missing keys left out so a pin reads as the file does.
static func _attributes(by_name: Dictionary, variable_name: String, keys: Array) -> Dictionary:
	var variable: LocalVariable = by_name.get(variable_name) as LocalVariable
	if variable == null:
		return {"missing": variable_name}
	var picked: Dictionary = {}
	for key: String in keys:
		if (variable.attributes as Dictionary).has(key):
			picked[key] = variable.attributes[key]
	return picked


static func _declaration(by_name: Dictionary, variable_name: String) -> Dictionary:
	var variable: LocalVariable = by_name.get(variable_name) as LocalVariable
	if variable == null:
		return {"missing": variable_name}
	return {"untyped": variable.untyped, "type_name": variable.type_name, "exported": variable.exported}


## Variable name -> the hint it still keeps verbatim. Empty when every option lifted structured.
static func _verbatim_hints(by_name: Dictionary) -> Dictionary:
	var verbatim: Dictionary = {}
	for variable_name: Variant in by_name.keys():
		var hint: String = (by_name[variable_name] as LocalVariable).export_hint
		if not hint.is_empty():
			verbatim[variable_name] = hint
	return verbatim
