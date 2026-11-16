# Godot EventSheets - a sheet row that names a behaviour of a pack leads with that pack's icon.
#
# An object a row names resolves to a class. Godot's own classes have an icon in the editor theme; a pack's
# class is a script class, whose icon is the one its script names with `@icon`, and the theme knows nothing
# of it, so such a row drew no icon at all. The icon of a script class is read off the project's class list,
# following the bases of a class that names none, and a class that reaches only an engine class has none of
# its own (the engine class's icon is asked for in the usual way).
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const NAME: String = "row_pack_icon_test"
const HEALTH_ICON: String = "res://eventsheet_addons/health/icon.svg"


static func run() -> bool:
	var picture: Texture2D = EventSheetACEIcons.path_icon(HEALTH_ICON)
	var rows: Array = [
		["a pack's class names its icon path", EventSheetACEIcons.script_class_icon_path("SimpleHealthBehavior"), HEALTH_ICON],
		["an engine class has no script icon", EventSheetACEIcons.script_class_icon_path("Node2D"), ""],
		["a class that does not exist has none", EventSheetACEIcons.script_class_icon_path("NoSuchClassAnywhere"), ""],
		["a row naming a pack's class draws the pack's icon", EventSheetViewportReadingRows.class_icon_for("health", {"health": "SimpleHealthBehavior"}) == picture, true],
		["and the picture is there", picture != null, true],
		["an engine class still draws no icon headless, as before", EventSheetViewportReadingRows.class_icon_for("body", {"body": "Node2D"}), null]
	]
	return SUPPORT.pins(NAME, rows)
