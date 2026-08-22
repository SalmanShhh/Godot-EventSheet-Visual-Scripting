class_name ComboFighter
extends Node2D

var cancels: int = 0
var combo: Array = []
var combo_timer: float = 0.0
var hits: int = 0
var punch_input: int = -1

func _process(delta: float) -> void:
	combo_timer -= delta
	$Info.text = "J = punch   ·   K = kick   ·   %d hit frames   ·   %d cancels" % [hits, cancels]
	if combo_timer <= 0.0:
		combo.clear()

func _unhandled_input(event: InputEvent) -> void:
	if (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_J):
		punch_input = Engine.get_physics_frames() + 6
	if (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_K):
		press("kick")

func _physics_process(delta: float) -> void:
	if (Engine.get_physics_frames() <= punch_input):
		punch_input = Engine.get_physics_frames() - 1
		press("punch")

## @ace_hidden
func press(button: String) -> void:
	combo.append(button)
	combo_timer = 0.5
	match ",".join(combo):
		"punch,punch,kick":
			$AnimationPlayer.play("uppercut")
			combo.clear()
		"kick,kick":
			$AnimationPlayer.play("sweep")
			combo.clear()
		"punch,kick,punch":
			$AnimationPlayer.play("spin")
			combo.clear()

## @ace_hidden
func try_cancel() -> bool:
	if $AnimationPlayer.current_animation == "uppercut" and $AnimationPlayer.current_animation_position > 0.3 and $AnimationPlayer.current_animation_position < 0.6:
		cancels += 1
		return true
	return false

## @ace_hidden
func _on_hit_frame() -> void:
	hits += 1
	Engine.time_scale = 0.1
	await get_tree().create_timer(0.05, true, false, true).timeout
	Engine.time_scale = 1.0

# [b]Combo Fighter[/b] - the four pieces a fighting game is made of, each one a row. Press J (punch) and K (kick): the inputs collect into a rolling list with a 0.5 s window, and the move the list spells plays its animation. The uppercut's method track calls the hit frame, which freezes the whole game for 0.05 s - that is hit-stop. Between 0.3 s and 0.6 s of a move the next one may cancel it. A press made a few frames too early is buffered rather than dropped. Open this file as a sheet: every shape reads back as the row that writes it.
