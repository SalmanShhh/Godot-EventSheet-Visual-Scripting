extends Node2D

## A door with four states. Everything about it is decided in one match block, which is how most
## hand-written state machines in Godot projects are actually spelled.

signal opened
signal locked_door_rattled

enum State {CLOSED, OPENING, OPEN, LOCKED}

@export var needs_key: String = "brass_key"
@export var open_speed: float = 2.0

var state: State = State.CLOSED
var progress: float = 0.0


func _process(delta: float) -> void:
	match state:
		State.CLOSED:
			pass
		State.OPENING:
			progress += delta * open_speed
			position.y = -progress * 32.0
			if progress >= 1.0:
				state = State.OPEN
				opened.emit()
		State.OPEN:
			pass
		State.LOCKED:
			pass


func try_open(inventory: Array) -> void:
	if state != State.CLOSED:
		return
	if needs_key != "" and not inventory.has(needs_key):
		state = State.LOCKED
		locked_door_rattled.emit()
		return
	state = State.OPENING


func relock() -> void:
	state = State.LOCKED
	progress = 0.0
	position.y = 0.0


func state_name() -> String:
	match state:
		State.CLOSED:
			return "closed"
		State.OPENING:
			return "opening"
		State.OPEN:
			return "open"
	return "locked"
