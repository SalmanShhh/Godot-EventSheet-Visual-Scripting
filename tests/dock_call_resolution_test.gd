# Godot EventSheets - every `_dock.<name>(` call in the editor names something the dock has.
#
# The menus and the dock's ~40 helpers reach back into the dock through a `_dock` reference, and
# the menus dispatch by `match id:` arms that call `_dock._something()`. A call to a method the
# dock no longer has is not a parse error - it only prints a script error at click time, which is
# how Sheet > Publish New Version broke when its dock forwarder was folded into the provider glue.
# This test reads every editor file that holds a `_dock` reference, collects each `_dock.<name>(`
# and `_dock.<delegate>.<name>(` call, and asks the dock's script (and, for a delegate, the script
# or class the dock declares it with) whether the name is a method, variable or signal there.
@tool
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const EDITOR_ROOT := "res://addons/eventsheet/editor"
const DOCK_PATH := "res://addons/eventsheet/editor/event_sheet_dock.gd"
const EDITOR_PATH := "res://addons/eventforge/editor/event_sheet_editor.gd"
# Declared types that say nothing about what the delegate really is; a delegate typed only this
# loosely is checked when the dock also names the script it loads, and skipped otherwise.
const LOOSE_TYPES := ["", "Variant", "Object", "RefCounted", "Node", "Control", "Resource"]


static func run() -> bool:
	var all_passed: bool = true
	var dock_script: Script = load(EDITOR_PATH)
	var delegates: Dictionary = _delegate_kinds(FileAccess.get_file_as_string(DOCK_PATH))
	var direct_unresolved: Array = []
	var delegate_unresolved: Array = []
	var direct_seen: Dictionary = {}
	var direct_re := RegEx.create_from_string("\\b_dock\\.([A-Za-z_][A-Za-z0-9_]*)\\(")
	var chain_re := RegEx.create_from_string("\\b_dock\\.([A-Za-z_][A-Za-z0-9_]*)\\.([A-Za-z_][A-Za-z0-9_]*)\\(")
	var checked_chains: int = 0
	for path: String in _editor_files(EDITOR_ROOT):
		var source: String = FileAccess.get_file_as_string(path)
		if not source.contains("var _dock"):
			continue
		var code: String = _without_comments(source)
		for found: RegExMatch in direct_re.search_all(code):
			var name: String = found.get_string(1)
			direct_seen[name] = true
			if not _script_has(dock_script, name):
				direct_unresolved.append("%s: _dock.%s(" % [path.get_file(), name])
		for found: RegExMatch in chain_re.search_all(code):
			var holder: String = found.get_string(1)
			var name: String = found.get_string(2)
			if not delegates.has(holder):
				continue
			checked_chains += 1
			if not _kind_has(delegates[holder], name):
				delegate_unresolved.append("%s: _dock.%s.%s(" % [path.get_file(), holder, name])
	all_passed = _check("every _dock.<name>( call names a dock method, variable or signal",
		direct_unresolved, []) and all_passed
	all_passed = _check("every _dock.<delegate>.<name>( call names something on that delegate",
		delegate_unresolved, []) and all_passed
	# The Publish New Version break: the menu called a dock forwarder that had been folded away.
	all_passed = _check("the dock has no _open_publish_version_dialog forwarder",
		_script_has(dock_script, "_open_publish_version_dialog"), false) and all_passed
	all_passed = _check("the menu reaches the provider glue's open_publish_version_dialog",
		_kind_has(delegates.get("_providers_glue", null), "open_publish_version_dialog"), true) and all_passed
	all_passed = _check("the walk really read the menus (direct calls seen include the menu's)",
		[direct_seen.has("_open_sheet_type_dialog"), direct_seen.has("_open_include_manager")],
		[true, true]) and all_passed
	all_passed = _check("the walk resolved delegate chains (more than a hundred checked)",
		checked_chains > 100, true) and all_passed
	return all_passed


# The dock's delegate variables, each mapped to the Script it is known to hold or to a native
# class name; a delegate typed loosely with no script named anywhere is left out.
static func _delegate_kinds(dock_source: String) -> Dictionary:
	var kinds: Dictionary = {}
	var classes: Dictionary = {}
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		classes[str(entry["class"])] = str(entry["path"])
	var consts: Dictionary = {}
	var const_re := RegEx.create_from_string("(?m)^const ([A-Za-z_][A-Za-z0-9_]*)\\s*(?::=|=)\\s*preload\\(\"([^\"]+)\"\\)")
	for found: RegExMatch in const_re.search_all(dock_source):
		consts[found.get_string(1)] = found.get_string(2)
	var lines: PackedStringArray = dock_source.split("\n")
	var var_re := RegEx.create_from_string("^(?:@onready )?var ([A-Za-z_][A-Za-z0-9_]*)\\s*(?::\\s*([A-Za-z_][A-Za-z0-9_.]*))?")
	for index: int in lines.size():
		var found: RegExMatch = var_re.search(lines[index])
		if found == null:
			continue
		var name: String = found.get_string(1)
		var declared: String = found.get_string(2)
		var script_path: String = _script_path_for(name, dock_source, consts)
		if script_path.is_empty() and classes.has(declared):
			script_path = classes[declared]
		if not script_path.is_empty():
			kinds[name] = load(script_path)
		elif not LOOSE_TYPES.has(declared) and ClassDB.class_exists(declared):
			kinds[name] = declared
	return kinds


# The script a dock variable is filled from: its getter's or an assignment's load/preload path,
# or a preloaded const it is built from.
static func _script_path_for(name: String, dock_source: String, consts: Dictionary) -> String:
	var load_re := RegEx.create_from_string("\\b%s\\s*(?::[^=\\n]*)?=\\s*(?:load|preload)\\(\"([^\"]+\\.gd)\"\\)" % name)
	var found: RegExMatch = load_re.search(dock_source)
	if found != null:
		return found.get_string(1)
	var const_new_re := RegEx.create_from_string("\\b%s\\s*(?::[^=\\n]*)?=\\s*([A-Za-z_][A-Za-z0-9_]*)\\.new\\(" % name)
	found = const_new_re.search(dock_source)
	if found != null and consts.has(found.get_string(1)):
		return consts[found.get_string(1)]
	return ""


static func _kind_has(kind: Variant, name: String) -> bool:
	if kind is Script:
		return _script_has(kind, name)
	if kind is String:
		return _native_has(kind, name)
	return false


static func _script_has(script: Script, name: String) -> bool:
	var walk: Script = script
	while walk != null:
		for method: Dictionary in walk.get_script_method_list():
			if method["name"] == name:
				return true
		for property: Dictionary in walk.get_script_property_list():
			if property["name"] == name:
				return true
		for sig: Dictionary in walk.get_script_signal_list():
			if sig["name"] == name:
				return true
		if walk.get_script_constant_map().has(name):
			return true
		walk = walk.get_base_script()
	return _native_has(script.get_instance_base_type(), name)


static func _native_has(class_named: String, name: String) -> bool:
	if ClassDB.class_has_method(class_named, name) or ClassDB.class_has_signal(class_named, name):
		return true
	for property: Dictionary in ClassDB.class_get_property_list(class_named):
		if property["name"] == name:
			return true
	return false


# The source with each line's comment cut off (a `#` outside a string starts one).
static func _without_comments(source: String) -> String:
	var kept: PackedStringArray = []
	for line: String in source.split("\n"):
		var in_string: bool = false
		var quote: String = ""
		var cut: int = line.length()
		var index: int = 0
		while index < line.length():
			var ch: String = line[index]
			if in_string:
				if ch == "\\":
					index += 1
				elif ch == quote:
					in_string = false
			elif ch == "\"" or ch == "'":
				in_string = true
				quote = ch
			elif ch == "#":
				cut = index
				break
			index += 1
		kept.append(line.substr(0, cut))
	return "\n".join(kept)


static func _editor_files(root: String) -> Array:
	var files: Array = []
	var dir: DirAccess = DirAccess.open(root)
	if dir == null:
		return files
	for sub: String in dir.get_directories():
		files.append_array(_editor_files(root.path_join(sub)))
	for file: String in dir.get_files():
		if file.ends_with(".gd"):
			files.append(root.path_join(file))
	files.sort()
	return files


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("dock_call_resolution_test", label, actual, expected)
