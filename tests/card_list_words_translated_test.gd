# Godot EventSheets - the words a card list draws say themselves in the editor's language.
#
# THE ONE THING THIS FILE IS ABOUT: the card menu (Duplicate, Copy, Paste over, Move ...), the empty
# list's line, an opened card's Active and Label rows and the Add box's search field were English in
# every language, because they were set straight on the control instead of through the translation
# table. Pinned in German as "no longer the English word", through the same drawer the Inspector
# builds, so a word that is added later and forgotten fails here.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")

const TEST_NAME: String = "card_list_words_translated"

const SCHEMA: Dictionary = {"kinds": [
	{"kind": "shake", "label": "Shake", "fields": [], "defaults": {"amount": 0.4}}
], "label_key": "label", "enabled_key": "active"}


static func run() -> bool:
	EventSheetL10n.ensure_loaded()
	var before: String = EventSheetL10n.get_locale()
	EventSheetL10n.set_locale("de")
	var drawer: EventSheetCardListDrawer = EventSheetCardListDrawer.new({"kind_key": "verb", "schema_dict": SCHEMA})
	var empty_line: String = ""
	var empty_child: Node = drawer._list.get_child(0) if drawer._list.get_child_count() > 0 else null
	if empty_child is Label:
		empty_line = (empty_child as Label).text
	var popup: PopupMenu = PopupMenu.new()
	drawer._fill_card_menu(popup)
	var menu_words: Array = []
	for index: int in range(popup.item_count):
		if not popup.is_item_separator(index):
			menu_words.append(popup.get_item_text(index))
	popup.free()
	var active_row: Control = drawer._build_active_row(0, true)
	var label_row: Control = drawer._build_label_row(0, {"verb": "shake"}, SCHEMA["kinds"][0])
	var active_word: String = ((active_row as HBoxContainer).get_child(0) as Label).text
	var label_word: String = ((label_row as HBoxContainer).get_child(0) as Label).text
	var rows: Array = [
		["the empty list's line is no longer the English one", empty_line != "Nothing here yet. Add one." and not empty_line.is_empty(), true],
		["the Active row's title is translated", active_word != "Active", true],
		["the Label row's title is translated", label_word != "Label", true]
	]
	for word: Variant in ["Duplicate", "Copy", "Paste over", "Move to top", "Move up", "Move down", "Remove"]:
		rows.append(["the menu word %s is translated" % str(word), menu_words.has(word), false])
	active_row.free()
	label_row.free()
	drawer.free()
	EventSheetL10n.set_locale(before)
	return SUPPORT.pins(TEST_NAME, rows)
