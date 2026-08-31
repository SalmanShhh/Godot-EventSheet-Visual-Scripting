# A hand-written state machine, written the way a tutorial writes one: an enum, a variable, and a
# `match` on it. Nothing here knows this plugin exists - that is the point of the fixture.
extends CharacterBody2D

enum State { PATROL, CHASE, STAGGER }

var state: State = State.PATROL
var previous_state: State = State.PATROL
var speed: float = 40.0


func _physics_process(delta: float) -> void:
	match state:
		State.PATROL:
			velocity.x = speed
			if _sees_player():
				state = State.CHASE
		State.CHASE:
			velocity.x = speed * 3.0
			if not _sees_player():
				state = State.PATROL
		State.STAGGER:
			velocity.x = 0.0
	move_and_slide()


func _sees_player() -> bool:
	return $Sight.has_overlapping_bodies()
