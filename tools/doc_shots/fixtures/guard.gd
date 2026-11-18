extends CharacterBody2D

enum State { PATROL, HUNTING }

@export var detect_rate: float = 40.0
@export var calm_rate: float = 15.0
var suspicion: float = 0.0
var last_known: Vector2 = Vector2.ZERO
var state: State = State.PATROL
var player: Node2D


func _physics_process(delta: float) -> void:
	if _can_see(player) and not player.is_hidden:
		suspicion = minf(suspicion + detect_rate * delta, 100.0)
		last_known = player.global_position
	else:
		suspicion = maxf(suspicion - calm_rate * delta, 0.0)
	if suspicion >= 100.0:
		state = State.HUNTING


func _can_see(target: Node2D) -> bool:
	return target != null
