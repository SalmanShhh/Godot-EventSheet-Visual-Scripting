# Godot EventSheets - the Doctor window's unread mark is one quiet dot
#
# A finding that was not here last time leads with a small dot; a finding that was leads with
# nothing. There is no coloured bar down the cell's edge, and the dot keeps clear of the section
# word beside it, so a line reads the same whether it is marked or not. Pinned as data: what the
# mark would draw in a cell (`mark_shapes`), and that a read and an unread line fill their cells
# the same way, so marking a line as read cannot move its words sideways.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME := "doctor_unread_mark_test"


static func run() -> bool:
	var page: Array[Dictionary] = [
		{"severity": "info", "check": "reading", "path": "res://coin.gd", "message": "a new line", "is_new": true},
		{"severity": "info", "check": "reading", "path": "res://door.gd", "message": "an old line", "is_new": false},
	]
	var tree: Tree = EventSheetProjectDoctorPanel.inbox_tree()
	EventSheetProjectDoctorPanel.fill_inbox(tree, tree.create_item(), page)
	var branch: TreeItem = tree.get_root().get_first_child()
	var fresh: TreeItem = branch.get_child(0)
	var seen: TreeItem = branch.get_child(1)

	# A cell as narrow as a child row's is once its indent is taken off the column.
	var narrow: Rect2 = Rect2(Vector2(40.0, 10.0), Vector2(30.0, 24.0))
	var shapes: Array[Dictionary] = EventSheetProjectDoctorPanel.mark_shapes(narrow, true)
	var circle: Dictionary = shapes[0] if shapes.size() > 0 else {}
	var center: Vector2 = circle.get("center", Vector2.ZERO)
	var radius: float = float(circle.get("radius", 0.0))
	var kinds: Array = []
	for shape: Dictionary in shapes:
		kinds.append(str(shape.get("kind", "")))
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["an unread cell draws one circle and no bar", kinds, ["circle"]],
		["a read cell draws nothing", EventSheetProjectDoctorPanel.mark_shapes(narrow, false).size(), 0],
		["the dot is inside its cell on the left", center.x - radius >= narrow.position.x, true],
		["the dot leaves a clear gap before the cell's right edge, where the section word starts",
			narrow.end.x - (center.x + radius) >= 6.0, true],
		["the dot is centred down the cell", center.y, narrow.position.y + narrow.size.y / 2.0],
		["the dot is small", radius <= 4.0, true],
		["an unread and a read line both keep column 0 free of text", [fresh.get_text(0), seen.get_text(0)], ["", ""]],
		["an unread and a read line fill the cell the same way", fresh.get_cell_mode(0), seen.get_cell_mode(0)],
		["the section word is in the same column for both", [fresh.get_text(1), seen.get_text(1)], ["Reading", "Reading"]],
		["the mark column is wide enough for an indented dot", tree.get_column_width(0) >= 40, true],
	])
	tree.free()
	return ok
