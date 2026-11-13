# Godot EventSheets - the Debugger window (Watch / Trail).
# One window over two seams that already shipped. Pins the parts that can be pinned without a debug
# run: the tab names and their empty states, the run band, the sentences the paused row is named by,
# the watch table, and the bridge's timings message. The per-event timing model is pinned in
# trace_timings_test.gd.
@tool
class_name DebuggerWindowTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")


static func _event(uid: String, breakpoint_on: bool, condition: String) -> EventRow:
	var row: EventRow = EventRow.new()
	row.event_uid = uid
	row.debug_break = breakpoint_on
	row.debug_break_condition = condition
	return row


static func _flat(uid: String, number: int, breakpoint_on: bool,
		condition: String = "") -> Dictionary:
	var row_data: EventRowData = EventRowData.new()
	row_data.event_number = number
	row_data.source_resource = _event(uid, breakpoint_on, condition)
	return {"row": row_data}


static func run() -> bool:
	var ok: bool = true

	# ── The tabs, by name, and what each says before a run ──
	ok = _check("the tabs are the names a reader arrives with",
		",".join(EventSheetDebuggerWindow.TAB_TITLES),
		"Watch,Trail") and ok
	var missing_states: PackedStringArray = PackedStringArray()
	for title: String in EventSheetDebuggerWindow.TAB_TITLES:
		if str(EventSheetDebuggerWindow.EMPTY_STATES.get(title, "")).is_empty():
			missing_states.append(title)
	ok = _check("every tab says what to do when it is empty", ",".join(missing_states), "") and ok

	# ── The run band over every tab ──
	ok = SUPPORT.pins("debugger_window_test", [
		["a paused run names the sheet, the streams and the row",
			EventSheetDebuggerWindow.run_band("player.gd", true, true, true, "event 12 - when health <= 0"),
			PackedStringArray(["player.gd", "running · Live Values on · Event Trace on",
				"Paused at event 12 - when health <= 0"])],
		["no run reporting says so, and a run that is not paused says nothing about pausing",
			EventSheetDebuggerWindow.run_band("player.gd", false, true, false, ""),
			PackedStringArray(["player.gd", "no run reporting · Live Values on · Event Trace off", ""])],
	]) and ok

	# ── Breakpoints: the list, and what each row says ──
	var flat: Array = [_flat("a", 3, true), _flat("b", 4, false),
		_flat("c", 12, true, "health <= 0")]
	var breakpoints: Array[Dictionary] = EventSheetDebuggerWindow.breakpoint_rows(flat)
	ok = _check("only the armed rows are listed", breakpoints.size(), 2) and ok
	ok = _check("an unconditional breakpoint reads as its event",
		EventSheetDebuggerWindow.breakpoint_text(breakpoints[0]), "event 3") and ok
	ok = _check("a conditional one says when it pauses",
		EventSheetDebuggerWindow.breakpoint_text(breakpoints[1]),
		"event 12 - when health <= 0") and ok
	ok = _check("a sheet with no breakpoints lists none",
		EventSheetDebuggerWindow.breakpoint_rows([]).size(), 0) and ok
	ok = _test_the_window_is_two_tabs_with_the_mode_line() and ok
	ok = _test_watch_table() and ok

	# ── The bridge parses the timings message it will really be handed ──
	var window: Dictionary = EventSheetLiveValuesDebugger.parse_event_times(
		[[1000, 1200], [0], 1500])
	ok = _check("the stamps arrive", (window["stamps"] as PackedInt64Array).size(), 2) and ok
	ok = _check("the frame ruler arrives", (window["markers"] as PackedInt32Array).size(), 1) and ok
	ok = _check("the flush moment arrives", int(window["flush"]), 1500) and ok
	ok = _check("a truncated message fails closed rather than erroring",
		int(EventSheetLiveValuesDebugger.parse_event_times([]).get("flush", -1)), 0) and ok

	return ok


## The window has exactly the Watch and Trail tabs, and the Trail tab carries the line that says how
## the game got to the mode it is in (the line the separate Live Values window used to show).
static func _test_the_window_is_two_tabs_with_the_mode_line() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	var dock: EventSheetDock = EventSheetDock.new()
	dock.setup(sheet)
	var debugger: EventSheetDebuggerWindow = EventSheetDebuggerWindow.new(dock)
	debugger.ensure_window()
	var titles: PackedStringArray = PackedStringArray()
	for index: int in range(debugger.tabs.get_tab_count()):
		titles.append(debugger.tabs.get_tab_title(index))
	var panel: EventSheetLiveValuesPanel = dock._ensure_live_values_panel()
	debugger._refresh_trail()
	var quiet: bool = debugger.trail_modes_label.visible
	panel.note_mode({"mode": "MENU"})
	panel.note_mode({"mode": "PLAYING"})
	debugger._refresh_trail()
	var said: String = debugger.trail_modes_label.text
	var shown: bool = debugger.trail_modes_label.visible
	debugger.window.queue_free()
	dock.free()
	return SUPPORT.pins("debugger_window_test", [
		["the window has the two tabs", ",".join(titles), "Watch,Trail"],
		["the mode line stays hidden until a mode has streamed", quiet, false],
		["and once one has, the Trail tab says how the game got here", [shown, said.begins_with("How it got here: ")], [true, true]],
		["Live Values opens no window of its own", panel.has_method("ensure_window"), false],
	])


## The watch table the window draws: an unreadable watch says "cannot read" and why on its own line.
static func _test_watch_table() -> bool:
	var table: Tree = Tree.new()
	table.columns = 2
	var watched: Array[String] = ["health <= 0", "velocity.x > 0"]
	EventSheetLiveValuesPanel.fill_watch_tree(table, watched, {"health": 1, "Sine.phase": 0.5})
	var rows: Array[TreeItem] = table.get_root().get_children()
	var why: TreeItem = rows[1].get_first_child()
	var ok: bool = SUPPORT.pins("debugger_window_test", [
		["a readable watch shows its value", rows[0].get_text(1), "false"],
		["an unreadable one says it cannot be read, not an engine error", rows[1].get_text(1), "cannot read"],
		["and says why on its own line", why.get_text(0) if why != null else "", "velocity is not a streamed value."],
		["before a run every watch reads as a dash",
			_watch_cells_without_a_run(table, watched), "-,-"],
		["a missing name is found past members and calls",
			EventSheetLiveValuesPanel.missing_name("sin(speed) + pos.x + hp", PackedStringArray(["hp"])), "speed"],
		["Expression's own words are never missing",
			EventSheetLiveValuesPanel.missing_name("true and not PI", PackedStringArray()), ""],
	])
	table.free()
	return ok


static func _watch_cells_without_a_run(table: Tree, watched: Array[String]) -> String:
	EventSheetLiveValuesPanel.fill_watch_tree(table, watched, {})
	return ",".join(table.get_root().get_children().map(func(item: TreeItem) -> String: return item.get_text(1)))


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("  [FAIL] debugger_window_test: %s (got %s, expected %s)" % [label, str(actual), str(expected)])
	return false
