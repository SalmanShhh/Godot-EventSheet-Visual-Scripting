# Godot EventSheets - the Doctor's Class Name Clashes section.
#
# A script of the reader's whose class_name is one the plugin or a shipped behaviour uses is a
# finding that names both files: an error when something already in the project holds the name (the
# plugin itself, or a behaviour the project has), a warning when only the plugin's library does. The
# section is pinned by value over hand-made tables, and then once against this very repo, which
# must stay quiet: the library copies under the ignored folder repeat names by design and are not in
# Godot's list.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const SECTION := preload("res://addons/eventforge/class_name_clash_doctor.gd")
const P := "class_name_clash_doctor_test"


static func run() -> bool:
	var user: Dictionary = {
		"res://game/a.gd": "EventRow",
		"res://game/b.gd": "NavAgent3D",
		"res://game/c.gd": "WorldLook",
		"res://game/d.gd": "MyOwnThing",
		"res://game/same.gd": "SameFile",
	}
	var plugin: Dictionary = {"EventRow": "res://addons/eventforge/resources/event_row.gd", "SameFile": "res://game/same.gd"}
	var held: Dictionary = {"NavAgent3D": "res://eventsheet_addons/nav_agent_3d/nav_agent_3d_behavior.gd"}
	var library: Dictionary = {"WorldLook": "world_look.gd", "NavAgent3D": "nav_agent_3d"}
	var found: Array[Dictionary] = SECTION.report(user, plugin, held, library)
	var rows: Array = found.map(func(finding: Dictionary) -> Array:
		return [finding["severity"], finding["path"], finding["subject"]])
	var ok: bool = SUPPORT.pins(P, [
		["a plugin class name is an error, a held behaviour's is an error, a library-only name is a warning; a name of its own is quiet",
			rows, [["error", "res://game/a.gd", "EventRow"], ["error", "res://game/b.gd", "NavAgent3D"],
				["warning", "res://game/c.gd", "WorldLook"]]],
		["the plugin message names both files", [str(found[0]["message"]).contains("a.gd"),
			str(found[0]["message"]).contains("res://addons/eventforge/resources/event_row.gd")], [true, true]],
		["the held-behaviour message names the behaviour's file",
			str(found[1]["message"]).contains("res://eventsheet_addons/nav_agent_3d/nav_agent_3d_behavior.gd"), true],
		["the library message names the behaviour and says Add to project refuses",
			[str(found[2]["message"]).contains("world_look.gd"), str(found[2]["message"]).contains("Add to project")], [true, true]],
		["a script holding the very file that declares the name is not a clash",
			SECTION.report({"res://game/same.gd": "SameFile"}, plugin, {}, {}), []],
	])
	var live: Array[Dictionary] = []
	SECTION.check(PackedStringArray(), live)
	ok = SUPPORT.pins(P, [["this repository has no clash of its own", live, []]]) and ok
	return ok
