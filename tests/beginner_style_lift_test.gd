# Beginner-style GDScript lifts: the corpus that proved zero-blocks is style-guide code (typed
# signatures, `var x: int = 1`), but a beginner file spells everything differently - inferred
# `:=` variables and untyped lifecycle headers (`func _physics_process(delta):`). Each spelling
# is recorded on the lifted row and reproduced at emission, so these files get the same
# structured open + byte-exact round-trip the style-guide corpus gets.
@tool
class_name BeginnerStyleLiftTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const SOURCE_PATH := "user://beginner_style_lift.gd"
const SOURCE := """extends CharacterBody2D

enum State { PATROL, CHASE, FLEE }

var state := State.PATROL
var hp := 100


func _physics_process(delta):
	match state:
		State.PATROL:
			patrol_step(delta)
			if can_see_player():
				state = State.CHASE
		State.CHASE:
			chase_step(delta)
			if hp < 20:
				state = State.FLEE
		State.FLEE:
			if not can_see_player():
				state = State.PATROL
"""


static func run() -> bool:
	var ok: bool = true
	var file: FileAccess = FileAccess.open(SOURCE_PATH, FileAccess.WRITE)
	file.store_string(SOURCE)
	file.close()
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(SOURCE_PATH)
	ok = _check("beginner file imports", sheet != null, true) and ok

	# Inferred `:=` variables lift as first-class rows with the walrus spelling recorded.
	var hp_var: LocalVariable = _find_variable(sheet, "hp")
	ok = _check("hp lifts as a variable", hp_var != null, true) and ok
	ok = _check("hp records the walrus spelling", hp_var != null and hp_var.inferred_type, true) and ok
	ok = _check("hp keeps its verbatim default", str(hp_var.default_value) if hp_var != null else "", "100") and ok
	var state_var: LocalVariable = _find_variable(sheet, "state")
	ok = _check("state lifts as a variable", state_var != null, true) and ok
	ok = _check("state keeps its enum default", str(state_var.default_value) if state_var != null else "", "State.PATROL") and ok

	# The untyped lifecycle header lifts to the physics-tick trigger with structured match cases.
	var tick_event: EventRow = null
	for row: Variant in sheet.events:
		if row is EventRow and (row as EventRow).trigger_id == "OnPhysicsProcess":
			tick_event = row as EventRow
	ok = _check("untyped _physics_process lifts to the tick trigger", tick_event != null, true) and ok
	var lifted_match: MatchRow = null
	if tick_event != null and tick_event.actions.size() == 1 and tick_event.actions[0] is MatchRow:
		lifted_match = tick_event.actions[0] as MatchRow
	ok = _check("the match lifts as one structured row", lifted_match != null, true) and ok
	ok = _check("all three states become cases", lifted_match.cases.size() if lifted_match != null else -1, 3) and ok

	# The whole point: reopening and saving the beginner file changes nothing.
	var compiled: Dictionary = SheetCompiler.compile(sheet, "user://beginner_style_lift_out.gd")
	ok = _check("round-trip is byte-identical", str(compiled.get("output", "")) == SOURCE, true) and ok

	return ok


static func _find_variable(sheet: EventSheetResource, variable_name: String) -> LocalVariable:
	for row: Variant in sheet.events:
		if row is LocalVariable and (row as LocalVariable).name == variable_name:
			return row as LocalVariable
	return null


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("beginner_style_lift_test", label, actual, expected)
