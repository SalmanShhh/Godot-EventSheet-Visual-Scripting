# EventForge — visual probe for the Open Sheets dock (dev tool, not shipped logic).
# Instantiates the dock control (open_sheets_dock.gd), feeds it a sample tab snapshot (badges,
# a dirty sheet, a selected/active sheet, and a recently-closed section) and saves a PNG so the
# list can be eyeballed. Run NON-headless (needs a renderer):
#   godot --path . --script tools/render_open_sheets_dock.gd
@tool
extends SceneTree

var _frames: int = 0


func _init() -> void:
	root.title = "Open Sheets dock"
	root.size = Vector2i(264, 468)
	root.gui_embed_subwindows = true

	var bg: ColorRect = ColorRect.new()
	bg.color = Color("#21232a")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	var pad: MarginContainer = MarginContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pad.add_theme_constant_override("margin_left", 8)
	pad.add_theme_constant_override("margin_top", 8)
	pad.add_theme_constant_override("margin_right", 8)
	pad.add_theme_constant_override("margin_bottom", 8)
	root.add_child(pad)

	var dock: EventSheetOpenSheetsDock = EventSheetOpenSheetsDock.new()
	# Titles mimic what EventSheetDock.get_open_sheets_state() emits: ⚙ behaviour, ◆ custom
	# node, ● unsaved. Active index 2 (showcase_carousel) is the selected/highlighted row.
	dock.set_state([
		{"title": "Player", "path": "res://player.gd", "dirty": false},
		{"title": "⚙ PlatformerMovement", "path": "res://addons/eventsheet_addons/platformer/platformer_movement_behavior.gd", "dirty": false},
		{"title": "● showcase_carousel", "path": "res://demo/showcase/showcase_carousel.gd", "dirty": true},
		{"title": "◆ QuestFsm", "path": "res://demo/showcase/quest_fsm.gd", "dirty": false},
	], 2, ["res://demo/showcase/starfall.gd", "res://systems/inventory.gd"])
	pad.add_child(dock)

	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	if _frames < 8:
		return
	var image: Image = root.get_texture().get_image()
	var out_path: String = "res://_open_sheets_dock_preview.png"
	image.save_png(out_path)
	print("[open_sheets_dock_preview] saved %s (%dx%d)" % [out_path, image.get_width(), image.get_height()])
	quit(0)
