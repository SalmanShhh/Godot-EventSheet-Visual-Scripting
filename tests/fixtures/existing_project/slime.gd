extends CharacterBody2D

enum State {IDLE, WANDER, CHASE, HURT}

const GRAVITY = 900

@export var speed = 60
@export var chase_range = 180.0

var state = State.IDLE
var target: Node2D = null
var _wander_dir = 1
var _state_time = 0.0

@onready var anim = $AnimationPlayer
@onready var eyes: RayCast2D = $Eyes


func _ready():
	$Hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	target = get_tree().get_first_node_in_group("player")


func _physics_process(delta):
	_state_time += delta
	velocity.y += GRAVITY * delta

	match state:
		State.IDLE:
			velocity.x = 0
			if _state_time > 2.0:
				change_state(State.WANDER)
		State.WANDER:
			velocity.x = speed * _wander_dir
			if is_on_wall() or not eyes.is_colliding():
				_wander_dir *= -1
			if _can_see_target():
				change_state(State.CHASE)
		State.CHASE:
			if not _can_see_target():
				change_state(State.IDLE)
			else:
				velocity.x = sign(target.global_position.x - global_position.x) * speed * 1.5
		State.HURT:
			velocity.x = move_toward(velocity.x, 0, 400 * delta)
			if _state_time > 0.4:
				change_state(State.CHASE)

	move_and_slide()


func change_state(new_state):
	state = new_state
	_state_time = 0.0
	match new_state:
		State.IDLE, State.HURT:
			anim.play("idle" if new_state == State.IDLE else "hurt")
		State.WANDER, State.CHASE:
			anim.play("walk")


func _can_see_target():
	return target != null and global_position.distance_to(target.global_position) < chase_range


func _on_hurtbox_area_entered(area):
	if area.is_in_group("player_attack"):
		velocity = Vector2(200 * sign(global_position.x - area.global_position.x), -150)
		change_state(State.HURT)
