extends CharacterBody2D

## The player. Arrow keys or WASD move, space jumps, and the sprite faces the way we are going.

const SPEED: float = 220.0
const JUMP_VELOCITY: float = -380.0
const COYOTE_TIME: float = 0.12

@export var double_jump_allowed: bool = true
@export var max_health: int = 3

var health: int = 3
var jumps_left: int = 1
var coyote_timer: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var jump_sound: AudioStreamPlayer2D = $JumpSound


func _ready() -> void:
	health = max_health
	add_to_group("player")


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += 980.0 * delta
		coyote_timer -= delta
	else:
		coyote_timer = COYOTE_TIME
		jumps_left = 2 if double_jump_allowed else 1
	var direction: float = Input.get_axis("ui_left", "ui_right")
	velocity.x = direction * SPEED
	if direction < 0.0:
		sprite.flip_h = true
	if direction > 0.0:
		sprite.flip_h = false
	if Input.is_action_just_pressed("ui_accept"):
		try_to_jump()
	move_and_slide()


func try_to_jump() -> void:
	if coyote_timer <= 0.0 and jumps_left <= 0:
		return
	velocity.y = JUMP_VELOCITY
	jumps_left -= 1
	coyote_timer = 0.0
	jump_sound.play()


func take_damage(amount: int) -> void:
	health -= amount
	modulate = Color(1.0, 0.4, 0.4)
	if health <= 0:
		die()


func die() -> void:
	set_physics_process(false)
	queue_free()
