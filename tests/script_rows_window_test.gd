@tool
class_name ScriptRowsWindowTest
extends RefCounted

# Godot EventSheets - the "%s in event sheets" window reads its list from the one scan.
#
# The scan the window draws from carries, per row: the sentence the script wrote, the line of the
# function (so "Go to the line" lands on it), and the members the script hides, marked "left out"
# rather than dropped, so unticking is not a one-way door. Names and ids are unchanged.

const SUPPORT := preload("res://tests/support.gd")
const TWIN: String = "res://tests/fixtures/script_rows/annotated_twin.gd"


static func run() -> bool:
	var scan: Dictionary = EventSheetProviderPreview.scan(TWIN)
	var by_member: Dictionary = {}
	for entry: Dictionary in scan.get("entries", []):
		by_member["%s:%s" % [entry.get("source", ""), entry.get("member", "")]] = entry
	var take: Dictionary = by_member.get("method:take_damage", {})
	var hidden: Dictionary = by_member.get("method:internal_step", {})
	return SUPPORT.pins("script_rows_window_test", [
		["the scan still reads the script", scan.get("ok", false), true],
		["a row keeps its name", str(take.get("label", "")), "Hurt"],
		["a row carries the sentence the script wrote", str(take.get("sentence", "<none>")), "Take {amount} damage"],
		["and the line of its function", int(take.get("line", -1)), 15],
		["a hidden member is listed", by_member.has("method:internal_step"), true],
		["and marked left out", bool(hidden.get("left_out", false)), true],
	])
