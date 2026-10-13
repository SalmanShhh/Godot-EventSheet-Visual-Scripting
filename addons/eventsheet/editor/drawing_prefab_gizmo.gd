@tool
class_name EventSheetDrawingPrefabGizmo
extends "res://addons/eventsheet/editor/selection_preview.gd"

# Selection-driven 2D preview gizmo for DrawingPrefabResource references. Select ANY Node2D that exposes
# a DrawingPrefabResource property (e.g. `@export var marker: DrawingPrefabResource`) and that formation
# draws in the 2D viewport at the node's origin - so you SEE the prefab a node points at without running
# the game or wiring Draw Prefab. It mirrors EventSheetDrawingCanvasGizmo's discipline exactly: a
# transient owner-less DrawingPrefabStamp child (never written to the scene file), driven off
# EditorSelection.selection_changed so the 2D editor is never hijacked (a main-screen _handles plugin
# would switch Godot away from the workspace whenever such a node was selected).
#
# Nodes that already draw the prefab themselves are skipped so nothing double-draws: the DrawingCanvas
# (its preview_prefab has the dedicated EventSheetDrawingCanvasGizmo) and the DrawingPrefabStamp (a @tool
# node that paints its own prefab in _draw). Everything is duck-typed by script path, so this editor file
# never names the pack classes and never joins the boot compile.

const STAMP_PATH: String = "res://eventsheet_addons/drawing_prefab_stamp/drawing_prefab_stamp.gd"
const PREVIEW_NODE_NAME: String = "__DrawingPrefabPreview"
## A DrawingPrefabResource is recognised by its script path (never by class) so this file stays off the
## boot compile - the same discipline the canvas gizmo uses for the DrawingCanvas behaviour.
const PREFAB_SCRIPT_SUFFIX: String = "drawing_prefab_resource/drawing_prefab_resource.gd"
## Nodes that render the prefab on their own - excluded so the gizmo never draws a second copy over them.
const SELF_DRAWING_SUFFIXES: Array[String] = [
	"drawing_canvas/drawing_canvas_behavior.gd",
	"drawing_prefab_stamp/drawing_prefab_stamp.gd",
]


## Previews exactly one Node2D that exposes a DrawingPrefabResource (and does not draw it itself).
func _preview_for(node: Node) -> void:
	var prefab: Resource = find_prefab(node) if node is Node2D and not _is_self_drawing(node) else null
	if prefab != null:
		_add_preview(node as Node2D, prefab)


## The first DrawingPrefabResource-typed property value stored on the node, or null. Pure and
## editor-agnostic (no EditorInterface): it walks the node's stored properties and returns the first
## value whose script is the prefab resource - so it fires for any `@export var x: DrawingPrefabResource`
## no matter what the user named it, and returns nothing when the node references none.
static func find_prefab(node: Node) -> Resource:
	if node == null:
		return null
	for entry: Dictionary in node.get_property_list():
		if int(entry.get("usage", 0)) & PROPERTY_USAGE_STORAGE == 0:
			continue
		var value: Variant = node.get(str(entry.get("name", "")))
		if value is Resource and _is_prefab(value as Resource):
			return value as Resource
	return null


## True when a resource's script is the DrawingPrefabResource (matched by path so this file never names
## the pack class).
static func _is_prefab(res: Resource) -> bool:
	var script: Script = res.get_script() as Script
	return script != null and str(script.resource_path).ends_with(PREFAB_SCRIPT_SUFFIX)


## True when the node draws the prefab itself (DrawingCanvas or DrawingPrefabStamp), so this gizmo yields.
static func _is_self_drawing(node: Node) -> bool:
	var script: Script = node.get_script() as Script
	if script == null:
		return false
	var path: String = str(script.resource_path)
	for suffix: String in SELF_DRAWING_SUFFIXES:
		if path.ends_with(suffix):
			return true
	return false


## Spawns the transient preview stamp under the host Node2D (so it draws at the host's position). owner
## stays null so the node is never serialized into the scene.
func _add_preview(host: Node2D, prefab: Resource) -> void:
	var stamp_script: Script = load(STAMP_PATH) as Script
	if stamp_script == null or not stamp_script.can_instantiate():
		return
	var stamp: Node2D = stamp_script.new() as Node2D
	if stamp == null:
		return
	stamp.name = PREVIEW_NODE_NAME
	stamp.set("prefab", prefab)
	_show_preview(host, stamp)
