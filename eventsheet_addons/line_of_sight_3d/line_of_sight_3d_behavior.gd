@icon("res://eventsheet_addons/behavior.svg")
class_name LOS3DBehavior
extends Node

## The node this behavior acts on (its parent). Required host: Node3D.
var host: Node3D = null

func _enter_tree() -> void:
	host = get_parent() as Node3D
	if host == null:
		push_warning("LOS3DBehavior behavior requires a Node3D parent.")

@export var collision_mask: int = 1
@export var cone_of_view_degrees: float = 360.0
@export var sight_range: float = 1000.0

## @ace_expression
## @ace_name("Nearest Visible In Group")
## @ace_category("Line Of Sight 3D")
## @ace_codegen_template("$LOS3DBehavior.nearest_visible_in_group({group})")
## The closest group member this node can actually SEE (range + cone + raycast) — scans every
## candidate and skips occluded ones, so a nearer-but-blocked enemy can't shadow a visible farther
## one. Returns null if none are visible. The targeting primitive for auto-attack AI.
func nearest_visible_in_group(group: String) -> Node3D:
	var best: Node3D = null
	for n: Node in get_tree().get_nodes_in_group(group):
		var candidate: Node3D = n as Node3D
		if candidate == null or candidate == host:
			continue
		if not has_los_to(candidate.global_position):
			continue
		if best == null or host.global_position.distance_to(candidate.global_position) < host.global_position.distance_to(best.global_position):
			best = candidate
	return best

func _process(delta: float) -> void:
	pass

## @ace_condition
## @ace_name("Has Line Of Sight To")
## @ace_category("Line Of Sight 3D")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$LOS3DBehavior.has_los_to({point})")
func has_los_to(point: Vector3) -> bool:
	if host == null or host.global_position.distance_to(point) > sight_range:
		return false
	if cone_of_view_degrees < 360.0:
		var forward := -host.global_transform.basis.z
		var to_target := point - host.global_position
		if to_target.length() > 0.0001 and forward.angle_to(to_target) > deg_to_rad(cone_of_view_degrees) * 0.5:
			return false
	return has_los_between(host.global_position, point)

## @ace_condition
## @ace_name("Has LOS Between")
## @ace_category("Line Of Sight 3D")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$LOS3DBehavior.has_los_between({from_point}, {to_point})")
func has_los_between(from_point: Vector3, to_point: Vector3) -> bool:
	if host == null:
		return false
	var query := PhysicsRayQueryParameters3D.create(from_point, to_point)
	query.collision_mask = collision_mask
	return host.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

# Line of Sight 3D behavior (event-sheet parity): raycast LOS in 3D with range and an optional cone of view (degrees; 360 = all around, measured from the host's -Z forward). Conditions: Has Line Of Sight To, Has LOS Between positions.
