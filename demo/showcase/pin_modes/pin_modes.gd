class_name PinModesDemo
extends Node2D

var t: float = 0.0

func _ready() -> void:
	$Lantern/Pin.pin_rope($Post, 90.0)
	$Cart/Pin.pin_bar($Engine, 70.0)
	$CamTarget/Pin.pin_soft($Player, 3.0)
	$Hat/Pin.pin_spring($Player/Head, 140.0, 0.6)
	$Shadow/Pin.pin_x_to($Player)
	$Sword/Pin.pin_to_point($Player, "Hand")

func _physics_process(delta: float) -> void:
	t += delta
	$Post.position = Vector2(250.0 + sin(t * 1.2) * 190.0, 180.0)
	$Engine.position = Vector2(180.0 + fmod(t * 90.0, 760.0), 560.0)
	$Player.position = Vector2(600.0 + sin(t * 0.8) * 280.0, 420.0)
	$Player.rotation = sin(t * 0.8) * 0.25
	# Gravity for the lantern alone. The rope never pushes - it only stops the fall once the
	# line is straight, which is exactly the difference between a rope and a bar.
	$Lantern.position.y = minf($Lantern.position.y + 220.0 * delta, 620.0)

func _process(delta: float) -> void:
	$Screen.text = "PIN MODES   rope %.0f / 90 px   bar %.0f / 70 px   soft lag %.0f px" % [$Lantern.global_position.distance_to($Post.global_position), $Cart.global_position.distance_to($Engine.global_position), $CamTarget.global_position.distance_to($Player.global_position)]

# [b]Pin Modes[/b] - six ways one object can ride another, running at once. The sheet moves only the ANCHORS (the post, the engine, the walker); everything else is a Pin behavior in a different mode. Watch the rope go slack and then snap taut, the bar hold its length through every turn, the camera target trail behind, the hat overshoot and settle, the shadow keep its own ground line, and the sword stay in the hand rather than beside the body.
