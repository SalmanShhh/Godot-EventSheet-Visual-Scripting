@tool
extends RefCounted
# Godot EventSheets - the windows the canvas build touched say their words in the reader's language.
# Opened in a German editor, the Welcome answers, the tour, Loose Ends, the sheet map, the Sheet Type
# kinds, the shortcut names and the Words page's left column still read in English: their sentences
# were never handed to the translation tables, or were set straight from a table without a translate
# call. Pinned in German, as values, through the same static readers the windows show.


const SUPPORT := preload("res://tests/support.gd")
const NAME := "window_words_translated_test"
const SHEET_TYPE_DIALOG := preload("res://addons/eventsheet/editor/dock/sheet_type_dialog.gd")
const TOUR := preload("res://addons/eventsheet/editor/dock/tour_window.gd")
const WELCOME := preload("res://addons/eventsheet/editor/dock/welcome_window.gd")
const LOOSE_ENDS := preload("res://addons/eventsheet/editor/dock/loose_ends_panel.gd")


static func run() -> bool:
	EventSheetL10n.ensure_loaded()
	var before: String = EventSheetL10n.get_locale()
	EventSheetL10n.set_locale("de")
	var sheet: EventSheetResource = EventSheetResource.new()
	var parked: EventRow = EventRow.new()
	parked.trigger_id = "OnReady"
	parked.enabled = false
	sheet.events.append(parked)
	var loose: Array = LOOSE_ENDS.loose_ends(sheet, [])
	var words_page: AcceptDialog = EventSheetWordsSettingsDialog.new()
	var words_title: String = words_page.title
	words_page.free()
	var rows: Array = [
		["the tour's first step", str(TOUR.steps()[0]["task"]),
			"Sieh dir das Blatt an: Bedingungen stehen in der linken Spur, Aktionen in der rechten."],
		["a Welcome answer's summary", WELCOME.choice_summary(WELCOME.CAME_FROM_NEW).begins_with("Setzt: "), true],
		["a turned-off event in Loose Ends", str((loose[0] as Dictionary).get("label", "")) if not loose.is_empty() else "",
			"Ereignis 1 ist ausgeschaltet"],
		["a Sheet Type kind's sentence", EventSheetL10n.translate(SHEET_TYPE_DIALOG.TYPE_HINTS[0]),
			"Einfache Ereignisse auf dem Node, an den dieses Blatt angehängt ist."],
		["a shortcut's name", EventSheetL10n.translate(EventSheetShortcuts.label_for("add_comment")), "Kommentar hinzufügen"],
		["what a word names", EventSheetL10n.translate(EventSheetWords.names_what("group")), "eine Godot-Gruppe"],
		["the Words page's title", words_title, "Wörter: wähle, wie das Blatt Dinge nennt"],
		["a preset's name", EventSheetWords.preset_label(EventSheetWords.PRESET_FAMILIAR), "Vertraute Wörter"],
	]
	EventSheetL10n.set_locale(before)
	return SUPPORT.pins(NAME, rows)
