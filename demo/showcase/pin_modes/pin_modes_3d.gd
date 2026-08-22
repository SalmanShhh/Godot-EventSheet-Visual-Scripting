class_name PinModes3DDemo
extends Node3D

var t: float = 0.0

func _ready() -> void:
	$Lantern/Pin.pin_rope($Post, 2.0)
	$Cart/Pin.pin_bar($Engine, 2.0)
	$CamTarget/Pin.pin_soft($Player, 3.0)
	$Hat/Pin.pin_spring($Player/Head, 140.0, 0.6)
	$Shadow/Pin.pin_x_to($Player)
	$Sword/Pin.pin_to_point($Player, "Hand")

func _physics_process(delta: float) -> void:
	t += delta
	$Post.position = Vector3(-6.0 + sin(t * 1.2) * 3.0, 4.0, 0.0)
	$Engine.position = Vector3(fmod(t * 2.0, 14.0) - 7.0, 0.5, 6.0)
	$Player.position = Vector3(sin(t * 0.8) * 5.0, 1.0, 0.0)
	$Player.rotation.y = sin(t * 0.8) * 0.4
	# The same fall the 2D room gives its lantern, so the rope has something to hold.
	$Lantern.position.y = maxf($Lantern.position.y - 4.0 * delta, 0.3)

func _process(delta: float) -> void:
	$HudLayer/Readout.text = "PIN MODES 3D   rope %.2f / 2.00   bar %.2f / 2.00   soft lag %.2f" % [$Lantern.global_position.distance_to($Post.global_position), $Cart.global_position.distance_to($Engine.global_position), $CamTarget.global_position.distance_to($Player.global_position)]

# [b]Pin Modes 3D[/b] - the same six relationships, on the Pin 3D pack. Nothing here is a child of anything it follows: every one of them is a pin, which is why each can let go and none of them is destroyed when its anchor is. The point pin rides a Marker3D on the walker, which is where a BoneAttachment3D would sit on a real rig.
