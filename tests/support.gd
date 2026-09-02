# Godot EventSheets - the one assertion vocabulary every test in this folder speaks.
#
# Nearly every test file used to carry its own byte-identical copy of the same eight-line `_check`,
# differing only in the label prefix it printed. This is that function, once, with the prefix passed
# in - so a test keeps its own name in the output while the reporting lives in one place.
#
# THE PRINTED LINES ARE A CONTRACT. `tests/run_tests.gd`, `tools/test_report.gd`,
# `tools/run_tests_parallel.ps1` and CI all parse them: `[PASS] <prefix>: <label>`,
# `[FAIL] <prefix>: <label>` and the two-space-indented `expected:` / `actual:` pair beneath a
# failure, with `actual:` padded to line its value up under the expected one. Changing any of those
# shapes breaks the readers, so change the readers first or not at all.
#
# This file is not a test. `run_tests.gd` loads every `.gd` under `tests/` and skips the ones with
# no `static func run()`, which is exactly what a shared helper living here should be.
@tool
class_name EventSheetTestSupport
extends RefCounted


## Reports one assertion in the suite's line format and returns whether it held, so a caller can
## fold it: `all_passed = EventSheetTestSupport.check(P, "label", got, want) and all_passed`.
##
## `label_prefix` is the reporting test's own name (`"const_roundtrip_test"`), printed before the
## label with `": "` between them. `actual` and `expected` are compared with `==`, so pass VALUES
## rather than a boolean-and chain: `check(P, "x", a and b, "text")` compares a bool against a
## String, which is a runtime error in GDScript and takes the whole test down silently.
static func check(label_prefix: String, label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] %s: %s" % [label_prefix, label])
		return true
	print("[FAIL] %s: %s" % [label_prefix, label])
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false


## Reports a whole table of assertions under one prefix and returns whether every one of them held.
##
## Each row is `[label: String, actual: Variant, expected: Variant]` - the same three values
## `check` takes, in the same order. EVERY row is evaluated and reported: the result is the AND of
## all of them, never a short circuit, so one red pin never hides the ones after it. A row that is
## not a three-cell Array is reported as a failure rather than skipped, because a silently ignored
## pin is a test that stopped testing without saying so.
static func pins(label_prefix: String, rows: Array) -> bool:
	var all_passed: bool = true
	for row: Variant in rows:
		if not (row is Array) or (row as Array).size() != 3:
			print("[FAIL] %s: malformed pin row (want [label, actual, expected], got %s)"
				% [label_prefix, str(row)])
			all_passed = false
			continue
		var cells: Array = row as Array
		all_passed = check(label_prefix, str(cells[0]), cells[1], cells[2]) and all_passed
	return all_passed


## Compiles a sheet and returns the generated GDScript, which is what a compile test actually wants
## out of the compiler's result Dictionary (its `"output"` key; `""` when compilation produced none).
##
## `output_path` is the path the sheet is being saved to, and the compiler needs it for anything
## whose emission depends on where the file lands; leave it empty for a sheet with no home yet.
static func compile_output(sheet: EventSheetResource, output_path: String = "") -> String:
	return str(SheetCompiler.compile(sheet, output_path).get("output", ""))


## Opens generated GDScript back as a sheet, the way the editor opens a `.gd` file.
##
## `lift` false imports without lifting statements into ACE rows, which is how a test pins the
## verbatim fallback. `script_path` is the path the source came from, for the readings that need it.
static func reopen(source: String, lift: bool = true, script_path: String = "") -> EventSheetResource:
	return GDScriptImporter.new().import_external_source(source, lift, script_path)


## Reopens generated GDScript and re-emits it from the reopened sheet, returning the second text.
##
## This is the round-trip proof in one call: `reemit(source, path) == source` is the lossless
## contract, that opening a `.gd` and saving it untouched reproduces the file byte for byte. It
## returns the re-emitted text rather than a verdict so a caller that wants to print both sides of a
## mismatch still can. `verify_path` is the path the re-emission is saved to - a `user://` path
## naming the test is the convention here, and it must be the same one on both sides of the compare.
static func reemit(source: String, verify_path: String, lift: bool = true) -> String:
	var reopened: EventSheetResource = reopen(source, lift)
	if reopened == null:
		return ""
	reopened.external_source_path = verify_path
	return compile_output(reopened, verify_path)
