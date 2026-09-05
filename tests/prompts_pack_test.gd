# Godot EventSheets - the Prompts pack, driven directly.
#
# A quick-time prompt is a machine made of moments: when the window opened, when it closes, when
# the player pressed, how far off the beat a note was. None of those can be seen in a screenshot
# and none of them can be reached through a scene tree in this suite, so this file loads the
# COMPILED pack, drives the real director with no tree, no input device and nothing drawn, and pins
# the values it produces at hand-stepped moments.
#
# Everything the director DECIDES is a plain function of a moment and its own state - the drawing
# half is the only part that needs a node - which is what lets a whole prompt be opened, answered
# and graded here in three calls.
#
# The traps it exists to catch, each one a rule the pack states and a reader would otherwise have
# to trust:
#   - the pack is the Prompts autoload, and every row it emits addresses it by that name;
#   - a timed prompt grades on how much of its window was LEFT, so answering at once is perfect and
#     answering at the last moment is good, and a window of no length grades rather than dividing
#     by nothing;
#   - a hold that was let go is not a hold, and starts again from nothing;
#   - a mash counts presses and lands on the one that reaches the count, not the one after;
#   - a note is graded by how far the press was from its own moment, either side of it, and a press
#     beyond the hit window is not an answer to that note at all;
#   - a note whose moment has gone past answering is a miss, once, and leaves the lane;
#   - two notes for one control are answered nearest-moment first, not spawn-order first;
#   - the beat a note lands on is the song's when a Music director answers, and the lead when
#     nothing does, so the pack works alone;
#   - a sequence ends once, either way, and its progress counts what was ANSWERED;
#   - a glyph falls back from the layout in hand to the generic pad to the keyboard, so a
#     half-drawn sheet has holes rather than crashes;
#   - a player who has asked for no flashing gets a small slow fade rather than no answer at all;
#   - the two starter scenes and the plain glyph sheet ship beside the script.
@tool
class_name PromptsPackTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const PACK := "res://eventsheet_addons/prompts/prompts_addon.gd"
const GLYPH_RESOURCE := "res://eventsheet_addons/glyph_sheet_resource/glyph_sheet_resource.gd"
const PROMPT_SCENE := "res://eventsheet_addons/prompts/prompt.tscn"
const LANE_SCENE := "res://eventsheet_addons/prompts/lane.tscn"
const STARTER_SHEET := "res://eventsheet_addons/prompts/plain_glyphs.tres"
const TEST := "prompts_pack_test"


static func run() -> bool:
	var script: GDScript = load(PACK)
	var passed: bool = SUPPORT.check(TEST, "the pack loads and parses", script != null, true)
	if script == null:
		return passed
	passed = _the_pack_ships_as_the_autoload(script) and passed
	passed = _a_timed_prompt_grades_on_what_was_left(script) and passed
	passed = _a_press_lands_and_a_deadline_misses(script) and passed
	passed = _a_hold_that_was_let_go_starts_again(script) and passed
	passed = _a_mash_lands_on_the_press_that_reaches_the_count(script) and passed
	passed = _a_sequence_ends_once_either_way(script) and passed
	passed = _a_note_is_graded_against_its_own_moment(script) and passed
	passed = _notes_travel_and_expire(script) and passed
	passed = _the_beat_comes_from_the_song_or_from_the_lead(script) and passed
	passed = _glyphs_are_looked_up_per_device(script) and passed
	passed = _no_flashing_clamps_the_flash(script) and passed
	passed = _the_starters_ship() and passed
	passed = _the_press_that_opened_a_prompt_is_not_its_answer(script) and passed
	passed = _a_sequence_over_a_sequence_ends_the_first(script) and passed
	return passed


# ── One director, reached from anywhere ───────────────────────────────────────────────────────


## One prompt at a time, for the whole game, is the point of the pack - so it ships as the Prompts
## AUTOLOAD the way Music and Scene Flow do. That is not a remark about the file: it is what every
## row the pack emits ADDRESSES, so it is pinned against the shipped bytes rather than against the
## builder's intent.
static func _the_pack_ships_as_the_autoload(script: GDScript) -> bool:
	var source: String = FileAccess.get_file_as_string(PACK)
	var not_the_autoload: int = 0
	var published: PackedStringArray = PackedStringArray()
	var moments: PackedStringArray = PackedStringArray()
	for line: String in source.split("\n"):
		if not line.begins_with("## @ace_codegen_template("):
			continue
		if not line.begins_with("## @ace_codegen_template(\"Prompts."):
			not_the_autoload += 1
			continue
		published.append(line.substr(line.find("Prompts.") + 8).split("(")[0])
	for line: String in source.split("\n"):
		if line.begins_with("signal "):
			moments.append(line.substr(7).split("(")[0])
	return SUPPORT.pins(TEST, [
		["every published verb addresses the autoload by name", not_the_autoload, 0],
		# NAMED, not counted: a pin on the number goes green on a run where one row arrived and
		# another went missing, and says nothing about either.
		["and every verb the builder declares is one of them", _sorted(published),
			["cancel_prompt", "device", "force_device", "glyph_for", "grade_is", "hold_prompt",
				"last_grade", "mash_prompt", "prompt", "prompt_is_open", "prompt_on_beat",
				"prompt_time_left", "sequence", "sequence_progress"]],
		["with its three moments beside them", _sorted(moments),
			["prompt_hit", "prompt_missed", "sequence_finished"]],
		["nothing is scoped to a node, because an autoload has no host to act on",
			source.contains("var host: Node"), false],
		["the grades are the Timed Input rows' own two words plus the miss",
			source.contains("const GRADE_PERFECT: String = \"perfect\"")
				and source.contains("const GRADE_GOOD: String = \"good\"")
				and source.contains("const GRADE_MISS: String = \"miss\""), true],
	])


# ── The moment ────────────────────────────────────────────────────────────────────────────────


## A timed prompt is graded on how much of its window was still LEFT. Answering at once kept nearly
## all of it and is perfect; answering at the last moment kept none and is good. That grades
## reaction rather than nerve, which is what a quick-time event is asking about - and a window of no
## length grades good rather than dividing by nothing.
static func _a_timed_prompt_grades_on_what_was_left(script: GDScript) -> bool:
	var director: Node = script.new()
	var at_once: String = director.timed_grade(10.0, 10.0, 11.0, 0.5)
	var on_the_line: String = director.timed_grade(10.5, 10.0, 11.0, 0.5)
	var just_after: String = director.timed_grade(10.6, 10.0, 11.0, 0.5)
	var at_the_last: String = director.timed_grade(10.99, 10.0, 11.0, 0.5)
	var strict: String = director.timed_grade(10.5, 10.0, 11.0, 0.9)
	var no_window: String = director.timed_grade(10.0, 10.0, 10.0, 0.5)
	director.free()
	return SUPPORT.pins(TEST, [
		["answering the moment it opens is perfect", at_once, "perfect"],
		["half a window left is still perfect, because the share is what is asked for",
			on_the_line, "perfect"],
		["a moment past halfway is good", just_after, "good"],
		["and the very last moment is good", at_the_last, "good"],
		["a stricter share moves the line without changing the words", strict, "good"],
		["a window of no length grades rather than dividing by nothing", no_window, "good"],
	])


## The two endings of an open prompt: the press that lands, and the deadline that goes by with
## nothing pressed. Both carry the control they were asking for, which is what lets one hit reaction
## and one punish serve every prompt in a game.
static func _a_press_lands_and_a_deadline_misses(script: GDScript) -> bool:
	var director: Node = script.new()
	var hits: Array = []
	var misses: Array = []
	director.prompt_hit.connect(func(action: String, grade: String) -> void: hits.append([action, grade]))
	director.prompt_missed.connect(func(action: String) -> void: misses.append(action))
	director.prompt("ui_accept", 1.0, null)
	var opened: bool = director.prompt_is_open()
	var opened_at: float = director._opened_at
	var left_at_the_start: float = director._deadline - opened_at
	director.step(opened_at + 0.1, 0.016, true, false)
	var still_open: bool = director.prompt_is_open()
	var graded: String = director.last_grade()
	var asked_about: bool = director.grade_is("perfect")
	director.prompt("ui_cancel", 0.5, null)
	var second_deadline: float = director._deadline
	director.step(second_deadline, 0.016, false, false)
	var after_the_deadline: String = director.last_grade()
	var nothing_left: float = director.prompt_time_left()
	director.free()
	return SUPPORT.pins(TEST, [
		["a prompt opens and is open", opened, true],
		["for the seconds it was given", _round(left_at_the_start), 1.0],
		["a press closes it", still_open, false],
		["with a grade", graded, "perfect"],
		["that Grade Is asks about in the same word", asked_about, true],
		["and the trigger carries the control and the grade",
			", ".join(PackedStringArray([str(hits[0][0]), str(hits[0][1])] if hits.size() == 1 else ["none"])),
			"ui_accept, perfect"],
		["the deadline going by grades a miss", after_the_deadline, "miss"],
		["and the trigger carries the control nobody pressed",
			", ".join(PackedStringArray(misses)), "ui_cancel"],
		["nothing is open, so there is no time left to read", _round(nothing_left), 0.0],
	])


## A hold that survived being let go is not a hold. Letting go puts the count back to nothing, so
## the player has to keep it down rather than tap it while the window lasts.
static func _a_hold_that_was_let_go_starts_again(script: GDScript) -> bool:
	var director: Node = script.new()
	var hits: Array = []
	director.prompt_hit.connect(func(_action: String, grade: String) -> void: hits.append(grade))
	director.hold_prompt("ui_accept", 0.5, 3.0, null)
	var opened_at: float = director._opened_at
	director.step(opened_at + 0.25, 0.25, false, true)
	var quarter: float = director._held_for
	director.step(opened_at + 0.5, 0.25, false, false)
	var let_go: float = director._held_for
	var still_open: bool = director.prompt_is_open()
	director.step(opened_at + 0.75, 0.25, false, true)
	director.step(opened_at + 1.0, 0.25, false, true)
	var landed: bool = not director.prompt_is_open()
	director.free()
	return SUPPORT.pins(TEST, [
		["a quarter of a second held is a quarter of a second", _round(quarter), 0.25],
		["letting go puts it back to nothing", _round(let_go), 0.0],
		["and the prompt is still waiting rather than failed", still_open, true],
		["holding it long enough lands the prompt", landed, true],
		["once, with a grade", ", ".join(PackedStringArray(hits)), "perfect"],
	])


## A mash lands on the press that REACHES the count, not on the one after it - the difference
## between twelve presses and thirteen, which a player counting them out loud would notice.
static func _a_mash_lands_on_the_press_that_reaches_the_count(script: GDScript) -> bool:
	var director: Node = script.new()
	director.mash_prompt("ui_accept", 3, 3.0, null)
	var opened_at: float = director._opened_at
	director.step(opened_at + 0.1, 0.016, true, false)
	director.step(opened_at + 0.2, 0.016, true, false)
	var two_in: bool = director.prompt_is_open()
	var counted: int = director._mash_count
	director.step(opened_at + 0.3, 0.016, true, false)
	var landed: bool = not director.prompt_is_open()
	var graded: String = director.last_grade()
	director.free()
	return SUPPORT.pins(TEST, [
		["two of the three presses leave it open", two_in, true],
		["and are counted", counted, 2],
		["the third lands it", landed, true],
		["graded like any other answer in time", graded, "perfect"],
	])


## A sequence ends ONCE, either way, and its progress counts what has been ANSWERED - so a bar over
## a cutscene reads full on the frame the last control lands rather than on the frame after.
static func _a_sequence_ends_once_either_way(script: GDScript) -> bool:
	var director: Node = script.new()
	var endings: Array = []
	director.sequence_finished.connect(func(completed: bool) -> void: endings.append(completed))
	director.sequence("ui_left, ui_right, ui_accept", 1.0, null)
	var at_the_start: float = director.sequence_progress()
	var asking_for: String = director._action
	director.step(director._opened_at + 0.1, 0.016, true, false)
	var one_in: float = director.sequence_progress()
	var asking_next: String = director._action
	director.step(director._opened_at + 0.1, 0.016, true, false)
	director.step(director._opened_at + 0.1, 0.016, true, false)
	var finished: float = director.sequence_progress()
	director.free()
	var missed: Node = script.new()
	var missed_endings: Array = []
	missed.sequence_finished.connect(func(completed: bool) -> void: missed_endings.append(completed))
	missed.sequence("ui_left, ui_right", 1.0, null)
	missed.step(missed._deadline, 0.016, false, false)
	var stopped: bool = not missed.prompt_is_open()
	missed.free()
	return SUPPORT.pins(TEST, [
		["a sequence starts at no progress", _round(at_the_start), 0.0],
		["asking for the first control", asking_for, "ui_left"],
		["answering one is a third of the way", _round(one_in), 0.3333],
		["and moves on to the next control", asking_next, "ui_right"],
		["answering all three is the whole of it", _round(finished), 1.0],
		["and the trigger fires once, completed", ", ".join(PackedStringArray([str(endings[0])] if endings.size() == 1 else ["fired %d times" % endings.size()])), "true"],
		["a missed control ends the sequence there", stopped, true],
		["uncompleted, once", ", ".join(PackedStringArray([str(missed_endings[0])] if missed_endings.size() == 1 else ["fired %d times" % missed_endings.size()])), "false"],
	])


# ── On the beat ───────────────────────────────────────────────────────────────────────────────


## A note is graded by how far the press was from its own moment, either side of it - early and late
## count the same, because being early is as wrong as being late by the same amount. Beyond the hit
## window the press is not an answer to that note at all, which is what lets a player be early on a
## rhythm lane without being punished for it.
static func _a_note_is_graded_against_its_own_moment(script: GDScript) -> bool:
	var director: Node = script.new()
	var dead_on: String = director.beat_grade(4.0, 4.0, 0.08, 0.25)
	var a_little_early: String = director.beat_grade(3.95, 4.0, 0.08, 0.25)
	var a_little_late: String = director.beat_grade(4.05, 4.0, 0.08, 0.25)
	var outside_perfect: String = director.beat_grade(4.15, 4.0, 0.08, 0.25)
	var outside_everything: String = director.beat_grade(4.4, 4.0, 0.08, 0.25)
	var perfect_seconds: float = director.window_seconds(80)
	var hit_seconds: float = director.window_seconds(250)
	director.free()
	return SUPPORT.pins(TEST, [
		["a press on the moment is perfect", dead_on, "perfect"],
		["a little early is perfect too", a_little_early, "perfect"],
		["and a little late is the same answer", a_little_late, "perfect"],
		["further out is good", outside_perfect, "good"],
		["and beyond the hit window it is no answer to this note", outside_everything, "miss"],
		["eighty milliseconds is eight hundredths of a second", _round(perfect_seconds), 0.08],
		["and two hundred and fifty is a quarter", _round(hit_seconds), 0.25],
	])


## Notes on a lane: how far along one is, when it is past answering, which of two a press belongs
## to, and what happens to it either way. Driven with no lane at all, because a note IS a control, a
## moment and a place - the node is only how it is drawn.
static func _notes_travel_and_expire(script: GDScript) -> bool:
	var director: Node = script.new()
	var hits: Array = []
	var misses: Array = []
	director.prompt_hit.connect(func(action: String, grade: String) -> void: hits.append([action, grade]))
	director.prompt_missed.connect(func(action: String) -> void: misses.append(action))
	var at_the_start: float = director.note_progress(2.0, 2.0, 4.0)
	var halfway: float = director.note_progress(3.0, 2.0, 4.0)
	var arrived: float = director.note_progress(4.5, 2.0, 4.0)
	var still_answerable: bool = director.note_expired(4.2, 4.0, 0.25)
	var past_answering: bool = director.note_expired(4.3, 4.0, 0.25)
	var moment: float = director.now() + 2.0
	director.add_note("ui_accept", moment, null)
	director.add_note("ui_accept", moment + 4.0, null)
	var nearest: int = director.nearest_note("ui_accept", moment)
	var none: int = director.nearest_note("ui_cancel", moment)
	director.step_notes(moment, "ui_accept")
	var left_on_the_lane: int = director._notes.size()
	director.step_notes(moment + 4.4, "")
	var swept: int = director._notes.size()
	director.free()
	return SUPPORT.pins(TEST, [
		["a note starts at the far end of its lane", _round(at_the_start), 0.0],
		["is halfway along halfway through", _round(halfway), 0.5],
		["and stops on the line rather than walking past it", _round(arrived), 1.0],
		["a note just past its moment can still be answered", still_answerable, false],
		["and one past the hit window cannot", past_answering, true],
		["a press belongs to the note whose moment is nearest", nearest, 0],
		["and belongs to no note when nothing is waiting for that control", none, -1],
		["answering one takes it off the lane", left_on_the_lane, 1],
		["with the grade on the trigger",
			", ".join(PackedStringArray([str(hits[0][0]), str(hits[0][1])] if hits.size() == 1 else ["none"])),
			"ui_accept, perfect"],
		["a note nobody answered leaves the lane too", swept, 0],
		["as a miss", ", ".join(PackedStringArray(misses)), "ui_accept"],
	])


## Where the moment a note lands on comes from: the song, when a Music director answers with its
## next beat, and the Lead Seconds when nothing does. That fallback is what makes the pack work in a
## project with no music at all, rather than dropping every note on the same frame it was spawned.
static func _the_beat_comes_from_the_song_or_from_the_lead(script: GDScript) -> bool:
	var director: Node = script.new()
	var from_the_song: float = director.beat_moment(10.0, 10.5, 1.0)
	var from_the_lead: float = director.beat_moment(10.0, 0.0, 1.0)
	var a_beat_already_gone: float = director.beat_moment(10.0, 9.5, 1.0)
	var no_lead_at_all: float = director.beat_moment(10.0, 0.0, 0.0)
	director.free()
	return SUPPORT.pins(TEST, [
		["a song's next beat is the moment the note lands on", _round(from_the_song), 10.5],
		["with no song it is a lead's worth of time from now", _round(from_the_lead), 11.0],
		["a beat already gone by is not a moment to aim at", _round(a_beat_already_gone), 11.0],
		["and a lead of nothing is still a moment in the future", _round(no_lead_at_all), 10.01],
	])


# ── The glyphs ────────────────────────────────────────────────────────────────────────────────


## Which picture stands for a control: the layout in the player's hands, falling back to the generic
## pad and then to the keyboard. The fallbacks are what make a half-drawn sheet a sheet with holes
## rather than a crash, and the device is read from the pad's own product name rather than from a
## table of every controller ever made.
static func _glyphs_are_looked_up_per_device(script: GDScript) -> bool:
	var director: Node = script.new()
	var sheet_script: GDScript = load(GLYPH_RESOURCE)
	var keyboard_only: Texture2D = PlaceholderTexture2D.new()
	var pad_only: Texture2D = PlaceholderTexture2D.new()
	var console_only: Texture2D = PlaceholderTexture2D.new()
	var sheet: Resource = sheet_script.new()
	sheet.sheet_name = "Fixture"
	sheet.keyboard = {"ui_accept": keyboard_only, "ui_cancel": keyboard_only}
	sheet.pad = {"ui_accept": pad_only}
	sheet.playstation = {"ui_accept": console_only}
	director.glyphs = sheet
	var from_the_layout: bool = director.glyph_in(sheet, "playstation", "ui_accept") == console_only
	var falls_back_to_the_pad: bool = director.glyph_in(sheet, "xbox", "ui_accept") == pad_only
	var falls_back_to_the_keyboard: bool = director.glyph_in(sheet, "xbox", "ui_cancel") == keyboard_only
	var nothing_drawn: bool = director.glyph_in(sheet, "keyboard", "ui_never_drawn") == null
	var no_sheet_at_all: bool = director.glyph_in(null, "keyboard", "ui_accept") == null
	var starts_on_the_keyboard: String = director.device()
	director.force_device("PlayStation")
	var forced: String = director.device()
	var forced_glyph: bool = director.glyph_for("ui_accept") == console_only
	director.force_device("auto")
	var handed_back: String = director.device()
	var known_layout: String = director.device_for_name("Xbox Series Controller")
	var another: String = director.device_for_name("Sony DualSense Wireless Controller")
	var a_third: String = director.device_for_name("Nintendo Switch Pro Controller")
	var unknown: String = director.device_for_name("Some Other Pad")
	director.free()
	return SUPPORT.pins(TEST, [
		["the layout in hand answers first", from_the_layout, true],
		["a layout that drew nothing for a control falls back to the generic pad",
			falls_back_to_the_pad, true],
		["and a pad that drew nothing falls back to the keyboard",
			falls_back_to_the_keyboard, true],
		["a control nobody drew has no picture", nothing_drawn, true],
		["and neither does a project with no sheet at all", no_sheet_at_all, true],
		["the device starts as the keyboard", starts_on_the_keyboard, "keyboard"],
		["Force Device fixes it, whatever case it was typed in", forced, "playstation"],
		["and the glyph follows it", forced_glyph, true],
		["\"auto\" hands it back to the last input event", handed_back, "keyboard"],
		["a pad's own product name says which layout it is", known_layout, "xbox"],
		["for each of the three", another, "playstation"],
		["that a game draws buttons for", a_third, "nintendo"],
		["and a pad naming none of them is the generic pad", unknown, "pad"],
	])


## A player who has asked for no flashing still has to be told the prompt landed, so the flash is
## clamped small and stretched slow rather than taken away. The same two numbers every effect in
## this project clamps to.
static func _no_flashing_clamps_the_flash(script: GDScript) -> bool:
	var director: Node = script.new()
	var ordinary: Vector2 = director.flash_for(1.0, 0.15, false)
	var quiet: Vector2 = director.flash_for(1.0, 0.15, true)
	var already_gentle: Vector2 = director.flash_for(0.1, 0.6, true)
	director.free()
	return SUPPORT.pins(TEST, [
		["an ordinary flash is as bright as it was asked to be", _round(ordinary.x), 1.0],
		["and as quick", _round(ordinary.y), 0.15],
		["no flashing clamps the brightness to the ceiling", _round(quiet.x), 0.3],
		["and stretches it to the slowest a flash may be", _round(quiet.y), 0.4],
		["a flash already gentler than the ceiling is left as it is",
			_round(already_gentle.x), 0.1],
		["and one already slower than the floor keeps its own time",
			_round(already_gentle.y), 0.6],
	])


# ── The starters ──────────────────────────────────────────────────────────────────────────────


## The pack draws nothing without them: the prompt scene it copies per prompt, the lane whose Note
## child every note is made of, and the one plain glyph sheet that makes the pack show something on
## the first run. All three ship beside the script rather than being described in a guide.
static func _the_starters_ship() -> bool:
	var prompt: PackedScene = load(PROMPT_SCENE) as PackedScene
	var lane: PackedScene = load(LANE_SCENE) as PackedScene
	var sheet: Resource = load(STARTER_SHEET)
	var named: Array = []
	if sheet != null and sheet.keyboard is Dictionary:
		named = (sheet.keyboard as Dictionary).keys()
		named.sort()
	return SUPPORT.pins(TEST, [
		["the prompt scene ships", prompt != null and prompt.can_instantiate(), true],
		["the lane ships", lane != null and lane.can_instantiate(), true],
		["the plain glyph sheet ships", sheet != null, true],
		["under the name that says what it is", str(sheet.sheet_name) if sheet != null else "", "Plain"],
		["drawing the two controls every Godot project already has",
			", ".join(PackedStringArray(named)), "ui_accept, ui_cancel"],
		["for the generic pad as well as the keyboard",
			sheet != null and (sheet.pad as Dictionary).has("ui_accept"), true],
		["and for each of the three console layouts",
			sheet != null and (sheet.xbox as Dictionary).has("ui_accept")
				and (sheet.playstation as Dictionary).has("ui_accept")
				and (sheet.nintendo as Dictionary).has("ui_accept"), true],
	])


## Floats compared at four decimal places, because a third of three is 0.33333334 and a pin against
## a literal 0.3333 would be red for no reason anybody could act on. Rounded by multiply-and-DIVIDE
## rather than by snappedf, which multiplies back up by the step and lands on the same number the
## pin was red for.
static func _round(value: float) -> float:
	return roundf(value * 10000.0) / 10000.0


## THE PRESS THAT OPENED A PROMPT IS NOT ITS ANSWER. "On jump just pressed -> Prompt jump" is how
## half of these rows will be written, and a control stays "just pressed" for the whole of the frame
## it went down on - so without a guard the prompt opens and lands perfect on that same frame, before
## anything is drawn, and a mash prompt starts with one press already counted.
static func _the_press_that_opened_a_prompt_is_not_its_answer(script: GDScript) -> bool:
	var director: Node = script.new()
	var on_the_opening_frame: bool = director.fresh_press(true, 12, 12)
	var on_the_next_frame: bool = director.fresh_press(true, 12, 13)
	var nothing_pressed: bool = director.fresh_press(false, 12, 13)
	# The whole shape, driven: a prompt opened BY a press, then stepped with that press still down.
	director.prompt("ui_accept", 1.0, null)
	var opened: int = director._opened_frame
	director.step(director._opened_at + 0.001, 0.016,
		director.fresh_press(true, opened, opened), false)
	var still_open: bool = director.prompt_is_open()
	director.step(director._opened_at + 0.1, 0.016,
		director.fresh_press(true, opened, opened + 1), false)
	var answered: bool = not director.prompt_is_open()
	var graded: String = director.last_grade()
	director.free()
	var masher: Node = script.new()
	masher.mash_prompt("ui_accept", 2, 1.0, null)
	var opened_at: int = masher._opened_frame
	masher.step(masher._opened_at + 0.001, 0.016,
		masher.fresh_press(true, opened_at, opened_at), false)
	var counted: int = masher._mash_count
	masher.free()
	return SUPPORT.pins(TEST, [
		["a press on the frame the prompt opened is not an answer", on_the_opening_frame, false],
		["the same press one frame later is", on_the_next_frame, true],
		["and no press is no answer whichever frame it is", nothing_pressed, false],
		["a prompt opened by a press of its own control is still waiting", still_open, true],
		["the next frame answers it", answered, true],
		["and grades it as the reaction it was", graded, "perfect"],
		["a mash does not count the press that opened it", counted, 0],
	])


## A SEQUENCE STARTED OVER A RUNNING ONE ends the first, uncompleted, the way a plain prompt does.
## Overwriting the queue in silence leaves a cutscene waiting on a trigger that never comes, which is
## the hardest kind of bug to find in a game.
static func _a_sequence_over_a_sequence_ends_the_first(script: GDScript) -> bool:
	var director: Node = script.new()
	var endings: Array = []
	director.sequence_finished.connect(func(completed: bool) -> void: endings.append(completed))
	director.sequence("ui_left, ui_right", 1.0, null)
	director.sequence("ui_accept", 1.0, null)
	var the_first_ended: String = str(endings[0]) if endings.size() == 1 else "fired %d times" % endings.size()
	var now_asking_for: String = director._action
	var progress: float = director.sequence_progress()
	# A sequence given no controls at all is not a reason to end the one that is running.
	director.sequence("   ", 1.0, null)
	var untouched: String = director._action
	var no_second_ending: int = endings.size()
	director.free()
	return SUPPORT.pins(TEST, [
		["the sequence that was running ends, uncompleted, once", the_first_ended, "false"],
		["and the new one is what the player is being asked for", now_asking_for, "ui_accept"],
		["starting again at no progress", _round(progress), 0.0],
		["a sequence with no controls in it changes nothing", untouched, "ui_accept"],
		["and ends nothing", no_second_ending, 1],
	])


## A list of names in one order, whatever order they were gathered in - so a pin reads as the names
## the pack publishes rather than as the order a file happens to hold them in.
static func _sorted(names: PackedStringArray) -> Array:
	var sorted: Array = Array(names)
	sorted.sort()
	return sorted
