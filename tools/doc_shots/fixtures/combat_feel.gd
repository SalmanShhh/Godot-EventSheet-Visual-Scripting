extends CharacterBody2D

@export var player: Node2D
var wave: int = 0

signal jump_pressed
signal hurt

var __recent_at_u4: int = -1000000


func __recent_u4(current: bool, window: float) -> bool:
	if current:
		__recent_at_u4 = Time.get_ticks_msec()
		return true
	return Time.get_ticks_msec() - __recent_at_u4 <= int(window * 1000.0)
var __gcount_u5: int = -1


func __group_emptied_u5(group_name: String) -> bool:
	var count: int = get_tree().get_nodes_in_group(group_name).size()
	var previous: int = __gcount_u5
	__gcount_u5 = count
	return previous > 0 and count == 0


func _ready() -> void:
	jump_pressed.connect(_on_jump_pressed)
	hurt.connect(_on_hurt)


func _on_jump_pressed() -> void:
	set_meta(&"__ef_buffer_" + str("jump"), Time.get_ticks_msec() + int(0.12 * 1000.0))


func _process(_delta: float) -> void:
	if Time.get_ticks_msec() <= int(get_meta(&"__ef_buffer_" + str("jump"), 0)) and __recent_u4(bool(is_on_floor()), 0.1):
		jump()
		set_meta(&"__ef_buffer_" + str("jump"), 0)
	if __group_emptied_u5("enemies"):
		wave += 1
		start_wave(wave)
	var __push_u2: Vector2 = get_meta(&"__ef_push", Vector2.ZERO)
	if __push_u2.length_squared() > 0.01:
		global_position += __push_u2 * get_process_delta_time()
		set_meta(&"__ef_push", __push_u2 * exp(-8.0 * get_process_delta_time()))
	for __pull_u1: Node in get_tree().get_nodes_in_group("coins"):
		if __pull_u1 is Node2D and (__pull_u1 as Node2D).global_position.distance_to(global_position) <= 96.0:
			(__pull_u1 as Node2D).global_position = (__pull_u1 as Node2D).global_position.move_toward(global_position, 400.0 * get_process_delta_time())
	var __orbit_u3: float = float(get_meta(&"__orbit_u3", 0.0)) + deg_to_rad(90.0) * get_process_delta_time()
	set_meta(&"__orbit_u3", __orbit_u3)
	global_position = player.global_position + Vector2(cos(__orbit_u3), sin(__orbit_u3)) * 40.0


func _on_hurt() -> void:
	set_meta(&"__ef_push", (global_position - player.global_position).normalized() * 300.0)
	$Health.grant_invincibility(1.0)
	$HudKitBehavior.pop_floating_text("-10", global_position, Color.RED)


func jump() -> void:
	velocity.y = -400.0


func start_wave(number: int) -> void:
	print(number)
