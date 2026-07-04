# EventForge - the generated-line ↔ sheet-row mapper. Compiles a real sheet and pins: entries_for_line
# returns containing ranges MOST SPECIFIC FIRST (nested event beats its enclosing function range),
# resource_for_line resolves the live emitting resource (and skips freed ones by walking outward),
# range_for_resource round-trips a row to the exact lines its code occupies (verified against the
# actual output text, not just the map), and out-of-range / stale lookups fail closed. This is the
# shared core for the GDScript panel's click-to-select and the coming error→row / paused-at-row links.
@tool
class_name LineRowMapperTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	# A sheet with nesting: an event (inside its trigger handler's range) + a sheet function.
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "print"
	action.params = {"text": "\"hello\""}
	action.codegen_template = "print({text})"
	event.actions.append(action)
	sheet.events.append(event)
	var fn: EventFunction = EventFunction.new()
	fn.function_name = "helper_value"
	fn.return_type = TYPE_FLOAT
	sheet.functions.append(fn)

	var result: Dictionary = SheetCompiler.compile(sheet, "user://_line_row_mapper_out.gd")
	var source_map: Array = result.get("source_map", [])
	var lines: PackedStringArray = str(result.get("output", "")).split("\n")
	ok = _check("compile produced a source map", source_map.size() > 0, true) and ok

	# ── range_for_resource agrees with the actual output text ──
	var event_range: Vector2i = EventSheetLineRowMapper.range_for_resource(source_map, event)
	ok = _check("the event has a mapped range", event_range.x > 0 and event_range.y >= event_range.x, true) and ok
	var range_text: String = "\n".join(lines.slice(event_range.x - 1, event_range.y))
	ok = _check("the event's mapped lines contain its emitted action", range_text.contains("print(\"hello\")"), true) and ok
	var fn_range: Vector2i = EventSheetLineRowMapper.range_for_resource(source_map, fn)
	# The range STARTS at the function's annotation block (annotations are part of its emission),
	# so assert the declaration is INSIDE the range rather than on its first line.
	var fn_text: String = "\n".join(lines.slice(maxi(fn_range.x - 1, 0), fn_range.y)) if fn_range.x > 0 else ""
	ok = _check("the function's mapped range contains its declaration",
		fn_text.contains("func helper_value()"), true) and ok

	# ── entries_for_line: most specific first ──
	var inside_event: Array = EventSheetLineRowMapper.entries_for_line(source_map, event_range.x)
	ok = _check("a line inside the event resolves to at least the event entry", inside_event.size() >= 1, true) and ok
	ok = _check("the MOST SPECIFIC entry comes first (the event, not an enclosing range)",
		str((inside_event[0] as Dictionary).get("uid", "")), str(event.get_instance_id())) and ok
	if inside_event.size() > 1:
		var first_span: int = int((inside_event[0] as Dictionary).get("end", 0)) - int((inside_event[0] as Dictionary).get("start", 0))
		var last_span: int = int((inside_event[-1] as Dictionary).get("end", 0)) - int((inside_event[-1] as Dictionary).get("start", 0))
		ok = _check("ordering is by range size, ascending", first_span <= last_span, true) and ok

	# ── resource_for_line resolves the live resource; stale uids are walked past ──
	ok = _check("resource_for_line finds the event", EventSheetLineRowMapper.resource_for_line(source_map, event_range.x) == event, true) and ok
	ok = _check("resource_for_line finds the function", EventSheetLineRowMapper.resource_for_line(source_map, fn_range.x) == fn, true) and ok
	var with_stale: Array = [{"uid": "1", "start": event_range.x, "end": event_range.x, "kind": "event"}]
	with_stale.append_array(source_map)
	ok = _check("a freed/bogus inner entry is walked past to the live outer one",
		EventSheetLineRowMapper.resource_for_line(with_stale, event_range.x) == event, true) and ok

	# ── Post-map insertions must SHIFT the map with the text ──
	# A provider-instance action makes the compiler insert `var __eventsheet_provider_… := …` lines
	# near the top AFTER the map was built; without the shift every lookup below the insertion landed
	# a few rows off (and error deep-links would select the wrong event).
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	var provider_sheet: EventSheetResource = EventSheetResource.new()
	provider_sheet.host_class = "Node2D"
	var seed_event: EventRow = EventRow.new()
	seed_event.trigger_provider_id = "Core"
	seed_event.trigger_id = "OnProcess"
	provider_sheet.events.append(seed_event)
	dock.setup(provider_sheet)
	var view: EventSheetViewport = dock._active_view()
	for index: int in range(view.get_flat_rows().size()):
		var row_data: EventRowData = view.get_flat_rows()[index].get("row")
		if row_data != null and row_data.source_resource == seed_event:
			view._select_row(index)
	dock._ghost_row._refresh("heal 25")  # a provider-instance ACE - its apply bakes the real template
	dock._ghost_row._apply_selected()
	var provider_event: EventRow = null
	for row: Variant in dock.get_current_sheet().events:
		if row is EventRow:
			provider_event = row
	var provider_result: Dictionary = SheetCompiler.compile(dock.get_current_sheet(), "user://_line_row_mapper_out2.gd")
	dock.free()
	var provider_lines: PackedStringArray = str(provider_result.get("output", "")).split("\n")
	ok = _check("the provider declaration WAS inserted (the shift case is real)",
		str(provider_result.get("output", "")).contains("# Owned addon-provider instances"), true) and ok
	var heal_line: int = -1
	for line_index: int in range(provider_lines.size()):
		if provider_lines[line_index].contains("heal(25)"):
			heal_line = line_index + 1
	ok = _check("the emitted heal call was found", heal_line > 0, true) and ok
	ok = _check("the shifted map still resolves the heal line to ITS event",
		EventSheetLineRowMapper.resource_for_line(provider_result.get("source_map", []), heal_line) == provider_event, true) and ok
	var shifted_range: Vector2i = EventSheetLineRowMapper.range_for_resource(provider_result.get("source_map", []), provider_event)
	ok = _check("the event's shifted range contains the heal line",
		heal_line >= shifted_range.x and heal_line <= shifted_range.y, true) and ok

	# ── Fail-closed lookups ──
	ok = _check("a line past the file maps to nothing", EventSheetLineRowMapper.resource_for_line(source_map, lines.size() + 50) == null, true) and ok
	ok = _check("line 0 maps to nothing (maps are 1-based)", EventSheetLineRowMapper.entries_for_line(source_map, 0).size(), 0) and ok
	ok = _check("an unmapped resource reports (-1,-1)",
		EventSheetLineRowMapper.range_for_resource(source_map, EventRow.new()), Vector2i(-1, -1)) and ok
	ok = _check("a null resource reports (-1,-1)",
		EventSheetLineRowMapper.range_for_resource(source_map, null), Vector2i(-1, -1)) and ok

	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] line_row_mapper_test: %s" % label)
		return true
	print("[FAIL] line_row_mapper_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
