# Godot EventSheets - The guide to building on the plugin names every public function.
#
# The public API is one all-static class; a function it offers that its guide never names is one a
# reader cannot find. Each public static function of `EventSheets` must be named in the guide, and
# in its Full Reference table: the table is where a reader looks to see everything that exists.
@tool
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const P := "api_guide_names_every_function_test"
const API_PATH := "res://addons/eventsheet/api/eventsheets.gd"
const GUIDE_PATH := "res://addons/eventsheet/help/GUIDE-BUILDING-ON-EVENTSHEETS.md"
const SOURCE_GUIDE_PATH := "res://docs/GUIDE-BUILDING-ON-EVENTSHEETS.md"
const REFERENCE_HEADING := "## 7. Full Reference"
const NEXT_HEADING := "## 8. Use Cases"


static func run() -> bool:
	var guide: String = FileAccess.get_file_as_string(GUIDE_PATH)
	var declared: RegEx = RegEx.create_from_string("(?m)^static func ([a-z][a-z0-9_]*)\\(")
	var missing: Array[String] = []
	for found: RegExMatch in declared.search_all(FileAccess.get_file_as_string(API_PATH)):
		var name: String = found.get_string(1)
		var named: RegEx = RegEx.create_from_string("\\b%s\\b" % name)
		if named.search(guide) == null and not missing.has(name):
			missing.append(name)
	missing.sort()
	var source_guide: String = FileAccess.get_file_as_string(SOURCE_GUIDE_PATH)
	var start: int = source_guide.find(REFERENCE_HEADING)
	var table: String = source_guide.substr(start, source_guide.find(NEXT_HEADING) - start)
	var unlisted: Array[String] = []
	for found: RegExMatch in declared.search_all(FileAccess.get_file_as_string(API_PATH)):
		var name: String = found.get_string(1)
		if RegEx.create_from_string("\\b%s\\b" % name).search(table) == null and not unlisted.has(name):
			unlisted.append(name)
	unlisted.sort()
	var ok: bool = SUPPORT.check(P, "every public function is named in the guide", missing, [])
	ok = SUPPORT.check(P, "every public function is in the Full Reference table", unlisted, []) and ok
	return SUPPORT.check(P, "the Full Reference table was found", start >= 0 and not table.is_empty(), true) and ok
