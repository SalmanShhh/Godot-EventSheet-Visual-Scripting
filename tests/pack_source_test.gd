# Godot EventSheets - the pack source folders, and the line between them and a pack.
#
# A pack's behaviour code lives in real `.gd` files under tools/pack_builders/src/<pack>/, which a
# builder assembles with Lib.pack_from_source. Two things have to stay true about that tree, and
# neither is obvious from reading it:
#
#   1. The READER is exact. A piece is either a `#region` pair around top-level code or the body of
#      a top-level `func`, dedented by one tab with its trailing blank lines trimmed. Every one of
#      those rules is a byte of an emitted pack, so each is pinned here on a fixture whose expected
#      text is written out in full rather than counted.
#   2. A source file is NOT a pack, NOT a test and NOT a document. It is ordinary GDScript sitting
#      under tools/, and the four scans that walk this repository looking for those things each
#      have to keep walking past it - the provider scan (which publishes vocabulary), the suite's
#      own discovery, the documentation index, and the style gate. Three of them are addressed by
#      where the tree lives; the fourth was taught about it on purpose, and that is asserted too.
@tool
class_name PackSourceTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const Lib := preload("res://tools/pack_builders/_lib.gd")
const AddonScanner := preload("res://addons/eventsheet/ace/addon_scanner.gd")
const StyleGuide := preload("res://tests/style_guide_test.gd")

const SOURCE_ROOT := "res://tools/pack_builders/src"
const FIXTURE_DIR := "user://eventsheets_pack_source_fixture"


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _reader_pins() and all_passed
	all_passed = _folders_are_not_packs() and all_passed
	all_passed = _every_folder_is_claimed() and all_passed
	return all_passed


## The reader, pinned on a two-file fixture: a region piece keeps its own column, a func piece is
## dedented by one tab and loses its trailing blank lines, and a second file in the same folder
## contributes its pieces beside the first one's.
static func _reader_pins() -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FIXTURE_DIR))
	_write(FIXTURE_DIR.path_join("a_first.gd"), [
		"# A fixture, not a pack.",
		"extends Node",
		"",
		"var scaffolding: int = 0",
		"",
		"#region knobs",
		"@export var speed: float = 1.0",
		"",
		"## A helper the pack emits verbatim.",
		"func _halve(value: float) -> float:",
		"\treturn value * 0.5",
		"#endregion",
		"",
		"func _ready() -> void:",
		"\tspeed = _halve(speed)",
		"\tif speed < 0.0:",
		"\t\tspeed = 0.0",
		"",
		""])
	_write(FIXTURE_DIR.path_join("b_second.gd"), [
		"# The companion file: its pieces join the first file's.",
		"extends Node",
		"",
		"func set_speed(value: float) -> void:",
		"\tspeed = value",
		""])
	var pieces: Dictionary = Lib._read_pieces(FIXTURE_DIR)
	var all_passed: bool = true
	all_passed = _pins("the folder's piece names", ",".join(PackedStringArray(pieces.keys())),
		"knobs,_ready,set_speed") and all_passed
	all_passed = _pins("a region piece keeps its own column", str(pieces.get("knobs", "")),
		"@export var speed: float = 1.0\n\n## A helper the pack emits verbatim.\nfunc _halve(value: float) -> float:\n\treturn value * 0.5") and all_passed
	all_passed = _pins("a func piece is dedented by one tab", str(pieces.get("_ready", "")),
		"speed = _halve(speed)\nif speed < 0.0:\n\tspeed = 0.0") and all_passed
	all_passed = _pins("a companion file's piece is read too", str(pieces.get("set_speed", "")),
		"speed = value") and all_passed
	return all_passed


## The three scans that must walk past a source file, and the one that was taught about it.
static func _folders_are_not_packs() -> bool:
	var all_passed: bool = true
	var scanned_as_providers: bool = false
	for addon_dir: String in AddonScanner.ADDON_DIRS:
		if SOURCE_ROOT.begins_with(addon_dir):
			scanned_as_providers = true
	all_passed = _pins("the provider scan does not reach the source tree", scanned_as_providers, false) and all_passed
	var files: PackedStringArray = _source_files()
	var looks_like_a_test: String = ""
	for path: String in files:
		if path.ends_with("_test.gd"):
			looks_like_a_test = path
	all_passed = _pins("no source file is named like a test", looks_like_a_test, "") and all_passed
	var documented: String = ""
	for path: String in files:
		if path.get_extension() == "md":
			documented = path
	all_passed = _pins("no source file is a document the index must list", documented, "") and all_passed
	all_passed = _pins("the style gate knows the tree spells its blanks the emitter's way",
		StyleGuide.SINGLE_BLANK_TREE, SOURCE_ROOT + "/") and all_passed
	return all_passed


## Every folder under the source root belongs to a builder that asks for it by name, and no builder
## asks for a folder that is not there. An orphan folder is dead code nothing would ever report.
static func _every_folder_is_claimed() -> bool:
	var asked_for: PackedStringArray = PackedStringArray()
	var builders: DirAccess = DirAccess.open("res://tools/pack_builders")
	if builders != null:
		var names: PackedStringArray = builders.get_files()
		names.sort()
		for file_name: String in names:
			if file_name.get_extension() != "gd":
				continue
			var text: String = FileAccess.get_file_as_string("res://tools/pack_builders/".path_join(file_name))
			var opened: int = text.find("pack_from_source(\"")
			if opened >= 0:
				var rest: String = text.substr(opened + 18)
				asked_for.append(rest.substr(0, rest.find("\"")))
	asked_for.sort()
	var present: PackedStringArray = PackedStringArray()
	var root: DirAccess = DirAccess.open(SOURCE_ROOT)
	if root != null:
		present = root.get_directories()
		present.sort()
	return _pins("every source folder is claimed by a builder", ",".join(present), ",".join(asked_for))


static func _source_files() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var root: DirAccess = DirAccess.open(SOURCE_ROOT)
	if root == null:
		return found
	var folders: PackedStringArray = root.get_directories()
	folders.sort()
	for folder: String in folders:
		var inner: DirAccess = DirAccess.open(SOURCE_ROOT.path_join(folder))
		if inner == null:
			continue
		var names: PackedStringArray = inner.get_files()
		names.sort()
		for file_name: String in names:
			found.append(SOURCE_ROOT.path_join(folder).path_join(file_name))
	return found


static func _write(path: String, lines: PackedStringArray) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("\n".join(lines))
	file.close()


static func _pins(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("pack_source_test", label, actual, expected)
