@tool
class_name EventSheetDrawingCanvasGizmo
extends RefCounted

# Selection-driven 2D preview gizmo for the DrawingCanvas behaviour. Select a DrawingCanvas node in the
# scene and its preview_prefab formation draws in the 2D viewport, centered on the host and scaled and
# rotated by the node's Editor Preview knobs - so a designer can place a target marker or scorch
# formation before wiring Draw Prefab. The preview is a transient child (the shared DrawingPrefabStamp
# @tool renderer) whose owner stays null, so it is never written to the scene file and disappears the
# instant the node is deselected. The DrawingCanvas behaviour itself is not @tool and cannot draw
# in-editor; this is the editor-side bridge that gives it a live gizmo.
#
# Why a selection-driven child and not an EditorPlugin canvas overlay: this plugin owns the main
# EventSheet workspace, and a main-screen plugin whose _handles() returns true for a scene node hijacks
# the workspace whenever that node is selected (Godot switches to the handling plugin's main screen).
# Driving the preview off EditorSelection.selection_changed leaves the 2D editor completely untouched -
# the same discipline EventSheetBehaviorPreview uses for its in-editor motion preview.

const STAMP_PATH: String = "res://eventsheet_addons/drawing_prefab_stamp/drawing_prefab_stamp.gd"
## The DrawingCanvas is duck-typed by script path (never by class) so this editor code never names the
## pack and never joins the boot compile.
const CANVAS_SCRIPT_SUFFIX: String = "drawing_canvas/drawing_canvas_behavior.gd"
const PREVIEW_NODE_NAME: String = "__DrawingCanvasPreview"

var _editor_interface: EditorInterface = null
var _preview: Node2D = null


## Wires the gizmo to editor selection and previews the current selection. Called from the plugin's
## _enter_tree; a null interface (non-editor context) is a safe no-op.
func init(editor_interface: EditorInterface) -> void:
	_editor_interface = editor_interface
	if _editor_interface == null:
		return
	var selection: EditorSelection = _editor_interface.get_selection()
	if selection != null and not selection.selection_changed.is_connected(_on_selection_changed):
		selection.selection_changed.connect(_on_selection_changed)
	_on_selection_changed()


## Tears the gizmo down: drops any live preview and disconnects from selection, so a disabled plugin
## leaves the edited scene byte-identical to how it found it.
func teardown() -> void:
	_clear_preview()
	if _editor_interface != null:
		var selection: EditorSelection = _editor_interface.get_selection()
		if selection != null and selection.selection_changed.is_connected(_on_selection_changed):
			selection.selection_changed.disconnect(_on_selection_changed)
	_editor_interface = null


## Rebuilds the preview for the current selection: exactly one DrawingCanvas behaviour that has a
## preview_prefab set shows its formation at its host; every other selection clears it. The behaviour
## is a Node component (extends Node, host = get_parent() as Node2D), so the preview draws under the
## PARENT Node2D and its knobs are read off the selected behaviour.
func _on_selection_changed() -> void:
	_clear_preview()
	if _editor_interface == null:
		return
	var selected: Array[Node] = _editor_interface.get_selection().get_selected_nodes()
	if selected.size() != 1:
		return
	var canvas: Node = selected[0]
	if not _is_drawing_canvas(canvas):
		return
	var prefab: Variant = canvas.get("preview_prefab")
	if prefab == null:
		return
	var host: Node2D = canvas.get_parent() as Node2D
	if host == null:
		return
	_add_preview(host, canvas, prefab)


## True when the node's attached script is the DrawingCanvas behaviour (matched by path so this file
## never names the pack class).
static func _is_drawing_canvas(node: Node) -> bool:
	var script: Script = node.get_script() as Script
	return script != null and str(script.resource_path).ends_with(CANVAS_SCRIPT_SUFFIX)


## Spawns the transient preview stamp under the host Node2D (so it draws at the host's position),
## mirroring the behaviour's Editor Preview knobs. owner stays null so the node is never serialized.
func _add_preview(host: Node2D, source: Node, prefab: Variant) -> void:
	var stamp_script: Script = load(STAMP_PATH) as Script
	if stamp_script == null or not stamp_script.can_instantiate():
		return
	var stamp: Node2D = stamp_script.new() as Node2D
	if stamp == null:
		return
	stamp.name = PREVIEW_NODE_NAME
	stamp.set("prefab", prefab)
	stamp.set("prefab_scale", _knob(source, "preview_scale", 1.0))
	stamp.set("prefab_rotation", _knob(source, "preview_rotation", 0.0))
	host.add_child(stamp)
	stamp.owner = null
	_preview = stamp


## Reads a float knob off the behaviour node, tolerating a missing/unset property (returns fallback).
static func _knob(source: Node, property_name: String, fallback: float) -> float:
	var value: Variant = source.get(property_name)
	if value == null:
		return fallback
	return float(value)


## Removes the live preview stamp, if any.
func _clear_preview() -> void:
	if _preview != null and is_instance_valid(_preview):
		if _preview.get_parent() != null:
			_preview.get_parent().remove_child(_preview)
		_preview.queue_free()
	_preview = null
