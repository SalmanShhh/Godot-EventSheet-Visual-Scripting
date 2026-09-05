# Godot EventSheets - the Doctor's Shapes section.
#
# One check, and it describes something that runs today without an error and shows nothing on the
# screen: a sheet that marches a shape's dashes on a shape that has no dashes to march. Scroll
# Dashes moves a pattern along; it does not make one. A shape whose Dashed box is off draws a solid
# stroke however fast the offset is scrolling, and nothing anywhere says so - the row runs, the
# offset climbs, and the line sits still.
#
# IT ONLY SPEAKS WHEN IT CAN SEE THE ANSWER. Whether a shape is dashed is an Inspector fact, kept in
# the scene, so the check refuses to guess from the rows alone: it fires only when it can find the
# node the row names, in a scene that uses the sheet, and read that its Dashed box is off - and only
# when no row in the same sheet turns the dashes on first. A node it cannot find, a scene it cannot
# pair, a shape already dashed, or a Set Dashes row anywhere above: each of those is silence. A
# check that cries wolf gets switched off, and this one is about a mistake nobody can see.
#
# It ships as an EXTENSION check, registered through the very seam a pack uses
# (`EventSheets.register_doctor_check`), so it shows up in all four runners - the panel, the headless
# CLI, CI and the MCP server - without the plugin having to be loaded first.
#
# NOTHING is written and nothing is stored. A project with no shape in it pays one substring test
# per script and reports nothing at all.
@tool
class_name EventSheetShapesDoctor
extends EventSheetDoctorSection

## The id the section is registered under, and the id its one finding is filed as. Frozen alongside
## the wording: the quick-fix chips and the tests address a finding by its check id.
const CHECK_ID := "shapes"
const CHECK_SCROLL_WITHOUT_DASHES := "shapes-scroll-without-dashes"

## Where the pack's shape scripts ship. A node wearing one of these is a shape whose Dashed box this
## section can read; anything else in a scene is none of its business.
const SHAPE_DIRECTORY := "res://eventsheet_addons/vector_shapes/"

## The spellings this section reads, all of them EMITTED CODE rather than names a script might
## merely mention. The scroll call carries its dot, so the pack's own `func scroll_dashes` - the
## declaration, not a call - is not one of these and the pack never reports itself.
const SCROLL_CALL := ".scroll_dashes("
const DASHES_CALL := ".set_dashes("
const DASHED_ON := ".dashed = true"

## The scene property that says a shape is dashed. Godot writes a property line only when it differs
## from the script's default, and the default is off - so a shape with NO `dashed` line is a shape
## with its dashes off, which is exactly the case this check is about.
const DASHED_PROPERTY := "dashed"

## The speeds that are not a scroll. Zero stops the ants on purpose, and a row that stops them on a
## shape with no dashes is asking for nothing and getting it.
const STOPPED_SPEEDS: PackedStringArray = ["0", "0.0", "-0.0"]


## Registers the section, replacing any previous registration - so a plugin reload, a second Doctor
## run and a test that registers it by hand all leave exactly one.
static func ensure_registered() -> void:
	EventSheets.register_doctor_check(CHECK_ID, Callable(EventSheetShapesDoctor, "check"))


## The section itself, with the contract every registered check has: append findings, never write
## inside res://.
static func check(_sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	findings.append_array(report(scripts_scrolling_dashes()))


## Every script of the project that marches a shape's dashes, in path order. The substring sweep is
## the whole corpus question: a project with no shape in it pays one test per file and stops.
static func scripts_scrolling_dashes() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for script_path: String in EventSheets.project_scripts():
		if script_path.begins_with(PLUGIN_DIRECTORY):
			continue
		if EventSheetProjectDoctor.source_of(script_path).contains(SCROLL_CALL):
			found.append(script_path)
	return found


## The whole section as findings, the summary first: how many sheets march a shape's dashes and how
## many of them do it on a shape that has none. Pure over its corpus, so a test can hand it two
## paths.
static func report(scripts: PackedStringArray) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	if scripts.is_empty():
		return findings
	var troubled: int = 0
	# The summary points at the FIRST sheet with something wrong, because that is the one worth
	# opening - double-clicking the line in the panel is what takes the reader there.
	var worst_path: String = scripts[0]
	for script_path: String in scripts:
		var mine: Array[Dictionary] = script_findings(script_path)
		if mine.is_empty():
			continue
		if troubled == 0:
			worst_path = script_path
		troubled += 1
		findings.append_array(mine)
	findings.insert(0, _finding("info", CHECK_ID, worst_path,
		EventSheetL10n.translate("Shapes: %d sheet(s) march a shape's dashes, %d of them on a shape whose dashes are off.") % [
			scripts.size(), troubled], ""))
	return findings


## What one sheet contributes: one finding per target it scrolls that has no dashes to scroll. The
## script is read as TEXT - the emitted code is what runs, and it is what a row's target is spelled
## in - so a sheet that never reaches a shape costs one substring test.
static func script_findings(script_path: String) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	var source: String = EventSheetProjectDoctor.source_of(script_path)
	if not source.contains(SCROLL_CALL):
		return findings
	for target: String in scrolled_targets(source):
		if _dashes_turned_on(source, target):
			continue
		var scene_path: String = _scene_with_dashes_off(script_path, target)
		if scene_path.is_empty():
			continue
		findings.append(_finding("warning", CHECK_SCROLL_WITHOUT_DASHES, script_path,
			EventSheetL10n.translate("%s marches the dashes on %s, and that shape has none to march: its Dashed box is off in %s, and no row here turns it on. Turn Dashed on in the Inspector, or put a Set Dashes row before the Scroll Dashes.") % [
				script_path.get_file(), target, scene_path.get_file()], target))
	return findings


## The targets a script scrolls at a speed that is not zero, in the order they are written and each
## named once. A row is one statement on one line in emitted code, so what stands before the call is
## the target the row picked - `$AimLine`, `%Ring`, or a path down to one.
static func scrolled_targets(source: String) -> PackedStringArray:
	var targets: PackedStringArray = PackedStringArray()
	for raw_line: String in source.split("\n"):
		var line: String = raw_line.strip_edges()
		var at: int = line.find(SCROLL_CALL)
		if at <= 0:
			continue
		var target: String = line.substr(0, at)
		if target.is_empty() or targets.has(target):
			continue
		var argument: String = line.substr(at + SCROLL_CALL.length())
		var closes: int = argument.rfind(")")
		if closes >= 0:
			argument = argument.substr(0, closes)
		if STOPPED_SPEEDS.has(argument.strip_edges()):
			continue
		targets.append(target)
	return targets


## Whether the sheet itself turns this target's dashes on anywhere - the Set Dashes row, which
## always turns them on, or a plain property write. Either answers the question, wherever in the
## file it sits: the Doctor reads a sheet, not an order of execution.
static func _dashes_turned_on(source: String, target: String) -> bool:
	return source.contains(target + DASHES_CALL) or source.contains(target + DASHED_ON)


## The scene that answers for this target, when it says the dashes are off - and "" when no scene
## does, which is the silence the header promises. Every scene using the script is asked; one that
## finds the node dashed ends the question for all of them, because a sheet dropped into two scenes
## is doing the right thing in the one where the shape is dashed.
static func _scene_with_dashes_off(script_path: String, target: String) -> String:
	var node_name: String = _node_name_of(target)
	if node_name.is_empty():
		return ""
	var answer: String = ""
	for scene_path: String in EventSheetSceneConnections.scenes_using_script(script_path):
		for node: Variant in EventSheetSceneConnections.nodes_of_scene(scene_path):
			var entry: Dictionary = node
			if str(entry.get("name", "")) != node_name:
				continue
			if not str(entry.get("script_path", "")).begins_with(SHAPE_DIRECTORY):
				continue
			var properties: Dictionary = entry.get("properties", {})
			if str(properties.get(DASHED_PROPERTY, "false")).strip_edges() == "true":
				return ""
			if answer.is_empty():
				answer = scene_path
	return answer


## The node a target expression names: the last step of `$Aim/Line`, the name behind a `%Ring`, and
## nothing at all for a target that is not a node path (a variable, a function call, `self`), which
## is a target this section cannot resolve and therefore never reports.
static func _node_name_of(target: String) -> String:
	var text: String = target.strip_edges()
	if not (text.begins_with("$") or text.begins_with("%")):
		return ""
	text = text.substr(1).replace("\"", "").replace("'", "")
	if text.contains("/"):
		text = text.get_slice("/", text.get_slice_count("/") - 1)
	if text.contains("%"):
		text = text.get_slice("%", text.get_slice_count("%") - 1)
	return text
