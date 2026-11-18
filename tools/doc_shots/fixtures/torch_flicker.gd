extends CharacterBody2D

@onready var torch: Light2D = $Torch


func _physics_process(delta: float) -> void:
	if torch.shadow_filter_smooth > 1.0:
		torch.energy = 1.2
		torch.shadow_filter_smooth = 0.5
		torch.shadow_color = torch.color
