# Godot EventSheets - the Debugger window (Inspect / Watch / Profile / Breakpoints).
# One window over four seams that already shipped. Pins the parts that can be pinned without a
# debug run: the tab names and their empty states, the Inspect tab's object rows over a census and
# a streamed frame, the Profile numbers over a FIXTURE trace window (the self-time model, the frame
# ruler, the unmeasurable last fire of a frame), and the Breakpoints rows and their sentences.
@tool
class_name DebuggerWindowTest
extends RefCounted


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

	# ── The four tabs, by name, and what each says before a run ──
	ok = _check("the tabs are the four names a reader arrives with",
		",".join(EventSheetDebuggerWindow.TAB_TITLES),
		"Inspect,Watch,Profile,Breakpoints") and ok
	var missing_states: PackedStringArray = PackedStringArray()
	for title: String in EventSheetDebuggerWindow.TAB_TITLES:
		if str(EventSheetDebuggerWindow.EMPTY_STATES.get(title, "")).is_empty():
			missing_states.append(title)
	ok = _check("every tab says what to do when it is empty", ",".join(missing_states), "") and ok

	# ── Inspect: the objects, and which of them the run is reporting on ──
	var census: Array = [
		{"label": "Enemy", "kind": "node"},
		{"label": "Sine", "kind": "behaviour"},
	]
	var values: Dictionary = {"hp": 4, "Sine.phase": 1.5, "Sine.amplitude": 20}
	var rows: Array[Dictionary] = EventSheetDebuggerWindow.object_rows(census, values)
	ok = _check("one row per object the sheet talks about", rows.size(), 2) and ok
	ok = _check("an object the run reports on carries its values",
		(rows[1]["live"] as PackedStringArray).size(), 2) and ok
	ok = _check("and they are its own, in order",
		",".join(rows[1]["live"] as PackedStringArray), "Sine.amplitude,Sine.phase") and ok
	ok = _check("an object the run says nothing about promises nothing",
		(rows[0]["live"] as PackedStringArray).size(), 0) and ok

	# ── Profile: the self-time model over a fixture window ──
	# Two frames. Frame 1 fires a, b, c; frame 2 fires a, b. Stamps are microseconds.
	#   a: 1000 -> 1200 = 200          b: 1200 -> 1500 = 300      c: last of frame 1, unmeasured
	#   a: 20000 -> 20100 = 100        b: last of frame 2, closed by the flush at 20400 = 300
	EventSheetTraceTimings.reset()
	EventSheetTraceHitCounts.reset()
	var uids: PackedStringArray = PackedStringArray(["a", "b", "c", "a", "b"])
	EventSheetTraceHitCounts.note_fired(uids)
	EventSheetTraceTimings.note_window(uids,
		PackedInt64Array([1000, 1200, 1500, 20000, 20100]),
		PackedInt32Array([0, 3]), 20400)
	ok = _check("a fire is charged the time up to the next fire in its frame",
		EventSheetTraceTimings.usec_for("a"), 300) and ok
	ok = _check("and a fire closed by the flush is charged to the flush",
		EventSheetTraceTimings.usec_for("b"), 600) and ok
	ok = _check("the last fire of a frame that has already ended is not guessed at",
		EventSheetTraceTimings.usec_for("c"), 0) and ok
	ok = _check("only the measurable fires are averaged over",
		EventSheetTraceTimings.measured_calls_for("a"), 2) and ok
	ok = _check("the per-fire time is the average of those",
		EventSheetTraceTimings.ms_per_call("a"), 0.15) and ok
	ok = _check("an event with no measurable fire reads as unknown, never as zero",
		EventSheetTraceTimings.ms_per_call("c"), -1.0) and ok
	ok = _check("the run's traced span is first stamp to flush",
		EventSheetTraceTimings.run_span_usec(), 19400) and ok
	ok = _check("the frame ruler counted both frames", EventSheetTraceTimings.frames(), 2) and ok

	var profile: Array[Dictionary] = EventSheetTraceTimings.rows({"a": 4, "b": 7})
	ok = _check("the profile is busiest first",
		str(profile[0].get("uid", "")), "b") and ok
	ok = _check("and speaks in the sheet's event numbers",
		EventSheetTraceTimings.row_text(profile[0]),
		"event 7 · 0.30 ms · 3% of the run · 2 fires") and ok
	ok = _check("an event that fired but was never measurable is left out of the profile",
		profile.size(), 2) and ok
	EventSheetTraceTimings.reset()
	EventSheetTraceHitCounts.reset()
	ok = _check("resetting forgets the run", EventSheetTraceTimings.has_run(), false) and ok

	# A window with no stamps at all (an older debug compile) degrades rather than erroring.
	EventSheetTraceTimings.note_window(PackedStringArray(["a"]), PackedInt64Array(),
		PackedInt32Array(), 0)
	ok = _check("a window with no times still counts as a run",
		EventSheetTraceTimings.has_run(), true) and ok
	ok = _check("and reports no time rather than a wrong one",
		EventSheetTraceTimings.usec_for("a"), 0) and ok
	EventSheetTraceTimings.reset()

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

	# ── The bridge parses the timings message it will really be handed ──
	var window: Dictionary = EventSheetLiveValuesDebugger.parse_event_times(
		[[1000, 1200], [0], 1500])
	ok = _check("the stamps arrive", (window["stamps"] as PackedInt64Array).size(), 2) and ok
	ok = _check("the frame ruler arrives", (window["markers"] as PackedInt32Array).size(), 1) and ok
	ok = _check("the flush moment arrives", int(window["flush"]), 1500) and ok
	ok = _check("a truncated message fails closed rather than erroring",
		int(EventSheetLiveValuesDebugger.parse_event_times([]).get("flush", -1)), 0) and ok

	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("  [FAIL] debugger_window_test: %s (got %s, expected %s)" % [label, str(actual), str(expected)])
	return false
