# Wave-4 vocabulary: Vanish-Respawn-In, the metric distance condition, Only Once Ever (+
# Forget First Time) and Start Ramp Clock. Emission pins with defaults and a parse gate on the
# awaiting action.
@tool
class_name Wave4VocabTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")


static func run() -> bool:
	var ok: bool = true

	# ── Emission pins ──
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var row: EventRow = EventRow.new()
	row.trigger_id = "OnProcess"
	row.trigger_provider_id = "Core"
	row.conditions.append(_baked_cond("IsWithinDistanceMetric", {"other": "get_parent()", "distance": "64.0", "metric": "3"}, "m1"))
	row.conditions.append(_baked_cond("OnlyOnceEver", {"key": "\"hint_dash\""}, "o1"))
	row.actions.append(_baked_act("VanishRespawnIn", {"seconds": "10.0"}, "v1"))
	row.actions.append(_baked_act("ForgetOnce", {"key": "\"hint_dash\""}, "f1"))
	row.actions.append(_baked_act("StartRampClock", {}, "r1"))
	sheet.events.append(row)
	var output: String = str(SheetCompiler.compile(sheet, "user://wave4_vocab_out.gd").get("output", ""))
	ok = _check("metric 3 emits the grid-steps index", output.contains("][3]) <= maxf(64.0, 0.0)"), true) and ok
	ok = _check("once-ever helper emits with the baked uid", output.contains("func __once_ever_o1(key: String) -> bool:"), true) and ok
	ok = _check("once-ever stores in the Remember file", output.contains("__save.set_value(\"OnceEver\", key, true)"), true) and ok
	ok = _check("vanish hides first", output.contains("visible = false"), true) and ok
	ok = _check("vanish awaits the respawn delay", output.contains("await get_tree().create_timer(maxf(10.0, 0.0)).timeout"), true) and ok
	ok = _check("vanish calls the reset seam", output.contains("if has_method(&\"reset\"):"), true) and ok
	ok = _check("forget writes false", output.contains("__forget_f1.set_value(\"OnceEver\", \"hint_dash\", false)"), true) and ok
	ok = _check("ramp clock stamps minute zero", output.contains("set_meta(&\"__ramp_zero\", float(Time.get_ticks_msec()) / 60000.0)"), true) and ok
	ok = _check("no {uid} survives", output.contains("{uid}"), false) and ok
	var parsed: GDScript = GDScript.new()
	parsed.source_code = output
	ok = _check("emitted source parses (await tolerated)", parsed.reload(), OK) and ok
	return ok


static func _baked_cond(ace_id: String, params: Dictionary, uid: String) -> ACECondition:
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = ace_id
	condition.params = params
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", ace_id)
	condition.codegen_template = descriptor.codegen_template.replace("{uid}", uid)
	condition.member_declaration = descriptor.member_template.replace("{uid}", uid)
	return condition


static func _baked_act(ace_id: String, params: Dictionary, uid: String) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = params
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", ace_id)
	action.codegen_template = descriptor.codegen_template.replace("{uid}", uid)
	return action


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("wave4_vocab_test", label, actual, expected)
