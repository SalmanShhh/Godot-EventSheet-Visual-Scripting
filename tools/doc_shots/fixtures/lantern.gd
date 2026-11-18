extends Node2D

@onready var hand: Marker2D = $Player/Hand
@onready var rail: PathFollow2D = $Track/Runner
@export var rope_length: float = 80.0
@export var bar_length: float = 64.0
@export var follow_speed: float = 10.0
var anchor: Node2D
var hitch: Node2D
var lead: Node2D
var ground: Node2D
var pin_offset: Vector2 = Vector2(0, -20)


func _physics_process(delta: float) -> void:
	global_position = anchor.global_position + (global_position - anchor.global_position).limit_length(rope_length)
	global_position = hitch.global_position + (global_position - hitch.global_position).normalized() * bar_length
	global_position = global_position.lerp(lead.global_position, follow_speed * delta)
	rotation = lead.rotation
	global_position = hand.global_position + pin_offset
	global_position = rail.global_position
	global_position.x = ground.global_position.x
	global_position.y = ground.global_position.y
	scale = anchor.scale
