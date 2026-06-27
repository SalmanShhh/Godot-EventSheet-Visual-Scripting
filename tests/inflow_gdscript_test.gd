# EventForge — GDScript inside the event flow (event-sheet inline scripting)
#
# In-flow GDScript blocks live in an event's actions: they render line-by-line in the
# action lane, compile indented into the trigger body, double-click opens the code dialog,
# and the lint/completion helper validates against the sheet's context (host class +
# sheet symbols). Headless-safe.
@tool
extends RefCounted
class_name InflowGDScriptTest

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

	# Compile: in-flow block emits inside the trigger body, indented under the condition if.
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "CharacterBody2D"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = "Always"
	event.conditions.append(condition)
	var inline_block: RawCodeRow = RawCodeRow.new()
	inline_block.code = "velocity.x = 0.0\nmove_and_slide()"
	event.actions.append(inline_block)
	sheet.events.append(event)
	var compile_result: Dictionary = SheetCompiler.compile(sheet, "user://eventforge_inflow.gd")
	var output: String = str(compile_result.get("output", ""))
	all_passed = _check("in-flow block compiles inside the condition body",
		output.contains("\t\tvelocity.x = 0.0") and output.contains("\t\tmove_and_slide()"), true) and all_passed
	var raw_mapped: bool = false
	for entry in compile_result.get("source_map", []):
		if entry is Dictionary and str((entry as Dictionary).get("uid", "")) == str(inline_block.get_instance_id()):
			raw_mapped = true
	all_passed = _check("in-flow block has a source-map entry", raw_mapped, true) and all_passed

	var disabled_block: RawCodeRow = RawCodeRow.new()
	disabled_block.code = "print(\"skip me\")"
	disabled_block.enabled = false
	event.actions.append(disabled_block)
	var output_with_disabled: String = str(SheetCompiler.compile(sheet, "user://eventforge_inflow.gd").get("output", ""))
	all_passed = _check("disabled in-flow block is skipped", not output_with_disabled.contains("skip me"), true) and all_passed
	event.actions.remove_at(1)

	# Render: one action-lane cell per code line, sharing the block's ace_index.
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_sheet(sheet)
	var event_index: int = -1
	var flat: Array[Dictionary] = viewport.get_flat_rows()
	for i in range(flat.size()):
		var row_data: EventRowData = flat[i].get("row")
		if row_data != null and row_data.source_resource == event:
			event_index = i
	var event_row_data: EventRowData = flat[event_index].get("row")
	viewport._ensure_event_spans(event_row_data)
	var raw_spans: Array = []
	for span in event_row_data.spans:
		if span != null and span.metadata is Dictionary and bool((span.metadata as Dictionary).get("raw_action", false)):
			raw_spans.append(span)
	all_passed = _check("in-flow block renders one cell per code line", raw_spans.size(), 2) and all_passed
	all_passed = _check("block lines share one ace_index (move/delete as one action)",
		raw_spans.size() == 2
			and int((raw_spans[0].metadata as Dictionary).get("ace_index", -1)) == 0
			and int((raw_spans[1].metadata as Dictionary).get("ace_index", -1)) == 0, true) and all_passed
	all_passed = _check("line count accounts for the block's lines", viewport._count_event_lines(event) >= 3, true) and all_passed

	# Double-clicking a block cell routes to the code dialog with in_flow = true.
	var captured: Dictionary = {"raw": null, "in_flow": false}
	viewport.raw_code_edit_requested.connect(func(raw_resource: Resource, in_flow: bool) -> void:
		captured["raw"] = raw_resource
		captured["in_flow"] = in_flow
	)
	viewport._get_or_build_row_layout(event_index, viewport.get_canvas_logical_width(), viewport._get_font(), viewport._get_font_size())
	var cell_center: Vector2 = (raw_spans[0] as SemanticSpan).rect.get_center()
	viewport._handle_mouse_button(_button(cell_center, true, false))
	viewport._handle_mouse_button(_button(cell_center, false, false))
	viewport._handle_mouse_button(_button(cell_center, true, true))
	all_passed = _check("double-click opens the block (in_flow)", captured["raw"] == inline_block and bool(captured["in_flow"]), true) and all_passed
	viewport.free()

	# Lint: valid statements pass against host class + sheet symbols; syntax errors fail.
	sheet.variables = {"health": {"type": "int", "default": 100}}
	var lint_ok: Dictionary = EventSheetGDScriptLint.lint("health += 5\nmove_and_slide()", true, sheet)
	all_passed = _check("lint accepts sheet-var + host-member statements", bool(lint_ok.get("ok", false)), true) and all_passed
	var lint_bad: Dictionary = EventSheetGDScriptLint.lint("func (", true, sheet)
	all_passed = _check("lint rejects broken code", bool(lint_bad.get("ok", true)), false) and all_passed
	var lint_class_level: Dictionary = EventSheetGDScriptLint.lint("func helper() -> int:\n\treturn 1", false, sheet)
	all_passed = _check("lint accepts class-level blocks", bool(lint_class_level.get("ok", false)), true) and all_passed

	# Completion candidates include sheet symbols and host members.
	var labels: Array[String] = []
	for candidate in EventSheetGDScriptLint.completion_candidates(sheet):
		labels.append(str(candidate.get("label", "")))
	all_passed = _check("completion offers sheet variables", labels.has("health"), true) and all_passed
	all_passed = _check("completion offers host-class members", labels.has("move_and_slide"), true) and all_passed

	# Context menu appends a block to the event's actions.
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(sheet)
	editor.set_undo_redo_manager(NoopUndoManager.new())
	var editor_viewport: EventSheetViewport = editor.get_viewport_control()
	for entry in editor_viewport.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data != null and row_data.source_resource == event:
			editor._context_row = row_data
	var actions_before: int = event.actions.size()
	editor._add_gdscript_action_to_context_row()
	all_passed = _check("context menu adds a GDScript action",
		event.actions.size() == actions_before + 1 and event.actions[event.actions.size() - 1] is RawCodeRow, true) and all_passed
	editor.free()

	return all_passed

static func _button(at: Vector2, pressed: bool, double_click: bool) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.double_click = double_click
	event.position = at
	return event

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] inflow_gdscript_test: %s" % label)
		return true
	print("[FAIL] inflow_gdscript_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
