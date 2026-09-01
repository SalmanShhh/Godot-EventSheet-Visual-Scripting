# EventForge - render harness (dev tool) for THE PLAY BUTTON: one face, six ways to play. Two
# pictures out of one run:
#
#   docs/images/play-button-dropdown.png  the split button with its dropdown open on all six
#   docs/images/play-button-stop.png      the same face while a game is running, reading Stop
#
# The second picture is STAGED: a headless-or-not preview run has no game to play, so the face is
# relabelled through the very call the run controls make when a game starts (label_for with running
# true), rather than by starting one. What the picture shows is what the strip shows.
#
# Run NON-headless (a headless run cannot render, and the popup needs embedded subwindows):
#   godot --path . --script tools/render_play_button_preview.gd
@tool
extends SceneTree

var _frames: int = 0
var _editor: EventSheetEditor = null


func _init() -> void:
	root.title = "Play Button"
	root.size = Vector2i(900, 460)
	root.gui_embed_subwindows = true
	var bg: ColorRect = ColorRect.new()
	bg.color = Color("#2b2b2b")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	process_frame.connect(_on_frame)


func _sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "CharacterBody2D"
	var event_row: EventRow = EventRow.new()
	event_row.trigger_provider_id = "Core"
	event_row.trigger_id = "OnProcess"
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "AddVar"
	action.codegen_template = "{var_name} += {amount}"
	action.params = {"var_name": "score", "amount": "1"}
	event_row.actions.append(action)
	sheet.events.append(event_row)
	return sheet


func _on_frame() -> void:
	_frames += 1
	if _frames == 2:
		_editor = EventSheetEditor.new()
		root.add_child(_editor)
		_editor.setup(_sheet())
		_editor._menu_bar.set_full_toolbar(false)
		return
	if _frames == 6:
		var menu: MenuButton = _editor._toolbar.find_child("EventSheetPlayMenu", true, false) as MenuButton
		var popup: PopupMenu = menu.get_popup()
		popup.position = Vector2i(menu.get_screen_position() + Vector2(0.0, 30.0))
		popup.reset_size()
		popup.popup()
		return
	if _frames == 10:
		var image: Image = root.get_texture().get_image()
		image.save_png("res://docs/images/play-button-dropdown.png")
		print("[preview] play button, dropdown open %dx%d" % [image.get_width(), image.get_height()])
		var menu: MenuButton = _editor._toolbar.find_child("EventSheetPlayMenu", true, false) as MenuButton
		menu.get_popup().hide()
		# Staged running state: the face wears whatever the run controls say its run is called while
		# a game runs, which for Run Scene is Stop.
		var face: Button = _editor._menu_bar.play_button().face()
		face.text = EventSheetL10n.translate(EventSheetRunControls.label_for(
			_editor._run_controls.main_run_id(), true))
		return
	if _frames < 16 or _editor == null:
		return
	var stopped: Image = root.get_texture().get_image()
	stopped.save_png("res://docs/images/play-button-stop.png")
	print("[preview] play button, face reading Stop %dx%d" % [stopped.get_width(), stopped.get_height()])
	quit(0)
