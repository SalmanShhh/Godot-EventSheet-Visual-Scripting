class_name BoomerLevel
extends Node3D
## A small shooter level: a red keycard, the door that wants it, two grunts that turn on each other, a respawning pickup, a secret and the exit tally.

## How many grunts the level started with.
@export var enemies_total: int = 2
var keys: Array = []
var kills: int = 0
var level_over: bool = false
var level_seconds: float = 0.0
## The time to beat, shown beside your own.
@export var par_seconds: float = 60.0
var secrets_found: Array = []
## How many secrets this level hides.
@export var secrets_total: int = 1

func _ready() -> void:
	get_node("RedCard").body_entered.connect(_on_redcard_body_entered)
	get_node("DoorTrigger").body_entered.connect(_on_doortrigger_body_entered)
	get_node("SecretRoom").body_entered.connect(_on_secretroom_body_entered)
	get_node("Exit").body_entered.connect(_on_exit_body_entered)
	print("Boomer Level - WASD/arrows move, mouse looks, Space jumps (hold it on landing to bunny hop), Tab throws a rocket, Esc frees the mouse.")

func _physics_process(delta: float) -> void:
	if level_over == false:
		level_seconds += delta

func _process(delta: float) -> void:
	$Player/FPSController.bob_with_movement($Player/Head/Weapon)
	$Player/FPSController.sway_with_mouse($Player/Head/Weapon)
	if Input.is_action_just_pressed(&"ui_focus_next"):
		var __blast_rocket = PhysicsShapeQueryParameters3D.new()
		var __ball_rocket = SphereShape3D.new()
		__ball_rocket.radius = 6.0
		__blast_rocket.shape = __ball_rocket
		__blast_rocket.transform = Transform3D(Basis(), $Grunt1.global_position)
		__blast_rocket.collision_mask = 1
		for __caught_rocket in get_world_3d().direct_space_state.intersect_shape(__blast_rocket, 32):
			var __body_rocket = __caught_rocket.collider
			var __away_rocket = __body_rocket.global_position - $Grunt1.global_position
			var __falloff_rocket = clampf(1.0 - __away_rocket.length() / 6.0, 0.0, 1.0)
			if __body_rocket.has_method("take_damage"):
				__body_rocket.take_damage(35 * __falloff_rocket)
			if __body_rocket is CharacterBody3D:
				__body_rocket.velocity += __away_rocket.normalized() * 10.0 * __falloff_rocket
			elif __body_rocket is RigidBody3D:
				__body_rocket.apply_impulse(__away_rocket.normalized() * 10.0 * __falloff_rocket)
	$HudLayer/Hud.text = "Keys %d   Secrets %d of %d   %s" % [keys.size(), secrets_found.size(), secrets_total, $RedDoor.locked_hint]

func _on_redcard_body_entered(body: Node) -> void:
	keys.append("red_key")
	$RedCard.hide()
	$RedCard.set_deferred("monitoring", false)

func _on_doortrigger_body_entered(body: Node) -> void:
	var __door_level = $RedDoor
	if str(__door_level.needs_key) in keys:
		__door_level.open_door()
	else:
		__door_level.locked_door_tried(str(__door_level.needs_key))

func _on_secretroom_body_entered(body: Node) -> void:
	if not "SecretRoom" in secrets_found:
		secrets_found.append("SecretRoom")

func _on_exit_body_entered(body: Node) -> void:
	level_over = true
	$HudLayer/Tally.text = "Kills %d of %d   Secrets %d of %d   Time %s of %s" % [kills, enemies_total, secrets_found.size(), secrets_total, ("%02d:%02d" % [int(level_seconds) / 60, int(level_seconds) % 60]), ("%02d:%02d" % [int(par_seconds) / 60, int(par_seconds) % 60])]

## @ace_hidden
func count_kill() -> void:
	kills += 1

# Boomer Level: WASD moves, the mouse looks, Tab throws a rocket at the grunts. Find the red keycard, open the door, take the exit.
