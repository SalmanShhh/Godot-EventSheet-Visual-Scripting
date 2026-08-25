# What a node WEARS, who else wears it, and the five ways an effect silently does nothing.
#
# A material is a resource, and a resource is shared. That one sentence is the whole of this test:
# twelve goblins pointing at one `.tres` are twelve nodes and ONE material, so a row that dissolves
# the goblin the player hit dissolves the tribe - and nothing anywhere says so until the game runs.
#
# Measured here, by value:
#
#   the INDEX - one scan of the project answering who holds which file and which node wears which
#   material, and the readiness that lets a head band say "counting…" instead of waiting for it;
#   the BAND - the material file, the shader at the end of the chain, the passes it draws in, and the
#   sharing (or the copy this sheet already takes, which is the answer rather than the warning);
#   the FINDINGS - a dial the shader does not declare, dials turned on a shared material, rows on a
#   node wearing nothing, a global Project Settings never declared, and a screen effect left drawing;
#   the FIX - the row that gives this node its own copy, written where it has to run: once, first;
#   the REPORT - the same five, filed as the Doctor's Effects section.
@tool
class_name EffectFactsTest
extends RefCounted

const Pins := preload("res://tests/pin_table.gd")

const FIXTURE_DIR: String = "res://tests/fixtures/"
const BOSS: String = FIXTURE_DIR + "effect_scene_boss.gd"
const GOBLIN: String = FIXTURE_DIR + "effect_scene_goblin.gd"
const GOBLIN_SCENE: String = FIXTURE_DIR + "effect_scene_goblin.tscn"
const ORC_SCENE: String = FIXTURE_DIR + "effect_scene_orc.tscn"
const SCREEN_SCENE: String = FIXTURE_DIR + "effect_scene_screen.tscn"
const SHARED_MATERIAL: String = FIXTURE_DIR + "effect_shared_material.tres"


static func run() -> bool:
	var ok: bool = true
	ok = _test_the_index() and ok
	ok = _test_the_bands() and ok
	ok = _test_the_findings() and ok
	ok = _test_the_screen_effect() and ok
	ok = _test_the_fix() and ok
	ok = _test_the_report() and ok
	return ok


## ONE scan, answering every question about every file at once. What is pinned is that it answers the
## same whether it was asked about a material or an environment, that it says so when it has NOT
## finished (which is what keeps it off the open), and that dropping it starts again.
static func _test_the_index() -> bool:
	_fresh()
	var ok: bool = _check("nothing is known before the scan runs",
		PackedStringArray([str(EventSheetProjectShareIndex.is_ready()),
			str(EventSheetProjectShareIndex.wearers_of(SHARED_MATERIAL).size())]),
		PackedStringArray(["false", "0"]))
	EventSheetProjectShareIndex.build_now()
	var worn: PackedStringArray = PackedStringArray()
	for wearer: Dictionary in EventSheetProjectShareIndex.wearers_of(SHARED_MATERIAL):
		worn.append("%s in %s" % [str(wearer["name"]), str(wearer["scene_path"]).get_file()])
	ok = _check("every node of the project wearing one material, in scan order", worn,
		PackedStringArray(["Goblin in effect_scene_goblin.tscn", "Torch in effect_scene_goblin.tscn",
			"Orc in effect_scene_orc.tscn"])) and ok
	ok = _check("and the scenes holding the file", EventSheetProjectShareIndex.holders_of(SHARED_MATERIAL),
		PackedStringArray([GOBLIN_SCENE, ORC_SCENE])) and ok
	# The two questions a band really asks: who ELSE, leaving the asker out of its own count.
	ok = _check("a node is never shared with itself",
		EventSheetProjectShareIndex.other_wearers(SHARED_MATERIAL,
			"%s|." % GOBLIN_SCENE).size(), 2) and ok
	ok = _check("and a scene is never sharing with itself",
		EventSheetProjectShareIndex.other_holders(SHARED_MATERIAL, GOBLIN_SCENE),
		PackedStringArray([ORC_SCENE])) and ok
	EventSheetProjectShareIndex.clear_cache()
	ok = _check("dropping it forgets everything", PackedStringArray([
		str(EventSheetProjectShareIndex.is_ready()),
		str(EventSheetProjectShareIndex.holders_of(SHARED_MATERIAL).size())]),
		PackedStringArray(["false", "0"])) and ok
	# The same question through the public seam, which is where a pack asks it: it builds the scan
	# if nothing has yet, so a caller with no head band to say "counting…" through still gets an
	# answer rather than an empty one.
	return _check("a pack asks the same question through the API", PackedStringArray([
		",".join(EventSheets.scenes_using_resource(SHARED_MATERIAL, GOBLIN_SCENE)),
		",".join(EventSheets.scenes_using_resource(""))]),
		PackedStringArray([ORC_SCENE, ""])) and ok


## The band. One per wearing node of the attached scene, saying the file, the shader and the sharing -
## and saying "counting…" rather than waiting while the scan is still running, which is the whole
## reason the scan is sliced at all.
static func _test_the_bands() -> bool:
	_fresh()
	# Asked BEFORE the scan finishes, which in a run with no frames to spread it over is always.
	var counting: Array[Dictionary] = EventSheetSceneEffectFacts.effect_bands(GOBLIN)
	var ok: bool = _check("a band asked mid-scan says so rather than waiting",
		str(counting[0]["value"]),
		"effect_shared_material.tres (effect_dissolve.gdshader) · counting…")
	EventSheetProjectShareIndex.build_now()
	var said: PackedStringArray = PackedStringArray()
	for band: Dictionary in EventSheetSceneEffectFacts.effect_bands(GOBLIN):
		said.append("%s | %s" % [str(band["value"]), str(band["warning"])])
	ok = _check("one band per wearing node, with who else wears the file", said, PackedStringArray([
		"effect_shared_material.tres (effect_dissolve.gdshader) · shared with 2 other nodes | true",
		"effect_shared_material.tres (effect_dissolve.gdshader) · shared with 2 other nodes | true"
	])) and ok
	# The echo is the node's own line of the scene file, then the names its rows may use, then the
	# nodes a dial row would move as well as this one.
	ok = _check("the echo is the line the scene really holds",
		str(EventSheetSceneEffectFacts.effect_bands(GOBLIN)[0]["echo"]),
		"effect_scene_goblin.tscn: Sprite2D \"Goblin\", material = \"%s\" · uniform dissolve, edge_tint, burn_noise, steps · also worn by Torch, Orc"
			% SHARED_MATERIAL) and ok
	# With the copy taken, the band ANSWERS instead of warning. A reader who has fixed it is not told
	# about it again, which is the difference between a head that is read and one that is not.
	ok = _check("the sheet that takes a copy reads as taking one", str(
		EventSheetSceneEffectFacts.effect_bands(GOBLIN, PackedStringArray(["self"]))[0]["value"]),
		"effect_shared_material.tres (effect_dissolve.gdshader) · its own copy at runtime") and ok
	# And the boss, whose second node keeps its material INSIDE the scene: nothing else can wear it,
	# so there is nothing to warn about and the band says which shader it runs anyway.
	var boss: PackedStringArray = PackedStringArray()
	for band: Dictionary in EventSheetSceneEffectFacts.effect_bands(BOSS):
		boss.append(str(band["value"]))
	return _check("a material kept inside the scene is shared with nobody", boss, PackedStringArray([
		"effect_dissolve_material.tres (effect_dissolve.gdshader) · worn by this node only",
		"a material of its own (effect_glow.gdshader) · kept inside this scene - nothing else wears it"
	])) and ok


## The four findings about the rows. Every one of them runs today without an error and shows nothing,
## and every one is a comparison of two files somebody can already look at.
static func _test_the_findings() -> bool:
	_fresh()
	EventSheetProjectShareIndex.build_now()
	var goblin: EventSheetResource = GDScriptImporter.new().import_external(GOBLIN)
	var said: PackedStringArray = PackedStringArray()
	for finding: Dictionary in EventSheetEffectFindings.findings(goblin):
		said.append("%s | %s | %s" % [str(finding["kind"]), str(finding["subject"]),
			str(finding["fix_label"])])
	# One finding per NODE and not per row: the goblin turns a dial on itself and on its torch, and
	# both wear the same file, so that is two nodes and two fixes rather than four notes.
	var ok: bool = _check("dials turned on a shared material, once per node", said, PackedStringArray([
		"effect-dials-on-a-shared-material | self | Make the effect this node's own",
		"effect-dials-on-a-shared-material | Torch | Make the effect this node's own"
	]))
	ok = _check("and the message names who else moves",
		str(EventSheetEffectFindings.findings(goblin)[0]["message"]),
		"effect_shared_material.tres is worn by Torch, Orc as well, and a material is one object - every dial this row turns turns for them too. Give this node its own copy first.") and ok
	# A sheet that has taken the copy is never told again - the finding and the head band read the
	# same rows to decide it, so they can never disagree.
	goblin.events.insert(0, _own_copy_event(""))
	ok = _check("a sheet that takes its own copy is left alone about that node",
		_kinds(EventSheetEffectFindings.findings(goblin)),
		PackedStringArray(["effect-dials-on-a-shared-material"])) and ok
	# The other three, each on the sheet that has it. The boss names a dial its shader does not
	# declare and a global Project Settings has never heard of; the row aimed at a node wearing
	# nothing at all is the third.
	var boss: EventSheetResource = GDScriptImporter.new().import_external(BOSS)
	ok = _check("the boss's own two", _kinds(EventSheetEffectFindings.findings(boss)),
		PackedStringArray(["effect-dial-the-shader-does-not-declare",
			"shader-global-the-project-does-not-declare"])) and ok
	# And the finding says WHICH parameter holds the name, because a hand-written line naming a dial
	# the shader never had lifts to the frozen free-string row - which keeps it quoted, in `param`.
	# A re-pick that wrote into `dial` there would add a parameter nothing reads and change nothing.
	ok = _check("the re-pick knows the slot the name really sits in", PackedStringArray([
		str(EventSheetEffectFindings.findings(boss)[0]["param"]),
		EventSheetEffectFindings.dial_param_of((_dial_event("", "dissolve").actions[0]) as Resource)]),
		PackedStringArray(["param", "dial"])) and ok
	var plain: EventSheetResource = EventSheetResource.new()
	plain.external_source_path = BOSS
	plain.events.append(_dial_event("$Plain", "dissolve"))
	plain.events.append(_dial_event("aura", "dissolve"))
	return _check("a row on a node wearing nothing is a finding, a row on a variable is not",
		_kinds(EventSheetEffectFindings.findings(plain)),
		PackedStringArray(["effect-rows-on-a-node-wearing-none"])) and ok


## The screen effect: a rect covering the screen with a shader that samples it back, visible, with
## every dial still where the shader put it. The whole screen redraws through it every frame for
## nothing - and the same scene's hidden rect costs nothing, so only one of the two is a finding.
static func _test_the_screen_effect() -> bool:
	_fresh()
	var said: PackedStringArray = PackedStringArray()
	for finding: Dictionary in EventSheetEffectFindings.scene_findings(SCREEN_SCENE):
		said.append("%s | %s" % [str(finding["subject"]), str(finding["message"])])
	return _check("only the visible rect with every dial at rest", said, PackedStringArray([
		"Full | Full covers the screen with effect_screen.gdshader and every dial is still at rest - the whole screen redraws through the shader each frame for nothing. Hide it until an effect turns it on."
	]))


## The one-click fix: the row that gives this node its own copy, in an event of its own, on ready,
## above everything that reads through it. Pressed twice it writes one row, because a sheet that has
## taken the step has taken it.
static func _test_the_fix() -> bool:
	_fresh()
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.external_source_path = GOBLIN
	sheet.events.append(_dial_event("", "dissolve"))
	var written: bool = EventSheetEffectFindings.insert_own_material(sheet, "self")
	var head: EventRow = sheet.events[0] as EventRow
	var ok: bool = _check("the copy is taken first, on ready", PackedStringArray([str(written),
		head.trigger_id, str((head.actions[0] as Resource).get("ace_id")),
		str(((head.actions[0] as Resource).get("params") as Dictionary).get("target", ""))]),
		PackedStringArray(["true", "OnReady", "EffectOwnMaterial", ""]))
	ok = _check("the line it writes is the shipped row's own",
		str((head.actions[0] as Resource).get("codegen_template")),
		"{target.}material = {target.}material.duplicate()") and ok
	return _check("pressing it again writes nothing", PackedStringArray([
		str(EventSheetEffectFindings.insert_own_material(sheet, "self")),
		str(sheet.events.size())]), PackedStringArray(["false", "2"])) and ok


## The Doctor's Effects section: the same five findings, filed under their check ids, with a summary
## naming how many scenes wear an effect and how many of them have something wrong.
static func _test_the_report() -> bool:
	_fresh()
	EventSheetEffectsDoctor.ensure_registered()
	var registered: int = 0
	for entry: Dictionary in EventSheetProjectDoctor._extension_checks:
		if str(entry.get("id", "")) == EventSheetEffectsDoctor.CHECK_ID:
			registered += 1
	# Registering twice would run the section twice; the seam replaces by id, and this is what proves
	# it (ensure_registered has now been called at least once by the Doctor and once here).
	var ok: bool = _check("the section registers through the seam a pack uses, exactly once",
		registered, 1)
	var report: Array[Dictionary] = EventSheetEffectsDoctor.report(
		PackedStringArray([GOBLIN_SCENE, ORC_SCENE, SCREEN_SCENE]), PackedStringArray([GOBLIN, BOSS]))
	var checks: PackedStringArray = PackedStringArray()
	for finding: Dictionary in report:
		checks.append(str(finding["check"]))
	ok = _check("every finding is filed under its own check id", checks, PackedStringArray([
		"effects", "effects-screen-effect-idle", "effects-shared-material", "effects-shared-material",
		"effects-unknown-dial", "effects-undeclared-global"])) and ok
	ok = _check("and the summary counts the scenes", str(report[0]["message"]),
		"Effects: 3 scene(s) wearing a material, 1 with something that will not show at run time.") and ok
	return _check("a project with no effects in it reports nothing at all",
		EventSheetEffectsDoctor.report(PackedStringArray(), PackedStringArray()).size(), 0) and ok


# -- the walk -----------------------------------------------------------------------------------


## Every reader dropped, so one test's scan cannot answer the next one's question. The same call the
## editor makes when the filesystem changes.
static func _fresh() -> void:
	EventSheetProjectShareIndex.clear_cache()
	EventSheetSceneEffects.clear_cache()
	EventForgeShaderUniforms.clear_cache()


## One event holding one Set row aimed at `target`, turning `dial`.
static func _dial_event(target: String, dial: String) -> EventRow:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "EffectSetDial"
	action.codegen_template = "{target.}material.set_shader_parameter(&\"{dial}\", {value})"
	action.params = {"target": target, EventForgeEffectDialACEs.DIAL_PARAM: dial, "value": "0.7"}
	var event_row: EventRow = EventRow.new()
	event_row.actions.append(action)
	return event_row


## The event the one-click fix writes, built the way the fix builds it.
static func _own_copy_event(target: String) -> EventRow:
	var event_row: EventRow = EventRow.new()
	event_row.trigger_provider_id = "Core"
	event_row.trigger_id = EventSheetEffectFindings.READY_TRIGGER
	event_row.actions.append(EventSheetEffectFindings.own_material_action(target))
	return event_row


static func _kinds(found: Array[Dictionary]) -> PackedStringArray:
	var kinds: PackedStringArray = PackedStringArray()
	for finding: Dictionary in found:
		kinds.append(str(finding["kind"]))
	return kinds


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return Pins.check_value("effect_facts_test", label, actual, expected)
