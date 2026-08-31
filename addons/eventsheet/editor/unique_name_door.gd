# Godot EventSheets - the one door that hands a node its %name.
#
# A node reached by path (`$UI/Panel/Bars/HealthBar`) works until somebody moves it, and Godot's own
# answer to that is the scene-unique mark: tick it and the node answers to `%HealthBar` from anywhere
# in the scene. It is one checkbox in the Scene dock, and the moment somebody is in a sheet writing a
# row about that node is exactly the moment they do not want to go and find it.
#
# So both places a node arrives from - the Pick Node dialog, and a drag out of the Scene dock into a
# parameter field - offer the same one-click door, and this is the one place it is implemented.
#
# IT IS A SCENE EDIT, NEVER A SHEET EDIT. The mark lives on the node, so it is applied through the
# EDITOR'S own undo manager and lands in the editor's undo history beside every other scene change -
# Ctrl+Z in the scene puts it back. The sheet's undo funnel is not involved and must not be: a sheet
# edit that quietly changed somebody's scene would be undoable from the wrong window.
#
# WHAT IT REFUSES. The scene root (it needs no handle - it is `self`), a node this scene does not own
# (an instanced scene's insides belong to that scene, and marking one there would not save), a node
# already marked, and a cross-scene search result that is not in the open scene at all. Each refusal
# is silent: the door simply does not appear, which is the honest answer to "there is nothing to do
# here".
@tool
class_name EventSheetUniqueNameDoor
extends RefCounted


## True when the node at `relative_path` can be given the mark: it exists, it is not the scene root
## or a cross-scene entry, this scene owns it, and it is not already marked. Pure given its inputs,
## so the offer is decided the same way in a test as in the editor.
static func can_mark(scene_root: Node, relative_path: String) -> bool:
	if scene_root == null or relative_path.is_empty() or relative_path == "." \
			or relative_path.contains("::"):
		return false
	var node: Node = scene_root.get_node_or_null(NodePath(relative_path))
	return node != null and node != scene_root and node.owner == scene_root \
		and not node.unique_name_in_owner


## Marks the node scene-unique through the EDITOR's undo manager and returns the `%Name` a row should
## now address it by. "" when there was nothing to mark, so a caller writes a reference only when the
## edit actually happened.
static func mark(scene_root: Node, relative_path: String) -> String:
	if not can_mark(scene_root, relative_path):
		return ""
	var node: Node = scene_root.get_node_or_null(NodePath(relative_path))
	if node == null:
		return ""
	var undo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo() \
		if Engine.is_editor_hint() else null
	if undo != null:
		undo.create_action(EventSheetL10n.translate("Mark \"%s\" as scene-unique") % str(node.name))
		undo.add_do_property(node, "unique_name_in_owner", true)
		undo.add_undo_property(node, "unique_name_in_owner", false)
		undo.commit_action()
	else:
		node.unique_name_in_owner = true
	return reference_for(str(node.name))


## The words the door wears, naming the node it is about: "Make %HealthBar unique".
static func offer_text(node_name: String) -> String:
	return EventSheetL10n.translate("Make %s unique") % reference_for(node_name)


## `HealthBar` -> `%HealthBar`. One spelling of the sigil for every caller.
static func reference_for(node_name: String) -> String:
	return EventSheetSceneUniqueNames.SIGIL + node_name.strip_edges()


## The scene path inside a `$Path` / `$"Path/To Node"` reference, or "" for anything that is not one -
## a `%name` (already marked, nothing to offer), an expression, a call, a bare value. This is what
## turns the text sitting in a parameter field back into a node the door can be offered for.
static func path_in_reference(reference: String) -> String:
	var text: String = reference.strip_edges()
	if not text.begins_with("$"):
		return ""
	var path: String = text.substr(1).strip_edges()
	if path.length() >= 2 and path.begins_with("\"") and path.ends_with("\""):
		path = path.substr(1, path.length() - 2)
	if path.is_empty() or path.begins_with("/"):
		return ""
	return path


## The last segment of a scene path - the node's own name, which is what the `%name` will be.
static func node_name_of_path(relative_path: String) -> String:
	var slash_at: int = relative_path.rfind("/")
	return relative_path if slash_at < 0 else relative_path.substr(slash_at + 1)
