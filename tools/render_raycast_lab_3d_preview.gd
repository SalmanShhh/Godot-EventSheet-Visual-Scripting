# EventForge - render harness (dev tool) for the Raycast Lab 3D showcase: instantiates the real
# scene, lets PHYSICS run so every cast resolves, asserts what each one found, and screenshots it.
# Run NON-headless (physics + rendering both need a live tree):
#   godot --path . --script tools/render_raycast_lab_3d_preview.gd
@tool
extends SceneTree

var _frames: int = 0
var _lab: Node3D = null


func _init() -> void:
	root.title = "Raycast Lab 3D"
	root.size = Vector2i(1152, 648)
	_lab = (load("res://demo/showcase/raycast_lab_3d/raycast_lab_3d.tscn") as PackedScene).instantiate()
	root.add_child(_lab)
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	# Park the cursor over the centre target so the picking ray has something to report. Warped AFTER
	# the window exists (a warp in _init lands before the window is up and is silently dropped).
	# get_viewport().get_mouse_position() reads the real pointer, so this drives the shipped code path.
	if _frames == 10:
		root.warp_mouse(Vector2(576.0, 384.0))
		return
	# Phase one: cursor on the centre TARGET, so the group test has something to be true about.
	# A sphere has no mesh triangles, so face index is legitimately -1 here - phase two covers it.
	if _frames == 40:
		print("[smoke] cursor on a target -> hit=%s point=%s face=%d on_target=%s" % [
			str(not (_lab.pick as Dictionary).is_empty()), str(_lab.pick_point),
			_lab.pick_face, str(_lab.pick_on_target)])
		# Phase two: cursor onto bare FLOOR, which is a concave trimesh - the only kind of shape that
		# has a face index at all. Both facts need a different cursor, so the smoke asserts both.
		root.warp_mouse(Vector2(300.0, 520.0))
		return
	if _frames < 70:
		return
	var picked: bool = not (_lab.pick as Dictionary).is_empty()
	print("[smoke] cursor on the floor -> hit=%s point=%s face=%d on_target=%s" % [
		str(picked), str(_lab.pick_point), _lab.pick_face, str(_lab.pick_on_target)])
	print("[smoke] raycast3d node     -> hit=%s end=%s normal=%s" % [
		str(_lab.radar_hit), str(_lab.radar_end), str(_lab.radar_normal)])
	print("[smoke] sphere overlap     -> nearby=%d" % (_lab.nearby as Array).size())
	print("[smoke] box overlap        -> in_box=%d" % (_lab.in_box as Array).size())
	print("[smoke] point query        -> under turret=%d" % (_lab.at_point as Array).size())
	print("[smoke] sphere motion cast -> travel=%.3f probe_end=%s" % [_lab.travel, str(_lab.probe_end)])
	print("[smoke] shapecast3d        -> touching=%d safe_fraction=%.3f" % [_lab.sweep_count, _lab.sweep_travel])
	var img: Image = root.get_texture().get_image()
	img.save_png("res://docs/images/raycast-lab-3d.png")
	print("[smoke] screenshot %dx%d" % [img.get_width(), img.get_height()])
	quit(0)
