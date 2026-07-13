# EventForge - StatForge pack (buff-stack stats) + StatSheetResource + the Juice tints and
# the rounded-corner theme tokens shipped alongside. Pins the stat MATH (add/multiply/
# override-highest, clamp/wrap), tag/source bulk ops, activation, timers + expiry, threshold
# crossing (one-shot vs repeating, re-arm), and the .tres loadout loader.
@tool
class_name StatForgeTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true
	var forge: Node = (load("res://eventsheet_addons/stat_forge/stat_forge_behavior.gd") as GDScript).new()
	forge.set("auto_tick", false)

	# ── The computation: (base + adds) * multipliers; override = HIGHEST wins ──
	forge.call("set_stat_base", "speed", 100.0)
	forge.call("add_buff", "boots", "speed", 20.0, "add", "equipment", "shop", 0.0)
	forge.call("add_buff", "haste", "speed", 1.5, "multiply", "", "potion", 0.0)
	all_passed = _check("(base + add) * multiply", forge.call("stat_total", "speed"), 180.0) and all_passed
	forge.call("add_buff", "curse_cap", "speed", 60.0, "override", "", "boss", 0.0)
	forge.call("add_buff", "weak_cap", "speed", 40.0, "override", "", "boss", 0.0)
	all_passed = _check("override: the HIGHEST override wins", forge.call("stat_total", "speed"), 60.0) and all_passed
	forge.call("remove_buffs_by_source", "boss")
	all_passed = _check("remove by source restores the math", forge.call("stat_total", "speed"), 180.0) and all_passed

	# ── Re-adding an id replaces; inactive contributes nothing ──
	forge.call("add_buff", "boots", "speed", 50.0, "add", "equipment", "shop", 0.0)
	all_passed = _check("re-adding an id replaces the buff", forge.call("stat_total", "speed"), 225.0) and all_passed
	forge.call("set_buff_active", "haste", false)
	all_passed = _check("inactive buffs contribute nothing", forge.call("stat_total", "speed"), 150.0) and all_passed
	forge.call("set_buff_active", "haste", true)

	# ── Tags: counting + bulk removal ──
	all_passed = _check("tag counting", forge.call("buff_count_with_tag", "equipment"), 1) and all_passed
	forge.call("remove_buffs_by_tag", "equipment")
	all_passed = _check("remove by tag", forge.call("has_buff", "boots"), false) and all_passed

	# ── Overflow: clamp and wrap ──
	forge.set("max_value", 130.0)
	all_passed = _check("clamp stops at max", forge.call("stat_total", "speed"), 130.0) and all_passed
	forge.set("overflow_mode", "wrap")
	forge.set("min_value", 0.0)
	all_passed = _check("wrap loops around", forge.call("stat_total", "speed"), 20.0) and all_passed
	forge.set("overflow_mode", "none")
	all_passed = _check("none applies no limit", forge.call("stat_total", "speed"), 150.0) and all_passed

	# ── Timers: manual advance, pause, refresh, expiry signal ──
	var expired: Array = []
	forge.connect("buff_expired", func(buff_id: String, _stat: String) -> void: expired.append(buff_id))
	forge.call("add_buff", "shield", "armor", 5.0, "add", "", "", 3.0)
	forge.call("advance_timers", 2.0)
	all_passed = _check("timer counts down", forge.call("buff_time_left", "shield"), 1.0) and all_passed
	forge.call("set_buff_timer_paused", "shield", true)
	forge.call("advance_timers", 5.0)
	all_passed = _check("paused timers hold", forge.call("buff_time_left", "shield"), 1.0) and all_passed
	forge.call("set_buff_timer_paused", "shield", false)
	forge.call("refresh_buff", "shield", 3.0)
	all_passed = _check("refresh restarts the countdown", forge.call("buff_time_left", "shield"), 3.0) and all_passed
	forge.call("advance_timers", 3.5)
	all_passed = _check("expiry removes the buff", forge.call("has_buff", "shield"), false) and all_passed
	all_passed = _check("On Buff Expired fired with the id", expired, ["shield"]) and all_passed
	all_passed = _check("Last Expired Buff context reads back", forge.call("last_expired_buff"), "shield") and all_passed

	# ── Thresholds: rising crossing, one-shot spend, re-arm, repeating ──
	var crossings: Array = []
	forge.connect("threshold_crossed", func(rule_id: String, _stat: String, _total: float) -> void: crossings.append(rule_id))
	forge.call("set_stat_base", "combo", 0.0)
	forge.call("add_threshold_rule", "combo5", "combo", 5.0, "rising", false)
	forge.call("set_stat_base", "combo", 6.0)
	all_passed = _check("rising rule fires on the crossing", crossings, ["combo5"]) and all_passed
	forge.call("set_stat_base", "combo", 0.0)
	forge.call("set_stat_base", "combo", 9.0)
	all_passed = _check("a spent one-shot stays quiet", crossings, ["combo5"]) and all_passed
	forge.call("set_stat_base", "combo", 0.0)
	forge.call("rearm_threshold_rule", "combo5")
	forge.call("set_stat_base", "combo", 7.0)
	all_passed = _check("re-armed rule fires again", crossings, ["combo5", "combo5"]) and all_passed
	all_passed = _check("Last Threshold Rule context reads back", forge.call("last_threshold_rule"), "combo5") and all_passed

	# ── The .tres loadout: bases then ordered buff rows ──
	var stat_sheet: Resource = (load("res://eventsheet_addons/stat_sheet_resource/stat_sheet_resource.gd") as GDScript).new()
	stat_sheet.set("bases", [{"stat": "hp", "value": 50.0}])
	stat_sheet.set("buffs", [
		{"buff_id": "class_bonus", "stat": "hp", "value": 25.0, "mode": "add", "tags": "class", "source": "knight", "duration": 0.0},
		{"buff_id": "vitality", "stat": "hp", "value": 2.0, "mode": "multiply", "tags": "", "source": "knight", "duration": 0.0}
	])
	forge.call("load_stat_sheet", stat_sheet)
	all_passed = _check("Load Stat Sheet applies bases + buff rows", forge.call("stat_total", "hp"), 150.0) and all_passed
	forge.free()

	# ── Juice tints: host tint math + the new verb surface (2D + 3D) ──
	var juice_host: Node2D = Node2D.new()
	var juice: Node = (load("res://eventsheet_addons/juice/juice_behavior.gd") as GDScript).new()
	juice_host.add_child(juice)
	# Out of the scene tree _enter_tree never fires, so bind the host directly.
	juice.set("host", juice_host)
	for tint_method: String in ["set_host_tint", "clear_host_tint", "set_screen_tint", "fade_screen_tint", "clear_screen_tint"]:
		all_passed = _check("Juice has %s" % tint_method, juice.has_method(tint_method), true) and all_passed
	juice.call("set_host_tint", Color(1.0, 0.0, 0.0), 0.5)
	all_passed = _check("host tint blends modulate by strength", juice_host.modulate.is_equal_approx(Color(1.0, 0.5, 0.5)), true) and all_passed
	juice.call("clear_host_tint")
	all_passed = _check("clear host tint restores white", juice_host.modulate, Color.WHITE) and all_passed
	juice_host.free()
	var juice_3d: Node = (load("res://eventsheet_addons/juice_3d/juice_3d_behavior.gd") as GDScript).new()
	for tint_3d_method: String in ["set_screen_tint", "fade_screen_tint", "clear_screen_tint"]:
		all_passed = _check("Juice 3D has %s" % tint_3d_method, juice_3d.has_method(tint_3d_method), true) and all_passed
	juice_3d.free()

	# ── The annotation-survival regression: a doc comment above `## @ace_action` used to
	# eat the WHOLE annotation block during save_pack's lift (silently unpublishing the
	# function), and @ace_param_options never survived emission. Pin the emitted pack text.
	var emitted: String = FileAccess.get_file_as_string("res://eventsheet_addons/stat_forge/stat_forge_behavior.gd")
	all_passed = _check("doc-comment-first functions keep @ace_action",
		emitted.contains("## @ace_name(\"Add Buff\")"), true) and all_passed
	all_passed = _check("doc comments fold into @ace_description",
		emitted.contains("## @ace_description(\"The one verb that runs the whole system"), true) and all_passed
	all_passed = _check("param options survive emission (mode dropdown)",
		emitted.contains("## @ace_param_options(mode add, multiply, override)"), true) and all_passed
	all_passed = _check("param options survive emission (direction dropdown)",
		emitted.contains("## @ace_param_options(direction rising, falling, both)"), true) and all_passed

	# ── Rounded corners: the theme tokens exist with the shipped defaults ──
	var style: EventSheetEventStyle = EventSheetEventStyle.new()
	all_passed = _check("event_corner_radius token ships (theme-editable)", style.event_corner_radius, 8) and all_passed
	all_passed = _check("cell_corner_radius token ships (theme-editable)", style.cell_corner_radius, 4) and all_passed

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] stat_forge_test: %s" % label)
		return true
	print("[FAIL] stat_forge_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
