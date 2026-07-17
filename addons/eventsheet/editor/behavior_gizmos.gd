@tool
extends RefCounted

# Selection-driven editor gizmos for behavior packs (event-sheet parity with engines whose
# behaviors draw their setup in the editor): select a node and every attached behavior that
# opts in draws its overlay - a bounds rectangle, a sight cone, a patrol route - live in the
# 2D viewport. A behavior opts in by shipping a pure static on its emitted script:
#
#   static func editor_gizmo_draw(params: Dictionary, host: Node2D, canvas: CanvasItem) -> void
#
# (see behavior_gizmo_canvas.gd for the full contract), or - for scripts that cannot ship the
# static - by registering a drawer for its script path via EventSheets.register_editor_gizmo.
#
# The overlay is a transient child canvas under the host (owner null, never serialized) that
# disappears the instant the selection moves on - the same discipline as the DrawingCanvas
# gizmo and for the same reason: a main-screen plugin whose _handles() claims scene nodes
# hijacks the workspace, so gizmos ride EditorSelection.selection_changed instead and leave
# the 2D editor untouched.
#
# BOOT-PATH FILE (loaded from plugin._enter_tree): no heavy class names in code - the API and
# the canvas load by path at use time.

const CANVAS_PATH: String = "res://addons/eventsheet/editor/behavior_gizmo_canvas.gd"
const API_PATH: String = "res://addons/eventsheet/api/eventsheets.gd"
const CANVAS_NODE_NAME: String = "__BehaviorGizmoCanvas"

var _editor_interface: EditorInterface = null
var _canvas: Node2D = null


## Wires the gizmos to editor selection and covers the current selection. Called from the
## plugin's _enter_tree; a null interface (non-editor context) is a safe no-op.
func init(editor_interface: EditorInterface) -> void:
	_editor_interface = editor_interface
	if _editor_interface == null:
		return
	var selection: EditorSelection = _editor_interface.get_selection()
	if selection != null and not selection.selection_changed.is_connected(_on_selection_changed):
		selection.selection_changed.connect(_on_selection_changed)
	_on_selection_changed()


## Drops any live canvas and disconnects from selection - a disabled plugin leaves the edited
## scene byte-identical to how it found it.
func teardown() -> void:
	_clear_canvas()
	if _editor_interface != null:
		var selection: EditorSelection = _editor_interface.get_selection()
		if selection != null and selection.selection_changed.is_connected(_on_selection_changed):
			selection.selection_changed.disconnect(_on_selection_changed)
	_editor_interface = null


func _on_selection_changed() -> void:
	_clear_canvas()
	if _editor_interface == null:
		return
	var selected: Array[Node] = _editor_interface.get_selection().get_selected_nodes()
	if selected.size() != 1:
		return
	var pair: Dictionary = gizmo_target_for(selected[0])
	var host: Node2D = pair.get("host")
	var entries: Array[Dictionary] = pair.get("entries", [] as Array[Dictionary])
	if host == null or entries.is_empty():
		return
	var canvas: Node2D = (load(CANVAS_PATH) as Script).new() as Node2D
	canvas.name = CANVAS_NODE_NAME
	canvas.set("host", host)
	canvas.set("entries", entries)
	host.add_child(canvas)
	canvas.owner = null
	_canvas = canvas


## Resolves what to draw for a selected node: selecting a HOST gizmos every opted-in child
## behavior; selecting a BEHAVIOR gizmos that one (host = its parent). Returns
## {"host": Node2D or null, "entries": Array[Dictionary]} - pure, so tests pin it headless.
static func gizmo_target_for(selected: Node) -> Dictionary:
	var entries: Array[Dictionary] = []
	var host: Node2D = null
	var own_entry: Dictionary = _entry_for(selected)
	if not own_entry.is_empty():
		host = selected.get_parent() as Node2D
		entries.append(own_entry)
	else:
		host = selected as Node2D
		if host != null:
			for child: Node in selected.get_children():
				var entry: Dictionary = _entry_for(child)
				if not entry.is_empty():
					entries.append(entry)
	return {"host": host, "entries": entries}


## The gizmo entry for one behavior node, or {} when it does not opt in. A drawer registered
## via the API wins over the script's own static.
static func _entry_for(behavior: Node) -> Dictionary:
	var script: Script = behavior.get_script() as Script
	if script == null:
		return {}
	var drawer: Callable = load(API_PATH).call("editor_gizmo_drawer_for", str(script.resource_path))
	if not drawer.is_valid() and not _has_gizmo_static(script):
		return {}
	return {"behavior": behavior, "drawer": drawer, "script": script}


static func _has_gizmo_static(script: Script) -> bool:
	for method: Dictionary in script.get_script_method_list():
		if str(method.get("name", "")) == "editor_gizmo_draw":
			return true
	return false


func _clear_canvas() -> void:
	if _canvas != null and is_instance_valid(_canvas):
		if _canvas.get_parent() != null:
			_canvas.get_parent().remove_child(_canvas)
		_canvas.queue_free()
	_canvas = null
