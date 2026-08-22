class_name MirrorHero
extends Node2D
## A character that faces the way it moves - picture, sword ray, muzzle point and dust all together.

## How fast the hero paces back and forth, in pixels a second.
@export var speed: float = 120.0
var t: float = 0.0
var velocity: Vector2 = Vector2(0.0, 0.0)

func _process(delta: float) -> void:
	t += delta
	velocity.x = sin(t * 1.2) * speed
	position += velocity * delta
	if velocity.x != 0.0:
		scale.x = -1.0 if velocity.x < 0.0 else 1.0
	$Plate.scale.x = signf(scale.x)

# [b]Mirror Hero[/b] - one row faces the way it moves, and because it mirrors the WHOLE object every child comes along: the sword's ray reaches the way the hero looks, the muzzle point moves to the other hand, the dust blows the right way. The [b]name plate[/b] is the exception - Keep Upright re-negates it, so the text reads forwards whichever way the hero faces.
