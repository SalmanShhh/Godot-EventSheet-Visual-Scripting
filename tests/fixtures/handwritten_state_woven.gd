# A machine that is NOT the canonical shape, kept as a fixture because staying honest code is the
# promise: the arms of this `match` are not in the order the compiler writes them, one of them binds
# a name, and the states are reached through a helper the file wrote itself. None of that lifts to
# the state rows, and none of it is allowed to move a byte either.
extends Node

enum State { CLOSED, OPENING, OPEN }

var state: State = State.CLOSED
var elapsed: float = 0.0


func _process(delta: float) -> void:
	match state:
		State.CLOSED:
			elapsed = 0.0
		var pending:
			elapsed += delta
			if elapsed > 1.0:
				_enter(State.OPEN if pending == State.OPENING else State.CLOSED)


func _enter(next: State) -> void:
	state = next
	elapsed = 0.0
