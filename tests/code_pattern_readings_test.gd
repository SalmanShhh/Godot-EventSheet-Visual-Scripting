@tool
class_name CodePatternReadingsTest
extends RefCounted

# Pins the batch-eight PATTERN readings - the shapes several lines make together, which no single
# line can decide:
#
#   S4  a number counted down by a delta and asked about against zero reads as a countdown
#   S2  a list drained behind an is_empty guard with an instantiate fallback reads as a pool
#
# Two gates: the whole-file facts (which names are countdowns, which lists are pools) and the
# sentences the grammar builds once it has them. Both are values, pinned literally, so a reading
# that drifts is a failing line rather than a changed count.


static func run() -> bool:
	var ok: bool = true
	ok = _countdown_facts() and ok
	ok = _countdown_sentences() and ok
	ok = _pool_facts() and ok
	return ok


## S4. Both halves are required: counted down by a delta AND compared against zero.
static func _countdown_facts() -> bool:
	var ok: bool = true
	var lines: PackedStringArray = PackedStringArray([
		"cooldown -= delta",
		"if cooldown <= 0 and Input.is_action_pressed(\"fire\"):",
		"invincible_for = max(0.0, invincible_for - delta)",
		"if invincible_for > 0:",
		"fuse = move_toward(fuse, 0, delta)",
		"if fuse <= 0:",
		"score -= delta",
		"ammo -= 1",
		"if ammo <= 0:"
	])
	var facts: Dictionary = EventSheetPatternReadings.countdown_variables(lines)
	ok = _check("a bare delta countdown is one", facts.get("cooldown", "missing"), "") and ok
	ok = _check("a clamped countdown says it stays above zero",
		facts.get("invincible_for", "missing"), "never below 0") and ok
	ok = _check("move_toward toward zero is a countdown",
		facts.get("fuse", "missing"), "never below 0") and ok
	ok = _check("a number never compared to zero is not a countdown", facts.has("score"), false) and ok
	ok = _check("a number never counted down by a delta is not a countdown", facts.has("ammo"), false) and ok
	ok = _check("nothing else is claimed", facts.size(), 3) and ok
	return ok


## S4. The four sentences a countdown reads in, with the file's own facts in the context.
static func _countdown_sentences() -> bool:
	var ok: bool = true
	var context: Dictionary = {
		"script_object": "Player",
		"countdown_variables": {"cooldown": "", "invincible_for": "never below 0"}
	}
	ok = _check("counting down reads as counting down",
		_reading(EventSheetSentence.statement("cooldown -= delta", context)),
		"Player ▸ Count down cooldown (by dt)") and ok
	ok = _check("a clamped countdown says so",
		_reading(EventSheetSentence.statement("invincible_for = max(0.0, invincible_for - delta)", context)),
		"Player ▸ Count down invincible_for (never below 0)") and ok
	ok = _check("setting a countdown starts it",
		_reading(EventSheetSentence.statement("cooldown = 0.5", context)),
		"Player ▸ Start cooldown for 0.5 seconds") and ok
	ok = _check("reaching zero is running out",
		_reading(EventSheetSentence.condition("cooldown <= 0", context)),
		"Player ▸ cooldown has run out") and ok
	ok = _check("above zero is still running",
		_reading(EventSheetSentence.condition("invincible_for > 0", context)),
		"Player ▸ invincible_for is running") and ok
	# With no countdown facts in the context nothing fires, and every line keeps its own reading.
	ok = _check("a plain subtraction is still a subtraction",
		_reading(EventSheetSentence.statement("cooldown -= delta", {"script_object": "Player"})),
		"System ▸ Subtract dt from cooldown") and ok
	return ok


## S2. The pooled-Create line, in both orders of the ternary that writes it.
static func _pool_facts() -> bool:
	var ok: bool = true
	var taken: Dictionary = EventSheetPatternReadings.pool_take_parts(
		"var b = pool.pop_back() if not pool.is_empty() else BULLET.instantiate()")
	ok = _check("the pool is named", taken.get("pool", ""), "pool") and ok
	ok = _check("the scene is named", taken.get("scene", ""), "BULLET") and ok
	ok = _check("the new object keeps its own name", taken.get("alias", ""), "b") and ok
	var flipped: Dictionary = EventSheetPatternReadings.pool_take_parts(
		"var b = BULLET.instantiate() if pool.is_empty() else pool.pop_front()")
	ok = _check("the other order of the ternary reads the same", flipped.get("pool", ""), "pool") and ok
	ok = _check("a pool with no guard is not a pool",
		EventSheetPatternReadings.pool_take_parts("var b = pool.pop_back()").is_empty(), true) and ok
	ok = _check("a ternary that makes two different things is not a pool",
		EventSheetPatternReadings.pool_take_parts(
			"var b = A.instantiate() if pool.is_empty() else C.instantiate()").is_empty(), true) and ok
	var pools: Dictionary = EventSheetPatternReadings.pool_variables(PackedStringArray([
		"var b = pool.pop_back() if not pool.is_empty() else BULLET.instantiate()"
	]))
	ok = _check("the file's pools are found", pools.has("pool"), true) and ok
	var sleep_step: Dictionary = EventSheetPatternReadings.pool_return_step("b.set_process(false)", pools)
	ok = _check("switching an object off is a sleep step", sleep_step.get("kind", ""), "sleep") and ok
	var back: Dictionary = EventSheetPatternReadings.pool_return_step("pool.push_back(b)", pools)
	ok = _check("pushing it back is the return step", back.get("kind", ""), "return") and ok
	ok = _check("the returned object is named", back.get("object", ""), "b") and ok
	ok = _check("a push onto a list that is not a pool is not a return step",
		EventSheetPatternReadings.pool_return_step("names.push_back(b)", pools).is_empty(), true) and ok
	return ok


## "Object ▸ sentence", the way the canvas draws a row, so a pin reads like the row it stands for.
static func _reading(result: Dictionary) -> String:
	var text: String = ""
	for segment: Variant in (result.get("segments", []) as Array):
		text += str((segment as Dictionary).get("text", ""))
	var object_name: String = str(result.get("object", ""))
	return text.strip_edges() if object_name.is_empty() else "%s ▸ %s" % [object_name, text.strip_edges()]


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] code_pattern_readings_test: %s" % label)
		return true
	print("[FAIL] code_pattern_readings_test: %s - expected %s, got %s" % [label, expected, actual])
	return false
