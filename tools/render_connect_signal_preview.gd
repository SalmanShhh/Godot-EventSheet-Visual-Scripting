# EventForge - render harness (dev tool) for the Connect Signal to Event Sheet dialog:
# opens the signal picker over a probe node carrying script + native signals, so the
# searchable list and the card copy can be eyeballed. Run NON-headless:
#   godot --path . --script tools/render_connect_signal_preview.gd
@tool
extends SceneTree

var _frames: int = 0
var _dialog_host: RefCounted = null


func _init() -> void:
	root.title = "Connect Signal"
	root.size = Vector2i(560, 520)
	root.gui_embed_subwindows = true
	var bg: ColorRect = ColorRect.new()
	bg.color = Color("#2b2b2b")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	if _frames == 2:
		var probe: Node = Node.new()
		probe.name = "Player"
		var probe_script: GDScript = GDScript.new()
		probe_script.source_code = "extends Node\n\nsignal exploded(power: int, source: Node)\nsignal healed(amount: int)\nsignal died\n"
		probe_script.reload()
		probe.set_script(probe_script)
		root.add_child(probe)
		_dialog_host = (load("res://addons/eventsheet/editor/connect_signal_dialog.gd") as Script).new()
		_dialog_host.call("open", probe, "res://probe_sheet.gd", root)
		return
	if _frames < 10:
		return
	var img: Image = root.get_texture().get_image()
	img.save_png("res://docs/images/connect-signal-dialog.png")
	print("[preview] connect signal dialog %dx%d" % [img.get_width(), img.get_height()])
	quit(0)
