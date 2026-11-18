extends Node

var window_open := false
var window_until := 0.0


func open_dodge_window(seconds: float) -> void:
	window_open = true
	window_until = Time.get_ticks_msec() / 1000.0 + seconds


func answer_the_window(event: InputEvent) -> void:
	if window_open and event.is_action_pressed("dodge"):
		var remaining := window_until - Time.get_ticks_msec() / 1000.0
		if remaining > 0.15:
			print("good")
