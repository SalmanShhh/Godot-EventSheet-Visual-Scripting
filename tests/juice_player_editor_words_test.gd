# Godot EventSheets - what the editor itself says about the Juice Player: the Inspector strip's head,
# the toolbar's segment, the unknown-card finding and the Doctor's section.
#
# The words are PURE functions of a count, a subject or a label, so each is pinned as a value. The ids
# beside them (the Doctor's check id, the finding kind) are frozen and pinned too: a word may change,
# the name a settings list or an inbox files a finding under may not.
class_name JuicePlayerEditorWordsTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const STRIP := preload("res://addons/eventsheet/editor/inspector/feedback_player_strip.gd")
const SEGMENT := preload("res://addons/eventsheet/editor/dock/toolbar_moment_segment.gd")
const FINDINGS := preload("res://addons/eventsheet/editor/interaction/feedback_findings.gd")
const DOCTOR := preload("res://addons/eventforge/feedback_doctor.gd")

const TEST_NAME: String = "juice_player_editor_words"
const SHEET_PATH: String = "user://juice_player_editor_words_sheet.gd"
const SHEET_TEXT: String = "extends Node2D\n\n\nfunc _ready() -> void:\n\t$JuicePlayer.play(1.0)\n"


static func run() -> bool:
	var door: Array = SEGMENT.BUTTONS[SEGMENT.BUTTONS.size() - 1] as Array
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["the strip head with no cards", STRIP.head_text(0, "0.00 s"), "0 juice cards - 0.00 s total"],
		["with one card", STRIP.head_text(1, "0.30 s"), "1 juice card - 0.30 s total"],
		["with three", STRIP.head_text(3, "1.20 s"), "3 juice cards - 1.20 s total"],
		["the toolbar segment is called Juice", SEGMENT.title_for({"kind": SEGMENT.SUBJECT_PLAYER}), "Juice"],
		["its door says which node it opens", door[3], "Select the Juice Player this row is about, so its list opens in the Inspector."],
		["a beat that cannot be previewed says why", SEGMENT.NO_PREVIEW_REASON,
			"Only a Juice Player's list can be previewed here - this beat is a moment the game plays, so there is nothing on a node to sample."],
		["the finding names a juice card", FINDINGS.message_for("kick", "arena.tscn"),
			"This row names a juice card called \"kick\", and no Juice Player in arena.tscn has one. Rename the card, or name a card the player has."],
		["the finding's kind and the Doctor's check id are the frozen ones",
			[FINDINGS.KIND_UNKNOWN_LABEL, DOCTOR.CHECK_ID], ["feedback-label-nobody-has", "feedbacks"]],
		["the Doctor looks for both node names", DOCTOR.PLAYER_WORDS, PackedStringArray(["$FeedbackPlayer", "$JuicePlayer"])],
	])
	var file: FileAccess = FileAccess.open(SHEET_PATH, FileAccess.WRITE)
	file.store_string(SHEET_TEXT)
	file.close()
	var report: Array[Dictionary] = DOCTOR.report(PackedStringArray([SHEET_PATH]))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SHEET_PATH))
	return SUPPORT.pins(TEST_NAME, [
		["the Doctor's summary", str(report[0].get("message", "")) if not report.is_empty() else "<no summary>",
			"Juice Players: 1 sheet(s) play a beat through a Juice Player, and 0 row(s) name a juice card no player in their scene has."],
	]) and ok
