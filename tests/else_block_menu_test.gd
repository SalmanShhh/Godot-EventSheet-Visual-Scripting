# EventForge - the C3-style Else block is a first-class, DISCOVERABLE gesture: right-clicking an event
# offers "Make Else" / "Make Else-If" top-level (Simple Mode included - a Construct reflex, not an expert
# feature), the labels flip to "Clear Else" / "Clear Else-If" when the selection already carries that mode
# (the click toggles it off), and the whole flow compiles to a real `else:` / `elif:` chain that reads back
# with the "Else" badge. Pins: menu presence in SIMPLE mode, the live-state relabel, the toggle behavior
# through the menu handler, and the compile round-trip of a menu-made Else.
@tool
class_name ElseBlockMenuTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	var if_event: EventRow = EventRow.new()
	if_event.trigger_provider_id = "Core"
	if_event.trigger_id = "OnProcess"
	var guard: ACECondition = ACECondition.new()
	guard.provider_id = "Core"
	guard.ace_id = "ExpressionIsTrue"
	guard.params = {"expr": "health > 0"}
	if_event.conditions.append(guard)
	var else_event: EventRow = EventRow.new()
	# Same trigger as the if-event: same-trigger events group into ONE handler body, where adjacent
	# rows chain - exactly where a C3 Else lives (immediately after its if, at the same level).
	else_event.trigger_provider_id = "Core"
	else_event.trigger_id = "OnProcess"
	var die: ACEAction = ACEAction.new()
	die.provider_id = "Core"
	die.ace_id = "QueueFree"
	else_event.actions.append(die)
	sheet.events.append(if_event)
	sheet.events.append(else_event)

	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(sheet)
	dock._simple_mode = true  # the first-run default - Else must be reachable here
	var view: EventSheetViewport = dock._active_view()
	var else_row: EventRowData = null
	for entry: Dictionary in view.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data != null and row_data.source_resource == else_event:
			else_row = row_data

	# ── The context menu offers Make Else top-level in SIMPLE mode ──
	dock._context_row = else_row
	dock._build_row_context_menu(else_row)
	ok = _check("Simple Mode offers Make Else top-level", _item_text(dock, dock.ROW_MENU_MAKE_ELSE) != "", true) and ok
	ok = _check("Simple Mode offers Make Else-If top-level", _item_text(dock, dock.ROW_MENU_MAKE_ELIF) != "", true) and ok

	# ── The menu handler makes the row an Else; the label then reads Clear Else ──
	view._selected_row_uids[else_row.row_uid] = true
	else_row.selected = true
	dock._set_context_else_mode(EventRow.ElseMode.ELSE)
	ok = _check("Make Else sets the row's else_mode", else_event.else_mode, EventRow.ElseMode.ELSE) and ok
	dock._build_row_context_menu(else_row)
	dock._configure_context_menu(dock._row_context_menu)
	ok = _check("the label flips to Clear Else on an else row", _item_text(dock, dock.ROW_MENU_MAKE_ELSE), "Clear Else") and ok
	ok = _check("the sibling stays Make Else-If", _item_text(dock, dock.ROW_MENU_MAKE_ELIF), "Make Else-If") and ok

	# ── The compiled output is a real else: chain, and it reads back with the Else badge ──
	var source: String = str(SheetCompiler.compile(dock.get_current_sheet(), "user://else_menu.gd").get("output", ""))
	ok = _check("the sheet compiles an else: chain", source.contains("\telse:"), true) and ok
	var reimported: EventSheetResource = GDScriptImporter.new().import_external_source(source)
	var lifted_else: bool = false
	for row: Variant in _all_event_rows(reimported.events):
		if (row as EventRow).else_mode == EventRow.ElseMode.ELSE:
			lifted_else = true
	ok = _check("the else round-trips back as an Else row", lifted_else, true) and ok
	reimported.external_source_path = "user://else_menu_rt.gd"
	ok = _check("the menu-made else round-trips byte-identically",
		str(SheetCompiler.compile(reimported, "user://else_menu_rt.gd").get("output", "")) == source, true) and ok

	# ── Clicking Make Else again clears it (the toggle) ──
	dock._set_context_else_mode(EventRow.ElseMode.ELSE)
	var live_else: EventRow = dock.get_current_sheet().events[1] as EventRow
	ok = _check("Make Else on an else row clears it (toggle)", live_else.else_mode, EventRow.ElseMode.NONE) and ok

	# ── Rendering: on an ELIF row with a visible trigger, the "Else If" keyword owns its line - the
	# trigger badge renders on the NEXT line, never over the keyword (the badge-overlap regression). ──
	live_else.else_mode = EventRow.ElseMode.ELIF
	dock._refresh_after_edit()
	var elif_row: EventRowData = null
	for entry: Dictionary in dock._active_view().get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data != null and row_data.source_resource == live_else:
			elif_row = row_data
	var keyword_line: int = -1
	var trigger_line: int = -1
	if elif_row != null:
		for span: SemanticSpan in elif_row.spans:
			if span.metadata is Dictionary:
				var span_kind: String = str((span.metadata as Dictionary).get("kind", ""))
				if span_kind == "else_keyword":
					keyword_line = int((span.metadata as Dictionary).get("line_index", -1))
				elif span_kind == "trigger":
					trigger_line = int((span.metadata as Dictionary).get("line_index", -1))
	ok = _check("the Else If keyword sits on line 0", keyword_line, 0) and ok
	ok = _check("the trigger badge renders on the NEXT line (no overlap)", trigger_line, 1) and ok

	dock.free()
	return ok


static func _item_text(dock: EventSheetDock, id: int) -> String:
	var index: int = dock._row_context_menu.get_item_index(id)
	return dock._row_context_menu.get_item_text(index) if index >= 0 else ""


static func _all_event_rows(rows: Array) -> Array:
	var out: Array = []
	for r: Variant in rows:
		if r is EventRow:
			out.append(r)
			out.append_array(_all_event_rows((r as EventRow).sub_events))
	return out


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] else_block_menu_test: %s" % label)
		return true
	print("[FAIL] else_block_menu_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
