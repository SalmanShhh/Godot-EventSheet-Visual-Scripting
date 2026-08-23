class_name RaycastLab3DDemo
extends Node3D

var turret_deg: float = 0.0
var orbit_deg: float = 0.0
var radar_hit: bool = false
var radar_end: Vector3 = Vector3(0.0, 0.0, 0.0)
var radar_normal: Vector3 = Vector3(0.0, 0.0, 0.0)
var pick: Dictionary = {}
var pick_point: Vector3 = Vector3(0.0, 0.0, 0.0)
var pick_normal: Vector3 = Vector3(0.0, 0.0, 0.0)
var pick_face: int = -1
var pick_on_target: bool = false
var nearby: Array = []
var in_box: Array = []
var at_point: Array = []
var travel: float = 1.0
var probe_end: Vector3 = Vector3(0.0, 0.0, 0.0)
var sweep_count: int = 0
var sweep_travel: float = 1.0


func _physics_process(delta: float) -> void:
	turret_deg = fmod(turret_deg + 40.0 * delta, 360.0)
	orbit_deg += (Input.get_axis("ui_left", "ui_right")) * 45.0 * delta
	radar_hit = false
	pick_on_target = false
	pick_face = -1
	$CameraArm.rotation_degrees = Vector3(0.0, orbit_deg, 0.0)
	$Turret/Radar.target_position = Vector3(sin(deg_to_rad(turret_deg)), 0.0, cos(deg_to_rad(turret_deg))) * 14.0
	$Turret/Radar.force_raycast_update()
	radar_end = $Turret.global_position + Vector3(sin(deg_to_rad(turret_deg)), 0.0, cos(deg_to_rad(turret_deg))) * 14.0
	var __cam_pick := get_viewport().get_camera_3d()
	var __mouse_pick := get_viewport().get_mouse_position()
	var __from_pick := __cam_pick.project_ray_origin(__mouse_pick)
	var __to_pick := __from_pick + __cam_pick.project_ray_normal(__mouse_pick) * 200.0
	var __rq_pick := PhysicsRayQueryParameters3D.create(__from_pick, __to_pick, 1, [])
	__rq_pick.collide_with_areas = false
	pick = get_world_3d().direct_space_state.intersect_ray(__rq_pick)
	var __ss_zone := SphereShape3D.new()
	__ss_zone.radius = 7.0
	var __sq_zone := PhysicsShapeQueryParameters3D.new()
	__sq_zone.shape = __ss_zone
	__sq_zone.transform = Transform3D(Basis(), $Turret.global_position)
	__sq_zone.collision_mask = 1
	nearby = []
	for __hit_zone in get_world_3d().direct_space_state.intersect_shape(__sq_zone, 16):
		nearby.append(__hit_zone.get("collider"))
	var __bs_bay := BoxShape3D.new()
	__bs_bay.size = Vector3(8.0, 4.0, 8.0)
	var __sq_bay := PhysicsShapeQueryParameters3D.new()
	__sq_bay.shape = __bs_bay
	__sq_bay.transform = Transform3D(Basis(), Vector3(9.0, 1.0, -9.0))
	__sq_bay.collision_mask = 1
	in_box = []
	for __hit_bay in get_world_3d().direct_space_state.intersect_shape(__sq_bay, 16):
		in_box.append(__hit_bay.get("collider"))
	var __pq_spot := PhysicsPointQueryParameters3D.new()
	__pq_spot.position = $Turret.global_position - Vector3(0.0, 1.05, 0.0)
	__pq_spot.collide_with_areas = false
	at_point = []
	for __hit_spot in get_world_3d().direct_space_state.intersect_point(__pq_spot, 8):
		at_point.append(__hit_spot.get("collider"))
	var __ss_probe := SphereShape3D.new()
	__ss_probe.radius = 0.6
	var __sq_probe := PhysicsShapeQueryParameters3D.new()
	__sq_probe.shape = __ss_probe
	__sq_probe.transform = Transform3D(Basis(), $Turret.global_position)
	__sq_probe.motion = Vector3(cos(deg_to_rad(turret_deg)), 0.0, -sin(deg_to_rad(turret_deg))) * 12.0
	__sq_probe.collision_mask = 1
	var __cm_probe := get_world_3d().direct_space_state.cast_motion(__sq_probe)
	travel = __cm_probe[0] if __cm_probe.size() > 0 else 1.0
	probe_end = $Turret.global_position + Vector3(cos(deg_to_rad(turret_deg)), 0.0, -sin(deg_to_rad(turret_deg))) * 12.0 * travel
	$Sweep.force_shapecast_update()
	sweep_count = $Sweep.get_collision_count()
	sweep_travel = $Sweep.get_closest_collision_safe_fraction()
	if $Turret/Radar.is_colliding():
		radar_hit = true
		radar_end = $Turret/Radar.get_collision_point()
		radar_normal = $Turret/Radar.get_collision_normal()
	if not pick.is_empty():
		pick_point = pick.get("position", Vector3.ZERO)
		pick_normal = pick.get("normal", Vector3.ZERO)
		pick_face = pick.get("face_index", -1)
		if (pick.get("collider", null) != null and pick["collider"].is_in_group("targets")):
			pick_on_target = true


func _process(delta: float) -> void:
	# The turning turret's ray: a yellow beam to whatever stopped it, and a marker on the spot.
	aim_beam($Beams/RadarBeam, $Turret.global_position, radar_end)
	$Markers/RadarMark.visible = radar_hit
	$Markers/RadarMark.global_position = radar_end
	# The cursor pick: the headline 3D cast. Cyan beam from the camera to whatever is under the
	# pointer, and the marker turns orange when that thing is a target.
	$Markers/PickMark.visible = not pick.is_empty()
	$Markers/PickMark.global_position = pick_point
	$Markers/PickMark.scale = Vector3.ONE * (1.6 if pick_on_target else 1.0)
	# NOT a beam from the camera to the cursor: you are looking straight down that ray, so it draws
	# as a stray line skidding over the floor. The surface NORMAL at the hit is the fact worth
	# showing, and it stands up off whatever was struck.
	aim_beam($Beams/PickBeam, pick_point, pick_point + pick_normal * 1.8)
	# Where a rolling 0.6m ball would jam, and where the thick sweep runs out of clear road.
	$Markers/ProbeMark.global_position = probe_end
	aim_beam($Beams/ProbeBeam, $Turret.global_position, probe_end)
	$Markers/SweepMark.global_position = $Sweep.global_position + $Sweep.target_position * sweep_travel
	aim_beam($Beams/SweepBeam, $Sweep.global_position, $Sweep.global_position + $Sweep.target_position)
	# Query Bodies In Sphere: park a ring of markers on whatever the sphere caught.
	var ring: Node3D = $Markers/ZoneMarks
	for slot: int in ring.get_child_count():
		var mark: Node3D = ring.get_child(slot)
		mark.visible = slot < nearby.size()
		if mark.visible:
			mark.global_position = (nearby[slot] as Node3D).global_position + Vector3(0.0, 1.6, 0.0)
	$HudLayer/Readout.text = "cursor: %s   face %d   in sphere %d   in box %d   under turret %d   ball travel %.2f   sweep %.2f (%d)" % ["TARGET" if pick_on_target else ("scenery" if not pick.is_empty() else "sky"), pick_face, nearby.size(), in_box.size(), at_point.size(), travel, sweep_travel, sweep_count]


## @ace_hidden
func aim_beam(beam: Node3D, from: Vector3, to: Vector3) -> void:
	var span: float = from.distance_to(to)
	beam.visible = span > 0.05
	if not beam.visible:
		return
	beam.global_position = (from + to) * 0.5
	beam.look_at(to, Vector3.UP)
	# The mesh is a unit box on -Z, so scaling z by the span turns it into a beam of that length.
	beam.scale = Vector3(1.0, 1.0, span)

# [b]Raycast Lab 3D[/b] - the same six questions as the 2D room, in the dimension where two of them only exist. [b]Cyan[/b] is [b]Cast Ray From Mouse Into[/b]: the camera projects a ray through your cursor and stores what it finds, which is the whole of click-to-select in 3D - the readout even names the mesh TRIANGLE it struck (Ray Result Face Index, a 3D-only fact). [b]Yellow[/b] is a RayCast3D NODE on the turning turret. [b]Blue[/b] is a ShapeCast3D sweeping with THICKNESS, parked at its safe fraction. [b]Pink[/b] is Cast Sphere Motion Into - how far a ball could roll before it jams. [b]Green[/b] rings mark what Query Bodies In Sphere caught. The camera orbits rather than being mouse-driven on purpose: a captured pointer has no screen position to project a picking ray through.
