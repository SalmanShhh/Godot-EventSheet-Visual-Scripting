# EventSheets - a Reading line finding in the Check the project window knows which line of its script it is about,
# and the sheet's own source map names the row that wrote that line.
#
# The window opens the finding's script as a sheet and then selects the row holding the line. The two halves that can
# be pinned without a window are the reading of the line out of the finding, and that the source map of a script opened
# as a sheet answers a line of it with a row.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "doctor_reading_line_test"
const FIXTURE := "res://tests/fixtures/handwritten_state_patrol.gd"


static func run() -> bool:
	var panel: GDScript = load("res://addons/eventsheet/editor/dock/project_doctor_panel.gd")
	var rows: Array = [
		["a Reading line names its line", panel.reading_line_of({"check": "reading-line", "subject": "res://a/b.gd:42"}), 42],
		["a path with a colon in it still gives the last number", panel.reading_line_of({"check": "reading-line", "subject": "user://x.gd:7"}), 7],
		["the count of more lines of a shape names none", panel.reading_line_of({"check": "reading-line", "subject": "var name:name=number+"}), 0],
		["a subject whose tail is not a number names none", panel.reading_line_of({"check": "reading-line", "subject": "res://a.gd:abc"}), 0],
		["a finding of another section names none", panel.reading_line_of({"check": "reading-shape", "subject": "res://a.gd:9"}), 0],
		["a finding with no subject names none", panel.reading_line_of({"check": "reading-line"}), 0],
	]
	var text: String = FileAccess.get_file_as_string(FIXTURE)
	var function_line: int = 0
	var lines: PackedStringArray = text.split("\n")
	for index: int in range(lines.size()):
		if lines[index].strip_edges().begins_with("match "):
			function_line = index + 1
			break
	var sheet: EventSheetResource = EventSheetGDScriptImporter.new().import_external(FIXTURE)
	var mapped: Dictionary = EventSheetRuntimeErrorLocator.source_map_for(sheet, false)
	var entries: Array = EventSheetLineRowMapper.entries_for_line(mapped.get("map", []), function_line)
	var resource: Resource = null
	for entry: Variant in entries:
		resource = instance_from_id(int(str((entry as Dictionary).get("uid", "0")))) as Resource
		if resource != null:
			break
	rows.append(["the fixture has a match to ask about", function_line > 0, true])
	rows.append(["the script opened as a sheet is not stale against its file", bool(mapped.get("stale", true)), false])
	rows.append(["the source map answers a line inside a function with a row", resource != null, true])
	return SUPPORT.pins(P, rows)
