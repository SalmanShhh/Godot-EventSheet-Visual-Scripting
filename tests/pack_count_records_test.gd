# Godot EventSheets - the pack count README.md and CLAUDE.md quote must be the count the tree has.
#
# Those files state the number of shipped behaviour packs as a hand-typed literal in four sentences.
# Nothing derived it, so it drifted every time a pack landed. This test measures the tree with
# tools/measure_packs.gd - THE SAME static function the tool prints from, never a second walk of its
# own - and fails with both numbers and the one line that fixes them.
#
# The measurement itself is pinned by VALUE against tests/fixtures/pack_count_builders/, a four-file
# stand-in for the builders folder holding one of each shape: a folder pack published through
# Lib.publish, a folder pack published through Lib.save_pack, a root runtime script with no folder,
# and a builder that ships nothing. Pinning against the live tree instead would pin a number that
# moves every day, which is the exact failure this file exists to end.
@tool
class_name PackCountRecordsTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const MEASURE := preload("res://tools/measure_packs.gd")
const PREFIX := "pack_count_records_test"

## The stand-in builders folder the walk is pinned against. Two of its four builders publish a pack
## folder; see the header for what the other two are there to prove.
const FIXTURE_BUILDERS := "res://tests/fixtures/pack_count_builders/"


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _pin_the_walk() and all_passed
	all_passed = _pin_the_records() and all_passed
	return all_passed


## The measurement, by value, on the fixture folder. Folder NAMES are pinned rather than a count, so
## a walk that lost one pack and gained another (or started counting the root runtime script) is a
## failure that names what it counted instead of a bare number that happens to match.
static func _pin_the_walk() -> bool:
	var folders: PackedStringArray = MEASURE.pack_folders(FIXTURE_BUILDERS)
	return SUPPORT.pins(PREFIX, [
		["fixture folders published", ",".join(folders), "fixture_alpha_pack,fixture_beta"],
		["fixture pack count", folders.size(), 2],
		["fixture publishing builders", MEASURE.publishing_builders(FIXTURE_BUILDERS), 2],
		# The root-runtime builder ships to res://eventsheet_addons/fixture_root_runtime with no
		# folder after it. If the pattern ever stopped requiring the trailing slash, this name would
		# appear in the list above; naming it here says WHY the row above reads the way it does.
		["root runtime script is not a pack", folders.has("fixture_root_runtime"), false],
	])


## Every pack-count sentence in README.md and CLAUDE.md against the live measurement.
static func _pin_the_records() -> bool:
	var measured: int = MEASURE.pack_folders(MEASURE.BUILDERS_DIR).size()
	var rows: Array = [
		# A tree with no packs at all means the walk broke, not that the records are right.
		["the tree ships at least one pack", measured > 0, true],
	]
	for path: String in MEASURE.RECORD_FILES:
		var quoted: PackedInt32Array = MEASURE.record_counts(path)
		rows.append(["%s quotes the pack count somewhere" % path, quoted.size() > 0, true])
		for index: int in range(quoted.size()):
			rows.append(["%s pack-count sentence %d" % [path, index + 1], quoted[index], measured])
	var all_passed: bool = SUPPORT.pins(PREFIX, rows)
	if not all_passed:
		print("  pack count: the tree ships %d packs; rewrite the records with:" % measured)
		print("  %s" % MEASURE.FIX_LINE)
	return all_passed
