class_name HierarchyPlayground
extends Node3D

var crates_settled: bool = false
var mounted: bool = false
var orbit_deg: float = 0.0
var squad_hp: int = 0


func _ready() -> void:
	equip(%Hat)
	%HealthBar.top_level = true
	heal_squad($Squad)


func _process(delta: float) -> void:
	if Input.is_action_just_pressed(&"ui_accept"):
		if mounted:
			dismount(%Rider)
		else:
			mount(%Rider)
		mounted = not mounted
	# The camera does nothing: its PARENT turns, and a child goes where its parent goes.
	orbit_deg = fmod(orbit_deg + 18.0 * delta, 360.0)
	$CameraPivot.rotation_degrees = Vector3(0.0, orbit_deg, 0.0)
	# The rider leans as it rides. The hat leans with it; the bar, ignoring the rider's
	# movement, has to be told where to stand - which is exactly what that flag costs.
	%Rider.rotation_degrees = Vector3(0.0, 0.0, sin(orbit_deg * 0.08) * 14.0)
	%HealthBar.global_position = %Rider.global_position + Vector3(0.0, 1.9, 0.0)
	%HealthBar.rotation = Vector3.ZERO
	$HudLayer/Readout.text = "rider's parent: %s   hat follows size: no   bar ignores movement: yes   squad hp: %d   crates settled: %s" % [%Rider.get_parent().name, squad_hp, "yes" if crates_settled else "no"]


func _physics_process(delta: float) -> void:
	if not crates_settled:
		for crate: Node3D in $Crates.get_children():
			var __down := PhysicsRayQueryParameters3D.create(
				crate.global_position + Vector3(0.0, 3.0, 0.0),
				crate.global_position - Vector3(0.0, 8.0, 0.0), 1)
			var __ground := get_world_3d().direct_space_state.intersect_ray(__down)
			if not __ground.is_empty():
				crate.global_position = __ground["position"] + Vector3(0.0, 0.5, 0.0)
		crates_settled = true


## @ace_hidden
func mount(rider: Node3D) -> void:
	rider.reparent($Horse/Saddle, false)


## @ace_hidden
func dismount(rider: Node3D) -> void:
	rider.reparent(get_tree().current_scene)


## @ace_hidden
func equip(hat: Node3D) -> void:
	hat.reparent(%Head)
	hat.top_level = true
	var __follow_hat := RemoteTransform3D.new()
	%Head.add_child(__follow_hat)
	__follow_hat.remote_path = __follow_hat.get_path_to(hat)
	__follow_hat.update_scale = false


## @ace_hidden
func heal_squad(leader: Node3D) -> void:
	squad_hp = 0
	for unit in leader.get_children():
		if unit.is_in_group("soldier"):
			unit.hp += 10
			squad_hp += unit.hp

# [b]Hierarchy Playground[/b] - everything a game does to the scene tree while it runs, in one room. [b]Space[/b] mounts the rider onto the horse's [b]Saddle[/b] and dismounts again: mounting SNAPS the rider to its new parent, dismounting hands it back to the layout keeping the place it stands in. The [b]hat[/b] is a child of the rider's head that follows position and angle but NOT size - the flag that Godot has no single property for, so a RemoteTransform3D drives it instead. The [b]health bar[/b] is still a child and still dies with the rider, but ignores its movement, which is why it never tilts. The [b]squad[/b] is healed by ONE walk over the leader's children. The [b]camera[/b] orbits because its parent pivot turns - it does nothing itself. The [b]crates[/b] each cast a ray down and park on whatever the ray found.
