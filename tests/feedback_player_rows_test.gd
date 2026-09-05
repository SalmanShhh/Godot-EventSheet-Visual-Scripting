# Godot EventSheets - everything the Feedback Player's Inspector does, as rows.
#
# THE ONE THING THIS FILE IS ABOUT: a list edited in the Inspector and a list edited by rows have to
# be the same list. So the pins here are about the ADDRESS (a card answers to its label, or to its
# own word when it was never named), about what each editing row does to the list BY VALUE, about
# the three powers only a running game can want (a family muted, one of several picked, the head
# held), and about the two places the editor says something: the toolbar's contextual segment and
# the quiet finding on a row that names a card nobody has.
#
# A LIST WITH NO WAIT IN IT RUNS SYNCHRONOUSLY, which is what lets a headless test walk one: every
# await in the runner is a wait a card asked for. The hold pin uses exactly that - a card's own
# trigger holds the head, and the play only finishes when a later line lets it go.
@tool
class_name FeedbackPlayerRowsTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const PLAYER := preload("res://eventsheet_addons/juice/feedback_player.gd")
const STEP_FIELD := preload("res://addons/eventsheet/editor/inspector/feedback_step_field.gd")

const TEST_NAME: String = "feedback_player_rows"

## Where the finding pins write the scene they read back. Under user://, and taken away again at the
## end of the run, so a suite leaves nothing behind it.
const SCENE_PATH: String = "user://feedback_player_rows_test.tscn"


static func run() -> bool:
	var ok: bool = true
	ok = _address_pins() and ok
	ok = _edit_pins() and ok
	ok = _sweep_pins() and ok
	ok = _hold_pins() and ok
	ok = _finding_pins() and ok
	ok = _segment_pins() and ok
	ok = _step_field_pins() and ok
	return ok


## The address: a card answers to the name it was given, or to its own word when it was never named,
## and For Each Feedback reads the list out in order.
static func _address_pins() -> bool:
	var player: Node = _player([
		{"verb": "shake", "label": "kick", "amount": 0.4, "seconds": 0.0},
		{"verb": "flash", "amount": 1.0, "seconds": 0.0},
		{"verb": "punch", "label": "swell", "amount": 1.2, "seconds": 0.0}
	])
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["a named card answers to its name", player._index_of("kick"), 0],
		["an unnamed one answers to its word", player._index_of("flash"), 1],
		["a name nobody has is not found", player._index_of("nobody"), -1],
		["For Each Feedback reads the list out in order", PackedStringArray(player.for_each_feedback()),
			PackedStringArray(["kick", "flash", "swell"])],
		["Feedback Count counts every card", player.feedback_count(), 3],
		["Feedback Label At is one-based", player.feedback_label_at(2), "flash"],
		["and answers with nothing past the end", player.feedback_label_at(9), ""],
		["Has Feedback is the same question the rows ask", [player.has_feedback("swell"), player.has_feedback("nope")],
			[true, false]]
	])
	player.free()
	return ok


## Each editing row, by VALUE: what the list holds afterwards, not how many times something was
## called. One player, walked through the gestures the Inspector offers in the order a designer
## would make them.
static func _edit_pins() -> bool:
	var player: Node = _player([{"verb": "shake", "label": "kick", "amount": 0.4, "seconds": 0.2}])
	player.add_feedback({"verb": "flash", "label": "pop", "amount": 1.0, "seconds": 0.1}, "kick")
	var added: PackedStringArray = _labels(player)
	player.insert_feedback_before({"verb": "hitstop", "label": "freeze"}, "kick")
	var inserted: PackedStringArray = _labels(player)
	player.replace_feedback("kick", {"verb": "recoil", "amount": 2.0})
	var replaced: Array = [str((player.steps[1] as Dictionary).get("verb", "")), _labels(player)]
	player.set_feedback_field("pop", "amount", 0.25)
	var tuned: float = float((player._card_named("pop") as Dictionary).get("amount", -1.0))
	player.set_feedback_timing("pop", 0.05, 3, 0.02, "real")
	var timed: Array = [
		float((player._card_named("pop") as Dictionary).get("delay", -1.0)),
		int((player._card_named("pop") as Dictionary).get("repeat", -1)),
		str((player._card_named("pop") as Dictionary).get("clock", ""))]
	player.set_feedback_chance("pop", 40.0)
	var chanced: float = float((player._card_named("pop") as Dictionary).get("chance", -1.0))
	player.disable_feedback("pop")
	var off: bool = player.feedback_is_enabled("pop")
	player.enable_feedback("pop")
	var on: bool = player.feedback_is_enabled("pop")
	player.set_feedback_label("pop", "flashy")
	var renamed: PackedStringArray = _labels(player)
	player.duplicate_feedback("flashy", "flashier")
	var duplicated: PackedStringArray = _labels(player)
	player.move_feedback_to("flashier", 1)
	var moved: PackedStringArray = _labels(player)
	player.remove_feedback("flashier")
	var removed: PackedStringArray = _labels(player)
	player.set_loop_count("freeze", 4)
	var looped: int = player.loops_left("freeze")
	player.clear_feedbacks()
	var cleared: int = player.feedback_count()

	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["Add Feedback puts a card after the one it names", added, PackedStringArray(["kick", "pop"])],
		["Insert Feedback Before puts one above it", inserted, PackedStringArray(["freeze", "kick", "pop"])],
		["Replace Feedback swaps the card and keeps its name", replaced,
			["recoil", PackedStringArray(["freeze", "kick", "pop"])]],
		["Set Feedback Field writes the one value", tuned, 0.25],
		["Set Feedback Timing writes the three and the clock", timed, [0.05, 3, "real"]],
		["Set Feedback Chance writes the roll", chanced, 40.0],
		["Disable and Enable Feedback move the box both ways", [off, on], [false, true]],
		["Set Feedback Label renames the card", renamed, PackedStringArray(["freeze", "kick", "flashy"])],
		["Duplicate Feedback puts the copy under the original", duplicated,
			PackedStringArray(["freeze", "kick", "flashy", "flashier"])],
		["Move Feedback To is one-based", moved,
			PackedStringArray(["flashier", "freeze", "kick", "flashy"])],
		["Remove Feedback takes one out", removed, PackedStringArray(["freeze", "kick", "flashy"])],
		["Set Loop Count is what Loops Left answers with", looped, 4],
		["Clear Feedbacks empties the list", cleared, 0]
	])
	player.free()
	return ok


## The rows that move the whole list at once: a family muted, every amount scaled, every length
## retimed, one of a prefix picked, and one player's list copied onto another.
static func _sweep_pins() -> bool:
	var player: Node = _player([
		{"verb": "shake", "label": "shake_a", "amount": 1.0, "seconds": 0.2},
		{"verb": "shake", "label": "shake_b", "amount": 1.0, "seconds": 0.2},
		{"verb": "pulse", "label": "screeny", "amount": 1.0, "seconds": 0.4}
	])
	player.mute_feedback_category("screen", true)
	var muted: String = player._why_not(player._card_named("screeny"), 1.0, 0)
	var camera_still_runs: String = player._why_not(player._card_named("shake_a"), 1.0, 1)
	player.mute_feedback_category("screen", false)
	var unmuted: String = player._why_not(player._card_named("screeny"), 1.0, 0)
	player.scale_feedback_amounts("camera", 0.5)
	var scaled: Array = [
		float((player._card_named("shake_a") as Dictionary).get("amount", -1.0)),
		float((player._card_named("screeny") as Dictionary).get("amount", -1.0))]
	player.retime_feedbacks(0.5)
	var retimed: float = float((player._card_named("screeny") as Dictionary).get("seconds", -1.0))
	player.pick_one_feedback_of("shake_")
	var picked: int = 0
	for label: String in ["shake_a", "shake_b"]:
		if bool((player._card_named(label) as Dictionary).get("active", true)):
			picked += 1
	var untouched: bool = bool((player._card_named("screeny") as Dictionary).get("active", true))
	player.skip_feedback_once("screeny")
	var skipped: String = player._why_not(player._card_named("screeny"), 1.0, 0)
	var only_once: String = player._why_not(player._card_named("screeny"), 1.0, 0)

	var other: Node = _player([])
	other.copy_feedbacks_from(player)
	var copied: PackedStringArray = _labels(other)
	other.remove_feedback("screeny")
	var independent: int = player.feedback_count()

	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["a muted family says why it was skipped", muted, "muted"],
		["and only that family is muted", camera_still_runs, ""],
		["unmuting lets it be felt again", unmuted, ""],
		["Scale Feedback Amounts moves one family only", scaled, [0.5, 1.0]],
		["Retime Feedbacks moves every length", retimed, 0.2],
		["Pick One Feedback Of leaves exactly one of the prefix on", picked, 1],
		["and leaves everything else alone", untouched, true],
		["Skip Feedback Once says why", skipped, "skipped once"],
		["and means once", only_once, ""],
		["Copy Feedbacks From takes the whole list", copied,
			PackedStringArray(["shake_a", "shake_b", "screeny"])],
		["as a copy, so editing it leaves the original alone", independent, 3]
	])
	player.free()
	other.free()
	return ok


## Hold Here stops the head where it is, and Release Hold carries on from the same card. The hold is
## asked for by the beat itself - a card's own started trigger - because that is the only way to be
## inside a play when the row runs.
static func _hold_pins() -> bool:
	var player: Node = _player([
		{"verb": "shake", "label": "one", "amount": 1.0, "seconds": 0.0},
		{"verb": "flash", "label": "two", "amount": 1.0, "seconds": 0.0},
		{"verb": "punch", "label": "three", "amount": 1.0, "seconds": 0.0}
	])
	var listener: Node = _listener()
	player.add_child(listener)
	player.on_feedback_started.connect(func(label: String) -> void:
		if label == "one":
			player.hold_here())
	player.play(1.0)
	# DUPLICATED, not just read: the listener goes on appending to the very same buffer, so a plain
	# read would grow under the pin and the hold would look as if it never happened.
	var during: PackedStringArray = (listener.get("words") as PackedStringArray).duplicate()
	var held: Array = [player.playing, player.current_feedback()]
	player.release_hold()
	var after: PackedStringArray = listener.get("words")
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["Hold Here stops the head on the card it was asked from", during, PackedStringArray(["shake"])],
		["and the play is still running, on that card", held, [true, "one"]],
		["Release Hold carries on from the same card", after,
			PackedStringArray(["shake", "flash", "punch"])],
		["and the play finishes", player.playing, false]
	])
	player.free()
	return ok


## The quiet finding: a row naming a card no Feedback Player in the scene has. The evidence is the
## scene's own saved bytes, so the pins write one, read the labels back out of it, and take it away.
static func _finding_pins() -> bool:
	var root: Node2D = Node2D.new()
	var player: Node = PLAYER.new()
	player.name = "HitFeedback"
	root.add_child(player)
	player.owner = root
	var list: Array[Dictionary] = [
		{"verb": "shake", "label": "kick", "amount": 1.0, "seconds": 0.0},
		{"verb": "flash", "amount": 1.0, "seconds": 0.0}
	]
	player.steps = list
	var packed: PackedScene = PackedScene.new()
	var packed_ok: bool = packed.pack(root) == OK and ResourceSaver.save(packed, SCENE_PATH) == OK
	var known: PackedStringArray = EventSheetFeedbackFindings.labels_in_scene(SCENE_PATH) if packed_ok \
		else PackedStringArray()

	var named: ACEAction = ACEAction.new()
	named.provider_id = EventSheetFeedbackFindings.PLAYER_PROVIDER
	named.ace_id = "disable_feedback"
	named.params = {"label": "\"kick\""}
	var wrong: ACEAction = ACEAction.new()
	wrong.provider_id = EventSheetFeedbackFindings.PLAYER_PROVIDER
	wrong.ace_id = "disable_feedback"
	wrong.params = {"label": "\"kik\""}
	var written: ACEAction = ACEAction.new()
	written.provider_id = EventSheetFeedbackFindings.PLAYER_PROVIDER
	written.ace_id = "disable_feedback"
	written.params = {"label": "Weapon.feedback_name"}
	var elsewhere: ACEAction = ACEAction.new()
	elsewhere.provider_id = "JuiceBehavior"
	elsewhere.ace_id = "shake"
	elsewhere.params = {"label": "\"kik\""}

	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["a scene's players are read without instancing one", known, PackedStringArray(["flash", "kick"])],
		["a card with no name of its own answers to its word",
			EventSheetFeedbackFindings.label_of({"verb": "flash"}), "flash"],
		["a row's quoted label is what the rule is asked about",
			EventSheetFeedbackFindings.labels_named(named), PackedStringArray(["kick"])],
		["a label that is an expression is left alone",
			EventSheetFeedbackFindings.labels_named(written), PackedStringArray()],
		["and a row on another pack is not this rule's business",
			EventSheetFeedbackFindings.labels_named(elsewhere), PackedStringArray()],
		["the label nobody has is the one the sentence names",
			EventSheetFeedbackFindings.labels_named(wrong)[0] in EventSheetFeedbackFindings.message_for(
				EventSheetFeedbackFindings.labels_named(wrong)[0], "arena.tscn"), true],
		["the finding is filed under one frozen id",
			EventSheetFeedbackDoctor.CHECK_UNKNOWN_LABEL, EventSheetFeedbackFindings.KIND_UNKNOWN_LABEL]
	])
	root.free()
	if FileAccess.file_exists(SCENE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SCENE_PATH))
	return ok


## The toolbar's contextual Moment segment: which rows it answers for, and what it leads with. The
## reading half only - the buttons are pictures, and a picture is not a pin.
static func _segment_pins() -> bool:
	var player_row: ACEAction = ACEAction.new()
	player_row.provider_id = EventSheetMomentSegment.PLAYER_PROVIDER
	player_row.ace_id = "play"
	var moment_row: ACEAction = ACEAction.new()
	moment_row.provider_id = "JuiceBehavior"
	moment_row.ace_id = "moment"
	moment_row.params = {"moment_name": "\"impact\""}
	var other_row: ACEAction = ACEAction.new()
	other_row.provider_id = "JuiceBehavior"
	other_row.ace_id = "shake"
	return SUPPORT.pins(TEST_NAME, [
		["a player row earns the segment", str(EventSheetMomentSegment.subject_of(player_row).get("kind", "")),
			EventSheetMomentSegment.SUBJECT_PLAYER],
		["and leads with the list it is about",
			EventSheetMomentSegment.title_for(EventSheetMomentSegment.subject_of(player_row)), "Feedbacks"],
		["a moment row earns it and names the moment",
			EventSheetMomentSegment.title_for(EventSheetMomentSegment.subject_of(moment_row)), "Moment: impact"],
		["a moment block's head earns it too",
			str(EventSheetMomentSegment.subject_of(null, "moment").get("kind", "")),
			EventSheetMomentSegment.SUBJECT_BLOCK],
		["every other row earns nothing at all", EventSheetMomentSegment.subject_of(other_row), {}],
		["and a row with nothing selected earns nothing", EventSheetMomentSegment.subject_of(null), {}],
		["the segment is five doors and a strength", EventSheetMomentSegment.BUTTONS.size(), 5],
		# The wiring, not the pure function: the head of a moment block is a row the registry knows
		# by kind, and that kind is the word the dock hands the segment.
		["the registry knows a moment block by the kind the segment answers for",
			EventSheetBlockRegistry.kind_for(MomentBlockRow.new()).kind_id,
			EventSheetMomentSegment.MOMENT_BLOCK_KIND],
		# A list on a node can be walked in the editor; a beat the running game plays cannot, so the
		# doors stay shut rather than moving whichever player the scene happened to have.
		["a player's list opens the doors",
			EventSheetMomentSegment.previewable(EventSheetMomentSegment.subject_of(player_row)), true],
		["a named moment leaves them shut",
			EventSheetMomentSegment.previewable(EventSheetMomentSegment.subject_of(moment_row)), false],
		["and so does a block's head",
			EventSheetMomentSegment.previewable(EventSheetMomentSegment.subject_of(null, "moment")), false]
	])


## The step parameter's field: what is in the box is the dictionary the row emits, and opening the
## card and closing it again leaves those bytes alone.
static func _step_field_pins() -> bool:
	var card: Dictionary = {"seconds": 0.2, "verb": "shake", "amount": 0.4, "label": "kick"}
	var written: String = STEP_FIELD.step_literal(card)
	var reopened: String = STEP_FIELD.step_literal(STEP_FIELD.parse_step(written))
	# A card holds counts as well as times, and a count opened and closed again is still a count.
	var counted: String = "{\"verb\": \"loop_back\", \"seconds\": 0.25, \"loops\": 2, \"to_hold\": true}"
	return SUPPORT.pins(TEST_NAME, [
		["a whole number opens and closes as a whole number",
			STEP_FIELD.step_literal(STEP_FIELD.parse_step(counted)), counted],
		["a card writes out with the file's four keys first", written,
			"{\"verb\": \"shake\", \"amount\": 0.4, \"seconds\": 0.2, \"label\": \"kick\"}"],
		["opening the card and closing it changes nothing", reopened, written],
		["an empty box opens as a plain shake", str(STEP_FIELD.parse_step("").get("verb", "")), "shake"],
		["and so does an expression, rather than being read as one",
			str(STEP_FIELD.parse_step("Weapon.kick_card").get("verb", "")), "shake"]
	])


## One player, holding a list, with a host to feel it on. Never in a tree - the runner needs none.
static func _player(list: Array) -> Node:
	var player: Node = PLAYER.new()
	var typed: Array[Dictionary] = []
	for entry: Variant in list:
		typed.append(entry as Dictionary)
	player.steps = typed
	# The host rides UNDER the player so freeing one frees both: a test that leaks a Node2D is a
	# test that prints an orphan at the end of somebody else's run.
	var host: Node2D = Node2D.new()
	player.add_child(host)
	player.host = host
	return player


## The labels a player's list holds right now.
static func _labels(player: Node) -> PackedStringArray:
	return PackedStringArray(player.for_each_feedback())


## A stand-in for the Juice behaviour beside a player: it answers the step call and writes down the
## word it was given, so a walk can be read back without a single effect happening.
static func _listener() -> Node:
	var listener: Node = Node.new()
	var script: GDScript = GDScript.new()
	script.source_code = "\n".join([
		"extends Node",
		"",
		"var words: PackedStringArray = PackedStringArray()",
		"",
		"func moment_step(word: String, _amount: float, _effect: String, _seconds: float, _strength: float) -> void:",
		"\twords.append(word)"
	])
	script.reload()
	listener.set_script(script)
	return listener
