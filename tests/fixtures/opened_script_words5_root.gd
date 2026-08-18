extends Node2D

signal hit(damage: int)

var hp: int = 10

@onready var sprite: AnimatedSprite2D = $Sprite


func _ready() -> void:
	if Engine.is_editor_hint():
		hp = 1
	set_physics_process(false)
	set_process(true)
	set_process_input(false)
	process_mode = PROCESS_MODE_DISABLED
	get_tree().create_timer(2.0).timeout.connect(func(): explode())
	hit.emit(3)
	take_damage(3, hp)


func _exit_tree() -> void:
	hp = 0


func _draw() -> void:
	draw_line(Vector2(0, 0), Vector2(100, 0), Color.RED)
	draw_rect(Rect2(0, 0, 10, 10), Color.BLUE)
	draw_circle(Vector2(4, 4), 2.0, Color.GREEN)
	queue_redraw()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			hp = 0
		NOTIFICATION_WM_CLOSE_REQUEST:
			hp = 1


func explode() -> void:
	hp = 0
	sprite.play("burst", 2.0)


func take_damage(amount: int, source: Node) -> void:
	hp -= amount
	if source == null:
		hp = 0
