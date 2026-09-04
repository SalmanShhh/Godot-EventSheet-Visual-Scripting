# The options menu, run rather than read: a control and a setting bound together, a page built from
# declarations, an apply you can walk back out of, and a rebinding whose conflict is answered.
#
# Every claim here is about BEHAVIOUR, so every one of them drives the real emitted pack with real
# Godot controls rather than asserting on the code it was built from. Four things are pinned:
#
#   BOTH DIRECTIONS   a slider moved writes the setting, and a setting written anywhere else moves
#                     the slider - including through a quality preset or Reset To Defaults, because
#                     both of those are ordinary Set Setting changes and the binding hangs off the
#                     announcement rather than off the menu.
#   THE PAGE          the rows come from the declarations, a hand-made control NAMED after a setting
#                     replaces the generated one, and the focus neighbours are wired, which is what
#                     makes a page work on a pad from its first frame.
#   THE WAY BACK      the countdown is a real one: the values as they were, restored by the same
#                     Set Setting path, with the trigger fired - because a menu that has just changed
#                     the screen mode cannot be trusted to be visible enough to ask twice.
#   THE CONFLICT      taking a key leaves the other control without one (and says so), swapping
#                     leaves nobody without one, and both are the same two InputMap calls a person
#                     would have written.
#   THE DIFFICULTY    a word finds its file, its factors answer by name, a key it says nothing about
#                     reads as 1, and clearing it puts every factor back - driven against the three
#                     starter files, because a starter nobody can load is not a starter.
#   THE ASSIST        Declare Assist is one row that lands a toggle on the Accessibility page and
#                     makes the assist trigger fire beside the setting one; a plain toggle nobody
#                     declared as an assist answers neither.
#
# Two traps this file is written around. The pack declares a class_name that a headless --script run
# cannot resolve, so it is reached by load(path). And a test process has no scene tree, so the input
# path is driven at the seam BELOW the viewport: the same functions the unhandled-input handler calls,
# with the pending event put in place by hand.
@tool
class_name OptionsMenuTest
extends RefCounted

const PACK_PATH := "res://eventsheet_addons/game_settings/game_settings_addon.gd"

## Two staged input actions, named so they cannot collide with a real project's own. Both are put
## into the Input Map AND into Project Settings (that is where a reset reads the originals from), and
## both are taken out again at the end.
const ACTION_TAKING := "ro_interact"
const ACTION_HOLDING := "ro_inventory"

## Where the staged quality presets are written for the Doctor's gap question. Under user://, because
## a test that wrote inside res:// would be editing the repository to measure it.
const STAGED_FULL := "user://options_menu_test_full.tres"
const STAGED_GAPPED := "user://options_menu_test_gapped.tres"


static func run() -> bool:
	var ok: bool = true
	ok = _test_binding_runs_both_ways() and ok
	ok = _test_the_kinds_have_to_agree() and ok
	ok = _test_the_page_builds_itself() and ok
	ok = _test_the_way_back() and ok
	ok = _test_the_conflict_has_three_answers() and ok
	ok = _test_the_doctor_reads_both() and ok
	ok = _test_difficulty_is_a_file() and ok
	ok = _test_assists_are_declared_settings() and ok
	ok = _test_the_doctor_notices_a_difficulty_nothing_reads() and ok
	return ok


## DIFFICULTY IS A FILE, and the three starters are the files. Everything here runs the shipped pack
## against the shipped starters: a word puts one in force, its factors answer by name, a key it has
## no answer for reads as 1, and clearing it puts every factor back to 1.
##
## The factors live on Engine, so this test puts that metadata back the way it found it - a
## difficulty left in force would follow every test that runs after this one.
static func _test_difficulty_is_a_file() -> bool:
	var settings: Node = _settings()
	var had: bool = Engine.has_meta("difficulty_factors")
	var before: Variant = Engine.get_meta("difficulty_factors", {})
	var heard: Array = []
	settings.connect("difficulty_changed", func(word: String) -> void: heard.append(word))
	settings.call("use_difficulty", "hard")
	var ok: bool = _check("the word a difficulty goes by finds its file, letter case and all",
		settings.call("difficulty_name"), "Hard")
	ok = _check("and the trigger says which one, once", heard, ["Hard"]) and ok
	ok = _check("the difficulty answers as a question too",
		[settings.call("difficulty_is", "hard"), settings.call("difficulty_is", "easy")],
		[true, false]) and ok
	ok = _check("a factor the file writes answers with its number",
		settings.call("difficulty_factor", "damage_taken"), 1.5) and ok
	ok = _check("a factor it says nothing about reads as 1",
		settings.call("difficulty_factor", "no_such_factor"), 1.0) and ok
	ok = _check("the folder IS the list, in file-name order",
		settings.call("difficulty_names"), ["Easy", "Hard", "Normal"]) and ok
	# The setting road in: the value of a declared setting names the difficulty, which is what makes
	# the choice save, reset and re-apply with everything else in the options screen.
	settings.call("declare_setting", "difficulty", "easy", "choice", "easy|normal|hard", "Game", "")
	settings.call("use_difficulty_from", "difficulty")
	ok = _check("the difficulty a setting names is the one put in force",
		[settings.call("difficulty_name"), settings.call("difficulty_factor", "damage_taken")],
		["Easy", 0.5]) and ok
	# And nothing at all clears it, so every factor is 1 again rather than whatever was last chosen.
	settings.call("use_difficulty", null)
	ok = _check("naming nothing clears the difficulty and every factor with it",
		[settings.call("difficulty_name"), settings.call("difficulty_factor", "damage_taken")],
		["", 1.0]) and ok
	settings.free()
	if had:
		Engine.set_meta("difficulty_factors", before)
	else:
		Engine.remove_meta("difficulty_factors")
	return ok


## AN ASSIST IS A SETTING, and the point of Declare Assist is that it says so in one row: the toggle
## lands on the Accessibility page the menu already builds, and the assist trigger fires beside the
## setting one so a reaction reads as being about an assist.
static func _test_assists_are_declared_settings() -> bool:
	var settings: Node = _settings()
	var heard: Array = []
	settings.connect("assist_changed", func(assist_name: String, on: bool) -> void:
		heard.append([assist_name, on]))
	settings.call("declare_assist", "invincible", false)
	var ok: bool = _check("an assist is declared as an ordinary toggle on the accessibility page",
		[settings.call("setting_is_declared", "invincible"), settings.call("setting_kind", "invincible"),
			settings.call("setting_page", "invincible")], [true, "toggle", "Accessibility"])
	ok = _check("and it starts off, because that is what it was declared with",
		settings.call("assist_is_on", "invincible"), false) and ok
	settings.call("set_setting", "invincible", true)
	ok = _check("switching it on is switching the setting on",
		settings.call("assist_is_on", "invincible"), true) and ok
	ok = _check("and the assist trigger carries the name and the answer",
		heard, [["invincible", true]]) and ok
	# An ordinary setting is not an assist, however yes-or-no it is: only a declared one answers.
	settings.call("declare_setting", "fullscreen", true, "toggle", "", "Video", "")
	ok = _check("a plain setting nobody declared as an assist reads as off",
		settings.call("assist_is_on", "fullscreen"), false) and ok
	ok = _check("and changing it says nothing on the assist trigger", heard.size(), 1) and ok
	settings.free()
	return ok


## The third Doctor question, asked of two staged scripts rather than of this repository: a project
## that chooses a difficulty and never multiplies by one is told so, and the same project with one
## factor read anywhere in it is told nothing.
static func _test_the_doctor_notices_a_difficulty_nothing_reads() -> bool:
	var chooser: Dictionary = {"path": "res://menu.gd",
		"source": "func _on_picked(word: String) -> void:
	Settings.use_difficulty(word)"}
	var reader: Dictionary = {"path": "res://player.gd",
		"source": "func hurt(amount: float) -> void:
	take_damage(amount * Settings.difficulty_factor(\"damage_taken\"))"}
	var ok: bool = _check("a difficulty nothing reads a factor out of is one finding",
		_messages(EventSheetOptionsDoctor.report(PackedStringArray(), PackedStringArray(), [chooser])),
		PackedStringArray([
			"menu.gd chooses a difficulty, but nothing in this project reads a factor out of one - the menu changes nothing. Multiply by Difficulty Factor where the difficulty is meant to be felt."]))
	ok = _check("one row reading one factor anywhere is enough to answer it",
		_messages(EventSheetOptionsDoctor.report(PackedStringArray(), PackedStringArray(), [chooser, reader])),
		PackedStringArray()) and ok
	ok = _check("and a project that never chooses one is said nothing about",
		_messages(EventSheetOptionsDoctor.report(PackedStringArray(), PackedStringArray(), [])),
		PackedStringArray()) and ok
	return ok


## A slider, a checkbox and a dropdown, each bound once and then driven from both ends.
static func _test_binding_runs_both_ways() -> bool:
	var settings: Node = _settings()
	settings.call("declare_setting", "music_volume", 80, "percent", "", "Audio", "")
	settings.call("declare_setting", "fullscreen", false, "toggle", "", "Video", "")
	settings.call("declare_setting", "quality", "Medium", "choice", "Low|Medium|High", "Video", "")
	var slider: HSlider = HSlider.new()
	var check: CheckBox = CheckBox.new()
	var picker: OptionButton = OptionButton.new()
	settings.call("bind_control", slider, "music_volume")
	settings.call("bind_control", check, "fullscreen")
	settings.call("bind_control", picker, "quality")
	var ok: bool = _check("a control shows the value in force the moment it is bound",
		[slider.value, check.button_pressed, picker.get_item_text(picker.selected)], [80.0, false, "Medium"])
	ok = _check("a dropdown with no items of its own takes the declared choices", picker.item_count, 3) and ok
	# The player's end, staged as the controls really behave. A checkbox announces the moment its
	# value changes; a dropdown announces when an ITEM IS PICKED, which `select` deliberately does not
	# count as; and a slider outside a scene tree announces nothing at all, so the drag that a player
	# would have done is spelled out here rather than assumed.
	slider.value = 55.0
	slider.value_changed.emit(55.0)
	check.button_pressed = true
	picker.select(2)
	picker.item_selected.emit(2)
	ok = _check("moving a control writes the setting, in the kind it was declared with",
		[settings.call("setting_value", "music_volume"), settings.call("setting_value", "fullscreen"),
			settings.call("setting_value", "quality")], [55, true, "High"]) and ok
	# The other end: anything at all that changes a setting moves the control back, because the
	# binding hangs off the announcement rather than off the menu.
	settings.call("set_setting", "music_volume", 20)
	settings.call("reset_settings_to_defaults")
	ok = _check("a setting changed anywhere else moves the control back",
		[slider.value, check.button_pressed, picker.selected], [80.0, false, 1]) and ok
	slider.free()
	check.free()
	picker.free()
	settings.free()
	return ok


## The amber sentence, which is the whole of what "this control is the wrong shape for this setting"
## has to say: what the setting is, what it wants, and what it was given.
static func _test_the_kinds_have_to_agree() -> bool:
	var settings: Node = _settings()
	settings.call("declare_setting", "music_volume", 80, "percent", "", "Audio", "")
	settings.call("declare_setting", "fullscreen", false, "toggle", "", "Video", "")
	var check: CheckBox = CheckBox.new()
	var slider: HSlider = HSlider.new()
	var unknown: Control = Control.new()
	var ok: bool = _check("a checkbox on a percent says which is which",
		settings.call("binding_mismatch", check, "music_volume"),
		"music_volume is a percent and wants a slider - this is a checkbox.")
	ok = _check("a control that fits says nothing at all",
		settings.call("binding_mismatch", check, "fullscreen"), "") and ok
	ok = _check("and a slider on a toggle is the same complaint the other way",
		settings.call("binding_mismatch", slider, "fullscreen"),
		"fullscreen is yes or no and wants a checkbox - this is a slider.") and ok
	ok = _check("a name nothing declares is answered as that, not as a mismatch",
		settings.call("binding_mismatch", check, "invented"),
		"nothing declares 'invented' yet - Declare Setting it first.") and ok
	ok = _check("a control this pack does not recognise is never complained about",
		settings.call("binding_mismatch", unknown, "music_volume"), "") and ok
	check.free()
	slider.free()
	unknown.free()
	settings.free()
	return ok


## The page: one row per declaration on it, in declared order, with the label the declaration gave
## and the control its kind asks for - and a hand-made control taking the place of a generated one.
static func _test_the_page_builds_itself() -> bool:
	var settings: Node = _settings()
	settings.call("declare_setting", "fullscreen", false, "toggle", "", "Video", "")
	settings.call("declare_setting", "quality", "Medium", "choice", "Low|Medium|High", "Video", "Graphics quality")
	settings.call("declare_setting", "screen_shake", true, "toggle", "", "Accessibility", "")
	settings.call("declare_setting", "difficulty", "Normal", "choice", "Easy|Normal|Hard", "", "")
	var ok: bool = _check("a page is every setting declared for it, in declared order",
		settings.call("settings_on_page", "Video"), ["fullscreen", "quality"])
	ok = _check("a setting declared for no page is on none of them",
		settings.call("setting_page", "difficulty"), "") and ok
	ok = _check("the label is the one that was written, or the name opened out",
		[settings.call("setting_label", "quality"), settings.call("setting_label", "screen_shake")],
		["Graphics quality", "Screen shake"]) and ok
	# The hand-made half: a control already in the container, named after a setting, is used instead
	# of a generated one - so a designed slider simply replaces its row and nothing is built twice.
	var page: VBoxContainer = VBoxContainer.new()
	var by_hand: CheckBox = CheckBox.new()
	by_hand.name = "fullscreen"
	page.add_child(by_hand)
	settings.call("build_settings_page", page, "Video")
	var built: PackedStringArray = PackedStringArray()
	for child: Node in page.get_children():
		built.append(str(child.name))
	ok = _check("the generated rows are the settings the page did not already show",
		built, PackedStringArray(["fullscreen", "quality_row"])) and ok
	# Nothing here is owned by a scene, so every search says so: find_child looks only at OWNED
	# children unless told otherwise, and a page built in code has none.
	var made: Node = page.find_child("quality", true, false)
	ok = _check("and each generated control is the one its kind asks for",
		[made.get_class(), (page.find_child("quality_row", true, false).get_child(0) as Label).text],
		["OptionButton", "Graphics quality"]) and ok
	settings.call("set_setting", "fullscreen", true)
	ok = _check("the hand-made control was bound like any other", by_hand.button_pressed, true) and ok
	# The focus chain, which is what makes the page work on a pad from its first frame.
	ok = _check("every control points at the next one, and the last wraps round",
		[by_hand.get_node_or_null(by_hand.focus_neighbor_bottom), made.get_node_or_null(made.focus_neighbor_bottom)],
		[made, by_hand]) and ok
	ok = _check("with the chain wired, nothing on the page is out of reach",
		settings.call("unreachable_controls", page), []) and ok
	by_hand.focus_mode = Control.FOCUS_NONE
	ok = _check("a control whose focus is switched off is named",
		settings.call("unreachable_controls", page), ["fullscreen"]) and ok
	page.free()
	settings.free()
	return ok


## Apply, ask, and take silence for a no. The countdown is driven a frame at a time, because that is
## how it runs in a game and because a test that reached in and set the clock would be testing the
## test.
static func _test_the_way_back() -> bool:
	var settings: Node = _settings()
	settings.call("declare_setting", "resolution_scale", 1.0, "number", "", "Video", "")
	var announced: Array = []
	(settings.get("settings_reverted") as Signal).connect(func() -> void: announced.append("reverted"))
	(settings.get("settings_kept") as Signal).connect(func() -> void: announced.append("kept"))
	settings.call("keep_a_way_back", 10.0)
	settings.call("set_setting", "resolution_scale", 0.5)
	settings.call("_process", 4.0)
	var ok: bool = _check("while the player still has time, the new value stands",
		[settings.call("setting_value", "resolution_scale"), settings.call("seconds_left_to_keep")], [0.5, 6.0])
	settings.call("_process", 6.0)
	ok = _check("silence puts every value back, and says so",
		[settings.call("setting_value", "resolution_scale"), announced], [1.0, ["reverted"]]) and ok
	# And the other answer: keeping stops the clock, changes nothing, and cannot revert afterwards.
	settings.call("keep_a_way_back", 10.0)
	settings.call("set_setting", "resolution_scale", 0.75)
	settings.call("keep_settings")
	settings.call("_process", 30.0)
	ok = _check("keeping them leaves them alone, however long anyone waits afterwards",
		[settings.call("setting_value", "resolution_scale"), announced],
		[0.75, ["reverted", "kept"]]) and ok
	settings.free()
	return ok


## The three answers to a key that is taken, each one measured by what the Input Map holds afterwards.
static func _test_the_conflict_has_three_answers() -> bool:
	var settings: Node = _settings()
	_stage_actions(KEY_E, KEY_F)
	var ok: bool = _check("a binding reads as the word on the key",
		[settings.call("key_binding_of", ACTION_TAKING), settings.call("pad_binding_of", ACTION_TAKING)],
		["F", ""])
	# Swapping: the two trade, and nobody is left without a key.
	_stage_pending(settings, ACTION_TAKING, KEY_E)
	ok = _check("the conflict names the control that already answers to the key",
		settings.call("conflicting_action"), ACTION_HOLDING) and ok
	settings.call("swap_the_binding")
	ok = _check("a swap gives each of them the other's key",
		[settings.call("key_binding_of", ACTION_TAKING), settings.call("key_binding_of", ACTION_HOLDING)],
		["E", "F"]) and ok
	ok = _check("and leaves nobody unbound", settings.call("unbound_actions").has(ACTION_HOLDING), false) and ok
	# Taking it anyway: honest rather than tidy, and the pack says who it cost.
	_stage_actions(KEY_E, KEY_F)
	_stage_pending(settings, ACTION_TAKING, KEY_E)
	settings.call("take_the_binding_anyway")
	ok = _check("taking a key really does take it",
		[settings.call("key_binding_of", ACTION_TAKING), settings.call("key_binding_of", ACTION_HOLDING)],
		["E", ""]) and ok
	ok = _check("and the control it was taken from says it has nothing left",
		[settings.call("unbound_actions"), settings.call("action_is_unbound", ACTION_HOLDING)],
		[[ACTION_HOLDING], true]) and ok
	# Picking another key changes nothing and goes on listening, which is what makes it the safe one.
	_stage_pending(settings, ACTION_TAKING, KEY_G)
	settings.call("pick_another_key")
	ok = _check("picking another key changes nothing and keeps listening",
		[settings.call("key_binding_of", ACTION_TAKING), settings.call("waiting_for_a_key")],
		["E", true]) and ok
	settings.call("cancel_listening")
	# A reset goes back to what the PROJECT ships with, not to what was last saved.
	settings.call("reset_binding", ACTION_HOLDING)
	ok = _check("a reset restores the binding the project ships with",
		settings.call("key_binding_of", ACTION_HOLDING), "E") and ok
	_clear_actions()
	settings.free()
	return ok


## The Doctor's two questions, each with a project staged for it.
static func _test_the_doctor_reads_both() -> bool:
	_stage_actions(KEY_E, KEY_F)
	ProjectSettings.set_setting("input/%s" % ACTION_HOLDING, {"deadzone": 0.2, "events": []})
	var findings: Array[Dictionary] = EventSheetOptionsDoctor.report(
		PackedStringArray([ACTION_TAKING, ACTION_HOLDING]), PackedStringArray())
	var ok: bool = _check("an action with no binding on any device is one finding",
		_messages(findings), PackedStringArray([
			"%s has no binding on any device - nobody can press it. Bind it in Project Settings, or let a Controls page bind it." % ACTION_HOLDING]))
	_clear_actions()
	# The preset gap: two files, one of which says nothing about a setting the other answers for.
	var wrote: String = EventSheetQualityPresets.write_preset(STAGED_FULL, "Full", 1,
		{"msaa": 2, "resolution_scale": 1.0})
	wrote += EventSheetQualityPresets.write_preset(STAGED_GAPPED, "Gapped", 0, {"msaa": 0})
	ok = _check("the staged presets were written", wrote, "") and ok
	var staged: PackedStringArray = PackedStringArray([STAGED_GAPPED, STAGED_FULL])
	ok = _check("what every preset should answer for is what any of them answers for",
		EventSheetOptionsDoctor.settings_every_preset_should_answer(staged),
		PackedStringArray(["msaa", "resolution_scale"])) and ok
	ok = _check("and the one that says nothing about a setting is named with what it left out",
		_messages(EventSheetOptionsDoctor.report(PackedStringArray(), staged)),
		PackedStringArray([
			"options_menu_test_gapped.tres says nothing about resolution_scale, so picking it leaves that where the last preset put it."])) and ok
	DirAccess.remove_absolute(ProjectSettings.globalize_path(STAGED_FULL))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(STAGED_GAPPED))
	return ok


## A settings node of the shipped pack, reached by path because a headless run cannot resolve the
## class name the pack declares.
static func _settings() -> Node:
	return (load(PACK_PATH) as GDScript).new()


## Two input actions in both places that matter: the Input Map (what the game answers to now) and
## Project Settings (what a reset goes back to). The holding one gets the first key, the taking one
## the second, so a rebinding to the first key is always a conflict.
static func _stage_actions(held_key: int, taken_key: int) -> void:
	_clear_actions()
	for pair: Array in [[ACTION_HOLDING, held_key], [ACTION_TAKING, taken_key]]:
		var action: String = str(pair[0])
		var event: InputEventKey = InputEventKey.new()
		event.keycode = int(pair[1])
		event.pressed = true
		InputMap.add_action(action)
		InputMap.action_add_event(action, event)
		ProjectSettings.set_setting("input/%s" % action, {"deadzone": 0.2, "events": [event]})


## Puts the pack where the unhandled-input handler would have put it: listening for one control, with
## a key the player has just pressed waiting to be answered for.
static func _stage_pending(settings: Node, action: String, pressed_key: int) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = pressed_key
	event.pressed = true
	settings.call("listen_for_binding", action, "keyboard")
	settings.set("_pending_event", event)


## Takes the staged actions back out of both places, so nothing this file did is visible to the test
## that runs after it.
static func _clear_actions() -> void:
	for action: String in [ACTION_HOLDING, ACTION_TAKING]:
		if InputMap.has_action(action):
			InputMap.erase_action(action)
		ProjectSettings.set_setting("input/%s" % action, null)


## The messages of a run of findings, which is what a reader of the report actually gets.
static func _messages(findings: Array[Dictionary]) -> PackedStringArray:
	var said: PackedStringArray = PackedStringArray()
	for finding: Dictionary in findings:
		said.append(str(finding.get("message", "")))
	return said


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] options_menu_test: %s" % label)
		return true
	print("[FAIL] options_menu_test: %s - expected %s, got %s" % [label, expected, actual])
	return false
