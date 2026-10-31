# Godot EventSheets - every variable a shipped behaviour declares carries a `##` description.
#
# The description is what the variable's row shows, what the Inspector shows as its tooltip for an
# exported one, and what a reader of the emitted script sees above the line. Two things are pinned:
#   - the compiler writes a description for a variable that is NOT exported (it used to write it only
#     for an exported one, so a described internal variable came out of the build with no doc at all);
#   - no variable or constant at the top level of a shipped pack script lacks one.
@tool
class_name PackVariableDocsTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const SHIPPED := preload("res://addons/eventforge/shipped_pack_folders.gd")
const PREFIX := "pack_variable_docs_test"
const VARIABLE_LINE := "^(?:@[a-z_]+(?:\\((?:[^()]|\\([^()]*\\))*\\))?\\s+)*(?:static\\s+)?(?:var|const)\\s+([A-Za-z_][A-Za-z0-9_]*)"


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _pin_compiler() and all_passed
	all_passed = _pin_rule() and all_passed
	all_passed = _pin_shipped_packs() and all_passed
	return all_passed


## A variable that is not exported still gets its description above it in the emitted script.
static func _pin_compiler() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	sheet.variables = {
		"hidden_count": {"type": "int", "default": 0, "exported": false, "description": "How many have been counted."},
		"bare_count": {"type": "int", "default": 0, "exported": false},
	}
	var output: String = SUPPORT.compile_output(sheet)
	return SUPPORT.pins(PREFIX, [
		["a described private variable is documented", output.contains("## How many have been counted.\nvar hidden_count: int = 0"), true],
		["an undescribed one stays bare", Array(_undocumented(output)), ["bare_count"]],
	])


## The rule itself, pinned on written-out scripts so a loosening of it is seen.
static func _pin_rule() -> bool:
	var documented: String = "## The speed.\nvar speed: float = 0.0\n"
	var bare: String = "var speed: float = 0.0\n"
	var grouped: String = "## The speed.\n@export_group(\"Move\")\n@export var speed: float = 0.0\n"
	var tagged_only: String = "## @ace_hidden\nconst TABLE: Dictionary = {}\n"
	var trailing: String = "var speed: float = 0.0  ## The speed.\n"
	return SUPPORT.pins(PREFIX, [
		["a doc line above counts", Array(_undocumented(documented)), []],
		["no doc is reported", Array(_undocumented(bare)), ["speed"]],
		["a doc above an export group line counts", Array(_undocumented(grouped)), []],
		["an annotation tag is not a description", Array(_undocumented(tagged_only)), ["TABLE"]],
		["a trailing doc counts", Array(_undocumented(trailing)), []],
	])


## Every top-level variable and constant of every shipped pack script has a description.
static func _pin_shipped_packs() -> bool:
	var missing: Array = []
	for folder: String in SHIPPED.FOLDERS:
		var root: String = "res://eventsheet_addons/%s/" % folder
		for file_name: String in DirAccess.get_files_at(root):
			if not file_name.ends_with(".gd"):
				continue
			var source: String = FileAccess.get_file_as_string(root + file_name)
			for name: String in _undocumented(source):
				missing.append("%s/%s: %s" % [folder, file_name, name])
	return SUPPORT.pins(PREFIX, [["every shipped pack variable has a description", missing, []]])


## Names of the top-level variables and constants in `source` with no `##` description.
static func _undocumented(source: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var pattern: RegEx = RegEx.new()
	pattern.compile(VARIABLE_LINE)
	var lines: PackedStringArray = source.split("\n")
	for index: int in range(lines.size()):
		var line: String = lines[index]
		var hit: RegExMatch = pattern.search(line)
		if hit == null or line.begins_with("\t"):
			continue
		if line.contains("  ## ") or line.contains(" ## "):
			continue
		var above: int = index - 1
		while above >= 0 and _is_section_or_tag(lines[above]):
			above -= 1
		if above >= 0 and lines[above].begins_with("##") and not lines[above].begins_with("## @ace_"):
			continue
		found.append(hit.get_string(1))
	return found


static func _is_section_or_tag(line: String) -> bool:
	return line.begins_with("@export_group") or line.begins_with("@export_subgroup") \
		or line.begins_with("@export_category") or line.begins_with("## @ace_")
