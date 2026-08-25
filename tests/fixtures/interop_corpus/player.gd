extends CharacterBody2D

signal died
## Fires whenever the hit points change, so the bar can follow.
signal health_changed(current)

const SPEED = 220.0
const GRAVITY = 980.0

var health = 100
var alive = true


func _physics_process(delta):
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	velocity.x = Input.get_axis("ui_left", "ui_right") * SPEED
	move_and_slide()


## Takes a hit, and dies once the bar empties.
func take_damage(amount):
	health -= amount
	health_changed.emit(health)
	if health <= 0:
		die()


func heal(amount):
	health = min(health + amount, 100)
	health_changed.emit(health)


func die():
	alive = false
	died.emit()
