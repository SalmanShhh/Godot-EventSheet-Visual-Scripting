# EventForge - the hand-written-GDScript lift gate.
#
# WHY THIS EXISTS: four separate bugs each reverted whole hand-written files back to verbatim
# blocks - the style guide's two blank lines between functions, an explicit `: Variant`
# parameter, a typed-collection return, and a plain `#` note above a function. Measured across
# this repo, 88.1% of all hand-written code lines were landing in blocks. The entire suite was
# green throughout, because every other lift test builds its own fixture: a fixture written to
# suit the lifter cannot notice that real code does not look like it.
#
# So this gate opens REAL files - the plugin's own hand-written source, chosen because it is
# ordinary style-guide GDScript nobody wrote for a test - and pins the two things that matter:
#
#   1. BYTE-EXACT round-trip on every one. This is the lossless contract measured on real code
#      rather than a fixture, and it is the assertion that must never be relaxed.
#   2. A FLOOR on how many functions come back as real functions. Every bug above failed the
#      same way - a single unreproducible line reverted the whole file - so a floor across
#      several files is what actually screams when one returns. It is a floor, not an exact
#      count, so ordinary edits to these files never produce a false alarm.
@tool
class_name HandwrittenLiftGateTest
extends RefCounted

## Ordinary hand-written sources, none of them compiler output, none written for this test.
const SAMPLES: Array[String] = [
	"res://addons/eventforge/importer/lift_report.gd",
	"res://addons/eventforge/importer/variable_parser.gd",
	"res://addons/eventforge/importer/function_parser.gd",
	"res://addons/eventsheet/ace/vocabulary_inference.gd",
	"res://addons/eventsheet/ace/refactor_follow.gd",
	"res://addons/eventsheet/ace/project_scanner.gd",
	"res://addons/eventsheet/ace/verb_suggestion.gd",
	"res://addons/eventsheet/editor/dock/add_row_requests.gd",
	"res://addons/eventsheet/editor/behaviour_anatomy_panel.gd",
	"res://addons/eventsheet/ace/gdscript_lint.gd",
	"res://addons/eventforge/registration/ace_registry.gd",
]

## These files lift 84 functions today. The floor sits well below that so editing them stays
## free, while any of the whole-file reversions above (which drove this to nearly zero) fails.
##
## The floor alone is NOT what catches a regression, and assuming it did was a mistake worth
## recording: reintroducing the `: Variant` bug against an earlier sample set moved this from 42
## to 41 and sailed straight through. What catches a regression is the raw-block ceiling below,
## plus picking samples that actually CONTAIN each shape. Each file here was chosen for one:
## behaviour_anatomy_panel.gd is the file the `: Variant` bug emptied, all ten functions of it;
## gdscript_lint.gd carries six typed-collection returns; add_row_requests.gd has the mid-file
## `#` notes; and every one of them uses the style guide's two-blank spacing. Every sample was
## verified to FAIL this gate with its bug reintroduced - an untested gate is a decoration.
const FUNCTION_FLOOR: int = 70

## ...and essentially no function should be left sitting as a raw block. THIS is the assertion
## that actually bites: a reversion puts every function of the affected file here at once (eleven,
## for the `: Variant` bug), while the tolerance keeps one awkward new helper from breaking a build.
const RAW_FUNCTION_ROW_CEILING: int = 2


static func run() -> bool:
	var all_passed: bool = true
	var total_functions: int = 0
	var raw_function_rows: int = 0
	var missing: PackedStringArray = PackedStringArray()
	var drifted: PackedStringArray = PackedStringArray()
	for path: String in SAMPLES:
		if not FileAccess.file_exists(path):
			missing.append(path)
			continue
		var source: String = FileAccess.get_file_as_string(path)
		var sheet: EventSheetResource = GDScriptImporter.new().import_external(path)
		if sheet == null:
			drifted.append(path)
			continue
		total_functions += sheet.functions.size()
		for item: Variant in sheet.events:
			if item is RawCodeRow and ((item as RawCodeRow).code.begins_with("func ") \
					or (item as RawCodeRow).code.begins_with("static func ")):
				raw_function_rows += 1
		if str(SheetCompiler.compile(sheet, "user://_handwritten_lift_gate.gd").get("output", "")) != source:
			drifted.append(path)
	# A renamed or deleted sample would make every count below pass vacuously.
	all_passed = _check("every sample file is present to be measured", missing, PackedStringArray()) and all_passed
	all_passed = _check("every hand-written sample round-trips byte-identically",
		drifted, PackedStringArray()) and all_passed
	all_passed = _check("hand-written functions come back as functions (floor %d, have %d)"
		% [FUNCTION_FLOOR, total_functions], total_functions >= FUNCTION_FLOOR, true) and all_passed
	all_passed = _check("almost no function is left as a raw block (ceiling %d, have %d)"
		% [RAW_FUNCTION_ROW_CEILING, raw_function_rows],
		raw_function_rows <= RAW_FUNCTION_ROW_CEILING, true) and all_passed
	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] handwritten_lift_gate_test: %s" % label)
		return true
	print("[FAIL] handwritten_lift_gate_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
