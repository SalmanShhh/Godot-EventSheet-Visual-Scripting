# EventForge - visual render harness for the Save Studio window (dev tool).
# Instantiates EventSheetSaveStudio against a stub dock holding one Player sheet, screenshots the
# What gets saved tab, then runs a Format Preview and screenshots that tab. Run NON-headless; add
# --editor for the editor's own theme (the dark or light one its settings pick):
#   godot --editor --path . --script tools/render_save_studio_preview.gd -- out=<folder> tag=<name>
@tool
extends SceneTree

var _frames: int = 0
var _studio: EventSheetSaveStudio = null
var _dock_stub: Control = null
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
		_dock_stub = Control.new()
		_dock_stub.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_dock_stub.set_script(load("res://tools/render_save_studio_stub.gd"))
		root.add_child(_dock_stub)
		_dock_stub.call("open_player")
		_studio = EventSheetSaveStudio.new()
		_studio.init(_dock_stub)
		_studio.open()
		_studio._window.size = Vector2i(840, 720)
		_studio._window.position = Vector2i(20, 20)
	if _frames == 8:
		_shoot("save_studio_what")
		# Down to the foot of the tab: the legend and Where it is kept.
		var scroll: ScrollContainer = _find_tabs(_studio._window).get_child(0) as ScrollContainer
		scroll.scroll_vertical = 100000
	if _frames == 11:
		_shoot("save_studio_where")
		var tabs: TabContainer = _find_tabs(_studio._window)
		tabs.current_tab = 1
		_studio._preview_addon_picker.selected = _pick_addon_index("Stat")
		_studio._preview_format_picker.selected = 1  # json
		_studio._run_format_preview()
	if _frames < 17:
		return
	_shoot("save_studio_format")
	quit(0)


func _shoot(name: String) -> void:
	var path: String = "%s%s_%s.png" % [_out, name, _tag]
	root.get_texture().get_image().save_png(path)
	print("[save_studio_preview] saved %s" % path)


func _find_tabs(node: Node) -> TabContainer:
	if node is TabContainer:
		return node
	for child: Node in node.get_children():
		var found: TabContainer = _find_tabs(child)
		if found != null:
			return found
	return null


func _pick_addon_index(needle: String) -> int:
	for i: int in range(_studio._preview_addon_picker.item_count):
		if _studio._preview_addon_picker.get_item_text(i).contains(needle):
			return i
	return 0
