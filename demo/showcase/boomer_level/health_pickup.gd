class_name BoomerLevelPickup
extends Area3D
## A health pickup that comes back. Walking into it takes it away and the Respawn After row puts it back.

## How long the pickup stays gone before it comes back.
@export var respawn_seconds: float = 3.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	hide()
	set_deferred("monitoring", false)
	await get_tree().create_timer(respawn_seconds).timeout
	show()
	set_deferred("monitoring", true)

# A health pickup: taken, then back after its own timer.
