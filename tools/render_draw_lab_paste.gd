# EventForge - render harness (dev tool): runs the Draw Lab showcase live and screenshots it after the
# comet has orbited a while, so the paste demo is visible - the gem LAYER baked onto the persistent canvas
# at load (Paste Layer) plus the trail of gem stamps the orbiting comet leaves (Paste Node). Run:
#   godot --path . --script tools/render_draw_lab_paste.gd
@tool
extends SceneTree

var _frames: int = 0


func _init() -> void:
	root.title = "Draw Lab - paste demo"
	root.size = Vector2i(1152, 648)
	var scene: Node = load("res://demo/showcase/draw_lab/draw_lab.tscn").instantiate()
	root.add_child(scene)
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	# Let the comet orbit and stamp its Paste Node trail for a couple of seconds before the shot.
	if _frames < 150:
		return
	var image: Image = root.get_texture().get_image()
	image.save_png("res://docs/images/draw-lab-paste.png")
	print("[draw_lab_paste] saved (%dx%d)" % [image.get_width(), image.get_height()])
	quit(0)
