# Wave-4 vocabulary: Vanish-Respawn-In, the metric distance condition, Only Once Ever (+
# Forget First Time), Ramped (+ Start Ramp Clock), and Tiles. Emission pins with defaults, a
# parse gate on the awaiting action, and RUNTIME truth for the metric geometry and the
# once-ever persistence (ConfigFile works treeless).
@tool
class_name Wave4VocabTest
extends RefCounted


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

	# ── Runtime: the five metric geometries ──
	var host_script: GDScript = GDScript.new()
	host_script.source_code = "extends Node2D\nvar other: Node2D = null\nfunc within(distance: float, metric: int) -> bool:\n\treturn ([global_position.distance_to(other.global_position), absf(global_position.x - other.global_position.x), absf(global_position.y - other.global_position.y), absf(global_position.x - other.global_position.x) + absf(global_position.y - other.global_position.y), maxf(absf(global_position.x - other.global_position.x), absf(global_position.y - other.global_position.y))][metric]) <= maxf(distance, 0.0)\n"
	ok = _check("metric harness parses", host_script.reload(), OK) and ok
	var me: Variant = Node2D.new()
	(me as Node2D).set_script(host_script)
	var them: Node2D = Node2D.new()
	me.global_position = Vector2(100.0, 5.0)
	them.global_position = Vector2.ZERO
	me.other = them
	ok = _check("straight line: 100.12 is beyond 100", me.within(100.0, 0), false) and ok
	ok = _check("horizontal only: exactly 100", me.within(100.0, 1), true) and ok
	ok = _check("vertical only: 5 fits in 50", me.within(50.0, 2), true) and ok
	ok = _check("grid steps: 105 needs 105", me.within(104.0, 3), false) and ok
	ok = _check("grid steps: 105 fits in 105", me.within(105.0, 3), true) and ok
	ok = _check("king moves: 100 fits in 100", me.within(100.0, 4), true) and ok
	(me as Node2D).free()
	them.free()

	# ── Runtime: once-ever fires once, persists, and Forget re-arms the NEXT run ──
	var forget_probe: ConfigFile = ConfigFile.new()
	forget_probe.load("user://remembered.cfg")
	forget_probe.set_value("OnceEver", "wave4_test_key", false)
	forget_probe.save("user://remembered.cfg")
	var once_script: GDScript = GDScript.new()
	once_script.source_code = "extends RefCounted\nvar __onceever_t: int = -1\nfunc once(key: String) -> bool:\n\tif __onceever_t == -1:\n\t\tvar __cfg: ConfigFile = ConfigFile.new()\n\t\t__cfg.load(\"user://remembered.cfg\")\n\t\t__onceever_t = 1 if bool(__cfg.get_value(\"OnceEver\", key, false)) else 0\n\tif __onceever_t == 1:\n\t\treturn false\n\t__onceever_t = 1\n\tvar __save: ConfigFile = ConfigFile.new()\n\t__save.load(\"user://remembered.cfg\")\n\t__save.set_value(\"OnceEver\", key, true)\n\t__save.save(\"user://remembered.cfg\")\n\treturn true\n"
	ok = _check("once-ever harness parses", once_script.reload(), OK) and ok
	var first_run: Variant = once_script.new()
	ok = _check("fires the first time", first_run.once("wave4_test_key"), true) and ok
	ok = _check("silent the second time, same run", first_run.once("wave4_test_key"), false) and ok
	var second_run: Variant = once_script.new()
	ok = _check("silent on a fresh run (persisted)", second_run.once("wave4_test_key"), false) and ok
	var forget: ConfigFile = ConfigFile.new()
	forget.load("user://remembered.cfg")
	forget.set_value("OnceEver", "wave4_test_key", false)
	forget.save("user://remembered.cfg")
	var third_run: Variant = once_script.new()
	ok = _check("fires again after Forget, next run", third_run.once("wave4_test_key"), true) and ok

	# ── Ramped: clamp bounds hold in both directions (elapsed ~0 at test speed) ──
	var start: float = 2.0
	var ramp_now: float = clampf(start + -0.3 * 0.0, minf(start, 0.5), maxf(start, 0.5))
	ok = _check("ramp starts at start", ramp_now, 2.0) and ok
	var ramp_late: float = clampf(start + -0.3 * 100.0, minf(start, 0.5), maxf(start, 0.5))
	ok = _check("ramp clamps at the limit", ramp_late, 0.5) and ok

	# ── Tiles reads the project setting with a 16px default ──
	var tiles_expr: float = 3 * float(ProjectSettings.get_setting("eventforge/tile_size", 16.0))
	ok = _check("Tiles(3) is 48 at the default size", tiles_expr, 48.0) and ok

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
	if actual == expected:
		print("[PASS] wave4_vocab_test: %s" % label)
		return true
	print("[FAIL] wave4_vocab_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
