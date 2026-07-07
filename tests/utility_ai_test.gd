# Godot EventSheets - utility_ai pack (per-node UtilityBrain decision engine) smoke + rules.
#
# Loads the COMPILED behavior and drives it directly (pure Dictionary state + signals; _process never
# ticks on a bare .new(), so cooldown EXPIRY is not exercised here - the set/clear/exclude logic is).
# Proves the response curves, score-based selection, the consideration-less fallback action, the
# no-valid-action path, force / interrupt / cooldown, and history.
@tool
class_name UtilityAiTest
extends RefCounted

const PACK := "res://eventsheet_addons/utility_ai/utility_ai_addon.gd"


static func run() -> bool:
	var all_passed: bool = true
	var script: GDScript = load(PACK)
	all_passed = _check("utility_ai pack loads + parses", script != null, true) and all_passed
	if script == null:
		return all_passed

	# Response curves map a 0-1 input to a 0-1 score as documented.
	var br: Node = script.new()
	all_passed = _check("linear curve returns the input",
		is_equal_approx(br._curve_score("linear", 0.7, 0.5, 1.0), 0.7), true) and all_passed
	all_passed = _check("inverse curve returns 1 - input",
		is_equal_approx(br._curve_score("inverse", 0.7, 0.5, 1.0), 0.3), true) and all_passed
	all_passed = _check("quadratic curve returns input squared",
		is_equal_approx(br._curve_score("quadratic", 0.5, 0.5, 1.0), 0.25), true) and all_passed
	all_passed = _check("threshold curve is 1 at/above center, 0 below",
		br._curve_score("threshold", 0.6, 0.5, 1.0) == 1.0 and br._curve_score("threshold", 0.4, 0.5, 1.0) == 0.0, true) and all_passed

	# A three-action combat brain: flee when hurt, attack when healthy + close, idle as the fallback.
	var decisions: Array = [0]
	var starts: Array = [0]
	var changes: Array = [0]
	var no_valid: Array = [0]
	var interrupts: Array = [0]
	var cooldown_starts: Array = [0]
	br.on_decision_made.connect(func() -> void: decisions[0] += 1)
	br.on_action_started.connect(func() -> void: starts[0] += 1)
	br.on_action_changed.connect(func() -> void: changes[0] += 1)
	br.on_no_valid_action.connect(func() -> void: no_valid[0] += 1)
	br.on_action_interrupted.connect(func() -> void: interrupts[0] += 1)
	br.on_cooldown_started.connect(func() -> void: cooldown_starts[0] += 1)

	br.add_action("flee", 0.0, true, 1.0)
	br.add_consideration("flee", "hp", "inverse", 1.0, 0.5, 1.0)
	br.add_action("attack", 0.0, true, 1.0)
	br.add_consideration("attack", "hp", "linear", 1.0, 0.5, 1.0)
	br.add_consideration("attack", "distance", "inverse", 1.0, 0.5, 1.0)
	br.add_action("idle", 0.0, false, 1.0)
	all_passed = _check("Add Action registers each candidate", br.action_count(), 3) and all_passed

	# Hurt -> flee wins; the first decision starts and changes the action.
	br.set_input("hp", 0.1)
	br.set_input("distance", 0.3)
	br.evaluate()
	all_passed = _check("a low-hp brain flees (and fires decision + start + change)",
		br.current_action() == "flee" and br.is_running("flee") and decisions[0] == 1 and starts[0] == 1 and changes[0] == 1 and br.decision_score() > 0.0, true) and all_passed

	# Healthy + close -> attack; the action changes and remembers what it was.
	var starts_before: int = starts[0]
	br.set_input("hp", 0.9)
	br.set_input("distance", 0.1)
	br.evaluate()
	all_passed = _check("a healthy, close brain switches to attack and remembers the previous action",
		br.current_action() == "attack" and br.previous_action() == "flee" and br.was_last_action("flee") and starts[0] == starts_before + 1, true) and all_passed

	# Re-evaluating the same winner fires a decision but does NOT restart the action.
	starts_before = starts[0]
	br.evaluate()
	all_passed = _check("re-picking the running action does not restart it",
		br.current_action() == "attack" and starts[0] == starts_before, true) and all_passed

	# Both combat actions veto to ~0 (healthy but far, and not hurt) -> the fallback idle wins.
	br.set_input("hp", 1.0)
	br.set_input("distance", 1.0)
	br.evaluate()
	all_passed = _check("a consideration-less action is the natural low fallback",
		br.current_action() == "idle", true) and all_passed

	# History: index 0 is current, index 1 is the one before.
	all_passed = _check("Action History is most-recent-first",
		br.action_history(0) == "idle" and br.action_history(1) == "attack", true) and all_passed

	# Disable everything -> nothing clears the threshold -> On No Valid Action.
	var no_valid_before: int = no_valid[0]
	br.set_action_enabled("flee", false)
	br.set_action_enabled("attack", false)
	br.set_action_enabled("idle", false)
	br.evaluate()
	all_passed = _check("disabling every action fires On No Valid Action", no_valid[0] == no_valid_before + 1, true) and all_passed
	br.set_action_enabled("idle", true)

	# Force overrides scoring: idle would never beat nothing, but Force starts it outright.
	starts_before = starts[0]
	br.set_action_enabled("attack", true)
	br.force_action("attack")
	all_passed = _check("Force Action starts an action regardless of score",
		br.current_action() == "attack" and starts[0] == starts_before + 1, true) and all_passed

	# Interrupt cancels an interruptible action and re-evaluates.
	var interrupts_before: int = interrupts[0]
	br.interrupt()
	all_passed = _check("Interrupt cancels an interruptible action", interrupts[0] == interrupts_before + 1, true) and all_passed

	# A non-interruptible action ignores Interrupt.
	br.force_action("idle")
	interrupts_before = interrupts[0]
	br.interrupt()
	all_passed = _check("a non-interruptible action ignores Interrupt",
		interrupts[0] == interrupts_before and br.current_action() == "idle", true) and all_passed

	# Cooldowns: Mark Complete on an action with a cooldown benches it and re-picks another.
	br.add_action("special", 5.0, true, 5.0)
	br.add_consideration("special", "threat", "linear", 1.0, 0.5, 1.0)
	br.set_input("threat", 1.0)
	br.evaluate()
	all_passed = _check("a high-priority action wins when its input is hot", br.current_action() == "special", true) and all_passed
	var cd_before: int = cooldown_starts[0]
	br.mark_complete()
	all_passed = _check("Mark Complete benches the action on its cooldown and re-picks another",
		br.is_on_cooldown("special") and br.cooldown_action() == "special" and cooldown_starts[0] == cd_before + 1
		and br.current_action() != "special" and br.cooldown_remaining("special") > 0.0, true) and all_passed
	br.clear_cooldowns()
	all_passed = _check("Clear Cooldowns frees the action again", br.is_on_cooldown("special"), false) and all_passed

	# Manual Set Action Cooldown, then a negative duration clears it.
	br.set_cooldown("attack", 3.0)
	all_passed = _check("Set Action Cooldown benches an action", br.is_on_cooldown("attack"), true) and all_passed
	br.set_cooldown("attack", 0.0)
	all_passed = _check("a zero cooldown clears it", br.is_on_cooldown("attack"), false) and all_passed

	# get_input reads back what was set; an unset key reads as 0.
	all_passed = _check("Get Input reads world state (and unset keys read as 0)",
		is_equal_approx(br.get_input("hp"), 1.0) and is_equal_approx(br.get_input("never_set"), 0.0), true) and all_passed

	br.free()
	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] utility_ai_test: %s" % label)
		return true
	print("[FAIL] utility_ai_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
