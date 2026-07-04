# EventForge - Compile demo test
# Golden-file verification for the Phase 1 compiler.
@tool
class_name CompileDemoTest
extends RefCounted

const SHEET_PATH: String = "res://demo/sheets/player.tres"
const GOLDEN_PATH: String = "res://demo/sheets/player_generated.gd"
# user:// so the test never writes byproducts into the repo (the committed golden is
# demo/sheets/player_generated.gd; regenerate it via tools/regenerate_demo_golden.gd).
const TEST_OUTPUT_PATH: String = "user://player_generated_test_output.gd"


## Runs the demo compile golden-file verification.
static func run() -> bool:
	var sheet: EventSheetResource = load(SHEET_PATH) as EventSheetResource
	assert(sheet != null, "Failed to load demo sheet")

	var result: Dictionary = SheetCompiler.compile(sheet, TEST_OUTPUT_PATH)
	assert(bool(result.get("success", false)), "Compiler failed: %s" % str(result.get("errors", [])))

	var expected: String = FileAccess.get_file_as_string(GOLDEN_PATH)
	var actual: String = str(result.get("output", ""))
	# The golden must PARSE, not just byte-match - a broken golden once shipped because
	# only the byte comparison gated it (the editor smoke caught it instead).
	var golden_script: GDScript = GDScript.new()
	golden_script.source_code = expected
	if golden_script.reload(true) != OK:
		print("[FAIL] compile_demo_test: golden does not parse as GDScript")
		return false
	var passed: bool = expected == actual
	if passed:
		print("[PASS] compile_demo_test")
	else:
		print("[FAIL] compile_demo_test")
		print("Expected:\n%s" % expected)
		print("Actual:\n%s" % actual)
	return passed
