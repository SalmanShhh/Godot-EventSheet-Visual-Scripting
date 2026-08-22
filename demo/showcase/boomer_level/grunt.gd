class_name BoomerLevelGrunt
extends CharacterBody3D
## One grunt. Alert Enemies Within tells it who to go for, and being hurt makes it shout - which is what turns a room of them on each other.

## How much damage this grunt takes before it falls.
@export var hp: float = 40.0
## How far its shout carries when something hurts it.
@export var shout_radius: float = 9.0
## How fast it walks at whatever it is going for.
@export var walk_speed: float = 2.4

## Whoever this grunt is going for right now.
var target: Node3D = null

func alerted(who: Variant) -> void:
	if who.is_in_group("enemies"):
		target = who

func _physics_process(delta: float) -> void:
	if target != null and is_instance_valid(target):
		var toward := (target.global_position - global_position)
		velocity.x = toward.normalized().x * walk_speed
		velocity.z = toward.normalized().z * walk_speed
	move_and_slide()

## @ace_hidden
func take_damage(amount: float) -> void:
	hp -= amount
	for __alerted_hurt in get_tree().get_nodes_in_group("enemies"):
		if __alerted_hurt != self and __alerted_hurt.global_position.distance_to(global_position) < shout_radius:
			__alerted_hurt.alerted(self)
	if hp <= 0.0:
		get_parent().count_kill()
		queue_free()

# A grunt: told who to go for by Alert Enemies Within, and shouting to the room when it is hurt.
