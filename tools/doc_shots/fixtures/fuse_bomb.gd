extends Node2D

var hp: int = 10


func _ready() -> void:
	if Engine.is_editor_hint():
		hp = 1
	set_physics_process(false)
	set_process(true)
	set_process_input(false)
	process_mode = PROCESS_MODE_DISABLED


func _exit_tree() -> void:
	hp = 0


func _draw() -> void:
	draw_line(Vector2(0, 0), Vector2(100, 0), Color.RED)
	draw_rect(Rect2(0, 0, 10, 10), Color.BLUE)
	draw_circle(Vector2(4, 4), 2.0, Color.GREEN)
	queue_redraw()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST:
			hp = 1
