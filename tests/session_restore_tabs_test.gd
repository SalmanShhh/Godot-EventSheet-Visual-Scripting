# EventSheets - the saved session keeps each file once, caps what a very long session brings back, and
# keeps the tab in front. One file had come back as six tabs.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "session_restore_tabs_test"


static func run() -> bool:
	var store: GDScript = EventSheetSessionStore
	var spelled: PackedStringArray = PackedStringArray([
		"res://a.gd", "res://b.gd", "res://./a.gd", "res://sub/../a.gd", "res://c.gd", "res://b.gd"])
	var unique: Dictionary = store.unique_paths(spelled, 5)
	var many: PackedStringArray = PackedStringArray()
	for number: int in range(60):
		many.append("res://sheet_%02d.gd" % number)
	var capped_early: Dictionary = store.capped(many, 3)
	var capped_late: Dictionary = store.capped(many, 41)
	var few: Dictionary = store.capped(PackedStringArray(["res://a.gd", "res://b.gd"]), 1)
	return SUPPORT.pins(P, [
		["six saved tabs of three files are three tabs", unique["paths"], PackedStringArray(["res://a.gd", "res://b.gd", "res://c.gd"])],
		["the tab in front is the first copy of its file", unique["active"], 1],
		["spellings of one path are one file", store.same_file_key("res://sub/../a.gd"), "res://a.gd"],
		["a long session brings back the limit and no more", (capped_early["paths"] as PackedStringArray).size(), store.RESTORE_LIMIT],
		["it keeps the first tabs in their order", (capped_early["paths"] as PackedStringArray)[0], "res://sheet_00.gd"],
		["and the tab in front when it is among them", capped_early["active"], 3],
		["a tab in front that was saved past the limit still comes back", (capped_late["paths"] as PackedStringArray).has("res://sheet_41.gd"), true],
		["and is the one the restore ends on", (capped_late["paths"] as PackedStringArray)[capped_late["active"]], "res://sheet_41.gd"],
		["a short session is left as it is", few["paths"], PackedStringArray(["res://a.gd", "res://b.gd"])],
		["with its tab in front", few["active"], 1],
	])
