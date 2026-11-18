extends Node

@export_group("Stats")
# @inspector_header Combat #e06666
# @inspector_info Shared by every fighter - edits affect all of them.
# @inspector_look progress_bar
## The fighter's current health (0-100).
@export_range(0, 100) var health: int = 100
@export_group("")


func _ready() -> void:
	print(health)
