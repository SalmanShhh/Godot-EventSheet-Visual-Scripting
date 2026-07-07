# Godot EventSheets - combo_box pack (autoload input-sequence detector) smoke + rules.
#
# Loads the COMPILED pack and drives it directly. _process never ticks on a bare .new(), so the
# internal clock is set by hand (cb._clock) to stamp inputs and prove per-gap timing deterministically.
# Covers matching, wildcards, timing windows + timeout failure, strict vs interleaved, best-wins
# selection, enable/disable, tags, the rolling buffer, partial tracking, and clearing.
@tool
class_name ComboBoxTest
extends RefCounted

const PACK := "res://eventsheet_addons/combo_box/combo_box_addon.gd"


static func run() -> bool:
	var all_passed: bool = true
	var script: GDScript = load(PACK)
	all_passed = _check("combo_box pack loads + parses", script != null, true) and all_passed
	if script == null:
		return all_passed

	var cb: Node = script.new()
	var matched: Array = [0]
	var failed: Array = [0]
	var partial: Array = [0]
	var cleared: Array = [0]
	cb.on_combo_matched.connect(func() -> void: matched[0] += 1)
	cb.on_combo_failed.connect(func() -> void: failed[0] += 1)
	cb.on_partial_progress.connect(func() -> void: partial[0] += 1)
	cb.on_buffer_cleared.connect(func() -> void: cleared[0] += 1)

	# Basic sequence match, all inputs at the same instant (any gap is within the default window).
	_reset(cb)
	cb.register_combo("hadouken", "forward,forward,punch", -1.0)
	all_passed = _check("Register Combo adds to the registry", cb.combo_count(), 1) and all_passed
	var m0: int = matched[0]
	cb.press_input("forward")
	cb.press_input("forward")
	cb.press_input("punch")
	all_passed = _check("a full sequence fires On Combo Matched with the id",
		matched[0] == m0 + 1 and cb.matched_id() == "hadouken", true) and all_passed

	# Wildcard token matches any single input.
	_reset(cb)
	cb.register_combo("wild", "*,attack", -1.0)
	cb.press_input("block")
	cb.press_input("attack")
	all_passed = _check("a wildcard token matches any input", cb.matched_id() == "wild", true) and all_passed

	# Timing: a gap wider than the window breaks the combo and fires On Combo Failed.
	_reset(cb)
	cb.register_combo("quick", "a,b", 0.2)
	var f0: int = failed[0]
	cb._clock = 0.0
	cb.press_input("a")
	cb._clock = 0.5
	cb.press_input("b")
	all_passed = _check("a too-slow input breaks the combo and fires On Combo Failed",
		failed[0] == f0 + 1 and cb.failed_id() == "quick" and cb.fail_index() == 1, true) and all_passed

	# Timing: within the window it matches.
	_reset(cb)
	cb.register_combo("quick", "a,b", 0.2)
	var m1: int = matched[0]
	cb._clock = 0.0
	cb.press_input("a")
	cb._clock = 0.1
	cb.press_input("b")
	all_passed = _check("a fast-enough input completes the combo", matched[0] == m1 + 1 and cb.matched_id() == "quick", true) and all_passed

	# Strict mode forbids an unrelated input between the combo's tokens.
	_reset(cb)
	cb.register_combo("adj", "a,b", -1.0)
	cb.set_combo_strict("adj", true)
	var m2: int = matched[0]
	cb.press_input("a")
	cb.press_input("x")
	cb.press_input("b")
	all_passed = _check("strict mode does not match across a stray input", matched[0], m2) and all_passed

	# Non-strict (the default) tolerates a stray input in between (fighting-game feel).
	_reset(cb)
	cb.register_combo("loose", "a,b", -1.0)
	cb.press_input("a")
	cb.press_input("x")
	cb.press_input("b")
	all_passed = _check("non-strict mode matches across a stray input", cb.matched_id() == "loose", true) and all_passed

	# One combo wins per input: the longer completing combo beats the shorter one it contains.
	_reset(cb)
	cb.register_combo("light", "attack", -1.0)
	cb.register_combo("heavy", "attack,attack", -1.0)
	cb.press_input("attack")
	all_passed = _check("the single-input combo fires first", cb.matched_id() == "light", true) and all_passed
	cb.press_input("attack")
	all_passed = _check("the longer combo wins when both complete on one input", cb.matched_id() == "heavy", true) and all_passed

	# Disabled combos are skipped; re-enabling brings them back.
	_reset(cb)
	cb.register_combo("d", "x,y", -1.0)
	cb.disable_combo("d")
	var m3: int = matched[0]
	cb.press_input("x")
	cb.press_input("y")
	all_passed = _check("a disabled combo does not match", matched[0], m3) and all_passed
	cb.enable_combo("d")
	cb.press_input("x")
	cb.press_input("y")
	all_passed = _check("re-enabling lets it match again", cb.matched_id() == "d", true) and all_passed

	# Tags drive batch enable/disable.
	_reset(cb)
	cb.register_combo("g1", "a,b", -1.0)
	cb.set_combo_tags("g1", "ground")
	cb.disable_combos_by_tag("ground")
	all_passed = _check("Disable Combos By Tag disables the tagged combo", cb.is_combo_enabled("g1"), false) and all_passed
	cb.enable_combos_by_tag("ground")
	all_passed = _check("Enable Combos By Tag and Combo Has Tag work",
		cb.is_combo_enabled("g1") and cb.combo_has_tag("g1", "ground"), true) and all_passed

	# The buffer is a rolling window: old inputs drop off past the length.
	_reset(cb)
	cb.set_buffer_length(3)
	cb.press_input("t1")
	cb.press_input("t2")
	cb.press_input("t3")
	cb.press_input("t4")
	all_passed = _check("the buffer keeps only the most recent inputs",
		cb.buffer_length_now() == 3 and cb.buffer_token(0) == "t2", true) and all_passed

	# Partial tracking exposes progress toward a longer combo.
	_reset(cb)
	cb.register_combo("tri", "a,b,c", -1.0)
	var p0: int = partial[0]
	cb.press_input("a")
	all_passed = _check("a part-way combo is tracked for progress UI",
		partial[0] == p0 + 1 and cb.partial_count() == 1 and cb.partial_id(0) == "tri" and cb.partial_progress(0) == 1 and cb.partial_length(0) == 3, true) and all_passed

	# Clearing empties the buffer and reports how much it held.
	_reset(cb)
	cb.press_input("a")
	cb.press_input("b")
	all_passed = _check("pressing fills the buffer", cb.is_buffer_empty(), false) and all_passed
	var c0: int = cleared[0]
	cb.clear_buffer()
	all_passed = _check("Clear Buffer empties it and fires On Buffer Cleared with the count",
		cb.is_buffer_empty() and cleared[0] == c0 + 1 and cb.cleared_count() == 2, true) and all_passed

	# Registry listing.
	_reset(cb)
	cb.register_combo("one", "a", -1.0)
	cb.register_combo("two", "b", -1.0)
	all_passed = _check("the registry can be counted and listed",
		cb.combo_count() == 2 and cb.combo_id_at(0) == "one" and not cb.has_combo("nope"), true) and all_passed

	cb.free()
	return all_passed


static func _reset(cb: Node) -> void:
	cb._combos.clear()
	cb._buffer.clear()
	cb._progress.clear()
	cb._partials.clear()
	cb._clock = 0.0


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] combo_box_test: %s" % label)
		return true
	print("[FAIL] combo_box_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
