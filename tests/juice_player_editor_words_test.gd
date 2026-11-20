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
		["the strip head with no cards", STRIP.head_text(0, "0.00 s"), "0 juice cards - 0.00 s once through"],
		["with one card", STRIP.head_text(1, "0.30 s"), "1 juice card - 0.30 s once through"],
		["with three", STRIP.head_text(3, "1.20 s"), "3 juice cards - 1.20 s once through"],
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
	ok = strip_words_pins() and ok
	var file: FileAccess = FileAccess.open(SHEET_PATH, FileAccess.WRITE)
	file.store_string(SHEET_TEXT)
	file.close()
	var report: Array[Dictionary] = DOCTOR.report(PackedStringArray([SHEET_PATH]))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SHEET_PATH))
	return label_pins() and SUPPORT.pins(TEST_NAME, [
		["the Doctor's summary", str(report[0].get("message", "")) if not report.is_empty() else "<no summary>",
			"Juice Players: sheets that play a beat through a Juice Player: 1; rows that name a juice card no player in their scene has: 0."],
	]) and ok


## A row from the pack is filed under the id it was saved with (`FeedbackPlayer`, frozen) but READS
## under the class it is now: the object column on a placed row and the name beside a row in the
## picker say Juice Player. A pack that never renamed its class has no label of its own.
static func label_pins() -> bool:
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport._sheet = EventSheetResource.new()
	var pack: Array[ACEDefinition] = []
	for path: String in ["res://eventsheet_addons/juice/juice_player.gd", "res://eventsheet_addons/juice/juice_behavior.gd"]:
		pack.append_array(EventSheetACEGenerator.new().generate_from_script(load(path)))
	viewport._ace_registry.refresh_from_sources([], true, pack)
	var from_player: ACEDefinition = viewport._find_definition("FeedbackPlayer", "method:play")
	var from_juice: ACEDefinition = viewport._find_definition("JuiceBehavior", "method:moment")
	var labels: Array = [viewport._row_builder._object_label_for("FeedbackPlayer", "method:play", {"target": "$JuicePlayer"}),
		viewport._row_builder._object_label_for("FeedbackPlayer", "signal:on_loop", {})]
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["a placed row's object column says Juice Player", labels, ["JuicePlayer", "JuicePlayer"]],
		["the definition carries the label beside the frozen id",
			[from_player.provider_id if from_player != null else "<none>", from_player.metadata.get("provider_label", "") if from_player != null else "<none>"],
			["FeedbackPlayer", "JuicePlayer"]],
		["a pack whose class was never renamed carries none", str(from_juice.metadata.has("provider_label")) if from_juice != null else "<none>", "false"],
	])
	viewport.free()
	return ok


## The two lines of the strip that read alike on the node: the preview's tick says it repeats the PREVIEW, and
## the head says its time is one pass. The node's own loop is a different thing and the tooltip says which.
static func strip_words_pins() -> bool:
	var strip: VBoxContainer = STRIP.new()
	var ticks: Array = strip.find_children("*", "CheckBox", true, false)
	var words: PackedStringArray = PackedStringArray()
	for tick: Node in ticks:
		words.append((tick as CheckBox).text)
	var labels: PackedStringArray = PackedStringArray()
	for label: Node in strip.find_children("*", "Label", true, false):
		labels.append((label as Label).text)
	var head: Label = strip._head
	var tip: String = ((ticks[0] as CheckBox).tooltip_text) if not ticks.is_empty() else ""
	var rows: Array = [
		["the preview's tick says it repeats the preview", words, PackedStringArray(["Repeat the preview"])],
		["under the label Preview, not the node's Loop", labels.has("Preview") and not labels.has("Repeat"), true],
		["its tooltip names the Loop tick as the game's own loop", tip.contains("Loop tick on the node"), true],
		["the head line explains its number in a tooltip", head.tooltip_text.begins_with("How long one pass of the list takes"), true],
		["and the number is one pass, not a sum of the cards", head.tooltip_text.contains("start together, so their times do not add up"), true],
	]
	strip.free()
	return SUPPORT.pins(TEST_NAME, rows)
