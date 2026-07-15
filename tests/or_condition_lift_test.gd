# EventForge (gap G1) - a purely-OR `if` reverse-lifts as an OR block. `if a or b:` used to lift as ONE
# opaque Expression-Is-True term (byte-exact but flattened); now each top-level ` or ` term becomes its own
# condition and the event's condition_mode is set to OR, so the row reads as a C3-style "Or block". A top-
# level ` and ` still takes precedence (GDScript binds `and` tighter than `or`): a mixed `a or b and c` keeps
# the ` and ` split and stays AND-mode - byte-exact but not falsely restructured. The ` or ` split is top-
# level only (inside parens / brackets / a string it does NOT fragment), and every reconstruction is gated by
# the byte-identical recompile, so a `.gd` always round-trips.
@tool
class_name OrConditionLiftTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true
	# label, body, expected condition count, expected OR mode, expect a negated term
	ok = _case("plain OR splits into two OR'd conditions", "if a or b:\n\tfoo()", 2, true, false) and ok
	ok = _case("three-way OR splits into three", "if a or b or c:\n\tfoo()", 3, true, false) and ok
	ok = _case("plain AND stays AND-mode", "if a and b:\n\tfoo()", 2, false, false) and ok
	# GDScript binds `and` tighter than `or`, so a mixed expression must NOT collapse to one condition_mode:
	# the top-level ` and ` split wins (`a or b` | `c`), staying AND-mode. Byte-exact is all that is promised.
	ok = _case("mixed and/or keeps the and split (and-mode)", "if a or b and c:\n\tfoo()", 2, false, false) and ok
	# Top-level only: an ` or ` inside a call, a subscript, or a string literal never fragments the term.
	ok = _case("or inside a call stays one term", "if f(a or b):\n\tfoo()", 1, false, false) and ok
	ok = _case("or inside a string stays one term", "if x == \"a or b\":\n\tfoo()", 1, false, false) and ok
	# A negated leading term survives the OR split: `not (a) or b` -> [not a] OR [b], first negated.
	ok = _case("negated first OR term keeps its negation", "if not (a) or b:\n\tfoo()", 2, true, true) and ok
	return ok


static func _case(label: String, body: String, expected_conds: int, expect_or: bool, expect_negated: bool) -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var ev: EventRow = EventRow.new()
	ev.trigger_provider_id = "Core"
	ev.trigger_id = "OnProcess"
	var raw: RawCodeRow = RawCodeRow.new()
	raw.code = body
	ev.actions.append(raw)
	sheet.events.append(ev)
	var source: String = str(SheetCompiler.compile(sheet, "user://or_cond.gd").get("output", ""))

	var imported: EventSheetResource = GDScriptImporter.new().import_external_source(source)
	var conditioned: EventRow = _first_conditioned(imported.events)
	ok = _check("%s: found the conditioned row" % label, conditioned != null, true) and ok
	if conditioned == null:
		return false
	ok = _check("%s: condition count" % label, conditioned.conditions.size(), expected_conds) and ok
	var is_or: bool = conditioned.condition_mode == EventRow.ConditionMode.OR
	ok = _check("%s: condition_mode is %s" % [label, "OR" if expect_or else "AND"], is_or, expect_or) and ok
	if expect_negated:
		var any_neg: bool = false
		for c: ACECondition in conditioned.conditions:
			any_neg = any_neg or c.negated
		ok = _check("%s: negation preserved" % label, any_neg, true) and ok

	# The covenant: whatever structure the lift chose, re-emitting reproduces the source byte-for-byte.
	imported.external_source_path = "user://or_cond_rt.gd"
	var rt: String = str(SheetCompiler.compile(imported, "user://or_cond_rt.gd").get("output", ""))
	ok = _check("%s: round-trips byte-identically" % label, rt == source, true) and ok
	if rt != source:
		print("    SRC<%s>\n    RT <%s>" % [source, rt])
	return ok


## The first EventRow (depth-first) that carries conditions - the lifted `if`.
static func _first_conditioned(rows: Array) -> EventRow:
	for r: Variant in rows:
		if r is EventRow:
			if not (r as EventRow).conditions.is_empty():
				return r as EventRow
			var nested: EventRow = _first_conditioned((r as EventRow).sub_events)
			if nested != null:
				return nested
	return null


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] or_condition_lift_test: %s" % label)
		return true
	print("[FAIL] or_condition_lift_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
