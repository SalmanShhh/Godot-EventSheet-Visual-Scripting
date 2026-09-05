# Godot EventSheets - the Scene Flow pack's loading screens.
#
# The pack already changed scenes with a shape drawn over the change. This half puts a screen of the
# project's OWN in the middle of that change while the next scene comes off the disk on a thread,
# and everything worth pinning about it is arithmetic:
#
#   THE READING a bar is set to, which is the slower of the two things being waited on - how much of
#   the scene is off the disk, and how much of the shortest time has been served;
#   THE GATE that says the wait is over, which is both of those and not either;
#   THE BRANCH at the end of the wait: the runner walks in by itself, unless the row asked to wait
#   for a key, in which case Enter Loaded Scene is what the key does;
#   THE TIPS a text file holds, one per line, with the file's own notes left out.
#
# All four are STATIC functions on the shipped pack over plain numbers and text, which is what makes
# them testable here at all: a headless run has no main loop, no scene tree and no disk to load a
# scene off, so nothing in this file waits for a frame and nothing asks the real loader anything.
# The loader's own status is stubbed as the integer it is, and the integers themselves are pinned so
# a stub that stopped meaning what it says fails here rather than passing for the wrong reason.
#
# The last two sections are the other half of the slice: the words the shipped rows carry, and the
# Doctor's quiet note about a big scene opened with nothing over it.
@tool
class_name SceneFlowPackTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "scene_flow_pack_test"
const PACK_PATH := "res://eventsheet_addons/scene_flow/scene_flow_behavior.gd"
const STARTER_SCREEN := "res://eventsheet_addons/scene_flow/loading_screen.tscn"
const STARTER_SHEET := "res://eventsheet_addons/scene_flow/loading_screen.gd"
const STARTER_TIPS := "res://eventsheet_addons/scene_flow/tips.txt"

## A tips file as somebody would really keep one: a note to itself at the top, a blank line for air,
## and two tips, one of them indented by a hand that was lining things up.
const TIPS_TEXT := "# Rewrite these for your own game.\n\nHold run to clear the widest gaps.\n\n\tStanding still refills your shield.\n"

## What a plain, uncovered swap looks like in a compiled sheet, in both spellings the check reads:
## the engine's own call and the pack verb that wraps it.
const PLAIN_SWAP_SOURCE := "func _on_pressed() -> void:\n\tget_tree().change_scene_to_file(\"res://levels/forest.tscn\")\n"
const PACK_SWAP_SOURCE := "func _on_pressed() -> void:\n\t$SceneFlowBehavior.go_to_scene(\"res://levels/cavern.tscn\")\n"

## One megabyte, the size the note starts speaking at, and two of them so the sentence has a number
## in it that is not the threshold itself.
const ONE_MEGABYTE: int = 1048576


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _test_the_stubbed_status() and all_passed
	all_passed = _test_the_reading() and all_passed
	all_passed = _test_the_shortest_time() and all_passed
	all_passed = _test_the_wait_for_key_branch() and all_passed
	all_passed = _test_the_tips_file() and all_passed
	all_passed = _test_the_shipped_rows() and all_passed
	all_passed = _test_the_entry_waits_for_the_cover() and all_passed
	all_passed = _test_the_starters() and all_passed
	all_passed = _test_the_doctor_note() and all_passed
	return all_passed


## THE STUB'S OWN HONESTY. Every pin below hands the model an integer where the running game hands
## it `load_threaded_get_status`'s answer, so these three integers are the whole seam. Pinned by
## value because a stub that drifted from the engine would leave the rest of this file green while
## the shipped pack answered the opposite of what it says.
static func _test_the_stubbed_status() -> bool:
	return SUPPORT.pins(P, [
		["the loader says 1 while a load is in progress",
			int(ResourceLoader.THREAD_LOAD_IN_PROGRESS), 1],
		["2 when it failed", int(ResourceLoader.THREAD_LOAD_FAILED), 2],
		["and 3 when the scene is off the disk", int(ResourceLoader.THREAD_LOAD_LOADED), 3],
	])


## THE READING, from 0 to 1: what Scene Load Progress answers with and what a bar is set to. It is the
## SLOWER of the two waits, which is the whole point - a bar that races to the end on a fast disk
## and then sits there for a second reads as a hang, and a game that looks hung is worse than a game
## that is slow.
static func _test_the_reading() -> bool:
	return SUPPORT.pins(P, [
		["with no shortest time the reading is the disk's own",
			SceneFlowBehavior.loading_reading(0.5, 10.0, 0.0), 0.5],
		["half the scene read and a quarter of the wait served shows the quarter",
			SceneFlowBehavior.loading_reading(0.5, 0.5, 2.0), 0.25],
		["a scene that landed at once still walks the shortest time",
			SceneFlowBehavior.loading_reading(1.0, 1.0, 2.0), 0.5],
		["and a wait that is over does not hurry the disk along",
			SceneFlowBehavior.loading_reading(0.25, 4.0, 2.0), 0.25],
		["both of them done is the end of the bar",
			SceneFlowBehavior.loading_reading(1.0, 2.0, 2.0), 1.0],
		["a loader answering below zero is still the start of the bar",
			SceneFlowBehavior.loading_reading(-1.0, 1.0, 0.0), 0.0],
		["and one answering above one is still the end of it",
			SceneFlowBehavior.loading_reading(2.0, 1.0, 1.0), 1.0],
	])


## THE GATE. The wait is over when the scene is off the disk AND the shortest time has been served,
## and asking it as one question is what makes a fast machine and a slow one spend the same beat on
## the screen instead of one of them flashing it past in a frame.
static func _test_the_shortest_time() -> bool:
	return SUPPORT.pins(P, [
		["a load still running is not the end of the wait, however long it has been",
			SceneFlowBehavior.loading_wait_is_over(
				ResourceLoader.THREAD_LOAD_IN_PROGRESS, 5.0, 1.0), false],
		["a scene that landed early waits for the shortest time",
			SceneFlowBehavior.loading_wait_is_over(
				ResourceLoader.THREAD_LOAD_LOADED, 0.5, 1.0), false],
		["and is over the moment that time is served",
			SceneFlowBehavior.loading_wait_is_over(
				ResourceLoader.THREAD_LOAD_LOADED, 1.0, 1.0), true],
		["a load that failed is never the end of the wait",
			SceneFlowBehavior.loading_wait_is_over(
				ResourceLoader.THREAD_LOAD_FAILED, 5.0, 1.0), false],
		["and a shortest time of nothing asks only the disk",
			SceneFlowBehavior.loading_wait_is_over(
				ResourceLoader.THREAD_LOAD_LOADED, 0.0, 0.0), true],
	])


## THE BRANCH at the end of the wait. Off, the runner walks into the new scene by itself; on, it
## stops there and the screen stays up until a row runs Enter Loaded Scene - the press-any-key
## screen, which is a row and not a setting.
static func _test_the_wait_for_key_branch() -> bool:
	return SUPPORT.pins(P, [
		["with the key branch off, a finished wait enters by itself",
			SceneFlowBehavior.loading_enters_itself(
				ResourceLoader.THREAD_LOAD_LOADED, 2.0, 1.0, false), true],
		["with it on, the same finished wait waits",
			SceneFlowBehavior.loading_enters_itself(
				ResourceLoader.THREAD_LOAD_LOADED, 2.0, 1.0, true), false],
		["and neither branch enters a wait that is not over",
			SceneFlowBehavior.loading_enters_itself(
				ResourceLoader.THREAD_LOAD_IN_PROGRESS, 2.0, 1.0, false), false],
	])


## THE TIPS a text file holds. One per line, blanks dropped, a line starting with # left out so the
## file can carry a note about itself, and any number at all picks one by wrapping round - which is
## what lets the pack hand it a raw random number without doing arithmetic at the call site.
static func _test_the_tips_file() -> bool:
	var tips: PackedStringArray = SceneFlowBehavior.loading_tip_lines(TIPS_TEXT)
	return SUPPORT.pins(P, [
		["the file's own note and its blank lines are not tips", tips,
			PackedStringArray(["Hold run to clear the widest gaps.",
				"Standing still refills your shield."])],
		["the first tip is the first line that is one",
			SceneFlowBehavior.loading_tip_at(tips, 0), "Hold run to clear the widest gaps."],
		["a number past the end wraps round",
			SceneFlowBehavior.loading_tip_at(tips, 3), "Standing still refills your shield."],
		["and so does one below the start",
			SceneFlowBehavior.loading_tip_at(tips, -1), "Standing still refills your shield."],
		["a file with no tips in it answers with nothing at all",
			SceneFlowBehavior.loading_tip_at(SceneFlowBehavior.loading_tip_lines("# only a note\n"), 5), ""],
	])


## THE WORDS THE ROWS CARRY, read out of the shipped pack rather than out of the builder, because
## the shipped file is what a project opens. Four rows, two triggers and three knobs, plus the one
## sentence Go To Scene With Loading reads as on the sheet.
static func _test_the_shipped_rows() -> bool:
	var shipped: String = FileAccess.get_file_as_string(PACK_PATH)
	return SUPPORT.pins(P, [
		["the pack ships the loading verb",
			shipped.contains("func go_to_with_loading(scene: String, min_seconds: float, wait_for_key: bool) -> void:"), true],
		["and the row it reads as", shipped.contains(
			"## @ace_display_template(\"Go to scene [b]{scene}[/b] with loading, at least [b]{min_seconds}[/b] s\")"), true],
		["the press-any-key door is a verb of its own",
			shipped.contains("func enter_loaded_scene() -> void:"), true],
		["the question a row asks while a screen is up",
			shipped.contains("## @ace_name(\"Scene Is Loading\")"), true],
		["the number a bar is set to", shipped.contains("## @ace_name(\"Scene Load Progress\")"), true],
		["the line a label shows", shipped.contains("## @ace_name(\"Loading Tip\")"), true],
		["the bar's own trigger", shipped.contains("## @ace_name(\"On Loading Progress\")"), true],
		["and the arrival's", shipped.contains("## @ace_name(\"On Loading Finished\")"), true],
		["both triggers are real signals",
			shipped.contains("signal loading_progress_changed") \
				and shipped.contains("signal loading_finished"), true],
		["the screen is a file the project picks",
			shipped.contains("@export_file(\"*.tscn\", \"*.scn\") var loading_scene: String = \"\""), true],
		["the tips are a file the project picks",
			shipped.contains("@export_file(\"*.txt\") var loading_tips_file: String = \"\""), true],
		["and the shape over the change comes from the same wardrobe as the rest",
			shipped.contains("@export_enum(\"none\", \"fade\", \"wipe\", \"dissolve\", \"iris\", \"blinds\", \"pixelate\", \"page curl\") var loading_transition: String = \"fade\""), true],
		["the three background rows the engine already had are untouched",
			shipped.contains("load_threaded_request"), true],
	])


## THE ORDER OF THE TWO CHANGES. A loading screen is reached under a cover and left under another
## one, and the runner that leaves must not go while the one that arrived is still walking: the
## cover into the screen swaps to it at its own halfway mark, so a scene entered underneath it is
## replaced by the loading screen a moment later, with the runner already freed. That is a whole
## frame of tree state no headless run can build, so the pins are the lines themselves - the shape
## of the wait, read out of the pack the builder shipped.
static func _test_the_entry_waits_for_the_cover() -> bool:
	var shipped: String = FileAccess.get_file_as_string(PACK_PATH)
	return SUPPORT.pins(P, [
		["an entry asked for while a cover is walking is remembered rather than made",
			shipped.contains("\t\tif not get_tree().get_nodes_in_group(SceneFlowBehavior.TRANSITION_GROUP).is_empty():\n\t\t\t_entry_wanted = true\n\t\t\treturn"), true],
		["and it is made on the first frame the screen is clear again",
			shipped.contains("\t\tif _entry_wanted and not covered:\n\t\t\t_entry_wanted = false\n\t\t\tenter()"), true],
		["the plain swap under a running cover is gone",
			shipped.contains("if busy or word.is_empty()"), false],
		["and the shortest time is counted only while the loading screen is what is on screen",
			shipped.contains("\t\tif not covered:\n\t\t\t_elapsed += delta"), true],
	])


## THE STARTERS, which are files and not a list the pack owns. Both ship beside the script, and
## NEITHER is pointed at: the two knobs open empty, so a project that wants the shipped screen
## copies it and says so, and a project that wants its own never meets these at all.
static func _test_the_starters() -> bool:
	var shipped: String = FileAccess.get_file_as_string(PACK_PATH)
	var starter_tips: PackedStringArray = SceneFlowBehavior.loading_tip_lines(
		FileAccess.get_file_as_string(STARTER_TIPS))
	return SUPPORT.pins(P, [
		["a loading screen ships beside the pack", FileAccess.file_exists(STARTER_SCREEN), true],
		["and it holds the bar the rows set",
			FileAccess.get_file_as_string(STARTER_SCREEN).contains(
				"[node name=\"LoadBar\" type=\"ProgressBar\" parent=\".\"]"), true],
		["whose top is one, because that is what the reading answers with",
			FileAccess.get_file_as_string(STARTER_SCREEN).contains("max_value = 1.0"), true],
		# AND THE BAR MOVES. A starter whose bar sits at zero and whose tip label is empty teaches
		# the wrong thing about what these rows do, so the scene carries the three rows that drive
		# it - as an ordinary sheet the reader can open, not as machinery hidden in the pack.
		["the screen carries a sheet of its own", FileAccess.file_exists(STARTER_SHEET), true],
		["which the scene really points at",
			FileAccess.get_file_as_string(STARTER_SCREEN).contains(
				"script = ExtResource(\"2_loading_screen\")"), true],
		["it sets the bar from the reading, every time the reading moves",
			_starter_sheet().contains("$SceneFlow.loading_progress_changed.connect(_on_loading_progress_changed)")
				and _starter_sheet().contains("$LoadBar.value = $SceneFlow.loading_progress()"), true],
		["it reads the tip once, when the screen opens",
			_starter_sheet().contains("$Tip.text = $SceneFlow.loading_tip()"), true],
		["and the press-any-key line waits for the end of the wait",
			_starter_sheet().contains("$SceneFlow.loading_finished.connect(_on_loading_finished)")
				and _starter_sheet().contains("$PressAnyKey.visible = true"), true],
		["a tips file ships beside it", FileAccess.file_exists(STARTER_TIPS), true],
		# The tips themselves rather than how many there are: a starter file is meant to be
		# rewritten, so a count would fail for the one change it is asking for, while the rule
		# under test - the file's own notes are left out and its first tip is the first line
		# shown - holds however many lines a project ends up keeping.
		["its own note about itself is not a tip",
			_starts_with_a_note(starter_tips), false],
		["and the first tip is the first line that is not one",
			starter_tips[0] if not starter_tips.is_empty() else "",
			"Hold the run button while you jump to clear the widest gaps."],
		["the screen knob opens empty, so nothing is pointed at either of them",
			shipped.contains("var loading_scene: String = \"\""), true],
		["and so does the tips knob",
			shipped.contains("var loading_tips_file: String = \"\""), true],
	])


## Whether any line the tips reader handed back is one of the file's own notes - the rule the
## starter file is shipped to demonstrate, asked of the shipped file itself.
static func _starts_with_a_note(tips: PackedStringArray) -> bool:
	for tip: String in tips:
		if tip.begins_with("#"):
			return true
	return false


## The starter screen's own sheet, read off disk - the three rows the scene is shipped wired to.
static func _starter_sheet() -> String:
	return FileAccess.get_file_as_string(STARTER_SHEET)


## THE DOCTOR'S QUIET NOTE: a big scene opened with nothing over it. It is an info note with the
## door in its words, because hard-cutting into a big scene is a CHOICE - a splash screen that
## should cut is allowed to stay exactly as it is - and the sheet itself says nothing at all.
static func _test_the_doctor_note() -> bool:
	var big: Dictionary = {"res://levels/forest.tscn": ONE_MEGABYTE * 2}
	var found: Array[Dictionary] = EventSheetShipItDoctor.loading_screen_findings(
		{"res://menu.gd": PLAIN_SWAP_SOURCE}, big)
	var small: Array[Dictionary] = EventSheetShipItDoctor.loading_screen_findings(
		{"res://menu.gd": PLAIN_SWAP_SOURCE}, {"res://levels/forest.tscn": 4096})
	var all_passed: bool = SUPPORT.pins(P, [
		["the engine's own swap names the scene it opens",
			EventSheetShipItDoctor.plainly_opened_scenes(PLAIN_SWAP_SOURCE),
			PackedStringArray(["res://levels/forest.tscn"])],
		["and so does the pack verb that wraps it",
			EventSheetShipItDoctor.plainly_opened_scenes(PACK_SWAP_SOURCE),
			PackedStringArray(["res://levels/cavern.tscn"])],
		["a swap that is commented out is not a swap",
			EventSheetShipItDoctor.plainly_opened_scenes(
				"# get_tree().change_scene_to_file(\"res://levels/forest.tscn\")\n"),
			PackedStringArray()],
		["a swap through a variable names nothing, because nothing can be sized",
			EventSheetShipItDoctor.plainly_opened_scenes(
				"\tget_tree().change_scene_to_file(next_path)\n"), PackedStringArray()],
		["the same scene opened twice is named once",
			EventSheetShipItDoctor.plainly_opened_scenes(
				PLAIN_SWAP_SOURCE + PLAIN_SWAP_SOURCE),
			PackedStringArray(["res://levels/forest.tscn"])],
		["a small scene earns no note", small.size(), 0],
		["a big one earns exactly one", found.size(), 1],
	])
	if found.is_empty():
		return false
	var note: Dictionary = found[0]
	return SUPPORT.pins(P, [
		["it is filed under the loading check", str(note.get("check", "")), "ship-loading-screen"],
		["as a note rather than a warning", str(note.get("severity", "")), "info"],
		["against the script that opens the scene", str(note.get("path", "")), "res://menu.gd"],
		["about the scene itself", str(note.get("subject", "")), "res://levels/forest.tscn"],
		["and it says the size it measured", str(note.get("message", "")).contains("2.0 MB"), true],
		["and names the door out", str(note.get("message", "")).contains(
			"Go To Scene With Loading"), true],
	]) and all_passed
