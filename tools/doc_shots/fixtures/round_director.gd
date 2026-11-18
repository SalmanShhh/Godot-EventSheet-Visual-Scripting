extends Node2D

var spotlight_on: bool = false
var zoom: float = 1.0
var target_zoom: float = 1.0
var prompt_text: String = ""

var __everyr_time_u3: float = 0.0
var __everyr_next_u3: float = -1.0


func __everyr_u3(min_seconds: float, max_seconds: float) -> bool:
	if __everyr_next_u3 < 0.0:
		__everyr_next_u3 = randf_range(min_seconds, maxf(max_seconds, min_seconds))
	if __everyr_time_u3 < __everyr_next_u3:
		return false
	__everyr_time_u3 = 0.0
	__everyr_next_u3 = randf_range(min_seconds, maxf(max_seconds, min_seconds))
	return true


func _ready() -> void:
	show_message("Ready...")
	await get_tree().create_timer(1.0).timeout
	show_message("GO!")
	await get_tree().create_timer(0.2).timeout
	start_round()


func _process(_delta: float) -> void:
	__everyr_time_u3 += get_process_delta_time()
	if __everyr_u3(2.0, 5.0):
		spotlight_on = not spotlight_on
	zoom = lerp(zoom, target_zoom, 1.0 - exp(-8.0 * get_process_delta_time()))
	rotation = rotate_toward(rotation, (get_parent().global_position - global_position).angle(), deg_to_rad(180.0) * get_process_delta_time())
	var __wrap_size_u1: Vector2 = get_viewport_rect().size
	global_position = Vector2(wrapf(global_position.x, 0.0, __wrap_size_u1.x), wrapf(global_position.y, 0.0, __wrap_size_u1.y))
	if not has_meta(&"__bob_base_u2"):
		set_meta(&"__bob_base_u2", position.y)
	position.y = float(get_meta(&"__bob_base_u2")) + sin(Time.get_ticks_msec() / 1000.0 * TAU / 2.0) * 6.0
	if global_position.distance_to(get_parent().global_position) <= 64.0:
		prompt_text = "E - open"


func show_message(text: String) -> void:
	print(text)


func start_round() -> void:
	print("go")
