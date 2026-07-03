# EventForge — live paused-at-row for sheet breakpoints. Core debugger messages (stack dumps) never
# reach editor plugins, so the generated code reports its OWN location: right before each emitted
# `breakpoint` statement it sends "eventsheets:paused_row" with the row's stable event_uid over the
# same custom channel live-values uses; the editor bridge relays it and the dock finds the event
# across the open tabs and reveals it. Pins: the compiler emission (plain + conditional breakpoints,
# absent on clean sheets), the bridge parse, and the dock's cross-tab find-activate-reveal.
@tool
class_name PausedRowTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	# ── Compiler: the announce precedes the breakpoint, carrying the row's uid ──
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	sheet.emit_breakpoints = true
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	event.debug_break = true
	sheet.events.append(event)
	var conditional: EventRow = EventRow.new()
	conditional.trigger_provider_id = "Core"
	conditional.trigger_id = "OnReady"
	conditional.debug_break = true
	conditional.debug_break_condition = "health <= 0"
	sheet.events.append(conditional)
	var output: String = str(SheetCompiler.compile(sheet, "user://_paused_row_out.gd").get("output", ""))
	var announce: String = "EngineDebugger.send_message(\"eventsheets:paused_row\", [\"%s\"])" % event.event_uid
	ok = _check("the announce line is emitted with the row's uid", output.contains(announce), true) and ok
	ok = _check("the announce comes BEFORE the breakpoint",
		output.find(announce) < output.find("\tbreakpoint") and output.find(announce) >= 0, true) and ok
	ok = _check("a conditional breakpoint announces inside its condition",
		output.contains("if health <= 0:") and output.contains(conditional.event_uid), true) and ok
	ok = _check("the announce is debugger-guarded (no cost in exported games)",
		output.contains("if EngineDebugger.is_active(): EngineDebugger.send_message(\"eventsheets:paused_row\""), true) and ok

	# ── A clean sheet (no emit flag) carries none of it ──
	sheet.emit_breakpoints = false
	var clean: String = str(SheetCompiler.compile(sheet, "user://_paused_row_out.gd").get("output", ""))
	ok = _check("no emit flag → no announce, no breakpoint", clean.contains("paused_row") or clean.contains("breakpoint"), false) and ok

	# ── The bridge's payload parse (static — EditorDebuggerPlugin can't be instantiated headless) ──
	ok = _check("the bridge parses the paused uid",
		EventSheetLiveValuesDebugger.parse_paused([event.event_uid]), event.event_uid) and ok
	ok = _check("an empty payload parses empty (fail closed downstream)",
		EventSheetLiveValuesDebugger.parse_paused([]), "") and ok

	# ── The dock finds the event across tabs, activates its tab, and reveals the row ──
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(sheet)  # tab 0 holds the breakpoint sheet
	var other: EventSheetResource = EventSheetResource.new()
	other.host_class = "Node"
	dock._open_sheet_in_tab(other, "")  # tab 1, now active
	ok = _check("the other tab is active before the pause", dock.get_current_sheet(), other) and ok
	dock.reveal_paused_row(event.event_uid)
	ok = _check("the pause switched to the breakpoint sheet's tab", dock.get_current_sheet(), sheet) and ok
	ok = _check("the paused event's row is selected",
		dock._active_view().get_selected_context().get("source_resource", null), event) and ok
	dock.reveal_paused_row("")  # empty uid: a no-op, never a crash
	dock.free()

	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] paused_row_test: %s" % label)
		return true
	print("[FAIL] paused_row_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
