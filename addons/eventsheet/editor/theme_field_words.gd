# Godot EventSheets - what the Theme Editor's Theme field says about each theme it lists.
#
# The field is Godot's own drop-down. Each entry carries a small swatch of the colour the theme's sheet is
# drawn on, the folder the theme lives in, and a tooltip with the file and what Save does to it; under the
# closed field one plain sentence says the same for the theme that is open. A drop-down list has one text
# column, so the folder shares the entry's line with the name instead of standing in a column of its own.
#
# DELIBERATELY NO `class_name`: the window builds it by path, so nothing else compiles it.
@tool
extends RefCounted


const FILES_PATH := "res://addons/eventsheet/theme/theme_files.gd"
## The side of a swatch, before the display scale.
const SWATCH_SIZE := 14
## The gap between a name and its folder on an entry's line.
const FOLDER_GAP := "     "


## The folder a theme lives in as the project names it ("demo/themes/"), or "" for a look with no file.
static func folder_of(path: String) -> String:
	if path.is_empty():
		return ""
	return path.trim_prefix("res://").get_base_dir() + "/"


## The text of a list entry: the name, then the folder.
static func entry_text(name: String, path: String) -> String:
	var folder: String = folder_of(path)
	return name if folder.is_empty() else name + FOLDER_GAP + folder


## The name part of a list entry's text.
static func name_of(entry: String) -> String:
	return entry.get_slice(FOLDER_GAP, 0)


## One plain sentence about the theme at `path` ("" is Match Editor): what it is and what Save does to it.
static func sentence(path: String) -> String:
	var files: GDScript = load(FILES_PATH)
	if path.is_empty():
		return EventSheetL10n.translate("Worked out from Godot's editor, dark or light. Change anything and it becomes a theme of your own: Save As asks where to keep it.")
	if path.begins_with("res://addons/"):
		return EventSheetL10n.translate("A starter that comes with the plugin, so a plugin update would replace it. Save a Copy makes your own in eventsheet_themes/ and leaves the starter as shipped.")
	if files.is_shipped(path):
		return EventSheetL10n.translate("A theme that comes with the demos. Save a Copy makes your own in eventsheet_themes/ and leaves this one as shipped.")
	return EventSheetL10n.translate("A file in your project. Save writes it in place (Ctrl+S) and every open sheet wearing it repaints.")


## The tooltip of a list entry: the file and the sentence.
static func tip(path: String) -> String:
	var where: String = path if not path.is_empty() else EventSheetL10n.translate("not a file: the colours come from Godot's editor theme")
	return where + "\n" + sentence(path)


## A small square in the colour the theme's sheet is drawn on in the running editor, edged by a hairline.
static func swatch(path: String) -> Texture2D:
	var base: Color = EventSheetEditorThemeDeriver.running_editor_base()
	if base.a <= 0.0:
		base = EventSheetEditorThemeDeriver.NATIVE_DARK_REFERENCE_BASE
	var style: EventSheetEditorStyle = null
	if not path.is_empty():
		var loaded: Resource = ResourceLoader.load(path)
		if loaded is EventSheetEditorStyle:
			style = (loaded as EventSheetEditorStyle).duplicate(true) as EventSheetEditorStyle
	var look: EventSheetEditorStyle = EventSheetEditorThemeDeriver.sheet_look(style, base) if style != null \
		else EventSheetEditorThemeDeriver.default_style_for(base)
	var fill: Color = look.get_event_style().sheet_background_color
	var side: int = EventSheetPalette.scaled(SWATCH_SIZE)
	var image: Image = Image.create(side, side, false, Image.FORMAT_RGBA8)
	image.fill(Color(fill.r, fill.g, fill.b, 1.0))
	var edge: Color = Color(0.5, 0.5, 0.5, 0.9)
	for step: int in range(side):
		for pair: Vector2i in [Vector2i(step, 0), Vector2i(step, side - 1), Vector2i(0, step), Vector2i(side - 1, step)]:
			image.set_pixelv(pair, edge)
	return ImageTexture.create_from_image(image)


## Fills the drop-down from the window's choices (name, path, group), with a swatch, the folder and a tooltip
## on every theme and a title over each group.
static func fill(field: OptionButton, choices: Array[Dictionary]) -> void:
	field.clear()
	var group: String = ""
	for choice: Dictionary in choices:
		if str(choice["group"]) != group:
			group = str(choice["group"])
			field.add_separator(group)
		var path: String = str(choice["path"])
		field.add_icon_item(swatch(path), entry_text(str(choice["name"]), path))
		var index: int = field.item_count - 1
		field.set_item_metadata(index, path)
		field.set_item_tooltip(index, tip(path))
