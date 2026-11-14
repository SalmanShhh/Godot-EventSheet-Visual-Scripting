# Godot EventSheets - a small class written inside a sheet is a type its rows may use, not a pick.
#
# A behaviour that keeps its records as small classes (`class Edge extends RefCounted:`) names them in
# typed locals and typed lists. The mistake check loads the rows it judges in a probe script, so the
# probe has to carry those classes, and a loop over a list of them is not "the picked node" a scene row
# could act on. This opens such a file and pins that the check has nothing to say about it.
@tool
class_name HelperClassRowsTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const NAME: String = "helper_class_rows_test"
const PATH: String = "user://helper_class_rows_probe.gd"
const SOURCE: String = """extends Node
class_name HelperClassRowsProbe

## One link.
class Link extends RefCounted:
	## Where it goes.
	var to: int = 0

var _links: Array[Link] = []


func total() -> int:
	var sum: int = 0
	for link: Link in _links:
		sum += link.to
	return sum


func add(to: int) -> void:
	var made: Link = Link.new()
	made.to = to
	_links.append(made)
"""


static func run() -> bool:
	var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(SOURCE)
	file.close()
	var sheet: EventSheetResource = EventSheetGDScriptImporter.new().import_external(PATH)
	if sheet == null:
		return SUPPORT.check(NAME, "the file opens as a sheet", false, true)
	var found: Array[Dictionary] = EventSheetMistakeFindings.findings(sheet, PATH)
	var kinds: Array = []
	for finding: Dictionary in found:
		kinds.append(str(finding.get("kind", "")))
	return SUPPORT.pins(NAME, [
		["a sheet that keeps its records as small classes earns no mistake finding", kinds, []],
		["a loop over a list of them picks nothing", EventSheetPickScope.all_picks(sheet).has("link"), false],
	])
