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
	return ok


static func _once(sheet: EventSheetResource, variable_name: String, value: String) -> float:
	var started: int = Time.get_ticks_usec()
	EventSheetTypeCheck.check_field("{var_name} = {value}", "value", value,
		{"var_name": variable_name, "value": value}, sheet, PackedStringArray(["delta"]))
	return float(Time.get_ticks_usec() - started) / 1000.0
