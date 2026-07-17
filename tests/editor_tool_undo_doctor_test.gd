# Godot EventSheets - the Doctor's "editor tool without undo" check. A tool_mode sheet whose
# compiled script mutates the OPEN scene (add/remove/reparent through get_edited_scene_root())
# without registering undo (create_action / EditorUndoRedoManager) gets an info nudge - the
# classic first-editor-tool mistake where Ctrl+Z can't take the change back. Read-only tools,
# undo-registering tools, and non-tool sheets are left alone. Mirrors save_support_doctor_test:
# build a fixture, compile it to its output, run the single check, assert the finding.
@tool
class_name EditorToolUndoDoctorTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true

	# A tool that adds nodes to the edited scene with no undo registration is nudged.
	all_passed = _check("a scene-mutating tool without undo is flagged",
		_message_for(_tool_sheet("var root: Node = EditorInterface.get_edited_scene_root()\nvar marker: Node2D = Node2D.new()\nroot.add_child(marker)\nmarker.owner = root"), "etu_bare").contains("without registering undo"), true) and all_passed

	# The same mutation wrapped in create_action/commit_action passes clean.
	all_passed = _check("a tool that registers undo is not flagged",
		_message_for(_tool_sheet("var undo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()\nundo.create_action(\"Add Marker\")\nvar root: Node = EditorInterface.get_edited_scene_root()\nvar marker: Node2D = Node2D.new()\nundo.add_do_method(root, \"add_child\", marker)\nundo.commit_action()"), "etu_undo").is_empty(), true) and all_passed

	# A read-only tool (prints a report, mutates nothing) is not nudged.
	all_passed = _check("a read-only tool is not flagged",
		_message_for(_tool_sheet("var root: Node = EditorInterface.get_edited_scene_root()\nif root != null:\n\tprint(root.get_child_count())"), "etu_read").is_empty(), true) and all_passed

	# A non-tool behavior that adds children at runtime is none of this check's business.
	var runtime_sheet: EventSheetResource = _tool_sheet("var child: Node2D = Node2D.new()\nadd_child(child)")
	runtime_sheet.tool_mode = false
	all_passed = _check("a non-tool sheet is skipped",
		_message_for(runtime_sheet, "etu_game").is_empty(), true) and all_passed

	return all_passed


## An editor-tool sheet whose On Editor Run body is the given code block.
static func _tool_sheet(body: String) -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "EditorScript"
	sheet.tool_mode = true
	var run_event: EventRow = EventRow.new()
	run_event.trigger_provider_id = "Core"
	run_event.trigger_id = "OnEditorRun"
	var chore: RawCodeRow = RawCodeRow.new()
	chore.code = body
	run_event.actions.append(chore)
	sheet.events.append(run_event)
	return sheet


## Saves the fixture, compiles it to its output path, runs the single check, and returns
## the editor-tool-undo finding's message ("" when there is none). Cleans up both files.
static func _message_for(sheet: EventSheetResource, name: String) -> String:
	var path: String = "user://%s.tres" % name
	ResourceSaver.save(sheet, path)
	var output_path: String = EventSheetProjectDoctor.output_path_for(path)
	SheetCompiler.compile(sheet, output_path)
	var findings: Array[Dictionary] = []
	EventSheetProjectDoctor.check_editor_tool_undo(PackedStringArray([path]), findings)
	var message: String = ""
	for finding: Dictionary in findings:
		if str(finding.get("check")) == "editor-tool-undo":
			message = str(finding.get("message"))
	DirAccess.remove_absolute(path)
	if FileAccess.file_exists(output_path):
		DirAccess.remove_absolute(output_path)
	return message


static func _check(label: String, actual: bool, expected: bool) -> bool:
	if actual != expected:
		print("  [FAIL] %s (got %s)" % [label, actual])
		return false
	return true
