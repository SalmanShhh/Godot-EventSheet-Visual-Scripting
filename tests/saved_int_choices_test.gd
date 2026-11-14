@tool
class_name SavedIntChoicesTest
extends RefCounted

## A pack's exported choice that is stored as a number (Drag & Drop's directions, the Virtual Cursor's
## direction, hover and bounce modes) is a real enum with pinned values. A scene saved before the enum
## existed stores the plain number, and it must load into the enum-typed export unchanged.

const SUPPORT := preload("res://tests/support.gd")
const SCENE := "res://tests/fixtures/saved_int_choices_scene.tscn"


static func run() -> bool:
	var root: Node = (load(SCENE) as PackedScene).instantiate()
	var drag: Node = root.get_node("DragDrop")
	var cursor: Node = root.get_node("VirtualCursor")
	var drag_enum: Dictionary = (drag.get_script() as GDScript).get_script_constant_map().get("Directions", {})
	var cursor_constants: Dictionary = (cursor.get_script() as GDScript).get_script_constant_map()
	var result: bool = SUPPORT.pins("saved_int_choices_test", [
		["a scene that stored directions = 3 still reads 3", drag.get("directions"), 3],
		["3 is the four-way lock", drag.get("directions") == drag_enum.get("FOUR_DIR"), true],
		["the Drag & Drop values are pinned", drag_enum, {"FREE": 0, "UP_DOWN": 1, "LEFT_RIGHT": 2, "FOUR_DIR": 3, "EIGHT_DIR": 4}],
		["a stored direction_mode of 1 still reads 1", cursor.get("direction_mode"), 1],
		["a stored hover_mode of 1 still reads 1", cursor.get("hover_mode"), 1],
		["a stored bounce_mode of 2 still reads 2", cursor.get("bounce_mode"), 2],
		["the cursor's direction values are pinned", cursor_constants.get("DirectionMode"), {"UP_DOWN": 0, "LEFT_RIGHT": 1, "FOUR": 2, "EIGHT": 3}],
		["the cursor's hover values are pinned", cursor_constants.get("HoverMode"), {"POINT": 0, "OVERLAP": 1}],
		["the cursor's bounce values are pinned", cursor_constants.get("BounceMode"), {"NONE": 0, "SOLIDS": 1, "CONSTRAINTS": 2, "BOTH": 3}],
	])
	root.free()
	return result
