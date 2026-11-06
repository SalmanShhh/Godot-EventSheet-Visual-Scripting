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

## A theme that stands in for the editor's where there is no editor theme at all - a headless run, so
## the suite can ask which icon a line resolves to. Never set by the plugin: in the editor it is null
## and the running editor theme answers.
static var stand_in_theme: Theme = null


## The editor icon called `icon_name`, or null. Null when there is no editor (a headless run has no
## editor theme at all, unless a stand-in theme was handed in), when the running theme does not carry
## the name and nothing can be derived from it, or when the name is empty.
static func icon(icon_name: String) -> Texture2D:
	if icon_name.is_empty():
		return null
	var editor_theme: Theme = _theme()
	if editor_theme == null:
		return null
	_notice_theme()
	if editor_theme.has_icon(icon_name, "EditorIcons"):
		return editor_theme.get_icon(icon_name, "EditorIcons")
	return _mirror_of(editor_theme, icon_name)


## Whether the running editor theme (or this file's mirror table) can answer for `icon_name`.
## Answers false headlessly, where there is no theme to ask.
static func has(icon_name: String) -> bool:
	return icon(icon_name) != null


## True when some theme can answer for icons - the running editor's, or the stand-in - so a name that
## finds nothing is a real miss rather than a run with no theme to ask.
static func has_theme() -> bool:
	return _theme() != null


## The theme icons are asked of: the running editor's, else the stand-in, else null.
static func _theme() -> Theme:
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		var editor_theme: Theme = EditorInterface.get_editor_theme()
		if editor_theme != null:
			return editor_theme
	return stand_in_theme


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
	# A mirror is not in the theme's list, and a live switch has to know what it was too.
	_names_by_texture[made.get_instance_id()] = icon_name
	return made


# ── Following a live switch of the editor's theme ─────────────────────────────────────────────
# Godot rasterises its icons per theme, so after a switch from a dark editor to a light one (or back)
# every texture this plugin fetched earlier is the OLD theme's: white strokes on a pale button. The
# editor rebuilds its own controls; the plugin's are re-pointed here, by remembering which name each
# texture of the theme belongs to and asking the new theme for that name.

## The icon whose texture's identity tells a new theme from the one before: Godot builds new textures
## on every theme reload, so a changed instance id IS a reload.
const GENERATION_PROBE: String = "Save"

## {texture instance id: icon name} for the theme in force when it was last read. It still holds the
## OLD answer at the moment a switch is noticed, which is exactly what the controls still wear.
static var _names_by_texture: Dictionary = {}
static var _probe_id: int = 0
static var _generation: int = 0
## The generation the controls were last re-pointed at.
static var _retargeted: int = 0


## How many times the editor's icon set has been replaced under us, noticed when asked. A cache of
## anything made from an editor icon compares this against the value it was built at, and a retained
## paint's signature carries it, so a switch repaints rows that did not otherwise change.
static func generation() -> int:
	_notice_theme()
	return _generation


## Looks at the running theme and, when its icons are new textures, bumps the generation. The names
## of the old textures stay in `_names_by_texture` until `retarget` has used them.
static func _notice_theme() -> void:
	var editor_theme: Theme = _theme()
	if editor_theme == null or not editor_theme.has_icon(GENERATION_PROBE, "EditorIcons"):
		return
	var probe: int = editor_theme.get_icon(GENERATION_PROBE, "EditorIcons").get_instance_id()
	if probe == _probe_id:
		return
	if _probe_id != 0:
		_generation += 1
		_mirrored.clear()
	else:
		_remember(editor_theme)
	_probe_id = probe


## Remembers every texture of `editor_theme`'s icon set by name.
static func _remember(editor_theme: Theme) -> void:
	_names_by_texture.clear()
	for icon_name: StringName in editor_theme.get_icon_list("EditorIcons"):
		_names_by_texture[editor_theme.get_icon(icon_name, "EditorIcons").get_instance_id()] = str(icon_name)
	for mirrored_name: Variant in _mirrored:
		var made: Texture2D = (_mirrored[mirrored_name] as Array)[1]
		_names_by_texture[made.get_instance_id()] = str(mirrored_name)


## The name of the editor icon `texture` is (as of the last theme read), or "".
static func name_of(texture: Texture2D) -> String:
	if texture == null:
		return ""
	return str(_names_by_texture.get(texture.get_instance_id(), ""))


## Re-points every control under `root` that wears an icon of the previous editor theme at the same
## name in the current one. Returns how many it changed; 0 when the icon set did not change.
static func retarget(root: Node) -> int:
	_notice_theme()
	if _generation == _retargeted or root == null:
		return 0
	_retargeted = _generation
	var changed: int = _retarget_node(root)
	_remember(_theme())
	return changed


static func _renewed(texture: Texture2D) -> Texture2D:
	var icon_name: String = name_of(texture)
	if icon_name.is_empty():
		return texture
	var fresh: Texture2D = icon(icon_name)
	return fresh if fresh != null else texture


static func _retarget_node(node: Node) -> int:
	var changed: int = 0
	if node is Button:
		var button: Button = node
		var fresh: Texture2D = _renewed(button.icon)
		if fresh != button.icon:
			button.icon = fresh
			changed += 1
	elif node is LineEdit:
		var field: LineEdit = node
		var fresh_right: Texture2D = _renewed(field.right_icon)
		if fresh_right != field.right_icon:
			field.right_icon = fresh_right
			changed += 1
	elif node is TabBar:
		var tabs: TabBar = node
		for index: int in tabs.tab_count:
			var fresh_tab: Texture2D = _renewed(tabs.get_tab_icon(index))
			if fresh_tab != tabs.get_tab_icon(index):
				tabs.set_tab_icon(index, fresh_tab)
				changed += 1
	elif node is TextureRect:
		var rect: TextureRect = node
		var fresh_rect: Texture2D = _renewed(rect.texture)
		if fresh_rect != rect.texture:
			rect.texture = fresh_rect
			changed += 1
	elif node is ItemList:
		var list: ItemList = node
		for index: int in list.item_count:
			var fresh_item: Texture2D = _renewed(list.get_item_icon(index))
			if fresh_item != list.get_item_icon(index):
				list.set_item_icon(index, fresh_item)
				changed += 1
	elif node is Tree:
		changed += _retarget_tree_item((node as Tree).get_root())
	if node is PopupMenu:
		var menu: PopupMenu = node
		for index: int in menu.item_count:
			var fresh_entry: Texture2D = _renewed(menu.get_item_icon(index))
			if fresh_entry != menu.get_item_icon(index):
				menu.set_item_icon(index, fresh_entry)
				changed += 1
	for child: Node in node.get_children():
		changed += _retarget_node(child)
	return changed


static func _retarget_tree_item(item: TreeItem) -> int:
	var changed: int = 0
	while item != null:
		for column: int in item.get_tree().columns:
			var fresh: Texture2D = _renewed(item.get_icon(column))
			if fresh != item.get_icon(column):
				item.set_icon(column, fresh)
				changed += 1
		changed += _retarget_tree_item(item.get_first_child())
		item = item.get_next()
	return changed
