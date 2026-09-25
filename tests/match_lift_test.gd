# EventForge - Phase 3 (Stage C): control-flow reverse-lift (match / the "switch").
# A `match EXPR:` inside a lifted trigger body reverse-lifts to a MatchRow action - subject plus
# verbatim branch text - instead of an in-flow GDScript cell. The branch lines are kept verbatim
# (patterns + bodies are not parsed as ACEs); the byte-identical recompile gates the reconstruction.
@tool
class_name MatchLiftTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")


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
	# That it lifts at all, and that it round-trips byte for byte, is switch_case_lift_test's on this
	# same input; what is pinned here is the verbatim branch text the MatchRow carries.
	var match_rows: Array = _collect_match_rows(imported.events)
	var branches: String = (match_rows[0] as MatchRow).branches_text if not match_rows.is_empty() else "<no MatchRow>"
	ok = _check("branch text reconstructed", branches, "State.IDLE:\n\tpass\n_:\n\tqueue_free()") and ok
	ok = _check("no match header stayed an in-flow code cell", _has_raw_match(imported.events), false) and ok

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
	return SUPPORT.check("match_lift_test", label, actual, expected)
