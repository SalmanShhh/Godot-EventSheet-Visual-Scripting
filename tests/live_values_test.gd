# Godot EventSheets - Live Values v1 (debugging rung 2): debug compiles stream sheet
# variables over EngineDebugger; the editor's Live Values window shows them. Normal
# compiles never carry the stream (covenant intact).
@tool
class_name LiveValuesTest
extends RefCounted


class NoopUndoManager:
	extends RefCounted
	func create_action(_a = null) -> void: pass
	func add_do_method(_a = null, _b = null, _c = null, _d = null, _e = null) -> void: pass
	func add_undo_method(_a = null, _b = null, _c = null, _d = null, _e = null) -> void: pass
	func commit_action() -> void: pass
	func has_undo() -> bool: return false
	func has_redo() -> bool: return false
	func undo() -> void: pass
	func redo() -> void: pass
	func clear_history() -> void: pass


static func run() -> bool:
	var all_passed: bool = true

	# Off by default: no stream artifacts at all.
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.variables = {"hp": {"type": "int", "default": 100, "exported": true}}
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	var act: ACEAction = ACEAction.new()
	act.provider_id = "Core"
	act.ace_id = "X"
	act.codegen_template = "rotation += delta"
	event.actions.append(act)
	sheet.events.append(event)
	sheet.host_class = "Node2D"
	var off_output: String = str(SheetCompiler.compile(sheet, "user://eventsheets_lv_off.gd").get("output", ""))
	all_passed = _check("normal compiles carry no stream", off_output.contains("live_values"), false) and all_passed

	# On + existing _process trigger: the send block injects BEFORE user logic.
	sheet.emit_live_values = true
	var on_output: String = str(SheetCompiler.compile(sheet, "user://eventsheets_lv_on.gd").get("output", ""))
	all_passed = _check("debug compiles declare the throttle member",
		on_output.contains("var __live_values_timer: float = 0.0"), true) and all_passed
	all_passed = _check("send block injects into the existing _process",
		on_output.contains("var __live_frame: Array = [\"hp\", hp]")
		and on_output.contains("EngineDebugger.send_message(\"eventsheets:live_values\", __live_frame)")
		and on_output.find("send_message") < on_output.find("rotation += delta")
		and on_output.count("func _process") == 1, true) and all_passed
	var on_script: GDScript = GDScript.new()
	on_script.source_code = on_output
	all_passed = _check("streaming output parses", on_script.reload(true) == OK, true) and all_passed

	# On + NO process trigger: a standalone _process is emitted.
	var idle: EventSheetResource = EventSheetResource.new()
	idle.emit_live_values = true
	idle.variables = {"score": {"type": "int", "default": 0, "exported": true}}
	var idle_output: String = str(SheetCompiler.compile(idle, "user://eventsheets_lv_idle.gd").get("output", ""))
	all_passed = _check("sheets without a process trigger get a standalone one",
		idle_output.contains("func _process(delta: float) -> void:") and idle_output.contains("[\"score\", score]"), true) and all_passed
	var idle_script: GDScript = GDScript.new()
	idle_script.source_code = idle_output
	all_passed = _check("standalone output parses", idle_script.reload(true) == OK, true) and all_passed

	# No variables: honest warning, no broken emission.
	var empty: EventSheetResource = EventSheetResource.new()
	empty.emit_live_values = true
	var empty_result: Dictionary = SheetCompiler.compile(empty, "user://eventsheets_lv_empty.gd")
	all_passed = _check("no variables warns instead of emitting",
		str(empty_result.get("warnings")).contains("no variables") and not str(empty_result.get("output", "")).contains("live_values"), true) and all_passed

	# Payload parsing (the editor side of the channel).
	all_passed = _check("payload pairs parse",
		EventSheetLiveValuesDebugger.parse_payload(["hp", 95, "speed", 4.5]), {"hp": 95, "speed": 4.5}) and all_passed
	all_passed = _check("odd payloads drop the trailing name",
		EventSheetLiveValuesDebugger.parse_payload(["hp", 95, "orphan"]), {"hp": 95}) and all_passed

	# Dock window updates from a frame.
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(EventSheetResource.new())
	editor.set_undo_redo_manager(NoopUndoManager.new())
	editor.update_live_values({"hp": 42, "ammo": 7})
	var first_row: TreeItem = editor._live_values_tree.get_root().get_first_child()
	all_passed = _check("Live Values tree renders the frame sorted",
		first_row.get_text(0) == "ammo" and first_row.get_text(1) == "7" and first_row.get_next().get_text(0) == "hp", true) and all_passed
	all_passed = _check("values are editable in place", first_row.is_editable(1), true) and all_passed
	# Edit-back channel: typed parsing + the no-session guard.
	all_passed = _check("edited text parses to typed values",
		[EventSheetLiveValuesDebugger.parse_edited_value("3.5"), EventSheetLiveValuesDebugger.parse_edited_value("true"), EventSheetLiveValuesDebugger.parse_edited_value("hello")],
		[3.5, true, "hello"]) and all_passed
	# Nested values: containers expand into read-only subtrees; scalars stay editable.
	editor.update_live_values({"stats": {"hp": 9, "mp": 3}, "tags": ["a", "b"], "score": 5})
	var score_row: TreeItem = null
	var stats_row: TreeItem = null
	var tags_row: TreeItem = null
	var walk: TreeItem = editor._live_values_tree.get_root().get_first_child()
	while walk != null:
		match walk.get_text(0):
			"score": score_row = walk
			"stats": stats_row = walk
			"tags": tags_row = walk
		walk = walk.get_next()
	all_passed = _check("dictionaries expand into subtrees",
		stats_row.get_child_count() == 2 and stats_row.get_first_child().get_text(0) == "hp" and stats_row.get_first_child().get_text(1) == "9", true) and all_passed
	all_passed = _check("arrays expand with indices",
		tags_row.get_child_count() == 2 and tags_row.get_first_child().get_text(0) == "[0]", true) and all_passed
	all_passed = _check("containers are read-only, scalars stay editable",
		not stats_row.is_editable(1) and not stats_row.get_first_child().is_editable(1) and score_row.is_editable(1), true) and all_passed

	# (EditorDebuggerPlugin isn't instantiable headless - send_set_value's no-session
	# guard is exercised by the editor smoke instead.)
	# Debug compiles register the receiver + handler; normal compiles never do.
	var rx_output: String = str(SheetCompiler.compile(sheet, "user://eventsheets_lv_rx.gd").get("output", ""))
	all_passed = _check("debug compiles register the edit-back receiver",
		rx_output.contains("EngineDebugger.register_message_capture(&\"eventsheets\", _eventsheets_debug_set)")
		and rx_output.contains("func _eventsheets_debug_set(message: String, data: Array) -> bool:"), true) and all_passed
	var rx_script: GDScript = GDScript.new()
	rx_script.source_code = rx_output
	all_passed = _check("receiver output parses", rx_script.reload(true) == OK, true) and all_passed
	all_passed = _check("normal compiles carry no receiver",
		off_output.contains("_eventsheets_debug_set"), false) and all_passed
	editor.free()

	# Stateful copy independence (sweep regression): duplicated Every X Seconds
	# conditions re-bake their member uid - copies own their own accumulator.
	var stateful: ACECondition = ACECondition.new()
	stateful.member_declaration = "var __every_aaaa1111: float = 0.0"
	stateful.codegen_template = "__every_aaaa1111 >= maxf(2.0, 0.001)"
	stateful.codegen_prelude = "__every_aaaa1111 += delta"
	stateful.codegen_on_true = "__every_aaaa1111 = fmod(__every_aaaa1111, maxf(2.0, 0.001))"
	var copy_event: EventRow = EventRow.new()
	copy_event.conditions.append(stateful)
	var copy_editor: EventSheetEditor = EventSheetEditor.new()
	copy_editor.setup(EventSheetResource.new())
	copy_editor.set_undo_redo_manager(NoopUndoManager.new())
	copy_editor._assign_fresh_event_uids(copy_event)
	all_passed = _check("duplicated stateful conditions re-bake their uid",
		not stateful.member_declaration.contains("aaaa1111")
		and stateful.codegen_template.contains(stateful.member_declaration.get_slice(":", 0).trim_prefix("var ")), true) and all_passed
	# Same class of bug for ACTION templates: pasted spawn/audio one-shots must not
	# redeclare the same baked local in one trigger body.
	var spawn_copy: ACEAction = ACEAction.new()
	spawn_copy.codegen_template = "var __spawn_bbbb2222 = load(\"res://x.tscn\").instantiate()\nadd_child(__spawn_bbbb2222)"
	var spawn_event: EventRow = EventRow.new()
	spawn_event.actions.append(spawn_copy)
	copy_editor._assign_fresh_event_uids(spawn_event)
	all_passed = _check("duplicated action templates re-bake their uid",
		not spawn_copy.codegen_template.contains("bbbb2222")
		and spawn_copy.codegen_template.count("__spawn_") == 2, true) and all_passed
	copy_editor.free()
	# Baked {uid} tokens never collide within a session (regression: the random-only draw could
	# repeat, so two {uid} ACEs in one event body declared the same local - invalid GDScript).
	var uid_seen: Dictionary = {}
	var uid_ok: bool = true
	for _uid_i in range(4000):
		var tok: String = EventSheetDock._fresh_uid_token()
		if uid_seen.has(tok) or tok.length() != 8:
			uid_ok = false
		uid_seen[tok] = true
	all_passed = _check("minted {uid} tokens are unique + 8 hex digits", uid_ok, true) and all_passed

	# Watch panel (#3): evaluate_watch evaluates an expression over the streamed variable values.
	var w1: Dictionary = EventSheetLiveValuesPanel.evaluate_watch("health + 1", {"health": 5})
	all_passed = _check("watch: arithmetic over a variable", bool(w1.get("ok")) and w1.get("value") == 6, true) and all_passed
	var w2: Dictionary = EventSheetLiveValuesPanel.evaluate_watch("health <= 0", {"health": 0})
	all_passed = _check("watch: a boolean condition", bool(w2.get("ok")) and w2.get("value") == true, true) and all_passed
	all_passed = _check("watch: product of a variable", EventSheetLiveValuesPanel.evaluate_watch("score * 2", {"score": 10}).get("value"), 20) and all_passed
	all_passed = _check("watch: a syntax error reports not-ok", bool(EventSheetLiveValuesPanel.evaluate_watch("1 +", {}).get("ok", true)), false) and all_passed
	all_passed = _check("watch: an unknown identifier reports not-ok", bool(EventSheetLiveValuesPanel.evaluate_watch("nope", {"health": 1}).get("ok", true)), false) and all_passed

	# Live event trace (#2): emit_event_trace instruments each event to stream its UID as it fires.
	var trace_sheet: EventSheetResource = EventSheetResource.new()
	trace_sheet.variables = {"hp": {"type": "int", "default": 1}}
	trace_sheet.emit_live_values = true
	trace_sheet.emit_event_trace = true
	var trace_event: EventRow = EventRow.new()
	trace_event.event_uid = "evt_trace_1"
	trace_event.trigger_provider_id = "Core"
	trace_event.trigger_id = "OnReady"
	var trace_action: ACEAction = ACEAction.new()
	trace_action.provider_id = "Core"
	trace_action.ace_id = "X"
	trace_action.codegen_template = "hp += 1"
	trace_event.actions.append(trace_action)
	trace_sheet.events.append(trace_event)
	var trace_output: String = str(SheetCompiler.compile(trace_sheet, "user://eventsheets_trace.gd").get("output", ""))
	all_passed = _check("event trace declares the fired buffer", trace_output.contains("var __eventsheets_fired: PackedStringArray"), true) and all_passed
	all_passed = _check("event trace appends the firing event uid", trace_output.contains("__eventsheets_fired.append(\"evt_trace_1\")"), true) and all_passed
	all_passed = _check("event trace streams + clears the buffer", trace_output.contains("eventsheets:fired_events") and trace_output.contains("__eventsheets_fired.clear()"), true) and all_passed
	var trace_script: GDScript = GDScript.new()
	trace_script.source_code = trace_output
	all_passed = _check("event-trace output parses", trace_script.reload(true) == OK, true) and all_passed
	trace_sheet.emit_event_trace = false
	all_passed = _check("event trace off leaves no instrumentation", str(SheetCompiler.compile(trace_sheet, "user://eventsheets_notrace.gd").get("output", "")).contains("__eventsheets_fired"), false) and all_passed
	all_passed = _check("parse_fired turns the payload into uids", Array(EventSheetLiveValuesDebugger.parse_fired(["a", "b"])), ["a", "b"]) and all_passed

	# Regression: the event trace must work WITHOUT live values (the member + send used to be gated
	# behind emit_live_values, so a trace-only compile was silently dead). Injection path (user _process):
	var trace_only: EventSheetResource = EventSheetResource.new()
	trace_only.emit_event_trace = true  # emit_live_values stays FALSE
	trace_only.host_class = "Node2D"
	var to_event: EventRow = EventRow.new()
	to_event.event_uid = "evt_only_1"
	to_event.trigger_provider_id = "Core"
	to_event.trigger_id = "OnProcess"
	var to_action: ACEAction = ACEAction.new()
	to_action.provider_id = "Core"
	to_action.ace_id = "X"
	to_action.codegen_template = "rotation += delta"
	to_event.actions.append(to_action)
	trace_only.events.append(to_event)
	var to_output: String = str(SheetCompiler.compile(trace_only, "user://eventsheets_traceonly.gd").get("output", ""))
	all_passed = _check("trace-only declares the fired buffer + timer",
		to_output.contains("var __eventsheets_fired: PackedStringArray") and to_output.contains("var __live_values_timer"), true) and all_passed
	all_passed = _check("trace-only appends the firing uid", to_output.contains("__eventsheets_fired.append(\"evt_only_1\")"), true) and all_passed
	all_passed = _check("trace-only streams fired_events but NOT live_values",
		to_output.contains("eventsheets:fired_events") and not to_output.contains("eventsheets:live_values"), true) and all_passed
	all_passed = _check("trace-only emits exactly one _process", to_output.count("func _process") == 1, true) and all_passed
	var to_script: GDScript = GDScript.new()
	to_script.source_code = to_output
	all_passed = _check("trace-only output parses", to_script.reload(true) == OK, true) and all_passed
	# Synthesis path (no user _process): a standalone _process is created for the trace alone.
	var trace_idle: EventSheetResource = EventSheetResource.new()
	trace_idle.emit_event_trace = true
	var ti_event: EventRow = EventRow.new()
	ti_event.event_uid = "evt_idle_1"
	ti_event.trigger_provider_id = "Core"
	ti_event.trigger_id = "OnReady"
	var ti_action: ACEAction = ACEAction.new()
	ti_action.provider_id = "Core"
	ti_action.ace_id = "X"
	ti_action.codegen_template = "pass"
	ti_event.actions.append(ti_action)
	trace_idle.events.append(ti_event)
	var ti_output: String = str(SheetCompiler.compile(trace_idle, "user://eventsheets_traceidle.gd").get("output", ""))
	all_passed = _check("trace-only without a process trigger synthesizes one _process",
		ti_output.contains("func _process(delta: float) -> void:") and ti_output.contains("eventsheets:fired_events") and ti_output.count("func _process") == 1, true) and all_passed
	var ti_script: GDScript = GDScript.new()
	ti_script.source_code = ti_output
	all_passed = _check("trace-only standalone output parses", ti_script.reload(true) == OK, true) and all_passed

	# The viewport highlights events that fired (set_fired_events sets a transient firing flag).
	var fire_viewport: EventSheetViewport = EventSheetViewport.new()
	var fire_sheet: EventSheetResource = EventSheetResource.new()
	var fire_event: EventRow = EventRow.new()
	fire_event.event_uid = "evt_fire_1"
	fire_event.trigger_provider_id = "Core"
	fire_event.trigger_id = "OnReady"
	fire_sheet.events.append(fire_event)
	fire_viewport.set_sheet(fire_sheet)
	fire_viewport.set_fired_events(PackedStringArray(["evt_fire_1"]))
	var fired_flag: bool = false
	for entry: Dictionary in fire_viewport.get_flat_rows():
		var rd: EventRowData = entry.get("row")
		if rd != null and rd.source_resource == fire_event:
			fired_flag = rd.firing
	all_passed = _check("set_fired_events highlights the firing event", fired_flag, true) and all_passed
	fire_viewport.set_fired_events(PackedStringArray())
	var cleared_flag: bool = true
	for entry: Dictionary in fire_viewport.get_flat_rows():
		var rd2: EventRowData = entry.get("row")
		if rd2 != null and rd2.source_resource == fire_event:
			cleared_flag = rd2.firing
	all_passed = _check("clearing fired events un-highlights", cleared_flag, false) and all_passed

	# The pulse: a fire holds intensity 1.0, keeps fading after the flag clears (a flash,
	# not a hard blink), decays over ~0.6s in _process, and vanishes at zero.
	var pulse_after_clear: float = 0.0
	for entry: Dictionary in fire_viewport.get_flat_rows():
		var rd3: EventRowData = entry.get("row")
		if rd3 != null and rd3.source_resource == fire_event:
			pulse_after_clear = rd3.firing_intensity
	all_passed = _check("the pulse keeps fading after the batch clears", pulse_after_clear, 1.0) and all_passed
	fire_viewport._decay_firing(0.3)
	var pulse_mid: float = 0.0
	for entry: Dictionary in fire_viewport.get_flat_rows():
		var rd4: EventRowData = entry.get("row")
		if rd4 != null and rd4.source_resource == fire_event:
			pulse_mid = rd4.firing_intensity
	all_passed = _check("half the fade leaves roughly half the glow", absf(pulse_mid - 0.5) < 0.01, true) and all_passed
	fire_viewport._decay_firing(0.4)
	var pulse_done: float = 1.0
	for entry: Dictionary in fire_viewport.get_flat_rows():
		var rd5: EventRowData = entry.get("row")
		if rd5 != null and rd5.source_resource == fire_event:
			pulse_done = rd5.firing_intensity
	all_passed = _check("the pulse dies at zero", pulse_done, 0.0) and all_passed
	fire_viewport.free()

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] live_values_test: %s" % label)
		return true
	print("[FAIL] live_values_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
