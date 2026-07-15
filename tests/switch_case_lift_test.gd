# EventForge - switch/case phase 3: opening a .gd with a `match` lifts it to STRUCTURED cases (each branch a
# first-class MatchCase with a pattern + body), not just a branches_text blob. Byte-gated: the cases are only
# taken when re-emitting them reproduces the branch text exactly, so the .gd round-trips byte-for-byte. Pins:
# a simple match's cases, a NESTED case body (the dedent must preserve inner indentation), and - the covenant
# - that both round-trip identically. This is what makes structured switch/case reachable by opening a file.
@tool
class_name SwitchCaseLiftTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	# ── A simple match: two branches, one statement each ──
	var source_a: String = _author("match state:\n\tState.IDLE:\n\t\tpass\n\t_:\n\t\tqueue_free()")
	var imported_a: EventSheetResource = GDScriptImporter.new().import_external_source(source_a)
	var mr_a: MatchRow = _first_match(imported_a)
	ok = _check("the match lifts to a MatchRow", mr_a != null, true) and ok
	if mr_a != null:
		ok = _check("it lifts two structured cases", mr_a.cases.size(), 2) and ok
		ok = _check("first case pattern", _case_pattern(mr_a, 0), "State.IDLE") and ok
		ok = _check("first case body", _case_body(mr_a, 0), "pass") and ok
		ok = _check("default case pattern", _case_pattern(mr_a, 1), "_") and ok
		ok = _check("default case body", _case_body(mr_a, 1), "queue_free()") and ok
	ok = _check("the simple match round-trips byte-identically", _roundtrip(imported_a) == source_a, true) and ok

	# ── A NESTED case body (an if inside a branch): the dedent must keep the inner tab ──
	var source_b: String = _author("match state:\n\t1:\n\t\tif health > 0:\n\t\t\ttake_damage()\n\t_:\n\t\tpass")
	var imported_b: EventSheetResource = GDScriptImporter.new().import_external_source(source_b)
	var mr_b: MatchRow = _first_match(imported_b)
	ok = _check("the nested match lifts to structured cases", mr_b != null and mr_b.cases.size() == 2, true) and ok
	if mr_b != null and mr_b.cases.size() == 2:
		ok = _check("the nested case body keeps its inner indentation",
			_case_body(mr_b, 0), "if health > 0:\n\ttake_damage()") and ok
	ok = _check("the nested match round-trips byte-identically", _roundtrip(imported_b) == source_b, true) and ok

	return ok


static func _author(match_code: String) -> String:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	var raw: RawCodeRow = RawCodeRow.new()
	raw.code = match_code
	event.actions.append(raw)
	sheet.events.append(event)
	return str(SheetCompiler.compile(sheet, "user://switch_lift_src.gd").get("output", ""))


static func _roundtrip(sheet: EventSheetResource) -> String:
	sheet.external_source_path = "user://switch_lift_rt.gd"
	return str(SheetCompiler.compile(sheet, "user://switch_lift_rt.gd").get("output", ""))


static func _first_match(sheet: EventSheetResource) -> MatchRow:
	for row: Variant in sheet.events:
		if row is EventRow:
			for a: Variant in (row as EventRow).actions:
				if a is MatchRow:
					return a as MatchRow
	return null


static func _case_pattern(mr: MatchRow, index: int) -> String:
	return str((mr.cases[index] as MatchCase).pattern)


static func _case_body(mr: MatchRow, index: int) -> String:
	var events: Array = (mr.cases[index] as MatchCase).events
	if events.is_empty():
		return "<empty>"
	return str((events[0] as RawCodeRow).code) if events[0] is RawCodeRow else "<not-raw>"


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] switch_case_lift_test: %s" % label)
		return true
	print("[FAIL] switch_case_lift_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
