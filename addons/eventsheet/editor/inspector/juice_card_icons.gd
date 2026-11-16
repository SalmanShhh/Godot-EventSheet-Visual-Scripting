# Godot EventSheets - the picture a Juice card wears on its line and in the Add box (editor-only, by path).
#
# Every kind of card has one drawing in the Juice pack's own folder (cards/<kind>.svg), in Godot's neutral
# icon ink. The card line tints it with the card's family colour, so one file serves every family on a
# dark and on a light editor. A card of your own wears the icon its script names with `@icon`, else the
# default drawing `own.svg`. A project that has no such folder simply gets no picture, and the card keeps
# the small family square it always had.
#
# The drawings are read as text and made into a picture at the size asked for (the editor's scale), so
# they stay sharp on a large display and need no import beside them.
#
# No class_name on purpose: this is an editor-only helper reached by path, and a name would put it in
# every editor start.
@tool
extends RefCounted

const PACK_NAMES_PATH: String = "res://addons/eventsheet/editor/inspector/juice_player_names.gd"
const CARD_FOLDER: String = "cards/"
const OWN_ICON: String = "own"

static var _pictures: Dictionary = {}


## The picture of an entry's card: {"texture": Texture2D, "tint": bool}, where `tint` says the picture is the
## neutral drawing the family colour is to be put on. Empty when there is nothing to draw, which leaves the
## family square. `scale` is the editor's scale (1.0 is 16 px).
static func icon_for(entry: Dictionary, scale: float) -> Dictionary:
	var own_script: String = str(entry.get("script_path", ""))
	if not own_script.is_empty():
		var named: Texture2D = script_icon(own_script)
		if named != null:
			return {"texture": named, "tint": false}
		return _drawn(OWN_ICON, scale)
	return _drawn(str(entry.get("kind", "")), scale)


## The icon a script names with `@icon("...")`, or null when it names none or the file is not one a texture
## can be read from. Read from the file, the way the editor reads it.
static func script_icon(script_path: String) -> Texture2D:
	var named: String = icon_path_of(FileAccess.get_file_as_string(script_path))
	if named.is_empty() or not ResourceLoader.exists(named):
		return null
	return ResourceLoader.load(named) as Texture2D


## The path or uid inside a script's `@icon("...")` line, "" when it has none. PURE over the script's text.
static func icon_path_of(source: String) -> String:
	var found: RegExMatch = RegEx.create_from_string("(?m)^@icon\\(\\s*\"([^\"]+)\"\\s*\\)").search(source)
	return found.get_string(1) if found != null else ""


## The folder the Juice pack's card drawings are in, beside the pack's own code.
static func folder() -> String:
	return str(load(PACK_NAMES_PATH).PACK_FOLDER) + CARD_FOLDER


## One drawing as a picture at a scale, or {} when the pack carries no drawing of that name.
static func _drawn(kind: String, scale: float) -> Dictionary:
	if kind.is_empty():
		return {}
	var key: String = "%s@%s" % [kind, scale]
	if not _pictures.has(key):
		var path: String = "%s%s.svg" % [folder(), kind]
		var texture: Texture2D = null
		if FileAccess.file_exists(path):
			var picture: Image = Image.new()
			if picture.load_svg_from_string(FileAccess.get_file_as_string(path), scale) == OK:
				texture = ImageTexture.create_from_image(picture)
		_pictures[key] = texture
	var cached: Variant = _pictures[key]
	return {"texture": cached, "tint": true} if cached != null else {}
