# EventForge - the public GDScript-basics coverage receipt's regression pin. Every row of
# docs/GDSCRIPT-BASICS-COVERAGE.md rests on a named ACE, block kind, or resource seam; this
# test asserts each of those exists, so renaming or dropping one breaks the suite before it
# breaks the published table. IDs only - behavior is pinned by each feature's own test.
@tool
class_name GDScriptBasicsCoverageTest
extends RefCounted

## One entry per receipt row that rests on a builtin ACE id (frozen API).
const REQUIRED_ACE_IDS: PackedStringArray = [
	"SetLocalConst",           # constants (local)
	"LoopBreak", "LoopContinue",           # break / continue
	"LoopIndex", "LoopIndexNamed",         # loop counters
	"EmitSignal", "ConnectSignal",         # signals
	"Wait",                                # await / coroutines
	"LambdaValue", "LambdaStatement", "CallableFromMethod", "CallableBind",  # lambdas / callables
	"InlineIf",                            # ternary (Value If)
	"TextFromPattern", "FormatString",     # string formatting
	"IsNull",                              # null checks
	"ExpressionIsTrue",                    # the escape-hatch condition
	"SetProperty",                         # generic property access
	"OnEditorRun",                         # @tool / editor scripts
]

## Receipt rows resting on Custom Block kinds.
const REQUIRED_BLOCK_KINDS: PackedStringArray = ["enum", "signal", "preload", "region"]


static func run() -> bool:
	var ok: bool = true

	var known_ids: Dictionary = {}
	for descriptor: ACEDescriptor in EventForgeBuiltinACEs.get_descriptors():
		known_ids[descriptor.ace_id] = true
	for required_id: String in REQUIRED_ACE_IDS:
		ok = _check(ok, known_ids.has(required_id), "receipt ACE exists: Core/%s" % required_id)

	for kind_id: String in REQUIRED_BLOCK_KINDS:
		ok = _check(ok, EventSheetBlockRegistry.get_kind(kind_id) != null, "receipt block kind exists: %s" % kind_id)

	# Resource seams the table names: properties (setter/getter), doc comments, tool button,
	# the loop index, and tool-mode sheets. Property existence = the seam is still there.
	var variable_probe: LocalVariable = LocalVariable.new()
	ok = _check(ok, "setter_body" in variable_probe and "getter_body" in variable_probe, "properties seam (LocalVariable setter/getter)")
	var function_probe: EventFunction = EventFunction.new()
	ok = _check(ok, "doc_comment" in function_probe and "tool_button_label" in function_probe, "doc comment + Inspector button seams (EventFunction)")
	var pick_probe: PickFilter = PickFilter.new()
	ok = _check(ok, "index_name" in pick_probe, "loop index seam (PickFilter.index_name)")
	var sheet_probe: EventSheetResource = EventSheetResource.new()
	ok = _check(ok, "tool_mode" in sheet_probe and "class_description" in sheet_probe, "tool mode + class doc seams (EventSheetResource)")

	# The published table itself exists and still carries its two scope notes.
	var receipt: String = FileAccess.get_file_as_string("res://docs/GDSCRIPT-BASICS-COVERAGE.md")
	ok = _check(ok, not receipt.is_empty(), "the coverage receipt doc exists")
	ok = _check(ok, receipt.contains("Scope notes"), "the receipt keeps its scope notes")

	return ok


static func _check(ok: bool, condition: bool, label: String) -> bool:
	if not condition:
		print("  [FAIL] ", label)
	return ok and condition
