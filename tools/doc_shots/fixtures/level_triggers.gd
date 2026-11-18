extends Node2D


func _ready() -> void:
	$Gate.body_entered.connect(_on_gate_body_entered)
	$Timer.timeout.connect(_on_timer_timeout)
	$Slider.value_changed.connect(_on_slider_value_changed)


func _on_gate_body_entered(body: Node2D) -> void:
	$Banner.text = "Gate opened"


func _on_timer_timeout() -> void:
	$Hint.text = "Hurry"
	$Hint.show()


func _on_slider_value_changed(value: float) -> void:
	$Meter.value = value
