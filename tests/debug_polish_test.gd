# Godot EventSheets - Debug & polish: breakpoint UX wiring, Find & Replace, shader/
# date/platform vocabulary.
@tool
class_name DebugPolishTest
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

	# F9 persists onto the model; the toolbar toggle flips the sheet's debug compile.
	var sheet: EventSheetResource = EventSheetResource.new()
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	sheet.events.append(event)
	var comment: CommentRow = CommentRow.new()
	comment.text = "old_name notes"
	sheet.events.append(comment)
	var block: RawCodeRow = RawCodeRow.new()
	block.code = "old_name += 1"
	event.actions.append(block)
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(sheet)
	editor.set_undo_redo_manager(NoopUndoManager.new())
	var viewport: EventSheetViewport = editor.get_viewport_control()
	viewport._toggle_breakpoint(0)
	all_passed = _check("F9 persists onto the event resource", event.debug_break, true) and all_passed
	viewport._toggle_breakpoint(0)
	all_passed = _check("F9 toggles back off", event.debug_break, false) and all_passed
	editor._toggle_breakpoint_emission()
	all_passed = _check("Debug BP toggle flips the sheet flag", sheet.emit_breakpoints, true) and all_passed
	editor._toggle_breakpoint_emission()

	# Find & Replace across comments, blocks, and params.
	var ace: ACEAction = ACEAction.new()
	ace.provider_id = "Core"
	ace.ace_id = "X"
	ace.codegen_template = "set({v})"
	ace.params = {"v": "old_name + 1"}
	event.actions.append(ace)
	editor._refresh_after_edit()
	editor._ensure_find_bar()
	editor._find_edit.text = "old_name"
	editor._replace_edit.text = "new_name"
	editor._replace_all_in_sheet()
	all_passed = _check("replace hits comments", comment.text, "new_name notes") and all_passed
	all_passed = _check("replace hits GDScript blocks", block.code, "new_name += 1") and all_passed
	all_passed = _check("replace hits string params", str(ace.params.get("v")), "new_name + 1") and all_passed
	editor.free()

	# New vocabulary registered + compiles.
	var by_id: Dictionary = {}
	for descriptor in EventForgeBuiltinACEs.get_descriptors():
		by_id[descriptor.ace_id] = descriptor
	all_passed = _check("shader/date/platform registered",
		by_id.has("SetShaderParameter") and by_id.has("GetDatetimeString") and by_id.has("GetUnixTime") and by_id.has("GetOSName") and by_id.has("HasOSFeature"), true) and all_passed
	all_passed = _check("platform feature is a dropdown",
		((by_id["HasOSFeature"].params[0] as ACEParam).options as Array).size() >= 6, true) and all_passed
	all_passed = _check("shader template uses the StringName idiom",
		str(by_id["SetShaderParameter"].codegen_template).contains("material.set_shader_parameter(&{param}, {value})"), true) and all_passed

	# Stage 3: ACE comments + starter templates.
	var note_editor: EventSheetEditor = EventSheetEditor.new()
	note_editor.setup(EventSheetResource.new())
	note_editor.set_undo_redo_manager(NoopUndoManager.new())
	var noted: ACECondition = ACECondition.new()
	noted.provider_id = "Core"
	noted.ace_id = "Always"
	noted.codegen_template = "true"
	noted.comment = "guards the tutorial"
	all_passed = _check("ACE comments render dimmed after the text",
		note_editor.get_viewport_control()._format_condition_descriptor(noted).contains("⊳ guards the tutorial"), true) and all_passed
	note_editor._starter._new_sheet_from_template(1)
	var template_sheet: EventSheetResource = note_editor._current_sheet
	var template_events: int = 0
	for row in template_sheet.events:
		if row is EventRow:
			template_events += 1
	all_passed = _check("platformer template builds events", template_events >= 2, true) and all_passed
	all_passed = _check("template adopts as unsaved", note_editor._current_sheet_path, "") and all_passed
	var template_output: String = str(SheetCompiler.compile(template_sheet, "user://eventsheets_template.gd").get("output", ""))
	var template_script: GDScript = GDScript.new()
	template_script.source_code = template_output
	all_passed = _check("template compiles + parses", template_script.reload(true) == OK, true) and all_passed
	note_editor.free()

	# Conditional breakpoint (#5 visual debugging): a guarded `if <cond>: breakpoint`.
	var bp_sheet: EventSheetResource = EventSheetResource.new()
	bp_sheet.emit_breakpoints = true
	bp_sheet.variables = {"health": {"type": "int", "default": 100}}
	var bp_event: EventRow = EventRow.new()
	bp_event.trigger_provider_id = "Core"
	bp_event.trigger_id = "OnReady"
	bp_event.debug_break = true
	bp_event.debug_break_condition = "health <= 0"
	var bp_action: RawCodeRow = RawCodeRow.new()
	bp_action.code = "pass"
	bp_event.actions.append(bp_action)
	bp_sheet.events.append(bp_event)
	var bp_output: String = str(SheetCompiler.compile(bp_sheet, "user://eventsheets_bp.gd").get("output", ""))
	all_passed = _check("conditional breakpoint emits an if-guard", bp_output.contains("if health <= 0:"), true) and all_passed
	all_passed = _check("conditional breakpoint still emits breakpoint", bp_output.contains("breakpoint"), true) and all_passed
	var bp_script: GDScript = GDScript.new()
	bp_script.source_code = bp_output
	all_passed = _check("conditional breakpoint compiles + parses", bp_script.reload(true) == OK, true) and all_passed
	# A blank condition falls back to a bare (unguarded) breakpoint.
	bp_event.debug_break_condition = ""
	var bare_output: String = str(SheetCompiler.compile(bp_sheet, "user://eventsheets_bp2.gd").get("output", ""))
	all_passed = _check("blank condition emits a bare breakpoint (no guard)", bare_output.contains("if health <= 0:"), false) and all_passed

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] debug_polish_test: %s" % label)
		return true
	print("[FAIL] debug_polish_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
