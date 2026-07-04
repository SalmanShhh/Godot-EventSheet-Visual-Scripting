# EventForge - clean-removal contract test.
# The headline covenant is "delete the plugin and your game still runs": every shipped
# generated script and behavior pack must reference NO plugin class and must parse on its
# own. This turns that promise from a claim into a gate: scan each output's CODE (comments
# and the global class_name line excluded) for banned EventForge*/EventSheet* symbols, and
# reload() it as a standalone GDScript to confirm it parses without the plugin on the path.
@tool
class_name CleanRemovalTest
extends RefCounted

const BANNED: Array[String] = ["EventForge", "EventSheet", "addons/eventforge", "addons/eventsheet"]


static func run() -> bool:
	var passed: bool = true
	var files: Array[String] = []
	# Behavior packs (the game uses these as plain classes after removal).
	_collect(files, "res://eventsheet_addons", "_behavior.gd")
	# Compiled demo + showcase scripts (what scenes actually attach).
	_collect(files, "res://demo", "_generated.gd")
	for showcase_gd: String in ["res://demo/showcase/showcase_carousel.gd", "res://demo/showcase/starfall.gd", "res://demo/showcase/quest_fsm.gd"]:
		if FileAccess.file_exists(showcase_gd):
			files.append(showcase_gd)

	passed = _check("found generated outputs to verify", files.size() > 0, true) and passed
	for path: String in files:
		var source: String = FileAccess.get_file_as_string(path)
		var name: String = path.get_file()
		# CODE only: drop comment lines and the class_name registration line.
		var code: String = ""
		for source_line: String in source.split("\n"):
			var trimmed: String = source_line.strip_edges()
			if trimmed.begins_with("#") or trimmed.begins_with("class_name "):
				continue
			code += source_line + "\n"
		for banned: String in BANNED:
			passed = _check("%s code references no '%s'" % [name, banned], code.contains(banned), false) and passed
		# Parses standalone (strip class_name so reload doesn't collide with the already-
		# registered global class - that's a registration conflict, not a syntax fault).
		var parse_source: String = ""
		for source_line: String in source.split("\n"):
			if source_line.begins_with("class_name "):
				continue
			parse_source += source_line + "\n"
		var script: GDScript = GDScript.new()
		script.source_code = parse_source
		passed = _check("%s parses standalone (no plugin on path)" % name, script.reload(true) == OK, true) and passed
	return passed


static func _collect(out: Array[String], root: String, suffix: String) -> void:
	var dir: DirAccess = DirAccess.open(root)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while not entry.is_empty():
		var full: String = root.path_join(entry)
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_collect(out, full, suffix)
		elif entry.ends_with(suffix):
			out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] clean_removal_test: %s" % label)
		return true
	print("[FAIL] clean_removal_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
