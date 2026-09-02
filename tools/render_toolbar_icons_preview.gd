# EventForge - render harness (dev tool) for THE STRIP'S ICONS, and the live probe behind them.
#
# The suite runs headless, where there is no editor theme to ask, so no test can tell you whether
# the editor actually carries an icon the strip asks for by name. This harness is the answer: it
# runs INSIDE a real editor, prints has_icon for every name the strip uses plus every candidate that
# was considered, and renders the resting strip so the three icon faces can be looked at.
#
#   docs/images/resting-toolbar-icons.png   the resting strip drawn with the editor's own icons
#
# Run NON-headless AND in editor mode (headless cannot render; a plain --script run has no editor
# theme at all, which is exactly the blind spot this harness exists to cover):
#   godot --editor --path . --script tools/render_toolbar_icons_preview.gd
@tool
extends SceneTree

## Every icon name the strip asks for, plus the candidates weighed while looking for the two that
## were missing. Printed with the editor's own answer beside each, so the next reader does not have
## to guess which names exist in the version they are running.
const PROBED: Array = [
	"Save", "Undo", "Redo", "UndoRedo", "Back", "Forward", "ArrowLeft", "ArrowRight", "Reload",
	"Play", "Debug", "Timer", "Instance", "PlayScene", "MainPlay", "MainScene",
	"Add", "MemberConstant", "MemberMethod", "Script",
]

var _frames: int = 0
var _editor: EventSheetEditor = null


func _init() -> void:
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	if _frames == 4:
		_probe()
		var bg: ColorRect = ColorRect.new()
		bg.color = Color("#2b2b2b")
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		root.add_child(bg)
		_editor = EventSheetEditor.new()
		root.add_child(_editor)
		_editor.setup(EventSheetResource.new())
		_editor._menu_bar.set_full_toolbar(false)
		return
	if _frames < 12 or _editor == null:
		return
	print("[icons] resting strip minimum width, IN AN EDITOR: %.1f px"
		% _editor._menu_bar.resting_minimum_width())
	for button_name: String in ["EventSheetSaveButton", "EventSheetUndoButton", "EventSheetRedoButton"]:
		var button: Button = _editor._toolbar.find_child(button_name, true, false) as Button
		print("[icons] %s: text=%s icon=%s" % [button_name, "\"%s\"" % button.text,
			"none" if button.icon == null else "%dx%d" % [button.icon.get_width(), button.icon.get_height()]])
	# Cropped to the strip itself: the picture is about seven controls, and a screenshot of a whole
	# editor window makes each of them four pixels tall. The crop is taken from the strip's OWN
	# measured rectangle rather than from typed-in numbers, with a little air around it.
	var image: Image = root.get_texture().get_image()
	var crop: Rect2i = Rect2i(0, 0,
		mini(int(_editor._menu_bar.resting_minimum_width()) + 24, image.get_width()),
		mini(int(_editor._toolbar.size.y) + 12, image.get_height()))
	image = image.get_region(crop)
	image.save_png("res://docs/images/resting-toolbar-icons.png")
	print("[icons] wrote resting-toolbar-icons.png %dx%d" % [image.get_width(), image.get_height()])
	quit(0)


## has_icon, straight from the running editor theme, plus what the strip's own seam answers - which
## is the interesting column, because the seam DERIVES the one arrow Godot ships without a twin.
func _probe() -> void:
	var editor_theme: Theme = EditorInterface.get_editor_theme()
	print("[icons] editor theme carries %d EditorIcons" % editor_theme.get_icon_list("EditorIcons").size())
	for probed: Variant in PROBED:
		var icon_name: String = str(probed)
		print("[icons] %-16s has_icon=%s  seam=%s" % [icon_name,
			editor_theme.has_icon(icon_name, "EditorIcons"), EventSheetEditorIcons.has(icon_name)])
