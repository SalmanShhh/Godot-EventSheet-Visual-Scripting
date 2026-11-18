extends Node2D


func _ready() -> void:
	$LightFlickerBehavior.start_flickering(0.5)
	await get_tree().create_timer(4.0).timeout
	$LightFlickerBehavior.stop_flickering()
	$Torch.glow_up(1.0)
