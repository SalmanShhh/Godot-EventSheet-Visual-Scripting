@tool
class_name AnimationComboReadingTest
extends RefCounted

# Pins batch fourteen's animation-combo readings and the vocabulary behind them:
#
#   Y1  the hand-written combo DETECTOR - a pressed-list, a countdown that empties it, and a `match`
#       on the joined list - read as the Combo Box behaviour it is: the push and the window as one
#       Press input row, every arm of the match as its own On combo TRIGGER, and the clip each arm
#       plays as the Set animation row the sheet already had
#   Y2  the two timing tricks around it - the slice of one clip another move may cancel it in, the
#       three time-scale lines that are one hit-stop, and a press remembered for six frames
#   Y3  the animation-driven events - the sprite frame a clip reaches, and the function an
#       animation's METHOD TRACK calls, which no line of the script says anything about
#
# Six gates, in the order they matter:
#   1. the grammar's own values - one shape, one sentence, asserted literally;
#   2. the whole path - a hand-written file opened as a sheet, walked row by row;
#   3. the pattern registry - the new shape claimed on the events that own it;
#   4. the promise all of them rest on - the file still saves byte-identically;
#   5. the AUTHORED rows write the very lines the readings recognise (post-transform templates);
#   6. the other half of the contract - what an animation calls, and the Doctor that checks it.
#
# The source lives here as a string rather than in tests/fixtures/ for the same reason its sibling
# reading tests' sources do: the lifter's byte gate compares against what the COMPILER would emit,
# and the compiler puts ONE blank line between functions.
#
# WHAT A RUNNING GAME PROVED, and why it is not asserted here. `run_tests.gd` has no scene tree and
# no physics - its `_init` runs before the main loop exists - so nothing below can play an animation
# or watch a time scale move. The showcase these rows build was therefore driven by a throwaway
# NON-headless harness, and this is what it saw, so a later change that breaks any of it has a
# written record to fail against:
#
#   press("punch") x2 then press("kick")  ->  AnimationPlayer.current_animation == "uppercut"
#                                             and the combo buffer emptied (combo.size() == 0)
#   the uppercut's method track at 0.35 s ->  hits == 1, so the animation really did call the sheet
#   the hit frame's Hitstop row           ->  Engine.time_scale left 1.0 during the freeze and was
#                                             back at 1.0 sixty frames later - it lifts, every time
#   seek(0.45) then try_cancel()          ->  true, cancels == 1   (inside the 0.3 - 0.6 window)
#   seek(0.75) then try_cancel()          ->  false               (outside it)

const SOURCE_PATH := "user://eventforge_animation_combo_reading.gd"

const SOURCE: String = """extends CharacterBody2D

@onready var anim: AnimationPlayer = $AnimationPlayer
var combo: Array = []
var combo_timer := 0.0
var punch_input := -1

func press(button: String) -> void:
	combo.append(button)
	combo_timer = 0.5
	match ",".join(combo):
		"punch,punch,kick":
			anim.play("uppercut")
			combo.clear()
		"kick,kick":
			anim.play("sweep")
			combo.clear()

func _process(delta: float) -> void:
	combo_timer -= delta
	if combo_timer <= 0.0:
		combo.clear()

func land_the_blow() -> void:
	Engine.time_scale = 0.05
	await get_tree().create_timer(0.08, true, false, true).timeout
	Engine.time_scale = 1.0

func may_cancel() -> void:
	if anim.current_animation_position > 0.3 and anim.current_animation_position < 0.6:
		print("cancel")

func remember_the_punch() -> void:
	punch_input = Engine.get_physics_frames() + 6
"""

## The ace_ids these items add, with the template each one SHIPS - after the registry has given a
## node-scoped ACE its optional "On node" prefix. Frozen from here on: an authored row must keep
## writing the very line the reading above recognises.
##
## The three animation rows carry their OWN `target` parameter rather than taking the automatic one,
## because each names the player more than once and the automatic prefix reaches only the first
## member on a line - which is why their templates below show `{target.}` in every slot.
static var SHIPPED_TEMPLATES: Dictionary = {
	"AnimationIsBetween": "{target.}current_animation == {animation} and {target.}current_animation_position > {from_time} and {target.}current_animation_position < {to_time}",
	"PauseAnimationFor": "{target.}pause()\nawait get_tree().create_timer({seconds}, true, false, true).timeout\n{target.}play()",
	"SpriteAnimationFrameIs": "{target.}animation == {animation} and {target.}frame == {frame}",
	"BufferInput": "{input} = Engine.get_physics_frames() + {frames}",
	"IsInputBuffered": "(Engine.get_physics_frames() <= {input})",
	"ConsumeBufferedInput": "{input} = Engine.get_physics_frames() - 1",
	# Y2's hit-stop was NOT minted here: the Juice module already shipped this exact template, and a
	# second row writing the same three lines under a second name would be the one thing the whole
	# vocabulary is meant to prevent. The reading says the shipped row's words.
	"Hitstop": "Engine.time_scale = {scale}\nawait get_tree().create_timer({seconds}, true, false, true).timeout\nEngine.time_scale = 1.0"
}

## Every reading the opened file must contain, one per shape these items claim.
static var EXPECTED_READINGS: PackedStringArray = PackedStringArray([
	"CharacterBody2D ▸ Combo Box ▸ Press input button",
	"CharacterBody2D ▸ Combo Box ▸ On combo \"punch punch kick\"",
	"CharacterBody2D ▸ Combo Box ▸ On combo \"kick kick\"",
	"Set animation to \"uppercut\" (play from beginning)",
	"Set animation to \"sweep\" (play from beginning)",
	"System ▸ Hitstop for 0.08 seconds",
	"anim ▸ Is between 0.3 s and 0.6 s of the current animation"
])

## Readings the file must NOT contain: the lines each run swallowed, and the two spellings the arms
## had before they were triggers. A run that silently stopped firing would otherwise pass the list
## above by never being asked about.
static var FORBIDDEN_READINGS: PackedStringArray = PackedStringArray([
	"System ▸ Set time scale to 0.05",
	"System ▸ Set time scale to 1",
	"System ▸ \",\".join(combo) = \"punch,punch,kick\"",
	"Clear combo"
])


static func run() -> bool:
	var ok: bool = true
	ok = _grammar_values() and ok
	ok = _shipped_templates() and ok
	var opened: Dictionary = _open_and_read()
	var readings: PackedStringArray = opened.get("readings", PackedStringArray())
	for expected: String in EXPECTED_READINGS:
		ok = _check("opened row reads \"%s\"" % expected, readings.has(expected), true) and ok
	for forbidden: String in FORBIDDEN_READINGS:
		ok = _check("no row still reads \"%s\"" % forbidden, readings.has(forbidden), false) and ok
	ok = _pattern_claims(opened.get("patterns", {})) and ok
	ok = _round_trip() and ok
	ok = _animation_events() and ok
	ok = _method_track_doctor() and ok
	ok = _combo_box_move_table() and ok
	ok = _authored_events_compile() and ok
	return ok


## The sentence context an opened fighting-game script hands the grammar. `combo_lists` is the fact
## no single line can decide - a list is only a combo buffer once the file appends to it, empties it
## on a countdown, and asks what it spells.
static func _context() -> Dictionary:
	return {
		"self_object": "Player",
		"script_object": "Player",
		"self_class": "CharacterBody2D",
		"object_classes": {"anim": "AnimationPlayer"},
		"engine_properties": {"position": true, "velocity": true},
		"combo_lists": {"combo": {"timer": "combo_timer", "window": "0.5"}}
	}


## Gate one: the grammar answering on its own, value by value.
static func _grammar_values() -> bool:
	var ok: bool = true
	var context: Dictionary = _context()
	# Y1 - the push and the window, and the two ways the pair is refused.
	var pressed: Dictionary = EventSheetSentence.combo_press_parts("combo.append(button)",
		"combo_timer = 0.5", context)
	ok = _check("the push and the window read as one press",
		str(pressed.get("text", "")), "Combo Box ▸ Press input button") and ok
	ok = _check("the press row says how long the player has",
		str(pressed.get("note", "")), "within 0.5 s") and ok
	ok = _check("a push onto a list this file never empties is refused",
		EventSheetSentence.combo_press_parts("names.append(button)", "combo_timer = 0.5", context)
			.is_empty(), true) and ok
	ok = _check("a push with something other than the window under it is refused",
		EventSheetSentence.combo_press_parts("combo.append(button)", "hp = 100", context)
			.is_empty(), true) and ok
	# Y1 - the subject that makes a `match` a combo detector rather than a switch on a string.
	var subject: Dictionary = EventSheetSentence.combo_match_subject("\",\".join(combo)")
	ok = _check("the joined buffer names the list it joins", str(subject.get("list", "")), "combo") and ok
	ok = _check("and the separator it joins them with", str(subject.get("separator", "")), ",") and ok
	ok = _check("a match on a plain value is not a combo detector",
		EventSheetSentence.combo_match_subject("state").is_empty(), true) and ok
	# Y1 - one arm, as the trigger it is, with the inputs put back in the order they are pressed.
	var arm: Dictionary = EventSheetSentence.combo_arm_words("\"punch,punch,kick\"", ",", "0.5")
	ok = _check("an arm reads as the move its inputs spell",
		str(arm.get("text", "")), "Combo Box ▸ On combo \"punch punch kick\"") and ok
	ok = _check("and carries the window as its note", str(arm.get("note", "")), "within 0.5 s") and ok
	ok = _check("the catch-all arm is not a combo",
		EventSheetSentence.combo_arm_words("_", ",", "0.5").is_empty(), true) and ok
	# Y2 - the freeze, and the missing flag that means it is not one.
	var frozen: Dictionary = EventSheetSentence.freeze_time_parts("Engine.time_scale = 0.05",
		"await get_tree().create_timer(0.08, true, false, true).timeout",
		"Engine.time_scale = 1.0", context)
	ok = _check("the three time-scale lines read as one hit-stop",
		str(frozen.get("text", "")), "Hitstop for 0.08 seconds") and ok
	ok = _check("the hit-stop note says what freezes and how far",
		str(frozen.get("note", "")), "the whole game freezes at 0.05 - hit-stop") and ok
	ok = _check("a freeze whose wait is NOT on real time is refused - it would never lift",
		EventSheetSentence.freeze_time_parts("Engine.time_scale = 0.05",
			"await get_tree().create_timer(0.08, true, false, false).timeout",
			"Engine.time_scale = 1.0", context).is_empty(), true) and ok
	# Y2 - the per-object twin, and the pause and play that are on two different players.
	var paused: Dictionary = EventSheetSentence.animation_pause_parts("anim.pause()",
		"await get_tree().create_timer(0.08, true, false, true).timeout", "anim.play()", context)
	ok = _check("one player held still and let go reads as one row",
		str(paused.get("text", "")), "Pause for 0.08 s") and ok
	ok = _check("a pause on one player and a play on another stay two rows",
		EventSheetSentence.animation_pause_parts("anim.pause()",
			"await get_tree().create_timer(0.08, true, false, true).timeout",
			"other.play()", context).is_empty(), true) and ok
	# Y2 - the cancel window, and the pair that only fences one side.
	var window: Dictionary = EventSheetSentence.animation_window_pieces(
		"anim.current_animation_position > 0.3 and anim.current_animation_position < 0.6", context)
	ok = _check("a floor and a ceiling on one play head read as the window they are",
		str((window.get("pieces", []) as Array)[0][0] if not window.is_empty() else ""),
		"Is between 0.3 s and 0.6 s of the current animation") and ok
	ok = _check("the window claims the combo pattern", str(window.get("pattern", "")), "animation_combo") and ok
	ok = _check("two floors are not a window",
		EventSheetSentence.animation_window_pieces(
			"anim.current_animation_position > 0.3 and anim.current_animation_position > 0.6",
			context).is_empty(), true) and ok
	ok = _check("two different players are not a window either",
		EventSheetSentence.animation_window_pieces(
			"anim.current_animation_position > 0.3 and other.current_animation_position < 0.6",
			context).is_empty(), true) and ok
	# Y1 - which end of the clip a play starts from, said out loud.
	ok = _check("the plain play restarts from the top",
		_spoken(EventSheetSentence.statement("anim.play(\"uppercut\")", context)),
		"Set animation to \"uppercut\" (play from beginning)") and ok
	ok = _check("the four-argument form with from_end set plays it backwards",
		_spoken(EventSheetSentence.statement("anim.play(\"uppercut\", -1, 1.0, true)", context)),
		"Set animation to \"uppercut\" (play from end)") and ok
	ok = _check("a queued clip is a different sentence from a played one",
		_spoken(EventSheetSentence.statement("anim.queue(\"idle\")", context)),
		"Set animation to \"idle\" after the current one") and ok
	return ok


## Gate five: the authored rows write the very lines the readings recognise.
static func _shipped_templates() -> bool:
	var ok: bool = true
	var shipped: Dictionary = {}
	for descriptor: ACEDescriptor in EventForgeBuiltinACEs.get_descriptors():
		shipped[str(descriptor.ace_id)] = str(descriptor.codegen_template)
	for ace_id: String in SHIPPED_TEMPLATES:
		ok = _check("%s writes the line the reading recognises" % ace_id,
			str(shipped.get(ace_id, "")), str(SHIPPED_TEMPLATES[ace_id])) and ok
	return ok


## Gate three: the new shape is claimed in the registry, on the events that own it.
static func _pattern_claims(patterns: Dictionary) -> bool:
	var ok: bool = true
	ok = _check("the pattern id is registered and never renamed",
		EventSheetPatternFacts.PATTERN_IDS.has("animation_combo"), true) and ok
	ok = _check("the pattern offers the behaviour that replaces the hand-written detector",
		EventSheetPatternVocabulary.adoptable("animation_combo"), "combo_box") and ok
	ok = _check("and that behaviour has a name to offer it under",
		EventSheetPatternVocabulary.pack_label("combo_box"), "Combo Box") and ok
	# Three claims, one per EVENT that writes a shape: the function that pushes an input and asks
	# what the buffer spells (the two arms are that one event's own branches, so they claim on it),
	# the function that freezes, and the function that fences the cancel window.
	ok = _check("the combo pattern is claimed on the events that write the shapes",
		int(patterns.get("animation_combo", 0)), 3) and ok
	return ok


## Y3, gate six: the other half of the contract. What an animation CALLS is written in the scene or
## the resource that holds it, and nothing in the script says so - which is the whole reason both the
## reading and the Doctor have to go and look.
static func _animation_events() -> bool:
	var ok: bool = true
	var scene: String = """[gd_scene load_steps=2 format=3]

[sub_resource type="Animation" id="Animation_1"]
resource_name = "punch"
length = 0.8
tracks/0/type = "method"
tracks/0/path = NodePath(".")
tracks/0/keys = {"times": PackedFloat32Array(0.35), "transitions": PackedFloat32Array(1), "values": [{"args": [], "method": &"_on_hit_frame"}]}

[node name="Player" type="Node2D"]
"""
	var tracks: Array = EventSheetAnimationTrackFacts.tracks_in(scene)
	ok = _check("the method a track calls is read off the file", tracks.size(), 1) and ok
	if tracks.size() == 1:
		ok = _check("with the function it names",
			str((tracks[0] as Dictionary).get("method", "")), "_on_hit_frame") and ok
		ok = _check("and the clip the key sits on",
			str((tracks[0] as Dictionary).get("animation", "")), "punch") and ok
	ok = _check("a file with no method track names nothing",
		EventSheetAnimationTrackFacts.tracks_in("[node name=\"Player\" type=\"Node2D\"]\n").size(), 0) and ok
	ok = _check("the handler's name reads back as the words that made it",
		EventSheetAnimationTrackFacts.event_words("_on_hit_frame"), "hit frame") and ok
	# The picker's side of the same contract: the words the author types become that very function.
	ok = _check("the authored event writes the function the track has to call",
		TriggerResolver.animation_event_handler_name("hit frame"), "_on_hit_frame") and ok
	ok = _check("punctuation in the words cannot produce a name that does not parse",
		TriggerResolver.animation_event_handler_name("hit-frame (left)"), "_on_hit_frame_left") and ok
	var named: EventRow = EventRow.new()
	named.trigger_provider_id = "Core"
	named.trigger_id = "OnAnimationEvent"
	named.trigger_params = {"event_name": "hit frame"}
	ok = _check("the animation event compiles to that function and connects nothing",
		TriggerResolver.resolve_trigger(named).get("function_name", ""), "_on_hit_frame") and ok
	ok = _check("and no signal is wired up for it - the animation IS the caller",
		str(TriggerResolver.resolve_trigger(named).get("signal_name", "")), "") and ok
	var other: EventRow = EventRow.new()
	other.trigger_provider_id = "Core"
	other.trigger_id = "OnAnimationEvent"
	other.trigger_params = {"event_name": "footstep"}
	ok = _check("two differently named events are two different functions",
		TriggerResolver.get_trigger_key(named) == TriggerResolver.get_trigger_key(other), false) and ok
	# Y3's 2D half: the sprite's own signal, with the clip-and-frame question left as a condition.
	var frame_event: EventRow = EventRow.new()
	frame_event.trigger_provider_id = "Core"
	frame_event.trigger_id = "OnAnimationFrame"
	ok = _check("the sprite frame event listens to the sprite's own signal",
		str(TriggerResolver.resolve_trigger(frame_event).get("signal_name", "")), "frame_changed") and ok
	return ok


## Y3, the Doctor: a method track that names a function nobody wrote. The bug it catches is the one
## with no symptom at all - the key plays, nothing is called, and nothing is reported.
static func _method_track_doctor() -> bool:
	var findings: Array[Dictionary] = []
	EventSheetProjectDoctor.check_animation_method_tracks(findings)
	var about_this_repo: PackedStringArray = PackedStringArray()
	for finding: Dictionary in findings:
		about_this_repo.append(str(finding.get("message", "")))
	var ok: bool = true
	# This repo's own animations must all call something real - the showcase's hit frame included.
	ok = _check("no animation in this project calls a function nobody wrote",
		"\n".join(about_this_repo), "") and ok
	# And the project-wide scan the READING asks is the same scan: the showcase's uppercut really
	# does name a function, so a green check above cannot mean "found nothing and had nothing to say".
	var called: Dictionary = EventSheetAnimationTrackFacts.by_method()
	ok = _check("the showcase's uppercut calls the hit frame its sheet defines",
		str((called.get("_on_hit_frame", {}) as Dictionary).get("animation", "")), "uppercut") and ok
	return ok


## Y1's authoring half: the move list as a table. The pack gained the one row that joins a sequence
## to a clip, and the emitted pack is what a project actually loads.
static func _combo_box_move_table() -> bool:
	var ok: bool = true
	var pack: String = FileAccess.get_file_as_string("res://eventsheet_addons/combo_box/combo_box_addon.gd")
	ok = _check("the pack ships the row that wires a combo to an animation",
		pack.contains("func set_animation_for_combo(id: String, player: AnimationPlayer, animation: String)"), true) and ok
	ok = _check("the wiring is a table rather than a branch per move",
		pack.contains("_animations[id] = {\"player\": player, \"animation\": animation}"), true) and ok
	ok = _check("a matched combo plays its clip before the trigger fires",
		pack.contains("\t\t_play_combo_animation(best_full)\n\t\ton_combo_matched.emit()"), true) and ok
	ok = _check("a combo wired to nothing still fires its trigger",
		pack.contains("\tif not _animations.has(id):\n\t\treturn"), true) and ok
	ok = _check("and a player that has left the tree is skipped rather than erroring",
		pack.contains("\tif is_instance_valid(player) and player.has_animation(str(wired.animation)):"), true) and ok
	return ok


## Y3, the authoring half end to end: a sheet built out of the two new triggers compiles to GDScript
## that PARSES, wires the sprite's signal in _ready, and declares the function the method track has to
## call. A trigger that resolves correctly and then emits something Godot will not load is the failure
## the resolver checks above cannot see.
static func _authored_events_compile() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "AnimationEventProbe"
	var frame_event: EventRow = EventRow.new()
	frame_event.trigger_provider_id = "Core"
	frame_event.trigger_id = "OnAnimationFrame"
	frame_event.trigger_source_path = "AnimatedSprite2D"
	var gate: ACECondition = ACECondition.new()
	gate.provider_id = "Core"
	gate.ace_id = "SpriteAnimationFrameIs"
	gate.codegen_template = "{target.}animation == {animation} and {target.}frame == {frame}"
	gate.params = {"animation": "\"punch\"", "frame": "3", "target": "$AnimatedSprite2D"}
	frame_event.conditions.append(gate)
	var raised: RawCodeRow = RawCodeRow.new()
	raised.code = "print(\"hit\")"
	frame_event.actions.append(raised)
	sheet.events.append(frame_event)
	var called: EventRow = EventRow.new()
	called.trigger_provider_id = "Core"
	called.trigger_id = "OnAnimationEvent"
	called.trigger_params = {"event_name": "hit frame"}
	var stepped: RawCodeRow = RawCodeRow.new()
	stepped.code = "print(\"track\")"
	called.actions.append(stepped)
	sheet.events.append(called)
	var output: String = str(SheetCompiler.compile(sheet, "user://eventforge_animation_events.gd").get("output", ""))
	ok = _check("the frame event connects the sprite's own signal",
		output.contains("get_node(\"AnimatedSprite2D\").frame_changed.connect(_on_animatedsprite2d_frame_changed)"), true) and ok
	ok = _check("and asks the clip-and-frame question inside the handler",
		output.contains("if $AnimatedSprite2D.animation == \"punch\" and $AnimatedSprite2D.frame == 3:"), true) and ok
	ok = _check("the animation event is a plain function the track can call by name",
		output.contains("func _on_hit_frame() -> void:"), true) and ok
	ok = _check("and nothing is connected for it - the animation IS the caller",
		output.contains("_on_hit_frame.connect"), false) and ok
	var script: GDScript = GDScript.new()
	script.source_code = output
	ok = _check("the whole thing parses", script.reload(), OK) and ok
	return ok


## Writes the source, opens it as a sheet, walks every row and returns {readings, patterns} - the
## cell readings as "object ▸ text", and {pattern id: how many events claimed it}.
static func _open_and_read() -> Dictionary:
	var handle: FileAccess = FileAccess.open(SOURCE_PATH, FileAccess.WRITE)
	handle.store_string(SOURCE)
	handle.close()
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(SOURCE_PATH)
	sheet.read_only = true
	var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
	style.ensure_defaults()
	sheet.editor_style = style
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_ace_registry(EventSheetACERegistry.new())
	viewport.set_sheet(sheet)
	viewport.set_reading_mode(true)
	var readings: PackedStringArray = PackedStringArray()
	for row_data: EventRowData in _walk(viewport._root_rows, viewport):
		for span: SemanticSpan in row_data.spans:
			var object_label: String = str(span.metadata.get("object_label", ""))
			var text: String = span.text.strip_edges()
			readings.append("%s ▸ %s" % [object_label, text] if not object_label.is_empty() else text)
	var patterns: Dictionary = {}
	for claim: Variant in EventSheetPatternFacts.claims(sheet):
		var pattern: String = str((claim as Dictionary).get("pattern", ""))
		patterns[pattern] = int(patterns.get(pattern, 0)) + 1
	viewport.free()
	return {"readings": readings, "patterns": patterns}


## Every row in the tree, parents before children.
static func _walk(rows: Array, viewport: EventSheetViewport) -> Array:
	var found: Array = []
	for row_data: EventRowData in rows:
		viewport._row_builder._ensure_event_spans(row_data)
		found.append(row_data)
		found.append_array(_walk(row_data.children, viewport))
	return found


## Gate four: every reading here is a lens over a value the row already holds, so opening the file
## and saving it untouched puts back every byte.
static func _round_trip() -> bool:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(SOURCE_PATH)
	var output: String = str(SheetCompiler.compile(sheet, SOURCE_PATH).get("output", ""))
	return _check("opening the file and saving it reproduces every byte", output, SOURCE)


## The words a sentence says, joined - the one string a reading test can pin by value.
static func _spoken(reading: Dictionary) -> String:
	var text: String = ""
	for segment: Variant in (reading.get("segments", []) as Array):
		text += str((segment as Dictionary).get("text", ""))
	return text.strip_edges()


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] animation_combo_reading_test: %s" % label)
		return true
	print("[FAIL] animation_combo_reading_test: %s - expected %s, got %s" % [label, expected, actual])
	return false
