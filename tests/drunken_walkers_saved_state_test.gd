# Godot EventSheets - Drunken Walkers: a state saved by an older version still loads, and saves back unchanged.
#
# A walker and a mark are small classes inside the behaviour now, but the state they are saved in is
# the same text it always was. This loads a state written in the old form, as plain text, pins what
# the behaviour reads out of it, and pins that saving it again gives the identical text.
@tool
class_name DrunkenWalkersSavedStateTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const NAME: String = "drunken_walkers_saved_state_test"
const PACK: String = "res://eventsheet_addons/drunken_walkers/drunken_walkers_addon.gd"

## A state exactly as the behaviour wrote it before its walkers and marks became classes: a six by
## five grid, one walker stopped part way, three marks.
const OLD_FORM: String = "{\"cellSize\":32,\"cells\":[0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,0,0,1,0,0,0,0,0,1,0,0,0],\"emptyValue\":0,\"height\":5,\"injected\":[],\"marks\":[{\"tag\":\"coin\",\"x\":2,\"y\":4},{\"tag\":\"coin\",\"x\":2,\"y\":2},{\"tag\":\"coin\",\"x\":1,\"y\":2}],\"originX\":0.0,\"originY\":0.0,\"randomSource\":\"internal\",\"rngSeed\":\"1383873669\",\"rngState\":\"6406646002565572497\",\"seed\":\"old-form\",\"version\":1,\"walkers\":[{\"borderRerolls\":0,\"brushHeight\":0,\"brushSize\":1,\"brushWidth\":0,\"carveValue\":1,\"directions\":4,\"finished\":false,\"heading\":90.0,\"id\":\"a\",\"maxTurn\":180.0,\"path\":[2,2,1,2,2,2,2,3,2,4],\"startAngle\":0.0,\"startX\":2,\"startY\":2,\"started\":true,\"steps\":6,\"stepsLeft\":2,\"tag\":\"t\",\"turnChance\":1.0,\"weights\":[1.0,2.0,1.0,1.0],\"x\":2,\"y\":4}],\"width\":6}"


static func run() -> bool:
	var script: GDScript = load(PACK) as GDScript
	var walkers: Node = script.new() as Node
	walkers.call("load_state_from_text", OLD_FORM)
	var walker: Variant = (walkers.get("_walkers") as Dictionary).get("a")
	var rows: Array = [
		["the grid is read", [walkers.call("current_grid_width"), walkers.call("current_grid_height")], [6, 5]],
		["the walker is read back", [walker != null, walker.get("x"), walker.get("y"), walker.get("steps_left"), (walker.get("path") as Array).size()], [true, 2, 4, 2, 5]],
		["the marks are read back", [walkers.call("count_marks", "coin"), walkers.call("has_mark_at", 2, 4, "coin"), walkers.call("mark_x_by_index", "coin", 2)], [3, true, 1]],
		["saving it again gives the same text", walkers.call("save_state_as_text"), OLD_FORM],
	]
	walkers.free()
	return SUPPORT.pins(NAME, rows)
