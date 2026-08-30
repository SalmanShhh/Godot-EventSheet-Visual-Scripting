# Godot EventSheets - the Doctor's Collision Layers section.
#
# A named-layer row stores the layer's NUMBER and reads the project's name for it back when it is
# drawn. That is the right way round - renaming a layer renames every sentence about it and moves no
# file - and it has one consequence worth saying out loud: a layer that stops being named stops being
# readable. The row is not broken, the game still runs, and the sentence quietly goes back to saying
# "Collide with 4" in a project where every other row says a word.
#
# So there are two notes here, and both of them are about a NUMBER the project cannot name:
#
#   a layer nobody named  - the project names layers of this dimension, and this row's is not one of
#                           them. Renamed away, renumbered, or simply never given a name.
#   not a layer at all    - a number outside 1-32. Godot has thirty-two collision layers and the
#                           call silently does nothing for anything else.
#
# NOTHING IS SAID ABOUT A PROJECT THAT NAMES NO LAYERS. Numbers are a perfectly good way to work,
# and a section that arrives amber on a stock install is a section its reader learns to scroll past.
# The note exists because the project already speaks in names and one row cannot.
#
# The corpus is the project's SCRIPTS, read as text. The number a row carries is the number the
# emitted line carries, so the line is the row for this purpose, and reading text means a project
# with a thousand scripts pays one substring test each rather than a thousand sheet opens.
#
# It ships as an EXTENSION check, registered through the very seam a pack uses
# (`EventSheets.register_doctor_check`), so a pack that ships collision verbs of its own lands in
# this same section rather than inventing a second report.
#
# NOTHING is written and nothing is stored.
@tool
class_name EventSheetCollisionLayerDoctor
extends RefCounted

## The id the section is registered under, and the id each finding is filed as. Frozen alongside the
## wording: the tests address a finding by its check id.
const CHECK_ID := "collision-layers"
const CHECK_UNNAMED := "collision-layer-unnamed"
const CHECK_NOT_A_LAYER := "collision-layer-out-of-range"

## The plugin's own folder, left out of the corpus for the reason every other Doctor corpus leaves it
## out: it is shipped code the project author did not write and cannot usefully edit.
const PLUGIN_DIRECTORY := "res://addons/"

## The three calls a named-layer row compiles to, as the text a script carries. The pre-read that
## keeps a project which never touches a layer from paying for this section at all.
const LAYER_CALLS: PackedStringArray = [
	"set_collision_mask_value(", "set_collision_layer_value(", "get_collision_mask_value("
]

## The one word every one of them contains, for the cheapest possible first question.
const MARK := "collision_"


## Registers the section, replacing any previous registration - so a plugin reload, a second Doctor
## run and a test that registers it by hand all leave exactly one.
static func ensure_registered() -> void:
	EventSheets.register_doctor_check(CHECK_ID, Callable(EventSheetCollisionLayerDoctor, "check"))


## The section itself, with the contract every registered check has: append findings, never write
## inside res://.
static func check(_sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	findings.append_array(report(EventSheets.project_scripts()))


## The whole section as findings. Pure over its corpus, so a test can hand it a list of scripts and
## read the same report the panel shows. Scripts are walked in sorted order, which is what makes two
## audits of an unchanged project read the same on every machine.
static func report(scripts: PackedStringArray) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	var ordered: PackedStringArray = ranked(scripts)
	for script_path: String in ordered:
		findings.append_array(script_findings(script_path,
			EventSheetProjectDoctor.source_of(script_path)))
	return findings


## The scripts worth reading, sorted. The plugin's own are left out, and so is every script that
## never names a collision layer at all.
static func ranked(scripts: PackedStringArray) -> PackedStringArray:
	var ordered: PackedStringArray = PackedStringArray()
	for script_path: String in scripts:
		if script_path.begins_with(PLUGIN_DIRECTORY):
			continue
		if says_enough(EventSheetProjectDoctor.source_of(script_path)):
			ordered.append(script_path)
	ordered.sort()
	return ordered


## Does this text address a layer by number at all. Deliberately looser than the rules below: it only
## decides what gets READ, and the rules decide what is reported.
static func says_enough(source: String) -> bool:
	if not source.contains(MARK):
		return false
	for call_text: String in LAYER_CALLS:
		if source.contains(call_text):
			return true
	return false


## One script's findings. The dimension is the file's own - a script extending a 3D body means the
## 3D list of names - which is the same question the lift asks of the same text.
static func script_findings(script_path: String, source: String) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	if not says_enough(source):
		return findings
	var dimension: String = EventForgePhysicsLayers.dimension_for_class(
		EventForgeCollisionLayerLift.extended_class(source))
	var names_any: bool = EventForgePhysicsLayers.names_any(dimension)
	var seen: Dictionary = {}
	for number: int in layer_numbers(source):
		if seen.has(number):
			continue
		seen[number] = true
		if not EventForgePhysicsLayers.is_layer_number(number):
			findings.append(_finding("warning", CHECK_NOT_A_LAYER, script_path,
				EventSheetL10n.translate("%s addresses collision layer %d, and Godot has layers 1 to 32 - that call does nothing.") % [script_path.get_file(), number],
				"%s|%d" % [script_path, number]))
			continue
		if names_any and EventForgePhysicsLayers.name_of(number, dimension).is_empty():
			findings.append(_finding("info", CHECK_UNNAMED, script_path,
				EventSheetL10n.translate("%s is about collision layer %d, which this project does not name - the row reads as the number while every other row reads as a word. Name it in Project Settings ▸ Layer Names, or point the row at the layer that was renamed.") % [script_path.get_file(), number],
				"%s|%d" % [script_path, number]))
	return findings


## The source with every string literal's contents and every comment blanked out, character for
## character so nothing else shifts. A file that merely QUOTES a layer call - a test's fixture
## constant, a doc string, a codegen template, a line commented out while somebody thinks - is
## TALKING about one rather than making one, and a section that cannot tell the difference files a
## finding against the plugin's own suite. The compiler draws this same line for the same reason.
static func code_only(source: String) -> String:
	var written: PackedStringArray = PackedStringArray()
	var index: int = 0
	var length: int = source.length()
	while index < length:
		var character: String = source[index]
		if character == "#":
			while index < length and source[index] != "\n":
				written.append(" ")
				index += 1
			continue
		if character != "\"" and character != "'":
			written.append(character)
			index += 1
			continue
		# A quote opens a literal, of one of the two lengths GDScript writes: the plain one and the
		# block one. Both are blanked to their own width, and the newlines inside a block are kept so
		# the lines of the file stay the lines of the file.
		var run: int = 3 if source.substr(index, 3) == character.repeat(3) else 1
		written.append(" ".repeat(run))
		index += run
		while index < length:
			if source[index] == "\\" and run == 1:
				written.append("  ")
				index += 2
				continue
			if source.substr(index, run) == character.repeat(run):
				written.append(" ".repeat(run))
				index += run
				break
			written.append("\n" if source[index] == "\n" else " ")
			index += 1
	return "".join(written)


## Every layer number the text addresses by a plain literal, lowest first. A call whose layer is an
## expression is left alone: the number it works out to is not knowable here, and a note about a
## layer nobody can point at would be a guess.
static func layer_numbers(text: String) -> PackedInt32Array:
	var found: Dictionary = {}
	var source: String = code_only(text)
	for call_text: String in LAYER_CALLS:
		var cursor: int = 0
		while true:
			var at: int = source.find(call_text, cursor)
			if at == -1:
				break
			cursor = at + call_text.length()
			var argument: String = _first_argument(source, cursor)
			if argument.is_valid_int():
				found[argument.to_int()] = true
	var numbers: Array = found.keys()
	numbers.sort()
	var out: PackedInt32Array = PackedInt32Array()
	for number: Variant in numbers:
		out.append(int(number))
	return out


## The text of a call's first argument, from just after its opening bracket. "" when the call is
## unclosed, which a half-typed file can be.
static func _first_argument(source: String, from: int) -> String:
	for index: int in range(from, source.length()):
		var character: String = source[index]
		if character == "," or character == ")":
			return source.substr(from, index - from).strip_edges()
		if character == "\n":
			return ""
	return ""


static func _finding(severity: String, check_id: String, path: String, message: String,
		subject: String) -> Dictionary:
	return {
		"severity": severity, "check": check_id, "path": path, "message": message,
		"subject": subject
	}
