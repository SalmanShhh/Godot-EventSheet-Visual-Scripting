extends Node2D

@onready var label: Label = $Label
@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	label.text = "Ready"
	sprite.visible = false
	await get_tree().create_timer(1.5).timeout
	label.text = "Go!"
	sprite.visible = true
