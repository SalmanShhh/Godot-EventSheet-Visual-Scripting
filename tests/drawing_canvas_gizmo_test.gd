# EventForge - DrawingCanvas 2D preview gizmo
#
# Guards the selection-driven preview lifecycle (drawing_canvas_gizmo.gd): the DrawingCanvas behaviour
# is duck-typed by script path, and selecting one spawns a transient DrawingPrefabStamp under its host
# Node2D that mirrors the Editor Preview knobs and never serializes (owner == null). The stamp's actual
# vector rendering is proven separately (drawing_prefab_stamp render verification); this pins the glue.
@tool
class_name DrawingCanvasGizmoTest
extends RefCounted

const BEHAVIOR_PATH: String = "res://eventsheet_addons/drawing_canvas/drawing_canvas_behavior.gd"
const STAMP_PATH: String = "res://eventsheet_addons/drawing_prefab_stamp/drawing_prefab_stamp.gd"
const PREFAB_PATH: String = "res://eventsheet_addons/drawing_prefab_resource/drawing_prefab_resource.gd"


static func run() -> bool:
	var all_passed: bool = true

	# Duck-typing: only the DrawingCanvas behaviour script matches, and it matches by path (never class).
	var behavior_node: Node = Node.new()
	behavior_node.set_script(load(BEHAVIOR_PATH))
	all_passed = _check("DrawingCanvas behaviour is recognized",
		EventSheetDrawingCanvasGizmo._is_drawing_canvas(behavior_node), true) and all_passed
	var scriptless: Node = Node.new()
	all_passed = _check("a scriptless node is not a DrawingCanvas",
		EventSheetDrawingCanvasGizmo._is_drawing_canvas(scriptless), false) and all_passed
	# DrawingPrefabStamp extends Node2D, so its host must be a Node2D for the script to attach.
	var other: Node2D = Node2D.new()
	other.set_script(load(STAMP_PATH))
	all_passed = _check("a different script is not a DrawingCanvas",
		EventSheetDrawingCanvasGizmo._is_drawing_canvas(other), false) and all_passed
	scriptless.free()
	other.free()

	# Preview lifecycle: _add_preview spawns the stamp under the HOST (the behaviour's parent Node2D),
	# copying the knobs off the behaviour, with owner null; _clear_preview removes it.
	var host: Node2D = Node2D.new()
	host.add_child(behavior_node)
	behavior_node.set("preview_scale", 2.5)
	behavior_node.set("preview_rotation", 45.0)
	var prefab: Resource = load(PREFAB_PATH).new()
	var gizmo: EventSheetDrawingCanvasGizmo = EventSheetDrawingCanvasGizmo.new()
	gizmo._add_preview(host, behavior_node, prefab)

	var stamp: Node = host.get_node_or_null(EventSheetDrawingCanvasGizmo.PREVIEW_NODE_NAME)
	all_passed = _check("preview stamp is added under the host", stamp != null, true) and all_passed
	if stamp != null:
		all_passed = _check("preview stamp is the DrawingPrefabStamp renderer",
			str((stamp.get_script() as Script).resource_path).ends_with("drawing_prefab_stamp.gd"), true) and all_passed
		all_passed = _check("preview stamp never serializes (owner is null)", stamp.owner, null) and all_passed
		all_passed = _check("preview stamp carries the prefab", stamp.get("prefab"), prefab) and all_passed
		all_passed = _check("preview stamp mirrors the scale knob", stamp.get("prefab_scale"), 2.5) and all_passed
		all_passed = _check("preview stamp mirrors the rotation knob", stamp.get("prefab_rotation"), 45.0) and all_passed

	gizmo._clear_preview()
	all_passed = _check("clearing removes the preview stamp",
		host.get_node_or_null(EventSheetDrawingCanvasGizmo.PREVIEW_NODE_NAME), null) and all_passed

	# init(null) / teardown() are safe no-ops outside an editor (no selection singleton).
	gizmo.init(null)
	gizmo.teardown()
	all_passed = _check("init(null) + teardown() are safe no-ops", true, true) and all_passed

	host.free()
	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] drawing_canvas_gizmo_test: %s" % label)
		return true
	print("[FAIL] drawing_canvas_gizmo_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
