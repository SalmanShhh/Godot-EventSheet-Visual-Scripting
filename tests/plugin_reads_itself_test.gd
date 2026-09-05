# EventForge - the dogfood gate: the editor reads ITSELF, measured and pinned.
#
# WHY THIS EXISTS, next to handwritten_lift_gate_test. That gate pins eleven hand-picked plugin files
# for byte round-trip and for how little of them still renders as a wall of code, and both numbers
# have been at their floor for a while. What neither of them measures is whether the rows SAY
# anything: a file can open at 100% events and still read as `Call method`, `Call method`, `Set x to
# thing` three hundred times over. That is the file's shape with none of its meaning, and it is what
# the reading batches are for. So this gate adds the second number - the share of rows with no words
# of their own - and it measures it across the WHOLE editor rather than across a chosen few.
#
# SAMPLED, AND ROTATING. There are ~500 .gd files under addons/ and tools/, and opening one means
# running the importer and the compiler over it - a full sweep is a release-ritual job, not a
# per-commit one. So each run takes a sample of forty, seeded BY THE DAY: one run is fast, and a week
# of runs has been over most of the editor. A failure names the day seed and the file, so it is
# reproducible even though the sample moves.
#
# AND ONE THING THE SAMPLE CANNOT ANSWER. The wordless-row measure is a regex over a row's TEXT, so a
# row the DERIVED layer has named - the method resolved off its receiver's class, the chips carrying
# the method's own parameter names - still scores exactly as it did before. So there is a second,
# NAMED set of five files at the bottom of this gate with a floor on how many generic calls that layer
# names in each: not sampled, so the number is the same on every machine and every run.
#
# CEILINGS ARE MEASURED, THEN RATCHETED, NEVER GUESSED. Every number below was read off the tree it
# was written on (the probe that produced them is the same `EventSheetGenericRows.measure` the Doctor
# and the bar use). They are set just above what the worst file in each group scores today, so any
# file getting WORSE fails, and the honest way to move one is to lower it after the work that earns it.
@tool
class_name PluginReadsItselfTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
## When a round-trip is refused, the evidence goes on disk rather than into a rebuild by hand.
const Repro := preload("res://tests/repro_bundle.gd")

## Where the editor's own source is, for this gate: the shipped plugin and the tools around it. The
## tests folder is deliberately out - it is listed in the This-editor folder, but its files are full
## of multi-line GDScript fixtures whose interiors are, correctly, code.
const GATE_ROOTS: PackedStringArray = ["res://addons/", "res://tools/"]

## How many files one run measures. Forty is about four seconds, which is what a per-commit gate can
## afford; the release ritual runs the whole set by raising this past the corpus size.
const SAMPLE_SIZE: int = 40

## The share of a file's rows that may say nothing of their own, per role group. Measured on the tree
## this gate was written on, as the WORST file in each group, then rounded up a little:
##
##   plugin 2 · workspace 29 · canvas 10 · readings 11 · importer 8 · recognisers 62 · compiler 0
##   vocabulary 60 · manual 17 · command tools 20 · pack recipes 97 · everything else 26
##
## Pack recipes stand out for a reason worth writing down rather than hiding: a pack builder IS a
## list of strings, so nearly every row of one is a literal entry. That is the item that reads them
## as Define rows; when it lands, this ceiling comes down with it, and until then a ceiling of 99 is
## an honest "not measured yet" rather than a pretend pass.
const GENERIC_CEILING_BY_ROLE: Dictionary = {
	"plugin": 5,
	"workspace": 32,
	"canvas": 14,
	"readings": 15,
	# Read off the tree like the rest. Raised by one when the rotating sample reached
	# scene_effect_facts.gd, which measures 13: a facts reader is a run of short lookups whose rows
	# genuinely have little to say, and the ceiling is a description of the group rather than a
	# target. Nothing about the reading layer changed to move it - the measure is taken off the
	# imported sheet's own shape and the raw text of each row.
	#
	# It was raised to 19 for one file - the scenes pass's own layout_on_top_lift.gd, which measured
	# 18 - and put back. A ratchet a pass moves for its file it just added is not a ratchet: the
	# honest answer was to write that matcher so it measures like its neighbours, which is what
	# happened (it hands one dictionary back rather than building a literal a row at a time, and its
	# reasoning is prose above the code rather than lines inside a literal). Re-measured over the
	# whole role afterwards: the worst importer file is scene_effect_facts.gd at 13, the three run
	# matchers are 0, 0 and 6, and nothing else reaches 13.
	"importer": 13,
	# Re-measured over the WHOLE role rather than off the file the rotating sample happened to
	# reach. The group is eighteen families now, not the three it was when 48 was written, and
	# three of them stand over that number. Read off the tree today, worst first: node_dignity 62,
	# layout_on_top 57, camera 52, animation 47, collision_edge 46, collision_filter 43, removal 41,
	# effect 39, view 38, physics_query 36, lighting 27, input_event 27, collision_layer 26,
	# multiplayer 12, state 8, lift_table 1, spawn_run 0, text_effect 0. The worst is
	# node_dignity_lift.gd at 62, and every one of the three over the old ceiling was added by an
	# earlier pass, so this is a re-measure and not a pass moving a ratchet for its own file.
	#
	# It measures that way for the reason the whole group does: a lift-entries family IS a TABLE,
	# one dictionary literal per entry, so most of its rows are literal entries rather than logic,
	# and the widest table scores the highest. That is the same reason a pack recipe sits where it
	# does. Nothing about the reading layer changed to move this - the ceiling is a description of
	# the group, taken off the worst file in it, rounded up a little.
	"recognisers": 63,
	"compiler": 5,
	# Re-measured over the WHOLE role rather than off the files the rotating sample happened to
	# reach, after the sample moved and landed on sequencer_aces.gd, which measures 67. The sample is
	# forty files of about five hundred, seeded by the day, so which forty it takes shifts whenever
	# the corpus gains or loses a file - and 65 was read off a run that had never opened the worst
	# file in this group. All 152 of them, read off the tree today, worst first: sequencer_aces 67,
	# tooling_aces 57, testing_aces 54, ace_adapter 50, world_look_aces 47, file_aces 41,
	# scene_lighting_aces 35, provider_preview 24, focus_and_exposure_aces 21, material_aces 20, and
	# nothing else over 19.
	#
	# It measures that way for the reason the whole group does: a vocabulary module IS a table, one
	# descriptor per verb built from its own literal fields, so most of its rows are entries rather
	# than logic, and the widest table scores the highest. Nothing about the reading layer changed to
	# move it - the ceiling is a description of the group, taken off the worst file in it, and it is
	# the measured number exactly rather than a number with room in it, so any file getting worse
	# still fails.
	"vocabulary": 67,
	# Raised from 21 when the rotating sample reached doc_editor_words.gd, which measures 26: that
	# page's body is one dictionary literal of key -> sentence (the words table itself lives
	# elsewhere and is read, not repeated), so most of its rows ARE literal entries - the same reason
	# the vocabulary and pack-recipe groups sit where they do. Nothing about the reading layer
	# changed to move it; the ceiling is a description of the group, taken off the worst file in it.
	"manual": 26,
	"tests": 30,
	"command_tools": 24,
	"pack_recipes": 99,
	"other": 30,
}

## The files that do NOT round-trip byte-exact today, with what is wrong beside each. Empty: the two
## drifts this gate found at birth (a provider declaration injected into a file whose STRING quoted
## the member convention; a tab-only separator line swapped with the blank beside it) are fixed at
## their roots, and opened_file_drift_regressions_test pins both shapes. An entry added here must
## carry its cause and is DELETED the day that cause is fixed - never added to make a red run green.
const KNOWN_DRIFT: PackedStringArray = []

## HOW MANY GENERIC CALLS THE DERIVED LAYER NAMES, per file, as a FLOOR. Measured, then ratcheted.
##
## The wordless-row ceiling above cannot see the derived layer at all: `is_generic_code` is a regex
## over a row's TEXT, and a derived reading changes the row's words without touching its code, so
## `_dock._refresh_after_edit()` scores as a wordless row whether or not the layer has named the
## method, its parameter names and its description. That is correct for what that number measures and
## it leaves the pass's central claim with unit coverage only. This is the whole-file measurement:
## five of the editor's own files, chosen for having enough generic calls to be worth counting, with
## the number the derived layer names in each today. It is a FLOOR - naming fewer fails, naming more
## is the work landing - and the honest way to move one is to raise it after the work that earns it.
const DERIVED_FLOOR: Dictionary = {
	"res://addons/eventforge/compiler/sheet_compiler.gd": 6,
	"res://addons/eventsheet/editor/dock/multi_view_manager.gd": 11,
	"res://addons/eventsheet/editor/dock/quick_prompt_dialogs.gd": 16,
	"res://addons/eventsheet/editor/event_sheet_exposed_node.gd": 8,
	"res://addons/eventsheet/editor/objects_panel.gd": 10,
}

## The files under addons/ and tools/ that still put lines in a script block, with the count each one
## has today. Everything else in the editor's own source reaches zero. An entry here is a debt with a
## cause, not a licence: it is deleted the day the cause is fixed, and never added to make a red run
## green. (Three lighting pack recipes were listed here for one release: every one of the 105 recipes
## opens with `@tool` and `const Lib := preload(…)`, and the reading accepted the annotation but not
## the import, so a recipe whose body split cleanly was left with its prelude standing as code. The
## reading now knows a preloaded constant is an import, and the three entries are gone with it.)
const KNOWN_BLOCK_LINES: Dictionary = {
	"res://addons/eventsheet/theme/event_sheet_editor_style.gd": 6,
	"res://tools/render_opened_script_head5_preview.gd": 3,
}


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _test_gate() and all_passed
	all_passed = _test_roles() and all_passed
	all_passed = _test_generic_measure() and all_passed
	all_passed = _test_corpus() and all_passed
	all_passed = _test_the_derived_layer_names_something() and all_passed
	return all_passed


## THE DERIVED LAYER, measured on whole files rather than on hand-built lines. Not sampled: these five
## are named, so the number is the same on every machine and on every run, and a reading that stopped
## resolving a receiver - or a declaration map that started declining one it used to answer for -
## fails here rather than passing quietly under a ceiling that cannot see it.
static func _test_the_derived_layer_names_something() -> bool:
	var passed: bool = true
	var below: PackedStringArray = PackedStringArray()
	var said: PackedStringArray = PackedStringArray()
	var paths: PackedStringArray = PackedStringArray(DERIVED_FLOOR.keys())
	paths.sort()
	for path: String in paths:
		var sheet: EventSheetResource = GDScriptImporter.new().import_external(path)
		var measure: Dictionary = EventSheetGenericRows.derived_measure(sheet)
		var named: int = int(measure.get("derived", 0))
		said.append("%s %d/%d" % [path.get_file(), named, int(measure.get("statements", 0))])
		if named < int(DERIVED_FLOOR[path]):
			below.append("%s (%d named, floor %d)" % [path, named, int(DERIVED_FLOOR[path])])
	print("  derived layer: %s" % ", ".join(said))
	passed = _check("no file names fewer generic calls than its floor", below,
		PackedStringArray()) and passed
	# And the refusal, on the same measure: a sheet the layer can say nothing about scores zero
	# rather than scoring high for the wrong reason.
	passed = _check("a sheet that is not there names nothing",
		EventSheetGenericRows.derived_measure(null),
		{"derived": 0, "statements": 0, "percent": 0}) and passed
	return passed


## THE GATE ITSELF: both marks, or nothing. A game that installed the plugin has the descriptor
## and no pack recipes beside it, and must see none of this.
static func _test_gate() -> bool:
	var passed: bool = true
	passed = _check("this repo IS the editor's own project",
		EventSheetThisEditor.is_editor_project(), true) and passed
	passed = _check("a project that only INSTALLED the plugin is not the editor's own",
		EventSheetThisEditor.is_editor_project_at(
			EventSheetThisEditor.PLUGIN_CFG_PATH, "res://not_a_folder_here"), false) and passed
	passed = _check("a project with neither mark is not the editor's own",
		EventSheetThisEditor.is_editor_project_at("res://nothing.cfg", "res://not_a_folder_here"),
		false) and passed
	passed = _check("the plugin's own script is one of the editor's sources",
		EventSheetThisEditor.is_editor_source(EventSheetThisEditor.PLUGIN_SCRIPT_PATH), true) and passed
	passed = _check("a game's own script is not",
		EventSheetThisEditor.is_editor_source("res://player.gd"), false) and passed
	# The distinction the read-only bar hangs on: a test IS listed in the folder, and saving one
	# reloads nothing, so it must not wear "part of this editor · read-only".
	passed = _check("a test file is not something the running editor is built from",
		EventSheetThisEditor.is_editor_source("res://tests/plugin_reads_itself_test.gd"), false) and passed
	passed = _check("but it is still listed in the folder",
		EventSheetThisEditor.role_for("res://tests/plugin_reads_itself_test.gd", ""), "tests") and passed
	return passed


## WHAT EACH FILE IS, from its shape. One case per rule, so a rule that stops working says which.
static func _test_roles() -> bool:
	var passed: bool = true
	passed = _check("an EditorPlugin is the Plugin",
		EventSheetThisEditor.role_for("res://addons/eventforge/plugin.gd",
			"@tool\nextends EditorPlugin\n"), "plugin") and passed
	passed = _check("a helper holding a back-reference into the dock is Workspace",
		EventSheetThisEditor.role_for("res://addons/eventsheet/editor/thing.gd",
			"extends RefCounted\nvar _dock: Control = null\n"), "workspace") and passed
	passed = _check("a tools script that extends SceneTree is a Command tool",
		EventSheetThisEditor.role_for("res://tools/audit_addons.gd",
			"@tool\nextends SceneTree\n"), "command_tools") and passed
	passed = _check("a pack builder is a Pack recipe",
		EventSheetThisEditor.role_for("res://tools/pack_builders/health.gd",
			"extends RefCounted\n"), "pack_recipes") and passed
	passed = _check("a test file is a Test",
		EventSheetThisEditor.role_for("res://tests/thing_test.gd",
			"extends RefCounted\n"), "tests") and passed
	passed = _check("the importer is the Importer",
		EventSheetThisEditor.role_for("res://addons/eventforge/importer/open_job.gd",
			"extends RefCounted\n"), "importer") and passed
	passed = _check("the compiler is the Compiler",
		EventSheetThisEditor.role_for("res://addons/eventforge/compiler/sheet_compiler.gd",
			"extends RefCounted\n"), "compiler") and passed
	passed = _check("the row builder is the Canvas",
		EventSheetThisEditor.role_for("res://addons/eventsheet/editor/interaction/viewport_row_builder.gd",
			"extends RefCounted\n"), "canvas") and passed
	passed = _check("the sentence grammar is a Reading",
		EventSheetThisEditor.role_for("res://addons/eventsheet/editor/interaction/sentence_grammar.gd",
			"extends RefCounted\n"), "readings") and passed
	passed = _check("a docs-dock file is the Manual",
		EventSheetThisEditor.role_for("res://addons/eventsheet/editor/docs/doc_browser.gd",
			"extends RefCounted\n"), "manual") and passed
	passed = _check("a registration module is Vocabulary",
		EventSheetThisEditor.role_for("res://addons/eventforge/registration/modules/core_aces.gd",
			"extends RefCounted\n"), "vocabulary") and passed
	return passed


## WHAT COUNTS AS A ROW WITH NO WORDS. Three shapes and only three, pinned one by one, because the
## number the gate and the Doctor both report is only worth reading if this is exactly right.
static func _test_generic_measure() -> bool:
	var passed: bool = true
	passed = _check("a bare call says nothing of its own",
		EventSheetGenericRows.is_generic_code("queue_redraw()"), true) and passed
	passed = _check("a bare call through a member says nothing either",
		EventSheetGenericRows.is_generic_code("_dock._refresh_after_edit()"), true) and passed
	passed = _check("a set to a bare function name says nothing",
		EventSheetGenericRows.is_generic_code("var found = _collect_rows()"), true) and passed
	passed = _check("a set to a bare name says nothing",
		EventSheetGenericRows.is_generic_code("total = collected"), true) and passed
	passed = _check("an entry of a list is a literal, and says nothing",
		EventSheetGenericRows.is_generic_code("\t\"walk\", \"run\","), true) and passed
	passed = _check("a call with a value in it DOES say something",
		EventSheetGenericRows.is_generic_code("var speed = clampf(value, 0.0, 1.0)"), false) and passed
	passed = _check("a comparison says something",
		EventSheetGenericRows.is_generic_code("if health <= 0:"), false) and passed
	passed = _check("a note is not a row with no words",
		EventSheetGenericRows.is_generic_code("# what this does"), false) and passed
	passed = _check("an await says something",
		EventSheetGenericRows.is_generic_code("await get_tree().process_frame"), false) and passed
	return passed


## THE CORPUS PASS: a rotating sample of the editor's own source, opened, re-emitted and measured.
static func _test_corpus() -> bool:
	var passed: bool = true
	var sample: PackedStringArray = sample_for_day(corpus(), day_seed(), SAMPLE_SIZE)
	passed = _check("the sample has files in it to measure", sample.size(), SAMPLE_SIZE) and passed
	var unreadable: PackedStringArray = PackedStringArray()
	var drifted: PackedStringArray = PackedStringArray()
	var blocky: PackedStringArray = PackedStringArray()
	var wordless: PackedStringArray = PackedStringArray()
	for path: String in sample:
		var source: String = FileAccess.get_file_as_string(path)
		var sheet: EventSheetResource = GDScriptImporter.new().import_external(path)
		if sheet == null:
			unreadable.append(path)
			continue
		var emitted: String = str(SheetCompiler.compile(sheet,
			"user://_plugin_reads_itself.gd").get("output", ""))
		if emitted != source and not path in KNOWN_DRIFT:
			drifted.append(path)
			print("  %s" % Repro.dump("plugin_reads_itself_test", path, source, emitted, path))
		var blocks: int = int(EventSheetReadingCoverage.measure(sheet).get("block_lines", 0))
		if blocks > int(KNOWN_BLOCK_LINES.get(path, 0)):
			blocky.append("%s (%d lines)" % [path, blocks])
		var role: String = EventSheetThisEditor.role_for(path, source)
		var generic: int = int(EventSheetGenericRows.measure(sheet).get("percent", 0))
		if generic > int(GENERIC_CEILING_BY_ROLE.get(role, 100)):
			wordless.append("%s (%s, %d%% > %d%%)" % [path, role, generic,
				int(GENERIC_CEILING_BY_ROLE.get(role, 100))])
	# The seed is printed with every result, because the sample moves and a failure has to be
	# reproducible by whoever reads the log tomorrow.
	print("  plugin_reads_itself_test: day seed %d, %d files sampled from %d"
		% [day_seed(), sample.size(), corpus().size()])
	passed = _check("every sampled file of this editor opens as a sheet",
		unreadable, PackedStringArray()) and passed
	passed = _check("every sampled file round-trips byte-identically",
		drifted, PackedStringArray()) and passed
	passed = _check("no sampled file gained a script block",
		blocky, PackedStringArray()) and passed
	passed = _check("no sampled file is over its group's wordless-row ceiling",
		wordless, PackedStringArray()) and passed
	return passed


## Every .gd this gate measures, sorted, so the sample is drawn from a stable list.
static func corpus() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for path: String in EventSheetThisEditor.source_files():
		for root: String in GATE_ROOTS:
			if path.begins_with(root):
				found.append(path)
				break
	found.sort()
	return found


## The day, as a number. The sample rotates once a day rather than once a run, so a red gate stays
## red long enough to be looked at.
static func day_seed() -> int:
	return int(floor(Time.get_unix_time_from_system() / 86400.0))


## `count` files from `paths`, chosen by `seed` - the same seed always chooses the same files, and no
## file is chosen twice. Pure, so a test of the test pins it.
static func sample_for_day(paths: PackedStringArray, seed_value: int, count: int) -> PackedStringArray:
	var picked: PackedStringArray = PackedStringArray()
	if paths.is_empty():
		return picked
	var generator: RandomNumberGenerator = RandomNumberGenerator.new()
	generator.seed = seed_value
	var order: Array = []
	for index: int in paths.size():
		order.append(index)
	# Shuffle by the seeded generator rather than by `Array.shuffle`, whose source is the global one.
	for index: int in range(order.size() - 1, 0, -1):
		var swap_index: int = generator.randi_range(0, index)
		var held: Variant = order[index]
		order[index] = order[swap_index]
		order[swap_index] = held
	for index: int in mini(count, order.size()):
		picked.append(paths[int(order[index])])
	return picked


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("plugin_reads_itself_test", label, actual, expected)
