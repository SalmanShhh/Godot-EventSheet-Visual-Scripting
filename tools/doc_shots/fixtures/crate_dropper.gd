extends Node3D

@onready var crate: Node3D = $Crate


func drop_crate() -> void:
	var query := PhysicsRayQueryParameters3D.create(crate.global_position, crate.global_position + Vector3.DOWN * 100.0)
	var ground := get_world_3d().direct_space_state.intersect_ray(query)
	if not ground.is_empty():
		crate.global_position = ground.position
