class_name InputControlsFixture
extends CharacterBody2D

## A player that reads the project's controls the ordinary way, plus the two shapes the sheet used to
## have no words for: a stick on a numbered gamepad, and a control the Input Map does not have.

var speed: float = 220.0


func _physics_process(delta: float) -> void:
	velocity.x = Input.get_axis(&"ui_left", &"ui_right") * speed
	if Input.is_action_just_pressed("ui_accept"):
		velocity.y = -420.0
	if Input.is_action_pressed("dash"):
		velocity.x *= 2.0
	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed and event.device == 0 and event.button_index == JOY_BUTTON_A:
		velocity.y = -420.0
	if event is InputEventScreenDrag:
		velocity.x = 0.0


func rebind_jump() -> void:
	var ev = await get_window().window_input
	InputMap.action_erase_events("ui_accept")
	InputMap.action_add_event("ui_accept", ev)
