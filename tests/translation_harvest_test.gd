# Godot EventSheets - the translation harvest has nothing left to do.
#
# Three gates already NAME the CSV row a wave forgot; tools/harvest_translations.gd is the tool that
# WRITES it. This test runs that tool in dry run and fails when it would write anything, so the two
# halves can never disagree: a key the harvest thinks is owed and no CSV carries is a red run here,
# printed as the rows themselves rather than as a count.
#
# WHY IT IS NOT THE SAME TEST TWICE. The other gates read the CSVs and the sources separately, each
# in its own spelling of "what a key is". This one asks the writer, in the writer's own words, and
# so catches the failure the others cannot see: a harvest that would MOVE a byte of a generated
# file. Nine hand-maintained CSVs are only derivable while running the deriver is a no-op.
#
# THE CONTROL WALK IS NOT SWEPT HERE. It needs a live dock under a SceneTree and the suite has no
# main loop, and it is advisory in any case - it never appends. The two owed sources are the two
# that can write a row, so they are the two this gate holds.
@tool
class_name TranslationHarvestTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const HARVEST := preload("res://tools/harvest_translations.gd")


static func run() -> bool:
	var ok: bool = _test_the_sources_are_alive()
	ok = _test_a_verbatim_literal_keeps_its_spaces() and ok
	ok = _test_the_harvest_has_nothing_to_write() and ok
	ok = _test_no_key_is_listed_twice() and ok
	ok = _test_no_kept_row_names_a_retired_option() and ok
	return ok


## A source that answered nothing would make the gate below pass for the wrong reason.
static func _test_the_sources_are_alive() -> bool:
	var ok: bool = _check("the editor literals are read", HARVEST.editor_literals().keys.size() > 300, true)
	return _check("the owed vocabulary is read", HARVEST.owed_vocabulary().keys.size() > 300, true) and ok


## Four shipped rows begin with a space, because the sentence they tail onto supplies the one before
## them. A harvest that trimmed a literal would append a second, spaceless spelling of a row already
## translated in eight languages - so the leading space is pinned here rather than left to be
## rediscovered.
static func _test_a_verbatim_literal_keeps_its_spaces() -> bool:
	var carried: Dictionary = {}
	for key: String in HARVEST.editor_literals().keys:
		carried[key] = true
	return _check("a literal that starts with a space is that key",
		carried.has(" %d sheet(s) that include this one are rewritten and SAVED, which one Ctrl+Z here does not undo."), true)


## The whole point: running the harvest on this tree changes nothing.
static func _test_the_harvest_has_nothing_to_write() -> bool:
	var plan: HARVEST.Plan = HARVEST.plan([HARVEST.editor_literals(), HARVEST.owed_vocabulary()])
	if not plan.append.is_empty():
		print("  the harvest would append %d row(s) to all nine CSVs:" % plan.append.size())
		for key: String in plan.append:
			print("    %s" % key)
		print("  run: \"$GODOT\" --headless --path . --script tools/harvest_translations.gd")
	return _check("the harvest would write nothing", plan.append, PackedStringArray())


## Two harvests that meet in a merge can each append the same key. The second row is dead weight
## whose value drifts from the first one's, and only the later of the two is ever read.
static func _test_no_key_is_listed_twice() -> bool:
	var doubled: PackedStringArray = PackedStringArray()
	for file_name: String in DirAccess.get_files_at("res://addons/eventsheet/translations"):
		if file_name.get_extension() != "csv":
			continue
		var file: FileAccess = FileAccess.open("res://addons/eventsheet/translations".path_join(file_name), FileAccess.READ)
		var seen: Dictionary = {}
		while not file.eof_reached():
			var row: PackedStringArray = file.get_csv_line()
			if row.is_empty() or row[0].is_empty():
				continue
			if seen.has(row[0]):
				doubled.append("%s: %s" % [file_name, row[0]])
			seen[row[0]] = true
	return _check("no catalog lists a key twice", doubled, PackedStringArray())


## The harvest never deletes, so a row whose source sentence was reworded stays in all nine files,
## still telling a translator about a menu option the editor no longer has. The two options the
## Save choice replaced are the ones a reworded sentence is most likely to leave behind.
static func _test_no_kept_row_names_a_retired_option() -> bool:
	var plan: HARVEST.Plan = HARVEST.plan([HARVEST.editor_literals(), HARVEST.owed_vocabulary()])
	var stale: PackedStringArray = PackedStringArray()
	for key: String in plan.kept_by_hand:
		if key.contains("Remember Between Runs") or key.contains("Add Save Support"):
			stale.append(key)
	return _check("no row kept by hand names Remember Between Runs or Add Save Support", stale, PackedStringArray())


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("translation_harvest_test", label, actual, expected)
