# Godot EventSheets - THE CORPUS: whole files a real Godot developer would plausibly have written.
#
# Every other lift test builds the fixture it needs. A fixture written to suit the lifter cannot
# notice that real code does not look like it, which is exactly how 88.1% of hand-written lines once
# ended up in verbatim blocks with the whole suite green. The hand-written gate answered half of that
# by opening the plugin's OWN source; this answers the other half, with files that are nobody's
# source: ordinary game code, in the shapes tutorials and engine docs spell them, written to be
# opened rather than to be maintained.
#
# res://tests/corpus/ holds eight of them today:
#   player_controller.gd   the first script every project has - a character body, input, a jump
#   door_state_machine.gd  an enum and one match block, which is how hand-written FSMs are spelled
#   network_lobby.gd       an autoload that hosts, joins and sends, in the engine's own spellings
#   pickup_juice.gd        tweens, a particle burst and a camera shake - the pile of small touches
#   pause_menu.gd          an input handler that asks the event, buttons wired with bound values,
#                          and the engine's own pause notifications - the three shapes a menu is
#   player_stats.gd        properties in both of Godot's spellings: two that name the functions that
#                          guard them, one that writes its accessor inline
#   guard_sight.gd         the three questions a project puts to the physics world directly: the ray
#                          in the three statements the manual prints, the same ray written compactly
#                          on one line, and the shape and point queries that stay code
#   mission_hud.gd         two multi-line text templates and the labels they fill - the file the
#                          LEDGER is measured on, because it is the one with lines nothing claims
#
# WHAT IS PINNED, AND WHY IT IS PINNED AS VALUES:
#
#   1. IT COMPILES, asked of every file before anything else is asked of it. Nothing else in this
#      gate needs it to - a reading opens text and a re-emission writes text back - so a file naming
#      a member its own base class does not have passed every pin below while being a file the
#      engine refuses to load, which is the one thing these files must never be.
#   2. BYTE-EXACT round-trip on every file. Open it as a sheet, save it untouched, get the same
#      bytes. This is the lossless contract measured on whole real files, and it never relaxes.
#   3. Per file, the reading as three NUMBERS: the share that reads as rows, how many lines a
#      lift-table entry claims by name, and how many stay honest code. Counts, not tolerances -
#      moving one means editing this file, which is the point. A coverage change becomes a
#      deliberate, visible diff instead of a floor quietly absorbing it.
#   4. THE LEDGER over the whole corpus, as values. The Doctor's Reading page and
#      tools/reading_shape_census.gd are both built on one census, and until a corpus file had
#      repeated shapes in it that census had no whole-file coverage at all: the ranking, the one-off
#      tail and the notes counter could all have gone wrong without moving a single pin. Now the
#      ranked shape, its count, the tail and the notes are pinned as the numbers they are - and the
#      notes number is the one that says the inside of a text block is not being shaped as code.
#
# THE RULE FOR ADDING TO IT: a new family adds the file that motivated it - the real code that made
# somebody write the recogniser, not a line distilled out of it. Pins move UP, and the commit that
# moves one states the delta ("network_lobby: entry lines 5 -> 8, the three join spellings").
# A pin that moves DOWN is a regression until the commit message says otherwise.
#
# The `reading` residue (lines that arrived as rows without a table entry naming them) is PRINTED
# rather than pinned: it is whatever is left over, so pinning it would fail this gate on cosmetic
# renames in the general reverse index while telling nobody anything about coverage.
@tool
class_name CorpusTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
## Where the corpus lives. Walked and SORTED rather than listed, so a file added to the folder is
## measured the moment it exists, and the order is the same on every machine.
const CORPUS_DIR: String = "res://tests/corpus/"

## The reading of each file, as values. `percent` is the share that reads as rows,
## `entry` the lines a lift-table entry claims by name, `code` the lines that stay a script block.
const PINS: Dictionary = {
	"door_state_machine.gd": {"percent": 100, "entry": 0, "code": 1},
	"guard_sight.gd": {"percent": 100, "entry": 4, "code": 0},
	"mission_hud.gd": {"percent": 100, "entry": 0, "code": 8},
	"network_lobby.gd": {"percent": 100, "entry": 5, "code": 0},
	"pause_menu.gd": {"percent": 100, "entry": 4, "code": 0},
	"pickup_juice.gd": {"percent": 100, "entry": 0, "code": 1},
	"player_controller.gd": {"percent": 100, "entry": 0, "code": 0},
	"player_stats.gd": {"percent": 100, "entry": 0, "code": 0}
}


static func run() -> bool:
	var all_passed: bool = true
	var files: PackedStringArray = _corpus_files()
	# A renamed or moved file would make every pin below pass vacuously.
	var names: PackedStringArray = PackedStringArray()
	for path: String in files:
		names.append(path.get_file())
	var expected_names: PackedStringArray = PackedStringArray(PINS.keys())
	expected_names.sort()
	all_passed = _check("the corpus is the files this gate pins", names, expected_names) and all_passed
	for path: String in files:
		var name: String = path.get_file()
		if not PINS.has(name):
			continue
		var pins: Dictionary = PINS[name]
		# THE FILE HAS TO COMPILE, and it is asked before anything else is asked of it. Nothing below
		# needs it to: a reading opens the text, a re-emission writes the text back, and a file naming
		# a member its own base class does not have passes every pin here while being a file the
		# engine refuses to load. That is the one thing this corpus must not be - these are scripts a
		# real developer would plausibly have written, and one that cannot run is not one of those.
		# The engine's own loader answers, so the verdict here is the verdict the game would get.
		all_passed = _check("%s compiles" % name, ResourceLoader.load(path, "GDScript") != null,
			true) and all_passed
		var source: String = FileAccess.get_file_as_string(path)
		var reading: Dictionary = EventSheetLiftReading.read(source, path)
		var counts: Dictionary = EventSheetLiftReading.layer_counts(reading)
		print("[corpus] %s: %d%% reads as rows, entry=%d reading=%d code=%d" % [name,
			EventSheetLiftReading.percent(reading),
			int(counts[EventSheetLiftReading.LAYER_ENTRY]),
			int(counts[EventSheetLiftReading.LAYER_READING]),
			int(counts[EventSheetLiftReading.LAYER_CODE])])
		var identical: bool = bool(reading.get("identical", false))
		if not identical:
			# The exact two lines, because a trailing space is the whole bug.
			print("  first difference: %s" % str(reading.get("diff", {})))
		all_passed = _check("%s saves back byte-identically" % name, identical, true) and all_passed
		all_passed = _check("%s reads as rows (pinned %d%%)" % [name, int(pins["percent"])],
			EventSheetLiftReading.percent(reading), int(pins["percent"])) and all_passed
		all_passed = _check("%s lines claimed by a lift entry (pinned %d)" % [name, int(pins["entry"])],
			int(counts[EventSheetLiftReading.LAYER_ENTRY]), int(pins["entry"])) and all_passed
		all_passed = _check("%s lines that stay code (pinned %d)" % [name, int(pins["code"])],
			int(counts[EventSheetLiftReading.LAYER_CODE]), int(pins["code"])) and all_passed
	return _test_the_ledger(files) and all_passed


## The census over the WHOLE corpus, as values. Everything the Doctor's Reading page and the census
## tool are built on runs here on real whole files rather than on a hand-built list of lines: which
## shape is said more than once and how often, how many lines nothing else repeats, and how many hold
## no statement to shape at all.
##
## The notes number is the load-bearing one. Six of them are the inside of the two text templates in
## mission_hud.gd - prose, not statements - and a walk that shaped those as code would rank a printf
## placeholder as a node path and move this pin.
static func _test_the_ledger(files: PackedStringArray) -> bool:
	var lines: Array = []
	for path: String in files:
		var reading: Dictionary = EventSheetLiftReading.read(FileAccess.get_file_as_string(path), path)
		lines.append_array(EventSheetReadingShapes.stays_code_lines(reading, path))
	var census: Dictionary = EventSheetReadingShapes.census(lines)
	var ranked: PackedStringArray = PackedStringArray()
	for entry: Variant in census.get("shapes", []) as Array:
		ranked.append("%s x%d" % [str((entry as Dictionary).get("shape", "")),
			int((entry as Dictionary).get("count", 0))])
	print("[corpus] ledger: %s | one-offs=%d notes=%d" % [", ".join(ranked),
		(census.get("one_offs", []) as Array).size(), int(census.get("notes", 0))])
	var ok: bool = _check("the corpus ledger ranks the shape it repeats", ranked,
		PackedStringArray(["const name:name=text x2"]))
	ok = _check("and counts the shapes nothing else repeats",
		(census.get("one_offs", []) as Array).size(), 2) and ok
	ok = _check("and the lines that hold no statement to shape",
		int(census.get("notes", 0)), 6) and ok
	ok = _check("which is every stays-code line of the corpus, accounted for",
		int(census.get("lines", 0)), 10) and ok
	return ok


## Every .gd in the corpus folder, sorted.
static func _corpus_files() -> PackedStringArray:
	var paths: PackedStringArray = PackedStringArray()
	var dir: DirAccess = DirAccess.open(CORPUS_DIR)
	if dir == null:
		return paths
	for file_name: String in dir.get_files():
		var name: String = file_name.trim_suffix(".remap")
		if name.ends_with(".gd"):
			paths.append(CORPUS_DIR + name)
	paths.sort()
	return paths


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("corpus_test", label, actual, expected)
