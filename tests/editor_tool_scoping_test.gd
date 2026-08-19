@tool
class_name EditorToolScopingTest
extends RefCounted

# Pins the three gates that keep the Editor object honest (R32 / R33 / R35):
#   1. the picker offers the Editor object on a @tool sheet and nowhere else - its rows call
#      EditorInterface, which does not exist in a running game;
#   2. a per-frame event on a @tool sheet says so, because "@tool means this is already running while
#      you edit" is the fact that surprises everyone exactly once;
#   3. the Doctor names the three mistakes a first editor tool makes - reaching outside the open
#      layout, destroying while editing, and ticking in the editor with no way to switch it off.


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _the_editor_object_is_scoped_to_tool_sheets() and all_passed
	all_passed = _a_tool_tick_says_it_runs_in_the_editor() and all_passed
	all_passed = _the_doctor_names_the_first_tool_mistakes() and all_passed
	return all_passed


static func _the_editor_object_is_scoped_to_tool_sheets() -> bool:
	var ok: bool = true
	ok = _check("the Editor object is hidden off a game sheet",
		ACEPickerDialog.editor_ace_hidden("Editor Tools", false), true) and ok
	ok = _check("the Editor object is offered on a tool sheet",
		ACEPickerDialog.editor_ace_hidden("Editor Tools", true), false) and ok
	ok = _check("every other category is untouched",
		ACEPickerDialog.editor_ace_hidden("Movement", false), false) and ok
	return ok


static func _a_tool_tick_says_it_runs_in_the_editor() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.tool_mode = true
	sheet.read_only = true
	var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
	style.ensure_defaults()
	sheet.editor_style = style
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnProcess"
	sheet.events.append(tick)
	ok = _check("a tool sheet's every-tick event wears the editor chip",
		_reads(sheet).contains("in the editor too"), true) and ok
	sheet.tool_mode = false
	ok = _check("a game sheet's every-tick event does not",
		_reads(sheet).contains("in the editor too"), false) and ok
	return ok


static func _the_doctor_names_the_first_tool_mistakes() -> bool:
	var ok: bool = true
	ok = _check("reaching outside the open layout is named",
		_checks_for("var found = get_tree().get_nodes_in_group(\"markers\")", "ets_scope").has("editor-tool-scope"), true) and ok
	ok = _check("destroying while editing is named",
		_checks_for("var root: Node = EditorInterface.get_edited_scene_root()\nroot.get_child(0).queue_free()", "ets_kill").has("editor-tool-destroy"), true) and ok
	ok = _check("a destroy wrapped in an undo action is left alone",
		_checks_for("var ur = get_undo_redo()\nur.create_action(\"Clear\")\nself.queue_free()\nur.commit_action()", "ets_undo").has("editor-tool-destroy"), false) and ok
	ok = _check("a read-only tool is named for none of them",
		_checks_for("print(\"hello\")", "ets_quiet").is_empty(), true) and ok
	return ok


## The finding ids the two editor-tool checks raise for a tool sheet whose On Editor Run body is the
## given code. Cleans up both files it writes.
static func _checks_for(body: String, name: String) -> PackedStringArray:
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
	var path: String = "user://%s.tres" % name
	ResourceSaver.save(sheet, path)
	var output_path: String = EventSheetProjectDoctor.output_path_for(path)
	SheetCompiler.compile(sheet, output_path)
	var findings: Array[Dictionary] = []
	EventSheetProjectDoctor.check_editor_tool_safety(PackedStringArray([path]), findings)
	var ids: PackedStringArray = PackedStringArray()
	for finding: Dictionary in findings:
		ids.append(str(finding.get("check", "")))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(output_path))
	return ids


## Every span's text on one sheet's rows, joined - enough to ask whether a chip is drawn.
static func _reads(sheet: EventSheetResource) -> String:
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_ace_registry(EventSheetACERegistry.new())
	viewport.set_sheet(sheet)
	viewport.set_reading_mode(true)
	var text: String = ""
	for row_data: EventRowData in viewport._root_rows:
		viewport._row_builder._ensure_event_spans(row_data)
		for span: SemanticSpan in row_data.spans:
			text += span.text + "\n"
	viewport.free()
	return text


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] editor tool scoping: %s" % label)
		return true
	print("[FAIL] editor tool scoping: %s - expected %s, got %s" % [label, str(expected), str(actual)])
	return false
