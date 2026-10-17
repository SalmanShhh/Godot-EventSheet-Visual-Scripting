# EventForge - visual render harness for the Save Studio window (dev tool).
# Instantiates EventSheetSaveStudio against a stub dock holding one Player sheet and screenshots
# each of its tabs in turn. Run NON-headless; add --editor for the editor's own theme (the dark or
# light one its settings pick):
#   godot --editor --path . --script tools/render_save_studio_preview.gd -- out=<folder> tag=<name>
@tool
extends SceneTree

## Each shot as [file name, tab, how far down the tab's scroll is].
const SHOTS: Array = [["save_studio_what", 0, 0], ["save_studio_format", 1, 0], ["save_studio_slots", 2, 0],
	["save_studio_peek", 3, 0], ["save_studio_player_settings", 4, 0], ["save_studio_player_uses", 4, 520]]

var _frames: int = 0
var _studio: EventSheetSaveStudio = null
var _out: String = "res://"
var _tag: String = "preview"


func _init() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("out="):
			_out = argument.trim_prefix("out=").trim_suffix("/") + "/"
		elif argument.begins_with("tag="):
			_tag = argument.trim_prefix("tag=")
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	if _frames == 2:
		# Built from the first frame, so an --editor run has its editor and theme by now.
		root.size = Vector2i(880, 760)
		root.gui_embed_subwindows = true
		var background: Panel = Panel.new()
		background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		root.add_child(background)
		var dock_stub: Control = Control.new()
		dock_stub.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		dock_stub.set_script(load("res://tools/render_save_studio_stub.gd"))
		root.add_child(dock_stub)
		dock_stub.call("open_player")
		_studio = EventSheetSaveStudio.new()
		_studio.init(dock_stub)
		_studio.open()
		_studio._window.size = Vector2i(840, 720)
		_studio._window.position = Vector2i(20, 20)
	# Six frames per tab: one to switch, the rest to lay out (the Player settings cards build on show).
	if _frames < 8 or (_frames - 8) % 6 != 0:
		return
	var shot: int = (_frames - 8) / 6
	if shot > 0:
		_shoot(str(SHOTS[shot - 1][0]))
	if shot >= SHOTS.size():
		quit(0)
		return
	_studio._tabs.current_tab = int(SHOTS[shot][1])
	var scroll: ScrollContainer = _first_scroll(_studio._tabs.get_current_tab_control())
	if scroll != null:
		scroll.scroll_vertical = int(SHOTS[shot][2])


func _first_scroll(node: Node) -> ScrollContainer:
	if node is ScrollContainer:
		return node
	for child: Node in node.get_children():
		var found: ScrollContainer = _first_scroll(child)
		if found != null:
			return found
	return null


func _shoot(name: String) -> void:
	var path: String = "%s%s_%s.png" % [_out, name, _tag]
	root.get_texture().get_image().save_png(path)
	print("[save_studio_preview] saved %s" % path)
