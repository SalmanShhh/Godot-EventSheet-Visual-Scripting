# EventForge — Phase 3.5 (Stage D): the corrected bare-expression condition fallback.
# An `if` whose condition no specific ACE claims still lifts to a real event — each top-level term
# becomes an Expression Is True condition (bare {expr}). The split is top-level-only: `and` inside
# parens/brackets/braces or a string literal does NOT fragment the term (the naive split produced
# garbage rows like "f(a" + "b)"). The byte-identical recompile gates every reconstruction.
@tool
class_name ConditionFallbackTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true
	ok = _case("top-level and splits into two terms", "if a and b:\n\tfoo()", 2, false) and ok
	ok = _case("and inside a call stays one term", "if f(a and b):\n\tfoo()", 1, false) and ok
	ok = _case("and inside a string stays one term", "if x == \"a and b\" and ok:\n\tfoo()", 2, false) and ok
	ok = _case("negated compound stays one term", "if not (a and b):\n\tfoo()", 1, true) and ok
	ok = _case("dict literal then top-level and", "if {\"k\": 1} and ok:\n\tfoo()", 2, false) and ok
	return ok


static func _case(label: String, body: String, expected_conds: int, expect_negated: bool) -> bool:
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
	var source: String = str(SheetCompiler.compile(sheet, "user://cf.gd").get("output", ""))

	var imported: EventSheetResource = GDScriptImporter.new().import_external_source(source)
	var conds: Array = _conds(imported.events)
	ok = _check("%s: condition count" % label, conds.size(), expected_conds) and ok
	if expect_negated:
		var any_neg: bool = false
		for c: ACECondition in conds:
			any_neg = any_neg or c.negated
		ok = _check("%s: negation preserved" % label, any_neg, true) and ok

	imported.external_source_path = "user://cf_rt.gd"
	var rt: String = str(SheetCompiler.compile(imported, "user://cf_rt.gd").get("output", ""))
	ok = _check("%s: round-trips byte-identically" % label, rt == source, true) and ok
	if rt != source:
		print("    SRC<%s>\n    RT <%s>" % [source, rt])
	return ok


static func _conds(rows: Array) -> Array:
	var out: Array = []
	for r: Variant in rows:
		if r is EventRow:
			for c: Variant in (r as EventRow).conditions:
				if c is ACECondition:
					out.append(c)
			out.append_array(_conds((r as EventRow).sub_events))
	return out


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] condition_fallback_test: %s" % label)
		return true
	print("[FAIL] condition_fallback_test: %s" % label)
	print("  expected: %s, actual: %s" % [str(expected), str(actual)])
	return false
