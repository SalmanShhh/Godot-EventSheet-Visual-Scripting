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
extends EventSheetDoctorSection

## The id the section is registered under, and the id each finding is filed as. Frozen alongside the
## wording: the quick-fix chips and the tests address a finding by its check id.
const CHECK_ID := "effects"
const CHECK_UNKNOWN_DIAL := "effects-unknown-dial"
const CHECK_SHARED := "effects-shared-material"
const CHECK_NO_MATERIAL := "effects-no-material"
const CHECK_GLOBAL := "effects-undeclared-global"
const CHECK_SCREEN := "effects-screen-effect-idle"
const CHECK_BLEND := "effects-blend-over-shader"

## And the two the material words earn: a mesh whose material file other meshes wear (information -
## every material word takes its own copy first, so nothing needs fixing), and a blending or lighting
## word on a 2D item wearing a shader, where the value has nowhere to go.
const CHECK_MESH_SHARED := "effects-shared-mesh-material"
const CHECK_MATERIAL_ON_SHADER := "effects-material-word-on-a-shader"

## And the one the POST STACK earns: effects that cover the whole viewport in a scene that also
## carries an interface layer, with no row saying which side of it they belong on.
const CHECK_POST_ORDER := "effects-post-stack-order-unsaid"

## Which check id each finding reports as. One table, so the note on the row and the line in the
## report are the same finding under two roofs.
const CHECK_FOR_KIND: Dictionary = {
	EventSheetEffectFindings.KIND_UNKNOWN_DIAL: CHECK_UNKNOWN_DIAL,
	EventSheetEffectFindings.KIND_SHARED_MATERIAL: CHECK_SHARED,
	EventSheetEffectFindings.KIND_NO_MATERIAL: CHECK_NO_MATERIAL,
	EventSheetEffectFindings.KIND_UNDECLARED_GLOBAL: CHECK_GLOBAL,
	EventSheetEffectFindings.KIND_IDLE_SCREEN_EFFECT: CHECK_SCREEN,
	EventSheetEffectFindings.KIND_BLEND_OVER_SHADER: CHECK_BLEND,
	EventSheetEffectFindings.KIND_MESH_SHARED_MATERIAL: CHECK_MESH_SHARED,
	EventSheetEffectFindings.KIND_MATERIAL_WORD_ON_A_SHADER: CHECK_MATERIAL_ON_SHADER,
	EventSheetEffectFindings.KIND_POST_ORDER_UNSAID: CHECK_POST_ORDER,
}

## The cheap first question asked of a scene's text before anything is parsed - a scene with no
## material line in it wears no effect, and a project with no shaders should not pay to have every
## scene parsed to find that out.
const MATERIAL_WORD := "material = "

## And of a script's text: the member every dial row reaches through, the call every global one
## makes, and the call a blend row makes. A script that says none of them cannot be one of these
## sheets.
##
## EVERY WORD HERE IS A SPELLING A ROW WRITES, never a name a script might merely mention. That is
## not tidiness: a script matching any of them is fully OPENED AS A SHEET in memory, so a word like a
## bare class name - which every script that names the class in a comment, a type, or a doc line
## carries - buys a whole sheet build for a file that has no rows of this kind at all. So the mesh
## word is the WRITE the row emits, the two 2D words are the cast and the test their template emits,
## and the post-stack words are the calls rather than the phrase "post effect".
const SHEET_WORDS: PackedStringArray = ["set_shader_parameter", "get_shader_parameter",
	"global_shader_parameter", EventSheetEffectFindings.BLEND_CALL, "material_override = ",
	"is CanvasItemMaterial", "as CanvasItemMaterial", "post_effect(", "post_effect_is_on(",
	"post_effect_count(", "post_effects_below(", "post_effects_above(", "use_look(",
	"blend_to_look("]


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
	# TWO CORPORA, and either one on its own is enough to have something to say. A 3D project can
	# have no scene wearing a `material` at all - a mesh wears its material somewhere else - and its
	# sheets still say things about materials worth reading, so the sweep over the scripts is asked
	# its own cheap question rather than riding on the scenes having answered first.
	var sheets: PackedStringArray = _sheets_reaching_a_material(scripts)
	if scenes.is_empty() and sheets.is_empty():
		return findings
	# The counts the section is about are project-wide questions, and the one that answers them is the
	# shared index. A Doctor run has no frames to spread it over, so it is built here, once, before
	# anything asks - which is also what makes the report the same whether the editor was open or not.
	EventSheetProjectShareIndex.build_now()
	var troubled: int = 0
	# The summary points at the FIRST scene with something wrong, because that is the one worth
	# opening - double-clicking the line in the panel is what takes the reader there.
	var worst_path: String = scenes[0] if not scenes.is_empty() else sheets[0]
	for scene_path: String in scenes:
		var found: Array[Dictionary] = EventSheetEffectFindings.scene_findings(scene_path)
		if found.is_empty():
			continue
		if troubled == 0:
			worst_path = scene_path
		troubled += 1
		findings.append_array(_filed(scene_path, found, CHECK_FOR_KIND, CHECK_ID))
	for script_path: String in sheets:
		findings.append_array(sheet_findings(script_path))
	findings.insert(0, _finding("info", CHECK_ID, worst_path,
		EventSheetL10n.translate("Effects: %d scene(s) wearing a material, %d with something that will not show at run time.") % [
			scenes.size(), troubled], ""))
	return findings


## The scripts worth opening as sheets - the substring sweep, asked once so the two callers of it
## cannot drift. A project with no shaders and no material words pays one test per file and stops.
static func _sheets_reaching_a_material(scripts: PackedStringArray) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for script_path: String in scripts:
		if _says_any(EventSheetProjectDoctor.source_of(script_path), SHEET_WORDS):
			found.append(script_path)
	return found


## What one script contributes: the four findings that need the rows as well as the scene. The script
## is opened as a sheet in memory, measured and dropped - nothing is written, and a script that never
## reaches a shader costs one substring test.
static func sheet_findings(script_path: String) -> Array[Dictionary]:
	var source: String = EventSheetProjectDoctor.source_of(script_path)
	if not _says_any(source, SHEET_WORDS):
		return []
	var sheet: EventSheetResource = EventSheetProjectDoctor.sheet_of(script_path)
	if sheet == null:
		return []
	return _filed(script_path, EventSheetEffectFindings.findings(sheet), CHECK_FOR_KIND, CHECK_ID)
