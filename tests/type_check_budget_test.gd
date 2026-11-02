@tool
class_name TypeCheckBudgetTest
extends RefCounted

# The keystroke path stays responsive: one type check on the biggest shipped pack (114 variables, 217
# functions, so the largest stand-in script the check ever builds) is a few milliseconds. Measured at
# about 15 ms warm on the development machine for a refused value and for an accepted one; the budget is
# three times that, so a loaded machine passes and a check that grew a second probe per field does not.

const SUPPORT := preload("res://tests/support.gd")
const NAME := "type_check_budget_test"
const PACK_PATH := "res://eventsheet_addons/platformer_pathfinding/platformer_pathfinding_behavior.gd"
## The median time of one check, in milliseconds.
const CHECK_BUDGET_MS: float = 50.0
## What the row sweep adds to the biggest sheet, in milliseconds: every line compiled at once the first time
## the sheet's types are seen (measured about 180 ms), and with every line known, what an edit costs on top of
## the walk (measured about 20 ms). Both three times that and rounded up.
const SWEEP_COLD_BUDGET_MS: float = 600.0
const SWEEP_WARM_BUDGET_MS: float = 60.0


static func run() -> bool:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(PACK_PATH)
	if sheet == null:
		return SUPPORT.check(NAME, "the pack opens as a sheet", false, true)
	var variable_name: String = ""
	for line: String in EventSheetGDScriptLint.typed_variable_lines(sheet):
		if line.contains(": Dictionary"):
			variable_name = line.trim_prefix("var ").get_slice(":", 0)
			break
	if variable_name.is_empty():
		return SUPPORT.check(NAME, "the pack declares a typed Dictionary variable", false, true)
	# The first check loads the classes the second one reuses.
	_once(sheet, variable_name, "1")
	var refused: Array[float] = []
	var accepted: Array[float] = []
	for round_index: int in range(5):
		refused.append(_once(sheet, variable_name, "1"))
		accepted.append(_once(sheet, variable_name, "{}"))
	refused.sort()
	accepted.sort()
	var finding: Dictionary = EventSheetTypeCheck.check_field("{var_name} = {value}", "value", "1",
		{"var_name": variable_name, "value": "1"}, sheet, PackedStringArray(["delta"]))
	var ok: bool = SUPPORT.pins(NAME, [
		["a whole number into a Dictionary variable of the pack is refused", str(finding.get("level", "")), "error"],
		["a refused value is checked within the budget", refused[2] < CHECK_BUDGET_MS, true],
		["an accepted value is checked within the budget", accepted[2] < CHECK_BUDGET_MS, true],
	])
	print("[INFO] %s: median %.1f ms refused, %.1f ms accepted (budget %.0f ms)" % [NAME, refused[2], accepted[2], CHECK_BUDGET_MS])
	return _sweep_within_budget(sheet) and ok


static func _sweep_within_budget(sheet: EventSheetResource) -> bool:
	var lines: Array[Dictionary] = []
	for function_entry: Variant in sheet.functions:
		for event_entry: Variant in (function_entry as EventFunction).events:
			if event_entry is EventRow:
				for action: Variant in (event_entry as EventRow).actions:
					lines.append({"code": EventSheetMistakeFindings.emitted_line(action), "condition": false})
	EventSheetTypeCheck.forget_lines()
	var started: int = Time.get_ticks_usec()
	EventSheetTypeCheck.judge_lines(sheet, lines, {})
	var cold: float = float(Time.get_ticks_usec() - started) / 1000.0
	var warm: Array[float] = []
	for _round: int in range(5):
		var again: int = Time.get_ticks_usec()
		EventSheetTypeCheck.judge_lines(sheet, lines, {})
		warm.append(float(Time.get_ticks_usec() - again) / 1000.0)
	warm.sort()
	print("[INFO] %s: %d lines swept in %.0f ms the first time, %.1f ms again" % [NAME, lines.size(), cold, warm[2]])
	return SUPPORT.pins(NAME, [
		["a sheet's lines are compiled together within the budget", cold < SWEEP_COLD_BUDGET_MS, true],
		["and an edit that changed none of them stays within its budget", warm[2] < SWEEP_WARM_BUDGET_MS, true],
	])


static func _once(sheet: EventSheetResource, variable_name: String, value: String) -> float:
	var started: int = Time.get_ticks_usec()
	EventSheetTypeCheck.check_field("{var_name} = {value}", "value", value,
		{"var_name": variable_name, "value": value}, sheet, PackedStringArray(["delta"]))
	return float(Time.get_ticks_usec() - started) / 1000.0
