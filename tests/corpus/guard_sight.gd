extends CharacterBody2D

## The guard that has to see you before it comes after you. A ray for the line of sight, a swept
## circle for the sword and a pinprick under the cursor - the three questions a project puts to the
## physics world directly, each written the way the engine's own pages spell it.

@export var sight_range: float = 320.0
@export var swing_radius: float = 48.0

var target: Node2D = null
var seen: bool = false


func _physics_process(delta: float) -> void:
	if target == null:
		return
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, target.global_position)
	var sight := space_state.intersect_ray(query)
	seen = sight.is_empty()
	if seen:
		chase(delta)


func swing() -> void:
	var reach := PhysicsShapeQueryParameters2D.new()
	var circle := CircleShape2D.new()
	circle.radius = swing_radius
	reach.shape = circle
	reach.transform = Transform2D(0.0, global_position)
	var caught := get_world_2d().direct_space_state.intersect_shape(reach, 8)
	for hit in caught:
		hurt(hit.collider)


func pick_at(where: Vector2) -> Node:
	var probe := PhysicsPointQueryParameters2D.new()
	probe.position = where
	probe.collide_with_areas = true
	var under := get_world_2d().direct_space_state.intersect_point(probe, 1)
	if under.is_empty():
		return null
	return under[0].collider


func ledge_ahead() -> bool:
	var edge := global_position + Vector2(48.0, 64.0)
	var ground := get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(global_position, edge))
	return ground.is_empty()


func chase(delta: float) -> void:
	velocity = global_position.direction_to(target.global_position) * 120.0
	move_and_slide()


func hurt(body: Node) -> void:
	if body.has_method("take_damage"):
		body.take_damage(1)
