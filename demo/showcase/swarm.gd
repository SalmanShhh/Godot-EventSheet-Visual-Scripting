class_name Swarm
extends Node2D

## How many sprites to spawn.
@export_range(100, 2000, 50) var count: int = 800
var t: float = 0.0
var __loop_cursor_7647f9_0: int = 0
var __loop_items_7647f9_0: Array = []


func _ready() -> void:
	var __cols: int = 40
	for __i: int in range(count):
		var __dot: Sprite2D = load("res://demo/showcase/dot.tscn").instantiate()
		__dot.position = Vector2(48.0 + float(__i % __cols) * 27.0, 70.0 + float(__i / __cols) * 27.0)
		add_child(__dot)


func _process(delta: float) -> void:
	t += delta
	$Info.text = "%d sprites   ·   Budgeted For Each: 90/frame   ·   %d FPS" % [count, Engine.get_frames_per_second()]
	if __loop_cursor_7647f9_0 >= __loop_items_7647f9_0.size():
		__loop_cursor_7647f9_0 = 0
	if __loop_cursor_7647f9_0 == 0:
		__loop_items_7647f9_0 = Array(get_tree().get_nodes_in_group("swarm"))
	var __loop_end_7647f9_0: int = Time.get_ticks_usec() + int(0.0 * 1000.0)
	var __done_7647f9_0: int = 0
	while __loop_cursor_7647f9_0 < __loop_items_7647f9_0.size():
		if __done_7647f9_0 > 0 and ((90 > 0 and __done_7647f9_0 >= 90) or (0.0 > 0.0 and Time.get_ticks_usec() >= __loop_end_7647f9_0)):
			break
		var dot = __loop_items_7647f9_0[__loop_cursor_7647f9_0]
		__loop_cursor_7647f9_0 += 1
		__done_7647f9_0 += 1
		if dot is Object and not is_instance_valid(dot):
			continue
		dot.offset = Vector2(sin(t * 2.0 + dot.position.x * 0.02) * 10.0, cos(t * 2.4 + dot.position.y * 0.02) * 10.0)
		dot.modulate = Color.from_hsv(fmod(t * 0.08 + dot.position.x * 0.0008, 1.0), 0.65, 1.0)

# [b]Swarm[/b] - frame-spreading made visible. On Ready spawns 800 sprites into the "swarm" group; ONE For Each with a frame-spread budget of 90/frame wobbles them, so only a slice updates each frame and the colour refresh SWEEPS through the crowd - that visible wave IS the spreading. The FPS stays pinned even though the loop never touches the whole crowd in a single frame. Tick frame_spread_count on any For Each to get this - no behavior, no await.
