@tool
extends RefCounted

# THE EVENTS OVERLAY - the badges themselves.
#
# Two surfaces, one set of facts (scene_events_facts.gd):
#   * the SCENE DOCK: a node whose script is a sheet wears a small ⌗ and its event count at the
#     right edge of its row, hovering names its triggers, and clicking the badge opens the sheet;
#   * the 2D / 3D EDITOR: the same badge beside the node's gizmo, drawn on a transient canvas under
#     the edited scene's root.
# Off by default (eventsheets/editor/show_scene_events) - a badge on every node is noise, and the
# scene editor belongs to whoever is editing the scene.
#
# Nothing is added to the scene that survives it: the canvas is a transient child with owner null,
# the Scene-dock mark is a mouse-transparent Control laid over the dock's own Tree, and both come
# off the moment the overlay is turned off or the plugin is disabled. If the editor's own layout
# ever moves the dock's Tree out from under this, the overlay simply draws nothing - it never
# guesses, and it never touches what it did not find.
#
# BOOT-PATH FILE (loaded from plugin._enter_tree): no heavy class names in code - the facts load by
# path at use time.

const FACTS_PATH: String = "res://addons/eventsheet/editor/scene_events_facts.gd"
## The same name scene_events_facts.gd owns, spelled here so the boot path can read the switch
## without compiling the facts (and the vocabulary behind them) to find out it is off.
const SETTING_SHOW_EVENTS: String = "eventsheets/editor/show_scene_events"
const CANVAS_NODE_NAME: String = "__EventSheetEventsCanvas"
const DOCK_MARK_NAME: String = "__EventSheetEventsDockMark"

var _editor_interface: EditorInterface = null
var _canvas: Node2D = null
var _dock_mark: Control = null


## Wires the overlay to the edited scene and draws the current one. A null interface (non-editor
## context) is a safe no-op, and so is the overlay being switched off.
func init(editor_interface: EditorInterface) -> void:
	_editor_interface = editor_interface
	if _editor_interface == null:
		return
	if not _editor_interface.get_selection().selection_changed.is_connected(refresh):
		_editor_interface.get_selection().selection_changed.connect(refresh)
	# The View-menu toggle reaches the live overlay through the hook refresh() registers, and that
	# only happens once the overlay is actually ON - loading the facts compiles the reading
	# vocabulary behind them, and the boot path must not pay for a feature nobody switched on. So
	# the FIRST switch-on draws at the next selection change rather than instantly; every one after
	# that is immediate.
	refresh()


## Drops every mark and disconnects - a disabled plugin leaves the edited scene and the editor's
## own docks exactly as it found them.
func teardown() -> void:
	_clear()
	if _editor_interface != null:
		var selection: EditorSelection = _editor_interface.get_selection()
		if selection != null and selection.selection_changed.is_connected(refresh):
			selection.selection_changed.disconnect(refresh)
	_editor_interface = null


## Re-reads the edited scene and re-marks both surfaces. Cheap enough to call on any editor change:
## the facts are a text read per script, and an overlay that is off returns immediately.
func refresh() -> void:
	_clear()
	if _editor_interface == null:
		return
	# The setting is read WITHOUT loading the facts: this runs at editor boot, and the reading
	# vocabulary behind the badges must not be compiled for a feature nobody switched on. The name
	# is spelled here rather than named through the facts for exactly that reason.
	if not bool(ProjectSettings.get_setting(SETTING_SHOW_EVENTS, false)):
		return
	var facts: Script = load(FACTS_PATH) as Script
	if facts == null:
		return
	facts.call("register_refresh", refresh)
	var root: Node = _editor_interface.get_edited_scene_root()
	if root == null:
		return
	var marked: Array = facts.call("badges_in_scene", root)
	if marked.is_empty():
		return
	_mark_scene_editor(marked, root)
	_mark_scene_dock(marked, root, facts)


## The 2D badge: one transient canvas under the scene root drawing every marked node's badge at its
## own position. 3D nodes are marked in the Scene dock only - a 3D gizmo is the editor's own.
func _mark_scene_editor(marked: Array, root: Node) -> void:
	var host: Node2D = root as Node2D
	if host == null:
		return
	var entries: Array = []
	for entry: Variant in marked:
		var node: Node2D = (entry as Dictionary).get("node") as Node2D
		if node != null:
			entries.append({"node": node, "count": int((entry as Dictionary).get("count", 0))})
	if entries.is_empty():
		return
	var canvas: Node2D = (load("res://addons/eventsheet/editor/scene_events_canvas.gd") as Script).new() as Node2D
	canvas.name = CANVAS_NODE_NAME
	canvas.set("entries", entries)
	host.add_child(canvas)
	canvas.owner = null
	_canvas = canvas


## The Scene-dock badge: a mouse-transparent Control laid over the dock's own Tree, drawing the mark
## beside every row whose node has events. The Tree is identified by its ROOT ITEM naming the edited
## scene's root - the one thing about the Scene dock that is not a layout detail - so a rearranged
## editor finds it or draws nothing, never something else.
func _mark_scene_dock(marked: Array, root: Node, facts: Script) -> void:
	var tree: Tree = _find_scene_tree(_editor_interface.get_base_control(), root.name)
	if tree == null:
		return
	var labels: Dictionary = {}
	for entry: Variant in marked:
		var node: Node = (entry as Dictionary).get("node") as Node
		if node == null:
			continue
		labels[node.name] = {
			"text": str(facts.call("badge_text", entry as Dictionary)),
			"tooltip": str(facts.call("badge_tooltip", entry as Dictionary)),
		}
	var mark: Control = (load("res://addons/eventsheet/editor/scene_events_dock_mark.gd") as Script).new() as Control
	mark.name = DOCK_MARK_NAME
	mark.set("badges", labels)
	mark.set("tree", tree)
	tree.add_child(mark)
	_dock_mark = mark


## The editor's Scene-dock Tree: the one whose root item is named after the edited scene's root.
static func _find_scene_tree(base: Control, root_name: String) -> Tree:
	if base == null or root_name.is_empty():
		return null
	var pending: Array[Node] = [base]
	while not pending.is_empty():
		var node: Node = pending.pop_front()
		var tree: Tree = node as Tree
		if tree != null:
			var item: TreeItem = tree.get_root()
			if item != null and item.get_text(0) == root_name:
				return tree
		for child: Node in node.get_children():
			pending.append(child)
	return null


func _clear() -> void:
	if _canvas != null and is_instance_valid(_canvas):
		if _canvas.get_parent() != null:
			_canvas.get_parent().remove_child(_canvas)
		_canvas.queue_free()
	_canvas = null
	if _dock_mark != null and is_instance_valid(_dock_mark):
		if _dock_mark.get_parent() != null:
			_dock_mark.get_parent().remove_child(_dock_mark)
		_dock_mark.queue_free()
	_dock_mark = null
