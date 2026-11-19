# Godot EventSheets - the Doctor's Renamed Classes section.
#
# Godot keeps one list of global class names for a whole project, so a plugin class called like a
# class of the game's own can stop the game's class from loading. Nine of this plugin's classes took
# the EventSheet prefix for that reason, and the old names were not kept as aliases on purpose: an alias
# would bring the clash back. A script of the reader's that still names an old one stops parsing until
# the name is replaced, and this section lists each such line with the replacement:
#
#   SheetCompiler -> EventSheetCompiler        GDScriptImporter -> EventSheetGDScriptImporter
#   VariableParser -> EventSheetVariableParser  TriggerResolver -> EventSheetTriggerResolver
#   VariableDialog -> EventSheetVariableDialog  FunctionParser -> EventSheetFunctionParser
#   ParamDefaultResolver -> EventSheetParamDefaultResolver
#   ActionCodegen -> EventSheetActionCodegen    ConditionCodegen -> EventSheetConditionCodegen
#
# Only the CODE of a line counts: text after a `#` and the inside of a string are blanked first, so a
# note that says what a class used to be called is not a finding. A file that declares one of the old
# names as its own class, and any old name the project declares as a global class of its own, are left
# alone - after the rename a game may rightly own a `SheetCompiler`. Nothing is written.
#
# It has no class_name of its own (that would be one more name to clash) and registers by path,
# through the same seam a pack's check uses.
@tool
extends "res://addons/eventforge/doctor_section.gd"

## The id the section is registered under and the id each finding is filed as.
const CHECK_ID := "renamed-classes"
const THIS_SCRIPT := "res://addons/eventforge/renamed_classes_doctor.gd"

## Old class name -> the name it carries now.
const RENAMED: Dictionary = {
	"SheetCompiler": "EventSheetCompiler",
	"GDScriptImporter": "EventSheetGDScriptImporter",
	"VariableParser": "EventSheetVariableParser",
	"TriggerResolver": "EventSheetTriggerResolver",
	"VariableDialog": "EventSheetVariableDialog",
	"FunctionParser": "EventSheetFunctionParser",
	"ParamDefaultResolver": "EventSheetParamDefaultResolver",
	"ActionCodegen": "EventSheetActionCodegen",
	"ConditionCodegen": "EventSheetConditionCodegen",
}


## Registers the section, replacing any earlier registration.
static func ensure_registered() -> void:
	EventSheetProjectDoctor.register_check(CHECK_ID, Callable(load(THIS_SCRIPT), "check"))


## The section, with the contract every registered check has: append findings, never write inside res://.
static func check(_sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	var sources: Dictionary = {}
	var turn: int = 0
	for script_path: String in own_paths(EventSheetProjectDoctor._project_scripts()):
		turn += 1
		await EventSheetProjectDoctor.breathe_every(turn)
		var source: String = EventSheetProjectDoctor.source_of(script_path)
		if _mentions_an_old_name(source):
			sources[script_path] = source
	if sources.is_empty():
		return
	findings.append_array(report(sources, _project_class_names()))


## The names of the global classes the reader's own scripts declare.
static func _project_class_names() -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if not _is_shipped(str(entry.get("path", ""))):
			names.append(str(entry.get("class", "")))
	return names


## The findings, pure over what was read: `sources` is script path -> its text, `project_classes` the
## class names the project declares itself. A test hands each its own table.
static func report(sources: Dictionary, project_classes: PackedStringArray) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	var paths: Array = sources.keys()
	paths.sort()
	for path: String in paths:
		for hit: Dictionary in hits(str(sources[path]), project_classes):
			findings.append(_finding("warning", CHECK_ID, path, EventSheetL10n.translate(
				"Line %d: rename %s to %s. Nothing else changed.") % [
				int(hit["line"]), hit["old"], hit["new"]], str(hit["old"])))
	return findings


## Every use of an old class name in the code of `source`, as {line, old, new}, in line order.
static func hits(source: String, project_classes: PackedStringArray) -> Array:
	var found: Array = []
	if not _mentions_an_old_name(source):
		return found
	var word: RegEx = RegEx.create_from_string("(?<![A-Za-z0-9_])(" + "|".join(RENAMED.keys()) + ")(?![A-Za-z0-9_])")
	var own: Dictionary = {}
	var declaration: RegEx = RegEx.create_from_string("(?m)^class_name\\s+([A-Za-z_][A-Za-z0-9_]*)")
	for declared: RegExMatch in declaration.search_all(source):
		own[declared.get_string(1)] = true
	var lines: PackedStringArray = source.split("\n")
	for index: int in lines.size():
		var code: String = _code_of(lines[index])
		for match: RegExMatch in word.search_all(code):
			var old: String = match.get_string(1)
			if own.has(old) or project_classes.has(old):
				continue
			found.append({"line": index + 1, "old": old, "new": str(RENAMED[old])})
	return found


## The cheap pre-read: opening a line is the expensive half.
static func _mentions_an_old_name(source: String) -> bool:
	for old: String in RENAMED:
		if source.contains(old):
			return true
	return false


## A line with its comment dropped and every string's inside blanked, so only code is left.
static func _code_of(line: String) -> String:
	var code: String = ""
	var quote: String = ""
	var index: int = 0
	while index < line.length():
		var letter: String = line[index]
		if quote != "":
			if letter == "\\":
				index += 2
				code += "  "
				continue
			if letter == quote:
				quote = ""
			code += " "
		elif letter == "#":
			break
		elif letter == "\"" or letter == "'":
			quote = letter
			code += " "
		else:
			code += letter
		index += 1
	return code
