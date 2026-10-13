extends CharacterBody2D
## Top-down player. Reads input, moves, dashes, and tells the HUD what happened.

signal health_changed(new_health: int, max_health: int)
signal died
signal dashed(direction)

@export_category("Movement")
@export_group("Walking")
@export var walk_speed := 180.0
@export var acceleration := 1200.0
@export var friction := 900.0
@export_group("Dash", "dash_")
@export var dash_speed := 520.0
@export var dash_time := 0.18
@export_range(0.0, 3.0, 0.05, "suffix:s") var dash_cooldown := 0.8
@export_category("Combat")
@export var max_health: int = 5
@export_flags_2d_physics var hurt_layers := 2
@export var hit_flash_color := Color(1, 0.3, 0.3)

var health: int
var _dash_left := 0.0
var _dash_ready := true
var _facing := Vector2.RIGHT

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _cooldown: Timer = %DashCooldown


func _ready():
	health = max_health
	_cooldown.wait_time = dash_cooldown
	_cooldown.timeout.connect(func(): _dash_ready = true)


func _physics_process(delta):
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input != Vector2.ZERO:
		_facing = input.normalized()

	if _dash_left > 0.0:
		_dash_left -= delta
		velocity = _facing * dash_speed
	elif input == Vector2.ZERO:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	else:
		velocity = velocity.move_toward(input * walk_speed, acceleration * delta)

	if Input.is_action_just_pressed("dash") and _dash_ready:
		_start_dash()

	move_and_slide()
	_update_animation(input)


func _start_dash():
	_dash_left = dash_time
	_dash_ready = false
	_cooldown.start()
	dashed.emit(_facing)


func _update_animation(input: Vector2) -> void:
	if input.x != 0:
		_sprite.flip_h = input.x < 0
	_sprite.play("run" if input != Vector2.ZERO else "idle")


func take_hit(amount: int = 1) -> void:
	health = clampi(health - amount, 0, max_health)
	health_changed.emit(health, max_health)
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", hit_flash_color, 0.05)
	tween.tween_property(_sprite, "modulate", Color.WHITE, 0.15)
	if health == 0:
		died.emit()
		set_physics_process(false)
