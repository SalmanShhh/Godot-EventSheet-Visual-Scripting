extends Node2D
## A turret that turns toward its target and fires bursts. Every knob is tuned in the Inspector.

@export_category("Aiming")
@export var target: NodePath
@export_node_path("Marker2D") var muzzle: NodePath = NodePath("Muzzle")
@export_range(-180, 180, 1, "radians_as_degrees") var rest_angle: float = 0.0
@export_range(0, 1, 0.01, "exp", "hide_slider") var aim_smoothing: float = 0.2
@export_category("Firing")
@export_group("Bullet", "bullet_")
@export var bullet_speed = 400.0
@export var bullet_damage = 2
@export_range(1, 8, 1, "or_greater", "or_less") var bullet_count: int = 3
@export_group("")
@export var burst_delay = 0.6
@export_group("Sound")
@export_subgroup("Shot", "shot_")
@export_file_path("*.wav", "*.ogg") var shot_sound: String = ""
@export_exp_easing("attenuation", "positive_only") var shot_falloff: float = 1.0
@export_custom(PROPERTY_HINT_RANGE, "0,24,0.5,or_greater", PROPERTY_USAGE_DEFAULT) var shot_pitch_steps: float = 0.0

var _cooldown = 0.0


func _process(delta):
	_cooldown -= delta
