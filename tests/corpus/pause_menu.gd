extends CanvasLayer

## The pause menu. Escape opens and closes it, the buttons say which slot they belong to, and the
## engine's own notifications keep the rest of the game honest about being paused.

@export var slot_count: int = 3

var is_open: bool = false

@onready var resume_button: Button = $Panel/Resume
@onready var quit_button: Button = $Panel/Quit
@onready var save_timer: Timer = $SaveTimer
@onready var panel: Panel = $Panel


func _ready() -> void:
	resume_button.pressed.connect(_on_resume_pressed.bind(0))
	quit_button.pressed.connect(_on_quit_pressed.bind(slot_count - 1))
	save_timer.timeout.connect(_on_save_due.bind("autosave", 2))
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle()
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("ui_down", true):
		focus_next()
	if event.is_action_released("ui_accept"):
		confirm()
	if event.is_action("ui_page_down"):
		print("page")


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_PAUSED:
			panel.modulate = Color(0.8, 0.8, 0.9)
		NOTIFICATION_UNPAUSED:
			panel.modulate = Color(1.0, 1.0, 1.0)
		NOTIFICATION_WM_CLOSE_REQUEST:
			save_and_quit()
		NOTIFICATION_PREDELETE:
			print("pause menu gone")


func _on_resume_pressed(slot: int) -> void:
	print(slot)
	confirm()


func _on_quit_pressed(slot: int) -> void:
	print(slot)
	save_and_quit()


func _on_save_due(reason: String, retries: int) -> void:
	print(reason)
	print(retries)


func toggle() -> void:
	is_open = not is_open
	get_tree().paused = is_open
	visible = is_open


func focus_next() -> void:
	quit_button.grab_focus()


func confirm() -> void:
	hide()


func save_and_quit() -> void:
	get_tree().quit()
