# Godot EventSheets — Live Values v1 (debugging rung 2): debug compiles stream sheet
# variables over EngineDebugger; the editor's Live Values window shows them. Normal
# compiles never carry the stream (covenant intact).
@tool
extends RefCounted
class_name LiveValuesTest

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
		on_output.contains("EngineDebugger.send_message(\"eventsheets:live_values\", [\"hp\", hp])")
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

	# (EditorDebuggerPlugin isn't instantiable headless — send_set_value's no-session
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
	# conditions re-bake their member uid — copies own their own accumulator.
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

	return all_passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] live_values_test: %s" % label)
		return true
	print("[FAIL] live_values_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
