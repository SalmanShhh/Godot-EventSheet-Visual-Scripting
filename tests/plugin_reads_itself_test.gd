# EventForge - W22, the dogfood gate: the editor reads ITSELF, measured and pinned.
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
# CEILINGS ARE MEASURED, THEN RATCHETED, NEVER GUESSED. Every number below was read off the tree it
# was written on (the probe that produced them is the same `EventSheetGenericRows.measure` the Doctor
# and the bar use). They are set just above what the worst file in each group scores today, so any
# file getting WORSE fails, and the honest way to move one is to lower it after the work that earns it.
@tool
class_name PluginReadsItselfTest
extends RefCounted

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
##   plugin 2 · workspace 29 · canvas 10 · readings 11 · importer 8 · compiler 0
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
	"importer": 12,
	"compiler": 5,
	"vocabulary": 65,
	"manual": 21,
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

## The two files under addons/ and tools/ that still put lines in a script block, with the count each
## one has today. Everything else in the editor's own source reaches zero.
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
	return all_passed


## THE W1 GATE ITSELF: both marks, or nothing. A game that installed the plugin has the descriptor
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
		if str(SheetCompiler.compile(sheet, "user://_plugin_reads_itself.gd").get("output", "")) != source \
				and not path in KNOWN_DRIFT:
			drifted.append(path)
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
	if actual == expected:
		print("[PASS] plugin_reads_itself_test: %s" % label)
		return true
	print("[FAIL] plugin_reads_itself_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
