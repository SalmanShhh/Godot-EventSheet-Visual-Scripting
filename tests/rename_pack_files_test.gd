# Godot EventSheets - the Rename window leaves the plugin's own behaviour packs out of "Named and left".
#
# The name index finds the word `speed` in every row that says it, so a pack that has a `speed` variable
# of its own matched a rename of the reader's `speed` and 37 pack files filled the list. A file in a shipped
# pack folder is listed only when its text refers to the script being renamed; the others are counted in
# one plain sentence. Files of the reader's own are always listed, whatever folder they sit in.
@tool
class_name RenamePackFilesTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")


static func run() -> bool:
	var texts: Dictionary = {
		"res://eventsheet_addons/bullet/bullet_behavior.gd": "var speed := 1.0",
		"res://eventsheet_addons/car/car_behavior.gd": "var speed := 1.0\nvar mover: Mover",
		"res://game/eventsheet_addons/wave/wave_behavior.gd": "var speed := 1.0",
		"res://eventsheet_addons/my_own_thing/thing.gd": "var speed := 1.0",
		"res://enemies/enemy.gd": "var speed := 1.0",
	}
	var found: Array = []
	for path: String in ["res://enemies/enemy.gd", "res://mover.gd", "res://eventsheet_addons/my_own_thing/thing.gd",
			"res://eventsheet_addons/car/car_behavior.gd", "res://eventsheet_addons/bullet/bullet_behavior.gd",
			"res://game/eventsheet_addons/wave/wave_behavior.gd"]:
		found.append({"sheet": path, "count": 2})
	var reader: Callable = func(path: String) -> String: return str(texts.get(path, ""))
	var split: Dictionary = EventSheetRenameReceipt.split_elsewhere(found, "res://mover.gd",
		PackedStringArray(["res://mover.gd", "Mover"]), reader)
	var plain: Dictionary = EventSheetRenameReceipt.split_elsewhere(found, "res://mover.gd",
		PackedStringArray(["res://mover.gd"]), reader)
	var listed: Array = []
	for entry: Dictionary in split["listed"]:
		listed.append(str(entry["path"]))
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.custom_class_name = "Mover"
	return SUPPORT.pins("rename pack files", [
		["the reader's files and a pack that refers to this script are listed, by path", listed,
			["res://enemies/enemy.gd", "res://eventsheet_addons/car/car_behavior.gd", "res://eventsheet_addons/my_own_thing/thing.gd"]],
		["a shipped pack that only has the name for itself is left out and counted", split["left_out"], 2],
		["the sheet being renamed is in neither", [listed.has("res://mover.gd"), int(split["left_out"]) + listed.size()], [false, 5]],
		["with no class name only the path says a file refers to the script", plain["left_out"], 3],
		["the markers are the path and the class name", Array(EventSheetRenameReceipt.own_markers(sheet, "res://mover.gd")),
			["res://mover.gd", "Mover"]],
		["the sentence says how many were left out and why",
			EventSheetRenameReceipt.summary_text(2, [], PackedStringArray(), 37),
			"2 row(s) in this sheet, and nothing else in the project calls it by that name. 37 file(s) of the behaviours that ship with this plugin also say that name, and nothing in them refers to this script, so they are not listed."],
		["nothing left out says nothing more", EventSheetRenameReceipt.summary_text(2, [], PackedStringArray(), 0),
			"2 row(s) in this sheet, and nothing else in the project calls it by that name."],
	])
