# Godot EventSheets - a sheet that calls a behaviour on a child node declares it once, with its type.
#
# `$HudKit.set_text(...)` works, but Godot cannot say what `$HudKit` is, so a hand edit gets no list of
# what the node can do and a typo is found only when the line runs. A sheet that keeps typed variables
# writes `@onready var hud_kit: HudKitBehavior = $HudKit` under its class head and calls through it. What
# this pins:
#   - a file made before this existed (`$HudKit.` everywhere) opens and saves byte for byte, in its own form
#   - the same sheet, switched to typed variables, writes the declaration and the calls through it, and the
#     result parses as GDScript
#   - that file opens as the same rows (same verbs, same words) and saves byte for byte
#   - the places a variable cannot serve keep `$Path`: a handler Godot runs early, a static function, a
#     class inside the file, a class-level initialiser, a string and a comment
#   - two nodes with the same name under different parents get different variables, and a name the file
#     already uses is never taken
#   - a hand-written script with a variable of its own opens exactly as it did, and saves byte for byte
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME := "typed_node_variables_test"
const NodeVariables := preload("res://addons/eventforge/compiler/node_variables.gd")

const OLD_FORM: String = """extends Control


func _ready() -> void:
	$HudKit.set_text("ScoreLabel", "Ready")
	$HudKit.show_toast("Hello")


func _process(_delta: float) -> void:
	if $HudKit.is_panel_visible("GameScreen"):
		$HudKit.set_text("ScoreLabel", "Playing")
"""


static func run() -> bool:
	var ok: bool = true
	ok = _old_form_stays(ok)
	ok = _typed_form(ok)
	ok = _where_a_path_stays(ok)
	ok = _names(ok)
	ok = _hand_written(ok)
	return ok


static func _compiled(sheet: EventSheetResource, path: String) -> String:
	sheet.external_source_path = path
	return SUPPORT.compile_output(sheet, path)


static func _old_form_stays(ok: bool) -> bool:
	var path: String = SUPPORT.own_path("typed_old_form.gd")
	var sheet: EventSheetResource = SUPPORT.reopen(OLD_FORM)
	var rows: Array = [
		["a file with only `$HudKit.` calls is not read as typed", sheet.typed_node_variables, false],
		["and saves byte for byte, in its own form", _compiled(sheet, path), OLD_FORM],
	]
	return SUPPORT.pins(TEST_NAME, rows) and ok


## Every verb the sheet's rows write: provider, verb and the values in the slots, in file order.
static func _verbs(sheet: EventSheetResource) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	_collect(sheet.events, found)
	for function_entry: Variant in sheet.functions:
		if function_entry is EventFunction:
			_collect((function_entry as EventFunction).events, found)
	return found


static func _collect(rows: Array, into: PackedStringArray) -> void:
	for entry: Variant in rows:
		if entry is EventRow:
			for condition: Variant in (entry as EventRow).conditions:
				var term: ACECondition = condition as ACECondition
				into.append("c %s::%s %s %s" % [term.provider_id, term.ace_id, str(term.params), term.codegen_template])
			for action: Variant in (entry as EventRow).actions:
				if action is ACEAction:
					var step: ACEAction = action as ACEAction
					into.append("a %s::%s %s %s" % [step.provider_id, step.ace_id, str(step.params), step.codegen_template])
			_collect((entry as EventRow).sub_events, into)
		elif entry is EventGroup:
			_collect((entry as EventGroup).child_rows(), into)


static func _typed_form(ok: bool) -> bool:
	var path: String = SUPPORT.own_path("typed_form.gd")
	var sheet: EventSheetResource = SUPPORT.reopen(OLD_FORM)
	var old_verbs: PackedStringArray = _verbs(sheet)
	sheet.typed_node_variables = true
	var typed: String = _compiled(sheet, path)
	var reopened: EventSheetResource = SUPPORT.reopen(typed)
	var script: GDScript = GDScript.new()
	script.source_code = typed
	var rows: Array = [
		["the declaration sits under the class head", typed.begins_with("extends Control\n\n# Nodes this sheet calls, declared once with their type.\n@onready var hud_kit: HudKitBehavior = $HudKit\n\n\nfunc _ready()"), true],
		["calls go through the variable", typed.contains("\thud_kit.set_text(\"ScoreLabel\", \"Ready\")\n"), true],
		["no call is left on the path", typed.contains("$HudKit.set_text"), false],
		["the path is written once", typed.count("$HudKit"), 1],
		["the typed file parses as GDScript", script.reload(), OK],
		["the file opens as typed", reopened.typed_node_variables, true],
		["and remembers the class of the node", reopened.node_variable_types, {"$HudKit": "HudKitBehavior"}],
		["it opens as the same rows as the old form", _verbs(reopened), old_verbs],
		["it saves byte for byte", _compiled(reopened, path), typed],
		["the old form's rows come back as the same file", _compiled(SUPPORT.reopen(OLD_FORM), path), OLD_FORM],
	]
	return SUPPORT.pins(TEST_NAME, rows) and ok


static func _where_a_path_stays(ok: bool) -> bool:
	var source: String = """extends Control

var cached: Variant = $HudKit.is_panel_visible("A")


func _init() -> void:
	$HudKit.hide_panel("Early")


func _enter_tree() -> void:
	$HudKit.hide_panel("Entering")


static func helper(node: Node) -> void:
	node.get_node("HudKit").hide_panel("Static")


class Inner:
	func poke(node: Node) -> void:
		$HudKit.hide_panel("Inner")


func _ready() -> void:
	print("$HudKit.hide_panel is text")  # $HudKit.hide_panel is a comment
	$HudKit.hide_panel("Ready")
"""
	var lines: PackedStringArray = source.split("\n")
	NodeVariables.apply(lines, {"$HudKit": "HudKitBehavior"})
	var typed: String = "\n".join(lines)
	var rows: Array = [
		["a handler Godot runs early keeps the path", typed.contains("func _init() -> void:\n\t$HudKit.hide_panel(\"Early\")"), true],
		["so does _enter_tree", typed.contains("func _enter_tree() -> void:\n\t$HudKit.hide_panel(\"Entering\")"), true],
		["a class-level initialiser keeps the path", typed.contains("var cached: Variant = $HudKit.is_panel_visible(\"A\")"), true],
		["a class inside the file keeps the path", typed.contains("\t\t$HudKit.hide_panel(\"Inner\")"), true],
		["text and comments are left as written", typed.contains("print(\"$HudKit.hide_panel is text\")  # $HudKit.hide_panel is a comment"), true],
		["an ordinary function goes through the variable", typed.contains("\thud_kit.hide_panel(\"Ready\")"), true],
		["a node with no known class is left alone", _without_class(source), source],
	]
	return SUPPORT.pins(TEST_NAME, rows) and ok


static func _without_class(source: String) -> String:
	var lines: PackedStringArray = source.split("\n")
	NodeVariables.apply(lines, {"$Other": "HudKitBehavior"})
	return "\n".join(lines)


static func _names(ok: bool) -> bool:
	var source: String = """extends Node2D


func _ready() -> void:
	$Player/Movement.go()
	$Jumper/Movement.go()
	$Player/Name.go()
	var hud_kit: int = 3
	$HudKit.show_toast(str(hud_kit))
"""
	var lines: PackedStringArray = source.split("\n")
	NodeVariables.apply(lines, {"$Player/Movement": "MoveA", "$Jumper/Movement": "MoveB", "$Player/Name": "NameBehavior", "$HudKit": "HudKitBehavior"})
	var typed: String = "\n".join(lines)
	var rows: Array = [
		["the first node takes its own name", typed.contains("@onready var movement: MoveA = $Player/Movement\n"), true],
		["the second, with the same name, takes its parent's name in front", typed.contains("@onready var jumper_movement: MoveB = $Jumper/Movement\n"), true],
		["a name the host class has is not taken", typed.contains("@onready var player_name: NameBehavior = $Player/Name\n"), true],
		["a name the file already uses is not taken", typed.contains("@onready var hud_kit_node: HudKitBehavior = $HudKit\n"), true],
		["the local keeps its own name", typed.contains("var hud_kit: int = 3"), true],
	]
	return SUPPORT.pins(TEST_NAME, rows) and ok


static func _hand_written(ok: bool) -> bool:
	var path: String = SUPPORT.own_path("typed_hand_written.gd")
	var source: String = """extends Control

@onready var hud: HudKitBehavior = $HudKit


func _ready() -> void:
	hud.set_text("ScoreLabel", "Ready")
"""
	var sheet: EventSheetResource = SUPPORT.reopen(source)
	# The same lines as the compiler writes them, name and place and all, but without the comment it puts above
	# them: still a script somebody wrote, so its variable stays a variable of its own.
	var look_alike: String = """extends Control

@onready var hud_kit: HudKitBehavior = $HudKit


func _ready() -> void:
	hud_kit.set_text("ScoreLabel", "Ready")
"""
	var alike: EventSheetResource = SUPPORT.reopen(look_alike)
	var rows: Array = [
		["a script with a variable of its own is read as it stands", sheet.typed_node_variables, false],
		["and saves byte for byte", _compiled(sheet, path), source],
		["so is one whose variable looks just like the compiler's", alike.typed_node_variables, false],
		["and its variable is still a row of its own", _compiled(alike, path), look_alike],
	]
	return SUPPORT.pins(TEST_NAME, rows) and ok
