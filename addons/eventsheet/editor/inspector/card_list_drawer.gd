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

## The drag payload's own key. Cards only accept a drag that came from the SAME drawer instance, so
## two card lists open in one Inspector cannot swallow each other's rows.
const DRAG_KEY: String = "eventsheet_card_index"

## The marker parsers (`parse_unit_spec`, `parse_toggle_spec`), reached BY PATH and called as
## statics. A card field names its editor with the SAME words an `eventsheet:` export marker uses,
## so the parsing must be the one already shipped rather than a second copy - and by path rather
## than by class name because that file names this one, and two files naming each other is a cycle.
const ATTRIBUTE_DRAWERS_PATH: String = "res://addons/eventsheet/editor/attribute_drawers.gd"

static var _drawers_script: Script = null


## The attribute-drawers script, loaded on first use and cached for the session.
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
var _list: VBoxContainer = null
var _head_label: Label = null
var _add_button: Button = null
var _add_popup: PopupPanel = null
var _add_filter: LineEdit = null
var _add_tree: Tree = null


## `spec` is the parsed marker - {kind_key, schema, stripe_key} - and may carry `schema_dict` instead
## of a registered schema name, which is how an owner with its own vocabulary (the Drawing Prefab)
## hands its kinds straight over.
func _init(spec: Dictionary = {}) -> void:
	for key: Variant in spec:
		_spec[str(key)] = spec[key]
	_schema = EventSheetCardSchemas.schema_for(_spec)
	add_theme_constant_override("separation", 4)
	_build_chrome()
	_rebuild()


## The schema this drawer resolved - the Drawing Prefab's own, or the one registered under the
## marker's name.
func schema() -> Dictionary:
	return _schema


func set_value(cards: Array) -> void:
	_cards = []
	for card: Variant in cards:
		if card is Dictionary:
			_cards.append((card as Dictionary).duplicate(true))
	_unfolded.clear()
	_rebuild()


func get_value() -> Array:
	return _cards.duplicate(true)


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


## Add a card of one kind at the end, folded.
func add_card(kind: String) -> void:
	var entry: Dictionary = EventSheetCardSchemas.kind_entry(_schema, kind)
	if entry.is_empty():
		return
	_cards.append(EventSheetCardSchemas.new_card(_spec, entry))
	_commit()


## Move the card at `from` to `to` - what a finished drag, and "Move to top", write.
func move_card(from: int, to: int) -> void:
	_cards = EventSheetCardSchemas.move_card(_cards, from, to)
	_commit()


func duplicate_card(index: int) -> void:
	_cards = EventSheetCardSchemas.duplicate_card(_cards, index)
	_commit()


func remove_card(index: int) -> void:
	_cards = EventSheetCardSchemas.remove_card(_cards, index)
	_commit()


## Switch one card on or off. Absent means on, so switching a card back on leaves the file exactly
## as it was before it was ever switched off.
func set_card_enabled(index: int, enabled: bool) -> void:
	if index < 0 or index >= _cards.size():
		return
	_cards[index] = EventSheetCardSchemas.set_card_enabled(_schema, _cards[index], enabled)
	_commit()


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
	return EventSheetCardSchemas.kind_entry(_schema, str(card.get(str(_spec.get("kind_key", "kind")), "")))


# ── The chrome around the list: the head line, the list itself, the Add dropdown ────────────────


func _build_chrome() -> void:
	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	_head_label = Label.new()
	_head_label.add_theme_font_size_override("font_size", EventSheetPalette.scaled(10))
	_head_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_head_label)
	head.add_child(_small_button("Copy all", "Copy every card to the clipboard.", _on_copy_all))
	head.add_child(_small_button("Paste all", "Replace the list with the cards on the clipboard.", _on_paste_all))
	add_child(head)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 3)
	add_child(_list)
	_add_button = Button.new()
	_add_button.text = "Add"
	_add_button.tooltip_text = "Add a card. Type to search; the list is grouped the way its pack groups it."
	_add_button.pressed.connect(_on_add_pressed)
	add_child(_add_button)


func _small_button(text: String, tooltip: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.tooltip_text = tooltip
	button.add_theme_font_size_override("font_size", EventSheetPalette.scaled(10))
	button.pressed.connect(action)
	return button


func _on_copy_all() -> void:
	DisplayServer.clipboard_set(EventSheetCardSchemas.cards_to_text(_cards))


func _on_paste_all() -> void:
	var pasted: Array = EventSheetCardSchemas.cards_from_text(DisplayServer.clipboard_get())
	if pasted.is_empty():
		return
	_cards = pasted
	_unfolded.clear()
	_commit()


## The Add dropdown: a field you type into over a tree grouped by category - the engine's own "search
## a long list" shape, so there is nothing new to learn.
func _on_add_pressed() -> void:
	if _add_popup == null:
		_add_popup = PopupPanel.new()
		var box: VBoxContainer = VBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		_add_filter = LineEdit.new()
		_add_filter.placeholder_text = "Search"
		_add_filter.clear_button_enabled = true
		_add_filter.custom_minimum_size = Vector2(EventSheetPalette.scaled(220), 0.0)
		_add_filter.text_changed.connect(func(_text: String) -> void: _fill_add_tree())
		box.add_child(_add_filter)
		_add_tree = Tree.new()
		_add_tree.hide_root = true
		_add_tree.custom_minimum_size = Vector2(EventSheetPalette.scaled(220), EventSheetPalette.scaled(220))
		_add_tree.item_activated.connect(_on_add_chosen)
		box.add_child(_add_tree)
		_add_popup.add_child(box)
		add_child(_add_popup)
	_add_filter.text = ""
	_fill_add_tree()
	var below: Vector2i = Vector2i(_add_button.get_screen_position()) + Vector2i(0, int(_add_button.size.y))
	_add_popup.popup(Rect2i(below, Vector2i.ZERO))
	_add_filter.grab_focus()


func _fill_add_tree() -> void:
	_add_tree.clear()
	var root: TreeItem = _add_tree.create_item()
	var needle: String = _add_filter.text.strip_edges().to_lower()
	for group: Variant in EventSheetCardSchemas.kinds_by_category(_schema):
		var group_dict: Dictionary = group as Dictionary
		var matching: Array = []
		for entry: Variant in group_dict.get("kinds", []):
			var label: String = str((entry as Dictionary).get("label", (entry as Dictionary).get("kind", "")))
			if needle.is_empty() or label.to_lower().contains(needle) or str((entry as Dictionary).get("kind", "")).to_lower().contains(needle):
				matching.append(entry)
		if matching.is_empty():
			continue
		var category: String = str(group_dict.get("category", ""))
		var parent: TreeItem = _add_tree.create_item(root)
		parent.set_text(0, category.capitalize() if not category.is_empty() else "Other")
		parent.set_selectable(0, false)
		parent.set_custom_color(0, EventSheetCardSchemas.stripe_color(_schema, category))
		for entry: Variant in matching:
			var leaf: TreeItem = _add_tree.create_item(parent)
			leaf.set_text(0, str((entry as Dictionary).get("label", (entry as Dictionary).get("kind", ""))))
			leaf.set_tooltip_text(0, str((entry as Dictionary).get("help", "")))
			leaf.set_metadata(0, str((entry as Dictionary).get("kind", "")))


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
	_head_label.text = "%d card%s" % [_cards.size(), "" if _cards.size() == 1 else "s"]
	_head_label.modulate = Color(1.0, 1.0, 1.0, 0.7)
	_add_button.disabled = not editable or EventSheetCardSchemas.kinds_of(_schema).is_empty()
	if _cards.is_empty():
		var empty: Label = Label.new()
		empty.text = "Nothing here yet. Add one."
		empty.add_theme_font_size_override("font_size", EventSheetPalette.scaled(11))
		empty.modulate = Color(1.0, 1.0, 1.0, 0.55)
		_list.add_child(empty)
		return
	for index: int in range(_cards.size()):
		_list.add_child(_build_card(index))


func _build_card(index: int) -> Control:
	var card: Dictionary = _cards[index]
	var entry: Dictionary = _entry_for(card)
	var enabled: bool = EventSheetCardSchemas.card_enabled(_schema, card)
	var stripe: Color = EventSheetCardSchemas.stripe_color(_schema, EventSheetCardSchemas.card_category(_spec, entry, card))
	var panel: _CardRow = _CardRow.new(self, index)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.04)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(5)
	style.border_width_left = EventSheetPalette.scaled(3)
	style.border_color = stripe if enabled else Color(stripe.r, stripe.g, stripe.b, 0.35)
	panel.add_theme_stylebox_override("panel", style)
	var body: VBoxContainer = VBoxContainer.new()
	body.add_theme_constant_override("separation", 3)
	panel.add_child(body)
	body.add_child(_build_header(index, card, entry, enabled))
	if bool(_unfolded.get(index, false)):
		body.add_child(_build_body(index, card, entry))
	return panel


func _build_header(index: int, card: Dictionary, entry: Dictionary, enabled: bool) -> Control:
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 4)
	var handle: Label = Label.new()
	handle.text = "⋮⋮"
	handle.tooltip_text = "Drag to reorder."
	handle.modulate = Color(1.0, 1.0, 1.0, 0.45)
	handle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(handle)
	var fold: Button = Button.new()
	fold.flat = true
	fold.text = "▾" if bool(_unfolded.get(index, false)) else "▸"
	fold.tooltip_text = "Open this card."
	fold.pressed.connect(func() -> void:
		_unfolded[index] = not bool(_unfolded.get(index, false))
		_rebuild())
	header.add_child(fold)
	if not EventSheetCardSchemas.enabled_key(_schema).is_empty():
		var box: CheckBox = CheckBox.new()
		box.button_pressed = enabled
		box.disabled = not editable
		box.tooltip_text = "Untick to skip this card."
		box.toggled.connect(func(pressed: bool) -> void: set_card_enabled(index, pressed))
		header.add_child(box)
	var title: Label = Label.new()
	title.text = EventSheetCardSchemas.card_label(_schema, _spec, entry, card)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.modulate = Color(1.0, 1.0, 1.0, 1.0 if enabled else 0.5)
	header.add_child(title)
	var badge_text: String = EventSheetCardSchemas.card_badge(entry, card)
	if not badge_text.is_empty():
		var badge: Label = Label.new()
		badge.text = badge_text
		badge.add_theme_font_size_override("font_size", EventSheetPalette.scaled(10))
		badge.modulate = Color(1.0, 1.0, 1.0, 0.6)
		header.add_child(badge)
	header.add_child(_build_menu(index))
	return header


## The card's menu. "Paste over" replaces this card with the clipboard's first; "Move to top" is the
## reorder a long list actually asks for, and the drag handle is the rest.
func _build_menu(index: int) -> Control:
	var menu: MenuButton = MenuButton.new()
	menu.text = "⋯"
	menu.flat = true
	menu.tooltip_text = "More for this card."
	menu.disabled = not editable
	var popup: PopupMenu = menu.get_popup()
	for item: String in ["Duplicate", "Copy", "Paste over", "Move to top", "Move up", "Move down", "Remove"]:
		popup.add_item(item)
	popup.id_pressed.connect(func(id: int) -> void: _on_menu(index, id))
	return menu


func _on_menu(index: int, id: int) -> void:
	match id:
		0:
			duplicate_card(index)
		1:
			DisplayServer.clipboard_set(EventSheetCardSchemas.cards_to_text([_cards[index]] if index < _cards.size() else []))
		2:
			paste_over(index, DisplayServer.clipboard_get())
		3:
			move_card(index, 0)
		4:
			move_card(index, index - 1)
		5:
			move_card(index, index + 1)
		6:
			remove_card(index)


## The unfolded card: what this kind explains, then its own fields, then what the running game is
## writing back. Per-card hooks are whatever the schema declared - a card with none shows none.
func _build_body(index: int, card: Dictionary, entry: Dictionary) -> Control:
	var body: VBoxContainer = VBoxContainer.new()
	body.add_theme_constant_override("separation", 4)
	var help: String = str(entry.get("help", "")).strip_edges()
	if not help.is_empty():
		var info: Label = Label.new()
		info.text = help
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_theme_font_size_override("font_size", EventSheetPalette.scaled(10))
		info.modulate = Color(1.0, 1.0, 1.0, 0.6)
		body.add_child(info)
	var fields: VBoxContainer = VBoxContainer.new()
	fields.add_theme_constant_override("separation", 2)
	for field: Variant in EventSheetCardSchemas.fields_of(entry):
		if not (field is Dictionary) or not EventSheetCardSchemas.field_visible(field as Dictionary, card):
			continue
		fields.add_child(_build_field(index, card, field as Dictionary))
	body.add_child(fields)
	for live: Variant in EventSheetCardSchemas.live_of(entry):
		if not (live is Dictionary):
			continue
		var readout: Label = Label.new()
		readout.text = "%s  %s" % [str((live as Dictionary).get("label", "")), str(card.get(str((live as Dictionary).get("key", "")), ""))]
		readout.add_theme_font_size_override("font_size", EventSheetPalette.scaled(10))
		readout.modulate = Color(1.0, 1.0, 1.0, 0.4)
		readout.tooltip_text = "Written by the game while it runs."
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


## One field: its title, its editor, and - when the field is linked to another - the "=" toggle that
## writes both keys at once while it is lit.
func _build_field(index: int, card: Dictionary, field: Dictionary) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	var label: Label = Label.new()
	label.text = str(field.get("label", field.get("key", "")))
	label.add_theme_font_size_override("font_size", EventSheetPalette.scaled(10))
	label.custom_minimum_size = Vector2(EventSheetPalette.scaled(84), 0.0)
	label.modulate = Color(1.0, 1.0, 1.0, 0.75)
	row.add_child(label)
	var linked: String = str(field.get("link", ""))
	var link_toggle: CheckButton = null
	if not linked.is_empty():
		link_toggle = CheckButton.new()
		link_toggle.text = "="
		link_toggle.tooltip_text = "While this is on, %s follows this field." % linked
		link_toggle.disabled = not editable
	var write: Callable = func(value: Variant) -> void:
		var written: String = str(field.get("key", ""))
		_write_field(index, written, value)
		if link_toggle != null and link_toggle.button_pressed and not linked.is_empty():
			_write_field(index, linked, value)
		value_changed.emit(get_value())
		# Changing a card's KIND changes which fields it has, so the card is redrawn - deferred,
		# because the control that just emitted is still finishing its own signal.
		if written == str(_spec.get("kind_key", "kind")):
			_rebuild.call_deferred()
	var editor: Control = _build_field_editor(card, field, write)
	editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(editor)
	if link_toggle != null:
		row.add_child(link_toggle)
	return row


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


## The editor for one field, chosen by the field's `drawer` word. The words are the SAME ones the
## `eventsheet:` markers use, so a schema names a drawer the way an export does, and the widgets are
## the shipped ones rather than second copies.
func _build_field_editor(card: Dictionary, field: Dictionary, write: Callable) -> Control:
	var key: String = str(field.get("key", ""))
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
			var options: PackedStringArray = tail.split(",", false)
			var current: String = str(card.get(key, ""))
			for option_index: int in range(options.size()):
				choice.add_item(options[option_index])
				if options[option_index] == current:
					choice.select(option_index)
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
			var unit_spec: Dictionary = attribute_drawers().call("parse_unit_spec", tail)
			var unit_field: EventSheetDrawerWidgets.DrawerUnitField = EventSheetDrawerWidgets.DrawerUnitField.new(
				unit_spec.get("units", PackedStringArray(["px"])), str(unit_spec.get("store", "")))
			unit_field.set_value(float(card.get(key, 0.0)))
			unit_field.set_editable(editable)
			unit_field.value_changed.connect(func(value: float) -> void: write.call(value))
			return unit_field
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
			return _number_field(card, key, write, 1.0)
	return _number_field(card, key, write, 0.1)


func _number_field(card: Dictionary, key: String, write: Callable, step: float) -> Control:
	var spin: SpinBox = SpinBox.new()
	spin.allow_greater = true
	spin.allow_lesser = true
	spin.step = step
	spin.editable = editable
	spin.value = float(card.get(key, 0.0))
	spin.value_changed.connect(func(value: float) -> void: write.call(value))
	return spin


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
		placeholder.text = current.resource_path if current != null else "(none)"
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

	func _get_drag_data(_position: Vector2) -> Variant:
		if not _drawer.editable:
			return null
		var labels: PackedStringArray = _drawer.card_labels()
		var ghost: Label = Label.new()
		ghost.text = "  %s  " % (labels[_index] if _index < labels.size() else "card")
		set_drag_preview(ghost)
		return {EventSheetCardListDrawer.DRAG_KEY: _index, "drawer": _drawer}

	func _can_drop_data(_position: Vector2, data: Variant) -> bool:
		if not (data is Dictionary):
			return false
		return (data as Dictionary).get("drawer") == _drawer and (data as Dictionary).has(EventSheetCardListDrawer.DRAG_KEY)

	func _drop_data(_position: Vector2, data: Variant) -> void:
		_drawer.move_card(int((data as Dictionary)[EventSheetCardListDrawer.DRAG_KEY]), _index)
