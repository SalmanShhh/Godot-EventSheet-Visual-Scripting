# Godot EventSheets - working with sheets: live edit, the replay recorder, the conflict view and
# shared sheets (batch 11, V8-V11).
#
# Four features that all live one step outside the reading: what you do WITH a sheet once it reads.
# Each of them keeps its decision in a plain, editor-free module precisely so it can be pinned here,
# by VALUE, with no editor, no running game and no git:
#
#  - V8 live edit: the running game is a seam (`EventSheetLiveEdit.running_probe`), so "what does
#    the strip say" and "can this change be reloaded" are ordinary questions with exact answers.
#  - V9 replay recorder: a take is a list of controls with frames, and the sheet it writes is an
#    ordinary Test sheet whose rows compile - so the rows are pinned AND compiled here.
#  - V10 conflict view: a fixture with real merge markers is read into two columns, picked per
#    event, and written back with the bytes outside the region untouched.
#  - V11 shared sheets: including one as a base class rewrites one line; including one as a helper
#    writes the member and the forwarding rows, and the Doctor's question about two includes
#    handling the same trigger is answered off the sources alone.
@tool
class_name WorkingWithSheetsTest
extends RefCounted

const COMPILE_PATH := "user://ef_working_with_sheets_compile.gd"


static func run() -> bool:
	var passed: bool = true
	passed = _test_nothing_happens_unless_the_game_is_running() and passed
	passed = _test_an_ordinary_change_reloads() and passed
	passed = _test_a_retyped_variable_cannot_be_reloaded() and passed
	passed = _test_a_removed_function_cannot_be_reloaded() and passed
	passed = _test_a_paused_run_applies_on_resume() and passed
	passed = _test_the_changed_rows_are_the_ones_that_pulse() and passed
	passed = _test_a_take_reads_as_frame_addressed_rows() and passed
	passed = _test_a_take_writes_a_test_sheet_that_compiles() and passed
	passed = _test_a_drift_names_its_frame() and passed
	passed = _test_a_conflicted_file_reads_as_two_columns() and passed
	passed = _test_a_conflict_is_picked_per_event() and passed
	passed = _test_resolving_leaves_the_rest_of_the_file_alone() and passed
	passed = _test_the_doctor_lists_remaining_conflicts() and passed
	passed = _test_a_shared_sheet_declares_how_it_is_wired() and passed
	passed = _test_including_as_a_base_class_rewrites_one_line() and passed
	passed = _test_including_as_a_helper_writes_the_forwarding_rows() and passed
	passed = _test_two_includes_on_one_trigger_are_reported() and passed
	return passed


# ── V8 live edit ──────────────────────────────────────────────────────────────────────────
## The whole affordance is gated on a running game. With nothing running the strip says nothing at
## all: a button that can never do anything is worse than no button.
static func _test_nothing_happens_unless_the_game_is_running() -> bool:
	EventSheetLiveEdit.running_probe = func() -> bool: return false
	var ok: bool = _check("no running game, no offer", EventSheetLiveEdit.status_text(true), "")
	var plan: Dictionary = EventSheetLiveEdit.plan("var hp = 3", "var hp = 4")
	ok = _check("the plan knows nothing is running", bool(plan["running"]), false) and ok
	ok = _check("and offers nothing", str(plan["message"]), "") and ok
	EventSheetLiveEdit.running_probe = func() -> bool: return true
	ok = _check("a running game with no edit still offers nothing",
		EventSheetLiveEdit.status_text(false), "") and ok
	_clear_probes()
	return ok


## A changed value, a new variable, a rewritten function: the everyday edit, and it reloads.
static func _test_an_ordinary_change_reloads() -> bool:
	EventSheetLiveEdit.running_probe = func() -> bool: return true
	var before: String = "var speed := 200.0\n\n\nfunc jump() -> void:\n\tpass\n"
	var after: String = "var speed := 260.0\nvar coyote := 0.1\n\n\nfunc jump() -> void:\n\tvelocity.y = -400.0\n"
	var plan: Dictionary = EventSheetLiveEdit.plan(before, after)
	var ok: bool = _check("an ordinary change reloads", bool(plan["can_reload"]), true)
	ok = _check("and the strip offers it in the sheet's words", str(plan["message"]),
		"⟳ Apply to running game (Ctrl+Alt+S)") and ok
	ok = _check("no Restart is pushed", bool(plan["offer_restart"]), false) and ok
	ok = _check("what the strip says once it lands", EventSheetLiveEdit.applied_text(2),
		"Applied to the running game - 2 events changed.") and ok
	_clear_probes()
	return ok


## The running instance still holds a value of the OLD type, so this one is honest about failing.
static func _test_a_retyped_variable_cannot_be_reloaded() -> bool:
	EventSheetLiveEdit.running_probe = func() -> bool: return true
	var plan: Dictionary = EventSheetLiveEdit.plan("var lives := 3\n", "var lives := \"three\"\n")
	var ok: bool = _check("a retyped variable stops the reload", bool(plan["can_reload"]), false)
	ok = _check("the strip says which one and how", str(plan["message"]),
		"This change can't be applied to the running game: a variable changed type (lives is now String, not int). Restart to pick it up.") and ok
	ok = _check("and offers Restart", bool(plan["offer_restart"]), true) and ok
	ok = _check("a value change on the same variable is fine",
		EventSheetLiveEdit.blockers("var lives := 3\n", "var lives := 5\n").size(), 0) and ok
	_clear_probes()
	return ok


## Something may be standing inside the function that is gone.
static func _test_a_removed_function_cannot_be_reloaded() -> bool:
	EventSheetLiveEdit.running_probe = func() -> bool: return true
	var before: String = "func jump() -> void:\n\tpass\n\n\nfunc land() -> void:\n\tpass\n"
	var plan: Dictionary = EventSheetLiveEdit.plan(before, "func jump() -> void:\n\tpass\n")
	var ok: bool = _check("a removed function stops the reload", bool(plan["can_reload"]), false)
	ok = _check("the strip names it", str(plan["message"]),
		"This change can't be applied to the running game: the function land was removed and may be running. Restart to pick it up.") and ok
	ok = _check("a RENAMED body is not a removal",
		EventSheetLiveEdit.blockers(before, before.replace("pass", "return")).size(), 0) and ok
	_clear_probes()
	return ok


## Paused at a row, an edit is real - it simply lands when the game moves again, and the strip says
## so instead of pretending the button does nothing.
static func _test_a_paused_run_applies_on_resume() -> bool:
	EventSheetLiveEdit.running_probe = func() -> bool: return true
	EventSheetLiveEdit.paused_probe = func() -> bool: return true
	var ok: bool = _check("paused at a row, the edit applies on resume",
		EventSheetLiveEdit.status_text(true), "⟳ Applies when the game resumes (paused at a row)")
	_clear_probes()
	return ok


## Only what the reader can SEE change pulses: a save that changed nothing visible flashes nothing.
static func _test_the_changed_rows_are_the_ones_that_pulse() -> bool:
	var before: EventSheetResource = _two_event_sheet("120")
	var after: EventSheetResource = _two_event_sheet("200")
	var changed: PackedStringArray = EventSheetLiveEdit.changed_event_uids(before, after)
	var ok: bool = _check("one row changed, one row pulses", changed.size(), 1)
	ok = _check("and it is the one that changed", changed[0] if changed.size() > 0 else "", "moved") and ok
	ok = _check("an unchanged save pulses nothing",
		EventSheetLiveEdit.changed_event_uids(before, _two_event_sheet("120")).size(), 0) and ok
	return ok


# ── V9 the replay recorder ────────────────────────────────────────────────────────────────
## A take reads back as the rows it will become, in frame order, with the checkpoint slotted in.
static func _test_a_take_reads_as_frame_addressed_rows() -> bool:
	var recorder: EventSheetReplayRecorder = _recorded_take()
	var lines: PackedStringArray = recorder.take_lines()
	var ok: bool = _check("three rows recorded", lines.size(), 3)
	ok = _check("the press reads with its frame", lines[0], "simulate control jump pressed at frame 12") and ok
	ok = _check("the release reads with its frame", lines[1], "simulate control jump released at frame 19") and ok
	ok = _check("the checkpoint reads with its frame", lines[2], "expect hp = 90 at frame 300") and ok
	ok = _check("the take knows how long it is", recorder.length_in_frames(), 300) and ok
	var ignored: EventSheetReplayRecorder = EventSheetReplayRecorder.new()
	ignored.record_control("jump", true, 40)
	ok = _check("nothing is recorded while Record is up", ignored.entries.size(), 0) and ok
	return ok


## The sheet a take writes is an ORDINARY Test sheet: the runner's marker, the runner's trigger, and
## rows that really compile to the frame waits and control presses they read as.
static func _test_a_take_writes_a_test_sheet_that_compiles() -> bool:
	var sheet: EventSheetResource = _recorded_take().to_test_sheet("Jump Run")
	var ok: bool = _check("the recording is a test sheet", sheet.test_mode, true)
	ok = _check("its one event is the runner's trigger",
		(sheet.events[0] as EventRow).trigger_id, "OnTestStart") and ok
	ok = _check("with a row per entry", (sheet.events[0] as EventRow).actions.size(), 3) and ok
	var source: String = _compile(sheet)
	ok = _check("the marker a runner finds it by", source.contains("## @ace_test_sheet"), true) and ok
	ok = _check("the press waits for its frame first",
		source.contains("while Engine.get_frames_drawn() - int(get_meta(&\"__ef_replay_frame0\", 0)) < int(12):"), true) and ok
	ok = _check("then presses the control", source.contains("Input.action_press(\"jump\")"), true) and ok
	ok = _check("and lets it go later", source.contains("Input.action_release(\"jump\")"), true) and ok
	ok = _check("the checkpoint compares at its frame",
		source.contains("at frame %s expected %s, got %s"), true) and ok
	return ok


## A drift has to say the frame it drifted on - "expected 90, got 74" cannot be reproduced.
static func _test_a_drift_names_its_frame() -> bool:
	var ok: bool = _check("the Doctor's words for a drift",
		EventSheetReplayRecorder.drift_message("hp after the fall", 300, "simulate control jump pressed at frame 12"),
		"Replay drifted at frame 300: hp after the fall (after \"simulate control jump pressed at frame 12\").")
	ok = _check("the frame is read back out of the runner's message",
		EventSheetReplayRecorder.frame_in_message("at frame 300 expected 90, got 74"), 300) and ok
	ok = _check("an ordinary assertion failure is not dressed up as a drift",
		EventSheetReplayRecorder.frame_in_message("expected 3, got 2"), -1) and ok
	return ok


# ── V10 the conflict view ─────────────────────────────────────────────────────────────────
## The conflicted region reads as two columns: what both sides agree on is greyed (nothing to
## decide), and only the differing pairs are a question.
static func _test_a_conflicted_file_reads_as_two_columns() -> bool:
	var regions: Array[Dictionary] = EventSheetConflictRegions.find(_conflicted_source())
	var ok: bool = _check("one region found", regions.size(), 1)
	if regions.is_empty():
		return false
	ok = _check("the merge's own labels are kept", EventSheetConflictRegions.region_heading(regions[0]),
		"Conflict 1: HEAD against feature/jump") and ok
	var rows: Array[Dictionary] = EventSheetConflictRegions.side_by_side(regions[0])
	ok = _check("two pairs of events", rows.size(), 2) and ok
	ok = _check("the shared one is greyed", bool(rows[0]["same"]), true) and ok
	ok = _check("the differing one is the question", bool(rows[1]["same"]), false) and ok
	ok = _check("and each column names its event",
		str((rows[1]["ours"] as Dictionary)["label"]), "func jump() -> void:") and ok
	return ok


## Per EVENT, not per file: keep ours here, theirs there, both where both are wanted.
static func _test_a_conflict_is_picked_per_event() -> bool:
	var regions: Array[Dictionary] = EventSheetConflictRegions.find(_conflicted_source())
	var kept_theirs: PackedStringArray = EventSheetConflictRegions.resolved_lines(regions[0],
		["ours", EventSheetConflictRegions.KEEP_THEIRS])
	var ok: bool = _check("keeping theirs takes their body",
		"\n".join(kept_theirs).contains("velocity.y = -520.0"), true)
	ok = _check("and drops ours", "\n".join(kept_theirs).contains("velocity.y = -400.0"), false) and ok
	var kept_both: PackedStringArray = EventSheetConflictRegions.resolved_lines(regions[0],
		["ours", EventSheetConflictRegions.KEEP_BOTH])
	ok = _check("keeping both keeps ours first",
		"\n".join(kept_both).contains("velocity.y = -400.0"), true) and ok
	ok = _check("and theirs after it", "\n".join(kept_both).contains("velocity.y = -520.0"), true) and ok
	ok = _check("the agreed event is written once either way",
		"\n".join(kept_both).count("func land() -> void:"), 1) and ok
	return ok


## The promise that makes this safe to offer at all: everything outside the region comes back byte
## for byte, and the markers are the only lines that disappear.
static func _test_resolving_leaves_the_rest_of_the_file_alone() -> bool:
	var source: String = _conflicted_source()
	var resolved: String = str(EventSheetConflictRegions.resolve(source, [["ours", "ours"]])["text"])
	var ok: bool = _check("no markers survive", EventSheetConflictRegions.has_conflicts(resolved), false)
	ok = _check("the head is untouched", resolved.begins_with("extends CharacterBody2D\n\nvar speed := 200.0\n"), true) and ok
	ok = _check("the tail is untouched", resolved.ends_with("func _ready() -> void:\n\tspeed = 200.0\n"), true) and ok
	ok = _check("an unanswered region is left exactly as it was",
		str(EventSheetConflictRegions.resolve(source, [])["text"]), source) and ok
	return ok


## The Doctor's sentence about a file still holding markers, in the words the view offers.
static func _test_the_doctor_lists_remaining_conflicts() -> bool:
	var regions: Array[Dictionary] = EventSheetConflictRegions.find(_conflicted_source())
	var ok: bool = _check("one conflict, named", EventSheetConflictRegions.doctor_message(regions, "player.gd"),
		"player.gd still has an unresolved merge conflict - open it and pick per event (Keep ours / Keep theirs / Keep both).")
	ok = _check("a clean file has none", EventSheetConflictRegions.has_conflicts("extends Node\n"), false) and ok
	return ok


# ── V11 shared event sheets ───────────────────────────────────────────────────────────────
## A shared sheet says what it is and how it is wired, in its own header, once.
static func _test_a_shared_sheet_declares_how_it_is_wired() -> bool:
	var helper: String = EventSheetSharedSheets.new_shared_sheet_source("Pause Handling", EventSheetSharedSheets.WIRING_HELPER)
	var ok: bool = _check("a helper says so", EventSheetSharedSheets.wiring_of(helper), "helper")
	ok = _check("and reads in the menu's words", EventSheetSharedSheets.wiring_words("helper"), "as a helper") and ok
	ok = _check("its class name is the display name as one word",
		EventSheetSharedSheets.class_name_of(helper), "PauseHandling") and ok
	ok = _check("and it starts with something to forward to",
		EventSheetSharedSheets.handlers_of(helper), PackedStringArray(["on_tick"])) and ok
	var base: String = EventSheetSharedSheets.new_shared_sheet_source("Pause Handling", EventSheetSharedSheets.WIRING_BASE_CLASS)
	ok = _check("a base class says so", EventSheetSharedSheets.wiring_of(base), "base_class") and ok
	ok = _check("and reads in the menu's words", EventSheetSharedSheets.wiring_words("base_class"), "as a base class") and ok
	ok = _check("an ordinary script is not a shared sheet",
		EventSheetSharedSheets.is_shared_sheet("extends Node\n"), false) and ok
	return ok


## Base-class wiring is one line: the `extends` the includer already had, pointed at the shared one.
static func _test_including_as_a_base_class_rewrites_one_line() -> bool:
	var shared: String = EventSheetSharedSheets.new_shared_sheet_source("Pause Handling", EventSheetSharedSheets.WIRING_BASE_CLASS)
	var result: Dictionary = EventSheetSharedSheets.apply_include(
		"extends Node\n\nvar hp := 10\n", shared, "res://pause_handling.gd")
	var ok: bool = _check("the include lands", bool(result["ok"]), true)
	ok = _check("as one rewritten line", str(result["text"]), "extends PauseHandling\n\nvar hp := 10\n") and ok
	ok = _check("and says which wiring it used", str(result["wiring"]), "base_class") and ok
	var twice: Dictionary = EventSheetSharedSheets.apply_include(str(result["text"]), shared, "res://pause_handling.gd")
	ok = _check("including it twice is refused, in words", str(twice["error"]),
		"This script already includes PauseHandling.") and ok
	return ok


## Helper wiring is composition: one member, and one forwarding function per handler the shared
## sheet actually declares - the rows the sheet writes so nobody has to.
static func _test_including_as_a_helper_writes_the_forwarding_rows() -> bool:
	var shared: String = "%s(helper)\nclass_name PauseHandling\nextends RefCounted\n\n\nfunc on_tick(host: Node, delta: float) -> void:\n\tpass\n\n\nfunc on_input(host: Node, event: InputEvent) -> void:\n\tpass\n" % EventSheetSharedSheets.MARKER
	var result: Dictionary = EventSheetSharedSheets.apply_include(
		"extends Node\n\nvar hp := 10\n", shared, "res://pause_handling.gd")
	var ok: bool = _check("the include lands", bool(result["ok"]), true)
	ok = _check("as composition, with the whole file kept", str(result["text"]),
		"extends Node\n\nvar _pause_handling := PauseHandling.new()\n\n\nfunc _process(delta: float) -> void:\n\t_pause_handling.on_tick(self, delta)\n\n\nfunc _input(event: InputEvent) -> void:\n\t_pause_handling.on_input(self, event)\n\n\nvar hp := 10\n") and ok
	ok = _check("only the handlers it has are forwarded",
		str(result["text"]).contains("on_ready"), false) and ok
	var not_shared: Dictionary = EventSheetSharedSheets.apply_include("extends Node\n", "extends Node\n", "res://plain.gd")
	ok = _check("a script that is not a shared sheet says so", str(not_shared["error"]),
		"plain.gd is not a shared sheet - make one with Sheet > New shared sheet….") and ok
	return ok


## The one confusion a reader of the INCLUDER cannot see, because neither handler is written there.
static func _test_two_includes_on_one_trigger_are_reported() -> bool:
	var sources: Dictionary = {
		"PauseHandling": "%s(helper)\nclass_name PauseHandling\nfunc on_tick(host: Node, delta: float) -> void:\n\tpass\n" % EventSheetSharedSheets.MARKER,
		"CheatKeys": "%s(helper)\nclass_name CheatKeys\nfunc on_tick(host: Node, delta: float) -> void:\n\tpass\n" % EventSheetSharedSheets.MARKER,
	}
	var includer: String = "extends Node\nvar _pause_handling := PauseHandling.new()\nvar _cheat_keys := CheatKeys.new()\n"
	var found: Array[Dictionary] = EventSheetSharedSheets.includes_in(includer, sources)
	var ok: bool = _check("both includes are seen", found.size(), 2)
	var messages: PackedStringArray = EventSheetSharedSheets.duplicate_trigger_messages(includer, sources)
	ok = _check("and the clash is one finding", messages.size(), 1) and ok
	ok = _check("worded so the reader knows which one wins", messages[0] if messages.size() > 0 else "",
		"Two included sheets handle Every tick - PauseHandling and CheatKeys. Both run, in include order, and the last one wins.") and ok
	ok = _check("one include on its own is silent",
		EventSheetSharedSheets.duplicate_trigger_messages(
			"extends Node\nvar _pause_handling := PauseHandling.new()\n", sources).size(), 0) and ok
	return ok


# ── fixtures ──────────────────────────────────────────────────────────────────────────────
static func _clear_probes() -> void:
	EventSheetLiveEdit.running_probe = Callable()
	EventSheetLiveEdit.paused_probe = Callable()


static func _two_event_sheet(speed: String) -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	var still: EventRow = EventRow.new()
	still.event_uid = "still"
	still.trigger_id = "OnReady"
	sheet.events.append(still)
	var moved: EventRow = EventRow.new()
	moved.event_uid = "moved"
	moved.trigger_id = "OnReady"
	var action: ACEAction = ACEAction.new()
	action.ace_id = "SetVariable"
	action.params = {"value": speed}
	moved.actions.append(action)
	sheet.events.append(moved)
	return sheet


static func _recorded_take() -> EventSheetReplayRecorder:
	var recorder: EventSheetReplayRecorder = EventSheetReplayRecorder.new()
	recorder.start(1000)
	recorder.record_control("jump", true, 1012)
	recorder.record_control("jump", false, 1019)
	recorder.stop()
	recorder.add_checkpoint("hp after the fall", "hp", "90", 300)
	return recorder


static func _conflicted_source() -> String:
	return "\n".join(PackedStringArray([
		"extends CharacterBody2D",
		"",
		"var speed := 200.0",
		"",
		"<<<<<<< HEAD",
		"func land() -> void:",
		"\tvelocity.y = 0.0",
		"",
		"func jump() -> void:",
		"\tvelocity.y = -400.0",
		"=======",
		"func land() -> void:",
		"\tvelocity.y = 0.0",
		"",
		"func jump() -> void:",
		"\tvelocity.y = -520.0",
		">>>>>>> feature/jump",
		"",
		"func _ready() -> void:",
		"\tspeed = 200.0",
		"",
	]))


static func _compile(sheet: EventSheetResource) -> String:
	var result: Dictionary = SheetCompiler.compile(sheet, COMPILE_PATH)
	DirAccess.remove_absolute(COMPILE_PATH)
	return str(result.get("output", ""))


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] working_with_sheets_test: %s" % label)
		return true
	print("[FAIL] working_with_sheets_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
