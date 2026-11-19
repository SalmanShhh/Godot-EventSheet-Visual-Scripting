class_name PoolSpark
extends Sprite2D
## One spark of the fountain. It flies, falls and fades for its lifetime, then says expired once. reset puts a used spark back to a fresh one: the pool calls it every time it hands the spark out again.

## Said once, when this spark has lived its whole life.
signal expired(spark: PoolSpark)

## How fast the spark is moving, in pixels a second; the fountain sets it as the spark is thrown.
var drift: Vector2 = Vector2(0.0, 0.0)
## Seconds this spark has been alive. A reused spark starts again from 0 in reset.
var age: float = 0.0
## Seconds a spark lives before it expires.
@export var lifetime: float = 1.2
## How hard the spark is pulled down, in pixels a second every second.
@export var gravity: float = 420.0

func _process(delta: float) -> void:
	age += delta
	drift.y += gravity * delta
	position += drift * delta
	modulate.a = 1.0 - age / lifetime
	if age >= lifetime:
		expired.emit(self)

# @ace_hidden
func reset() -> void:
	age = 0.0
	modulate.a = 1.0
	scale = Vector2(0.18, 0.18)
