## @ace_category("Line Of Sight")
## @ace_expose_all(node)
@icon("res://eventsheet_addons/behavior.svg")
class_name LOSBehavior
extends Node

## The node this behavior acts on (its parent). Required host: Node2D.
var host: Node2D = null

func _enter_tree() -> void:
	host = get_parent() as Node2D
	if host == null:
		push_warning("LOSBehavior behavior requires a Node2D parent.")

## Physics layers the sight raycast tests against - matching bodies block the view.
@export var collision_mask: int = 1
## Field of view angle in degrees centered on the node's facing - 360 sees all around.
@export var cone_of_view_degrees: float = 360.0
## Maximum distance the node can see - targets farther away are never visible.
@export var sight_range: float = 400.0

## @ace_expression
## @ace_name("Nearest Visible In Group")
## The closest group member this node can actually SEE (range + cone + raycast) - scans every
## candidate and skips occluded ones, so a nearer-but-blocked enemy can't shadow a visible farther
## one. Returns null if none are visible. The targeting primitive for auto-attack AI.
func nearest_visible_in_group(group: String) -> Node2D:
	var best: Node2D = null
	for n: Node in get_tree().get_nodes_in_group(group):
		var candidate: Node2D = n as Node2D
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
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$LOSBehavior.has_los_to({point})")
func has_los_to(point: Vector2) -> bool:
	if host == null or host.global_position.distance_to(point) > sight_range:
		return false
	if cone_of_view_degrees < 360.0:
		var to_target := (point - host.global_position).angle()
		if absf(angle_difference(host.rotation, to_target)) > deg_to_rad(cone_of_view_degrees) * 0.5:
			return false
	return has_los_between(host.global_position, point)

## @ace_condition
## @ace_name("Has LOS Between")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$LOSBehavior.has_los_between({from_point}, {to_point})")
func has_los_between(from_point: Vector2, to_point: Vector2) -> bool:
	if host == null:
		return false
	var query := PhysicsRayQueryParameters2D.create(from_point, to_point)
	query.collision_mask = collision_mask
	return host.get_world_2d().direct_space_state.intersect_ray(query).is_empty()

# Line of Sight behavior (event-sheet parity): raycast LOS with range and an optional cone of view (degrees; 360 = all around). Conditions: Has Line Of Sight To, Has LOS Between positions.
