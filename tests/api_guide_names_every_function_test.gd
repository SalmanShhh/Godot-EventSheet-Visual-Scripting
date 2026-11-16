# Godot EventSheets - The guide to building on the plugin names every public function.
#
# The public API is one all-static class; a function it offers that its guide never names is one a
# reader cannot find. Each public static function of `EventSheets` must be named in the guide.
@tool
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const P := "api_guide_names_every_function_test"
const API_PATH := "res://addons/eventsheet/api/eventsheets.gd"
const GUIDE_PATH := "res://addons/eventsheet/help/GUIDE-BUILDING-ON-EVENTSHEETS.md"


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
	return SUPPORT.check(P, "every public function is named in the guide", missing, [])
