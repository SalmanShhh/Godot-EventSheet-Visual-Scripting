# Godot EventSheets - what a user's OWN project reads like.
#
# Everything else in the suite opens the plugin's own files: its demo, its packs, its tools. A user
# meets the plugin installed beside a game they wrote by hand, with the behaviour packs copied in
# next to it, and that is where these readings went wrong without any test noticing:
#
#   - a `match state:` inside `func _update_state()` moved the object every frame, and the Doctor
#     said the states it went to could not be reached, because the walk stopped at the events;
#   - renaming a function nothing in its own file calls said "rewrites the 0 row(s) in this sheet",
#     while the button went on to rewrite its declaration;
#   - `@export_group("Feel")` covers every field after it, as Godot draws it, and the Inspector
#     Designer put only the first one under Feel;
#   - `var coyote_time := 0.1` is a float to Godot and read "Variant" in the Designer and the Save
#     studio, and the autoload `game_state.gd` was named game_state where every script says GameState;
#   - the Sheet map, Find in Project and the Doctor read the hundred-odd pack scripts as the game's
#     own: the map drew no game script at all, Find listed the packs' matches first, and the Doctor's
#     first warnings were about pack code the reader never wrote;
#   - opening the same script twice from the FileSystem made a second tab of it.
#
# The source below is the shape of a beginner's player script: typed and untyped exports, a group,
# the walrus everywhere, and the state machine in a function of its own.
@tool
class_name UserProjectReadingTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME := "user_project_reading_test"
const SCRIPT_PATH := "user://user_project_reading_player.gd"
const AUTOLOAD_SETTING := "autoload/ZqUserGameState"
const AUTOLOAD_SCRIPT := "res://zq_user_game_state.gd"

const PLAYER_SOURCE := """class_name ZqUserPlayer
extends CharacterBody2D

enum State { IDLE, RUN, JUMP }

@export var speed: float = 220.0
@export var jump_force = 420.0

@export_group("Feel")
@export var coyote_time := 0.1
@export var acceleration: float = 1200.0
@export var friction = 900.0

var state: State = State.IDLE
var run_time := 0.0


func _physics_process(delta: float) -> void:
	run_time += delta
	_update_state()


func _update_state() -> void:
	match state:
		State.IDLE:
			if absf(velocity.x) > 10.0:
				state = State.RUN
		State.RUN:
			if absf(velocity.x) <= 10.0:
				state = State.IDLE
		State.JUMP:
			if is_on_floor():
				state = State.IDLE
	if not is_on_floor():
		state = State.JUMP


func take_damage(amount):
	print(amount)
"""


static func run() -> bool:
	var sheet: EventSheetResource = _opened()
	var ok: bool = _check("the player script opens as a sheet", sheet != null, true)
	if sheet == null:
		return false
	ok = _states_set_in_a_function_are_reached(sheet) and ok
	ok = _renaming_a_function_lists_its_head(sheet) and ok
	ok = _the_designer_reads_groups_and_walrus_types(sheet) and ok
	ok = _the_save_studio_reads_types_and_globals(sheet) and ok
	ok = _the_packs_are_not_the_game() and ok
	ok = _opening_twice_keeps_one_tab() and ok
	ok = _the_words_preview_says_what_the_page_says() and ok
	return ok


## The file a user saved, opened the way the editor opens it: imported, then lifted.
static func _opened() -> EventSheetResource:
	var file: FileAccess = FileAccess.open(SCRIPT_PATH, FileAccess.WRITE)
	if file == null:
		return null
	file.store_string(PLAYER_SOURCE)
	file.close()
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(SCRIPT_PATH, false)
	if sheet != null:
		EventSheetACELifter.attempt_lift(sheet, PLAYER_SOURCE)
	return sheet


static func _states_set_in_a_function_are_reached(sheet: EventSheetResource) -> bool:
	var entered: Array = Array(EventSheetStateFacts.entered_states(sheet))
	entered.sort()
	var ok: bool = _check("the states a function's match goes to are states the object reaches",
		entered, ["IDLE", "JUMP", "RUN"])
	ok = _check("so the Doctor says nothing is unreachable",
		EventSheetStateFacts.findings(sheet).filter(func(finding: Dictionary) -> bool:
			return finding.get("kind") == EventSheetStateFacts.KIND_STATE_UNREACHABLE).size(), 0) and ok
	# The same file before its functions are lifted: the bodies are still script blocks, and a
	# `state = State.RUN` line in one reaches RUN all the same.
	var raw: EventSheetResource = GDScriptImporter.new().import_external(SCRIPT_PATH, false)
	var raw_entered: Array = Array(EventSheetStateFacts.entered_states(raw))
	raw_entered.sort()
	ok = _check("and a script block that says state = State.RUN reaches RUN too",
		raw_entered, ["IDLE", "JUMP", "RUN"]) and ok
	return ok


static func _renaming_a_function_lists_its_head(sheet: EventSheetResource) -> bool:
	return _check("renaming a function nothing here calls lists its own head line",
		Array(EventSheetRenameReceipt.row_lines(sheet, "take_damage", "hurt")),
		["func take_damage(amount): → func hurt(amount):"])


static func _the_designer_reads_groups_and_walrus_types(sheet: EventSheetResource) -> bool:
	var entries: Array[Dictionary] = EventSheetInspectorDesignerDialog.collect_entries(sheet)
	var types: Dictionary = {}
	for entry: Dictionary in entries:
		types[str(entry.get("name"))] = str(entry.get("type_name"))
	var ok: bool = _check("a walrus field is the type its value gives away, never Variant",
		[types.get("coyote_time"), types.get("jump_force")], ["float", "float"])
	var shown: Dictionary = EventSheetInspectorDesignerDialog.attributes_as_shown(entries)
	var groups: Array = []
	for field: String in ["speed", "coyote_time", "acceleration", "friction"]:
		groups.append(str((shown.get(field, {}) as Dictionary).get("group", "")))
	ok = _check("every field after @export_group(\"Feel\") is under Feel, as Godot draws it",
		groups, ["", "Feel", "Feel", "Feel"]) and ok
	ok = _check("only the field that opens the group draws its heading",
		[bool((shown["coyote_time"] as Dictionary).get("group_continues", false)),
			bool((shown["friction"] as Dictionary).get("group_continues", false))], [false, true]) and ok
	ok = _check("and the field's sentence says which group it is in",
		EventSheetInspectorPreviewCard.describe("float", shown["friction"] as Dictionary, true, false),
		"A number. It is grouped under Feel.") and ok
	var friction_entry: Array = entries.filter(func(entry: Dictionary) -> bool: return entry.get("name") == "friction")
	ok = _check("while the field's own attributes stay what the file says",
		(friction_entry[0] as Dictionary).get("attributes"), {}) and ok
	return ok


static func _the_save_studio_reads_types_and_globals(sheet: EventSheetResource) -> bool:
	var types: Dictionary = {}
	for variable: Dictionary in EventSheetSaveStudio.savable_variables(sheet):
		types[str(variable["name"])] = str(variable["type"])
	var ok: bool = _check("the Save studio types a walrus variable as Godot does",
		types.get("run_time"), "float")
	ProjectSettings.set_setting(AUTOLOAD_SETTING, "*" + AUTOLOAD_SCRIPT)
	var named: String = EventSheetSaveStudio.object_name(EventSheetResource.new(), AUTOLOAD_SCRIPT)
	ProjectSettings.set_setting(AUTOLOAD_SETTING, null)
	ok = _check("a global with no class name is called by its global's name", named, "ZqUserGameState") and ok
	ok = _check("and a plain script still by its file",
		EventSheetSaveStudio.object_name(EventSheetResource.new(), "res://zq_plain_script.gd"), "zq_plain_script") and ok
	return ok


static func _the_packs_are_not_the_game() -> bool:
	var drawn: PackedStringArray = EventSheetSheetMap._scripts_under("res://")
	var ok: bool = _check("the Sheet map draws no pack script",
		Array(drawn).filter(func(path: String) -> bool: return path.begins_with("res://eventsheet_addons/")).size(), 0)
	ok = _check("the Doctor counts a pack's script as shipped, as it counts the plugin's",
		[EventSheetDoctorSection._is_shipped("res://eventsheet_addons/fade/fade_behavior.gd"),
			EventSheetDoctorSection._is_shipped("res://addons/eventsheet/plugin.cfg"),
			EventSheetDoctorSection._is_shipped("res://player.gd")], [true, true, false]) and ok
	ok = _check("so the spawning section never reads a pack",
		Array(EventSheetSpawningDoctor.ranked(PackedStringArray(["res://eventsheet_addons/fade/fade_behavior.gd"]))), []) and ok
	var findings: Array[Dictionary] = []
	EventSheetProjectDoctor.check_unknown_input_actions(PackedStringArray(), findings)
	ok = _check("and no pack is told its controls are missing from the game's Input Map",
		findings.filter(func(finding: Dictionary) -> bool:
			return str(finding.get("path", "")).begins_with("res://eventsheet_addons/")).size(), 0) and ok
	var found: Array = EventSheetProjectFind.find_in_project("extends",
		PackedStringArray(["res://eventsheet_addons/fade/fade_behavior.gd", "res://tests/support.gd"]))
	ok = _check("Find lists the game's own files before the packs' matches",
		[str((found[0] as Dictionary).get("path")) if not found.is_empty() else "",
			str((found[found.size() - 1] as Dictionary).get("path")) if not found.is_empty() else ""],
		["res://tests/support.gd", "res://eventsheet_addons/fade/fade_behavior.gd"]) and ok
	return ok


static func _opening_twice_keeps_one_tab() -> bool:
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.open_or_focus_sheet(SCRIPT_PATH)
	var after_one: int = dock._open_tabs.size()
	dock.open_or_focus_sheet(SCRIPT_PATH)
	var ok: bool = _check("opening the same script twice keeps one tab of it",
		[after_one, dock._open_tabs.size()], [after_one, after_one])
	dock.free()
	return ok


## The Words page's preview reads the `_process` word the table above it sets.
static func _the_words_preview_says_what_the_page_says() -> bool:
	var page: EventSheetWordsSettingsDialog = EventSheetWordsSettingsDialog.new()
	page.refresh()
	var said: String = page._preview_verbs.text
	var word: String = EventSheetWords.word_for("every_tick", EventSheetWords.familiar_words_enabled(),
		EventSheetWords.overrides())
	page.free()
	return _check("the Words preview's trigger is the _process word the table sets",
		said.begins_with("System ▸ %s " % word), true)


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check(TEST_NAME, label, actual, expected)
