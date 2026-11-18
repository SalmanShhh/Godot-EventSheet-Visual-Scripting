extends Node2D
## A guard that walks its route and waits at every stop.

## How long the guard waits at each stop, in seconds.
@export var wait_time: float = 2.0

var stop_index: int = 0


func _ready() -> void:
	## Every guard starts at the first stop of the route.
	stop_index = 0
	# TODO: tune the wait before the first playtest
	# The route is kept short on purpose
	wait_time = 2.0
