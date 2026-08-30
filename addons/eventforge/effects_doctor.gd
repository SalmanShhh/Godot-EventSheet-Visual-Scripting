# Godot EventSheets - the Doctor's Effects section.
#
# Five checks, and every one of them describes something that runs today without an error and shows
# nothing on the screen: a dial the shader does not have, dials turned on a material eleven other
# nodes wear, effect rows on a node wearing no material at all, a global uniform Project Settings
# never declared, and a screen effect left drawing while everything is at rest.
#
# Four are about the ROWS and are read out of the sheets; the fifth is about a SCENE and is found
# without a sheet, because a rect left on is left on whether or not anybody wrote a row about it.
# What each of them MEANS lives in EventSheetEffectFindings, which is also what the canvas hangs
# under the row - so a reader meets the same sentence wherever they meet the problem.
#
# It ships as an EXTENSION check, registered through the very seam a pack uses
# (`EventSheets.register_doctor_check`), so a pack that ships effects of its own adds its scenes to
# this same section rather than inventing a second report. Registering from the Doctor's own run is
# what makes it show up in all four runners (the panel, the headless CLI, CI and the MCP server)
# without the plugin having to be loaded first.
#
# NOTHING is written and nothing is stored. A project with no shaders in it pays one substring test
# per scene and one per script, and reports nothing at all.
@tool
class_name EventSheetEffectsDoctor
extends RefCounted

## The id the section is registered under, and the id each finding is filed as. Frozen alongside the
## wording: the quick-fix chips and the tests address a finding by its check id.
const CHECK_ID := "effects"
const CHECK_UNKNOWN_DIAL := "effects-unknown-dial"
const CHECK_SHARED := "effects-shared-material"
const CHECK_NO_MATERIAL := "effects-no-material"
const CHECK_GLOBAL := "effects-undeclared-global"
const CHECK_SCREEN := "effects-screen-effect-idle"

## Which check id each finding reports as. One table, so the note on the row and the line in the
## report are the same finding under two roofs.
const CHECK_FOR_KIND: Dictionary = {
	EventSheetEffectFindings.KIND_UNKNOWN_DIAL: CHECK_UNKNOWN_DIAL,
	EventSheetEffectFindings.KIND_SHARED_MATERIAL: CHECK_SHARED,
	EventSheetEffectFindings.KIND_NO_MATERIAL: CHECK_NO_MATERIAL,
	EventSheetEffectFindings.KIND_UNDECLARED_GLOBAL: CHECK_GLOBAL,
	EventSheetEffectFindings.KIND_IDLE_SCREEN_EFFECT: CHECK_SCREEN,
}

## The plugin's own folder, left out of both corpora for the reason every other Doctor corpus leaves
## it out: it is shipped code the project author did not write and cannot usefully edit.
const PLUGIN_DIRECTORY := "res://addons/"

## The cheap first question asked of a scene's text before anything is parsed - a scene with no
## material line in it wears no effect, and a project with no shaders should not pay to have every
## scene parsed to find that out.
const MATERIAL_WORD := "material = "

## And of a script's text: the member every dial row reaches through, and the call every global one
## makes. A script that says neither cannot be one of these sheets.
const SHEET_WORDS: PackedStringArray = ["set_shader_parameter", "get_shader_parameter",
	"global_shader_parameter"]


## Registers the section, replacing any previous registration - so a plugin reload, a second Doctor
## run and a test that registers it by hand all leave exactly one.
static func ensure_registered() -> void:
	EventSheets.register_doctor_check(CHECK_ID, Callable(EventSheetEffectsDoctor, "check"))


## The section itself, with the contract every registered check has: append findings, never write
## inside res://.
static func check(_sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	findings.append_array(report(scenes_with_effects(), EventSheets.project_scripts()))


## Every scene of the project with a material worn in it, in path order. The substring sweep comes
## first, exactly as the Lighting section does, and the scenes that pass it are then really read -
## the number in the summary has to be the number of scenes wearing an effect rather than the number
## that mention the word.
static func scenes_with_effects() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for scene_path: String in EventSheetSceneConnections.scene_paths():
		if scene_path.begins_with(PLUGIN_DIRECTORY):
			continue
		if not EventSheetProjectDoctor.source_of(scene_path).contains(MATERIAL_WORD):
			continue
		if not EventSheetSceneEffects.for_scene(scene_path).is_empty():
			found.append(scene_path)
	return found


## The whole section as findings, the summary first: how many scenes wear an effect and how many of
## them have something wrong, then the scene findings, then the four the sheets earn. Pure over its
## two corpora, so a test can hand it a scene and a script.
static func report(scenes: PackedStringArray, scripts: PackedStringArray) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	if scenes.is_empty():
		return findings
	# The counts the section is about are project-wide questions, and the one that answers them is the
	# shared index. A Doctor run has no frames to spread it over, so it is built here, once, before
	# anything asks - which is also what makes the report the same whether the editor was open or not.
	EventSheetProjectShareIndex.build_now()
	var troubled: int = 0
	# The summary points at the FIRST scene with something wrong, because that is the one worth
	# opening - double-clicking the line in the panel is what takes the reader there.
	var worst_path: String = scenes[0]
	for scene_path: String in scenes:
		var found: Array[Dictionary] = EventSheetEffectFindings.scene_findings(scene_path)
		if found.is_empty():
			continue
		if troubled == 0:
			worst_path = scene_path
		troubled += 1
		findings.append_array(_filed(scene_path, found))
	for script_path: String in scripts:
		findings.append_array(sheet_findings(script_path))
	findings.insert(0, _finding("info", CHECK_ID, worst_path,
		EventSheetL10n.translate("Effects: %d scene(s) wearing a material, %d with something that will not show at run time.") % [
			scenes.size(), troubled], ""))
	return findings


## What one script contributes: the four findings that need the rows as well as the scene. The script
## is opened as a sheet in memory, measured and dropped - nothing is written, and a script that never
## reaches a shader costs one substring test.
static func sheet_findings(script_path: String) -> Array[Dictionary]:
	var source: String = EventSheetProjectDoctor.source_of(script_path)
	var reaches: bool = false
	for word: String in SHEET_WORDS:
		reaches = reaches or source.contains(word)
	if not reaches:
		return []
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(script_path)
	if sheet == null:
		return []
	return _filed(script_path, EventSheetEffectFindings.findings(sheet))


## A family's findings as the Doctor files them: its own severity and wording, under the check id its
## kind maps to, pointing at the file a reader should open.
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
