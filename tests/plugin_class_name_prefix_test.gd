# Godot EventSheets - the plugin's class names stay prefixed.
#
# Godot keeps one list of class names for a whole project, so a plugin class called EventRow can
# collide with a game's own EventRow and stop the plugin loading. Every class_name under
# addons/eventforge/ and addons/eventsheet/ therefore carries an EventSheet, EventForge or ACE
# prefix - except the names below, which shipped before that rule and are frozen by the public API
# (renaming one breaks every saved sheet and script that names it). The list only shrinks: a name
# that no longer exists fails the test until it is taken off.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "plugin_class_name_prefix_test"
const FOLDERS: Array[String] = ["res://addons/eventforge", "res://addons/eventsheet"]
const PREFIXES: Array[String] = ["EventSheet", "EventForge", "ACE"]
## Unprefixed names that shipped first. Frozen by the public API; never add to this list.
const ALLOWED: Array[String] = [
	"CollectionDeclRow", "CommentRow", "CustomBlockRow", "EditorParamStore", "EnumRow", "EventAnchorRow",
	"EventFunction", "EventGroup", "EventGroupResource", "EventRow", "EventRowData", "FunctionAnchorRow",
	"InnerClassRow", "LocalVariable", "MatchCase", "MatchRow", "MomentBlockRow", "MomentStepRow",
	"PickFilter", "RawCodeRow", "SignalRow", "TimelineRow", "TimelineStep",
]
## How much of a script is read to find its class_name, which comes before any code.
const HEAD_BYTES := 8192


static func run() -> bool:
	var pattern: RegEx = RegEx.create_from_string("(?m)^class_name\\s+([A-Za-z_][A-Za-z0-9_]*)")
	var declared: Dictionary = {}
	for folder: String in FOLDERS:
		_collect(folder, pattern, declared)
	var unprefixed: Array = []
	for declared_name: String in declared:
		var prefixed: bool = false
		for prefix: String in PREFIXES:
			prefixed = prefixed or declared_name.begins_with(prefix)
		if not prefixed and not ALLOWED.has(declared_name):
			unprefixed.append("%s (%s)" % [declared_name, declared[declared_name]])
	unprefixed.sort()
	var stale: Array = []
	for allowed_name: String in ALLOWED:
		if not declared.has(allowed_name):
			stale.append(allowed_name)
	return SUPPORT.pins(P, [
		["every plugin class_name is prefixed EventSheet, EventForge or ACE. A new internal helper should prefer no class_name at all (preload it by path), since each name is one a game's own script could already use",
			unprefixed, []],
		["an allow-list entry whose class no longer exists is taken off the list, so the list only shrinks", stale, []],
	])


static func _collect(folder: String, pattern: RegEx, out: Dictionary) -> void:
	for file_name: String in DirAccess.get_files_at(folder):
		if file_name.get_extension() != "gd":
			continue
		var file: FileAccess = FileAccess.open(folder.path_join(file_name), FileAccess.READ)
		if file == null:
			continue
		var found: RegExMatch = pattern.search(file.get_buffer(HEAD_BYTES).get_string_from_utf8())
		if found != null:
			out[found.get_string(1)] = folder.path_join(file_name)
	for child: String in DirAccess.get_directories_at(folder):
		_collect(folder.path_join(child), pattern, out)
