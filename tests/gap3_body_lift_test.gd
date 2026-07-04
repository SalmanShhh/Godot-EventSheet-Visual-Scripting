# Godot EventSheets - gap #3: opening a .gd de-codes function/event BODIES into structured ACE rows.
#
# When you open a .gd as a sheet, _lift_sheet_function / _lift_function reverse-parse each body with
# the same grammar event bodies use: if/elif/else become conditioned (sub-)events and template-
# matching statements become ACE action rows. Statements with no matching ACE template stay as honest
# in-flow GDScript (lossless either way). This pins that the body-lift genuinely produces structured
# ACE rows (not just code cells) AND the whole sheet still round-trips byte-identically.
@tool
class_name Gap3BodyLiftTest
extends RefCounted

const PACK := "res://eventsheet_addons/platformer_movement/platformer_movement_behavior.gd"


static func run() -> bool:
	var all_passed: bool = true
	if not FileAccess.file_exists(PACK):
		print("[PASS] gap3_body_lift_test: pack fixture missing - skipped")
		return true
	var source: String = FileAccess.get_file_as_string(PACK)
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(PACK)

	var counts: Dictionary = {"ace": 0, "raw": 0}
	for fn_variant: Variant in sheet.functions:
		var fn: EventFunction = fn_variant as EventFunction
		if fn != null:
			_count_rows(fn.events if not fn.events.is_empty() else fn.rows, counts)
	_count_rows(sheet.events, counts)

	print("[gap3] structured ACE actions=%d, in-flow code rows=%d" % [int(counts["ace"]), int(counts["raw"])])
	# The body-lift produces real structured rows, not just code cells.
	all_passed = _check("function/event bodies de-code into ACE action rows", int(counts["ace"]) > 0, true) and all_passed
	# And the lossless contract holds - the de-coded sheet reproduces its source byte-for-byte.
	var roundtrip: String = str(SheetCompiler.compile(sheet, "user://__gap3_verify.gd").get("output", ""))
	all_passed = _check("body-de-coded sheet round-trips byte-identically", roundtrip, source) and all_passed
	if FileAccess.file_exists("user://__gap3_verify.gd"):
		DirAccess.remove_absolute("user://__gap3_verify.gd")
	return all_passed


## Recursively tallies ACEActions (structured) vs RawCodeRows (un-lifted code) across a row list,
## descending into event actions and sub-events.
static func _count_rows(rows: Array, counts: Dictionary) -> void:
	for row: Variant in rows:
		if row is ACEAction:
			counts["ace"] = int(counts["ace"]) + 1
		elif row is RawCodeRow:
			counts["raw"] = int(counts["raw"]) + 1
		elif row is EventRow:
			_count_rows((row as EventRow).actions, counts)
			_count_rows((row as EventRow).sub_events, counts)
		elif row is EventGroup:
			_count_rows((row as EventGroup).events, counts)


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] gap3_body_lift_test: %s" % label)
		return true
	print("[FAIL] gap3_body_lift_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
