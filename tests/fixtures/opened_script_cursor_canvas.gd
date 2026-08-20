extends Node3D

@onready var cam: Camera3D = $Camera3D
@onready var crosshair: Sprite2D = $HUD/Crosshair
@export var assist_radius := 48.0
var hovered: Node3D = null
var best: Node3D = null

func _pick(mouse_pos: Vector2) -> void:
	var origin := cam.project_ray_origin(mouse_pos)
	var dir := cam.project_ray_normal(mouse_pos)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * 1000.0)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		hovered = null
		return
	hovered = hit.collider

func _aim() -> void:
	var from := cam.project_ray_origin(crosshair.get_global_transform_with_canvas().origin)
	var dir := cam.project_ray_normal(crosshair.get_global_transform_with_canvas().origin)
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 500.0)
	q.collision_mask = 1
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return
	hovered = hit.collider

func _aim_assist(enemies: Array) -> void:
	var centre := get_viewport().get_visible_rect().size / 2.0
	var best_d := assist_radius
	best = null
	for e in enemies:
		if cam.is_position_behind(e.global_position):
			continue
		var on_screen := cam.unproject_position(e.global_position)
		var d := centre.distance_to(on_screen)
		if d < best_d:
			best_d = d
			best = e

func _screen_pos(o: Node2D) -> Vector2:
	return o.get_global_transform_with_canvas().origin
