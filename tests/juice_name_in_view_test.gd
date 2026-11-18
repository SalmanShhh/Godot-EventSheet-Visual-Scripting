# Godot EventSheets - the words a reader sees call the feature Juice.
#
# The toolbar's contextual segment, the buttons and hovers on it, and the notes of the unreleased
# changes that the editor shows on its What's new page must not name the Juice Player's rows or the
# player itself by an older name. Ids, templates, saved keys and signal names are not words a reader
# sees and are not looked at here.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "juice_name_in_view_test"
const WHATS_NEW := "res://addons/eventsheet/help/whatsnew.esdoc"

## Names the rows carried before they said juice. None may stand in the page the editor shows.
const OLD_ROW_NAMES: PackedStringArray = [
	"Feedbacks Duration", "Feedbacks Progress", "Play Feedbacks", "Set Feedback Field", "Set Feedback Timing",
	"Set Feedback Chance", "Set Feedback Label", "Scale Feedback Amounts", "Retime Feedbacks",
	"Pick One Feedback Of", "Copy Feedbacks From", "Duplicate Feedback ", "Enable or Disable Feedback",
	"the Feedback Player's row of buttons", "the same feedback cards",
]


static func run() -> bool:
	var ok: bool = true
	ok = _segment_words() and ok
	ok = _whats_new_words() and ok
	ok = _connected_signal_words() and ok
	return ok


## What the segment leads with, what its buttons say and what they say when hovered.
static func _segment_words() -> bool:
	var words: PackedStringArray = PackedStringArray()
	for kind: String in ["player", "moment", "block"]:
		words.append(EventSheetMomentSegment.title_for({"kind": kind, "label": "hit"}))
	for entry: Array in EventSheetMomentSegment.BUTTONS:
		words.append(str(entry[1]))
		words.append(str(entry[3]))
	words.append(EventSheetMomentSegment.NO_PREVIEW_REASON)
	var named: PackedStringArray = PackedStringArray()
	for word: String in words:
		if word.to_lower().contains("feedback"):
			named.append(word)
	return SUPPORT.pins(P, [
		["the segment leads a player row with Juice", EventSheetMomentSegment.title_for({"kind": "player", "label": ""}), "Juice"],
		["no word on the segment names the feature by an older name", named, PackedStringArray()],
	])


static func _whats_new_words() -> bool:
	var page: String = FileAccess.get_file_as_string(WHATS_NEW)
	var found: PackedStringArray = PackedStringArray()
	for name: String in OLD_ROW_NAMES:
		if page.contains(name):
			found.append(name)
	return SUPPORT.pins(P, [
		["the What's new page was read", page.length() > 1000, true],
		["no older row name stands in the What's new page", found, PackedStringArray()],
	])


## A script that connects one of the Juice Player's signals on a node the sheet cannot tell is a Juice
## Player reads the signal's row under the words the picker shows, not under its id spelt out.
static func _connected_signal_words() -> bool:
	var view: EventSheetViewport = EventSheetViewport.new()
	view.set_ace_registry(EventSheetACERegistry.new())
	var words: PackedStringArray = PackedStringArray()
	for signal_id: String in ["on_feedback_signal", "on_feedbacks_started", "on_feedbacks_finished", "on_feedback_skipped"]:
		words.append(view._row_builder._trigger_display_text("", "signal:%s" % signal_id))
	view.free()
	return SUPPORT.pins(P, [
		["the Juice Player's connected signals read under the picker's words", words,
			PackedStringArray(["On Juice Signal", "On Juice Started", "On Juice Finished", "On Juice Card Skipped"])],
	])
