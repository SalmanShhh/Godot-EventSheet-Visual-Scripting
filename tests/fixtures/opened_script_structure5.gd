extends Node2D

var trail_color: Color = Color.RED
var alive: bool = false


func _enter_tree() -> void:
	alive = true


func _draw() -> void:
	draw_line(Vector2(0, 0), Vector2(100, 0), trail_color)
	draw_circle(Vector2(0, 0), 8.0, trail_color)


func _exit_tree() -> void:
	alive = false


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			alive = false
		NOTIFICATION_APPLICATION_RESUMED:
			alive = true
		NOTIFICATION_WM_CLOSE_REQUEST:
			if alive:
				alive = false
