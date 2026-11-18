extends CharacterBody2D

var hp: int = 100
@onready var label: Label = $Label
@onready var flash: AnimationPlayer = $Flash


func _process(delta: float) -> void:
	label.text = str(hp)
	if hp < 10:
		flash.play("hurt")


func _physics_process(delta: float) -> void:
	move_and_slide()
