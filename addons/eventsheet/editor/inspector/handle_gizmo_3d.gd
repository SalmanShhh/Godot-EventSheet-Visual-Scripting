# Godot EventSheets - the 3D half of the viewport handle seam (editor-only).
#
# The same `# @inspector_handle` decor lines the 2D overlay reads, drawn and dragged in the 3D
# viewport through the engine's own gizmo seam: a Node3D whose script declares handles gets a
# draggable dot per handle, and each finished drag is one undo step. Deliberately carries no
# class_name - it is loaded by path from the handle seam so that registering it never widens the
# editor's boot compile, and so the headless suite never loads an editor-only base class.
#
# Kinds read exactly as they do in 2D: `point` is an offset from the anchor, `length` a distance
# along local X, `angle` degrees around local Y, and `points` a list of offsets. The drag projects
# the cursor onto the plane through the anchor that faces the camera, which is what a designer means
# by dragging a handle in a perspective view.
@tool
extends EditorNode3DGizmoPlugin

const DECOR_PATH: String = "res://addons/eventsheet/editor/inspector/object_decor.gd"

## The arm an angle handle rides on, in node-local units (the 2D seam's own ANGLE_ARM, in metres).
const ANGLE_ARM: float = 1.0

## Set by the handle seam right after construction: the editor's undo manager, so a drag commits
## one step through the same funnel every other editor edit uses.
var undo_redo: Object = null

# gizmo instance id -> Array of {"handle": Dictionary, "index": int} in handle-id order, so
# _set_handle and _commit_handle can answer for the id the editor hands back.
var _slots: Dictionary = {}


func _init() -> void:
	create_handle_material("handles")


func _get_gizmo_name() -> String:
	return "EventSheet Handles"


func _has_gizmo(node: Node3D) -> bool:
	return node != null and not (load(DECOR_PATH) as GDScript).handles_for(node).is_empty()


func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	var node: Node3D = gizmo.get_node_3d()
	if node == null:
		return
	var slots: Array = []
	var positions: PackedVector3Array = PackedVector3Array()
	var ids: PackedInt32Array = PackedInt32Array()
	for handle: Variant in (load(DECOR_PATH) as GDScript).handles_for(node):
		var entry: Dictionary = handle as Dictionary
		for point_index: int in range(_mark_count(node, entry)):
			positions.append(mark_position(node, entry, point_index))
			ids.append(slots.size())
			slots.append({"handle": entry, "index": point_index})
	_slots[gizmo.get_instance_id()] = slots
	if not positions.is_empty():
		gizmo.add_handles(positions, get_material("handles", gizmo), ids)


func _get_handle_name(gizmo: EditorNode3DGizmo, handle_id: int, _secondary: bool) -> String:
	var slot: Dictionary = _slot_of(gizmo, handle_id)
	return str((slot.get("handle", {}) as Dictionary).get("property", ""))


func _get_handle_value(gizmo: EditorNode3DGizmo, handle_id: int, _secondary: bool) -> Variant:
	var node: Node3D = gizmo.get_node_3d()
	var slot: Dictionary = _slot_of(gizmo, handle_id)
	if node == null or slot.is_empty():
		return null
	return node.get(str((slot.get("handle", {}) as Dictionary).get("property", "")))


func _set_handle(gizmo: EditorNode3DGizmo, handle_id: int, _secondary: bool, camera: Camera3D, screen_point: Vector2) -> void:
	var node: Node3D = gizmo.get_node_3d()
	var slot: Dictionary = _slot_of(gizmo, handle_id)
	if node == null or camera == null or slot.is_empty():
		return
	var handle: Dictionary = slot.get("handle", {})
	var anchor: Vector3 = anchor_of(node, handle)
	var local_point: Variant = cursor_on_anchor_plane(node, camera, screen_point, anchor)
	if local_point == null:
		return
	var property: String = str(handle.get("property", ""))
	var value: Variant = value_from_point(str(handle.get("kind", "")), anchor, local_point as Vector3)
	if str(handle.get("kind", "")) == "points":
		value = _replaced_point(node.get(property), int(slot.get("index", 0)), value as Vector3)
	node.set(property, value)
	gizmo.get_node_3d().update_gizmos()


func _commit_handle(gizmo: EditorNode3DGizmo, handle_id: int, _secondary: bool, restore: Variant, cancel: bool) -> void:
	var node: Node3D = gizmo.get_node_3d()
	var slot: Dictionary = _slot_of(gizmo, handle_id)
	if node == null or slot.is_empty():
		return
	var property: String = str((slot.get("handle", {}) as Dictionary).get("property", ""))
	if cancel:
		node.set(property, restore)
		return
	var after: Variant = node.get(property)
	if undo_redo == null or restore == after:
		return
	undo_redo.call("create_action", "Drag %s" % property)
	undo_redo.call("add_do_property", node, property, after)
	undo_redo.call("add_undo_property", node, property, restore)
	undo_redo.call("commit_action")


## The anchor a handle is measured from: the Vector3 property named by `from`, or the node's origin.
func anchor_of(node: Node3D, handle: Dictionary) -> Vector3:
	var anchor_property: String = str(handle.get("from", ""))
	if anchor_property.is_empty():
		return Vector3.ZERO
	var value: Variant = node.get(anchor_property)
	return value if value is Vector3 else Vector3.ZERO


## Where one mark of a handle sits in node-local space.
func mark_position(node: Node3D, handle: Dictionary, point_index: int) -> Vector3:
	var anchor: Vector3 = anchor_of(node, handle)
	var value: Variant = node.get(str(handle.get("property", "")))
	match str(handle.get("kind", "")):
		"point":
			return anchor + (value if value is Vector3 else Vector3.ZERO)
		"length":
			return anchor + Vector3(float(value if value is float or value is int else 0.0), 0.0, 0.0)
		"angle":
			var degrees: float = float(value if value is float or value is int else 0.0)
			return anchor + Vector3(ANGLE_ARM, 0.0, 0.0).rotated(Vector3.UP, deg_to_rad(degrees))
		"points":
			var points: Array = _point_list(value)
			if point_index >= 0 and point_index < points.size():
				return anchor + (points[point_index] as Vector3)
	return anchor


## What the dragged property becomes with the cursor at `local_point` - the 3D reading of the same
## three answers the 2D seam gives.
func value_from_point(kind: String, anchor: Vector3, local_point: Vector3) -> Variant:
	var offset: Vector3 = local_point - anchor
	match kind:
		"length":
			return offset.length()
		"angle":
			return fposmod(rad_to_deg(atan2(-offset.z, offset.x)), 360.0)
	return offset


## The cursor projected onto the camera-facing plane through the anchor, in node-local space, or
## null when the ray runs parallel to it.
func cursor_on_anchor_plane(node: Node3D, camera: Camera3D, screen_point: Vector2, anchor: Vector3) -> Variant:
	var world_anchor: Vector3 = node.global_transform * anchor
	var plane: Plane = Plane(-camera.global_transform.basis.z, world_anchor)
	var hit: Variant = plane.intersects_ray(camera.project_ray_origin(screen_point), camera.project_ray_normal(screen_point))
	if hit == null:
		return null
	return node.global_transform.affine_inverse() * (hit as Vector3)


func _mark_count(node: Node3D, handle: Dictionary) -> int:
	if str(handle.get("kind", "")) != "points":
		return 1
	return _point_list(node.get(str(handle.get("property", "")))).size()


func _slot_of(gizmo: EditorNode3DGizmo, handle_id: int) -> Dictionary:
	var slots: Array = _slots.get(gizmo.get_instance_id(), [])
	if handle_id < 0 or handle_id >= slots.size():
		return {}
	return slots[handle_id]


func _point_list(value: Variant) -> Array:
	var points: Array = []
	if value is PackedVector3Array:
		for point: Vector3 in (value as PackedVector3Array):
			points.append(point)
	elif value is Array:
		for entry: Variant in (value as Array):
			if entry is Vector3:
				points.append(entry)
	return points


func _replaced_point(value: Variant, index: int, point: Vector3) -> Variant:
	var points: Array = _point_list(value)
	if index < 0 or index >= points.size():
		return value
	points[index] = point
	if value is PackedVector3Array:
		var packed: PackedVector3Array = PackedVector3Array()
		for entry: Variant in points:
			packed.append(entry as Vector3)
		return packed
	return points
