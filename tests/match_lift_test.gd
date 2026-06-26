# EventForge — Phase 3 (Stage C): control-flow reverse-lift (match / Construct's "switch").
# A `match EXPR:` inside a lifted trigger body reverse-lifts to a MatchRow action — subject plus
# verbatim branch text — instead of an in-flow GDScript cell. The branch lines are kept verbatim
# (patterns + bodies are not parsed as ACEs); the byte-identical recompile gates the reconstruction.
@tool
extends RefCounted
class_name MatchLiftTest

static func run() -> bool:
	var ok: bool = true

	var authored: EventSheetResource = EventSheetResource.new()
	authored.host_class = "Node2D"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	var raw: RawCodeRow = RawCodeRow.new()
	raw.code = "match state:\n\tState.IDLE:\n\t\tpass\n\t_:\n\t\tqueue_free()"
	event.actions.append(raw)
	authored.events.append(event)
	var source: String = str(SheetCompiler.compile(authored, "user://match_source.gd").get("output", ""))

	var imported: EventSheetResource = GDScriptImporter.new().import_external_source(source)
	var match_rows: Array = _collect_match_rows(imported.events)
	ok = _check("match lifts to a MatchRow", match_rows.size() >= 1, true) and ok
	if match_rows.size() >= 1:
		var mr: MatchRow = match_rows[0]
		ok = _check("subject expression extracted", mr.match_expression, "state") and ok
		ok = _check("branch text reconstructed", mr.branches_text, "State.IDLE:\n\tpass\n_:\n\tqueue_free()") and ok
	ok = _check("no match header stayed an in-flow code cell", _has_raw_match(imported.events), false) and ok

	imported.external_source_path = "user://match_rt.gd"
	var roundtrip: String = str(SheetCompiler.compile(imported, "user://match_rt.gd").get("output", ""))
	ok = _check("match lift round-trips byte-identically", roundtrip == source, true) and ok
	if roundtrip != source:
		print("  --- source ---\n%s\n  --- roundtrip ---\n%s" % [source, roundtrip])

	return ok

static func _collect_match_rows(rows: Array) -> Array:
	var out: Array = []
	for row: Variant in rows:
		if row is EventRow:
			for a: Variant in (row as EventRow).actions:
				if a is MatchRow:
					out.append(a)
			out.append_array(_collect_match_rows((row as EventRow).sub_events))
	return out

static func _has_raw_match(rows: Array) -> bool:
	for row: Variant in rows:
		if row is EventRow:
			for a: Variant in (row as EventRow).actions:
				if a is RawCodeRow and (a as RawCodeRow).code.contains("match "):
					return true
			if _has_raw_match((row as EventRow).sub_events):
				return true
	return false

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] match_lift_test: %s" % label)
		return true
	print("[FAIL] match_lift_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
