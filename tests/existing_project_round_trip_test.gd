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
#   turret.gd          every Inspector export option: prefixed groups and subgroups, a group end,
#                      categories, untyped exports, a raw-path file picker, a free-form @export_custom
# and res://tests/fixtures/existing_project_large/ the bigger, older shapes a grown project collects:
#   enemy_spawner.gd   a @tool spawner: refreshing setters, a hand-written _validate_property, ranges
#                      with two bounds, prefixed groups with a subgroup end, a static var, and untyped
#                      members in every literal spelling (hex, 1_000_000, 1e3, .5, &"name", ^"path")
#   save_manager.gd    an autoload with its own save_state()/load_state() pair over user://remembered.cfg
#   settings_menu.gd   a Control: enum, file, multiline, placeholder, storage and @export_custom exports,
#                      untyped @onready nodes, lambdas and method connects in _ready
#   weapon_data.gd     a @tool Resource: two-bound ranges, typed arrays, a getter-only property
#   hud.gd             a hand-written show-if comment above a group, beside a hand-written function
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
## Every file each folder holds, so a file that goes missing is a failure rather than one fewer check.
const FIXTURES: Dictionary = {
	"res://tests/fixtures/existing_project/": ["game_state.gd", "inventory_item.gd", "player.gd", "slime.gd",
		"spawn_area.gd", "turret.gd"],
	"res://tests/fixtures/existing_project_large/": ["enemy_spawner.gd", "hud.gd",
		"save_manager.gd", "settings_menu.gd", "weapon_data.gd"],
}
## File name -> why it does not round-trip yet. Empty: every file passed when the gate was written.
const EXPECTED_DEGRADE: Dictionary = {}


static func run() -> bool:
	var rows: Array = []
	for folder: String in FIXTURES:
		var found: PackedStringArray = PackedStringArray()
		for file: String in DirAccess.get_files_at(folder):
			if file.get_extension() == "gd":
				found.append(file)
		found.sort()
		rows.append(["%s holds the files this test names" % folder.get_base_dir().get_file(), found,
			PackedStringArray(FIXTURES[folder])])
		for file: String in FIXTURES[folder]:
			var failures: Array[Dictionary] = EventSheetVerify.file_failures(folder + file)
			for failure: Dictionary in failures:
				print("  %s" % EventSheetVerify.failure_line(failure))
			var expected_clean: bool = not EXPECTED_DEGRADE.has(file)
			var label: String = "%s opens and saves back byte for byte" % file
			if not expected_clean:
				label = "%s still degrades (%s) - drop it from EXPECTED_DEGRADE once it passes" % [file, EXPECTED_DEGRADE[file]]
			rows.append([label, failures.is_empty(), expected_clean])
	return SUPPORT.pins(TEST_NAME, rows)
