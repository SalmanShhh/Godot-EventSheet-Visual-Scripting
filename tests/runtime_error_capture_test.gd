# Godot EventSheets - runtime errors reach the strip from the RUNNING game. The engine's own error
# channel never reaches editor debugger plugins, so a debug compile carries a Logger subclass that
# announces each script error's message, file and line over the sheet's channel
# ("eventsheets:runtime_error"); the editor bridge relays it and the dock re-says the failure as
# the row said it. Pins: the compiler emission (the reporter class, the _ready arming, every debug
# switch arming it, absent on clean compiles), the emitted debug script still parsing, the bridge
# parse failing closed on a malformed announce, and a fake debug session's scripted error landing
# on the strip with its row resolved through the source map.
@tool
class_name RuntimeErrorCaptureTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")


static func run() -> bool:
	var ok: bool = true

	# ── Compiler: a debug compile carries the reporter, armed once per game in _ready ──
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	sheet.emit_breakpoints = true
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	# A real action, so the event emits real lines - an empty event is a bare `pass` with no
	# source-map entry, and the row-resolution half below needs a line to fail on.
	var vanish: ACEAction = ACEAction.new()
	vanish.provider_id = "Core"
	vanish.ace_id = "QueueFree"
	event.actions.append(vanish)
	sheet.events.append(event)
	var compiled: Dictionary = SheetCompiler.compile(sheet, "user://_runtime_error_capture_out.gd")
	var output: String = str(compiled.get("output", ""))
	var source_map: Array = compiled.get("source_map", [])
	ok = _check("the reporter class is emitted",
		output.contains("class __EventSheetsErrorReporter extends Logger:"), true) and ok
	ok = _check("the reporter is armed in _ready, once per game",
		output.contains("if EngineDebugger.is_active() and not __EventSheetsErrorReporter.armed:"),
		true) and ok
	ok = _check("arming registers the logger",
		output.contains("OS.add_logger(__EventSheetsErrorReporter.new())"), true) and ok
	ok = _check("only script errors are announced, and only in debug sessions",
		output.contains("if error_type != ERROR_TYPE_SCRIPT or not EngineDebugger.is_active():"),
		true) and ok
	ok = _check("each failing line is announced once per run",
		output.contains("if _said.has(location):"), true) and ok
	ok = _check("the announce carries message, file and line on the sheet's channel",
		output.contains("EngineDebugger.send_message.call_deferred(\"eventsheets:runtime_error\", [message, file, line])"),
		true) and ok

	# ── The emitted debug script still parses (the reporter rides inside a real class) ──
	var emitted: GDScript = GDScript.new()
	emitted.source_code = output
	ok = _check("the debug compile parses", emitted.reload(), OK) and ok

	# ── Every sheet-debug switch arms it on its own; a clean compile carries none of it ──
	sheet.emit_breakpoints = false
	sheet.emit_event_trace = true
	var trace_output: String = str(SheetCompiler.compile(sheet,
		"user://_runtime_error_capture_out.gd").get("output", ""))
	ok = _check("the event-trace switch arms the reporter",
		trace_output.contains("OS.add_logger(__EventSheetsErrorReporter.new())"), true) and ok
	sheet.emit_event_trace = false
	sheet.emit_live_values = true
	sheet.variables = {"score": 0}
	var live_output: String = str(SheetCompiler.compile(sheet,
		"user://_runtime_error_capture_out.gd").get("output", ""))
	ok = _check("the live-values switch arms the reporter",
		live_output.contains("OS.add_logger(__EventSheetsErrorReporter.new())"), true) and ok
	sheet.emit_live_values = false
	sheet.variables = {}
	var clean: String = str(SheetCompiler.compile(sheet,
		"user://_runtime_error_capture_out.gd").get("output", ""))
	ok = _check("a clean compile carries no reporter, no logger, no announce",
		clean.contains("__EventSheetsErrorReporter") or clean.contains("OS.add_logger")
			or clean.contains("eventsheets:runtime_error"), false) and ok

	# ── The bridge's payload parse (static - EditorDebuggerPlugin can't be instantiated headless) ──
	var full: Dictionary = EventSheetLiveValuesDebugger.parse_runtime_error(
		["Invalid call. Nonexistent function 'hit' in base 'null instance'.",
			"res://game/player.gd", 42])
	ok = _check("the bridge parses the message", str(full.get("message", "")),
		"Invalid call. Nonexistent function 'hit' in base 'null instance'.") and ok
	ok = _check("the bridge parses the file", str(full.get("script_path", "")),
		"res://game/player.gd") and ok
	ok = _check("the bridge parses the line", int(full.get("line", 0)), 42) and ok
	var truncated: Dictionary = EventSheetLiveValuesDebugger.parse_runtime_error(["boom"])
	ok = _check("a truncated announce keeps its message", str(truncated.get("message", "")),
		"boom") and ok
	ok = _check("a truncated announce defaults its file", str(truncated.get("script_path", "?")),
		"") and ok
	ok = _check("a truncated announce defaults its line", int(truncated.get("line", -1)), 0) and ok
	ok = _check("an empty announce parses empty (the bridge drops it, fail closed)",
		str(EventSheetLiveValuesDebugger.parse_runtime_error([]).get("message", "?")), "") and ok

	# ── A fake debug session: the scripted error lands on the strip, row resolved by line ──
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(sheet)
	dock._code_source_map = source_map
	var event_range: Vector2i = EventSheetLineRowMapper.range_for_resource(source_map, event)
	ok = _check("the event is in the source map", event_range.x > 0, true) and ok
	# The announce exactly as the running game sends it, through the bridge's own parse - the same
	# pipeline the wired signal drives, minus only the live EditorDebuggerSession transport.
	var relay: Dictionary = EventSheetLiveValuesDebugger.parse_runtime_error(
		["Invalid call. Nonexistent function 'hit' in base 'null instance'.",
			"res://game/player.gd", event_range.x])
	var report: Dictionary = dock.report_runtime_error(str(relay.get("message", "")),
		str(relay.get("script_path", "")), int(relay.get("line", 0)))
	ok = _check("the failure is re-said in the sheet's words", str(report.get("said", "")),
		"target is empty") and ok
	ok = _check("the scripted error resolved to its row", report.get("row_resource"), event) and ok
	ok = _check("and to its event number", int(report.get("event_number", 0)), 1) and ok
	ok = _check("the strip is showing", dock._runtime_error_strip.visible, true) and ok
	ok = _check("the strip says the sentence", dock._runtime_error_label.text,
		str(report.get("sentence", ""))) and ok
	ok = _check("Jump to event is live", dock._runtime_error_jump_button.disabled, false) and ok
	dock.free()

	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("runtime_error_capture_test", label, actual, expected)
