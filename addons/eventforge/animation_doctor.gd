# Godot EventSheets - the Doctor's Animation section.
#
# A blend tree is driven by strings, and a string is where the silent failures live. Two of them, and
# both run today without an error and without doing what the row says:
#
#   A STATE NOBODY DECLARED   `travel(&"Swng")` walks nowhere. The state machine looks for a state by
#                             that name, does not find one, and simply stays where it was. Nothing is
#                             printed, nothing is thrown, and the character keeps standing still.
#   A VECTOR INTO A LINE      a Vector2 written into a ONE-dimensional blend space. `set()` accepts
#                             it, the space keeps only what it can use, and the blend is driven by
#                             the x alone - so a character blends its walk-run by the horizontal
#                             stick and ignores the vertical one for ever.
#
# BOTH ARE ANSWERED BY THE SCENE, not by the sheet. The names live in the AnimationTree's own root
# resource, so a script that is not attached to exactly one scene has nothing to be checked against
# and is passed over in silence rather than reported as wrong.
#
# It ships as an EXTENSION check, registered through the very seam a pack uses
# (`EventSheets.register_doctor_check`), so a pack that ships animation rows of its own joins this
# same section rather than inventing a second report. Registering from the Doctor's own run is what
# makes it show up in all four runners (the panel, the headless CLI, CI and the MCP server) without
# the plugin having to be loaded first.
#
# THE QUIET SHEET: neither finding draws anything in the sheet. The row wears the amber state, and
# the words live in the triage inbox and in the row's help strip when it is selected.
#
# NOTHING is written and nothing is stored: a script is read as text, measured and dropped. A project
# with no blend tree in it pays one substring test per script and reports nothing at all.
@tool
class_name EventSheetAnimationDoctor
extends EventSheetDoctorSection

## The id the section is registered under, and the id each of the two findings is filed as. Frozen
## alongside the wording: the quick-fix chips and the tests address a finding by its check id.
const CHECK_ID := "animation"
const CHECK_UNKNOWN_STATE := "animation-unknown-state"
const CHECK_BLEND_DIMENSIONS := "animation-blend-dimensions"

## The words a script must say before it is worth reading properly. The pre-read, and deliberately
## looser than the rules behind it: it decides what is opened, not what is reported. Both are
## spellings a ROW WRITES rather than names a script might merely mention, so a file that talks
## about animation trees in a comment buys nothing.
const TREE_WORDS: PackedStringArray = ["parameters/playback", "/blend_position"]

## The two calls that name a state, and the parameter path suffix a blend position is written to.
const TRAVEL_CALLS: PackedStringArray = ["travel(", "start("]
const BLEND_PATH_LEAD: String = "\"parameters/"
const BLEND_PATH_TAIL: String = "/blend_position\""

## What a written value has to say to be a vector. Both spellings, because a row writes
## `Vector2(x, y)` and a hand-written line just as often writes `Vector2.ZERO` or a variable the
## reader named - and a variable is not checked at all, for the same reason a built name is not.
const VECTOR_MARKS: PackedStringArray = ["Vector2(", "Vector2.", "Vector3(", "Vector3."]


## Registers the section, replacing any previous registration - so a plugin reload, a second Doctor
## run and a test that registers it by hand all leave exactly one.
static func ensure_registered() -> void:
	EventSheets.register_doctor_check(CHECK_ID, Callable(EventSheetAnimationDoctor, "check"))


## The section itself, with the contract every registered check has: append findings, never write
## inside res://.
static func check(_sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	var sources: Array[Dictionary] = []
	for script_path: String in EventSheets.project_scripts():
		var source: String = EventSheetProjectDoctor.source_of(script_path)
		if not _says_any(source, TREE_WORDS):
			continue
		sources.append({
			"path": script_path,
			"source": source,
			"trees": EventSheetSceneAnimationTree.for_script(script_path),
		})
	findings.append_array(report(sources))


## The whole section as findings, the summary first. Pure over its corpus - a list of
## {path, source, trees} - so a test hands it a script and a tree and never touches the filesystem.
static func report(sources: Array[Dictionary]) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	if sources.is_empty():
		return findings
	var driving: int = 0
	var first_path: String = str(sources[0].get("path", ""))
	var first_trouble: String = ""
	var unknown: int = 0
	var flattened: int = 0
	for entry: Dictionary in sources:
		var path: String = str(entry.get("path", ""))
		var source: String = str(entry.get("source", ""))
		var trees: Array[Dictionary] = entry.get("trees", [] as Array[Dictionary])
		driving += 1
		# A script the reader cannot pair with one scene has no list of names to be wrong about. It
		# is counted as driving a tree - it plainly is - and asked nothing else.
		if trees.is_empty():
			continue
		for state_name: String in EventSheetSceneAnimationTree.missing_states(trees, states_travelled_to(source)):
			unknown += 1
			if first_trouble.is_empty():
				first_trouble = path
			findings.append(_finding("info", CHECK_UNKNOWN_STATE, path,
				unknown_state_words(path.get_file(), state_name,
					EventSheetSceneAnimationTree.nearest(trees, state_name)), state_name))
		for written: Dictionary in blend_positions_written(source):
			var space_name: String = str(written.get("space", ""))
			if EventSheetSceneAnimationTree.dimensions_of(trees, space_name) != 1:
				continue
			if not _says_any(str(written.get("value", "")), VECTOR_MARKS):
				continue
			flattened += 1
			if first_trouble.is_empty():
				first_trouble = path
			findings.append(_finding("info", CHECK_BLEND_DIMENSIONS, path,
				flattened_blend_words(path.get_file(), space_name), space_name))
	if driving == 0:
		return findings
	if not first_trouble.is_empty():
		first_path = first_trouble
	findings.insert(0, _finding("info", CHECK_ID, first_path,
		EventSheetL10n.translate("Animation: %d script(s) drive a blend tree, %d state(s) no tree declares, %d blend position(s) written as a vector into a one-dimensional space.") % [
			driving, unknown, flattened], ""))
	return findings


## THE first warning, in one place: the row shows it and the report prints it, so a reader meets the
## same words wherever they meet the problem.
static func unknown_state_words(file_name: String, state_name: String, nearest: String) -> String:
	var words: String = EventSheetL10n.translate("%s travels to \"%s\", which no animation tree in its scene declares. A misspelled state travels nowhere and is never reported by the game itself.") % [
		file_name, state_name]
	if nearest.is_empty():
		return words
	return "%s %s" % [words, EventSheetL10n.translate("Did you mean \"%s\"?") % nearest]


## And the second: what a Vector2 written into a line actually does, which is quietly keep half of it.
static func flattened_blend_words(file_name: String, space_name: String) -> String:
	return EventSheetL10n.translate("%s writes a vector into \"%s\", which is a one-dimensional blend space. Only the first number is used - the rest of the direction is dropped without a word.") % [
		file_name, space_name]


## Every state name a script travels or jumps to, in the order it says them. Read off the emitted
## text rather than off rows, because `.gd` is the sheet format and a text sweep answers for a
## hand-written line exactly as it does for a picked one.
static func states_travelled_to(source: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for line: String in source.split("\n"):
		if not line.contains("parameters/playback"):
			continue
		for call_text: String in TRAVEL_CALLS:
			var at: int = line.find(call_text)
			if at < 0:
				continue
			var argument: String = _argument_at(line, at + call_text.length())
			if not argument.is_empty():
				found.append(argument)
	return found


## Every blend position a script writes, as {"space", "value"} - the name inside the parameter path
## and the text of what was written into it.
static func blend_positions_written(source: String) -> Array[Dictionary]:
	var written: Array[Dictionary] = []
	for line: String in source.split("\n"):
		var lead: int = line.find(BLEND_PATH_LEAD)
		if lead < 0:
			continue
		var tail: int = line.find(BLEND_PATH_TAIL, lead)
		if tail < 0:
			continue
		var start: int = lead + BLEND_PATH_LEAD.length()
		var space_name: String = line.substr(start, tail - start)
		if space_name.is_empty() or space_name.contains("/"):
			continue
		var comma: int = line.find(",", tail)
		if comma < 0:
			continue
		written.append({"space": space_name,
			"value": line.substr(comma + 1).strip_edges().trim_suffix(")").strip_edges()})
	return written


## The one argument of a call that opens at `from`, as the text between the brackets. "" when the
## call carries more than one - a travel with a reset flag beside it is still one state, but a line
## this reader cannot cut cleanly is one it says nothing about.
static func _argument_at(line: String, from: int) -> String:
	var close: int = line.find(")", from)
	if close < 0:
		return ""
	var inside: String = line.substr(from, close - from).strip_edges()
	return "" if inside.contains(",") else inside
