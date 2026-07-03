# EventForge - the GDScript style-guide gate (docs.godotengine.org GDScript style guide).
#
# Sweeps every HAND-WRITTEN .gd (addons / tests / tools / demo showcase) and fails on:
#   1. `extends` before `class_name` (the guide puts class_name first)
#   2. a top-level func/class without two blank lines above it (counting its attached
#      comment/annotation block; multiline strings are skipped so fixtures with column-0
#      `func` INSIDE """...""" never false-positive)
#   3. camelCase function/variable names (with a small documented allowlist: resource
#      properties that are public API - renaming them would break saved .tres files and the
#      pack-author compatibility covenant)
#
# eventsheet_addons/*.gd and demo/sheets are COMPILER OUTPUT - their formatting is the
# emitter's contract (single blank between functions, byte-stable regeneration), a deliberate,
# documented deviation; the gate does not scan them.
@tool
class_name StyleGuideTest
extends RefCounted

const SCAN_ROOTS: Array[String] = ["res://addons", "res://tests", "res://tools", "res://demo/showcase"]

## Public-API resource properties frozen for compatibility (saved .tres files + pack authors
## reference them by name); everything else must be snake_case.
const NAMING_ALLOWLIST: Array[String] = ["listName", "nodeType", "initialValue", "displayText"]


static func run() -> bool:
	var violations: PackedStringArray = PackedStringArray()
	var scanned: int = 0
	for root: String in SCAN_ROOTS:
		scanned += _scan_directory(root, violations)
	for violation: String in violations:
		print("  style: %s" % violation)
	var all_passed: bool = true
	all_passed = _check("every hand-written script passes the style gate (%d scanned)" % scanned, violations.size(), 0) and all_passed
	return all_passed


static func _scan_directory(dir_path: String, violations: PackedStringArray) -> int:
	var scanned: int = 0
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return 0
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while not entry.is_empty():
		var full_path: String = dir_path.path_join(entry)
		if dir.current_is_dir():
			if not entry.begins_with("."):
				scanned += _scan_directory(full_path, violations)
		elif entry.get_extension() == "gd":
			_scan_file(full_path, violations)
			scanned += 1
		entry = dir.get_next()
	dir.list_dir_end()
	return scanned


static func _scan_file(path: String, violations: PackedStringArray) -> void:
	var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
	var extends_line: int = -1
	var class_name_line: int = -1
	var in_string: bool = false
	var name_regex: RegEx = RegEx.new()
	name_regex.compile("^\\t*(?:static func |func |(?:@export[a-z_()\" ,0-9.]*\\s+)?var )([A-Za-z_][A-Za-z0-9_]*)")
	for index: int in range(lines.size()):
		var line: String = lines[index]
		if in_string:
			if line.count("\"\"\"") % 2 == 1:
				in_string = false
			continue
		if extends_line < 0 and line.begins_with("extends "):
			extends_line = index
		if class_name_line < 0 and line.begins_with("class_name "):
			class_name_line = index
		if line.begins_with("func ") or line.begins_with("static func ") or (line.begins_with("class ") and line.contains(":")):
			var anchor: int = index
			while anchor > 0 and (lines[anchor - 1].begins_with("#") or lines[anchor - 1].begins_with("@")):
				anchor -= 1
			if anchor >= 2 and not (lines[anchor - 1].strip_edges().is_empty() and lines[anchor - 2].strip_edges().is_empty()):
				violations.append("%s:%d needs two blank lines above the declaration" % [path, index + 1])
		var name_match: RegExMatch = name_regex.search(line)
		if name_match != null:
			var declared: String = name_match.get_string(1)
			if declared.to_lower() != declared and not NAMING_ALLOWLIST.has(declared):
				violations.append("%s:%d '%s' is not snake_case" % [path, index + 1, declared])
		if line.count("\"\"\"") % 2 == 1:
			in_string = true
	if extends_line >= 0 and class_name_line >= 0 and extends_line < class_name_line:
		violations.append("%s: class_name must come before extends" % path)


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] style_guide_test: %s" % label)
		return true
	print("[FAIL] style_guide_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
