# EventForge - render harness (dev tool) for the "group_reference" rich param: opens the
# params dialog on Add To Group with a scene carrying real groups, so the group-name
# autocomplete (project global groups + scene groups as quoted literals) can be eyeballed
# with its suggestion popup dropped down. Run NON-headless:
#   godot --path . --script tools/render_group_reference_preview.gd
@tool
extends SceneTree

var _frames: int = 0
var _dialog: ACEParamsDialog = null


func _init() -> void:
	root.title = "Group Reference Param"
	root.size = Vector2i(660, 560)
	root.gui_embed_subwindows = true
	var bg: ColorRect = ColorRect.new()
	bg.color = Color("#2b2b2b")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	if _frames == 2:
		# A pretend edited scene whose nodes carry the groups a real project would.
		var scene_root: Node = Node.new()
		scene_root.name = "Level"
		for group_name: String in ["enemies", "pickups", "hazards", "checkpoints"]:
			var member: Node = Node.new()
			member.add_to_group(group_name, true)
			scene_root.add_child(member)
		root.add_child(scene_root)
		_dialog = ACEParamsDialog.new()
		_dialog.animation_scene_root_override = scene_root
		_dialog.init_dialog(root)
		var d: ACEDefinition = ACEDefinition.new()
		d.display_name = "Add To Group"
		d.parameters = [
			{"id": "target", "display_name": "Target", "default_value": "self",
				"description": "Node to tag.", "hint": "expression"},
			{"id": "group", "display_name": "Group", "default_value": "\"enemies\"",
				"description": "Group name.", "hint": "group_reference"},
		]
		_dialog.open(d, {})
		return
	if _frames == 6 and _dialog != null:
		# Drop the suggestion popup down so the shot shows the live group list.
		var group_edit: LineEdit = _dialog._fields.get("group") as LineEdit
		if group_edit != null:
			group_edit.text = ""
			var picker: MenuButton = group_edit.get_parent().get_child(1) as MenuButton
			if picker != null:
				picker.show_popup()
		return
	if _frames < 12 or _dialog == null:
		return
	var img: Image = root.get_texture().get_image()
	img.save_png("res://docs/images/group-reference-param.png")
	print("[preview] group reference param %dx%d" % [img.get_width(), img.get_height()])
	quit(0)
