@tool
class_name EventSheetEditorIcons
extends RefCounted

# THE STRIP'S ICONS, asked of the editor's own theme by the editor's own names.
#
# One seam, because a toolbar that asks for an icon the running editor does not ship gets null back
# and silently falls to its words - which is how the strip came to read "[save icon] Undo [redo
# icon]": two icons and one word, in a row that was supposed to be three icons.
#
# TWO NAMES DID NOT EXIST. Probed against the RUNNING editor theme of Godot 4.7 stable
# (has_icon(name, "EditorIcons") on EditorInterface.get_editor_theme(), 1045 icons in the set):
#
#   Undo       -> false      Redo      -> true      UndoRedo  -> true
#   MainScene  -> false      MainPlay  -> true      PlayScene -> true
#   Save       -> true       Play      -> true      Debug / Timer / Instance / Script -> true
#
# So Redo ships without its twin. UndoRedo is the HISTORY icon (a pair of arrows), not an undo
# arrow, and Back/ArrowLeft are navigation chevrons that mean somewhere else. The undo glyph is
# exactly the redo glyph facing the other way, so this file DERIVES it: the editor's own Redo image,
# flipped. The pair then matches stroke for stroke and wears whatever colour the reader's editor
# theme recoloured the original to, which no hand-drawn SVG of ours could follow.
#
# A run with no editor at all (headless, the suite) gets null from every call here, and the control
# that asked keeps its words or its glyph. Null is a normal answer, never an error.


## Icons this editor needs that the running theme does not ship, and the icon each is MIRRORED from.
## An entry earns its place by being the same drawing facing the other way - never by being
## "close enough", which is how a toolbar ends up with an arrow that means something else.
const MIRRORED: Dictionary = {"Undo": "Redo"}

## Mirrored icons already made, as {wanted name: [source texture instance id, made texture]}. An
## editor icon is a rasterised SVG, so flipping one costs an image copy - paid once per name rather
## than once per toolbar build. The source's id is kept beside it so an editor theme reload (which
## hands out NEW textures) remakes the mirror instead of serving one in yesterday's colours.
static var _mirrored: Dictionary = {}


## The editor icon called `icon_name`, or null. Null when there is no editor (a headless run has no
## editor theme at all), when the running theme does not carry the name and nothing can be derived
## from it, or when the name is empty.
static func icon(icon_name: String) -> Texture2D:
	if icon_name.is_empty() or not Engine.is_editor_hint() or not Engine.has_singleton("EditorInterface"):
		return null
	var editor_theme: Theme = EditorInterface.get_editor_theme()
	if editor_theme == null:
		return null
	if editor_theme.has_icon(icon_name, "EditorIcons"):
		return editor_theme.get_icon(icon_name, "EditorIcons")
	return _mirror_of(editor_theme, icon_name)


## Whether the running editor theme (or this file's mirror table) can answer for `icon_name`.
## Answers false headlessly, where there is no theme to ask.
static func has(icon_name: String) -> bool:
	return icon(icon_name) != null


## The mirrored twin of a name the theme does not carry, made once and kept.
static func _mirror_of(editor_theme: Theme, icon_name: String) -> Texture2D:
	var twin: String = str(MIRRORED.get(icon_name, ""))
	if twin.is_empty() or not editor_theme.has_icon(twin, "EditorIcons"):
		return null
	var source: Texture2D = editor_theme.get_icon(twin, "EditorIcons")
	if source == null:
		return null
	var remembered: Array = _mirrored.get(icon_name, [])
	if remembered.size() == 2 and int(remembered[0]) == int(source.get_instance_id()) \
			and is_instance_valid(remembered[1]):
		return remembered[1]
	var image: Image = source.get_image()
	if image == null:
		return null
	image = image.duplicate() as Image
	image.flip_x()
	var made: ImageTexture = ImageTexture.create_from_image(image)
	_mirrored[icon_name] = [source.get_instance_id(), made]
	return made
