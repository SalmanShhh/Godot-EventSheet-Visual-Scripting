# The same machine written the OTHER way a person writes one: the state variable announces its own
# change through a setter, and a handler answers that announcement per state. No `match` anywhere -
# the questions are plain comparisons in `if`s.
extends Node2D

signal state_changed(from_state: int, to_state: int)

enum State { IDLE, ALERT, HUNT }

var state_entered_msec: int = 0
var previous_state: State = State.IDLE
var state: State = State.IDLE:
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


func _process(delta: float) -> void:
	if state == State.IDLE:
		state = State.ALERT
	if state == State.ALERT and (Time.get_ticks_msec() - state_entered_msec) / 1000.0 > 1.5:
		state = State.HUNT
	if previous_state == State.HUNT:
		self.state = State.IDLE


func _on_state_changed(from_state: int, to_state: int) -> void:
	if from_state == State.HUNT:
		$Siren.stop()
	if to_state == State.ALERT:
		$Siren.play()
