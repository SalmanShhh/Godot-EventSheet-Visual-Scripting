extends CharacterBody2D

enum State { PATROL, CHASE, STAGGER }

signal state_changed(from_state: int, to_state: int)

var state_entered_msec: int = Time.get_ticks_msec()
var previous_state: State = State.PATROL
var state: State = State.PATROL:
	set(value):
		if value == state:
			return
		var was: int = state
		previous_state = was
		state = value
		state_entered_msec = Time.get_ticks_msec()
		state_changed.emit(was, value)


func _ready() -> void:
	state_changed.connect(_on_state_changed)


func _process(_delta: float) -> void:
	if state == State.PATROL:
		state = State.CHASE
	if state == State.STAGGER and (Time.get_ticks_msec() - state_entered_msec) / 1000.0 > 1.0:
		state = State.PATROL
	if previous_state == State.CHASE:
		state = State.STAGGER


func _on_state_changed(from_state: int, to_state: int) -> void:
	if from_state == State.STAGGER:
		state = State.PATROL
	if to_state == State.CHASE:
		state = State.PATROL
