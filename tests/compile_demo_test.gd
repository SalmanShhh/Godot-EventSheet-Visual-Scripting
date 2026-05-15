# EventForge — Compile demo test
@tool
extends RefCounted
class_name CompileDemoTest

const SHEET_PATH: String = "res://demo/sheets/player.tres"
const GOLDEN_PATH: String = "res://demo/sheets/player_generated.gd"
const TEST_OUTPUT_PATH: String = "res://demo/sheets/player_generated_test_output.gd"

## Runs the demo compile golden-file verification.
static func run() -> bool:
var sheet: EventSheetResource = load(SHEET_PATH)
assert(sheet != null, "Failed to load demo sheet")
var result: Dictionary = SheetCompiler.compile(sheet, TEST_OUTPUT_PATH)
assert(bool(result.get("success", false)), "Compiler failed: %s" % str(result.get("errors", [])))
var expected: String = FileAccess.get_file_as_string(GOLDEN_PATH)
var actual: String = str(result.get("output", ""))
var pass: bool = expected == actual
if pass:
print("[PASS] compile_demo_test")
else:
print("[FAIL] compile_demo_test")
print("Expected:\n%s" % expected)
print("Actual:\n%s" % actual)
return pass
