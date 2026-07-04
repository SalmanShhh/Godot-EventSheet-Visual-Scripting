# EventForge - visual render harness for the "Pick Node" dialog (dev tool, not shipped logic).
# Opens the scene-node picker (ACEParamsDialog) over a seeded sample scene and saves a PNG so the
# editor-themed AcceptDialog look can be inspected. Run NON-headless (needs a real renderer):
#   godot --path . --script tools/render_node_picker_preview.gd
@tool
extends SceneTree

var _frames: int = 0
var _dialog: ACEParamsDialog = null
var _picker: Window = null


func _init() -> void:
	root.title = "Node Picker Preview"
	root.size = Vector2i(760, 680)
	root.gui_embed_subwindows = true
	var background: ColorRect = ColorRect.new()
	background.color = Color("#252525")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	if _frames == 2:
		# A representative scene tree to list (CharacterBody2D + sprite + UI + static body).
		var scene: Node2D = Node2D.new()
		scene.name = "PlatformerShooter"
		var floor_body: StaticBody2D = StaticBody2D.new()
		floor_body.name = "Floor"
		scene.add_child(floor_body)
		var player: CharacterBody2D = CharacterBody2D.new()
		player.name = "Player"
		scene.add_child(player)
		var sprite: Sprite2D = Sprite2D.new()
		sprite.name = "Sprite2D"
		player.add_child(sprite)
		var hud: Label = Label.new()
		hud.name = "Hud"
		scene.add_child(hud)
		_dialog = ACEParamsDialog.new()
		_dialog.init_dialog(root)
		_dialog._ensure_node_picker_ui()
		_dialog._populate_node_picker_from_root(scene)
		_picker = _dialog._node_picker._node_picker_window
		_picker.popup_centered(Vector2i(520, 560))
		return
	if _frames < 10 or _picker == null:
		return
	var image: Image = _picker.get_texture().get_image()
	image.save_png("res://_node_picker_preview.png")
	print("[node_picker_preview] saved res://_node_picker_preview.png (%dx%d)" % [image.get_width(), image.get_height()])
	quit(0)
