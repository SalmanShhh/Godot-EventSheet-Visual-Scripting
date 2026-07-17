# EventForge - render harness (dev tool) for behavior editor gizmos: builds a host Node2D with
# a Bound To behavior child (custom bounds), spawns the transient gizmo canvas exactly the way
# the selection hook does, and screenshots the drawn overlay - the solid bound rectangle plus
# the dashed inner origin-reach line. Run NON-headless:
#   godot --path . --script tools/render_behavior_gizmo_preview.gd
@tool
extends SceneTree

var _frames: int = 0


func _init() -> void:
	root.title = "Behavior Gizmo"
	root.size = Vector2i(660, 480)
	var bg: ColorRect = ColorRect.new()
	bg.color = Color("#2b2b2b")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	var host: Node2D = Node2D.new()
	host.name = "Player"
	host.position = Vector2(180.0, 220.0)
	root.add_child(host)
	# A stand-in sprite so the overlay reads against something (a filled disc).
	host.draw.connect(func() -> void: host.draw_circle(Vector2.ZERO, 20.0, Color("#e0b34a")))
	host.queue_redraw()

	var behavior: Node = Node.new()
	behavior.name = "BoundTo"
	behavior.set_script(load("res://eventsheet_addons/bound_to/bound_to_behavior.gd"))
	behavior.set("bound_space", "custom")
	behavior.set("custom_bounds", Rect2(50.0, 40.0, 560.0, 380.0))
	behavior.set("half_width", 20.0)
	behavior.set("half_height", 20.0)
	host.add_child(behavior)

	# Spawn the gizmo canvas the way the selection hook does.
	var gizmos: Script = load("res://addons/eventsheet/editor/behavior_gizmos.gd")
	var target: Dictionary = gizmos.call("gizmo_target_for", host)
	var canvas: Node2D = (load("res://addons/eventsheet/editor/behavior_gizmo_canvas.gd") as Script).new() as Node2D
	canvas.set("host", target.get("host"))
	canvas.set("entries", target.get("entries"))
	host.add_child(canvas)

	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	if _frames < 8:
		return
	var img: Image = root.get_texture().get_image()
	img.save_png("res://docs/images/behavior-gizmo.png")
	print("[preview] behavior gizmo %dx%d" % [img.get_width(), img.get_height()])
	quit(0)
