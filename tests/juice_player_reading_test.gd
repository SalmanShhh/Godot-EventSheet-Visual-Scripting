# Godot EventSheets - a Juice Player line reopens as a Juice Player row, not as a sound row.
#
# Before this, `$FeedbackPlayer.play(0.6)` in an opened `.gd` was claimed by the built-in "Play Sound"
# row (its template is `{target}.play({from})`), and `.stop()` by "Stop Sound": the bytes were right
# and the sentence was wrong. The fix must leave the bytes exactly where they are, and must not take
# the sound reading away from a line that really plays a sound.
class_name JuicePlayerReadingTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")

const TEST_NAME: String = "juice_player_reading"

const PLAYER_LINES: String = "extends Node2D\n\n\nfunc _ready() -> void:\n\t$FeedbackPlayer.play(0.6)\n\t$JuicePlayer.play(1.0)\n\t$FeedbackPlayer.stop()\n"
const WAIT_LINES: String = "extends Node2D


func _ready() -> void:
	await $JuicePlayer.play_and_wait(1.0)
"
const SOUND_LINES: String = "extends Node2D\n\n\nfunc _ready() -> void:\n\t$AudioStreamPlayer2D.play(0.5)\n\t$AudioStreamPlayer2D.stop()\n"


static func run() -> bool:
	return SUPPORT.pins(TEST_NAME, [
		["the player lines are the pack's own rows", _rows(PLAYER_LINES), [["FeedbackPlayer", "method:play"],
			["FeedbackPlayer", "method:play"], ["FeedbackPlayer", "method:stop"]]],
		["a player line is not read as a sound", _ids(PLAYER_LINES).has("AudioPlay"), false],
		["nor is its stop", _ids(PLAYER_LINES).has("AudioStop"), false],
		["the player lines re-save byte for byte", SUPPORT.reemit(PLAYER_LINES, "user://juice_player_reading.gd"), PLAYER_LINES],
		["a play and wait line is the pack's row too", _rows(WAIT_LINES), [["FeedbackPlayer", "method:play_and_wait"]]],
		["and re-saves byte for byte", SUPPORT.reemit(WAIT_LINES, "user://juice_player_reading_wait.gd"), WAIT_LINES],
		["a sound line keeps its sound rows", _ids(SOUND_LINES), ["AudioPlay", "AudioStop"]],
		["and re-saves byte for byte", SUPPORT.reemit(SOUND_LINES, "user://juice_player_reading_sound.gd"), SOUND_LINES],
	])


static func _ids(source: String) -> Array:
	var ids: Array = []
	var sheet: EventSheetResource = SUPPORT.reopen(source)
	for event: Variant in sheet.events:
		if event is EventRow:
			for action: Variant in (event as EventRow).actions:
				ids.append(str((action as ACEAction).ace_id) if action is ACEAction else (action as Resource).get_class())
	return ids


## The provider and verb of every action a source reopens as.
static func _rows(source: String) -> Array:
	var rows: Array = []
	var sheet: EventSheetResource = SUPPORT.reopen(source)
	for event: Variant in sheet.events:
		if event is EventRow:
			for action: Variant in (event as EventRow).actions:
				if action is ACEAction:
					rows.append([str((action as ACEAction).provider_id), str((action as ACEAction).ace_id)])
	return rows
