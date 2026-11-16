# Godot EventSheets - a tool sheet's Building rows change the open scene outside Ctrl+Z, and say so.
#
# Add New Node and its siblings, and Remove What This Sheet Built, add and free nodes in the scene the
# editor has open when they sit in a Tool sheet. They reach that scene through the tree's own edited
# root rather than through the editor interface, so the quiet finding about edits the editor cannot
# take back used to read the sheet as one that never touches the open scene and said nothing. It now
# asks the same question of these rows: one note per kind of change, naming the undoable row that
# makes the same change as a step Ctrl+Z takes back, with no button (the rows take different values,
# so there is no respelling that loses nothing). The same rows in a game sheet earn nothing, and so
# does a Tool sheet that never builds.
@tool
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const BUILDING := preload("res://addons/eventforge/registration/modules/building_aces.gd")
const P := "tool_building_rows_not_undoable_test"


static func run() -> bool:
	var ok: bool = true
	var building: EventSheetResource = _sheet([_row("AddNewNodeInto", {"type": "Node2D", "label": "", "parent": BUILDING.TOOL_PARENT, "name": "fence"})], true)
	var found: Array[Dictionary] = EventSheetUndoableFindings.findings(building)
	ok = SUPPORT.check(P, "a Tool sheet that builds a node earns one note", found.size(), 1) and ok
	if found.size() == 1:
		var note: Dictionary = found[0]
		ok = SUPPORT.pins(P + ": the note", [
			["it is the not-undoable finding", str(note.get("kind", "")), EventSheetUndoableFindings.KIND_NOT_UNDOABLE],
			["it sits on the row that builds", int(note.get("index", -1)), 0],
			["it says what to reach for instead", str(note.get("message", "")).contains("Add Node (Undoable)"), true],
			["it is two short sentences, with no file name and no baked variable", str(note.get("message", "")),
				"This row adds a node to your scene, but Ctrl+Z will not take it back. Use Add Node (Undoable) to make it one step you can undo."],
			["it offers no button, because there is no twin that loses nothing", str(note.get("fix", "")), ""],
			["the line it quotes is the line the row writes, with no template markers", [str(note.get("subject", "")).contains("{"), str(note.get("subject", ""))], [false, "__scene_t1.add_child(fence, true)"]],
		]) and ok
	var clearing: EventSheetResource = _sheet([_row("RemoveBuiltNodes", {"parent": BUILDING.TOOL_PARENT})], true)
	var cleared: Array[Dictionary] = EventSheetUndoableFindings.findings(clearing)
	ok = SUPPORT.check(P, "Remove What This Sheet Built earns one note too", cleared.size(), 1) and ok
	if cleared.size() == 1:
		ok = SUPPORT.check(P, "which names the undoable removal", str(cleared[0].get("message", "")).contains("Remove Node (Undoable)"), true) and ok
	var game: EventSheetResource = _sheet([_row("AddNewNodeInto", {"type": "Node2D", "label": "", "parent": "get_tree().current_scene", "name": "fence"})], false)
	ok = SUPPORT.check(P, "the same row in a game sheet earns nothing", EventSheetUndoableFindings.findings(game).size(), 0) and ok
	var quiet: EventSheetResource = _sheet([_row("Print", {"message": "\"hi\""})], true)
	ok = SUPPORT.check(P, "a Tool sheet that builds nothing earns nothing", EventSheetUndoableFindings.findings(quiet).size(), 0) and ok
	var through_history: EventSheetResource = _sheet([_row("AddNodeUndoable", {"node": "Node2D.new()", "parent": "EditorInterface.get_edited_scene_root()"})], true)
	ok = SUPPORT.check(P, "the undoable row itself earns nothing", EventSheetUndoableFindings.findings(through_history).size(), 0) and ok
	var reported: Array[Dictionary] = EventSheetToolEditsDoctor.script_findings("res://tools/build.gd", found)
	ok = SUPPORT.check(P, "the Doctor files the same sentence as a warning",
		[reported.size(), str(reported[0].get("severity", "")) if reported.size() > 0 else ""], [1, "warning"]) and ok
	ok = SUPPORT.check(P, "a script that builds in the open scene is one the Doctor opens",
		EventForgeUndoableEdits.touches_open_scene("@tool\nextends Node\nfunc _run() -> void:\n\tvar n := Node.new()\n\tget_tree().edited_scene_root.add_child(n)\n"), true) and ok
	return ok


static func _row(ace_id: String, params: Dictionary) -> ACEAction:
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", ace_id)
	var action := ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = params
	var template: String = descriptor.codegen_template
	# What the dock keeps when a row is dropped into a Tool sheet.
	if BUILDING.is_tool_aware(ace_id, template):
		template = BUILDING.tool_form(template)
	action.codegen_template = template.replace("{uid}", "t1")
	return action


static func _sheet(rows: Array, tool_mode: bool) -> EventSheetResource:
	var event := EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnEditorRun"
	event.event_uid = "e1"
	for row: ACEAction in rows:
		event.actions.append(row)
	var sheet := EventSheetResource.new()
	sheet.tool_mode = tool_mode
	sheet.host_class = "Node"
	sheet.events.append(event)
	return sheet
