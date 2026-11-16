# Godot EventSheets - a card that is drawn knowing the list it sits in.
#
# THE ONE THING THIS FILE IS ABOUT: some of what a card says depends on the cards around it - how long a
# Hold will wait is what the cards above it take, which cards start together is a question about
# neighbours, and a Hold can be pointed at one card above it. So a badge or a note may ask for the list and
# its own place in it (a callable that takes three arguments); one that takes the card alone is called as it
# always was. A kind carries search words as well as its title, the cards that start together sit on one
# faint band that is a fill and never a border, and a short badge is never broken one letter to a line.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")

const TEST_NAME: String = "card_list_context"


static func _lone(card: Dictionary) -> String:
	return "alone " + str(card.get("verb", ""))


static func _with_list(card: Dictionary, cards: Array, index: int) -> String:
	return "%s %d of %d" % [str(card.get("verb", "")), index, cards.size()]


static func _together(cards: Array) -> Array:
	var ids: Array = []
	for card: Variant in cards:
		ids.append(-1 if str((card as Dictionary).get("verb", "")) == "wait" else 0)
	return ids


static func _above(cards: Array, index: int) -> Array:
	var found: Array = []
	for walked: int in range(index):
		found.append({"value": str((cards[walked] as Dictionary).get("label", "")), "text": "Card " + str((cards[walked] as Dictionary).get("label", ""))})
	return found


static func _schema() -> Dictionary:
	return {"kinds": [
		{"kind": "a", "label": "Alpha", "fields": [], "badge": _lone, "search": PackedStringArray(["first", "wait"])},
		{"kind": "b", "label": "Beta", "fields": [{"key": "waits_for", "label": "Waits for", "drawer": "above",
			"above": _above, "all_label": "All cards above"}], "badge": _with_list},
		{"kind": "wait", "label": "Wait", "fields": []}
	], "together": _together}


static func run() -> bool:
	var ok: bool = true
	ok = _badge_pins() and ok
	ok = _search_pins() and ok
	ok = _band_pins() and ok
	ok = _above_pins() and ok
	ok = _surface_pins() and ok
	return ok


static func _badge_pins() -> bool:
	var schema: Dictionary = _schema()
	var cards: Array = [{"verb": "a"}, {"verb": "b"}]
	var drawer: EventSheetCardListDrawer = EventSheetCardListDrawer.new({"kind_key": "verb", "schema_dict": schema})
	drawer.set_value(cards)
	var badge_a: Label = _badge_of(drawer, 0)
	var badge_b: Label = _badge_of(drawer, 1)
	var short_text: String = badge_a.text
	var wide_enough: bool = badge_b.custom_minimum_size.x >= badge_b.get_theme_font("font").get_string_size(
		badge_b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, badge_b.get_theme_font_size("font_size")).x - 1.0
	var texts: Array = [badge_a.text, badge_b.text]
	drawer.free()
	return SUPPORT.pins(TEST_NAME, [
		["a badge that takes the card alone is called as it always was", texts[0], "alone a"],
		["a badge that takes three arguments is handed the list and its own place in it", texts[1], "b 1 of 2"],
		["a short badge keeps room for all of its words, so it is not broken one letter to a line", wide_enough, true],
		["and still reads what it says", short_text, "alone a"]
	])


static func _badge_of(drawer: EventSheetCardListDrawer, index: int) -> Label:
	var surface: PanelContainer = drawer._lines.get(index) as PanelContainer
	for child: Node in surface.find_children("*", "Label", true, false):
		if (child as Label).size_flags_horizontal == Control.SIZE_EXPAND_FILL:
			return child as Label
	return null


static func _search_pins() -> bool:
	var schema: Dictionary = _schema()
	var entry_a: Dictionary = EventSheetCardSchemas.kind_entry(schema, "a")
	var entry_b: Dictionary = EventSheetCardSchemas.kind_entry(schema, "b")
	return SUPPORT.pins(TEST_NAME, [
		["the title is searched", EventSheetCardSchemas.kind_matches(entry_a, "alp"), true],
		["a kind's own search words are searched too", EventSheetCardSchemas.kind_matches(entry_a, "wait"), true],
		["a kind without that word does not match", EventSheetCardSchemas.kind_matches(entry_b, "wait"), false],
		["an empty search matches everything", EventSheetCardSchemas.kind_matches(entry_b, ""), true]
	])


static func _band_pins() -> bool:
	var drawer: EventSheetCardListDrawer = EventSheetCardListDrawer.new({"kind_key": "verb", "schema_dict": _schema()})
	drawer.set_value([{"verb": "a"}, {"verb": "b"}, {"verb": "wait"}, {"verb": "a"}])
	var kids: Array = []
	for child: Node in drawer._list.get_children():
		kids.append(child.get_class() if child is not PanelContainer or not child.has_meta("band") else "band")
	var band: PanelContainer = null
	for child: Node in drawer._list.get_children():
		if child.has_meta("band"):
			band = child as PanelContainer
	var box: StyleBoxFlat = band.get_theme_stylebox("panel") as StyleBoxFlat if band != null else null
	var border: int = (box.border_width_left + box.border_width_top + box.border_width_right + box.border_width_bottom) if box != null else -1
	var faint: bool = box != null and box.bg_color.a < 0.2
	var in_band: int = band.get_child(0).get_child_count() if band != null else 0
	drawer.free()
	return SUPPORT.pins(TEST_NAME, [
		["two cards that start together sit on one band, a card alone does not", kids.size(), 3],
		["the band holds the two cards", in_band, 2],
		["the band is a faint fill", faint, true],
		["and has no border", border, 0]
	])


static func _above_pins() -> bool:
	var drawer: EventSheetCardListDrawer = EventSheetCardListDrawer.new({"kind_key": "verb", "schema_dict": _schema()})
	var cards: Array = [{"verb": "a", "label": "One"}, {"verb": "a", "label": "Two"}, {"verb": "b"}]
	drawer.set_value(cards)
	var field: Dictionary = (EventSheetCardSchemas.fields_of(EventSheetCardSchemas.kind_entry(_schema(), "b")) as Array)[0]
	var written: Array = []
	var write: Callable = func(value: Variant) -> void: written.append(value)
	var picker: OptionButton = drawer._build_field_editor(drawer.get_value()[2], field, write, 2) as OptionButton
	var items: Array = []
	for index: int in range(picker.item_count):
		items.append(picker.get_item_text(index))
	picker.item_selected.emit(2)
	var chose_two: Array = written.duplicate()
	picker.item_selected.emit(0)
	var after_all: Array = drawer.get_value()[2].keys()
	var stale: Dictionary = (drawer.get_value()[2] as Dictionary).duplicate()
	stale["waits_for"] = "One"
	var stale_picker: OptionButton = drawer._build_field_editor(stale, field, write, 2) as OptionButton
	stale["waits_for"] = "Gone"
	var gone_picker: OptionButton = drawer._build_field_editor(stale, field, write, 2) as OptionButton
	var gone_text: String = gone_picker.get_item_text(gone_picker.selected)
	var one_selected: String = stale_picker.get_item_text(stale_picker.selected)
	picker.free()
	stale_picker.free()
	gone_picker.free()
	drawer.free()
	return SUPPORT.pins(TEST_NAME, [
		["the picker lists every card above, after the word for all of them", items, ["All cards above", "Card One", "Card Two"]],
		["choosing a card writes its name", chose_two, ["Two"]],
		["choosing all of them erases the key, so a card nobody changed stores nothing new", after_all, ["verb"]],
		["a stored name shows its card", one_selected, "Card One"],
		["a stored name that is no card above is still shown, not silently dropped", gone_text.contains("Gone"), true]
	])


## An open card is ONE surface: its head and its fields share the same panel with one hairline round the
## whole of it, and the card's menu sits in the head line rather than alone between the two.
static func _surface_pins() -> bool:
	var drawer: EventSheetCardListDrawer = EventSheetCardListDrawer.new({"kind_key": "verb", "schema_dict": _schema()})
	drawer.set_value([{"verb": "a"}, {"verb": "wait"}])
	var shut: PanelContainer = drawer._lines[1] as PanelContainer
	var shut_children: int = shut.get_child(0).get_child_count()
	var shut_border: int = (shut.get_theme_stylebox("panel") as StyleBoxFlat).border_width_left
	drawer._unfolded[1] = true
	drawer._rebuild()
	var surface: PanelContainer = drawer._lines[1] as PanelContainer
	var stack: Node = surface.get_child(0)
	var alone: int = 0
	for child: Node in stack.get_children():
		if child is MenuButton:
			alone += 1
	var head: Node = stack.get_child(0)
	var menus_in_head: int = head.find_children("*", "MenuButton", false, false).size()
	var box: StyleBoxFlat = surface.get_theme_stylebox("panel") as StyleBoxFlat
	var parts: int = stack.get_child_count()
	var hairline: int = box.border_width_left + box.border_width_top + box.border_width_right + box.border_width_bottom
	drawer.free()
	return SUPPORT.pins(TEST_NAME, [
		["a shut card is its head alone on the surface", shut_children, 1],
		["and has no hairline", shut_border, 0],
		["an open card holds its head and its fields on the same surface", parts, 2],
		["no menu button stands alone between them", alone, 0],
		["the menu is in the head line", menus_in_head, 1],
		["one hairline goes round the whole open card", hairline, 4]
	])
