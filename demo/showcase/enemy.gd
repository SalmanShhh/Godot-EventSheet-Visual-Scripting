## @ace_tags(family, demo)
## @ace_family(Enemy)
class_name Enemy
extends Sprite2D
## A falling enemy, marked as a Family so one rule can move or damage every Enemy at once.

## How fast (px/sec) this enemy falls.
@export var fall_speed: float = 90.0
## Hits this enemy survives before it dies.
@export var health: int = 3


func _ready() -> void:
	self.add_to_group("family_enemy")
	fall_speed = randf_range(60.0, 140.0)
	modulate = Color.from_hsv(randf(), 0.6, 1.0)
	scale = Vector2(0.4, 0.4)


## @ace_action
## @ace_name("Take Damage")
## @ace_category("Enemy")
## @ace_codegen_template("take_damage({amount})")
func take_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		queue_free()
