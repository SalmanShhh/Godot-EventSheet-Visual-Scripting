@tool
extends Node2D
## Marks a rectangle enemies spawn in. Draws itself in the editor so the level designer can see it.

@export var size := Vector2(256, 128):
	set(value):
		size = value
		queue_redraw()
@export var color := Color(1, 0.5, 0, 0.35):
	set(value):
		color = value
		queue_redraw()
@export var spawn_count := 4


func _draw():
	if not Engine.is_editor_hint():
		return
	draw_rect(Rect2(-size / 2, size), color)
	draw_rect(Rect2(-size / 2, size), color.lightened(0.4), false, 2.0)


func _get_configuration_warnings():
	var warnings := PackedStringArray()
	if spawn_count <= 0:
		warnings.append("Spawn count should be at least 1.")
	return warnings


func random_point() -> Vector2:
	var half := size / 2
	return global_position + Vector2(randf_range(-half.x, half.x), randf_range(-half.y, half.y))
