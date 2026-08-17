# EventForge - Row hit counts + "Why didn't this fire?"
#
# The two debugger LENSES over the Event Trace, and the one rule they both live under: with
# nothing turned on, the sheet is the program and no chrome is emitted. So this pins
#   1. the tally (the streamed window is a tally, repeats included - counting it is the feature),
#   2. the gate (lens off / no traced run -> the gutter draws exactly what it always drew),
#   3. the explanation (a real condition evaluated against real streamed values, and the plain
#      refusal to guess when the game is not running).
#
# Neither lens mutates a sheet, so there is no undo entry to restore: the assertion that matters
# instead is that the row resource is untouched after an explanation, which is checked below.
@tool
class_name HitCountsAndWhyTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _run_counts() and all_passed
	all_passed = _run_gate() and all_passed
	all_passed = _run_why() and all_passed
	all_passed = _run_dock_paths() and all_passed
	EventSheetTraceHitCounts.reset()
	if all_passed:
		print("[PASS] hit_counts_and_why_test: the tally, the off-by-default gate, the explanation, and both dock paths")
	return all_passed


# ── 1. The tally ──────────────────────────────────────────────────────────────────────────
static func _run_counts() -> bool:
	var all_passed: bool = true
	EventSheetTraceHitCounts.reset()
	all_passed = _check("no run yet", EventSheetTraceHitCounts.has_run(), false) and all_passed
	all_passed = _check("no count before a run", EventSheetTraceHitCounts.count_for("aa"), 0) and all_passed

	# One streamed window, exactly as the generated code sends it: an entry PER FIRE.
	EventSheetTraceHitCounts.note_fired(PackedStringArray(["aa", "aa", "aa", "bb"]))
	all_passed = _check("run seen", EventSheetTraceHitCounts.has_run(), true) and all_passed
	all_passed = _check("repeats in one window all count", EventSheetTraceHitCounts.count_for("aa"), 3) and all_passed
	all_passed = _check("second row counted once", EventSheetTraceHitCounts.count_for("bb"), 1) and all_passed
	# A second window accumulates onto the first.
	EventSheetTraceHitCounts.note_fired(PackedStringArray(["aa", "aa"]))
	all_passed = _check("windows accumulate", EventSheetTraceHitCounts.count_for("aa"), 5) and all_passed
	all_passed = _check("busiest row tracked", EventSheetTraceHitCounts.max_count(), 5) and all_passed
	all_passed = _check("row that never fired reads zero", EventSheetTraceHitCounts.count_for("zz"), 0) and all_passed
	all_passed = _check("busiest row is hot", EventSheetTraceHitCounts.is_hot("aa"), true) and all_passed
	all_passed = _check("one-hit row is not hot", EventSheetTraceHitCounts.is_hot("bb"), false) and all_passed

	all_passed = _check("chip is exact under a thousand", EventSheetTraceHitCounts.chip_text(437), "437") and all_passed
	all_passed = _check("chip abbreviates thousands", EventSheetTraceHitCounts.chip_text(1431), "1k") and all_passed
	all_passed = _check("chip caps the extreme case", EventSheetTraceHitCounts.chip_text(4000000), "99k+") and all_passed
	all_passed = _check("tooltip groups the exact number", EventSheetTraceHitCounts.format_count(1431), "1,431") and all_passed
	all_passed = _check("tooltip names the row and the count",
		EventSheetTraceHitCounts.tooltip_for("aa", 12), "Event 12: fired 5 times since Run - hot.") and all_passed
	all_passed = _check("tooltip says never rather than zero",
		EventSheetTraceHitCounts.tooltip_for("zz", 13), "Event 13: never fired since Run.") and all_passed

	# A new debug session (a new Run) starts the tally over - the reset the debugger bridge calls.
	EventSheetTraceHitCounts.reset()
	all_passed = _check("reset forgets the run", EventSheetTraceHitCounts.has_run(), false) and all_passed
	all_passed = _check("reset forgets the counts", EventSheetTraceHitCounts.count_for("aa"), 0) and all_passed
	# An EMPTY window still proves the game is running: that is what makes "never fired" honest.
	EventSheetTraceHitCounts.note_fired(PackedStringArray())
	all_passed = _check("an empty window still counts as a run", EventSheetTraceHitCounts.has_run(), true) and all_passed
	all_passed = _check("the report leads with the run",
		EventSheetTraceHitCounts.as_text().begins_with("Event trace"), true) and all_passed
	return all_passed


# ── 2. The gate: off means nothing is emitted ─────────────────────────────────────────────
static func _run_gate() -> bool:
	var all_passed: bool = true
	EventSheetTraceHitCounts.reset()
	EventSheetTraceHitCounts.note_fired(PackedStringArray(["aa", "aa", "aa"]))
	# The View toggle OFF - the default a fresh install ships with - emits nothing at all.
	all_passed = _check("lens off emits no chip", EventRowRenderer.hit_chip_uid(false, true, "aa"), "") and all_passed
	# On, but not an event row (a group / comment bar): still nothing, the gutter is theirs.
	all_passed = _check("non-event rows never get a chip", EventRowRenderer.hit_chip_uid(true, false, "aa"), "") and all_passed
	all_passed = _check("lens on reports the row", EventRowRenderer.hit_chip_uid(true, true, "aa"), "aa") and all_passed
	all_passed = _check("chip text carries the count", EventRowRenderer.hit_chip_text("aa"), "x3") and all_passed
	all_passed = _check("never-fired row reads x0", EventRowRenderer.hit_chip_text("zz"), "x0") and all_passed
	# No traced run: the lens is on and STILL nothing is drawn, because there is nothing to say.
	EventSheetTraceHitCounts.reset()
	all_passed = _check("no run means no chip even with the lens on",
		EventRowRenderer.hit_chip_uid(true, true, "aa"), "") and all_passed
	# The renderer a fresh viewport stamps: the flag ships false.
	var renderer: EventRowRenderer = EventRowRenderer.new()
	all_passed = _check("renderer ships with the lens off", renderer.show_hit_counts, false) and all_passed
	var viewport: EventSheetViewport = EventSheetViewport.new()
	all_passed = _check("viewport ships with the lens off", viewport.show_hit_counts, false) and all_passed
	viewport.free()
	# The hover answers even with the lens off - but only once a run has streamed.
	all_passed = _check("hover is silent with no run", EventSheetTraceHitCounts.tooltip_for("aa", 3), "") and all_passed
	return all_passed


# ── 3. Why didn't this fire? ──────────────────────────────────────────────────────────────
static func _run_why() -> bool:
	var all_passed: bool = true
	var row: EventRow = EventRow.new()
	row.conditions.append(_condition("score >= 100"))
	row.conditions.append(_condition("lives > 0"))
	var values: Dictionary = {"score": 142, "lives": 0}

	var report: Dictionary = EventSheetWhyPanel.build_report(row, values, true)
	var entries: Array = report.get("conditions", [])
	all_passed = _check("both conditions explained", entries.size(), 2) and all_passed
	all_passed = _check("the true condition reads true", str((entries[0] as Dictionary)["verdict"]), EventSheetWhyPanel.VERDICT_TRUE) and all_passed
	all_passed = _check("the false condition reads false", str((entries[1] as Dictionary)["verdict"]), EventSheetWhyPanel.VERDICT_FALSE) and all_passed
	all_passed = _check("the value it saw is reported", str((entries[0] as Dictionary)["seen"]), "score = 142") and all_passed
	all_passed = _check("the blocker is named", int(report.get("blocker_index", -1)), 1) and all_passed
	all_passed = _check("one blocker reads as one",
		str(report.get("verdict_line", "")), "One condition said no - it is marked below.") and all_passed
	all_passed = _check("a whole-word match does not spill",
		EventSheetWhyPanel._mentions_identifier("score >= 100", "cor"), false) and all_passed

	# A condition that reaches past the streamed variables is reported as unreadable, NOT guessed.
	var node_row: EventRow = EventRow.new()
	node_row.conditions.append(_condition("is_on_floor()"))
	var node_report: Dictionary = EventSheetWhyPanel.build_report(node_row, values, true)
	var node_entry: Dictionary = (node_report.get("conditions", []) as Array)[0]
	all_passed = _check("an unreadable condition stays unknown", str(node_entry["verdict"]), EventSheetWhyPanel.VERDICT_UNKNOWN) and all_passed
	all_passed = _check("and says why it cannot be read",
		str(node_entry["note"]), "not observable from here - it reads the node, not a sheet variable") and all_passed

	# No running game: it says so in one line rather than inventing a table of verdicts.
	var cold: Dictionary = EventSheetWhyPanel.build_report(row, {}, false)
	all_passed = _check("no session is stated, not guessed", str(cold.get("verdict_line", "")), EventSheetWhyPanel.NO_SESSION_LINE) and all_passed
	all_passed = _check("no session means no verdicts", int(cold.get("blocker_index", -1)), -1) and all_passed
	all_passed = _check("the conditions are still listed", (cold.get("conditions", []) as Array).size(), 2) and all_passed

	# The panel is a READ: the row it explains is not touched (no undo entry to restore, because
	# there is nothing to undo).
	all_passed = _check("the explained row keeps its conditions", row.conditions.size(), 2) and all_passed
	all_passed = _check("the explained row keeps its template",
		(row.conditions[0] as ACECondition).codegen_template, "score >= 100") and all_passed

	# The body assembles for a real report (the window is this plus a shell).
	var body: Control = EventSheetWhyPanel.build_body(report, 8)
	all_passed = _check("the panel body assembles", body != null, true) and all_passed
	if body != null:
		all_passed = _check("the panel body carries its sections", body.get_child_count() >= 4, true) and all_passed
		body.free()
	return all_passed


# ── 4. The dock paths: the View toggle across panes, and the run ending ───────────────────
static func _run_dock_paths() -> bool:
	var all_passed: bool = true
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	dock.setup(sheet)

	# ONE target state for every pane. A second pane that ships with the lens off (which every fresh
	# pane does) must not end up inverted against the first, or the menu tick reports the wrong one.
	var second_pane: EventSheetViewport = EventSheetViewport.new()
	dock._detached_viewport = second_pane
	dock._toggle_row_hit_counts(null)
	all_passed = _check("the toggle turns the main pane on", dock._viewport.show_hit_counts, true) and all_passed
	all_passed = _check("and the second pane with it", second_pane.show_hit_counts, true) and all_passed
	dock._toggle_row_hit_counts(null)
	all_passed = _check("toggling again turns the main pane off", dock._viewport.show_hit_counts, false) and all_passed
	all_passed = _check("and the second pane with it, never inverted", second_pane.show_hit_counts, false) and all_passed
	dock._detached_viewport = null
	second_pane.free()

	# The run ending: the last streamed frame stops being live. Without this the Why panel would
	# stamp "live" on minutes-old numbers in the case a reader is likeliest to hit - you stop the
	# game, THEN ask why the row did not fire.
	var row: EventRow = EventRow.new()
	row.conditions.append(_condition("score >= 100"))
	var panel: EventSheetLiveValuesPanel = dock._ensure_live_values_panel()
	panel._refresh_watches({"score": 142})
	all_passed = _check("a streamed frame reads as live",
		bool(EventSheetWhyPanel.build_report(row, panel._last_values, not panel._last_values.is_empty()).get("streaming", false)), true) and all_passed
	dock._on_debug_session_ended()
	all_passed = _check("the run ending drops the last frame", panel._last_values.is_empty(), true) and all_passed
	all_passed = _check("so the panel says there is no session rather than answering from stale values",
		str(EventSheetWhyPanel.build_report(row, panel._last_values, not panel._last_values.is_empty()).get("verdict_line", "")),
		EventSheetWhyPanel.NO_SESSION_LINE) and all_passed
	dock.free()
	return all_passed


## A condition whose compiled expression is exactly `expression` - the shape the dock bakes at
## apply time, so the panel reads the same string the compiler would emit.
static func _condition(expression: String) -> ACECondition:
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = "TestCondition"
	condition.codegen_template = expression
	return condition


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("[FAIL] hit_counts_and_why_test: %s - expected %s, got %s" % [label, str(expected), str(actual)])
	return false
