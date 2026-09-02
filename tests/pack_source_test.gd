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
#   2. The MANIFEST is typed. Everything a source folder cannot carry - behavior, autoload,
#      category, tags, version, variables, how the verbs are exposed - is declared by name on a
#      typed manifest rather than by key in a dictionary, so a misspelling is a parse error at the
#      call site instead of a trait the pack silently ships without. What each declaration puts on
#      the sheet is pinned here, because that is what an emitted pack is made of.
#   3. A source file is NOT a pack, NOT a test and NOT a document. It is ordinary GDScript sitting
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
	all_passed = _manifest_pins() and all_passed
	all_passed = _a_hole_fails_the_build() and all_passed
	all_passed = _folders_are_not_packs() and all_passed
	all_passed = _every_folder_is_claimed() and all_passed
	return all_passed


## The reader, pinned on a two-file fixture: a region piece keeps its own column, a func piece is
## dedented by one tab and loses its trailing blank lines, and a second file in the same folder
## contributes its pieces beside the first one's.
static func _reader_pins() -> bool:
	# The folder is EMPTIED first, not just created. The reader reads every `.gd` in it, so a file
	# a past run of a past fixture left behind would join this one's pieces and fail the piece-name
	# pin with a message about a file this test has never heard of.
	_empty_fixture_dir()
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
	_write(FIXTURE_DIR.path_join("c_third.gd"), [
		"# The two rules a reader of this tree has to know, pinned so they cannot change quietly.",
		"extends Node",
		"",
		"static func a_static_helper() -> void:",
		"	pass",
		"",
		"func stops_at_a_column_zero_comment() -> void:",
		"	var kept: int = 1",
		"# A comment at column 0 ends the piece here.",
		"	var lost: int = 2",
		""])
	var pieces: Dictionary = Lib._read_pieces(FIXTURE_DIR)
	var all_passed: bool = true
	all_passed = _pins("the folder's piece names", ",".join(PackedStringArray(pieces.keys())),
		"knobs,_ready,set_speed,stops_at_a_column_zero_comment") and all_passed
	all_passed = _pins("a static func is scaffolding, not a piece",
		pieces.has("a_static_helper"), false) and all_passed
	all_passed = _pins("a column-0 comment ends a func piece",
		str(pieces.get("stops_at_a_column_zero_comment", "")), "var kept: int = 1") and all_passed
	all_passed = _pins("a region piece keeps its own column", str(pieces.get("knobs", "")),
		"@export var speed: float = 1.0\n\n## A helper the pack emits verbatim.\nfunc _halve(value: float) -> float:\n\treturn value * 0.5") and all_passed
	all_passed = _pins("a func piece is dedented by one tab", str(pieces.get("_ready", "")),
		"speed = _halve(speed)\nif speed < 0.0:\n\tspeed = 0.0") and all_passed
	all_passed = _pins("a companion file's piece is read too", str(pieces.get("set_speed", "")),
		"speed = value") and all_passed
	return all_passed


## The manifest, field by field: what each declaration puts on the sheet, and what a pack that
## declares nothing gets. The two wholesale-exposure MODES are methods rather than a string a call
## site spells, so the spellings the compiler reads ("node", "all") are written down once, here and
## in the maker, and nowhere else.
static func _manifest_pins() -> bool:
	var all_passed: bool = true
	var bare: EventSheetResource = Lib.pack_from_source(
		"wrap", "Node2D", "Bare", "A pack that declares nothing.").sheet
	all_passed = _pins("an undeclared pack is not a behavior", bare.behavior_mode, false) and all_passed
	all_passed = _pins("an undeclared pack is not an autoload", bare.autoload_mode, false) and all_passed
	all_passed = _pins("an undeclared pack exposes no verbs wholesale", bare.ace_expose_all_mode, "") and all_passed
	var declared: Lib.PackManifest = Lib.manifest().behavior().category("Wrap")
	declared.verb_category("Wrapping").tags(PackedStringArray(["movement"])).version("2.1.0")
	declared.variables({"speed": {"type": "float", "default": 1.0, "exported": true}})
	declared.expose_all_verbs_on_a_node()
	var opened: Lib.PackSource = Lib.pack_from_source(
		"wrap", "Node2D", "Declared", "A pack that declares all of it.", declared)
	var sheet: EventSheetResource = opened.sheet
	all_passed = _pins("behavior() sets behavior_mode", sheet.behavior_mode, true) and all_passed
	all_passed = _pins("category() sets the Add Behavior category", sheet.addon_category, "Wrap") and all_passed
	all_passed = _pins("verb_category() sets the picker default", opened.verb_category, "Wrapping") and all_passed
	all_passed = _pins("tags() sets the search tags", ",".join(sheet.addon_tags), "movement") and all_passed
	all_passed = _pins("version() sets the pack version", sheet.addon_version, "2.1.0") and all_passed
	all_passed = _pins("variables() sets the Inspector variables",
		",".join(PackedStringArray(sheet.variables.keys())), "speed") and all_passed
	all_passed = _pins("a node-scoped wholesale exposure is the mode the compiler reads",
		sheet.ace_expose_all_mode, "node") and all_passed
	all_passed = _pins("a plain wholesale exposure is the other one",
		Lib.manifest().expose_all_verbs().expose_all_mode, "all") and all_passed
	var autoloaded: EventSheetResource = Lib.pack_from_source("save_system", "Node", "Auto",
		"An autoload pack.", Lib.manifest().autoload("SaveSystem")).sheet
	all_passed = _pins("autoload() turns autoload_mode on with the name",
		"%s/%s" % [autoloaded.autoload_mode, autoloaded.autoload_name], "true/SaveSystem") and all_passed
	all_passed = _pins("a pack with no verb category of its own falls back to its Add Behavior one",
		Lib.pack_from_source("wrap", "Node2D", "Fallback", "", Lib.manifest().category("Wrap")).verb_category,
		"Wrap") and all_passed
	return all_passed


## A pack with a hole in it does not get published. Asking for a piece the folder does not hold
## returns "" (there is nothing else it could return), and that empty body used to be appended as a
## row and written: the pack shipped, `save_pack` said true, and the build's exit code was 0. The
## refusal is at `publish`, so nothing reaches the disk.
##
## The engine errors this prints are the point of it - they are what a builder's author sees.
static func _a_hole_fails_the_build() -> bool:
	var all_passed: bool = true
	var opened: Lib.PackSource = Lib.pack_from_source("wrap", "Node2D", "Holed", "A pack with a hole.")
	all_passed = _pins("a folder that reads cleanly has no problems", opened.problems().size(), 0) and all_passed
	all_passed = _pins("a piece the folder does not hold is empty", opened.code("no_such_piece"), "") and all_passed
	all_passed = _pins("and it is a problem", opened.problems().size(), 1) and all_passed
	all_passed = _pins("a holed pack refuses to publish",
		Lib.publish(opened, "user://eventsheets_pack_source_never_written"), false) and all_passed
	all_passed = _pins("and nothing was written",
		FileAccess.file_exists("user://eventsheets_pack_source_never_written.gd"), false) and all_passed
	var missing: Lib.PackSource = Lib.pack_from_source(
		"no_such_folder", "Node", "Missing", "A pack whose folder is not there.")
	all_passed = _pins("a folder that is not there is a problem before a piece is even asked for",
		missing.problems().size(), 1) and all_passed
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


## The fixture folder, emptied. `user://` survives between runs on a developer's machine (CI gets a
## fresh one), so the folder is cleared rather than trusted.
static func _empty_fixture_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FIXTURE_DIR))
	var dir: DirAccess = DirAccess.open(FIXTURE_DIR)
	if dir == null:
		return
	var names: PackedStringArray = dir.get_files()
	names.sort()
	for file_name: String in names:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(FIXTURE_DIR.path_join(file_name)))


static func _write(path: String, lines: PackedStringArray) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("\n".join(lines))
	file.close()


static func _pins(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("pack_source_test", label, actual, expected)
