extends CharacterBody2D

## A hand-written player as a user writes one: a function that switches on its own state, each
## branch asking a question of its own before it moves on.

enum State { IDLE, RUN, JUMP }

var state: State = State.IDLE


func _update_state() -> void:
	match state:
		State.IDLE:
			if absf(velocity.x) > 10.0:
				state = State.RUN
		State.RUN:
			if absf(velocity.x) <= 10.0:
				state = State.IDLE
		State.JUMP:
			if is_on_floor():
				state = State.IDLE
	if not is_on_floor():
		state = State.JUMP
