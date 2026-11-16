# Godot EventSheets - the behaviour library's cards draw a pack's icon at twice the size it is made at.
#
# The icon is a 16 px drawing; a card is tall, so the icon is drawn at 32 px from the drawing itself (not the
# 16 px picture stretched), for a pack the project holds and for one that is only in the library alike.
# And a card grows to the lines it needs: no cap that cuts the last line of a long description.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const NAME: String = "library_card_icon_test"
const WINDOW_PATH: String = "res://addons/eventsheet/editor/behaviour_library_window.gd"


static func run() -> bool:
	var in_project: Texture2D = EventSheetBehaviourLibraryWindow.tile_icon({"icon": "res://eventsheet_addons/health/icon.svg"}, "")
	var from_library: Texture2D = EventSheetBehaviourLibraryWindow._svg_from_file("res://addons/eventsheet_library/health/icon.svg")
	var window_text: String = FileAccess.get_file_as_string(WINDOW_PATH)
	var rows: Array = [
		["a pack the project holds is drawn at 32 px", in_project.get_size() if in_project != null else Vector2.ZERO, Vector2(32, 32)],
		["a pack that is only in the library is drawn at 32 px", from_library.get_size() if from_library != null else Vector2.ZERO, Vector2(32, 32)],
		["the card's picture box is 32 px", EventSheetBehaviourLibraryWindow.ICON_SIDE, 32.0],
		["a card grows to its lines with no cap of three rows", window_text.contains("row_floor * 3.0"), false]
	]
	return SUPPORT.pins(NAME, rows)
