# Godot EventSheets - the icon in front of every Start page row.
#
# A starter wears the class its script extends, a recent sheet a file, a showcase a scene, a lesson
# the help mark - the editor's own icon names, never a kind word. The starters' classes are written
# beside them in the menu table, so the table is checked against the sheets the starters really
# build: a starter whose host changes and whose table entry does not fails here.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "start_page_icons_test"
## The starters the New menu fills in itself after the dock-free builder hands back a blank sheet,
## so the builder cannot say their class (the blank sheet is any node of the reader's choice).
const FILLED_BY_THE_MENU: Array[int] = [0, 3, 4, 5, 6, 7]


static func run() -> bool:
	var icons: Dictionary = {}
	for column: Variant in EventSheetStartPage.columns(PackedStringArray(["platformer"]), ["res://player.gd"]):
		for entry: Variant in (column as Dictionary).get("entries", []):
			icons[str((entry as Dictionary).get("label", ""))] = EventSheetStartPage.row_icon(entry as Dictionary)
	var drifted: Array = []
	for starter: Dictionary in EventSheetStarterTemplates.MENU_STARTERS:
		var id: int = int(starter["id"])
		if FILLED_BY_THE_MENU.has(id):
			continue
		var built: String = EventSheetStarterTemplates.build_starter(id).host_class
		if built != str(starter.get("host", "")):
			drifted.append("%s: table %s, builds %s" % [starter["label"], starter.get("host", ""), built])
	return SUPPORT.pins(P, [
		["the opener wears the open-file icon", icons.get("Open an existing script…"), "Load"],
		["a 2D starter wears the body it moves", icons.get("Platformer Starter"), "CharacterBody2D"],
		["a 3D starter its 3D body", icons.get("First-Person Controller"), "CharacterBody3D"],
		["a door starter its static body", icons.get("Keycard Door"), "StaticBody3D"],
		["a menu starter a Control", icons.get("Game Options"), "Control"],
		["the behaviour starter its Area2D", icons.get("Behavior Component"), "Area2D"],
		["an autoload starter a plain Node", icons.get("Game State"), "Node"],
		["the data starter a Resource", icons.get("Custom Resource"), "Resource"],
		["the New behaviour door the add mark", icons.get("New behaviour…"), "Add"],
		["the editor tool entry the tools mark", icons.get("Editor Tool…"), "Tools"],
		["a showcase its scene", icons.get("Platformer"), "PackedScene"],
		["a recent sheet a file", icons.get("player.gd"), "File"],
		["a lesson the help mark", icons.get("What's new"), "Help"],
		["every starter's table class is the class it builds", drifted, []],
	])
