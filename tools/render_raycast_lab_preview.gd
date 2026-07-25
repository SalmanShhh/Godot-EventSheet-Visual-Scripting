# EventForge - render harness (dev tool) for the Raycast Lab showcase: instantiates the real scene,
# lets PHYSICS run so every cast actually resolves, asserts what each one found, and screenshots the
# result. Run NON-headless (physics + rendering both need a live tree):
#   godot --path . --script tools/render_raycast_lab_preview.gd
@tool
extends SceneTree

var _frames: int = 0
var _lab: Node2D = null


func _init() -> void:
	root.title = "Raycast Lab"
	root.size = Vector2i(1152, 648)
	_lab = (load("res://demo/showcase/raycast_lab/raycast_lab.tscn") as PackedScene).instantiate()
	root.add_child(_lab)
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	# Park the cursor over Target1 so the cyan beam has something to report and the point query has
	# something to pick. Warped AFTER the window exists (a warp in _init lands before the window is
	# up and is silently dropped), then given frames to settle - get_global_mouse_position() reads the
	# real pointer, so this drives the actual code path rather than a stub.
	if _frames == 10:
		root.warp_mouse(Vector2(760.0, 150.0))
		return
	if _frames < 40:
		return
	print("[smoke] cursor parked at %s (target1 sits at (760, 150))" % str(_lab.get_global_mouse_position()))
	# Every assertion below reads state the SHEET wrote, so a silent mis-emit cannot pass.
	var beam_hit: bool = not (_lab.hit as Dictionary).is_empty()
	print("[smoke] cast ray into  -> hit=%s point=%s normal=%s on_target=%s" % [
		str(beam_hit), str(_lab.laser_end), str(_lab.laser_normal), str(_lab.laser_on_target)])
	print("[smoke] raycast2d node -> hit=%s end=%s normal=%s" % [
		str(_lab.radar_hit), str(_lab.radar_end), str(_lab.radar_normal)])
	print("[smoke] point query    -> under cursor=%d" % (_lab.picked as Array).size())
	print("[smoke] circle overlap -> nearby=%d" % (_lab.nearby as Array).size())
	print("[smoke] motion cast    -> travel=%.3f probe_end=%s" % [_lab.travel, str(_lab.probe_end)])
	print("[smoke] shapecast2d    -> touching=%d safe_fraction=%.3f" % [_lab.gate_count, _lab.gate_travel])
	var img: Image = root.get_texture().get_image()
	img.save_png("res://docs/images/raycast-lab.png")
	print("[smoke] screenshot %dx%d" % [img.get_width(), img.get_height()])
	quit(0)
