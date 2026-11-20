# EventSheets - no script assigns another script's static variable.
#
# In the editor, a static variable assigned from outside its own script (`SomeClass.value = x`, or
# `load(path).value = x`) marks that script resource as edited. Godot's scene save then writes every
# edited script back to its file: the bytes are identical, but each rewrite makes the engine reload the
# script and refresh the class list, and the first scene save of a session with a sheet open took seconds
# (one of the rewritten scripts is more than a megabyte). A write made from inside the owning script does
# not mark it, so a script that needs to be written from elsewhere offers a `static func set_<name>`.
#
# The sweep reads the shipped editor scripts as text: every `static var` of a script that has a
# `class_name`, then every assignment to `ClassName.<that var>` in any other script (plain `=` and the
# compound forms), and the same through a `preload` constant and through `load("res://...")`.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "static_var_outside_writes_test"

## The shipped scripts that are not editor code: packs run in the game, where the flag means nothing.
const SKIPPED_FOLDERS: PackedStringArray = ["res://addons/eventsheet/help", "res://addons/eventsheet_library"]


static func run() -> bool:
	var owner_text: String = "class_name Owner\nextends RefCounted\n\nstatic var count: int = 0\nstatic var _hidden: bool = false\n\n\nstatic func set_count(value: int) -> void:\n\tcount = value\n"
	var other_text: String = "extends RefCounted\n\n\nfunc go() -> void:\n\tOwner.count = 3\n\tOwner.count += 1\n\tOwner.set_count(2)\n\tvar same: bool = Owner.count == 3\n"
	var inside: Dictionary = {"res://a/owner.gd": owner_text + "\n\nstatic func bump() -> void:\n\tOwner.count = 4\n"}
	var ok: bool = SUPPORT.pins(P, [
		["an assignment and a compound assignment from another script are named, a call and a comparison are not",
			outside_writes({"res://a/owner.gd": owner_text, "res://a/other.gd": other_text}),
			PackedStringArray(["res://a/other.gd:5 Owner.count", "res://a/other.gd:6 Owner.count"])],
		["a write inside the owning script is not an outside write", outside_writes(inside), PackedStringArray()],
		["a write through a preload constant is named",
			outside_writes({"res://a/owner.gd": owner_text, "res://a/viaconst.gd": "const O := preload(\"res://a/owner.gd\")\n\nfunc go() -> void:\n\tO._hidden = true\n"}),
			PackedStringArray(["res://a/viaconst.gd:4 O._hidden"])],
		["a write through load() is named",
			outside_writes({"res://a/owner.gd": owner_text, "res://a/viaload.gd": "func go() -> void:\n\tload(\"res://a/owner.gd\").count = 1\n"}),
			PackedStringArray(["res://a/viaload.gd:2 res://a/owner.gd.count"])],
	])
	var texts: Dictionary = {}
	_gather("res://addons", texts)
	var found: PackedStringArray = outside_writes(texts)
	ok = SUPPORT.check(P, "no shipped editor script assigns another script's static variable", found, PackedStringArray()) and ok
	return ok


static func _gather(folder: String, into: Dictionary) -> void:
	if SKIPPED_FOLDERS.has(folder):
		return
	for file: String in DirAccess.get_files_at(folder):
		if file.ends_with(".gd"):
			into[folder + "/" + file] = FileAccess.get_file_as_string(folder + "/" + file)
	for sub: String in DirAccess.get_directories_at(folder):
		_gather(folder + "/" + sub, into)


## "<path>:<line> <what>" for each assignment, from outside, to a static variable of a script, in path order.
static func outside_writes(texts: Dictionary) -> PackedStringArray:
	var statics: Dictionary = {}
	var by_class: Dictionary = {}
	for path: String in texts:
		var text: String = str(texts[path])
		var names: PackedStringArray = PackedStringArray()
		for found: RegExMatch in RegEx.create_from_string("(?m)^static var (\\w+)").search_all(text):
			names.append(found.get_string(1))
		statics[path] = names
		var declared: RegExMatch = RegEx.create_from_string("(?m)^class_name (\\w+)").search(text)
		if declared != null and not names.is_empty():
			by_class[declared.get_string(1)] = path
	var assign: String = "\\s*(?:=(?!=)|\\+=|-=|\\*=|/=|\\|=)"
	var out: PackedStringArray = PackedStringArray()
	var paths: Array = texts.keys()
	paths.sort()
	for path: String in paths:
		var text: String = str(texts[path])
		var targets: Dictionary = {}
		for class_label: String in by_class:
			targets[class_label] = by_class[class_label]
		for constant: RegExMatch in RegEx.create_from_string("(?m)^const (\\w+)\\s*(?::=|:\\s*\\w+\\s*=)\\s*preload\\(\"(res://[^\"]+)\"\\)").search_all(text):
			if statics.has(constant.get_string(2)):
				targets[constant.get_string(1)] = constant.get_string(2)
		for label: String in targets:
			var owner_path: String = targets[label]
			for write: RegExMatch in RegEx.create_from_string("\\b" + label + "\\.(\\w+)" + assign).search_all(text):
				if owner_path != path and (statics[owner_path] as PackedStringArray).has(write.get_string(1)):
					out.append("%s:%d %s.%s" % [path, text.count("\n", 0, write.get_start()) + 1, label, write.get_string(1)])
		for loaded: RegExMatch in RegEx.create_from_string("load\\(\"(res://[^\"]+)\"\\)\\.(\\w+)" + assign).search_all(text):
			if statics.has(loaded.get_string(1)) and (statics[loaded.get_string(1)] as PackedStringArray).has(loaded.get_string(2)):
				out.append("%s:%d %s.%s" % [path, text.count("\n", 0, loaded.get_start()) + 1, loaded.get_string(1), loaded.get_string(2)])
	return out
