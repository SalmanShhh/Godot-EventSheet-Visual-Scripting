# Godot EventSheets - scripts from a project the plugin has never touched open and save back unchanged.
#
# A person adds this plugin to a game they already have. Their scripts were written by hand, in the
# shapes tutorials and the engine docs teach, long before any sheet existed - and the first thing
# they will do is open one. If saving it untouched changes a single byte, the plugin has edited their
# game behind their back. So res://tests/fixtures/existing_project/ holds the files such a project
# typically has, none of them written for the importer:
#   player.gd          a character body with @export categories, groups (one with a prefix), a range
#                      with a suffix, physics flags, signals with and without types, %Unique and $Path
#                      nodes, a lambda connected in _ready, and a tween
#   game_state.gd      an autoload: a property with an inline setter, a const array over several
#                      lines, an inner class with its own _init, and a ConfigFile save
#   inventory_item.gd  a Resource with class_name, an enum, typed array exports, a match with a
#                      default arm and a static sort function
#   spawn_area.gd      a @tool script whose exports redraw it, with configuration warnings
#   slime.gd           untyped code, an enum state machine in a match, an arm with two patterns
#
# Each file is asked every standing contract `tools/verify_sheets.gd` asks (it parses, it carries no
# merge markers or doubled locals, and it re-emits byte for byte), through the gate's own function,
# so this test and that tool can never disagree about what passing means.
#
# A file that fails today is NOT fixed by weakening it. It goes in EXPECTED_DEGRADE with the reason,
# and is pinned as still failing, so the commit that fixes the importer is told to take it out.
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME := "existing_project_round_trip_test"
const FIXTURE_DIR: String = "res://tests/fixtures/existing_project/"
## Every file the folder holds, so a file that goes missing is a failure rather than one fewer check.
const FILES: PackedStringArray = ["game_state.gd", "inventory_item.gd", "player.gd", "slime.gd", "spawn_area.gd"]
## File name -> why it does not round-trip yet. Empty: every file passed when the gate was written.
const EXPECTED_DEGRADE: Dictionary = {}


static func run() -> bool:
	var found: PackedStringArray = PackedStringArray()
	for file: String in DirAccess.get_files_at(FIXTURE_DIR):
		if file.get_extension() == "gd":
			found.append(file)
	found.sort()
	var rows: Array = [["the fixture folder holds the files this test names", found, FILES]]
	for file: String in FILES:
		var failures: Array[Dictionary] = EventSheetVerify.file_failures(FIXTURE_DIR + file)
		for failure: Dictionary in failures:
			print("  %s" % EventSheetVerify.failure_line(failure))
		var expected_clean: bool = not EXPECTED_DEGRADE.has(file)
		var label: String = "%s opens and saves back byte for byte" % file
		if not expected_clean:
			label = "%s still degrades (%s) - drop it from EXPECTED_DEGRADE once it passes" % [file, EXPECTED_DEGRADE[file]]
		rows.append([label, failures.is_empty(), expected_clean])
	return SUPPORT.pins(TEST_NAME, rows)
