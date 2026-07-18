# EventForge - render harness (dev tool) for the Outline panel: builds a sheet with
# regions, nested groups, and a published function, opens the panel, screenshots it.
# Run NON-headless:
#   godot --path . --script tools/render_outline_panel_preview.gd
@tool
extends SceneTree

var _frames: int = 0
var _editor: EventSheetEditor = null


func _region(label: String, is_end: bool = false) -> CustomBlockRow:
	var block: CustomBlockRow = CustomBlockRow.new()
	block.kind_id = "region"
	block.fields = {"label": label, "is_end": is_end}
	return block


func _group(name: String) -> EventGroup:
	var group: EventGroup = EventGroup.new()
	group.group_name = name
	return group


func _init() -> void:
	root.title = "Outline Panel"
	root.size = Vector2i(760, 560)
	root.gui_embed_subwindows = true
	var bg: ColorRect = ColorRect.new()
	bg.color = Color("#2b2b2b")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	if _frames == 2:
		var sheet: EventSheetResource = EventSheetResource.new()
		sheet.events.append(_region("Setup"))
		sheet.events.append(_region("", true))
		var combat: EventGroup = _group("Combat")
		combat.events.append(_group("Bosses"))
		combat.events.append(_group("Minions"))
		sheet.events.append(combat)
		sheet.events.append(_group("UI + Menus"))
		for fn_name: String in ["heal", "spawn_wave"]:
			var fn: EventFunction = EventFunction.new()
			fn.function_name = fn_name
			sheet.functions.append(fn)
		_editor = EventSheetEditor.new()
		root.add_child(_editor)
		_editor.setup(sheet)
		_editor._open_outline_panel()
		return
	if _frames < 16 or _editor == null:
		return
	var img: Image = root.get_texture().get_image()
	img.save_png("res://docs/images/outline-panel.png")
	print("[preview] outline panel %dx%d" % [img.get_width(), img.get_height()])
	quit(0)
