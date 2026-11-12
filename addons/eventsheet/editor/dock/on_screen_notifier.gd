@tool
class_name EventSheetOnScreenNotifier
extends RefCounted

# "Is On Screen" asks Godot's own VisibleOnScreenNotifier2D whether the node is in view. The row works
# from the moment it is added, so adding it also adds the notifier under the node in the scene, in the
# same undo step as the scene's own history, where it can be seen, moved and resized. Nothing is
# created while the game runs by this path: the notifier is already there.

const ACE_ID: String = "RenderingIsOnScreen"
const NODE_PARAM: String = "node"
const NOTIFIER_CLASS: String = "VisibleOnScreenNotifier2D"


## The node the row asks about, in the open scene: `self` (or nothing) is the node that runs the sheet,
## `$Path` is that path from it. Null when the scene does not run the sheet or the path leads nowhere.
static func target_of(host: Node, node_text: String) -> Node:
	if host == null:
		return null
	var text: String = node_text.strip_edges()
	if text.is_empty() or text == "self":
		return host
	if text.begins_with("$"):
		return host.get_node_or_null(NodePath(text.trim_prefix("$").trim_prefix("\"").trim_suffix("\"")))
	return null


## The target when it is a 2D node that has no notifier yet; null when there is nothing to add.
static func needs_notifier(host: Node, node_text: String) -> Node:
	var target: Node = target_of(host, node_text)
	if not (target is CanvasItem):
		return null
	for child: Node in target.get_children():
		if child is VisibleOnScreenNotifier2D:
			return null
	return target


## Adds the notifier under `target` through the editor's own undo (one step, owner set so it is saved
## with the scene). Returns the new node, or null when no editor is there to do it.
static func add_under(target: Node, scene_root: Node) -> Node:
	if target == null or scene_root == null:
		return null
	var notifier: VisibleOnScreenNotifier2D = VisibleOnScreenNotifier2D.new()
	notifier.name = NOTIFIER_CLASS
	var owner_node: Node = target.owner if target.owner != null else scene_root
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		var undo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
		undo.create_action("Add %s" % NOTIFIER_CLASS, UndoRedo.MERGE_DISABLE, target)
		undo.add_do_method(target, "add_child", notifier)
		undo.add_do_property(notifier, "owner", owner_node)
		undo.add_do_reference(notifier)
		undo.add_undo_method(target, "remove_child", notifier)
		undo.commit_action()
		EditorInterface.mark_scene_as_unsaved()
	else:
		target.add_child(notifier)
		notifier.owner = owner_node
	return notifier
