@tool
extends SceneTree

const SCENE_PATH := "res://demo/showcase/_proto_raycast/raycast_lab.tscn"

var _lab: Node = null
var _frames: int = 0
var _saw_radar_hit: bool = false
var _saw_gate_hit: bool = false
var _saw_target_laser: bool = false
var _min_travel: float = 2.0
var _max_nearby: int = 0
var _max_picked: int = 0


func _initialize() -> void:
	root.gui_embed_subwindows = true
	var packed: PackedScene = load(SCENE_PATH)
	_lab = packed.instantiate()
	root.add_child(_lab)
	print("[smoke] scene added")


func _process(_delta: float) -> bool:
	_frames += 1
	if _lab == null:
		return true
	# Drive the cursor onto a target block so the laser + pick paths actually fire.
	if _frames == 20:
		Input.warp_mouse(Vector2(430.0, 300.0))
	# Park the player on the gate rail so the ShapeCast path fires.
	if _frames == 200:
		_lab.get_node("Player").global_position = Vector2(300.0, 600.0)
	if _frames > 5:
		_saw_radar_hit = _saw_radar_hit or bool(_lab.get("radar_hit"))
		_saw_gate_hit = _saw_gate_hit or int(_lab.get("gate_count")) > 0
		_saw_target_laser = _saw_target_laser or bool(_lab.get("laser_on_target"))
		_min_travel = minf(_min_travel, float(_lab.get("travel")))
		_max_nearby = maxi(_max_nearby, (_lab.get("nearby") as Array).size())
		_max_picked = maxi(_max_picked, (_lab.get("picked") as Array).size())
	if _frames == 240:
		print("[smoke] radar_hit_seen=", _saw_radar_hit)
		print("[smoke] gate_hit_seen=", _saw_gate_hit, " gate_name=", _lab.get("gate_name"), " gate_travel=", _lab.get("gate_travel"))
		print("[smoke] laser_on_target_seen=", _saw_target_laser)
		print("[smoke] min_travel=", _min_travel)
		print("[smoke] max_nearby=", _max_nearby, " max_picked=", _max_picked)
		print("[smoke] readout=", _lab.get_node("HudLayer/Readout").text)
		var image: Image = root.get_texture().get_image()
		image.save_png("res://demo/showcase/_proto_raycast/smoke.png")
		print("[smoke] screenshot saved")
		return true
	return false
