# EventForge - stepping round a list is not switching weapons. `current = (current + 1) % points.size()`
# is how any list is walked round - a patrol's next point, a menu's next entry - so a file that writes
# it keeps its own line rather than being lifted into the weapon wheel's "Switch to next weapon" row,
# which would say something about weapons the file never has. The bytes stay the file's either way.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")

const SOURCE := "extends Node\n\nvar current: int = 0\nvar points: Array[Vector2] = []\n\n\nfunc _process(_delta: float) -> void:\n\tcurrent = (current + 1) % points.size()\n\tcurrent = (current - 1 + points.size()) % points.size()\n"


static func run() -> bool:
	var sheet: EventSheetResource = SUPPORT.reopen(SOURCE)
	var lifted: PackedStringArray = PackedStringArray()
	for entry: Variant in sheet.events:
		if entry is EventRow:
			for action: Variant in (entry as EventRow).actions:
				if action is ACEAction:
					lifted.append((action as ACEAction).ace_id)
	return SUPPORT.pins("list_step_reading_test", [
		["neither step is read as the weapon wheel",
			[lifted.has("SwitchToNextWeapon"), lifted.has("SwitchToPreviousWeapon")], [false, false]],
		["the file re-emits byte for byte", SUPPORT.reemit(SOURCE, "user://list_step_reading_test.gd"), SOURCE],
	])
