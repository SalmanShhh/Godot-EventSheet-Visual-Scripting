extends Node2D

signal arrived

@export var speed: float = 600.0
@export var accel: float = 0.0
@export var gravity: float = 0.0
@export var range_px: float = 800.0
@export var rotate_speed: float = 90.0
@export var fire_rate: float = 0.5
@export var turn_rate: float = 4.0
var velocity: Vector2 = Vector2.ZERO
var start: Vector2 = Vector2.ZERO
var destination: Vector2 = Vector2.ZERO
var moving: bool = false
var target: Node2D
var since_shot: float = 0.0
var screen: Vector2 = Vector2(1152, 648)
var anchor: Node2D
var pin_offset: Vector2 = Vector2(0, -20)


func _physics_process(delta: float) -> void:
	speed += accel * delta
	velocity = Vector2.RIGHT.rotated(rotation) * speed
	velocity.y += gravity * delta
	position += velocity * delta
	if position.distance_to(start) > range_px:
		queue_free()


func aim(delta: float) -> void:
	var nearest = null
	var best = range_px
	for e in get_tree().get_nodes_in_group("enemy"):
		var d = global_position.distance_to(e.global_position)
		if d < best:
			best = d
			nearest = e
	target = nearest
	if target:
		rotation = lerp_angle(rotation, global_position.angle_to_point(target.global_position), turn_rate * delta)


func go_to(p: Vector2) -> void:
	destination = p
	moving = true


func glide(delta: float) -> void:
	position = position.move_toward(destination, speed * delta)
	if position.distance_to(destination) < 1.0:
		moving = false
		arrived.emit()


func decorate(delta: float) -> void:
	rotation_degrees += rotate_speed * delta
	position.x = wrapf(position.x, 0.0, screen.x)
	position = position.clamp(Vector2.ZERO, screen)
	global_position = anchor.global_position + pin_offset
	rotation = anchor.rotation


func collect() -> void:
	var tw: Tween = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 1.0)
	tw.tween_callback(queue_free)
