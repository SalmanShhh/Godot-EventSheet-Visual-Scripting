## @ace_family(ShooterMonster)
class_name ShooterMonster
extends Area2D
## A monster that walks toward the player. A family, so the main sheet can pick every one at once.

## Hits this monster takes before it explodes.
@export var health: int = 3
## How fast it walks toward the player (px/sec).
@export var speed: float = 90.0

func _ready() -> void:
	self.add_to_group("family_shooter_monster")

func _process(delta: float) -> void:
	self.position = position.move_toward(get_tree().get_first_node_in_group("player").position, speed * delta)
