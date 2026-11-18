extends Node2D

@export var target: Node2D
var sight: Dictionary = {}
var ground: Dictionary = {}


func _physics_process(_delta: float) -> void:
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, target.global_position)
	query.collision_mask = 2
	sight = space_state.intersect_ray(query)
	ground = get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(global_position, target.global_position))
	var sweep := PhysicsShapeQueryParameters2D.new()
	var caught := get_world_2d().direct_space_state.intersect_shape(sweep, 8)
