# The declarations at the top of a script open as variable rows: a constant of any expression (with the
# type Godot infers for it), a variable with no value, a type written with a space before its colon, a
# hinted export that infers its type, and the annotation line that belongs to a declaration. The file
# saves back byte for byte.
@tool
class_name ScriptLevelDeclarationsLiftTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const NAME := "script_level_declarations_lift_test"
const SOURCE := """extends Node

const SPEED = 160
const HIT_MARGIN = 0.050
const CELL = Vector2i(64, 64)
const TAN30DEG = tan(deg_to_rad(30))
const BULLET_SCENE = preload("res://player/bullet.tscn")
const LIMIT: float = deg_to_rad(140.0)
var score
var tween : Tween
@onready var grid : Grid = get_parent()
@export_range(1, 1000) var row_size := 100
@warning_ignore("unused_private_class_variable")
var _cache := 1
@warning_ignore("unused_signal")
signal coin_collected()
signal done
"""


static func run() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = SUPPORT.reopen(SOURCE)
	var variables: Dictionary = {}
	var raw_declarations: int = 0
	for row: Variant in sheet.events:
		if row is LocalVariable:
			variables[(row as LocalVariable).name] = row
		elif row is RawCodeRow:
			for line: String in (row as RawCodeRow).code.split("\n"):
				if line.begins_with("const ") or line.begins_with("var ") or line.begins_with("@"):
					raw_declarations += 1
	ok = SUPPORT.check(NAME, "no declaration stays a block of code", raw_declarations, 0) and ok
	var types: Dictionary = {}
	for variable_name: Variant in variables.keys():
		types[variable_name] = (variables[variable_name] as LocalVariable).type_name
	ok = SUPPORT.check(NAME, "constants read as the type Godot infers", [types.get("SPEED"), types.get("HIT_MARGIN"), types.get("CELL"),
		types.get("TAN30DEG"), types.get("BULLET_SCENE"), types.get("LIMIT")], ["int", "float", "Vector2i", "float", "PackedScene", "float"]) and ok
	ok = SUPPORT.check(NAME, "a constant is a constant row", (variables.get("TAN30DEG") as LocalVariable).is_constant if variables.has("TAN30DEG") else null, true) and ok
	var score: LocalVariable = variables.get("score") as LocalVariable
	ok = SUPPORT.check(NAME, "a variable with no value has none and no type", [score.no_default, score.untyped, score.type_name] if score != null else [], [true, true, "Variant"]) and ok
	ok = SUPPORT.check(NAME, "a space before the colon is remembered", (variables.get("tween") as LocalVariable).spaced_colon if variables.has("tween") else null, true) and ok
	var onready_grid: LocalVariable = variables.get("grid") as LocalVariable
	ok = SUPPORT.check(NAME, "a typed @onready is a row", [onready_grid.onready, onready_grid.type_name] if onready_grid != null else [], [true, "Grid"]) and ok
	var row_size: LocalVariable = variables.get("row_size") as LocalVariable
	ok = SUPPORT.check(NAME, "a hinted export infers its type", [row_size.exported, row_size.inferred_type, row_size.export_hint] if row_size != null else [],
		[true, true, "@export_range(1, 1000)"]) and ok
	var cache: LocalVariable = variables.get("_cache") as LocalVariable
	ok = SUPPORT.check(NAME, "the @warning_ignore line stays attached to its variable", cache.leading_lines if cache != null else [], PackedStringArray(["@warning_ignore(\"unused_private_class_variable\")"])) and ok
	var signals: Dictionary = {}
	for row: Variant in sheet.events:
		if row is SignalRow:
			signals[(row as SignalRow).signal_name] = row
	ok = SUPPORT.check(NAME, "the @warning_ignore line stays attached to its signal", (signals.get("coin_collected") as SignalRow).leading_lines if signals.has("coin_collected") else [],
		PackedStringArray(["@warning_ignore(\"unused_signal\")"])) and ok
	ok = SUPPORT.check(NAME, "the file is written back byte for byte", SUPPORT.reemit(SOURCE, "user://script_level_declarations_out.gd"), SOURCE) and ok
	return ok
