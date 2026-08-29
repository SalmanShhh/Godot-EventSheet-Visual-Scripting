# Godot EventSheets - what the editor is allowed to cost on a project far bigger than this one.
#
# Every other timing pin in this suite is measured on THIS repository. That is a large project by
# most standards and it is still not the one the plugin has to survive: a game two years in, a
# thousand scripts, three hundred scenes, a hundred shaders, and the level scene nobody ever split
# up. So `huge_project_fixture.gd` fabricates that project under `user://` and the budgets below are
# measured against it.
#
# EVERY NUMBER HERE WAS MEASURED, at least three times, on a quiet machine, before it was written
# down, and each budget says what it measured at. A budget invented from a feeling is either so
# tight that everyone learns to ignore the failure or so loose that nothing can trip it. What these
# are for is a change that makes something ALGORITHMICALLY slower, and a regression of that kind
# lands far outside the band rather than just inside it.
#
# WHAT IS NOT HERE, and why:
#   - the 389-row viewport rebuild budget lives in `lift_perf_test.gd`, beside the structural pins
#     that are the real reason it is fast. It is not repeated here.
#   - the whole-project Doctor run is budgeted in `project_doctor_test.gd`, around the audit that
#     test already runs. Running it twice would cost the suite a minute and a half for one number.
#   - the whole-project scanners (the Doctor's sheet list, the picker's vocabulary, the shared
#     resource index) cannot be pointed at the fixture: `res://` is fixed when the process starts.
#     Those are measured on this repository, which carries 112 packs and every demo, and each pin
#     below says which corpus it used.
#
# COLD BOOT IS MEASURED IN ITS OWN PROCESS. By the time any test runs, half the plugin is compiled
# and every registry is warm, so the work an editor start really does measures as zero from in here.
# `cold_boot_probe.gd` is run as a subprocess and its two numbers are pinned.
@tool
class_name HugeProjectBudgetTest
extends RefCounted

const HugeProject := preload("res://tests/huge_project_fixture.gd")
const Pins := preload("res://tests/pin_table.gd")

## The probe that answers what a cold editor start costs, run in a process of its own.
const COLD_BOOT_PROBE: String = "res://tests/cold_boot_probe.gd"

## Enabling the plugin: loading plugin.gd and building everything `_enter_tree` hands the editor.
## Measured 268-293 ms across eight runs. The budget is deliberately far below the ~2,000 ms this
## used to cost, because that is the regression it exists to catch: one heavy class named in a boot
## file compiles its whole subtree into every editor start, and it has crept back in twice.
const BOOT_CLOSURE_BUDGET_MS: int = 1200

## The FIRST sheet tab of a session: every descriptor, the reverse index every lift matches against,
## the compiled matchers, the block kinds, and then one ordinary 74-line sheet opened through them.
## Measured 2,284-2,472 ms across eight runs, of which 2,030-2,190 is the registries - the half no
## later tab pays, and the half worth making smaller.
const FIRST_OPEN_BUDGET_MS: int = 5000

## Opening the fixture's 2,000-line script as a sheet: the import, the lift, and the row build with
## its head bands, ending in 1,441 rows. Measured 5,629, 5,758 and 7,305 ms - the widest spread of
## anything here, which is why the margin over it is the widest. The registries are warmed BEFORE
## the clock starts, because what they cost is the budget above rather than this one.
const BIG_SHEET_OPEN_BUDGET_MS: int = 14000

## REBUILDING those 1,441 rows, which is what the canvas pays after every edit - the number a reader
## feels most often, and the one nothing pinned until now. Measured 2,327, 2,337 and 2,358 ms.
##
## The rows of an opened script are made INERT (nothing may write to a published verb's body), and
## making one inert used to build its words there and then, so a long file paid for every row it had
## whether or not anyone had scrolled to it. On a 4,000-line script that was 5,700 ms a rebuild and
## is now 2,400. This budget is measured on the fixture's own 2,000-line script, which is under the
## viewport's eager-span threshold and so pays for its words either way; what it catches is a change
## that makes the WALK itself slower.
const BIG_SHEET_REBUILD_BUDGET_MS: int = 6000

## The Add picker's whole tree, built with every pack in this repository loaded and a sheet whose
## scene wears shader materials, so the scene shelves are built rather than skipped. Measured 498,
## 508 and 514 ms over 5,129 registered rows - it was 392-469 while the shelves were being skipped,
## and the difference is the work this budget did not cover before.
const PICKER_OPEN_BUDGET_MS: int = 1500

## The same tree built again per typed character, which is what the search box costs. The shelves
## are derived from the scene on every refresh, so a keystroke pays for them however narrow the
## filter, and this is the number a change to them moves. Measured 113, 116 and 116 ms.
const PICKER_KEYSTROKE_BUDGET_MS: int = 350

## A sheet of this repository whose attached scene really wears shader materials. The huge fixture
## cannot answer this one: its scenes live under `user://` and the readers behind the shelves follow
## `res://`, which is fixed when the process starts.
const WEARING_SHEET: String = "res://tests/fixtures/effect_scene_boss.gd"

## ONE KEYSTROKE in a completing field, with the kind's list already built. Sub-frame is the design
## target and 16 ms is the frame; measured 2.1-2.6 ms, so the pin is the TARGET rather than the
## measurement. Anything at all that scans the project per keystroke lands orders of magnitude out.
const KEYSTROKE_BUDGET_MS: float = 16.0

## Reading the lights and the material wearers of a 2,000-node scene, from cold. Measured 18.4, 20.2
## and 21.8 ms for the pair, down from 267-296 when each reader parsed the scene file for itself:
## they share one parse now, held per file. The budget is well clear of that but far under the old
## 900, because a reader that goes back to parsing on its own lands straight back at 270.
const SCENE_FACTS_BUDGET_MS: int = 150

## The same two questions asked again. Measured 0.02-0.04 ms for the pair, because the answer is
## held and handed back by reference - which is what the structural pin beside this one is really
## about. The budget is a claim that a second ask is FREE, not that it is fast.
const SCENE_FACTS_WARM_BUDGET_MS: int = 5

## Parsing the uniforms of all 100 fixture shaders from cold. Measured 176, 180 and 187 ms.
const SHADER_CORPUS_BUDGET_MS: int = 900

## Asking the same 100 shaders again. Measured 0.2 ms, four runs alike, down from 86-101: deciding
## whether the cache entry was current used to open every file for its length, so a "cached" read
## still cost I/O per question and a row build asking per dial per row paid it thousands of times.
## The identity is held per file now. Like the scene pin below it, this budget is a claim that a
## second ask is FREE rather than that it is fast.
const SHADER_CORPUS_WARM_BUDGET_MS: int = 5

## One keystroke measured once is noise; this many, divided, is a number.
const KEYSTROKE_SAMPLES: int = 20

## Prefixes a reader types on the way to a name, so the per-keystroke figure covers a growing filter
## rather than the same lookup twenty times.
const TYPED_PREFIXES: Array[String] = ["h", "he", "hea", "heal", "healt", "health"]


## A stand-in for the dock. The picker asks whatever it hangs on for the open sheet, and the scene
## shelves are built from the scene that sheet's script is attached to - so without one the shelf
## half of a tree refresh answers null and measures as free.
class SheetHost:
	extends Node

	var sheet: EventSheetResource = null


	func get_current_sheet() -> EventSheetResource:
		return sheet


static func run() -> bool:
	var project: Dictionary = HugeProject.build()
	var passed: bool = _pin_the_corpus(project)
	passed = _pin_cold_boot() and passed
	passed = _pin_scene_facts(project) and passed
	passed = _pin_the_shader_corpus(project) and passed
	passed = _pin_a_keystroke() and passed
	# One editor serves both the open budget and the picker budget. Building a second would measure
	# the same vocabulary scan twice and cost the suite half a minute for nothing.
	var editor: EventSheetEditor = EventSheetEditor.new()
	passed = _pin_opening_the_big_script(project, editor) and passed
	passed = _pin_the_picker(editor) and passed
	editor.free()
	return passed


## The fixture is what it says it is. Every budget under this one is meaningless if the corpus
## quietly shrank - a 40-node scene walks in no time at all, and would pass the 2,000-node pin.
static func _pin_the_corpus(project: Dictionary) -> bool:
	var big_script_lines: int = FileAccess.get_file_as_string(str(project["big_script"])).split("\n").size()
	var big_scene_nodes: int = EventSheetSceneConnections.nodes_of_scene(str(project["big_scene"])).size()
	var measured: Dictionary = {
		"scripts": (project["scripts"] as PackedStringArray).size(),
		"scenes": (project["scenes"] as PackedStringArray).size(),
		"shaders": (project["shaders"] as PackedStringArray).size(),
		"the big script is at least two thousand lines": big_script_lines >= HugeProject.BIG_SCRIPT_LINES,
		"the big scene is at least two thousand nodes": big_scene_nodes >= HugeProject.BIG_SCENE_NODES,
	}
	return Pins.check("huge_project_corpus", {
		"scripts": HugeProject.SCRIPT_COUNT,
		"scenes": HugeProject.SCENE_COUNT,
		"shaders": HugeProject.SHADER_COUNT,
		"the big script is at least two thousand lines": true,
		"the big scene is at least two thousand nodes": true,
	}, func(key: String) -> Variant:
		return measured[key])


## What enabling the plugin costs, and what the first sheet tab after it costs, both measured in a
## process that has never done either. A probe that cannot be run at all FAILS rather than passing
## quietly: a budget nobody measured is worse than no budget.
static func _pin_cold_boot() -> bool:
	var output: Array = []
	var arguments: PackedStringArray = PackedStringArray(["--headless", "--path",
		ProjectSettings.globalize_path("res://"), "--script", COLD_BOOT_PROBE])
	OS.execute(OS.get_executable_path(), arguments, output, true)
	var numbers: Dictionary = _probe_numbers(output)
	var passed: bool = _check("the cold boot probe answered", numbers.has("closure_ms"), true)
	if not passed:
		print("  the probe printed no result line; its output was:")
		for chunk: Variant in output:
			print("  %s" % str(chunk))
		return false
	var closure_ms: float = float(numbers["closure_ms"])
	var first_open_ms: float = float(numbers["first_open_ms"])
	passed = _check("enabling the plugin costs under %d ms (took %.1f ms)" % [
		BOOT_CLOSURE_BUDGET_MS, closure_ms],
		closure_ms <= float(BOOT_CLOSURE_BUDGET_MS), true) and passed
	passed = _check("the first sheet tab costs under %d ms (took %.1f ms, %.1f of it registries)" % [
		FIRST_OPEN_BUDGET_MS, first_open_ms, float(numbers.get("registries_ms", 0.0))],
		first_open_ms <= float(FIRST_OPEN_BUDGET_MS), true) and passed
	return passed


## The `key=value` pairs off the probe's one result line.
static func _probe_numbers(output: Array) -> Dictionary:
	var numbers: Dictionary = {}
	var text: String = ""
	for chunk: Variant in output:
		text += "%s\n" % str(chunk)
	for line: String in text.split("\n"):
		if not line.begins_with("cold_boot "):
			continue
		for pair: String in line.trim_prefix("cold_boot ").split(" ", false):
			var parts: PackedStringArray = pair.split("=")
			if parts.size() == 2:
				numbers[parts[0]] = float(parts[1])
	return numbers


## The 2,000-line script, opened the way the dock opens one: import, lift, and the row build with
## its head bands. The registries are warmed first on purpose - their cost is the first-tab budget
## above, and leaving it in here would measure the same two seconds twice and hide the row build
## behind them.
##
## What this number does NOT include is the scene-derived half of the head (which node the script is
## on, what lights it, what it wears): those bands resolve through the scenes under `res://`, and a
## fixture script lives outside it. The scene readers are budgeted directly instead, on the
## 2,000-node scene, which is the larger question anyway.
static func _pin_opening_the_big_script(project: Dictionary, editor: EventSheetEditor) -> bool:
	var path: String = str(project["big_script"])
	var source: String = FileAccess.get_file_as_string(path)
	EventSheetOpenJob.warm_registries()
	var start_usec: int = Time.get_ticks_usec()
	var importer: GDScriptImporter = GDScriptImporter.new()
	var sheet: EventSheetResource = importer.import_external(path, false)
	EventSheetACELifter.attempt_lift(sheet, source)
	editor.setup(sheet)
	var elapsed_ms: float = float(Time.get_ticks_usec() - start_usec) / 1000.0
	var rows: int = editor.get_viewport_control().get_total_row_count()
	var passed: bool = _check("the big script opened as rows (built %d)" % rows, rows > 100, true)
	passed = _check("opening a %d-line script under %d ms (took %.1f ms)" % [
		source.split("\n").size(), BIG_SHEET_OPEN_BUDGET_MS, elapsed_ms],
		elapsed_ms <= float(BIG_SHEET_OPEN_BUDGET_MS), true) and passed
	# And the same rows built again, which is what an edit costs: the sheet is unchanged, so this is
	# purely the walk plus the words, with every by-file answer already warm.
	var rebuild_start_usec: int = Time.get_ticks_usec()
	editor.get_viewport_control().call("_refresh_rows")
	var rebuild_ms: float = float(Time.get_ticks_usec() - rebuild_start_usec) / 1000.0
	return _check("rebuilding those %d rows under %d ms (took %.1f ms)" % [
		rows, BIG_SHEET_REBUILD_BUDGET_MS, rebuild_ms],
		rebuild_ms <= float(BIG_SHEET_REBUILD_BUDGET_MS), true) and passed


## The Add picker with every pack in this repository in it. Measured on the repository rather than
## the fixture because the vocabulary comes from `res://`, which no test can move.
##
## THE PICKER IS GIVEN A SHEET, and that is half the measurement. The scene shelves - one entry per
## wearing node per declared dial per verb, and the same for the scene's lights - are built inside
## the tree refresh, which runs again on every keystroke of the search box. A picker with no sheet
## answers null before it does any of that work, so the number then covers the tree as it was rather
## than as it is. The sheet is one of this repository's own effect fixtures, whose scene really
## wears materials; the shelf count is pinned beside the time so the budget cannot quietly go back
## to measuring nothing.
static func _pin_the_picker(editor: EventSheetEditor) -> bool:
	var registry: EventSheetACERegistry = editor.get_ace_registry()
	var loaded: int = registry.get_all_definitions().size()
	var passed: bool = _check("the picker's vocabulary is fully loaded (%d rows)" % loaded,
		loaded > 1000, true)
	var host: SheetHost = SheetHost.new()
	host.sheet = EventSheetResource.new()
	host.sheet.external_source_path = WEARING_SHEET
	var picker: ACEPickerDialog = ACEPickerDialog.new()
	picker.init_dialog(host, registry)
	picker._context = {"mode": "append_action", "signals_only": false, "selected_resource": null}
	var shelved: int = ACEPickerDialog.effect_dial_definitions(host.sheet, registry).size()
	passed = _check("the sheet really grows dial shelves (%d entries)" % shelved,
		shelved > 0, true) and passed
	var start_usec: int = Time.get_ticks_usec()
	picker._refresh_tree()
	var elapsed_ms: float = float(Time.get_ticks_usec() - start_usec) / 1000.0
	passed = _check("the picker opens over %d rows under %d ms (took %.1f ms)" % [
		loaded, PICKER_OPEN_BUDGET_MS, elapsed_ms],
		elapsed_ms <= float(PICKER_OPEN_BUDGET_MS), true) and passed
	# And the tree built again per typed character, which is what the search box costs: the shelves
	# are rebuilt from the scene every time, so a keystroke pays for them however narrow the filter.
	var typed_start_usec: int = Time.get_ticks_usec()
	for prefix: String in TYPED_PREFIXES:
		picker._search.text = prefix
		picker._refresh_tree()
	var per_keystroke_ms: float = float(Time.get_ticks_usec() - typed_start_usec) / 1000.0 \
		/ float(TYPED_PREFIXES.size())
	host.free()
	return _check("a search keystroke rebuilds the tree under %d ms (took %.1f ms)" % [
		PICKER_KEYSTROKE_BUDGET_MS, per_keystroke_ms],
		per_keystroke_ms <= float(PICKER_KEYSTROKE_BUDGET_MS), true) and passed


## One keystroke in a completing field. The list is built first, outside the clock, because that is
## the contract: a kind's candidates are built once and only FILTERED afterwards.
static func _pin_a_keystroke() -> bool:
	var sheet: EventSheetResource = _completing_sheet()
	EventSheetCompletions.for_field(sheet, EventSheetCompletions.FIELD_EXPRESSION, "")
	var start_usec: int = Time.get_ticks_usec()
	for repeat in KEYSTROKE_SAMPLES:
		for prefix: String in TYPED_PREFIXES:
			EventSheetCompletions.for_field(sheet, EventSheetCompletions.FIELD_EXPRESSION, prefix)
	var per_keystroke_ms: float = float(Time.get_ticks_usec() - start_usec) / 1000.0 \
		/ float(KEYSTROKE_SAMPLES * TYPED_PREFIXES.size())
	return _check("a keystroke answers inside a frame (%.3f ms, budget %.1f)" % [
		per_keystroke_ms, KEYSTROKE_BUDGET_MS],
		per_keystroke_ms <= KEYSTROKE_BUDGET_MS, true)


## A sheet with enough of its own vocabulary that filtering it is real work.
static func _completing_sheet() -> EventSheetResource:
	EventSheetCompletions.clear_cache()
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.custom_class_name = "Player"
	sheet.host_class = "CharacterBody2D"
	for index in 40:
		sheet.variables["health_%02d" % index] = {"type": "int", "default": index}
	for index in 12:
		var event_function: EventFunction = EventFunction.new()
		event_function.function_name = "do_thing_%02d" % index
		sheet.functions.append(event_function)
	return sheet


## The lights and the material wearers of a 2,000-node scene, cold and then warm - and the reason
## the warm read is free, which is that the answer is HELD rather than re-derived. Identity, not
## equality: two equal arrays would still mean every caller re-walked two thousand nodes.
static func _pin_scene_facts(project: Dictionary) -> bool:
	var scene_path: String = str(project["big_scene"])
	EventSheetSceneLights.clear_cache()
	EventSheetSceneEffects.clear_cache()
	var start_usec: int = Time.get_ticks_usec()
	var lights: Array[Dictionary] = EventSheetSceneLights.for_scene(scene_path)
	var wearers: Array[Dictionary] = EventSheetSceneEffects.for_scene(scene_path)
	var cold_ms: float = float(Time.get_ticks_usec() - start_usec) / 1000.0
	var passed: bool = _check("the big scene really holds lights to find (%d)" % lights.size(),
		lights.size() > 100, true)
	passed = _check("the big scene really holds material wearers to find (%d)" % wearers.size(),
		wearers.size() > 100, true) and passed
	passed = _check("scene facts on a %d-node scene under %d ms (took %.1f ms)" % [
		HugeProject.BIG_SCENE_NODES, SCENE_FACTS_BUDGET_MS, cold_ms],
		cold_ms <= float(SCENE_FACTS_BUDGET_MS), true) and passed
	start_usec = Time.get_ticks_usec()
	var lights_again: Array[Dictionary] = EventSheetSceneLights.for_scene(scene_path)
	var wearers_again: Array[Dictionary] = EventSheetSceneEffects.for_scene(scene_path)
	var warm_ms: float = float(Time.get_ticks_usec() - start_usec) / 1000.0
	passed = _check("asking again costs under %d ms (took %.3f ms)" % [
		SCENE_FACTS_WARM_BUDGET_MS, warm_ms],
		warm_ms <= float(SCENE_FACTS_WARM_BUDGET_MS), true) and passed
	passed = _check("the lights of a scene are held and handed out by reference",
		is_same(lights, lights_again), true) and passed
	passed = _check("the material wearers of a scene are held and handed out by reference",
		is_same(wearers, wearers_again), true) and passed
	return passed


## A hundred shaders, parsed and then asked again. The warm figure is pinned as well as the cold
## one, because a cache that still costs a filesystem call per question is a cache that stops
## helping the moment a row build asks it a thousand times.
static func _pin_the_shader_corpus(project: Dictionary) -> bool:
	var shaders: PackedStringArray = project["shaders"]
	EventForgeShaderUniforms.clear_cache()
	var start_usec: int = Time.get_ticks_usec()
	for path: String in shaders:
		EventForgeShaderUniforms.for_shader(path)
	var cold_ms: float = float(Time.get_ticks_usec() - start_usec) / 1000.0
	start_usec = Time.get_ticks_usec()
	for path: String in shaders:
		EventForgeShaderUniforms.for_shader(path)
	var warm_ms: float = float(Time.get_ticks_usec() - start_usec) / 1000.0
	var dials: Array[Dictionary] = EventForgeShaderUniforms.for_shader(shaders[0])
	var passed: bool = _check("a fixture shader really declares dials (%d)" % dials.size(),
		dials.size() > 4, true)
	passed = _check("the dials of a shader are held and handed out by reference",
		is_same(dials, EventForgeShaderUniforms.for_shader(shaders[0])), true) and passed
	passed = _check("%d shaders parse from cold under %d ms (took %.1f ms)" % [
		shaders.size(), SHADER_CORPUS_BUDGET_MS, cold_ms],
		cold_ms <= float(SHADER_CORPUS_BUDGET_MS), true) and passed
	return _check("%d shaders answer again under %d ms (took %.1f ms)" % [
		shaders.size(), SHADER_CORPUS_WARM_BUDGET_MS, warm_ms],
		warm_ms <= float(SHADER_CORPUS_WARM_BUDGET_MS), true) and passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] huge_project_budget_test: %s" % label)
		return true
	print("[FAIL] huge_project_budget_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
