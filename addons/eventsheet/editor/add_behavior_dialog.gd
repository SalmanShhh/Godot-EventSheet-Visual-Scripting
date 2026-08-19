@tool
class_name EventSheetAddBehaviorDialog
extends ConfirmationDialog

# Add behavior: one dialog for every pack.
#
# Object bar > right-click an object > Add behavior…, and the head's Behaviors folder "+". The
# shelves come from the packs' own categories, the search reads their names and pitches, and the
# card shows the pack's knobs as fields you can set before it lands. "Where" offers the node
# (always) and writing it into this script (only where the pack says its shape can be).
#
# After adding, the picker under the object lists the behavior's conditions, actions and
# expressions, the head's Behaviors folder shows it, and the Doctor checks the host the pack
# needs. All three are already true of any attached pack - this is the one gesture that gets it
# there.

var _object_label: String = ""
var _packs: Array[Dictionary] = []
var _selected_dir: String = ""
var _category: String = ""
var _search: LineEdit = null
var _shelf_bar: HBoxContainer = null
var _list: VBoxContainer = null
var _detail: VBoxContainer = null
var _properties: VBoxContainer = null
var _where: OptionButton = null
var _fields: Dictionary = {}
var _on_add: Callable = Callable()


func _init() -> void:
	title = "Add behavior"
	ok_button_text = "Add"
	add_child(EventSheetPopupUI.margined(_build_body()))
	confirmed.connect(_on_confirmed)


## `on_add` is called with (pack: Dictionary, values: Dictionary, inline: bool) - the dock does
## the scene write and the undo, because a window has no business touching either.
func configure(on_add: Callable) -> void:
	_on_add = on_add


## Opens for one object. The label is the object the picker and the head will show it under.
func open_for(object_label: String) -> void:
	_object_label = object_label
	title = "Add behavior to %s" % object_label if not object_label.is_empty() else "Add behavior"
	_packs = EventSheetPackCatalog.packs()
	_category = ""
	_selected_dir = ""
	if _search != null:
		_search.text = ""
	_rebuild_shelves()
	_rebuild_list()
	popup_centered(Vector2i(760, 520))


func _build_body() -> Control:
	var page: VBoxContainer = EventSheetPopupUI.form_box()
	page.custom_minimum_size = Vector2(720.0, 440.0)
	_shelf_bar = HBoxContainer.new()
	_shelf_bar.add_theme_constant_override("separation", 4)
	# A project with ninety packs has more shelves than fit: the bar scrolls sideways rather than
	# widening the dialog to the sum of every category name.
	var shelf_scroll: ScrollContainer = ScrollContainer.new()
	shelf_scroll.custom_minimum_size = Vector2(700.0, 34.0)
	shelf_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	shelf_scroll.add_child(_shelf_bar)
	page.add_child(shelf_scroll)
	_search = LineEdit.new()
	_search.placeholder_text = "search"
	_search.tooltip_text = "Reads every pack's name, its one-line pitch and its folder, so \"jump\" finds the platformer pack."
	_search.text_changed.connect(func(_text: String) -> void: _rebuild_list())
	page.add_child(_search)
	var band: HBoxContainer = HBoxContainer.new()
	band.add_theme_constant_override("separation", 10)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	var list_scroll: ScrollContainer = ScrollContainer.new()
	list_scroll.custom_minimum_size = Vector2(280.0, 300.0)
	list_scroll.add_child(_list)
	band.add_child(EventSheetPopupUI.panel_section(list_scroll))
	_detail = EventSheetPopupUI.form_box()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_properties = VBoxContainer.new()
	_properties.add_theme_constant_override("separation", 4)
	_detail.add_child(EventSheetPopupUI.titled_card("Properties", _properties))
	_where = OptionButton.new()
	_where.add_item("as a behavior node", 0)
	_where.add_item("written into this script", 1)
	_where.tooltip_text = "A behavior node is how every pack works: a node carrying the pack's script under the object. Writing it into this script puts the pack's knobs in the file instead, and only packs that say their shape can be written in offer it."
	_detail.add_child(EventSheetPopupUI.form_row("Where", _where))
	band.add_child(_detail)
	page.add_child(band)
	return page


func _rebuild_shelves() -> void:
	for child: Node in _shelf_bar.get_children():
		child.queue_free()
	var all_button: Button = Button.new()
	all_button.text = "All"
	all_button.toggle_mode = true
	all_button.button_pressed = _category.is_empty()
	all_button.pressed.connect(func() -> void: _select_category(""))
	_shelf_bar.add_child(all_button)
	for shelf: String in EventSheetPackCatalog.categories(_packs):
		var button: Button = Button.new()
		button.text = shelf
		button.toggle_mode = true
		button.button_pressed = _category == shelf
		button.pressed.connect(func() -> void: _select_category(shelf))
		_shelf_bar.add_child(button)


func _select_category(shelf: String) -> void:
	_category = shelf
	_rebuild_shelves()
	_rebuild_list()


func _rebuild_list() -> void:
	if _list == null:
		return
	for child: Node in _list.get_children():
		child.queue_free()
	var shown: Array[Dictionary] = EventSheetPackCatalog.filtered(
		_packs, _category, _search.text if _search != null else "")
	for pack: Dictionary in shown:
		_list.add_child(_build_card(pack))
	if shown.is_empty():
		_list.add_child(EventSheetPopupUI.hint_label("No pack here matches that.", 260.0))
	if not shown.is_empty() and _selected_dir.is_empty():
		_select_pack(shown[0])


func _build_card(pack: Dictionary) -> Control:
	var button: Button = Button.new()
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.toggle_mode = true
	button.button_pressed = _selected_dir == str(pack.get("dir", ""))
	var pitch: String = str(pack.get("pitch", "")).strip_edges()
	button.text = str(pack.get("name", "")) if pitch.is_empty() else "%s  -  %s" % [str(pack.get("name", "")), pitch]
	button.tooltip_text = pitch
	if not bool(pack.get("enabled", true)):
		button.disabled = true
		button.tooltip_text = "This pack is switched off in the Addon manager."
	button.pressed.connect(func() -> void: _select_pack(pack))
	return button


func _select_pack(pack: Dictionary) -> void:
	_selected_dir = str(pack.get("dir", ""))
	_fields.clear()
	for child: Node in _properties.get_children():
		child.queue_free()
	var knobs: Array[Dictionary] = EventSheetAddBehavior.exported_properties(str(pack.get("path", "")))
	for knob: Dictionary in knobs:
		var edit: LineEdit = LineEdit.new()
		edit.text = str(knob.get("default", ""))
		_properties.add_child(EventSheetPopupUI.form_row(str(knob.get("name", "")), edit))
		_fields[str(knob.get("id", ""))] = edit
	if knobs.is_empty():
		_properties.add_child(EventSheetPopupUI.hint_label("This pack has no knobs to set.", 320.0))
	if _where != null:
		var inline_capable: bool = bool(pack.get("inline_capable", false))
		_where.set_item_disabled(_where.get_item_index(1), not inline_capable)
		if not inline_capable and _where.get_selected_id() == 1:
			_where.select(_where.get_item_index(0))
	_rebuild_list_selection()


func _rebuild_list_selection() -> void:
	for child: Node in _list.get_children():
		if child is Button:
			(child as Button).set_pressed_no_signal((child as Button).text.begins_with(_selected_name()))


func _selected_name() -> String:
	for pack: Dictionary in _packs:
		if str(pack.get("dir", "")) == _selected_dir:
			return str(pack.get("name", ""))
	return ""


## The pack the dialog is on, or an empty Dictionary. Public so the dock (and a test) can ask.
func selected_pack() -> Dictionary:
	for pack: Dictionary in _packs:
		if str(pack.get("dir", "")) == _selected_dir:
			return pack
	return {}


## The values typed into the property fields, id -> text.
func property_values() -> Dictionary:
	var out: Dictionary = {}
	for key: Variant in _fields.keys():
		var edit: Variant = _fields[key]
		if edit is LineEdit:
			out[str(key)] = (edit as LineEdit).text
	return out


func _on_confirmed() -> void:
	var pack: Dictionary = selected_pack()
	if pack.is_empty() or not _on_add.is_valid():
		return
	_on_add.call(pack, property_values(), _where != null and _where.get_selected_id() == 1, _object_label)
