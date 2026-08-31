@tool
class_name EventSheetCommentDoorOpen
extends RefCounted

# WHERE A DOOR IN A COMMENT LEADS - the dock half of the doors.
#
# `EventSheetCommentDoors` decides WHICH words are doors, purely and headlessly, out of the indexes
# the completion seam already holds. This decides what happens when one is clicked, which is the
# half that needs the dock: opening a sheet, revealing a declaration, selecting a node.
#
# THREE OF THE FIVE KINDS ALREADY HAD A DOOR. A state, a mode and a function are exactly what the
# Quick Add field's answers open, and its ladder is the tested one - the declaration in the live
# sheet, else the sheet it lives in, else the status line saying plainly what could not be reached.
# So those three are handed to it as answers rather than re-implemented here, and a state opened
# from a comment and a state opened from the ask arrive in the same place by construction. Only the
# two kinds the ask never produces - a node of the scene and a sheet file - are opened here.
#
# NOTHING IS HELD. A door carries a NAME, never a resource: the undo funnel replaces every row
# object in the sheet on every edit, and the thing a door names is looked up in the live sheet (or
# the live scene) at the moment it is clicked.

var _dock: Control = null


func init(dock: Control) -> void:
	_dock = dock


## Goes where a clicked door points. Every branch either arrives somewhere or says on the status
## line what it could not reach - a door that silently does nothing is the one outcome this may not
## have, because the underline promised the jump.
func open(door: Dictionary) -> void:
	var target: String = str(door.get("target", ""))
	match str(door.get("kind", "")):
		EventSheetCommentDoors.KIND_NODE:
			_open_node(target)
		EventSheetCommentDoors.KIND_SHEET:
			_open_sheet(target)
		EventSheetCommentDoors.KIND_STATE:
			_dock._ask_field.open_answer(_answer(EventSheetCompletions.KIND_STATE, target,
				EventSheetStateFacts.word_for(target)))
		EventSheetCommentDoors.KIND_MODE:
			_dock._ask_field.open_answer(_answer(EventSheetCompletions.KIND_MODE, target,
				EventSheetModeFacts.word_for(target)))
		EventSheetCommentDoors.KIND_FUNCTION:
			_dock._ask_field.open_answer(_answer(EventSheetCompletions.KIND_FUNCTION, target, target))


## One door as the ask field's own answer shape: the name to find, the sheet to find it in (this
## one - a comment names what its own sheet can see), and the word to say if it has moved.
func _answer(kind: String, symbol: String, text: String) -> Dictionary:
	return {
		"kind": kind,
		"text": text,
		"symbol": symbol,
		"path": _dock._current_sheet_path,
		"home": EventSheetAskAnswers.home_of(_dock._current_sheet_path, _dock._current_sheet),
	}


## A node of the scene: selected in the Scene dock, which is where a node is looked at and edited.
## Both spellings a comment writes one in are the spellings the scene index holds - `$Path` from the
## root, `%Name` for a uniquely named node - so the sigil says which lookup to make.
func _open_node(reference: String) -> void:
	var scene_root: Node = EditorInterface.get_edited_scene_root() if Engine.is_editor_hint() else null
	var found: Node = null
	if scene_root != null:
		found = scene_root.get_node_or_null(NodePath(reference.substr(1)) if reference.begins_with("$") else NodePath(reference))
	if found == null:
		_dock._set_status(EventSheetL10n.translate("%s is not in the scene that is open.") % reference, true)
		return
	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(found)


## A sheet file named in a note: opened as a sheet, the same way every other door into another sheet
## opens one, with the current place recorded so Back comes home.
func _open_sheet(path: String) -> void:
	if path.is_empty() or not FileAccess.file_exists(path):
		_dock._set_status(EventSheetL10n.translate("%s is no longer in the project.") % path.get_file(), true)
		return
	_dock._navigate.record_current()
	_dock._navigate.open_or_focus(path)
