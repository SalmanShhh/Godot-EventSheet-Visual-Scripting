# A fixture scene the transform readings open: an arm inside a scaled body, a mirrored enemy and a
# hitbox scaled unevenly and turned. Its rows are the maths and the moves written by hand, so the
# same file measures both the lift and the facts the head says about the scene around it.
extends Node2D

var hp := 100.0
var max_hp := 100.0
var zoom := 1.0
var heading := 0.0


func _process(delta: float) -> void:
	hp = clampf(hp, 0.0, max_hp)
	zoom = lerp(zoom, 1.5, 0.1)
	heading = wrapf(heading, 0.0, 360.0)
	position += transform.x * 240.0 * delta
	global_position += Vector2.RIGHT * 20.0 * delta
	rotation = rotate_toward(rotation, global_position.angle_to_point(Vector2.ZERO), deg_to_rad(180.0) * delta)
