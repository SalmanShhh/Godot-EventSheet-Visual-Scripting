class_name RaycastLabDemo
extends Node2D

var gate_count: int = 0
var gate_travel: float = 1.0
var hit: Dictionary = {}
var laser_end: Vector2 = Vector2(0.0, 0.0)
var laser_normal: Vector2 = Vector2(0.0, 0.0)
var laser_on_target: bool = false
var nearby: Array = []
var picked: Array = []
var probe_end: Vector2 = Vector2(0.0, 0.0)
var radar_end: Vector2 = Vector2(0.0, 0.0)
var radar_hit: bool = false
var radar_normal: Vector2 = Vector2(0.0, 0.0)
var sweep_deg: float = 0.0
var travel: float = 1.0


func _physics_process(delta: float) -> void:
	sweep_deg = fmod(sweep_deg + 55.0 * delta, 360.0)
	radar_hit = false
	laser_on_target = false
	$Player/Radar.target_position = Vector2.from_angle(deg_to_rad(sweep_deg)) * 230.0
	$Player/Radar.force_raycast_update()
	radar_end = $Player.global_position + Vector2.from_angle(deg_to_rad(sweep_deg)) * 230.0
	var __rq_laser := PhysicsRayQueryParameters2D.create($Player.global_position, get_global_mouse_position(), 1, [$Player.get_rid()])
	__rq_laser.collide_with_areas = false
	hit = get_world_2d().direct_space_state.intersect_ray(__rq_laser)
	laser_end = get_global_mouse_position()
	laser_normal = Vector2.ZERO
	var __pq_pick := PhysicsPointQueryParameters2D.new()
	__pq_pick.position = get_global_mouse_position()
	__pq_pick.collide_with_areas = false
	picked = []
	for __hit_pick in get_world_2d().direct_space_state.intersect_point(__pq_pick, 8):
		picked.append(__hit_pick.get("collider"))
	var __cs_zone := CircleShape2D.new()
	__cs_zone.radius = 130.0
	var __sq_zone := PhysicsShapeQueryParameters2D.new()
	__sq_zone.shape = __cs_zone
	__sq_zone.transform = Transform2D(0.0, $Player.global_position)
	nearby = []
	for __hit_zone in get_world_2d().direct_space_state.intersect_shape(__sq_zone, 16):
		nearby.append(__hit_zone.get("collider"))
	var __cs_probe := CircleShape2D.new()
	__cs_probe.radius = 18.0
	var __sq_probe := PhysicsShapeQueryParameters2D.new()
	__sq_probe.shape = __cs_probe
	__sq_probe.transform = Transform2D(0.0, $Player.global_position)
	__sq_probe.motion = get_global_mouse_position() - $Player.global_position
	__sq_probe.collision_mask = 1
	var __cm_probe := get_world_2d().direct_space_state.cast_motion(__sq_probe)
	travel = __cm_probe[0] if __cm_probe.size() > 0 else 1.0
	probe_end = $Player.global_position + (get_global_mouse_position() - $Player.global_position) * travel
	$Gate.force_shapecast_update()
	gate_count = $Gate.get_collision_count()
	gate_travel = $Gate.get_closest_collision_safe_fraction()
	if $Player/Radar.is_colliding():
		radar_hit = true
		radar_end = $Player/Radar.get_collision_point()
		radar_normal = $Player/Radar.get_collision_normal()
	if not hit.is_empty():
		laser_end = hit.get("position", Vector2.ZERO)
		laser_normal = hit.get("normal", Vector2.ZERO)
		if (hit.get("collider", null) != null and hit["collider"].is_in_group("targets")):
			laser_on_target = true


func _process(delta: float) -> void:
	var ink: DrawingCanvas = $InkLayer/Ink
	var here: Vector2 = $Player.global_position
	var mouse: Vector2 = get_global_mouse_position()
	# RayCast2D node - dim to its full reach, bright to whatever stopped it.
	ink.draw_canvas_line(here.x, here.y, radar_end.x, radar_end.y, 2.0, Color(1.0, 0.85, 0.3, 0.4))
	if radar_hit:
		ink.draw_canvas_line(here.x, here.y, radar_end.x, radar_end.y, 3.0, Color(1.0, 0.85, 0.3, 0.95))
		ink.draw_canvas_ring(radar_end.x, radar_end.y, 9.0, 2.0, Color(1.0, 0.85, 0.3, 1.0))
		ink.draw_canvas_line(radar_end.x, radar_end.y, radar_end.x + radar_normal.x * 26.0, radar_end.y + radar_normal.y * 26.0, 2.0, Color(1.0, 1.0, 1.0, 0.75))
	# Query Bodies In Circle - the scan ring, and a mark on everything it collected.
	ink.draw_canvas_dashed_ring(here.x, here.y, 130.0, 9.0, 7.0, 1.0, Color(0.45, 1.0, 0.6, 0.45))
	for body: Node2D in nearby:
		ink.draw_canvas_ring(body.global_position.x, body.global_position.y, 20.0, 2.0, Color(0.45, 1.0, 0.6, 0.75))
	# Cast Ray Into - the cursor beam, stopped at the first thing in the way.
	ink.draw_canvas_line(here.x, here.y, laser_end.x, laser_end.y, 2.0, Color(0.4, 0.85, 1.0, 0.9))
	if laser_normal != Vector2.ZERO:
		ink.draw_canvas_ring(laser_end.x, laser_end.y, 7.0, 2.0, Color(0.4, 0.85, 1.0, 1.0))
		ink.draw_canvas_line(laser_end.x, laser_end.y, laser_end.x + laser_normal.x * 24.0, laser_end.y + laser_normal.y * 24.0, 2.0, Color(1.0, 1.0, 1.0, 0.7))
	if laser_on_target:
		ink.draw_canvas_ring(laser_end.x, laser_end.y, 16.0, 3.0, Color(1.0, 0.55, 0.2, 1.0))
	# Cast Circle Motion Into - where an 18px disc would jam on its way to the cursor.
	ink.draw_canvas_dashed_line(here.x, here.y, probe_end.x, probe_end.y, 8.0, 6.0, 1.0, Color(1.0, 0.45, 0.85, 0.45))
	ink.draw_canvas_ring(probe_end.x, probe_end.y, 18.0, 2.0, Color(1.0, 0.45, 0.85, 0.9))
	# Query Bodies Under Mouse - a ring around whatever the cursor is sitting on.
	ink.draw_canvas_ring(mouse.x, mouse.y, 5.0, 1.0, Color(1.0, 1.0, 1.0, 0.45))
	for body: Node2D in picked:
		ink.draw_canvas_ring(body.global_position.x, body.global_position.y, 30.0, 3.0, Color(1.0, 1.0, 1.0, 0.9))
	# ShapeCast2D node - the rail it sweeps, and the disc parked at its safe fraction.
	var rail: Vector2 = $Gate.global_position
	var reach: Vector2 = $Gate.target_position
	ink.draw_canvas_dashed_line(rail.x, rail.y, rail.x + reach.x, rail.y + reach.y, 10.0, 8.0, 1.0, Color(0.5, 0.7, 1.0, 0.45))
	ink.draw_canvas_ring(rail.x + reach.x * gate_travel, rail.y + reach.y * gate_travel, 16.0, 2.0, Color(0.5, 0.7, 1.0, 0.9))
	$HudLayer/Readout.text = "under cursor %d - in circle %d - disc travel %.2f - gate sweep %.2f - gate touching %d" % [picked.size(), nearby.size(), travel, gate_travel, gate_count]

# [b]Raycast Lab[/b] - six ways to ask the physics world a question, all drawn live. [b]Yellow[/b] is a RayCast2D NODE sweeping for whatever it can see. [b]Cyan[/b] is Cast Ray Into, firing ONE ray at your cursor and storing the result, which the Ray Result verbs then read for the hit point, the surface normal, and whether it was a target - three facts, one cast. [b]Green[/b] is Query Bodies In Circle collecting everything within 130px; [b]white[/b] is Query Bodies Under Mouse. [b]Pink[/b] is Cast Circle Motion Into - how far a disc could slide before it jams, which is how you move something fast without it tunnelling through a wall. [b]Blue[/b] is a ShapeCast2D sweeping the corridor: a ray with THICKNESS, parked at its safe fraction.
