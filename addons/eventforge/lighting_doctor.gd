# Godot EventSheets - the Doctor's Lighting section.
#
# L8. Every other Doctor check reads code. This one reads SCENES, because that is where lighting goes
# wrong: a light with no texture, shadows nothing can block, a darkened layer nothing reaches. None of
# those is a line anybody wrote, so no amount of reading the sheet would ever find them - and all
# three are visible in the `.tscn` before the game is run once.
#
# Two more are about the ROWS, and they need both halves: a sheet writing the world's environment
# into a scene that has no WorldEnvironment, and a sheet writing an environment `.tres` other scenes
# load. The second is the one finding here with a single step to take, so it carries the row that
# takes it.
#
# It ships as an EXTENSION check, registered through the very seam a pack uses
# (`EventSheets.register_doctor_check`), so a pack that adds lighting of its own - a weather system, a
# lantern kit - adds its scenes to this same section rather than inventing a second report.
# Registering from the Doctor's own run is what makes it show up in all four runners (the panel, the
# headless CLI, CI and the MCP server) without the plugin having to be loaded first.
#
# NOTHING is written and nothing is stored: a scene is read as text, measured and dropped. A project
# with no lighting in it pays one substring test per scene and one per script, and reports nothing at
# all.
@tool
class_name EventSheetLightingDoctor
extends RefCounted

## The id the section is registered under, and the ids each kind of finding is filed as. Frozen
## alongside the wording: the quick-fix chips and the tests address a finding by its check id.
const CHECK_ID := "lighting"
const CHECK_TEXTURE := "lighting-no-texture"
const CHECK_OCCLUDER := "lighting-no-occluder"
const CHECK_DARKNESS := "lighting-no-light"
const CHECK_NO_WORLD := "lighting-no-world-environment"
const CHECK_SHARED := "lighting-shared-environment"

## Which check id each of the five findings reports as. One table, so the note on the row and the
## line in the report are the same finding under two roofs.
const CHECK_FOR_KIND: Dictionary = {
	EventSheetLightingFindings.KIND_NO_TEXTURE: CHECK_TEXTURE,
	EventSheetLightingFindings.KIND_NO_OCCLUDER: CHECK_OCCLUDER,
	EventSheetLightingFindings.KIND_NO_LIGHT: CHECK_DARKNESS,
	EventSheetLightingFindings.KIND_NO_ENVIRONMENT: CHECK_NO_WORLD,
	EventSheetLightingFindings.KIND_SHARED_ENVIRONMENT: CHECK_SHARED
}

## The plugin's own folder, left out of both corpora for the reason every other Doctor corpus leaves
## it out: it is shipped code the project author did not write and cannot usefully edit.
const PLUGIN_DIRECTORY := "res://addons/"

## What every light class of both dimensions has in its name - the cheap first question asked of a
## scene's text before anything is parsed.
const LIGHT_WORD := "Light"


## Registers the section, replacing any previous registration - so a plugin reload, a second Doctor
## run and a test that registers it by hand all leave exactly one.
static func ensure_registered() -> void:
	EventSheets.register_doctor_check(CHECK_ID, Callable(EventSheetLightingDoctor, "check"))


## The section itself, with the contract every registered check has: append findings, never write
## inside res://.
static func check(_sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	findings.append_array(report(lit_scenes(), EventSheets.project_scripts()))


## Every scene of the project with lighting in it, in path order: a light, the CanvasModulate a
## layer's darkness sits on, or the WorldEnvironment the atmosphere is held in.
##
## Two passes, and both are needed. The substring sweep comes first, exactly as the Multiplayer
## section does - a project with no lighting in it should not pay to have every scene parsed to find
## that out. The scenes that pass it are then really read, because "Light" turns up in plenty of
## scenes that hold no light at all (a lightmap, a node called Highlight), and the number in the
## summary has to be the number of lit scenes rather than the number that mention the word.
static func lit_scenes() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for scene_path: String in EventSheetSceneConnections.scene_paths():
		if scene_path.begins_with(PLUGIN_DIRECTORY):
			continue
		var text: String = FileAccess.get_file_as_string(scene_path)
		if not (text.contains(LIGHT_WORD) or text.contains(EventSheetSceneLightingFacts.DARKNESS_CLASS)
				or text.contains(EventSheetSceneLightingFacts.ENVIRONMENT_CLASS)):
			continue
		if holds_lighting(scene_path):
			found.append(scene_path)
	return found


## True when a scene really holds one of the three. The reader behind it keeps the scene it parsed,
## so a scene counted here costs nothing to measure afterwards.
static func holds_lighting(scene_path: String) -> bool:
	if not EventSheetSceneLights.for_scene(scene_path).is_empty():
		return true
	for node_class: String in [EventSheetSceneLightingFacts.DARKNESS_CLASS,
			EventSheetSceneLightingFacts.ENVIRONMENT_CLASS]:
		if not EventSheetSceneLights.nodes_of_scene_class(scene_path, node_class).is_empty():
			return true
	return false


## The whole section as findings, the summary first: how many scenes are lit and how many of them
## have something wrong, then the scene findings, then the two the sheets earn. Pure over its two
## corpora, so a test can hand it a scene and a script.
static func report(scenes: PackedStringArray, scripts: PackedStringArray) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	if scenes.is_empty():
		return findings
	var troubled: int = 0
	# The summary points at the FIRST scene with something wrong, because that is the one worth
	# opening - double-clicking the line in the panel is what takes the reader there.
	var worst_path: String = scenes[0]
	for scene_path: String in scenes:
		var found: Array[Dictionary] = EventSheetLightingFindings.scene_findings(scene_path)
		if found.is_empty():
			continue
		if troubled == 0:
			worst_path = scene_path
		troubled += 1
		findings.append_array(_filed(scene_path, found))
	for script_path: String in scripts:
		findings.append_array(sheet_findings(script_path))
	findings.insert(0, _finding("info", CHECK_ID, worst_path,
		EventSheetL10n.translate("Lighting: %d lit scene(s), %d with something that will not show at run time.") % [
			scenes.size(), troubled], ""))
	return findings


## What one script contributes: the two findings that need the rows as well as the scene. The script
## is opened as a sheet in memory, measured and dropped - nothing is written, and a script saying
## nothing about the environment costs one substring test.
static func sheet_findings(script_path: String) -> Array[Dictionary]:
	# The member every one of those rows reaches through. A substring test, deliberately loose: a
	# script that never says the word cannot be one of these sheets, and a script that does is judged
	# by the ROWS rather than by the word (EventSheetLightingFindings.reaches_the_environment).
	var source: String = FileAccess.get_file_as_string(script_path)
	if not source.contains(EventForgeSceneLightingACEs.ENVIRONMENT_MEMBER):
		return []
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(script_path)
	if sheet == null:
		return []
	return _filed(script_path, EventSheetLightingFindings.findings(sheet))


## A family's findings as the Doctor files them: its own severity and wording, under the check id
## its kind maps to, pointing at the file a reader should open.
static func _filed(path: String, found: Array[Dictionary]) -> Array[Dictionary]:
	var filed: Array[Dictionary] = []
	for finding: Dictionary in found:
		filed.append(_finding(str(finding.get("severity", "warning")),
			str(CHECK_FOR_KIND.get(str(finding.get("kind", "")), CHECK_ID)), path,
			"%s %s" % [path.get_file(), str(finding.get("message", ""))],
			str(finding.get("subject", ""))))
	return filed


static func _finding(severity: String, check_id: String, path: String, message: String,
		subject: String) -> Dictionary:
	return {
		"severity": severity, "check": check_id, "path": path, "message": message,
		"subject": subject
	}
