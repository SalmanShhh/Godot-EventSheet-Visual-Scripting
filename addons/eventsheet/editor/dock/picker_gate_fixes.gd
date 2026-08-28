@tool
class_name EventSheetPickerGateFixes
extends RefCounted

# The dock's half of the picker's gates: performing the FIX a greyed entry offered, then carrying
# on to the row the reader wanted (see EventSheetPickerGates for the gates themselves).
#
# Each fix is one gesture the editor already has - a node added through the editor's own undo, the
# Sheet Type dialog opened on the setting that answers the gate - so pressing the fix button never
# does anything a reader could not have done by hand, it just does it from where they already are.
# After a fix that leaves the entry usable, the ordinary picker-selected path runs, so the params
# dialog opens exactly as if nothing had ever been in the way.

var _dock: Control = null


func init(dock: Control) -> void:
	_dock = dock


## One gate fix, dispatched on the gate's fix_id. Anything unrecognised says so on the status line
## rather than failing silently.
func apply(gate: Dictionary, definition: ACEDefinition, context: Dictionary) -> void:
	match str(gate.get("fix_id", "")):
		"add_node":
			_add_node(str(gate.get("node_type", "")), definition, context)
		"enable_tool":
			_enable_tool(definition, context)
		"open_sheet_kind":
			_open_sheet_kind()
		"attach_scene":
			_attach_scene()
		_:
			_dock._set_status(EventSheetL10n.translate("This entry's fix (%s) is not wired yet.")
				% str(gate.get("fix_id", "")), true)


## Adds the missing node to the open scene through the EDITOR'S own undo (a scene edit belongs to
## the scene's history, not the sheet's), then carries on to the row's parameters dialog.
func _add_node(node_type: String, definition: ACEDefinition, context: Dictionary) -> void:
	if node_type.is_empty() or not ClassDB.class_exists(node_type) or not ClassDB.can_instantiate(node_type):
		_dock._set_status(EventSheetL10n.translate("Can't add a %s here - add the node by hand in the Scene dock.")
			% node_type, true)
		return
	var scene_root: Node = EditorInterface.get_edited_scene_root() if Engine.is_editor_hint() else null
	if scene_root == null:
		_dock._set_status(EventSheetL10n.translate("Open the scene this sheet drives, then this entry can add the %s for you.")
			% node_type, true)
		return
	var node: Node = ClassDB.instantiate(node_type)
	node.name = node_type
	var undo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	if undo != null:
		undo.create_action("Add %s" % node_type)
		undo.add_do_method(scene_root, "add_child", node)
		undo.add_do_property(node, "owner", scene_root)
		undo.add_do_reference(node)
		undo.add_undo_method(scene_root, "remove_child", node)
		undo.commit_action()
	else:
		scene_root.add_child(node)
		node.owner = scene_root
	_dock._set_status(EventSheetL10n.translate("Added a %s to %s - Ctrl+Z takes it back.")
		% [node_type, scene_root.name], false)
	_dock._on_ace_picker_selected(definition, context)


## Switches Tool on for the open sheet through the sheet's own undo funnel, then carries on to the
## row - the Editor object's verbs are usable the moment the flag is.
func _enable_tool(definition: ACEDefinition, context: Dictionary) -> void:
	var sheet: EventSheetResource = _dock._current_sheet
	if sheet == null:
		_dock._set_status(EventSheetL10n.translate("Open a sheet first - Tool is a per-sheet setting."), true)
		return
	var changed: bool = bool(_dock._perform_undoable_sheet_edit("Switch Tool on", func() -> bool:
		_dock._current_sheet.tool_mode = true
		return true))
	if not changed:
		return
	_dock._mark_dirty(EventSheetL10n.translate("Tool is on - this sheet's rows can run inside the editor now."))
	_dock._on_ace_picker_selected(definition, context)


## The behavior-host verbs want a behavior sheet, which is a Sheet Type choice with its own
## consequences - so the fix opens that dialog rather than flipping the switch behind the
## reader's back.
func _open_sheet_kind() -> void:
	_dock._open_sheet_type_dialog()
	_dock._set_status(EventSheetL10n.translate("Pick Behavior here and the host verbs come off grey."), false)


## A sheet no scene carries can attach to the OPEN scene's root in one step, through the editor's
## own undo. With no scene open, the one honest answer is to say what attaching means.
func _attach_scene() -> void:
	var sheet: EventSheetResource = _dock._current_sheet
	var script_path: String = str(sheet.external_source_path).strip_edges() if sheet != null else ""
	var scene_root: Node = EditorInterface.get_edited_scene_root() if Engine.is_editor_hint() else null
	if script_path.is_empty() or scene_root == null:
		_dock._set_status(EventSheetL10n.translate("Attach this sheet's script to a node of your scene (select the node, then the Attach Script button) and its triggers have a source."), true)
		return
	if scene_root.get_script() != null:
		_dock._set_status(EventSheetL10n.translate("%s already has a script - attach %s to a child node instead, from the Scene dock.")
			% [str(scene_root.name), script_path.get_file()], true)
		return
	var script: Script = load(script_path)
	if script == null:
		_dock._set_status(EventSheetL10n.translate("Couldn't load %s to attach it.") % script_path.get_file(), true)
		return
	var undo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	if undo != null:
		undo.create_action("Attach %s" % script_path.get_file())
		undo.add_do_property(scene_root, "script", script)
		undo.add_undo_property(scene_root, "script", null)
		undo.commit_action()
	else:
		scene_root.set_script(script)
	_dock._set_status(EventSheetL10n.translate("Attached %s to %s - its triggers listen to this scene now.")
		% [script_path.get_file(), str(scene_root.name)], false)
