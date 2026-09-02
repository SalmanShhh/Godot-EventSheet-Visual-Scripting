# Remember Between Runs: a sheet variable carrying the `remember: true` attribute compiles into
# the persistence trio at the end of the file (an @onready boot that recalls saved values, plus
# the recall/store pair writing user://remembered.cfg on tree exit). The trio is name-addressed:
# a sheet that already carries `_ef_recall_remembered` (a reopened generated file, where the trio
# lifted as ordinary rows) must NOT get a second copy, or the reopen -> resave cycle would drift.
class_name RememberVariablesTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const PREFIX := "remember_variables_test"


static func run() -> bool:
	var all_passed: bool = true

	# ── Baseline: two remembered variables, one plain, one remembered-but-const ──
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.variables = {
		"high_score": {"type": "int", "default": 0, "exported": true, "attributes": {"remember": true}},
		"plain_var": {"type": "int", "default": 3, "exported": true},
		"volume": {"type": "float", "default": 1.0, "exported": true, "attributes": {"remember": true, "tooltip": "Kept between sessions."}},
		"MAX_LIVES": {"type": "int", "default": 9, "exported": false, "const": true, "attributes": {"remember": true}},
	}
	var result: Dictionary = SheetCompiler.compile(sheet, "user://remember_vars_out.gd")
	var output: String = str(result.get("output", ""))
	all_passed = SUPPORT.pins(PREFIX, [
		["compile succeeds", bool(result.get("success", false)), true],
		["boot member emits", output.contains("@onready var __ef_remember_boot: bool = _ef_recall_remembered()"), true],
		["recall reads high_score", output.contains("high_score = __remember_cfg.get_value(\"vars\", \"high_score\", high_score)"), true],
		["recall reads volume", output.contains("volume = __remember_cfg.get_value(\"vars\", \"volume\", volume)"), true],
		["store writes high_score", output.contains("__remember_cfg.set_value(\"vars\", \"high_score\", high_score)"), true],
		["store saves the file", output.contains("__remember_cfg.save(\"user://remembered.cfg\")"), true],
		["save-on-exit arms", output.contains("tree_exiting.connect(_ef_store_remembered)"), true],
		["plain variable is not recalled", output.contains("plain_var = __remember_cfg"), false],
		["const variable is not recalled", output.contains("MAX_LIVES = __remember_cfg"), false],
	]) and all_passed

	# The emitted file must parse: the trio references Node API (@onready, tree_exiting).
	var parsed: GDScript = GDScript.new()
	parsed.source_code = output
	all_passed = _check("emitted source parses", parsed.reload(), OK) and all_passed

	# Emission is deterministic (parity contract).
	var second: Dictionary = SheetCompiler.compile(sheet, "user://remember_vars_out.gd")
	all_passed = _check("emission is deterministic", str(second.get("output", "")) == output, true) and all_passed

	# ── Reopen cycle: the emitted file lifts (trio becomes ordinary rows, remember attribute is
	# not recovered) and re-emits byte-identically, because the name-addressed guard suppresses a
	# second trio while the lifted rows re-emit verbatim ──
	var reemitted: String = SUPPORT.reemit(output, "user://remember_vars_rt.gd")
	all_passed = _check("reopen then resave is byte-identical", reemitted == output, true) and all_passed

	# ── Section key: a named class saves under its own section, not "vars" ──
	var named: EventSheetResource = EventSheetResource.new()
	named.custom_class_name = "SaveDemo"
	named.variables = {"coins": {"type": "int", "default": 0, "exported": true, "attributes": {"remember": true}}}
	var named_output: String = SUPPORT.compile_output(named, "user://remember_vars_named.gd")
	all_passed = _check("named sheet uses its class as the section", named_output.contains("__remember_cfg.get_value(\"SaveDemo\", \"coins\", coins)"), true) and all_passed

	# ── Name-addressed guard: an existing _ef_recall_remembered means NO second trio ──
	var reopened: EventSheetResource = EventSheetResource.new()
	reopened.variables = {"coins": {"type": "int", "default": 0, "exported": true, "attributes": {"remember": true}}}
	var lifted_recall: EventFunction = EventFunction.new()
	lifted_recall.function_name = "_ef_recall_remembered"
	lifted_recall.return_type = TYPE_BOOL
	var lifted_body: EventRow = EventRow.new()
	var lifted_return: ACEAction = ACEAction.new()
	lifted_return.provider_id = "Core"
	lifted_return.ace_id = "ReturnValue"
	lifted_return.params = {"value": "true"}
	lifted_body.actions.append(lifted_return)
	lifted_recall.events.append(lifted_body)
	reopened.functions.append(lifted_recall)
	var reopened_output: String = SUPPORT.compile_output(reopened, "user://remember_vars_reopened.gd")
	all_passed = _check("existing recall function suppresses the trio", reopened_output.count("func _ef_recall_remembered"), 1) and all_passed
	all_passed = _check("suppressed trio emits no boot member", reopened_output.contains("__ef_remember_boot"), false) and all_passed

	# ── Non-Node host: warned and skipped, never emitted broken ──
	var resource_host: EventSheetResource = EventSheetResource.new()
	resource_host.host_class = "Resource"
	resource_host.variables = {"coins": {"type": "int", "default": 0, "exported": true, "attributes": {"remember": true}}}
	var resource_result: Dictionary = SheetCompiler.compile(resource_host, "user://remember_vars_resource.gd")
	all_passed = _check("resource host emits no trio", str(resource_result.get("output", "")).contains("__ef_remember_boot"), false) and all_passed
	all_passed = _check("resource host warns", str(resource_result.get("warnings", [])).contains("Remember Between Runs needs a Node host"), true) and all_passed

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check(PREFIX, label, actual, expected)
