extends CharacterBody2D

enum State { PATROL, CHASE }

var state = State.PATROL
var speed = 90.0
var target = null


func _physics_process(delta):
	if state == State.PATROL:
		patrol(delta)
	else:
		chase(delta)


func patrol(delta):
	velocity.x = speed * delta
	move_and_slide()


func chase(delta):
	if target == null:
		return
	velocity = (target.global_position - global_position).normalized() * speed
	move_and_slide()


func see_player(body):
	target = body
	state = State.CHASE
