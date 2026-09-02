extends Node2D

@onready var beam: Light2D = $Beam


func _ready() -> void:
	beam.set_process(false)
	rpc(&"take_damage", 10)
	match beam.energy:
		1.0:
			pass


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"jump"):
		beam.set_process(true)
