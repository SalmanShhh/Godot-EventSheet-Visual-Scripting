# Godot EventSheets - a hand-written line on a Juice Player reopens as that player's own row.
#
# THE ONE THING THIS FILE IS ABOUT: `$HitJuice.stop()` written in a script, on a node the script's scene
# says is a Juice Player, reopens as the pack's Stop row and not as a plain method call, for every verb the
# pack ships a row for, and the file saves back byte for byte. The lines are the pack's own examples with
# the node's name put in; the scene is a fixture saved beside the tests. The value-returning verbs are
# expressions used inside other rows, not rows, and have no line of their own.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const SCRIPT_PATH: String = "res://tests/fixtures/juice_hit_events.gd"
const TEST_NAME: String = "juice_player_lines"

## The pack's verbs that return a value: they are read inside other rows, so no line of theirs is a row.
const EXPRESSION_VERBS: PackedStringArray = ["feedbacks_progress", "feedbacks_duration", "feedback_count",
	"feedback_label_at", "feedback_field", "feedback_progress", "feedback_duration", "current_feedback", "loops_left"]


static func run() -> bool:
	EventSheetSceneConnections.clear_cache()
	var lines: PackedStringArray = PackedStringArray()
	for entry: Dictionary in EventForgePackSpellings.entries():
		var line: String = EventForgePackSpellings._fixture_line(entry)
		if line.contains("$JuicePlayer"):
			lines.append(line.replace("$JuicePlayer", "$HitJuice"))
	var not_own: PackedStringArray = PackedStringArray()
	var not_exact: PackedStringArray = PackedStringArray()
	for line: String in lines:
		var body: String = ("if %s:\n\t\tpass" % line) if _is_condition(line) else line
		var source: String = "extends Node2D\n\n\nfunc _ready() -> void:\n\t%s\n" % body
		var sheet: EventSheetResource = SUPPORT.reopen(source, true, SCRIPT_PATH)
		if _provider_of(sheet) != "FeedbackPlayer":
			not_own.append(line)
		sheet.external_source_path = SCRIPT_PATH
		if SUPPORT.compile_output(sheet, SCRIPT_PATH) != source:
			not_exact.append(line)
	var plain: String = "extends Node2D\n\n\nfunc _ready() -> void:\n\t$Body.stop()\n"
	var plain_sheet: EventSheetResource = SUPPORT.reopen(plain, true, SCRIPT_PATH)
	return SUPPORT.pins(TEST_NAME, [
		["every verb the pack has a row for has a line", lines.size() >= 40, true],
		["each line on a player of the scene reopens as the pack's own row", not_own, PackedStringArray()],
		["and saves back byte for byte", not_exact, PackedStringArray()],
		["a line on a node the scene does not say is a player stays a plain call", _provider_of(plain_sheet) == "FeedbackPlayer", false],
		["the verbs with no line of their own are the nine that return a value", EXPRESSION_VERBS.size(), 9]
	])


static func _is_condition(line: String) -> bool:
	for verb: String in ["is_playing", "has_played", "feedback_is_playing", "has_feedback", "feedback_is_enabled"]:
		if line.contains("." + verb + "("):
			return true
	return false


static func _provider_of(sheet: EventSheetResource) -> String:
	for event: Variant in sheet.events:
		if event is EventRow:
			for condition: Variant in (event as EventRow).conditions:
				if str((condition as Resource).get("provider_id")) == "FeedbackPlayer":
					return "FeedbackPlayer"
			for action: Variant in (event as EventRow).actions:
				return str((action as Resource).get("provider_id"))
	return ""
