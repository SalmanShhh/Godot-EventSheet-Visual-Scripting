# Godot EventSheets - the card-list drawer: an Array of Dictionaries edited as a list of cards.
#
# One list of cards, one editor. A Drawing Prefab's shapes and any other "a list of things, each of a
# kind, each with its own fields" property are the same picture: a stripe coloured by category, a drag
# handle, a fold arrow, an enable box, a label, a badge the schema computes, and a menu - with an "Add"
# dropdown you can type into underneath. Unfolding a card shows what that kind explains, then its own
# fields drawn with the REAL drawers (unit, toggles, swatch, curve, texture), then whatever the running
# game is writing back, greyed.
#
# WHAT THIS IS NOT. Nothing here reaches a sheet row: the model is a condition asks and an action does,
# and a list of cards is Inspector chrome for a property, exactly like the table drawer beside it.
# Nothing here reaches generated game code either - without the editor plugin the property is a plain
# Array field and the game reads the same Dictionaries it always did.
#
# The schema (what a kind is called, what it explains, which fields it has) and every operation on the
# array live in card_schemas.gd, so the contract is pinned by a headless suite and this file is only
# the picture of it.
@tool
class_name EventSheetCardListDrawer
extends VBoxContainer

signal value_changed(value: Array)

## The ids of the card menu's entries. The first seven are the ones every list has had; the ids are kept
## so a saved shortcut or a test that names one still means the same entry.
## How many whole lines the Add box shows before it scrolls.
const ADD_BOX_LINES: int = 14

const MENU_DUPLICATE: int = 0
const MENU_COPY: int = 1
const MENU_PASTE_OVER: int = 2
const MENU_MOVE_TO_TOP: int = 3
const MENU_MOVE_UP: int = 4
const MENU_MOVE_DOWN: int = 5
const MENU_REMOVE: int = 6
const MENU_CUT: int = 7
const MENU_PASTE_AFTER: int = 8
## And the one that only a list that can play its cards has.
const MENU_PLAY_FROM: int = 20

## The drag payload's own key. Cards only accept a drag that came from the SAME drawer instance, so
## two card lists open in one Inspector cannot swallow each other's rows.
const DRAG_KEY: String = "eventsheet_card_index"

## The marker parsers (`parse_unit_spec`, `parse_toggle_spec`), reached BY PATH and called as
## statics. A card field names its editor with the SAME words an `eventsheet:` export marker uses,
## so the parsing must be the one already shipped rather than a second copy - and by path rather
## than by class name because that file names this one, and two files naming each other is a cycle.
const ATTRIBUTE_DRAWERS_PATH: String = "res://addons/eventsheet/editor/attribute_drawers.gd"

## How finely a number cell moves - and, because a Range snaps the value it SHOWS to a multiple of
## its step, how much of a designer's stored number survives being looked at. A float cell steps by
## the same thousandth the unit field and the corners boxes step by; a field the schema calls an
## `int` steps by a whole one.
const FLOAT_STEP: float = 0.001
const INT_STEP: float = 1.0

static var _drawers_script: Script = null


## The attribute-drawers script, loaded on first use and cached for the session.
## The file that draws the fields that point at something in the scene, loaded the first time one is drawn.
const SCENE_FIELDS_PATH: String = "res://addons/eventsheet/editor/inspector/juice_card_fields.gd"


static func attribute_fields() -> Script:
	return load(SCENE_FIELDS_PATH) as Script


static func attribute_drawers() -> Script:
	if _drawers_script == null:
		_drawers_script = load(ATTRIBUTE_DRAWERS_PATH)
	return _drawers_script

var editable: bool = true

var _spec: Dictionary = {"kind_key": "kind", "schema": "", "stripe_key": "category"}
var _schema: Dictionary = {}
var _cards: Array = []
## Which cards are open, by index. Folding is a view, so it is deliberately not stored in the data.
var _unfolded: Dictionary = {}
## Which foldouts inside an open card are open, by "index:name". Closed until opened, and a view like the above.
var _open_folds: Dictionary = {}
## The clock marks drawn on card heads, by position, so one can be lit or put out as its card's timing changes.
var _timing_marks: Dictionary = {}
var _list: VBoxContainer = null
var _fold_button: Button = null
var _more_button: MenuButton = null
var _body: VBoxContainer = null
var _add_button: Button = null
var _add_popup: PopupPanel = null
var _add_filter: LineEdit = null
var _add_tree: Tree = null
## The object whose list this is, when the owner told us (the Inspector does). A card's pickers, its
## play mark and the footer under the list all need to know which object they are about.
var _edited: Object = null
## What the schema's footer built for the edited object, kept so it can be refreshed as the list changes.
var _footer: Control = null
## The note lines drawn right now, so one can be rewritten in place when a number beside it changes
## instead of rebuilding the card under the cursor. Each is {label, field, index}.
var _notes: Array = []
## The cards whose play mark is lit (the ones sounding right now), and the mark buttons drawn, by position.
var _lit: PackedInt32Array = PackedInt32Array()
var _marks: Dictionary = {}
## Which cards are selected, by index. Selecting is a view, like folding: it is never stored in the data,
## it follows its cards through a move, and an outside change to the list (an undo) clears it.
var _selected: Dictionary = {}
## The card a Shift+click measures its run from: the one last clicked or Ctrl+clicked.
var _anchor: int = -1
## Each card's line and title as drawn right now, by index, so a selection can be painted in place
## instead of rebuilding the list under the cursor (which would also lose the keyboard focus).
var _lines: Dictionary = {}
var _titles: Dictionary = {}
## The picture on each card line and the summary beside it, by index, for a schema whose card line
## follows its numbers (`live_head`): a write repaints them where they stand.
var _head_tiles: Dictionary = {}
var _badges: Dictionary = {}
## Entries of the list that are not Dictionaries (nothing a card can show), as [original index, value]. They
## are not drawn, but they are handed back where they were instead of being dropped from the file.
var _junk: Array = []


## `spec` is the parsed marker - {kind_key, schema, stripe_key} - and may carry `schema_dict` instead
## of a registered schema name, which is how an owner with its own vocabulary (the Drawing Prefab)
## hands its kinds straight over.
func _init(spec: Dictionary = {}) -> void:
	for key: Variant in spec:
		_spec[str(key)] = spec[key]
	_schema = EventSheetCardSchemas.schema_for(_spec)
	# The list holds the keyboard once a card is clicked, so Ctrl+C, Ctrl+V, Ctrl+D and Delete reach it.
	focus_mode = Control.FOCUS_CLICK
	focus_entered.connect(_paint_selection)
	focus_exited.connect(_paint_selection)
	_build_chrome()
	_rebuild()


## The schema this drawer resolved - the Drawing Prefab's own, or the one registered under the
## marker's name.
func schema() -> Dictionary:
	return _schema


func set_value(cards: Array) -> void:
	_cards = []
	_junk = []
	for position: int in range(cards.size()):
		var card: Variant = cards[position]
		if card is Dictionary:
			_cards.append((card as Dictionary).duplicate(true))
		else:
			_junk.append([position, card])
	_unfolded.clear()
	_open_folds.clear()
	_selected.clear()
	_anchor = -1
	_rebuild()


func get_value() -> Array:
	var value: Array = _cards.duplicate(true)
	# What the list held that is not a card goes back where it was (or at the end, when the list is shorter
	# now): an edit never drops an entry it does not understand.
	for kept: Variant in _junk:
		value.insert(mini(int((kept as Array)[0]), value.size()), (kept as Array)[1])
	return value


## Whether the schema asks for a play mark on each card and a "Play from here" entry in each menu.
func _marks_wanted() -> bool:
	var marks: Variant = _schema.get("marks")
	return marks is Dictionary and (marks as Dictionary).get("run") is Callable


## Hands a play request to the schema's handler, with the object this list belongs to.
func _run_mark(action: String, index: int) -> void:
	var marks: Variant = _schema.get("marks")
	if marks is Dictionary and (marks as Dictionary).get("run") is Callable and _edited != null:
		((marks as Dictionary).get("run") as Callable).call(_edited, action, index)


## A mark pressed: plays that card alone, or stops it while it is sounding.
func _on_mark_pressed(index: int) -> void:
	_run_mark("stop" if _lit.has(index) else "play_one", index)


## Lights the marks of the cards that are sounding. Done in place: the cards are not rebuilt, so a
## number being typed in an open card is not lost to a frame of the preview.
func set_marks(lit: PackedInt32Array) -> void:
	_lit = lit
	for index: Variant in _marks:
		_paint_mark(int(index))


## One mark in its resting or sounding look: the editor's Play icon, or its Stop icon while it sounds.
func _paint_mark(index: int) -> void:
	var mark: Button = _marks.get(index) as Button
	if mark == null or not is_instance_valid(mark):
		return
	var sounding: bool = _lit.has(index)
	var picture: Texture2D = EventSheetLookStyle.icon(&"Stop" if sounding else &"Play")
	if picture != null:
		mark.icon = picture
	else:
		mark.text = "■" if sounding else "▶"
	mark.tooltip_text = EventSheetL10n.translate("Stop.") if sounding else EventSheetL10n.translate("Play this card alone.")


## Tells the drawer which object it is editing, and builds the footer the schema declares for it
## (the strip of buttons that play a Juice Player's list sits there, under the cards it plays).
func set_edited_object(object: Object) -> void:
	_edited = object
	var maker: Variant = _schema.get("footer")
	if _footer != null or object == null or not (maker is Callable) or not (maker as Callable).is_valid():
		return
	var built: Variant = (maker as Callable).call(object, self)
	if built is Control:
		_footer = built as Control
		_body.add_child(_footer)


func edited_object() -> Object:
	return _edited


## The footer the schema built, or null. The owner refreshes it when the list changes underneath it.
func footer() -> Control:
	return _footer


# ── Selecting cards ─────────────────────────────────────────────────────────────────────────────
# A selection is a view. Click selects one card, Shift+click the run from the last click, Ctrl+click
# adds or takes one out; the list holds the keyboard from then on so the keys below act on it.


## Selects by a gesture: "click" (this card alone), "shift" (the run from the anchor to this card) or
## "ctrl" (this card added or taken out). Nothing is written to the list and nothing is announced.
func select_card(index: int, mode: String = "click") -> void:
	if index < 0 or index >= _cards.size():
		return
	match mode:
		"shift":
			if _anchor < 0 or _anchor >= _cards.size():
				_anchor = index
			_selected.clear()
			for walked: int in range(mini(_anchor, index), maxi(_anchor, index) + 1):
				_selected[walked] = true
		"ctrl":
			if _selected.has(index):
				_selected.erase(index)
			else:
				_selected[index] = true
			_anchor = index
		_:
			_selected.clear()
			_selected[index] = true
			_anchor = index
	_paint_selection()
	if is_inside_tree() and not has_focus():
		grab_focus()


## The selected cards' positions, in list order.
func selected_cards() -> Array:
	var chosen: Array = _selected.keys()
	chosen.sort()
	return chosen


func clear_selection() -> void:
	_selected.clear()
	_anchor = -1
	_paint_selection()


## The keys a list that holds the keyboard answers to, as Godot's own lists do: Ctrl+C copies the selected
## cards, Ctrl+X cuts them, Ctrl+V pastes under the last selected card (or at the end), Ctrl+D duplicates
## them in place and Delete removes them. Returns whether the key was taken. A key with nothing to act on
## (no selection, or a clipboard that holds no cards) is NOT taken, so the editor's own answer still runs.
func handle_key(event: InputEvent) -> bool:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo or not editable or key.alt_pressed:
		return false
	var command: bool = key.is_command_or_control_pressed() and not key.shift_pressed
	if command:
		match key.keycode:
			KEY_C:
				return not _selected.is_empty() and not copy_selected().is_empty()
			KEY_X:
				return not cut_selected().is_empty()
			KEY_V:
				return paste_after_selection(_clipboard_text())
			KEY_D:
				return duplicate_selected()
	elif (key.keycode == KEY_DELETE or key.keycode == KEY_BACKSPACE) and not key.shift_pressed:
		return remove_selected()
	return false


func _gui_input(event: InputEvent) -> void:
	if handle_key(event):
		accept_event()


## The clipboard's text, or "" where the display server has none (a headless run).
func _clipboard_text() -> String:
	return DisplayServer.clipboard_get() if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD) else ""


func _set_clipboard(text: String) -> void:
	if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		DisplayServer.clipboard_set(text)


## The selected cards as clipboard text, and on the clipboard. "" when nothing is selected.
func copy_selected() -> String:
	var chosen: Array = []
	for index: Variant in selected_cards():
		chosen.append(_cards[int(index)])
	if chosen.is_empty():
		return ""
	var text: String = EventSheetCardSchemas.cards_to_text(chosen)
	_set_clipboard(text)
	return text


## Copy, then remove: what Ctrl+X does. "" (and nothing removed) when nothing is selected.
func cut_selected() -> String:
	var text: String = copy_selected()
	if not text.is_empty():
		remove_selected()
	return text


## Removes every selected card, as one change. False when nothing is selected or the list is read-only.
func remove_selected() -> bool:
	if _selected.is_empty() or not editable:
		return false
	var order: Array = []
	for index: int in range(_cards.size()):
		if not _selected.has(index):
			order.append(index)
	var kept: Array = []
	for old_index: Variant in order:
		kept.append(_cards[int(old_index)])
	_cards = kept
	_refold(order)
	_selected.clear()
	_anchor = -1
	_commit()
	return true


## Copies each selected card directly under itself, selects the copies and announces one change.
func duplicate_selected() -> bool:
	if _selected.is_empty() or not editable:
		return false
	var order: Array = []
	var copies: Array = []
	var grown: Array = []
	for index: int in range(_cards.size()):
		order.append(index)
		grown.append(_cards[index])
		if _selected.has(index):
			# The copy is a card that did not exist a moment ago, so it starts shut and unselected until
			# the selection is handed to it below.
			order.append(-1)
			grown.append((_cards[index] as Dictionary).duplicate(true))
			copies.append(grown.size() - 1)
	_cards = grown
	_refold(order)
	_selected.clear()
	for copy_index: Variant in copies:
		_selected[int(copy_index)] = true
	_anchor = int(copies[0])
	_commit()
	return true


## Adds the clipboard's cards under the last selected card, or at the end when none is selected, and
## selects them. One change, however many cards: one Ctrl+Z takes them all back. False when the text
## holds no cards or the list is read-only. Nothing is replaced - that is what "Paste over" and
## "Paste all" are for.
func paste_after_selection(text: String) -> bool:
	var pasted: Array = EventSheetCardSchemas.cards_from_text(text)
	if pasted.is_empty() or not editable:
		return false
	var chosen: Array = selected_cards()
	var at: int = (int(chosen[chosen.size() - 1]) + 1) if not chosen.is_empty() else _cards.size()
	var order: Array = []
	for index: int in range(_cards.size()):
		if index == at:
			for _card: Variant in pasted:
				order.append(-1)
		order.append(index)
	if at >= _cards.size():
		for _card: Variant in pasted:
			order.append(-1)
	var grown: Array = _cards.slice(0, at)
	grown.append_array(pasted)
	grown.append_array(_cards.slice(at))
	_cards = grown
	_refold(order)
	_selected.clear()
	for offset: int in range(pasted.size()):
		_selected[at + offset] = true
	_anchor = at
	_commit()
	return true


## Paints every card's line in place: the selected ones in the fill Godot's lists select with.
func _paint_selection() -> void:
	for index: Variant in _lines:
		_paint_line(int(index))


## One card's line, selected or not. The selected fill is stronger while the list holds the keyboard.
func _paint_line(index: int) -> void:
	var line: PanelContainer = _lines.get(index) as PanelContainer
	if line == null or not is_instance_valid(line) or index >= _cards.size():
		return
	var chosen: bool = _selected.has(index)
	var open: bool = bool(_unfolded.get(index, false))
	line.add_theme_stylebox_override("panel", EventSheetLookStyle.selected_row_box(has_focus()) if chosen else EventSheetLookStyle.card_box(open))
	var title: Label = _titles.get(index) as Label
	if title != null and is_instance_valid(title):
		var enabled: bool = EventSheetCardSchemas.card_enabled(_schema, _cards[index])
		title.add_theme_color_override("font_color", EventSheetLookStyle.selected_row_ink() if chosen else (EventSheetLookStyle.ink() if enabled else EventSheetLookStyle.quiet()))


func set_editable(flag: bool) -> void:
	editable = flag
	_rebuild()


## The card titles in list order - what a preview harness and the suite read the list back as.
func card_labels() -> PackedStringArray:
	var labels: PackedStringArray = PackedStringArray()
	for card: Variant in _cards:
		var entry: Dictionary = _entry_for(card as Dictionary)
		labels.append(EventSheetCardSchemas.card_label(_schema, _spec, entry, card as Dictionary))
	return labels


## Add a card of the schema's FIRST kind - the one-click add, for the common case where a list only
## ever holds one thing and searching for it is a gesture too many.
func add_first_kind() -> void:
	var kinds: Array = EventSheetCardSchemas.kinds_of(_schema)
	if kinds.is_empty():
		return
	add_card(str((kinds[0] as Dictionary).get("kind", "")))


## Add a card of one kind at the end, folded.
func add_card(kind: String) -> void:
	var entry: Dictionary = EventSheetCardSchemas.kind_entry(_schema, kind)
	if entry.is_empty():
		return
	_cards.append(EventSheetCardSchemas.new_card(_spec, entry))
	# A schema may open the card it just added, with its first field ready, so the next thing a person does is
	# fill it in rather than hunt for it at the foot of the list.
	var opens_new: bool = bool(_schema.get("open_new", false))
	if opens_new:
		_unfolded[_cards.size() - 1] = true
	_commit()
	if opens_new:
		_ready_card.call_deferred(_cards.size() - 1)


## Gives a card's first field the keyboard and scrolls the card into view, once it is on screen.
func _ready_card(index: int) -> void:
	var surface: Control = _lines.get(index) as Control
	if surface == null or not is_instance_valid(surface) or not is_inside_tree():
		return
	var first: Control = _first_focusable(surface)
	if first != null:
		first.grab_focus()
	var scroller: Node = get_parent()
	while scroller != null and not (scroller is ScrollContainer):
		scroller = scroller.get_parent()
	if scroller != null:
		(scroller as ScrollContainer).ensure_control_visible(surface)


func _first_focusable(node: Node) -> Control:
	for child: Node in node.get_children():
		var found: Control = child as Control
		if found != null and found.visible and found.focus_mode == Control.FOCUS_ALL and not (found is BaseButton and (found as BaseButton).flat):
			return found
		var deeper: Control = _first_focusable(child)
		if deeper != null:
			return deeper
	return null


## Move the card at `from` to `to` - what a finished drag, and "Move to top", write. The open cards
## travel with their cards: the list is reordered and the fold map is read against the new order.
func move_card(from: int, to: int) -> void:
	var order: Array = _index_order()
	if from >= 0 and from < order.size() and to >= 0 and to < order.size() and from != to:
		var travelling: Variant = order[from]
		order.remove_at(from)
		order.insert(to, travelling)
	_cards = EventSheetCardSchemas.move_card(_cards, from, to)
	_refold(order)
	_commit()


func duplicate_card(index: int) -> void:
	var order: Array = _index_order()
	if index >= 0 and index < order.size():
		# The copy is a card that did not exist a moment ago, so it starts shut.
		order.insert(index + 1, -1)
	_cards = EventSheetCardSchemas.duplicate_card(_cards, index)
	_refold(order)
	_commit()


func remove_card(index: int) -> void:
	var order: Array = _index_order()
	if index >= 0 and index < order.size():
		order.remove_at(index)
	_cards = EventSheetCardSchemas.remove_card(_cards, index)
	_refold(order)
	_commit()


## The cards' current positions, as the starting point every reorder rewrites.
func _index_order() -> Array:
	var order: Array = []
	for index: int in range(_cards.size()):
		order.append(index)
	return order


## The fold map read against a new order (new index -> old index, -1 for a card that is new).
func _refold(order: Array) -> void:
	_unfolded = EventSheetCardSchemas.remapped_folds(_unfolded, order)
	# The selection travels with its cards the same way, and so does the card a run is measured from.
	_selected = EventSheetCardSchemas.remapped_folds(_selected, order)
	var anchor_now: int = order.find(_anchor)
	_anchor = anchor_now if _anchor >= 0 and anchor_now >= 0 and _selected.has(anchor_now) else -1


## Switch one card on or off. Absent means on, so switching a card back on leaves the file exactly
## as it was before it was ever switched off.
func set_card_enabled(index: int, enabled: bool) -> void:
	if index < 0 or index >= _cards.size():
		return
	_cards[index] = EventSheetCardSchemas.set_card_enabled(_schema, _cards[index], enabled)
	_commit()


## Rename one card. Only a schema that declares a `label_key` has a name to write; without one a
## card is titled by its kind, and typing a name would invent a key the file never had.
func set_card_label(index: int, text: String) -> void:
	var label_key: String = str(_schema.get("label_key", ""))
	if label_key.is_empty() or index < 0 or index >= _cards.size():
		return
	_cards[index][label_key] = text
	value_changed.emit(get_value())


## Give one card its own stripe colour, written at the stripe key as the "#rrggbb" a plain-data list
## holds. REFUSED when the stripe key is the key that holds the kind (which is how the Drawing
## Prefab colours its shapes): a colour written there would overwrite what the card IS.
func set_card_stripe(index: int, color: Color) -> void:
	var stripe_key: String = str(_spec.get("stripe_key", "category"))
	if stripe_key.is_empty() or stripe_key == str(_spec.get("kind_key", "kind")) or index < 0 or index >= _cards.size():
		return
	_cards[index][stripe_key] = "#" + color.to_html(false)
	# NOT _commit(): the picker fires this continuously while its wheel is being dragged, and a
	# rebuild would free the popup out from under the cursor. The stripe is restyled where it stands
	# instead, exactly as renaming a card does.
	_restyle_card(index)
	value_changed.emit(get_value())


## Repaint one card's stripe in place, without rebuilding the row it belongs to.
func _restyle_card(_index: int) -> void:
	# The stripe colour is kept in the data and not drawn, so there is nothing to repaint.
	pass


## Whether a card may carry a colour of its own - the swatch beside its name is drawn only then.
func stripe_editable() -> bool:
	var stripe_key: String = str(_spec.get("stripe_key", "category"))
	return not stripe_key.is_empty() and stripe_key != str(_spec.get("kind_key", "kind"))


## Replace the card at `index` with the clipboard's first card ("Paste over" on the card's menu).
func paste_over(index: int, text: String) -> void:
	var pasted: Array = EventSheetCardSchemas.cards_from_text(text)
	if pasted.is_empty() or index < 0 or index >= _cards.size():
		return
	_cards[index] = pasted[0]
	_commit()


func _commit() -> void:
	_rebuild()
	value_changed.emit(get_value())


func _entry_for(card: Dictionary) -> Dictionary:
	# A card that names the script it is made of is found by that script, before its word.
	var by_script: Variant = _schema.get("card_entry")
	if by_script is Callable and card.has("card_script"):
		var found: Dictionary = (by_script as Callable).call(card)
		if not found.is_empty():
			return found
	var entry: Dictionary = EventSheetCardSchemas.kind_entry(_schema, str(card.get(str(_spec.get("kind_key", "kind")), "")))
	# A card whose kind the schema does not know is still shown, as the card the schema makes of it, so it
	# can say so and be repaired rather than sitting there with no fields.
	var fallback: Variant = _schema.get("fallback_entry")
	if entry.is_empty() and fallback is Callable and (fallback as Callable).is_valid():
		var made: Variant = (fallback as Callable).call(card)
		if made is Dictionary:
			return made
	return entry


# ── The chrome around the list: the head line, the list itself, the Add dropdown ────────────────


func _build_chrome() -> void:
	# The head: one fold button saying how many cards the list holds, and one menu for the things
	# that act on the whole list. The cards and the Add button sit under them while it is open.
	var head: HBoxContainer = HBoxContainer.new()
	_fold_button = Button.new()
	_fold_button.toggle_mode = true
	_fold_button.button_pressed = true
	_fold_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_fold_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fold_button.toggled.connect(_on_fold_toggled)
	head.add_child(_fold_button)
	_more_button = MenuButton.new()
	var dots: Texture2D = _editor_icon("GuiTabMenuHl")
	if dots != null:
		_more_button.icon = dots
	else:
		_more_button.text = "⋯"
	_more_button.tooltip_text = EventSheetL10n.translate("More for this list.")
	var more_popup: PopupMenu = _more_button.get_popup()
	more_popup.add_item(EventSheetL10n.translate("Copy all"), 0)
	more_popup.set_item_tooltip(0, EventSheetL10n.translate("Copy every card to the clipboard."))
	more_popup.add_item(EventSheetL10n.translate("Paste all"), 1)
	more_popup.set_item_tooltip(1, EventSheetL10n.translate("Replace the list with the cards on the clipboard."))
	more_popup.id_pressed.connect(func(id: int) -> void:
		if id == 0:
			_on_copy_all()
		else:
			_on_paste_all())
	head.add_child(_more_button)
	add_child(head)
	_body = VBoxContainer.new()
	add_child(_body)
	_list = VBoxContainer.new()
	_body.add_child(_list)
	_add_button = Button.new()
	_add_button.text = str(_schema.get("add_word", "")) if not str(_schema.get("add_word", "")).is_empty() else EventSheetL10n.translate("Add card")
	var add_picture: Texture2D = _editor_icon("Add")
	if add_picture != null:
		_add_button.icon = add_picture
	else:
		_add_button.text = "+ " + _add_button.text
	_add_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_add_button.pressed.connect(_on_add_clicked)
	_body.add_child(_add_button)


## The fold button reads "Cards (N)" and carries the arrow that says whether the cards are showing.
func _show_fold() -> void:
	_fold_button.text = EventSheetL10n.translate("Cards (%d)") % _cards.size()
	var arrow: Texture2D = _editor_icon("GuiTreeArrowDown" if _fold_button.button_pressed else "GuiTreeArrowRight")
	_fold_button.icon = arrow


func _on_fold_toggled(open: bool) -> void:
	_body.visible = open
	_show_fold()


## A list that can only hold one kind of card adds it at once; a list of several kinds asks which.
func _on_add_clicked() -> void:
	if EventSheetCardSchemas.kinds_of(_schema).size() == 1:
		add_first_kind()
	else:
		_on_add_pressed()


## The title of the schema's first kind - what the one-click add says it will add.
func _first_kind_label() -> String:
	var kinds: Array = EventSheetCardSchemas.kinds_of(_schema)
	if kinds.is_empty():
		return "card"
	var entry: Dictionary = kinds[0] as Dictionary
	return str(entry.get("label", entry.get("kind", "card")))


func _small_button(text: String, tooltip: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.tooltip_text = tooltip
	button.add_theme_font_size_override("font_size", EventSheetPalette.scaled(10))
	button.pressed.connect(action)
	return button


func _on_copy_all() -> void:
	_set_clipboard(EventSheetCardSchemas.cards_to_text(_cards))


func _on_paste_all() -> void:
	var pasted: Array = EventSheetCardSchemas.cards_from_text(_clipboard_text())
	if pasted.is_empty():
		return
	_cards = pasted
	_junk = []
	_unfolded.clear()
	clear_selection()
	_commit()


## The Add dropdown: a field you type into over a tree grouped by category - the engine's own "search
## a long list" shape, so there is nothing new to learn.
func _on_add_pressed() -> void:
	prepare_add_box()
	_size_add_box()
	var below: Vector2i = Vector2i(_add_button.get_screen_position()) + Vector2i(0, int(_add_button.size.y))
	EventSheetWindowPlacement.popup_below(_add_popup, Rect2i(Vector2i(_add_button.get_screen_position()), Vector2i(_add_button.size)))
	_add_filter.grab_focus()


## Builds the Add box the first time it is wanted and fills it fresh, without showing it. The box is a field
## to type into over a tree; a schema that asks for a flat list (`flat_add`) gets one line per kind with
## the kind's own picture, and the up and down keys walk it from the field.
func prepare_add_box() -> void:
	if _add_popup == null:
		_add_popup = PopupPanel.new()
		var box: VBoxContainer = VBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		_add_filter = LineEdit.new()
		_add_filter.placeholder_text = EventSheetL10n.translate("Search")
		_add_filter.clear_button_enabled = true
		_add_filter.custom_minimum_size = Vector2(EventSheetPalette.scaled(220), 0.0)
		_add_filter.text_changed.connect(func(_text: String) -> void: _fill_add_tree())
		_add_filter.text_submitted.connect(func(_text: String) -> void: add_highlighted_or_first())
		_add_filter.gui_input.connect(_on_add_filter_key)
		box.add_child(_add_filter)
		_add_tree = Tree.new()
		_add_tree.hide_root = true
		_add_tree.custom_minimum_size = Vector2(EventSheetPalette.scaled(220), EventSheetPalette.scaled(220))
		_add_tree.item_activated.connect(_on_add_chosen)
		box.add_child(_add_tree)
		var hint_words: String = str(_schema.get("add_hint", ""))
		if not hint_words.is_empty():
			var hint: Label = Label.new()
			hint.text = hint_words
			hint.add_theme_font_size_override("font_size", EventSheetPalette.scaled(10))
			hint.add_theme_color_override("font_color", EventSheetLookStyle.quiet())
			box.add_child(hint)
		_add_popup.add_child(box)
		add_child(_add_popup)
	_add_filter.text = ""
	_fill_add_tree()


## The up and down keys in the Add box's field move the highlighted line, as the type-to-search boxes in
## Godot do, so a shape can be chosen without the mouse. Only a flat list is walked this way.
func _on_add_filter_key(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or not bool(_schema.get("flat_add", false)):
		return
	if key.keycode != KEY_DOWN and key.keycode != KEY_UP:
		return
	var current: TreeItem = _add_tree.get_selected()
	var step_to: TreeItem = null
	if current == null:
		step_to = _add_tree.get_root().get_first_child() if _add_tree.get_root() != null else null
	else:
		step_to = current.get_next() if key.keycode == KEY_DOWN else current.get_prev()
	if step_to != null:
		step_to.select(0)
		_add_tree.scroll_to_item(step_to)
	_add_filter.accept_event()


## The pieces a test reads: the tree, the field, the button's words.
func add_box_tree() -> Tree:
	return _add_tree


func add_box_filter() -> LineEdit:
	return _add_filter


func refill_add_box() -> void:
	_fill_add_tree()


func add_button_text() -> String:
	return _add_button.text


## The Add box is as wide as the Add card button above it, and as tall as a whole number of lines, so
## the last line it shows is never cut in half.
func _size_add_box() -> void:
	var wide: float = maxf(_add_button.size.x, EventSheetPalette.scaled(220))
	var line: float = EventSheetPalette.scaled(22)
	var first: TreeItem = _add_tree.get_root().get_first_child() if _add_tree.get_root() != null else null
	if first != null:
		line = maxf(_add_tree.get_item_area_rect(first).size.y, 1.0)
	_add_filter.custom_minimum_size = Vector2(wide, 0.0)
	# The tree starts its first line a little below its own top edge; the box ends where its last whole
	# line does, so no part of a next line shows under it.
	var top: float = _add_tree.get_item_area_rect(first).position.y if first != null else 0.0
	var lines: int = EventSheetCardSchemas.kinds_of(_schema).size() if bool(_schema.get("flat_add", false)) else ADD_BOX_LINES
	var pad: float = EventSheetPalette.scaled(8) if bool(_schema.get("flat_add", false)) else 0.0
	_add_tree.custom_minimum_size = Vector2(wide, top + line * float(mini(lines, ADD_BOX_LINES)) + pad)


func _fill_add_tree() -> void:
	_add_tree.clear()
	var root: TreeItem = _add_tree.create_item()
	var needle: String = _add_filter.text.strip_edges().to_lower()
	if bool(_schema.get("flat_add", false)):
		_fill_flat_add(root, needle)
		return
	for group: Variant in EventSheetCardSchemas.kinds_by_category(_schema):
		var group_dict: Dictionary = group as Dictionary
		var matching: Array = []
		for entry: Variant in group_dict.get("kinds", []):
			if EventSheetCardSchemas.kind_matches(entry as Dictionary, needle):
				matching.append(entry)
		if matching.is_empty():
			continue
		var category: String = str(group_dict.get("category", ""))
		var parent: TreeItem = _add_tree.create_item(root)
		parent.set_text(0, _said(str(group_dict.get("name", category.capitalize() if not category.is_empty() else "Other"))))
		parent.set_selectable(0, false)
		if EventSheetCardSchemas.tiles_wanted(_schema):
			# A heading wears the family's tile, the same square the cards of that family wear.
			parent.set_icon(0, _tile_texture(category))
		else:
			parent.set_custom_color(0, EventSheetCardSchemas.stripe_color(_schema, category))
		for entry: Variant in matching:
			var leaf: TreeItem = _add_tree.create_item(parent)
			leaf.set_text(0, _said(str((entry as Dictionary).get("label", (entry as Dictionary).get("kind", "")))))
			leaf.set_tooltip_text(0, _said(str((entry as Dictionary).get("help", ""))))
			leaf.set_metadata(0, str((entry as Dictionary).get("kind", "")))


## The flat form of the Add box: every kind that answers to what was typed, one line each, wearing the
## picture the schema draws for it (`kind_icon`). The first line is highlighted so Enter has something to add.
func _fill_flat_add(root: TreeItem, needle: String) -> void:
	var picture: Variant = _schema.get("kind_icon")
	var first: TreeItem = null
	for entry: Variant in EventSheetCardSchemas.kinds_of(_schema):
		if not (entry is Dictionary) or not EventSheetCardSchemas.kind_matches(entry as Dictionary, needle):
			continue
		var leaf: TreeItem = _add_tree.create_item(root)
		leaf.set_text(0, _said(str((entry as Dictionary).get("label", (entry as Dictionary).get("kind", "")))))
		leaf.set_tooltip_text(0, _said(str((entry as Dictionary).get("help", ""))))
		leaf.set_metadata(0, str((entry as Dictionary).get("kind", "")))
		if picture is Callable and (picture as Callable).is_valid():
			leaf.set_icon(0, (picture as Callable).call(str((entry as Dictionary).get("kind", "")), _on_light_ground()) as Texture2D)
		if first == null:
			first = leaf
	if first != null:
		first.select(0)


## Enter in the Add box: the highlighted line of a flat list, else the first card the search found.
func add_highlighted_or_first() -> void:
	if bool(_schema.get("flat_add", false)):
		var chosen: TreeItem = _add_tree.get_selected()
		if chosen == null and _add_tree.get_root() != null:
			chosen = _add_tree.get_root().get_first_child()
		if chosen != null and chosen.get_metadata(0) != null:
			_add_popup.hide()
			add_card(str(chosen.get_metadata(0)))
		return
	_add_first_match()


## Enter in the search box adds the first card the search found.
func _add_first_match() -> void:
	var group: TreeItem = _add_tree.get_root().get_first_child() if _add_tree.get_root() != null else null
	while group != null:
		var leaf: TreeItem = group.get_first_child()
		if leaf != null and leaf.get_metadata(0) != null:
			_add_popup.hide()
			add_card(str(leaf.get_metadata(0)))
			return
		group = group.get_next()


func _on_add_chosen() -> void:
	var chosen: TreeItem = _add_tree.get_selected()
	if chosen == null or chosen.get_metadata(0) == null:
		return
	_add_popup.hide()
	add_card(str(chosen.get_metadata(0)))


# ── The list ────────────────────────────────────────────────────────────────────────────────────


func _rebuild() -> void:
	if _list == null:
		return
	for stale: Node in _list.get_children():
		_list.remove_child(stale)
		stale.queue_free()
	_notes.clear()
	_marks.clear()
	_timing_marks.clear()
	_lines.clear()
	_titles.clear()
	_head_tiles.clear()
	_badges.clear()
	_show_fold()
	var nothing_to_add: bool = not editable or EventSheetCardSchemas.kinds_of(_schema).is_empty()
	_add_button.disabled = nothing_to_add
	_add_button.tooltip_text = "" if EventSheetCardSchemas.kinds_of(_schema).size() <= 1 else EventSheetL10n.translate("Add a card. Type to search; the list is grouped the way its pack groups it.")
	if _cards.is_empty():
		var empty: Label = Label.new()
		empty.text = EventSheetL10n.translate("Nothing here yet. Add one.")
		empty.add_theme_color_override("font_color", EventSheetLookStyle.quiet())
		_list.add_child(empty)
		return
	var groups: Array = EventSheetCardSchemas.together_groups(_schema, _cards)
	var captions: Array = _order_captions()
	if not captions.is_empty():
		_list.add_child(_order_caption(str(captions[0])))
	var index: int = 0
	while index < _cards.size():
		var group: int = int(groups[index]) if index < groups.size() else -1
		var last: int = index
		while group >= 0 and last + 1 < _cards.size() and last + 1 < groups.size() and int(groups[last + 1]) == group:
			last += 1
		if last > index:
			_list.add_child(_band_of(index, last))
		else:
			_list.add_child(_build_card(index))
		index = last + 1
	if not captions.is_empty():
		_list.add_child(_order_caption(str(captions[1])))


## The two words a schema puts at the ends of its list - what the first card is, and what the last is - or
## nothing for a list whose order says nothing. Said only while there are cards to say it about.
func _order_captions() -> Array:
	var words: Variant = _schema.get("order_captions")
	if words is Array and (words as Array).size() == 2 and not _cards.is_empty():
		return words
	return []


func _order_caption(text: String) -> Label:
	var caption: Label = Label.new()
	caption.text = text
	caption.set_meta("order_caption", true)
	caption.add_theme_font_size_override("font_size", EventSheetPalette.scaled(10))
	caption.add_theme_color_override("font_color", EventSheetLookStyle.quiet())
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return caption


## The caption words showing at the ends of the list right now, in order: what a test reads back.
func order_caption_texts() -> PackedStringArray:
	var texts: PackedStringArray = PackedStringArray()
	if _list == null:
		return texts
	for child: Node in _list.get_children():
		if child is Label and child.has_meta("order_caption") and not child.is_queued_for_deletion():
			texts.append((child as Label).text)
	return texts


## Cards that start together on one faint band: a fill behind them and nothing drawn round them, so the groups
## read without unfolding anything.
func _band_of(first: int, last: int) -> Control:
	var band: PanelContainer = PanelContainer.new()
	band.set_meta("band", true)
	band.mouse_filter = Control.MOUSE_FILTER_PASS
	band.add_theme_stylebox_override("panel", EventSheetLookStyle.band_box())
	var stack: VBoxContainer = VBoxContainer.new()
	band.add_child(stack)
	# A small quiet caption says what the band is: cards that start together, or the ones that follow a Hold.
	var caption: Label = Label.new()
	var after_hold: bool = first > 0 and str((_cards[first - 1] as Dictionary).get(str(_spec.get("kind_key", "kind")), "")) == "hold_until"
	caption.text = EventSheetL10n.translate("After the hold") if after_hold else EventSheetL10n.translate("Start together")
	caption.add_theme_font_size_override("font_size", EventSheetPalette.scaled(10))
	caption.add_theme_color_override("font_color", EventSheetLookStyle.quiet())
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.add_theme_constant_override("line_spacing", 0)
	var inset: MarginContainer = MarginContainer.new()
	inset.add_theme_constant_override("margin_left", int(EventSheetLookStyle.px(8.0)))
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inset.add_child(caption)
	stack.add_child(inset)
	for index: int in range(first, last + 1):
		stack.add_child(_build_card(index))
	return band


func _build_card(index: int) -> Control:
	var card: Dictionary = _cards[index]
	var entry: Dictionary = _entry_for(card)
	var enabled: bool = EventSheetCardSchemas.card_enabled(_schema, card)
	var panel: _CardRow = _CardRow.new(self, index)
	# ONE surface holds the head line and, when the card is open, its fields: the same ground, one hairline
	# round the whole card, no gap between the head and what it opens onto.
	var surface: PanelContainer = PanelContainer.new()
	# A panel keeps a click unless it is told to pass it on; the card behind it is what a right click (its
	# menu), a click (its selection) and a drag (its place in the list) are meant for.
	surface.mouse_filter = Control.MOUSE_FILTER_PASS
	surface.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lines[index] = surface
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", int(EventSheetLookStyle.px(4.0)))
	surface.add_child(stack)
	panel.add_child(surface)
	stack.add_child(_build_header(index, card, entry, enabled))
	if bool(_unfolded.get(index, false)):
		stack.add_child(_build_body(index, card, entry))
	_paint_line(index)
	return panel


## One card's line: a grip, then a field-coloured line holding the fold arrow, the kind in bold and the
## one grey sentence the schema computes for it, then a remove button. A right click on the line opens
## the card's menu (Duplicate, Copy, Paste over, Move ...); the same menu is inside the opened card.
func _build_header(index: int, card: Dictionary, entry: Dictionary, enabled: bool) -> Control:
	var header: HBoxContainer = HBoxContainer.new()
	header.add_child(_glyph_control("TripleBar", "⋮⋮", EventSheetL10n.translate("Drag to reorder.")))
	var inside: HBoxContainer = header
	var open: bool = bool(_unfolded.get(index, false))
	var fold: Button = Button.new()
	fold.flat = true
	var arrow: Texture2D = _editor_icon("GuiTreeArrowDown" if open else "GuiTreeArrowRight")
	if arrow != null:
		fold.icon = arrow
	else:
		fold.text = "▾" if open else "▸"
	fold.tooltip_text = EventSheetL10n.translate("Open this card.")
	fold.pressed.connect(func() -> void:
		_unfolded[index] = not bool(_unfolded.get(index, false))
		_rebuild())
	inside.add_child(fold)
	if not EventSheetCardSchemas.enabled_key(_schema).is_empty():
		var box: CheckBox = CheckBox.new()
		box.button_pressed = enabled
		box.disabled = not editable
		box.tooltip_text = EventSheetL10n.translate("Untick to skip this card.")
		box.toggled.connect(func(pressed: bool) -> void: set_card_enabled(index, pressed))
		inside.add_child(box)
	var head_tile: Variant = _schema.get("head_tile")
	if head_tile is Callable and (head_tile as Callable).is_valid():
		# A schema may draw its own tile: a picture of what the card is, in the card's own colour.
		var drawn: Variant = (head_tile as Callable).call(card, _on_light_ground())
		if drawn is Control:
			_head_tiles[index] = drawn
			inside.add_child(drawn as Control)
	elif EventSheetCardSchemas.tiles_wanted(_schema):
		inside.add_child(_family_tile(EventSheetCardSchemas.card_category(_spec, entry, card)))
	var title: Label = Label.new()
	title.text = EventSheetCardSchemas.card_label(_schema, _spec, entry, card)
	if title.text == str(entry.get("label", "")):
		title.text = _said(title.text)
	title.add_theme_font_override("font", EventSheetLookStyle.bold_font())
	title.add_theme_color_override("font_color", EventSheetLookStyle.ink() if enabled else EventSheetLookStyle.quiet())
	_titles[index] = title
	inside.add_child(title)
	var differs: Variant = _schema.get("timing_differs")
	if differs is Callable and (differs as Callable).is_valid():
		var clock: Control = _glyph_control("Time", "◷", EventSheetL10n.translate("This card's timing is not the default: it waits, repeats, counts real time, or is not always felt."))
		clock.visible = bool((differs as Callable).call(card))
		_timing_marks[index] = clock
		inside.add_child(clock)
	var badge_text: String = EventSheetCardSchemas.card_badge(entry, card, _cards, index)
	var badge: Label = Label.new()
	badge.text = badge_text
	badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# A short badge never wraps: it asks for exactly the room its words take.
	badge.autowrap_mode = TextServer.AUTOWRAP_OFF if badge_text.length() <= 12 else TextServer.AUTOWRAP_WORD_SMART
	# A wrapping label squeezed by a long title would break "0.30 s" one letter to a line. A short badge
	# keeps room for all of its words; a long one keeps room for its longest word and wraps between them.
	badge.custom_minimum_size.x = _badge_room(badge, badge_text)
	badge.add_theme_color_override("font_color", EventSheetLookStyle.quiet())
	badge.visible = not badge_text.is_empty()
	_badges[index] = badge
	inside.add_child(badge)
	if open:
		# The card's menu sits in the head line, before the play mark, so no control stands alone between
		# the head and the fields.
		inside.add_child(_build_menu(index))
	if _marks_wanted():
		var mark: Button = EventSheetLookStyle.icon_button(&"Play", "▶", EventSheetL10n.translate("Play this card alone."))
		mark.pressed.connect(func() -> void: _on_mark_pressed(index))
		_marks[index] = mark
		_paint_mark(index)
		inside.add_child(mark)
	var remove: Button = EventSheetLookStyle.icon_button(&"Remove", "✕", EventSheetL10n.translate("Remove this card."))
	remove.disabled = not editable
	remove.pressed.connect(func() -> void: remove_card(index))
	inside.add_child(remove)
	return header


## The width a badge asks for: all of its text when that is short, else its longest word.
func _badge_room(badge: Label, text: String) -> float:
	# The editor's own font, which is what the Inspector draws the badge in once it is on screen.
	var font: Font = EventSheetLookStyle.font()
	var size: int = EventSheetLookStyle.font_size()
	if font == null or text.is_empty():
		return 0.0
	if text.length() <= 12:
		return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 6.0
	var widest: float = 0.0
	for word: String in text.split(" ", false):
		widest = maxf(widest, font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
	return widest + 6.0


## Whether the card line is a light ground, which decides which of a family's two colours a tile wears.
func _on_light_ground() -> bool:
	return EventSheetLookStyle.field_fill().get_luminance() > 0.5


## The small square in a family's colour on a card head: what kind of thing the card is, at a glance, the
## way a variable row shows its type. It is drawn from the family and never stored on the card.
func _family_tile(category: String) -> Control:
	var tile: Panel = Panel.new()
	var side: float = EventSheetLookStyle.px(11.0)
	tile.custom_minimum_size = Vector2(side, side)
	tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tile.mouse_filter = Control.MOUSE_FILTER_PASS
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = EventSheetCardSchemas.tile_color(_schema, category, _on_light_ground())
	box.set_corner_radius_all(int(EventSheetLookStyle.px(3.0)))
	tile.add_theme_stylebox_override("panel", box)
	tile.tooltip_text = EventSheetCardSchemas.group_name(_schema, category)
	return tile


## The same square as a picture, for the headings of the Add box.
func _tile_texture(category: String) -> Texture2D:
	var side: int = int(EventSheetLookStyle.px(11.0))
	var picture: Image = Image.create(side, side, false, Image.FORMAT_RGBA8)
	picture.fill(EventSheetCardSchemas.tile_color(_schema, category, _on_light_ground()))
	return ImageTexture.create_from_image(picture)


## One of the editor's own icons, or null when there is no editor theme to ask (a headless tool run,
## a preview harness). Asking first is what keeps the row familiar where an editor exists and legible
## where one does not: every caller carries the plain glyph it falls back to.
func _editor_icon(icon_name: String) -> Texture2D:
	if icon_name.is_empty() or not has_theme_icon(icon_name, "EditorIcons"):
		return null
	return get_theme_icon(icon_name, "EditorIcons")


## A small, non-interactive mark: the editor's icon where there is one, the glyph otherwise.
func _glyph_control(icon_name: String, glyph: String, tooltip: String) -> Control:
	var icon: Texture2D = _editor_icon(icon_name)
	if icon != null:
		var mark: TextureRect = TextureRect.new()
		mark.texture = icon
		mark.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		mark.tooltip_text = tooltip
		mark.modulate = Color(1.0, 1.0, 1.0, 0.45)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return mark
	var label: Label = Label.new()
	label.text = glyph
	label.tooltip_text = tooltip
	label.modulate = Color(1.0, 1.0, 1.0, 0.45)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## The card's menu. "Paste over" replaces this card with the clipboard's first; "Move to top" is the
## reorder a long list actually asks for, and the drag handle is the rest. It is the button at the top
## of an opened card, and the same entries open from a right click on the card's line.
func _build_menu(index: int) -> Control:
	var menu: MenuButton = MenuButton.new()
	var dots: Texture2D = _editor_icon("GuiTabMenuHl")
	if dots != null:
		menu.icon = dots
	else:
		menu.text = "⋯"
	menu.tooltip_text = EventSheetL10n.translate("More for this card.")
	menu.disabled = not editable
	var popup: PopupMenu = menu.get_popup()
	_fill_card_menu(popup)
	popup.id_pressed.connect(func(id: int) -> void: _on_menu(index, id))
	return menu


func _fill_card_menu(popup: PopupMenu) -> void:
	popup.add_item(EventSheetL10n.translate("Duplicate"), MENU_DUPLICATE)
	popup.add_item(EventSheetL10n.translate("Cut"), MENU_CUT)
	popup.add_item(EventSheetL10n.translate("Copy"), MENU_COPY)
	popup.add_item(EventSheetL10n.translate("Paste"), MENU_PASTE_AFTER)
	popup.add_item(EventSheetL10n.translate("Paste over"), MENU_PASTE_OVER)
	popup.add_item(EventSheetL10n.translate("Move to top"), MENU_MOVE_TO_TOP)
	popup.add_item(EventSheetL10n.translate("Move up"), MENU_MOVE_UP)
	popup.add_item(EventSheetL10n.translate("Move down"), MENU_MOVE_DOWN)
	popup.add_item(EventSheetL10n.translate("Remove"), MENU_REMOVE)
	# The keys that do the same thing from the list, shown beside the words the way Godot's own menus show them.
	for hint: Array in [[MENU_DUPLICATE, KEY_D | KEY_MASK_CMD_OR_CTRL], [MENU_CUT, KEY_X | KEY_MASK_CMD_OR_CTRL],
			[MENU_COPY, KEY_C | KEY_MASK_CMD_OR_CTRL], [MENU_PASTE_AFTER, KEY_V | KEY_MASK_CMD_OR_CTRL], [MENU_REMOVE, KEY_DELETE]]:
		popup.set_item_accelerator(popup.get_item_index(int(hint[0])), int(hint[1]) as Key)
	if _marks_wanted():
		popup.add_separator()
		popup.add_item(EventSheetL10n.translate("Play from here"), MENU_PLAY_FROM)


## Opens the card's menu at a screen point, for a right click on its line.
func open_card_menu(index: int, at: Vector2i) -> void:
	if not editable or index < 0 or index >= _cards.size():
		return
	var popup: PopupMenu = PopupMenu.new()
	_fill_card_menu(popup)
	popup.id_pressed.connect(func(id: int) -> void: _on_menu(index, id))
	popup.popup_hide.connect(popup.queue_free)
	add_child(popup)
	EventSheetWindowPlacement.popup_at(popup, at)


## What a menu entry does. Duplicate, Cut, Copy and Remove act on everything selected when the card the menu
## belongs to is part of the selection, and on that one card otherwise; Paste adds under the card (or under
## the selection it is part of); Paste over and the moves are about this card alone.
func _on_menu(index: int, id: int) -> void:
	var in_selection: bool = _selected.has(index)
	match id:
		MENU_DUPLICATE:
			if in_selection:
				duplicate_selected()
			else:
				duplicate_card(index)
		MENU_CUT:
			_choose(index)
			cut_selected()
		MENU_COPY:
			_choose(index)
			copy_selected()
		MENU_PASTE_AFTER:
			_choose(index)
			paste_after_selection(_clipboard_text())
		MENU_PASTE_OVER:
			paste_over(index, _clipboard_text())
		MENU_MOVE_TO_TOP:
			move_card(index, 0)
		MENU_MOVE_UP:
			move_card(index, index - 1)
		MENU_MOVE_DOWN:
			move_card(index, index + 1)
		MENU_REMOVE:
			if in_selection:
				remove_selected()
			else:
				remove_card(index)
		MENU_PLAY_FROM:
			_run_mark("play_from", index)


## Makes the card the menu belongs to the selection when it is not part of it, so an entry that acts on
## "the selection" acts on what was clicked.
func _choose(index: int) -> void:
	if not _selected.has(index):
		select_card(index, "click")


## The unfolded card: what this kind explains, then its own fields, then what the running game is
## writing back. Per-card hooks are whatever the schema declared - a card with none shows none.
func _build_body(index: int, card: Dictionary, entry: Dictionary) -> Control:
	var body: VBoxContainer = VBoxContainer.new()
	var help: String = _said(str(entry.get("help", "")).strip_edges())
	# A schema may keep its explanation for the Add box's tooltips and say nothing above the fields.
	if not help.is_empty() and bool(_schema.get("help_in_body", true)):
		var info: Label = Label.new()
		info.text = help
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_theme_font_size_override("font_size", EventSheetPalette.scaled(10))
		info.modulate = Color(1.0, 1.0, 1.0, 0.6)
		body.add_child(info)
	if not EventSheetCardSchemas.enabled_key(_schema).is_empty():
		body.add_child(_build_active_row(index, EventSheetCardSchemas.card_enabled(_schema, card)))
	if not str(_schema.get("label_key", "")).is_empty():
		body.add_child(_build_label_row(index, card, entry))
	var fields: VBoxContainer = VBoxContainer.new()
	fields.add_theme_constant_override("separation", 2)
	var folded: Dictionary = {}
	var drawn_group: String = ""
	var last_row: HBoxContainer = null
	for field: Variant in EventSheetCardSchemas.all_fields(_schema, entry):
		if not (field is Dictionary) or not EventSheetCardSchemas.field_visible(field as Dictionary, card):
			continue
		var fold_name: String = EventSheetCardSchemas.field_fold(field as Dictionary)
		if not fold_name.is_empty():
			if not folded.has(fold_name):
				var rows: VBoxContainer = VBoxContainer.new()
				rows.add_theme_constant_override("separation", 2)
				folded[fold_name] = rows
				last_row = null
			last_row = _add_field_row(folded[fold_name] as VBoxContainer, index, card, field as Dictionary, last_row)
			continue
		var group: String = EventSheetCardSchemas.field_group(field as Dictionary)
		if group != drawn_group:
			drawn_group = group
			if not group.is_empty():
				fields.add_child(_section_heading(group))
		last_row = _add_field_row(fields, index, card, field as Dictionary, last_row)
	body.add_child(fields)
	for fold_name: Variant in folded:
		body.add_child(_build_foldout(index, str(fold_name), folded[fold_name] as VBoxContainer, card))
	for live: Variant in EventSheetCardSchemas.live_of(entry):
		if not (live is Dictionary):
			continue
		var readout: Label = Label.new()
		readout.text = "%s  %s" % [str((live as Dictionary).get("label", "")), str(card.get(str((live as Dictionary).get("key", "")), ""))]
		readout.add_theme_font_size_override("font_size", EventSheetPalette.scaled(10))
		readout.modulate = Color(1.0, 1.0, 1.0, 0.4)
		readout.tooltip_text = EventSheetL10n.translate("Written by the game while it runs.")
		body.add_child(readout)
	var actions: Array = entry.get("actions") if entry.get("actions") is Array else []
	if not actions.is_empty():
		var strip: HBoxContainer = HBoxContainer.new()
		strip.add_theme_constant_override("separation", 4)
		for action: Variant in actions:
			if not (action is Dictionary) or not ((action as Dictionary).get("run") is Callable):
				continue
			var run: Callable = (action as Dictionary).get("run")
			strip.add_child(_small_button(str((action as Dictionary).get("label", "Run")), "", func() -> void: run.call(_cards[index])))
		body.add_child(strip)
	return body


## One field's row added to a box: a field marked `beside` goes on the row before it (the top of a range beside
## its bottom) instead of starting its own. Returns the row the next field may sit beside.
func _add_field_row(box: VBoxContainer, index: int, card: Dictionary, field: Dictionary, last_row: HBoxContainer) -> HBoxContainer:
	if bool(field.get("beside", false)) and last_row != null:
		_build_field(index, card, field, last_row)
		return last_row
	var row: Control = _build_field(index, card, field)
	box.add_child(row)
	return row as HBoxContainer


## A foldout inside an open card: Godot's own foldable container, closed until it is opened, remembered
## while the list is on screen and never written to the data.
func _build_foldout(index: int, fold_name: String, rows: VBoxContainer, card: Dictionary = {}) -> Control:
	var key: String = "%d:%s" % [index, fold_name]
	var fold: FoldableContainer = FoldableContainer.new()
	fold.title = _said(fold_name)
	# Shut until opened - unless the schema says this card already holds something in it (a line that
	# is dashed shows its look without being asked).
	var opens_itself: Variant = _schema.get("fold_open")
	var starts_open: bool = opens_itself is Callable and (opens_itself as Callable).is_valid() and bool((opens_itself as Callable).call(card, fold_name))
	fold.folded = not bool(_open_folds.get(key, starts_open))
	fold.add_child(rows)
	# The card is already one surface, so the foldout is a heading on it and not a second panel: Godot's own
	# container with its boxes left empty.
	for box_name: String in ["title_panel", "title_collapsed_panel", "title_hover_panel", "title_collapsed_hover_panel", "panel"]:
		var flat: StyleBoxEmpty = StyleBoxEmpty.new()
		flat.content_margin_top = 2.0
		flat.content_margin_bottom = 2.0
		fold.add_theme_stylebox_override(box_name, flat)
	fold.add_theme_font_override("font", EventSheetLookStyle.bold_font())
	fold.folding_changed.connect(func(is_folded: bool) -> void: _open_folds[key] = not is_folded)
	return fold


## Lights or puts out the clock mark on a card's head after one of its timing numbers changed.
func _refresh_timing_mark(index: int) -> void:
	var mark: Control = _timing_marks.get(index) as Control
	var differs: Variant = _schema.get("timing_differs")
	if mark != null and is_instance_valid(mark) and differs is Callable and index >= 0 and index < _cards.size():
		mark.visible = bool((differs as Callable).call(_cards[index]))


## A section heading inside an open card - the line that turns a column of twenty fields into four
## short groups a designer reads in order. It is a LABEL, not a fold: a card is already the fold, and
## a second one inside it would hide the field somebody opened the card to change.
func _section_heading(title: String) -> Control:
	var heading: Label = Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size", EventSheetPalette.scaled(10))
	heading.modulate = Color(1.0, 1.0, 1.0, 0.5)
	return heading


## The card's own enable box, the same switch the header carries - here because an open card is where
## a designer reads what this one does before deciding to skip it.
func _build_active_row(index: int, enabled: bool) -> Control:
	var box: CheckBox = CheckBox.new()
	box.button_pressed = enabled
	box.disabled = not editable
	box.tooltip_text = EventSheetL10n.translate("Untick to skip this card.")
	box.toggled.connect(func(pressed: bool) -> void: set_card_enabled(index, pressed))
	return _titled_row(EventSheetL10n.translate("Active"), box)


## The card's name, and beside it the colour of its stripe when the list stores one per card. A
## schema that declares no label key has no name to type, so this row is not built at all.
func _build_label_row(index: int, card: Dictionary, entry: Dictionary) -> Control:
	var row: HBoxContainer = _titled_row(EventSheetL10n.translate("Label"), null)
	var name_edit: LineEdit = LineEdit.new()
	name_edit.text = str(card.get(str(_schema.get("label_key", "")), ""))
	name_edit.placeholder_text = EventSheetCardSchemas.card_label(_schema, _spec, entry, card)
	name_edit.editable = editable
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.text_changed.connect(func(text: String) -> void: set_card_label(index, text))
	row.add_child(name_edit)
	# The colour a card carries stays in the data; it is not drawn, so its editor is not offered.
	return row


## A muted title with its editor beside it - the shape every row inside a card has.
func _titled_row(title: String, control: Control) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	var label: Label = Label.new()
	label.text = title
	label.custom_minimum_size = Vector2(EventSheetPalette.scaled(120), 0.0)
	label.modulate = Color(1.0, 1.0, 1.0, 0.75)
	row.add_child(label)
	if control != null:
		row.add_child(control)
	return row


## One field: its title, its editor, and - when the field is linked to another - the "=" toggle that
## ties the two numbers together while it is lit.
##
## THE TIE IS A RATIO, never a copy: pressing "=" remembers what the linked key is worth per unit of
## this one, and every edit afterwards keeps that proportion - the SAME meaning the property-level
## "=" carries, so one glyph never stands for two things. A ratio only exists between numbers, so a
## link declared on a field holding text or a colour writes nothing.
func _build_field(index: int, card: Dictionary, field: Dictionary, into: HBoxContainer = null) -> Control:
	var row: HBoxContainer = into
	if row == null:
		if bool(field.get("full_width", false)):
			# A line of words that runs under the whole card, with no title column in front of it.
			row = HBoxContainer.new()
		else:
			row = _titled_row(_said(str(field.get("label", field.get("key", "")))), null)
	if into != null and not str(field.get("to_word", "")).is_empty():
		var joiner: Label = Label.new()
		joiner.text = _said(str(field.get("to_word")))
		joiner.add_theme_color_override("font_color", EventSheetLookStyle.quiet())
		row.add_child(joiner)
	var linked: String = str(field.get("link", ""))
	var link_toggle: CheckButton = null
	# Held in a one-cell Array so the two lambdas below share the ratio the toggle wrote, rather than
	# each capturing its own copy of a local float.
	var ratio: Array = [1.0]
	if not linked.is_empty():
		link_toggle = CheckButton.new()
		link_toggle.text = "="
		link_toggle.tooltip_text = EventSheetL10n.translate("Keep %s and this field in the ratio they have now.") % linked
		link_toggle.disabled = not editable
		link_toggle.toggled.connect(func(pressed: bool) -> void:
			if pressed:
				ratio[0] = link_ratio_for(index, str(field.get("key", "")), linked))
	var write: Callable = func(value: Variant) -> void:
		var written: String = str(field.get("key", ""))
		if link_toggle != null and link_toggle.button_pressed and (value is float or value is int):
			write_linked_pair(index, written, linked, ratio[0], float(value))
		else:
			_write_field(index, written, value)
			value_changed.emit(get_value())
		# A field may ask for other keys to follow its value (a speed that sets the card's length).
		var follows: Variant = field.get("on_change")
		if follows is Callable and index >= 0 and index < _cards.size():
			var more: Variant = (follows as Callable).call(_cards[index], _edited, value)
			if more is Dictionary:
				for more_key: Variant in more:
					_write_field(index, str(more_key), more[more_key])
				value_changed.emit(get_value())
		_refresh_notes(index)
		_refresh_timing_mark(index)
		_refresh_head(index)
		# Changing a card's KIND changes which fields it has, so the card is redrawn - deferred,
		# because the control that just emitted is still finishing its own signal.
		if written == str(_spec.get("kind_key", "kind")):
			_rebuild.call_deferred()
		# A field other fields show or hide on (a tick that reveals its settings) redraws the card too.
		elif bool(field.get("redraw", false)):
			_rebuild.call_deferred()
	var editor: Control = _build_field_editor(card, field, write, index)
	editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(editor)
	if str(field.get("drawer", "")) == "note":
		_notes.append({"label": editor, "field": field, "index": index})
		# A line with nothing to say takes no room, and neither does the row that holds it.
		row.visible = editor.visible
	var suffix: String = str(field.get("suffix", ""))
	if not suffix.is_empty():
		var unit: Label = Label.new()
		unit.text = suffix
		unit.add_theme_color_override("font_color", EventSheetLookStyle.quiet())
		row.add_child(unit)
	if link_toggle != null:
		row.add_child(link_toggle)
	return row


## A word a schema wrote, said in the editor's language. A word with no row in the translation tables
## reads as written, so a schema of a pack's own (the Drawing Prefab's, a project's) is unchanged.
func _said(text: String) -> String:
	return EventSheetL10n.translate(text) if not text.is_empty() else text


## Writes one key of one card and tells the owner, the way a field's own write does. For the fields that
## write more than the key they stand for (a picked node that also sets the card's length).
func write_card_key(index: int, key: String, value: Variant) -> void:
	_write_field(index, key, value)
	value_changed.emit(get_value())
	_refresh_head(index)


## Repaints one card's line in place after one of its numbers changed: the tile in the card's colour and the
## summary beside it. Only a schema that says its line follows its numbers (`live_head`) has this; any other
## list draws its line as it always did and keeps it until the list is rebuilt.
func _refresh_head(index: int) -> void:
	if not bool(_schema.get("live_head", false)) or index < 0 or index >= _cards.size():
		return
	var card: Dictionary = _cards[index]
	var tile: Control = _head_tiles.get(index) as Control
	if tile != null and is_instance_valid(tile) and tile.has_method("set_card"):
		tile.call("set_card", card)
	var badge: Label = _badges.get(index) as Label
	if badge != null and is_instance_valid(badge):
		var entry: Dictionary = _entry_for(card)
		var badge_text: String = EventSheetCardSchemas.card_badge(entry, card, _cards, index)
		badge.text = badge_text
		badge.visible = not badge_text.is_empty()
		badge.autowrap_mode = TextServer.AUTOWRAP_OFF if badge_text.length() <= 12 else TextServer.AUTOWRAP_WORD_SMART
		badge.custom_minimum_size.x = _badge_room(badge, badge_text)


## The words of the note lines showing in the open cards right now: what a test reads back.
func visible_notes() -> PackedStringArray:
	var words: PackedStringArray = PackedStringArray()
	for note: Variant in _notes:
		var label: Variant = (note as Dictionary).get("label")
		if is_instance_valid(label) and (label as Label).visible and not (label as Label).text.is_empty():
			words.append((label as Label).text)
	return words


## Opens or shuts one card, and draws the list again. A card's openness is a view, never stored.
func set_unfolded(index: int, open: bool) -> void:
	_unfolded[index] = open
	_rebuild()


func is_unfolded(index: int) -> bool:
	return bool(_unfolded.get(index, false))


## The keys of the fields an open card shows right now, in the order it draws them: what a test reads back.
func field_keys_of(index: int) -> Array:
	var keys: Array = []
	if index < 0 or index >= _cards.size():
		return keys
	for field: Variant in EventSheetCardSchemas.all_fields(_schema, _entry_for(_cards[index])):
		if field is Dictionary and EventSheetCardSchemas.field_visible(field as Dictionary, _cards[index]):
			keys.append(str((field as Dictionary).get("key", "")))
	return keys


## The tile on a card's line, or null: what a test and a repaint read back.
func head_tile_of(index: int) -> Control:
	return _head_tiles.get(index) as Control


## The summary written beside a card's title right now.
func head_summary_of(index: int) -> String:
	var badge: Label = _badges.get(index) as Label
	return badge.text if badge != null and is_instance_valid(badge) else ""


## Takes one key off a card, so a card that never used it is saved without it.
func erase_card_key(index: int, key: String) -> void:
	if index < 0 or index >= _cards.size() or not (_cards[index] as Dictionary).has(key):
		return
	(_cards[index] as Dictionary).erase(key)
	value_changed.emit(get_value())


## Draws the list again once the control that asked has finished its own signal.
func rebuild_soon() -> void:
	_rebuild.call_deferred()


## Write one value into one card, KEEPING the spelling the file already used: a number stored as an
## int stays an int, a colour stored as "#rrggbb" stays a String. This is what lets a list saved
## before this drawer existed be edited and saved again byte for byte apart from the value that moved.
func _write_field(index: int, key: String, value: Variant) -> void:
	if index < 0 or index >= _cards.size() or key.is_empty():
		return
	var card: Dictionary = _cards[index]
	var existing: Variant = card.get(key)
	if existing is int and value is float:
		card[key] = int(round(float(value)))
	elif existing is String and value is Color:
		card[key] = "#" + (value as Color).to_html((value as Color).a < 1.0)
	elif existing is String and (value is float or value is int):
		card[key] = str(value)
	else:
		card[key] = value


## The ratio the "=" tie remembers when it is switched on: what `linked` is worth per unit of `key`,
## as the card holds them right now. A leader of zero has no ratio to read, so the pair keeps a
## ratio of one - the same answer the property-level link gives.
func link_ratio_for(index: int, key: String, linked: String) -> float:
	return EventSheetDrawerWidgets.LinkToggle.link_ratio(_field_number(index, key), _field_number(index, linked))


## Write one field and move its linked partner to keep `ratio`, as one edit. This is what a lit "="
## does: the partner is not handed this field's value, it is handed its share of it.
func write_linked_pair(index: int, key: String, linked: String, ratio: float, value: float) -> void:
	_write_field(index, key, value)
	if not linked.is_empty():
		_write_field(index, linked, EventSheetDrawerWidgets.LinkToggle.link_follow(ratio, value))
	value_changed.emit(get_value())


## One card key read as a number - what the "=" tie measures its ratio from. A key the card does not
## hold, or holds as text, reads as zero, which is the same "no ratio to read" the property-level
## link answers with.
func _field_number(index: int, key: String) -> float:
	if index < 0 or index >= _cards.size():
		return 0.0
	var stored: Variant = (_cards[index] as Dictionary).get(key)
	if stored is float or stored is int:
		return float(stored)
	return 0.0


## The editor for one field, chosen by the field's `drawer` word. The words are the SAME ones the
## `eventsheet:` markers use, so a schema names a drawer the way an export does, and the widgets are
## the shipped ones rather than second copies.
func _build_field_editor(card: Dictionary, field: Dictionary, write: Callable, index: int = -1) -> Control:
	var key: String = str(field.get("key", ""))
	# A field with an `unset` value shows it while the card holds nothing under the key, and stores
	# nothing until the field is touched: the box is drawn from a copy, so reading a card never writes it.
	if field.has("unset") and not card.has(key):
		card = card.duplicate()
		card[key] = field["unset"]
	var spelling: String = str(field.get("drawer", "")).strip_edges()
	var drawer: String = spelling.get_slice(":", 0)
	var tail: String = spelling.substr(drawer.length() + 1) if spelling.length() > drawer.length() else ""
	match drawer:
		"bool":
			var check: CheckBox = CheckBox.new()
			check.button_pressed = bool(card.get(key, false))
			check.disabled = not editable
			check.toggled.connect(func(pressed: bool) -> void: write.call(pressed))
			return check
		"text":
			var edit: LineEdit = LineEdit.new()
			edit.text = str(card.get(key, ""))
			edit.editable = editable
			edit.text_changed.connect(func(text: String) -> void: write.call(text))
			return edit
		"options":
			var choice: OptionButton = OptionButton.new()
			# A choice may be spelled `value=Words to show`: the file keeps the value, the person reads the words.
			var options: PackedStringArray = PackedStringArray()
			var current: String = str(card.get(key, ""))
			for spelled: String in tail.split(",", false):
				options.append(spelled.get_slice("=", 0))
				choice.add_item(_said(spelled.get_slice("=", 1) if spelled.contains("=") else spelled))
				# A choice may wear a small picture, drawn by the schema from the stored word.
				var item_picture: Variant = field.get("option_icon")
				if item_picture is Callable and (item_picture as Callable).is_valid():
					choice.set_item_icon(choice.item_count - 1, (item_picture as Callable).call(spelled.get_slice("=", 0), _on_light_ground()) as Texture2D)
				if options[options.size() - 1] == current:
					choice.select(options.size() - 1)
			if bool(field.get("blank_unknown", false)) and not options.has(current):
				# A word that is none of the choices shows as nothing chosen, not as the first choice.
				choice.select(-1)
			choice.disabled = not editable
			choice.item_selected.connect(func(chosen: int) -> void:
				if chosen >= 0 and chosen < options.size():
					write.call(options[chosen]))
			return choice
		"toggle_row":
			var toggle_spec: Dictionary = attribute_drawers().call("parse_toggle_spec", Array(tail.split(":")))
			var toggles: EventSheetDrawerWidgets.DrawerToggleRow = EventSheetDrawerWidgets.DrawerToggleRow.new(
				toggle_spec.get("options", PackedStringArray()), str(toggle_spec.get("icons", "")), bool(toggle_spec.get("segmented", false)))
			toggles.set_value(str(card.get(key, "")))
			toggles.value_changed.connect(func(chosen: String) -> void: write.call(chosen))
			return toggles
		"unit":
			# The tail is spelled the way the export marker spells it - "kinds=s|ms,store=s", or just
			# a family's name ("time"). A spelling that named no units at all leaves an ordinary
			# number box rather than a dropdown with nothing in it.
			var unit_spec: Dictionary = attribute_drawers().call("parse_unit_spec", tail)
			var unit_ids: PackedStringArray = unit_spec.get("units", PackedStringArray())
			if unit_ids.is_empty():
				return _number_field(card, key, write, FLOAT_STEP)
			# A card holds its times in seconds, so the unit is a word beside the number, as it is for every
			# other unit on a card (dB), and not a second dropdown on the one row that has seconds.
			if unit_ids.has("s") and str(unit_spec.get("store", "s")) == "s":
				return _number_with_unit(card, key, write, "s")
			var unit_field: EventSheetDrawerWidgets.DrawerUnitField = EventSheetDrawerWidgets.DrawerUnitField.new(
				unit_ids, str(unit_spec.get("store", "")))
			unit_field.set_value(float(card.get(key, 0.0)))
			unit_field.set_editable(editable)
			unit_field.value_changed.connect(func(value: float) -> void: write.call(value))
			return unit_field
		"pair":
			return _pair_field(card, field, write, index)
		"tick_words":
			return _tick_field(card, field, write, tail)
		"color_button":
			var picker: ColorPickerButton = ColorPickerButton.new()
			picker.edit_alpha = true
			picker.color = _color_of(card.get(key))
			picker.disabled = not editable
			picker.custom_minimum_size.y = EventSheetLookStyle.px(22.0)
			picker.color_changed.connect(func(picked: Color) -> void: write.call(picked))
			return picker
		"swatch_row":
			var swatch: EventSheetDrawerWidgets.DrawerSwatchRow = EventSheetDrawerWidgets.DrawerSwatchRow.new()
			swatch.set_value(_color_of(card.get(key)))
			swatch.value_changed.connect(func(picked: Color) -> void: write.call(picked))
			return swatch
		"corners":
			var corners: EventSheetDrawerWidgets.DrawerCorners = EventSheetDrawerWidgets.DrawerCorners.new()
			corners.set_value(card.get(key) if card.get(key) is Vector4 else Vector4.ZERO)
			corners.set_editable(editable)
			corners.value_changed.connect(func(value: Vector4) -> void: write.call(value))
			return corners
		"vector_dial":
			var dial: EventSheetDrawerWidgets.DrawerVectorDial = EventSheetDrawerWidgets.DrawerVectorDial.new(
				tail.to_float() if tail.is_valid_float() else 100.0)
			dial.set_value(card.get(key) if card.get(key) is Vector2 else Vector2.ZERO)
			dial.value_changed.connect(func(value: Vector2) -> void: write.call(value))
			return dial
		"progress_bar":
			var bar: EventSheetDrawerWidgets.DrawerProgressBar = EventSheetDrawerWidgets.DrawerProgressBar.new(
				tail.get_slice(":", 0).to_float(), tail.get_slice(":", 1).to_float() if tail.contains(":") else 100.0)
			bar.set_value(float(card.get(key, 0.0)))
			bar.value_changed.connect(func(value: float) -> void: write.call(value))
			return bar
		"min_max":
			var slider: EventSheetDrawerWidgets.DrawerMinMaxSlider = EventSheetDrawerWidgets.DrawerMinMaxSlider.new(
				tail.get_slice(":", 0).to_float(), tail.get_slice(":", 1).to_float() if tail.contains(":") else 100.0)
			slider.set_value(card.get(key) if card.get(key) is Vector2 else Vector2.ZERO)
			slider.value_changed.connect(func(value: Vector2) -> void: write.call(value))
			return slider
		"texture_preview":
			return _texture_field(card, key, write)
		"curve_editor":
			return _curve_field(card, key, write)
		"int":
			# A field that holds a whole count writes one (a repeat of 3, not 3.0), as the row that writes it does.
			var whole: bool = bool(field.get("whole", false))
			return _number_field(card, key, (func(value: float) -> void: write.call(int(value))) if whole else write, INT_STEP)
		"limit":
			return _limit_field(card, key, write, _said(str(field.get("empty_word", ""))))
		"spread":
			return _spread_field(card, key, write)
		"bus":
			return _bus_field(card, key, write)
		"resource":
			return _resource_text_field(card, key, write, tail)
		"above":
			return _above_field(card, field, write, index)
		"note":
			return _note_line(card, field, index)
		"custom":
			return _custom_field(index, field)
		"godot":
			return attribute_fields().call("godot_field", self, card, field, write, index)
		"node", "property", "typed", "choices", "arguments", "from":
			return attribute_fields().call(drawer + "_field", self, card, field, write, index)
	return _number_field(card, key, write, FLOAT_STEP)


## A number cell. The STEP is the value's own precision, not a taste: a Range SNAPS what it shows to
## a multiple of its step, so a coarse step silently rewrites somebody's saved file - a stored 12.345
## would show as 12.3, and the next arrow press would write 12.4 back into the .tres. Floats therefore
## step by the same 0.001 the unit field and the corners boxes use, and only a field the schema calls
## an `int` steps by a whole one.
func _number_field(card: Dictionary, key: String, write: Callable, step: float) -> Control:
	var spin: SpinBox = SpinBox.new()
	spin.allow_greater = true
	spin.allow_lesser = true
	spin.step = step
	spin.rounded = false
	spin.editable = editable
	spin.value = float(card.get(key, 0.0))
	spin.value_changed.connect(func(value: float) -> void: write.call(value))
	return spin


## A number box that says a word while the number is 0: "no limit" where 0 means there is none. Typing a number
## writes it; clearing the box writes 0 again.
func _limit_field(card: Dictionary, key: String, write: Callable, empty_word: String) -> Control:
	var edit: LineEdit = LineEdit.new()
	edit.placeholder_text = empty_word
	edit.editable = editable
	var held: float = float(card.get(key, 0.0))
	edit.text = "" if held <= 0.0 else str(snappedf(held, 0.001)).trim_suffix(".0")
	edit.text_changed.connect(func(text: String) -> void:
		write.call(maxf(text.to_float(), 0.0) if text.is_valid_float() else 0.0))
	return edit


## A number box with its unit as small quiet text at the right.
func _number_with_unit(card: Dictionary, key: String, write: Callable, unit_text: String) -> Control:
	var box: HBoxContainer = HBoxContainer.new()
	var spin: Control = _number_field(card, key, write, FLOAT_STEP)
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(spin)
	var unit: Label = Label.new()
	unit.text = unit_text
	unit.add_theme_font_size_override("font_size", EventSheetPalette.scaled(10))
	unit.add_theme_color_override("font_color", EventSheetLookStyle.quiet())
	box.add_child(unit)
	return box


## Two numbers on ONE row, the way Godot's own Vector2 field is drawn: "x" and its box, "y" and its box. The
## field's key holds the first number and its `pair` names the key of the second, so a card keeps two plain
## keys and the row is only how they are shown.
func _pair_field(card: Dictionary, field: Dictionary, write: Callable, index: int) -> Control:
	var other: String = str(field.get("pair", ""))
	var box: HBoxContainer = HBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var write_other: Callable = func(value: float) -> void:
		_write_field(index, other, value)
		value_changed.emit(get_value())
		_refresh_notes(index)
		_refresh_head(index)
	var parts: Array = [[str(field.get("key", "")), "x", write, Color(0.9, 0.45, 0.45)], [other, "y", write_other, Color(0.55, 0.85, 0.45)]]
	for part: Array in parts:
		var axis: Label = Label.new()
		axis.text = str(part[1])
		axis.add_theme_color_override("font_color", _axis_ink(str(part[1]), part[3] as Color))
		box.add_child(axis)
		var number: Control = _number_field(card, str(part[0]), part[2] as Callable, FLOAT_STEP)
		number.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(number)
	return box


## The colour of an axis letter: the editor's own x / y colours where there is an editor theme to ask.
func _axis_ink(axis: String, fallback: Color) -> Color:
	var colour_name: String = "property_color_" + axis
	return get_theme_color(colour_name, "Editor") if has_theme_color(colour_name, "Editor") else fallback


## A tick over two stored words: ticked writes the first, unticked the second. The words are the file's own
## (`uniform` / `fixed`); the tick only says in plain words what the first one means.
func _tick_field(card: Dictionary, field: Dictionary, write: Callable, tail: String) -> Control:
	var words: PackedStringArray = tail.split(",")
	var on_word: String = words[0] if words.size() > 0 else "true"
	var off_word: String = words[1] if words.size() > 1 else "false"
	var check: CheckBox = CheckBox.new()
	check.text = _said(str(field.get("tick_text", "")))
	check.button_pressed = str(card.get(str(field.get("key", "")), "")) == on_word
	check.disabled = not editable
	check.toggled.connect(func(pressed: bool) -> void: write.call(on_word if pressed else off_word))
	return check


## A number with a plus-or-minus sign in front of it: how far a random roll may land either side of
## another number.
func _spread_field(card: Dictionary, key: String, write: Callable) -> Control:
	var box: HBoxContainer = HBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var sign_mark: Label = Label.new()
	sign_mark.text = "±"
	sign_mark.add_theme_color_override("font_color", EventSheetLookStyle.quiet())
	box.add_child(sign_mark)
	var number: Control = _number_field(card, key, write, FLOAT_STEP)
	number.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(number)
	return box


## The project's audio buses as a choice, read from the audio server the way Godot's own audio player
## nodes read them. A bus the card names that the project no longer has stays in the list, said so,
## because swapping it for another would rewrite a card nobody touched.
func _bus_field(card: Dictionary, key: String, write: Callable) -> Control:
	var choice: OptionButton = OptionButton.new()
	var names: PackedStringArray = PackedStringArray()
	for bus_index: int in range(AudioServer.bus_count):
		names.append(AudioServer.get_bus_name(bus_index))
	var current: String = str(card.get(key, "Master"))
	if not names.has(current):
		names.append(current)
	for bus_index: int in range(names.size()):
		var missing: bool = AudioServer.get_bus_index(names[bus_index]) < 0
		choice.add_item(names[bus_index] if not missing else EventSheetL10n.translate("%s (not in this project)") % names[bus_index])
		if names[bus_index] == current:
			choice.select(bus_index)
	choice.disabled = not editable
	choice.item_selected.connect(func(chosen: int) -> void:
		if chosen >= 0 and chosen < names.size():
			write.call(names[chosen]))
	return choice


## A file picked with Godot's own resource picker and kept as text: the file's uid when it has one (so
## it survives a move), else its path. A card is plain data, so it never holds the resource itself.
## What cannot be kept as text, a resource that lives inside the scene, is refused in words.
func _resource_text_field(card: Dictionary, key: String, write: Callable, base_type: String) -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	var stored: String = str(card.get(key, ""))
	var current: Resource = load(stored) as Resource if not stored.is_empty() and ResourceLoader.exists(stored) else null
	var refusal: Label = EventSheetLookStyle.message_line("", EventSheetLookStyle.Tone.WARNING)
	refusal.visible = false
	box.add_child(_resource_picker(base_type, current, func(picked: Resource) -> void:
		var text: String = EventSheetCardSchemas.resource_reference(picked)
		if picked != null and text.is_empty():
			refusal.text = EventSheetL10n.translate("Save it as a file first. A card keeps the file, not a copy inside the scene.")
			refusal.visible = true
			return
		refusal.visible = false
		write.call(text)
		# The notes under the picker (no sound picked, sound gone) change with the pick.
		_rebuild.call_deferred()))
	box.add_child(refusal)
	# Godot's picker shows a picture of a sound, not its name, so the file's name is said under it. (A
	# texture's picker already shows its own name.)
	if current != null and base_type != "Texture2D":
		var named: Label = Label.new()
		named.text = stored.get_file() if not stored.begins_with("uid://") else current.resource_path.get_file()
		named.add_theme_font_size_override("font_size", EventSheetPalette.scaled(10))
		named.add_theme_color_override("font_color", EventSheetLookStyle.quiet())
		box.add_child(named)
	return box


## Rewrites the note lines of one card from the card as it is now.
func _refresh_notes(index: int) -> void:
	if index < 0 or index >= _cards.size():
		return
	for note: Variant in _notes:
		var entry: Dictionary = note as Dictionary
		var maker: Variant = (entry.get("field") as Dictionary).get("text")
		if int(entry.get("index", -1)) == index and maker is Callable and is_instance_valid(entry.get("label")):
			(entry.get("label") as Label).text = str(EventSheetCardSchemas.ask(maker as Callable, _cards[index], _cards, index, _edited))
			if bool((entry.get("field") as Dictionary).get("hide_empty", false)):
				(entry.get("label") as Label).visible = not (entry.get("label") as Label).text.is_empty()
				(entry.get("label") as Label).get_parent().visible = (entry.get("label") as Label).visible


## A choice among the cards above this one, by name: the first entry stands for all of them and is what a card
## nobody changed holds (nothing is stored), the others are the names the schema lists. A name the card holds
## that is no card above any more is still shown, so it is never dropped without being seen.
func _above_field(card: Dictionary, field: Dictionary, write: Callable, index: int) -> Control:
	var key: String = str(field.get("key", ""))
	var choice: OptionButton = OptionButton.new()
	var values: PackedStringArray = PackedStringArray([""])
	choice.add_item(str(field.get("all_label", EventSheetL10n.translate("All cards above"))))
	var maker: Variant = field.get("above")
	var listed: Array = []
	if maker is Callable and index >= 0:
		var answer: Variant = (maker as Callable).call(_cards, index)
		listed = answer if answer is Array else []
	for entry: Variant in listed:
		values.append(str((entry as Dictionary).get("value", "")))
		choice.add_item(str((entry as Dictionary).get("text", "")))
	var current: String = str(card.get(key, ""))
	var picked: int = values.find(current) if not current.is_empty() else 0
	if picked < 0:
		values.append(current)
		choice.add_item(EventSheetL10n.translate("%s (not above this card)") % current)
		picked = values.size() - 1
	choice.select(picked)
	choice.disabled = not editable
	choice.item_selected.connect(func(chosen: int) -> void:
		if chosen == 0:
			if index >= 0 and index < _cards.size() and (_cards[index] as Dictionary).has(key):
				(_cards[index] as Dictionary).erase(key)
				value_changed.emit(get_value())
				_refresh_notes(index)
		elif chosen > 0 and chosen < values.size():
			write.call(values[chosen]))
	return choice


## A line of words under a field, computed from the card by the schema, never stored. It turns amber
## when the schema says the card needs attention.
func _note_line(card: Dictionary, field: Dictionary, index: int = -1) -> Control:
	var maker: Variant = field.get("text")
	var said: String = str(EventSheetCardSchemas.ask(maker as Callable, card, _cards, index, _edited)) if maker is Callable else EventSheetL10n.translate(str(field.get("label", "")))
	var warn: Variant = field.get("warn_when")
	var needs_care: bool = warn is Callable and bool(EventSheetCardSchemas.ask(warn as Callable, card, _cards, index, _edited))
	var line: Label = EventSheetLookStyle.message_line(said, EventSheetLookStyle.Tone.WARNING if needs_care else EventSheetLookStyle.Tone.NOTE)
	line.add_theme_font_size_override("font_size", EventSheetPalette.scaled(10))
	# A line that has nothing to say takes no room at all.
	line.visible = said.is_empty() == false or not bool(field.get("hide_empty", false))
	return line


## A control the schema builds itself. It is handed the card as it is NOW and a way to ask for it again
## (at every press), so what it does follows the numbers the person has just changed.
func _custom_field(index: int, field: Dictionary) -> Control:
	var maker: Variant = field.get("build")
	if not (maker is Callable) or not (maker as Callable).is_valid():
		return Control.new()
	var now: Callable = func() -> Dictionary:
		return _cards[index] if index >= 0 and index < _cards.size() else {}
	var made: Variant = (maker as Callable).call(now.call(), now, _edited)
	return made as Control if made is Control else Control.new()


## A texture slot: a path field and its thumbnail when the card stores a PATH (which is what a saved
## list of plain data holds), the editor's own picker when it stores a resource.
func _texture_field(card: Dictionary, key: String, write: Callable) -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	var preview: EventSheetDrawerWidgets.DrawerTexturePreview = EventSheetDrawerWidgets.DrawerTexturePreview.new()
	var stored: Variant = card.get(key)
	if stored is Object or stored == null:
		var picker: Control = _resource_picker("Texture2D", stored as Resource, func(resource: Resource) -> void:
			preview.set_texture(resource as Texture2D)
			write.call(resource))
		box.add_child(picker)
		preview.set_texture(stored as Texture2D)
	else:
		var path_edit: LineEdit = LineEdit.new()
		path_edit.text = str(stored)
		path_edit.placeholder_text = "res://path.png"
		path_edit.editable = editable
		path_edit.text_changed.connect(func(text: String) -> void:
			preview.set_texture(load(text) as Texture2D if ResourceLoader.exists(text) else null)
			write.call(text))
		box.add_child(path_edit)
		preview.set_texture(load(str(stored)) as Texture2D if ResourceLoader.exists(str(stored)) else null)
	box.add_child(preview)
	return box


func _curve_field(card: Dictionary, key: String, write: Callable) -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	var preview: EventSheetDrawerWidgets.DrawerCurvePreview = EventSheetDrawerWidgets.DrawerCurvePreview.new()
	var stored: Variant = card.get(key)
	box.add_child(_resource_picker("Curve", stored as Resource, func(resource: Resource) -> void:
		preview.set_curve(resource as Curve)
		write.call(resource)))
	preview.set_curve(stored as Curve)
	box.add_child(preview)
	return box


## The editor's resource picker, or a plain label when there is no editor around to build one (a
## headless tool run). A card is Inspector chrome either way, so the fallback says so and moves on.
func _resource_picker(base_type: String, current: Resource, on_changed: Callable) -> Control:
	if not ClassDB.can_instantiate("EditorResourcePicker"):
		var placeholder: Label = Label.new()
		placeholder.text = current.resource_path if current != null else EventSheetL10n.translate("(none)")
		placeholder.modulate = Color(1.0, 1.0, 1.0, 0.5)
		return placeholder
	var picker: EditorResourcePicker = EditorResourcePicker.new()
	picker.base_type = base_type
	picker.edited_resource = current
	picker.editable = editable
	picker.resource_changed.connect(on_changed)
	return picker


## A stored colour read as a Color, whichever way the file spelled it - a real Color, or the hex
## string a plain-data list holds.
static func _color_of(stored: Variant) -> Color:
	if stored is Color:
		return stored
	return Color.from_string(str(stored), Color.WHITE)


## One card's panel, and the whole of the drag-to-reorder: it hands its index over when dragged, and
## accepts only a card dragged out of the SAME drawer, so two lists in one Inspector stay separate.
class _CardRow:
	extends PanelContainer

	var _drawer: EventSheetCardListDrawer = null
	var _index: int = 0

	func _init(drawer: EventSheetCardListDrawer, index: int) -> void:
		_drawer = drawer
		_index = index
		mouse_default_cursor_shape = Control.CURSOR_MOVE
		# Every card has the same inset, so a card keeps its place whether or not a band sits behind it.
		var inset: StyleBoxEmpty = StyleBoxEmpty.new()
		inset.content_margin_left = 4.0
		inset.content_margin_right = 4.0
		add_theme_stylebox_override("panel", inset)

	func _gui_input(event: InputEvent) -> void:
		var click: InputEventMouseButton = event as InputEventMouseButton
		if click == null or not click.pressed:
			return
		if click.button_index == MOUSE_BUTTON_LEFT:
			_drawer.select_card(_index, "shift" if click.shift_pressed else ("ctrl" if click.is_command_or_control_pressed() else "click"))
			accept_event()
		elif click.button_index == MOUSE_BUTTON_RIGHT:
			# Like Godot's own lists, a right click on a card outside the selection selects it first, so the
			# menu that opens is about what was clicked.
			if not _drawer.selected_cards().has(_index):
				_drawer.select_card(_index, "click")
			_drawer.open_card_menu(_index, Vector2i(get_screen_position() + click.position))
			accept_event()

	func _get_drag_data(_position: Vector2) -> Variant:
		if not _drawer.editable:
			return null
		var labels: PackedStringArray = _drawer.card_labels()
		var ghost: Label = Label.new()
		ghost.text = "  %s  " % (labels[_index] if _index < labels.size() else EventSheetL10n.translate("card"))
		set_drag_preview(ghost)
		return {EventSheetCardListDrawer.DRAG_KEY: _index, "drawer": _drawer}

	func _can_drop_data(_position: Vector2, data: Variant) -> bool:
		if not (data is Dictionary):
			return false
		return (data as Dictionary).get("drawer") == _drawer and (data as Dictionary).has(EventSheetCardListDrawer.DRAG_KEY)

	func _drop_data(_position: Vector2, data: Variant) -> void:
		_drawer.move_card(int((data as Dictionary)[EventSheetCardListDrawer.DRAG_KEY]), _index)
