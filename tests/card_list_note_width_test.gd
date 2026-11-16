# Godot EventSheets - the paragraph under a card list takes the Inspector's whole width.
#
# THE ONE THING THIS FILE IS ABOUT: a note under a property sits in the value column, which is half the
# Inspector. For a short line that is right, but the paragraph a card list carries ("One juice card per
# effect...") wrapped into a column a few words wide and ran a dozen lines down. A note under a card
# list is built as a row without a label column, so it spans the row; every other note stays where it
# was.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")

const TEST_NAME: String = "card_list_note_width"


static func run() -> bool:
	var row_type: GDScript = EventSheetAttributeDrawers.widgets().NoteRow
	var rows: Array = [
		["a note keeps its label column by default", row_type.label_wanted(false), true],
		["a full-width note gives the column up", row_type.label_wanted(true), false],
		["a card list's notes span the row", EventSheetAttributeDrawers.notes_span_row("eventsheet:cards:kind=verb,schema=feedback_steps"), true],
		["a table's notes stay in the value column", EventSheetAttributeDrawers.notes_span_row("eventsheet:table:cols=a|b"), false],
		["so does a plain property's", EventSheetAttributeDrawers.notes_span_row(""), false],
		["an info paragraph from any pack asks to span the row", bool(EventSheetAttributeDrawers.widgets().build_info_panel("words").get_meta("spans_row", false)), true]
	]
	return SUPPORT.pins(TEST_NAME, rows)
