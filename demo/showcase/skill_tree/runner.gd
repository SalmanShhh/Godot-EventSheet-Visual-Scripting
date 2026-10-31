class_name SkillTreeRunner
extends CharacterBody2D

## The speed before any skill touches it.
@export var base_speed: float = 120.0
var jumps_left: int = 1
var stats: Node = null
var upgrades: Node = null

func _ready() -> void:
	stats = $Stats
	upgrades = get_parent().get_node("Upgrades")
	stats.set_stat_base("speed", base_speed)

func _physics_process(delta: float) -> void:
	var steer: float = Input.get_axis(&"ui_left", &"ui_right")
	velocity.x = steer * stats.stat_total("speed")
	if is_on_floor():
		jumps_left = 2 if upgrades.is_skill_unlocked("double_jump") else 1
	else:
		velocity.y += 900.0 * delta
	if Input.is_action_just_pressed(&"ui_accept") and jumps_left > 0:
		jumps_left -= 1
		velocity.y = -340.0
	move_and_slide()

# [b]Runner[/b] - the body the tree changes. Its speed is StatForge's Stat Total for "speed", so unlocking Swift moves it faster without a formula anywhere; its second jump exists only while the Double Jump perk is unlocked, which is one Is Unlocked question.
