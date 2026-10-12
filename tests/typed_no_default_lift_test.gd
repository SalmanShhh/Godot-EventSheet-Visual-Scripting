# A typed declaration with no initial value lifts to a variable row and saves back byte for byte.
#
# `@export var spark_prefab: PackedScene` is how a slot for the Inspector is usually written, and
# `var target: Node2D` how a member filled in `_ready` is. Both used to open as a code block in the
# variable list, because the only spelling the variable row could write back carried ` = ...`. The
# row now records that the file gave no value and writes none - for as long as the row's default
# stays empty, so a value given later is never hidden.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME := "typed_no_default_lift_test"
const FIXTURE_PATH := "res://tests/fixtures/typed_no_default_vars.gd"
const VERIFY_PATH := "user://typed_no_default_lift.gd"


static func run() -> bool:
	var ok: bool = true
	var source: String = FileAccess.get_file_as_string(FIXTURE_PATH)
	ok = SUPPORT.check(TEST_NAME, "the fixture is on disk", source.is_empty(), false) and ok
	var sheet: EventSheetResource = SUPPORT.reopen(source)

	# Every typed declaration without a value is a variable row, with the type as written and the
	# flag that keeps the spelling. Pinned as [type, exported, no_default, static, onready].
	var expected_rows: Dictionary = {
		"spark_prefab": ["PackedScene", true, true, false, false],
		"creak_sound": ["AudioStream", true, true, false, false],
		"speed": ["float", true, true, false, false],
		"level": ["int", true, true, false, false],
		"reach": ["float", true, true, false, false],
		"data_path": ["String", true, true, false, false],
		"aim": ["NodePath", true, true, false, false],
		"bio": ["String", true, true, false, false],
		"tint": ["Color", true, true, false, false],
		"gait": ["String", true, true, false, false],
		"guards": ["Array[Node2D]", true, true, false, false],
		"shared_target": ["Node", false, true, true, false],
		"target": ["Node2D", false, true, false, false],
		"hp": ["int", false, true, false, false],
		"tags": ["Array[String]", false, true, false, false],
		"lookup": ["Dictionary[String, int]", false, true, false, false],
		"wounded": ["bool", false, true, false, false],
		"health": ["int", false, true, false, false],
	}
	var rows: Dictionary = _variables(sheet)
	ok = SUPPORT.pin_table(TEST_NAME, expected_rows, func(variable_name: String) -> Variant:
		var row: LocalVariable = rows.get(variable_name) as LocalVariable
		if row == null:
			return "no variable row"
		return [row.type_name, row.exported, row.no_default, row.is_static, row.onready]) and ok

	# What the hints became is what a valued declaration of the same spelling becomes, so the
	# Inspector-side editors of the variable dialog see them unchanged.
	ok = SUPPORT.pins(TEST_NAME, [
		["the range hint stays verbatim", _row(rows, "level").export_hint, "@export_range(0, 10)"],
		["the modified range is structured", _row(rows, "reach").attributes.get("range"),
			{"min": "0", "max": "10", "step": "0.5", "or_greater": true}],
		["the file hint is structured", _row(rows, "data_path").attributes.get("file"),
			{"mode": "file", "global": false, "filters": ["*.json"]}],
		["the node path hint is structured", _row(rows, "aim").attributes.get("node_path_types"), ["Node2D"]],
		["the colour keeps no alpha", _row(rows, "tint").attributes.get("no_alpha"), true],
		["the enum keeps its choices", _row(rows, "gait").options, PackedStringArray(["Walk", "Run"])],
		["the group rides on its variable", _row(rows, "guards").attributes.get("group"), "Targets"],
		["the property keeps its setter", _row(rows, "health").setter_body, "health = clampi(value, 0, 100)"],
		["the doc comment becomes the tooltip", _row(rows, "spark_prefab").attributes.get("tooltip"), "Spawned at the hinges."],
		["the default stays empty", _row(rows, "hp").default_value, null],
	]) and ok

	# A trailing comment with no `=` before it would be read into the type, so that line keeps its
	# code block rather than opening as a variable of type `PackedScene # set in the Inspector`.
	ok = SUPPORT.check(TEST_NAME, "a commented declaration stays code", rows.has("note"), false) and ok
	# An @onready with no value has no node to read, and every reader of an @onready row reads one.
	ok = SUPPORT.check(TEST_NAME, "an empty @onready stays code", rows.has("cam"), false) and ok

	# The lossless contract: opened and saved untouched, the file comes back byte for byte.
	ok = SUPPORT.check(TEST_NAME, "the fixture round-trips", SUPPORT.reemit(source, VERIFY_PATH), source) and ok

	# The flag only holds while the default is empty: a value given to the row is written.
	var given: LocalVariable = _row(rows, "hp").duplicate() as LocalVariable
	given.default_value = 3
	var flagged: LocalVariable = _row(rows, "creak_sound")
	var written_null: LocalVariable = flagged.duplicate() as LocalVariable
	written_null.no_default = false
	ok = SUPPORT.pins(TEST_NAME, [
		["an empty slot writes no value", SheetCompiler._emit_tree_variable_line(flagged),
			"@export var creak_sound: AudioStream"],
		["a given value is written", SheetCompiler._emit_tree_variable_line(given), "var hp: int = 3"],
		["an unflagged empty default still says null", SheetCompiler._emit_tree_variable_line(written_null),
			"@export var creak_sound: AudioStream = null"],
	]) and ok

	# One line at a time: each spelling lifts alone, and the ones that must not lift stay code.
	ok = SUPPORT.pin_table(TEST_NAME, {
		"var spark: PackedScene": true,
		"@export var spark: PackedScene": true,
		"@export_storage var spark: PackedScene": true,
		"static var spark: PackedScene": true,
		"@onready var spark: Sprite2D": false,
		"var spark: PackedScene = null": true,
		"var spark: PackedScene # later": false,
		"var spark : PackedScene": false,
		"var spark": false,
		"@export var spark": false,
	}, func(line: String) -> Variant:
		var single: String = "extends Node\n\n%s\n" % line
		var opened: EventSheetResource = SUPPORT.reopen(single, false)
		var lifted: bool = false
		for row: Variant in opened.events:
			lifted = lifted or row is LocalVariable
		var round_trip: String = SUPPORT.reemit(single, VERIFY_PATH, false)
		if round_trip != single:
			return "round trip changed the line to %s" % round_trip
		return lifted) and ok
	return ok


static func _variables(sheet: EventSheetResource) -> Dictionary:
	var found: Dictionary = {}
	if sheet == null:
		return found
	for row: Variant in sheet.events:
		if row is LocalVariable:
			found[(row as LocalVariable).name] = row
	return found


static func _row(rows: Dictionary, variable_name: String) -> LocalVariable:
	var row: LocalVariable = rows.get(variable_name) as LocalVariable
	return row if row != null else LocalVariable.new()
