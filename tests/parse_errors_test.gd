# EventForge - the engine's parse errors, mapped to the rows they belong to.
#
# An event sheet marks a broken event red with the reason. When an opened .gd does not compile, the
# reason shown has to be the ENGINE'S own words on the engine's own line - so the report shape is
# pinned here by value, on the exact two lines Godot prints, and the line-to-row join is pinned
# against a real compile's source map rather than against a hand-built map that could agree with a
# bug. check_file itself runs a second Godot and is exercised end to end only on a file known to
# parse, so the suite never depends on a subprocess to decide a failure.
@tool
class_name ParseErrorsTest
extends RefCounted

## Exactly what `--check-only` prints for a file with two undeclared identifiers, plus the trailing
## load failure and a message belonging to a DIFFERENT file (a broken dependency), which must not be
## reported against this one.
const CHECK_OUTPUT: String = """Godot Engine v4.7.stable.official - https://godotengine.org

SCRIPT ERROR: Parse Error: Identifier "walk_speed" not declared in the current scope.
   at: GDScript::reload (res://broken.gd:7)
SCRIPT ERROR: Parse Error: Identifier "max_hp" not declared in the current scope.
   at: GDScript::reload (res://broken.gd:8)
SCRIPT ERROR: Parse Error: Expected expression after "+" operator.
   at: GDScript::reload (res://other.gd:3)
ERROR: Failed to load script "res://broken.gd" with error "Parse error".
   at: load (modules/gdscript/gdscript_resource_format.cpp:46)
"""


static func run() -> bool:
	var ok: bool = true
	ok = _report_shape() and ok
	ok = _sheet_storage() and ok
	ok = _rows_are_flagged() and ok
	ok = _a_healthy_file_reports_nothing() and ok
	return ok


## ── the engine's two lines become line + message ─────────────────────────────────────────────────
static func _report_shape() -> bool:
	var ok: bool = true
	var errors: Array = EventSheetParseErrors.parse_output(CHECK_OUTPUT, "res://broken.gd")
	ok = _check("only this file's errors are reported", errors.size(), 2) and ok
	if errors.size() == 2:
		ok = _check("the first error's line", int((errors[0] as Dictionary).get("line", 0)), 7) and ok
		ok = _check("the first error's message is the engine's own",
			str((errors[0] as Dictionary).get("message", "")),
			"Identifier \"walk_speed\" not declared in the current scope.") and ok
		ok = _check("the second error's line", int((errors[1] as Dictionary).get("line", 0)), 8) and ok
		ok = _check("the second error's message is the engine's own",
			str((errors[1] as Dictionary).get("message", "")),
			"Identifier \"max_hp\" not declared in the current scope.") and ok
	# The same output read against the OTHER file yields that file's one error and nothing else.
	var other: Array = EventSheetParseErrors.parse_output(CHECK_OUTPUT, "res://other.gd")
	ok = _check("a dependency's errors belong to the dependency", other.size(), 1) and ok
	if other.size() == 1:
		ok = _check("and carry its own line", int((other[0] as Dictionary).get("line", 0)), 3) and ok
	ok = _check("output with no parse errors yields none",
		EventSheetParseErrors.parse_output("Godot Engine v4.7.stable.official\n", "res://broken.gd").size(), 0) and ok
	return ok


## ── the count the head bar reads ─────────────────────────────────────────────────────────────────
static func _sheet_storage() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = EventSheetResource.new()
	ok = _check("an unchecked sheet has no errors", EventSheetParseErrors.error_count(sheet), 0) and ok
	EventSheetParseErrors.store_on_sheet(sheet, [{"line": 7, "message": "boom"}])
	ok = _check("the stored count is what the bar shows", EventSheetParseErrors.error_count(sheet), 1) and ok
	ok = _check("and the message comes back",
		str((EventSheetParseErrors.errors_for(sheet)[0] as Dictionary).get("message", "")), "boom") and ok
	EventSheetParseErrors.store_on_sheet(sheet, [])
	ok = _check("a file that parses clears the count", EventSheetParseErrors.error_count(sheet), 0) and ok
	return ok


## ── an error's line resolves to the row built from it ────────────────────────────────────────────
static func _rows_are_flagged() -> bool:
	var ok: bool = true
	var path: String = "res://tests/fixtures/opened_script_structure5.gd"
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(path)
	var result: Dictionary = SheetCompiler.compile(sheet, path)
	var source_map: Array = result.get("source_map", [])
	# The fixture re-emits byte-identically, so a line of the output IS that line of the file. Line 12
	# is the first `draw_line(...)` inside `_draw`.
	var lines: PackedStringArray = str(result.get("output", "")).split("\n")
	ok = _check("line 12 of the file is the draw call the error will name",
		lines[11] if lines.size() > 11 else "", "\tdraw_line(Vector2(0, 0), Vector2(100, 0), trail_color)") and ok
	var diagnostics: Array = EventSheetParseErrors.row_diagnostics([{"line": 12, "message": "boom"}], source_map)
	ok = _check("the line maps to exactly one row", diagnostics.size(), 1) and ok
	if diagnostics.size() == 1:
		ok = _check("the row carries the engine's message",
			str((diagnostics[0] as Dictionary).get("message", "")), "boom") and ok
		var flagged: Resource = EventSheetLineRowMapper.resource_for_line(source_map, 12)
		ok = _check("and it is the row the mapper resolves for that line",
			str((diagnostics[0] as Dictionary).get("uid", "")),
			str(flagged.get_instance_id()) if flagged != null else "") and ok
	# A line past the end of the file flags nothing rather than the nearest row.
	ok = _check("a line outside the file flags nothing",
		EventSheetParseErrors.row_diagnostics([{"line": 9999, "message": "boom"}], source_map).size(), 0) and ok
	return ok


## ── the check itself, on a file known to parse ───────────────────────────────────────────────────
static func _a_healthy_file_reports_nothing() -> bool:
	# End to end through the real subprocess: a healthy project file must come back clean. Anything
	# else means the check is inventing errors, which is the one failure mode worse than showing none.
	return _check("a file that parses reports no errors",
		EventSheetParseErrors.check_file("res://tests/fixtures/opened_script_structure5.gd").size(), 0)


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("[FAIL] %s: expected %s, got %s" % [label, str(expected), str(actual)])
	return false
