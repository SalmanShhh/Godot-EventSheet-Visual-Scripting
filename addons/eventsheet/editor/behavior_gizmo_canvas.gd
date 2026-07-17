@tool
class_name EventSheetBehaviorGizmoCanvas
extends Node2D

# The transient drawing surface behavior gizmos paint on. EventSheetBehaviorGizmos spawns one
# of these under the host Node2D while a gizmo-capable behavior is selected (owner stays null,
# so it is never written to the scene file) and fills `entries`; every draw pass re-reads each
# behavior's live script variables and hands this canvas to the behavior's drawer, so tweaking
# a knob in the Inspector repaints the overlay immediately.
#
# The drawer contract (the pack API seam, sibling to editor_preview_sample):
#
#   static func editor_gizmo_draw(params: Dictionary, host: Node2D, canvas: CanvasItem) -> void
#
# - params: the behavior node's script variables (exported knobs AND internal state), live.
# - host: the parent Node2D the behavior acts on.
# - canvas: this node - a child of the host at identity transform, so plain draw_* calls paint
#   in HOST-LOCAL space. For world-space shapes (a bounds rectangle, a patrol route), first:
#       canvas.draw_set_transform_matrix(host.get_global_transform().affine_inverse())
#
# STATIC on purpose, like the preview seam: the emitted pack script never runs in the editor
# (no @tool), but its statics are callable from editor code - one pure function, zero editor
# coupling in generated code.

## One entry per gizmo-capable behavior: {"behavior": Node, "drawer": Callable, "script": Script}.
## A valid "drawer" (registered via EventSheets.register_editor_gizmo) wins over the static.
var entries: Array[Dictionary] = []
var host: Node2D = null


func _process(_delta: float) -> void:
	# Repaint every frame while alive: the surface only exists during selection, and live
	# repaints are what make the gizmo track Inspector edits and host movement.
	queue_redraw()


func _draw() -> void:
	if host == null or not is_instance_valid(host):
		return
	for entry: Dictionary in entries:
		var behavior: Node = entry.get("behavior")
		if behavior == null or not is_instance_valid(behavior):
			continue
		var params: Dictionary = live_params(behavior)
		var drawer: Callable = entry.get("drawer", Callable())
		if drawer.is_valid():
			drawer.call(params, host, self)
		else:
			var script: Script = entry.get("script")
			if script != null:
				script.call("editor_gizmo_draw", params, host, self)
		# Each behavior draws from a clean slate - one drawer's transform never leaks into the next.
		draw_set_transform_matrix(Transform2D.IDENTITY)


## The behavior node's script variables by name - exported knobs and internal state alike, so
## a drawer sees exactly what the behavior would act on.
static func live_params(behavior: Node) -> Dictionary:
	var values: Dictionary = {}
	for property: Dictionary in behavior.get_property_list():
		if int(property.get("usage", 0)) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var property_name: String = str(property.get("name", ""))
			values[property_name] = behavior.get(property_name)
	return values
