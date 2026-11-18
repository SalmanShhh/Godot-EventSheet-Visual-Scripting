extends CharacterBody2D

enum State { PATROL, CHASE, FLEE }

var state := State.PATROL
var hp := 100


func _physics_process(delta):
	match state:
		State.PATROL:
			patrol_step(delta)
			if can_see_player():
				state = State.CHASE
		State.CHASE:
			chase_step(delta)
			if hp < 20:
				state = State.FLEE
		State.FLEE:
			if not can_see_player():
				state = State.PATROL


func patrol_step(delta: float) -> void:
	velocity = Vector2.RIGHT * 60.0


func chase_step(delta: float) -> void:
	velocity = Vector2.RIGHT * 120.0


func can_see_player() -> bool:
	return false
