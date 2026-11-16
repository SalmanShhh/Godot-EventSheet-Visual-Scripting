# Godot EventSheets - the one line the workspace needs to offer "Show its cards" (editor-only, a leaf).
#
# The entry itself, and everything that decides when to offer it, lives in the row-menu file beside this one,
# which names a good many of the editor's classes. The workspace is built the first time a sheet is opened, and
# whatever it loads is compiled before anything is on screen, so it loads only THIS file: it names nothing, and
# the entry's two functions are written as lambdas that load the heavy file on the first right-click that asks.
#
# No class_name on purpose: Create Node lists every named class, and an editor-only helper has no business there.
@tool
extends RefCounted

## The file that decides which rows carry the entry and does what it says.
const ROW_MENU_PATH: String = "res://addons/eventsheet/editor/dock/juice_row_menu.gd"


## Registers the entry on the right-click menu of every row, through the registry an extension's own entry goes
## through. Done once, when the workspace is built.
static func register() -> void:
	var registry: Script = load("res://addons/eventsheet/api/dock_registry.gd")
	registry.call("register_row_menu_item", EventSheetL10n.translate("Show its cards"),
		func(row: Resource) -> bool: return bool(load(ROW_MENU_PATH).call("offers_for_row", row)),
		func(row: Resource) -> void: load(ROW_MENU_PATH).call("show_for_row", row))
