# Godot EventSheets - the one door that draws a node's children as one picture.
#
# A node with several sprites under it draws each of them on its own, so fading the parent fades
# every child separately and the places where they OVERLAP go on showing through each other: a
# character made of six pieces vanishes like a paper cut-out instead of like a character. Godot's own
# answer is CanvasGroup - it draws its children into one picture first and puts that on the screen -
# and it is a node you have to know exists, add by hand, and move every child under.
#
# The Blend As One row does it at run time, which is the right answer for something that happens
# during a game. But a reader who is looking at the node in the scene and wants it drawn that way
# ALWAYS does not want a row at all: they want the scene to say so. That is this door, offered on the
# row's own node field, and it is the same shape as the "%name" one beside it.
#
# IT IS A SCENE EDIT, NEVER A SHEET EDIT. The group lives in the scene, so it is applied through the
# EDITOR'S own undo manager and lands in the editor's undo history beside every other scene change -
# Ctrl+Z in the scene puts the children back. The sheet's undo funnel is not involved and must not
# be: a sheet edit that quietly changed somebody's scene would be undoable from the wrong window.
#
# WHAT IT REFUSES, silently, because a door with nothing to do should not appear: a node this scene
# does not own, a node that IS already a CanvasGroup (it already draws its children as one), a node
# that already has one of these groups under it, and a node with fewer than two canvas children -
# one child cannot overlap itself, so there is nothing for a group to fix.
@tool
class_name EventSheetCanvasGroupDoor
extends RefCounted

## What the group is called, in the scene and at run time alike, so the two answers to the same
## question look the same wherever a reader meets one.
const GROUP_NAME := "BlendedAsOne"

## The parameter hint that asks for this door. A row whose node field wears it is a row about drawing
## a node's children together, which is the one question the door answers.
const HINT := "blend_group_target"


## True when the node at `relative_path` has children worth grouping and can be given the group.
## Pure given its inputs, so the offer is decided the same way in a test as in the editor.
static func can_group(scene_root: Node, relative_path: String) -> bool:
	if scene_root == null or relative_path.contains("::"):
		return false
	var node: Node = scene_root if relative_path.is_empty() or relative_path == "." \
		else scene_root.get_node_or_null(NodePath(relative_path))
	if node == null or node is CanvasGroup or not (node is CanvasItem):
		return false
	if node != scene_root and node.owner != scene_root:
		return false
	return groupable_children(node).size() >= 2


## The children a group would take: the ones that DRAW. A timer, an audio player or a collision shape
## under the same node is not part of the picture and is left exactly where it is, because moving it
## would change what its own node paths mean for nothing.
static func groupable_children(node: Node) -> Array[Node]:
	var found: Array[Node] = []
	if node == null:
		return found
	for child: Node in node.get_children():
		if child is CanvasItem and not (child is CanvasGroup and str(child.name) == GROUP_NAME):
			found.append(child)
	return found


## Puts a CanvasGroup under the node and moves its drawing children into it, through the EDITOR's undo
## manager when there is one. True when the edit happened, so a caller writes nothing on a refusal.
static func group_children(scene_root: Node, relative_path: String) -> bool:
	if not can_group(scene_root, relative_path):
		return false
	var node: Node = scene_root if relative_path.is_empty() or relative_path == "." \
		else scene_root.get_node_or_null(NodePath(relative_path))
	var moving: Array[Node] = groupable_children(node)
	var group: CanvasGroup = CanvasGroup.new()
	group.name = GROUP_NAME
	var undo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo() \
		if Engine.is_editor_hint() else null
	if undo == null:
		_apply(node, group, moving, scene_root)
		return true
	undo.create_action(EventSheetL10n.translate("Draw \"%s\" children as one picture") % str(node.name))
	undo.add_do_method(node, "add_child", group)
	undo.add_do_property(group, "owner", scene_root)
	for child: Node in moving:
		undo.add_do_method(node, "remove_child", child)
		undo.add_do_method(group, "add_child", child)
		undo.add_do_property(child, "owner", scene_root)
	# The way back, innermost first: every child home in the order it left, and then the group gone.
	for child: Node in moving:
		undo.add_undo_method(group, "remove_child", child)
		undo.add_undo_method(node, "add_child", child)
		undo.add_undo_property(child, "owner", scene_root)
	undo.add_undo_method(node, "remove_child", group)
	# The group is not in the tree until the action is done, so the history has to hold the only
	# reference to it - without this it is freed the moment this function returns.
	undo.add_do_reference(group)
	undo.commit_action()
	return true


## The words the door wears, naming the node it is about.
static func offer_text(node_name: String) -> String:
	return EventSheetL10n.translate("Draw %s's children as one") % node_name.strip_edges()


## The edit itself, with no editor around it: the same tree afterwards, which is what the test drives
## and what a project without the editor open would get.
static func _apply(node: Node, group: CanvasGroup, moving: Array[Node], scene_root: Node) -> void:
	node.add_child(group)
	group.owner = scene_root
	for child: Node in moving:
		node.remove_child(child)
		group.add_child(child)
		child.owner = scene_root
