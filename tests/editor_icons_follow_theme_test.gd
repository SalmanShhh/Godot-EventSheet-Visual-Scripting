# Godot EventSheets - a live switch of the editor's theme re-points the icons the plugin fetched
#
# Godot rasterises its icons per theme: after a dark to light switch every texture a button was
# given earlier is the old theme's. EventSheetEditorIcons remembers which name each texture of the
# theme belongs to and, once the icon set has been replaced, hands the controls the same names from
# the new set. A stand-in theme plays the editor's here (the suite has no editor).
@tool
class_name EditorIconsFollowThemeTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME := "editor_icons_follow_theme_test"


static func _texture(shade: float) -> ImageTexture:
	var image: Image = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color(shade, shade, shade, 1.0))
	return ImageTexture.create_from_image(image)


static func _reset() -> void:
	EventSheetEditorIcons.stand_in_theme = null
	EventSheetEditorIcons._names_by_texture.clear()
	EventSheetEditorIcons._probe_id = 0
	EventSheetEditorIcons._generation = 0
	EventSheetEditorIcons._retargeted = 0
	EventSheetEditorIcons._mirrored.clear()


static func run() -> bool:
	_reset()
	var theme: Theme = Theme.new()
	var dark_save: ImageTexture = _texture(1.0)
	var dark_play: ImageTexture = _texture(0.9)
	theme.set_icon("Save", "EditorIcons", dark_save)
	theme.set_icon("Play", "EditorIcons", dark_play)
	EventSheetEditorIcons.stand_in_theme = theme

	var root: Control = Control.new()
	var save_button: Button = Button.new()
	save_button.icon = EventSheetEditorIcons.icon("Save")
	var play_button: Button = Button.new()
	play_button.icon = EventSheetEditorIcons.icon("Play")
	var field: LineEdit = LineEdit.new()
	field.right_icon = EventSheetEditorIcons.icon("Play")
	var plain_button: Button = Button.new()
	var own_texture: ImageTexture = _texture(0.2)
	plain_button.icon = own_texture
	for child: Control in [save_button, play_button, field, plain_button]:
		root.add_child(child)

	var generation_before: int = EventSheetEditorIcons.generation()
	var untouched: int = EventSheetEditorIcons.retarget(root)
	var rows: Array = []
	rows.append(["no switch: nothing is re-pointed", untouched, 0])
	rows.append(["no switch: the generation holds", EventSheetEditorIcons.generation(), generation_before])

	# The editor switches theme: new textures for the same names.
	var light_save: ImageTexture = _texture(0.1)
	var light_play: ImageTexture = _texture(0.15)
	theme.set_icon("Save", "EditorIcons", light_save)
	theme.set_icon("Play", "EditorIcons", light_play)
	rows.append(["a switch bumps the generation", EventSheetEditorIcons.generation(), generation_before + 1])
	var changed: int = EventSheetEditorIcons.retarget(root)
	rows.append(["three controls were re-pointed", changed, 3])
	rows.append(["a button wears the new Save", save_button.icon == light_save, true])
	rows.append(["a button wears the new Play", play_button.icon == light_play, true])
	rows.append(["a field's right icon wears the new Play", field.right_icon == light_play, true])
	rows.append(["a control's own picture is left alone", plain_button.icon == own_texture, true])
	rows.append(["asking again changes nothing", EventSheetEditorIcons.retarget(root), 0])

	# And back: the names were re-learned from the new set.
	theme.set_icon("Save", "EditorIcons", dark_save)
	theme.set_icon("Play", "EditorIcons", dark_play)
	rows.append(["switching back re-points again", EventSheetEditorIcons.retarget(root), 3])
	rows.append(["and the old textures are worn again", [save_button.icon == dark_save, play_button.icon == dark_play], [true, true]])

	root.free()
	_reset()
	return SUPPORT.pins(TEST_NAME, rows)
