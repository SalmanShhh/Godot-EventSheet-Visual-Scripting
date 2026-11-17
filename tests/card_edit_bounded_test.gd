# Godot EventSheets - taking a card out of a long list, or putting one in, touches only that card.
#
# Deleting a card from the middle of a list of 500 shapes used to draw all 499 that were left, and so did an
# insert, a duplicate, a paste and the undo or redo of any of them. A card that stays now keeps its controls: they
# are renumbered, and the summary beside its title is written again only where the schema works it out from the
# cards around it (a Juice Hold waits for the cards above it). What the list shows afterwards - every title,
# summary, band, selection and the number each card answers to - is exactly what drawing the list afresh shows.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const STEPS_PROPERTY_PATH := "res://addons/eventsheet/editor/inspector/drawing_prefab_steps_property.gd"
const SCHEMA_PATH := "res://addons/eventsheet/editor/inspector/feedback_card_schema.gd"
const P := "card_edit_bounded_test"


static func _prefab() -> EventSheetCardListDrawer:
	var editor_class: GDScript = (load(STEPS_PROPERTY_PATH) as GDScript).get_script_constant_map().get("ShapeStepsEditor") as GDScript
	return editor_class.new() as EventSheetCardListDrawer


static func _juice() -> EventSheetCardListDrawer:
	var schema: Dictionary = (load(SCHEMA_PATH) as GDScript).call("schema")
	return EventSheetCardListDrawer.new({"kind_key": "verb", "schema_dict": schema})


static func _shapes(count: int) -> Array:
	var kinds: Array = ["circle", "ring", "rect", "line", "cone", "arc", "pie"]
	var steps: Array = []
	for index: int in count:
		steps.append({"kind": kinds[index % kinds.size()], "x": float(index), "y": 0.0, "p1": 5.0 + float(index), "p2": 3.0, "p3": 2.0, "color": "#ff8800"})
	return steps


## A Juice list: felt cards with a Pause every tenth card (so the list has bands) and a Hold now and then, whose summary
## depends on the cards above it.
static func _moments(count: int) -> Array:
	var verbs: Array = ["shake", "hitstop", "chromatic", "pulse"]
	var steps: Array = []
	for index: int in count:
		if index % 10 == 9:
			steps.append({"verb": "pause", "seconds": 0.1})
		elif index % 10 == 4:
			steps.append({"verb": "hold_until", "seconds": 0.0})
		else:
			steps.append({"verb": verbs[index % verbs.size()], "amount": 0.5, "seconds": 0.1 + float(index % 5) * 0.05})
	return steps


## Everything the list shows, in order, read off the controls it holds: each band's caption and each row's title,
## summary, summary colour, selection look and the card number the row answers to.
static func _signature(drawer: EventSheetCardListDrawer) -> Array:
	var titles: Dictionary = drawer.get("_titles")
	var badges: Dictionary = drawer.get("_badges")
	var painted: Dictionary = drawer.get("_painted") if drawer.get("_painted") is Dictionary else {}
	var list: Control = drawer.get("_list")
	var shown: Array = [(drawer.get("_fold_button") as Button).text]
	for child: Node in list.get_children():
		if child.is_queued_for_deletion():
			continue
		if child.has_meta("band"):
			var caption: Label = child.get_meta("caption", null) as Label
			shown.append("band: " + (caption.text if caption != null else "?"))
			for row: Node in child.get_child(0).get_children():
				if row.has_method("card_index"):
					shown.append(_row_text(row, titles, badges, painted))
		elif child.has_method("card_index"):
			shown.append(_row_text(child, titles, badges, painted))
		elif child is Label:
			shown.append("caption: " + (child as Label).text)
	return shown


static func _row_text(row: Node, titles: Dictionary, badges: Dictionary, painted: Dictionary) -> String:
	var index: int = int(row.call("card_index"))
	var title: Label = titles.get(index) as Label
	var badge: Label = badges.get(index) as Label
	var badge_text: String = "" if badge == null else "%s|%s|%s" % [badge.text, str(badge.visible), badge.get_theme_color("font_color").to_html()]
	var title_ink: String = "" if title == null else title.get_theme_color("font_color").to_html()
	return "%d %s [%s] %s sel=%s" % [index, "" if title == null else title.text, badge_text, title_ink, str(bool(painted.get(index, false)))]


## The row controls by card number, so a test can tell which survived a change.
static func _rows_of(drawer: EventSheetCardListDrawer) -> Dictionary:
	var found: Dictionary = {}
	var lines: Dictionary = drawer.get("_lines")
	for index: Variant in lines:
		var line: Control = lines[index] as Control
		if line != null and is_instance_valid(line):
			found[int(index)] = line.get_parent().get_instance_id()
	return found


## A list drawn afresh from the same cards, with the same cards open and selected.
static func _fresh(drawer: EventSheetCardListDrawer, maker: Callable) -> EventSheetCardListDrawer:
	var fresh: EventSheetCardListDrawer = maker.call()
	fresh.set_value(drawer.get_value())
	for index: Variant in (drawer.get("_unfolded") as Dictionary):
		fresh.set_unfolded(int(index), true)
	var chosen: Array = drawer.selected_cards()
	for position: int in chosen.size():
		fresh.select_card(int(chosen[position]), "click" if position == 0 else "ctrl")
	return fresh


static func run() -> bool:
	var ok: bool = true
	ok = _prefab_pins() and ok
	ok = _juice_pins() and ok
	ok = _control_pins() and ok
	return ok


static func _prefab_pins() -> bool:
	var table: Array = []
	var drawer: EventSheetCardListDrawer = _prefab()
	drawer.set_value(_shapes(120))
	var before_rows: Dictionary = _rows_of(drawer)

	drawer.select_card(50)
	var built: int = int(drawer.get("cards_built"))
	drawer.remove_selected()
	table.append(["taking a middle card out draws no card", int(drawer.get("cards_built")) - built, 0])
	table.append(["and the list holds one fewer", (drawer.get_value() as Array).size(), 119])
	table.append(["the card after it moved up to its place", (drawer.get_value() as Array)[50]["x"], 51.0])
	var after_rows: Dictionary = _rows_of(drawer)
	table.append(["the card that was 51 kept its controls", after_rows[50], before_rows[51]])
	table.append(["and the card that was 119 kept its too", after_rows[118], before_rows[119]])
	table.append(["a card before the gap kept its controls", after_rows[10], before_rows[10]])
	table.append(["the list reads as drawn afresh", _signature(drawer), _fresh_signature(drawer, _prefab)])

	var gone: Array = drawer.get_value()
	built = int(drawer.get("cards_built"))
	drawer.set_value(_shapes(120))
	table.append(["an undo (the card put back) draws one card", int(drawer.get("cards_built")) - built, 1])
	table.append(["and the list reads as drawn afresh", _signature(drawer), _fresh_signature(drawer, _prefab)])
	built = int(drawer.get("cards_built"))
	drawer.set_value(gone)
	table.append(["a redo (the card taken out again) draws none", int(drawer.get("cards_built")) - built, 0])
	table.append(["and reads as drawn afresh", _signature(drawer), _fresh_signature(drawer, _prefab)])
	drawer.set_value(_shapes(120))

	drawer.select_card(30)
	built = int(drawer.get("cards_built"))
	drawer.duplicate_selected()
	table.append(["a duplicate draws one card", int(drawer.get("cards_built")) - built, 1])
	table.append(["the copy sits under its card", [(drawer.get_value() as Array)[30]["x"], (drawer.get_value() as Array)[31]["x"], (drawer.get_value() as Array)[32]["x"]], [30.0, 30.0, 31.0]])
	table.append(["the copy is the selected one", drawer.selected_cards(), [31]])
	table.append(["and the list reads as drawn afresh", _signature(drawer), _fresh_signature(drawer, _prefab)])

	var text: String = EventSheetCardSchemas.cards_to_text([(drawer.get_value() as Array)[3], (drawer.get_value() as Array)[4]])
	drawer.select_card(80)
	built = int(drawer.get("cards_built"))
	drawer.paste_after_selection(text)
	table.append(["pasting two cards draws two", int(drawer.get("cards_built")) - built, 2])
	table.append(["and the list reads as drawn afresh", _signature(drawer), _fresh_signature(drawer, _prefab)])

	drawer.select_card(5, "click")
	drawer.select_card(70, "ctrl")
	built = int(drawer.get("cards_built"))
	drawer.remove_selected()
	table.append(["taking two cards out draws none", int(drawer.get("cards_built")) - built, 0])
	table.append(["and the list reads as drawn afresh", _signature(drawer), _fresh_signature(drawer, _prefab)])

	# A card that was open is open after the change, and the open card is the same card.
	drawer.set_unfolded(60, true)
	drawer.set_unfolded(10, true)
	drawer.select_card(20)
	built = int(drawer.get("cards_built"))
	drawer.remove_selected()
	table.append(["with two cards open a delete draws just those two again", int(drawer.get("cards_built")) - built, 2])
	table.append(["the open cards moved with their cards", [drawer.is_unfolded(10), drawer.is_unfolded(59), drawer.is_unfolded(60)], [true, true, false]])
	table.append(["and the list reads as drawn afresh", _signature(drawer), _fresh_signature(drawer, _prefab)])

	# An undo hands the list back shut (a view never travels with an undo).
	var value_now: Array = drawer.get_value()
	var trimmed: Array = value_now.duplicate()
	trimmed.remove_at(40)
	drawer.set_value(trimmed)
	table.append(["an outside change shuts the open cards, as it always did", [drawer.is_unfolded(10), drawer.is_unfolded(59)], [false, false]])
	table.append(["and the list reads as drawn afresh", _signature(drawer), _fresh_signature(drawer, _prefab)])

	# A change to a card in place (an undo of a kind change): one card drawn again.
	var changed: Array = drawer.get_value()
	changed[25] = {"kind": "ring", "x": 999.0, "y": 0.0, "p1": 4.0, "p2": 2.0, "p3": 1.0, "color": "#00ff00"}
	built = int(drawer.get("cards_built"))
	drawer.set_value(changed)
	table.append(["one card replaced draws one card", int(drawer.get("cards_built")) - built, 1])
	table.append(["and the list reads as drawn afresh", _signature(drawer), _fresh_signature(drawer, _prefab)])

	# A control a card kept still answers for its card by the card's place now.
	var wanted: Array = drawer.get_value()
	var remove_button: Button = _button_with_tooltip(drawer, 30, "Remove this card.")
	var x_of_that_card: float = float(wanted[30]["x"])
	drawer.select_card(2)
	drawer.remove_selected()
	var button_after: Button = _button_with_tooltip(drawer, 29, "Remove this card.")
	table.append(["the remove button of a card that kept its controls is the same button", button_after == remove_button, true])
	button_after.pressed.emit()
	var xs: Array = []
	for card: Variant in drawer.get_value():
		xs.append(float((card as Dictionary)["x"]))
	table.append(["and pressing it removes that card, not whichever sits at its old place", xs.has(x_of_that_card), false])
	table.append(["the list reads as drawn afresh after that too", _signature(drawer), _fresh_signature(drawer, _prefab)])

	# The edges: first, last, the only card, and the whole list.
	var edge: EventSheetCardListDrawer = _prefab()
	edge.set_value(_shapes(6))
	edge.select_card(0)
	edge.remove_selected()
	edge.select_card(4)
	edge.remove_selected()
	table.append(["the first and the last card taken out leave the others as drawn afresh", _signature(edge), _fresh_signature(edge, _prefab)])
	edge.select_card(0, "click")
	edge.select_card(3, "shift")
	edge.remove_selected()
	table.append(["taking out every card leaves the empty list's own words", (edge.get_value() as Array).size(), 0])
	table.append(["and it reads as drawn afresh", _signature(edge), _fresh_signature(edge, _prefab)])
	edge.set_value(_shapes(3))
	table.append(["a list filled again after that reads as drawn afresh", _signature(edge), _fresh_signature(edge, _prefab)])
	var ok: bool = SUPPORT.pins(P, table)
	for each: EventSheetCardListDrawer in [drawer, edge]:
		each.free()
	return ok


static func _juice_pins() -> bool:
	var table: Array = []
	var drawer: EventSheetCardListDrawer = _juice()
	drawer.set_value(_moments(120))
	var before_rows: Dictionary = _rows_of(drawer)
	table.append(["a Juice list of 120 has bands", (drawer.get("_list") as Control).get_children().filter(func(node: Node) -> bool: return node.has_meta("band")).size() > 5, true])

	# A card inside a band (index 22 is felt, in the band that runs 20 to 23).
	drawer.select_card(22)
	var built: int = int(drawer.get("cards_built"))
	drawer.remove_selected()
	table.append(["a card taken out of a band draws no card", int(drawer.get("cards_built")) - built, 0])
	table.append(["the cards after it kept their controls", _rows_of(drawer)[100], before_rows[101]])
	table.append(["the list reads as drawn afresh", _signature(drawer), _fresh_signature(drawer, _juice)])
	built = int(drawer.get("cards_built"))
	drawer.set_value(_moments(120))
	table.append(["an undo draws one card", int(drawer.get("cards_built")) - built, 1])
	table.append(["and reads as drawn afresh", _signature(drawer), _fresh_signature(drawer, _juice)])

	# A Hold's summary follows the cards above it: take one of them out and the Hold says the new wait.
	drawer.select_card(2)
	drawer.remove_selected()
	var holds_ok: bool = true
	var fresh: EventSheetCardListDrawer = _fresh(drawer, _juice)
	for index: int in range(drawer.get_value().size()):
		if drawer.head_summary_of(index) != fresh.head_summary_of(index):
			holds_ok = false
	table.append(["every summary equals the one a fresh drawing writes, the Holds included", holds_ok, true])

	# A card that stands apart (a Pause) taken out joins two bands into one: drawn whole, and still right.
	drawer.set_value(_moments(120))
	drawer.select_card(9)
	drawer.remove_selected()
	table.append(["taking out a Pause (two bands become one) reads as drawn afresh", _signature(drawer), _fresh_signature(drawer, _juice)])
	# A copy of a Pause is a card on its own.
	drawer.set_value(_moments(120))
	drawer.select_card(19)
	drawer.duplicate_selected()
	table.append(["a duplicated Pause reads as drawn afresh", _signature(drawer), _fresh_signature(drawer, _juice)])
	drawer.set_value(_moments(120))
	drawer.select_card(31)
	built = int(drawer.get("cards_built"))
	drawer.duplicate_selected()
	table.append(["a duplicated card inside a band draws one card", int(drawer.get("cards_built")) - built, 1])
	table.append(["and reads as drawn afresh", _signature(drawer), _fresh_signature(drawer, _juice)])
	# Two cards out of a band of three leave one on its own.
	drawer.set_value(_moments(30))
	drawer.select_card(10, "click")
	drawer.select_card(12, "shift")
	drawer.remove_selected()
	table.append(["a band cut down to one card reads as drawn afresh", _signature(drawer), _fresh_signature(drawer, _juice)])
	var ok: bool = SUPPORT.pins(P, table)
	fresh.free()
	drawer.free()
	return ok


## The controls a card keeps answer for the card by where it stands now, and a list that cannot be patched says so by
## drawing whole instead of drawing wrong.
static func _control_pins() -> bool:
	var table: Array = []
	var drawer: EventSheetCardListDrawer = _prefab()
	drawer.set_value(_shapes(8))
	# A list somebody else took the controls out of is drawn whole.
	var lines: Dictionary = drawer.get("_lines")
	var orphan: Node = (lines[3] as Control).get_parent()
	orphan.get_parent().remove_child(orphan)
	drawer.select_card(1)
	drawer.remove_selected()
	table.append(["a list with a card's controls missing still comes out right", _signature(drawer), _fresh_signature(drawer, _prefab)])
	var empty: EventSheetCardListDrawer = _prefab()
	empty.set_value([])
	empty.set_value(_shapes(4))
	table.append(["an empty list filled reads as drawn afresh", _signature(empty), _fresh_signature(empty, _prefab)])
	var ok: bool = SUPPORT.pins(P, table)
	drawer.free()
	empty.free()
	orphan.free()
	return ok


## The remove button of the card at `index` (found by its tooltip), or null.
static func _button_with_tooltip(drawer: EventSheetCardListDrawer, index: int, tooltip: String) -> Button:
	var surface: Control = (drawer.get("_lines") as Dictionary).get(index) as Control
	if surface == null:
		return null
	for node: Node in surface.find_children("*", "Button", true, false):
		if (node as Button).tooltip_text == EventSheetL10n.translate(tooltip):
			return node as Button
	return null


## What a list drawn afresh from `drawer`'s cards shows.
static func _fresh_signature(drawer: EventSheetCardListDrawer, maker: Callable) -> Array:
	var fresh: EventSheetCardListDrawer = _fresh(drawer, maker)
	var shown: Array = _signature(fresh)
	fresh.free()
	return shown
