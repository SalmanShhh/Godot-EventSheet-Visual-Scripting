# A fixture scene the animation reading tests open: a hero with a keyframed player and a flipbook.
extends Node2D


func _ready() -> void:
	$Anim.play("idle")
	$Anim.queue(&"swing")
