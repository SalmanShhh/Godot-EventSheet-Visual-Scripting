@tool
class_name EventSheetAddBehaviorDialog
extends ConfirmationDialog

# Add behavior: one window for every pack.
#
# Object bar > right-click an object > Add behavior…, and the head's Behaviors folder "+". The search
# and the shelves (the packs' own categories) share one row; the list reads each pack's name and
# pitch; the Properties card shows the pack's knobs the way the Inspector will - a number you can
# scrub, a tick for a true/false, under the names exactly as the pack wrote them. "Where" offers the
# node (always) and writing it into this script (only where the pack says its shape can be). The help
# strip says what the focused knob is for, from the pack's own doc comment, and where it will land.
#
# After adding, the picker under the object lists the behavior's conditions, actions and
# expressions, the head's Behaviors folder shows it, and the Doctor checks the host the pack needs.

var _object_label: String = ""
## The node the behaviour is being added to, when the scene is open - what the cards are measured against.
var _host: Node = null
var _packs: Array[Dictionary] = []
var _selected_dir: String = ""
var _category: String = ""
var _search: LineEdit = null
var _shelf_bar: HBoxContainer = null
var _list: VBoxContainer = null
var _properties: VBoxContainer = null
var _where: OptionButton = null
var _strip: EventSheetPopupUI.HelpStrip = null
var _fields: Dictionary = {}
var _on_add: Callable = Callable()
## Each listed pack's script text, read once per opening: the list is rebuilt on every keystroke of
## the search, and a big project has well over a hundred packs.
var _pack_sources: Dictionary = {}


func _init() -> void:
	title = EventSheetL10n.translate("Add behavior")
	ok_button_text = EventSheetL10n.translate("Add")
	add_child(EventSheetPopupUI.margined(_build_body()))
	confirmed.connect(_on_confirmed)


## `on_add` is called with (pack: Dictionary, values: Dictionary, inline: bool) - the dock does
## the scene write and the undo, because a window has no business touching either.
func configure(on_add: Callable) -> void:
	_on_add = on_add


## Opens for one object. The label is the object the picker and the head will show it under; `host` is
## its node in the open scene, when there is one, so a behaviour made for another kind of object is greyed.
func open_for(object_label: String, host: Node = null) -> void:
	_object_label = object_label
	_host = host
	title = EventSheetL10n.translate("Add behavior to {object}").replace("{object}", object_label) \
		if not object_label.is_empty() else EventSheetL10n.translate("Add behavior")
	_packs = EventSheetPackCatalog.packs()
	_pack_sources.clear()
	_category = ""
	_selected_dir = ""
	if _search != null:
		_search.text = ""
	_rebuild_shelves()
	_rebuild_list()
	popup_centered(Vector2i(int(EventSheetPalette.scaled_f(780.0)), int(EventSheetPalette.scaled_f(560.0))))


func _build_body() -> Control:
	var page: VBoxContainer = EventSheetPopupUI.form_box()
	page.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(720.0), EventSheetPalette.scaled_f(440.0))
	# The search and the shelves share one row: the search keeps its width, the shelves take the rest
	# and scroll sideways when a project has more categories than fit.
	var top: HBoxContainer = HBoxContainer.new()
	_search = LineEdit.new()
	_search.placeholder_text = EventSheetL10n.translate("search")
	_search.right_icon = EventSheetPopupUI._editor_icon("Search")
	_search.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(200.0), 0.0)
	_search.text_changed.connect(func(_text: String) -> void: _rebuild_list())
	top.add_child(_search)
	_shelf_bar = HBoxContainer.new()
	_shelf_bar.add_theme_constant_override("separation", int(EventSheetPalette.scaled_f(4.0)))
	var shelf_scroll: ScrollContainer = ScrollContainer.new()
	shelf_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shelf_scroll.custom_minimum_size = Vector2(0.0, EventSheetPalette.scaled_f(34.0))
	shelf_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	shelf_scroll.add_child(_shelf_bar)
	top.add_child(shelf_scroll)
	page.add_child(top)
	var band: HBoxContainer = HBoxContainer.new()
	band.add_theme_constant_override("separation", int(EventSheetPalette.scaled_f(10.0)))
	band.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", int(EventSheetPalette.scaled_f(4.0)))
	var list_scroll: ScrollContainer = ScrollContainer.new()
	list_scroll.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(280.0), EventSheetPalette.scaled_f(300.0))
	list_scroll.add_child(_list)
	band.add_child(EventSheetPopupUI.panel_section(list_scroll))
	var detail: VBoxContainer = EventSheetPopupUI.form_box()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_properties = VBoxContainer.new()
	_properties.add_theme_constant_override("separation", int(EventSheetPalette.scaled_f(4.0)))
	var properties_scroll: ScrollContainer = ScrollContainer.new()
	properties_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	properties_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_properties.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	properties_scroll.add_child(_properties)
	var properties_card: Control = EventSheetPopupUI.titled_card(EventSheetL10n.translate("Properties"), properties_scroll)
	properties_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_child(properties_card)
	_where = EventSheetPopupUI.described_option()
	EventSheetPopupUI.add_described_item(_where, EventSheetL10n.translate("as a behavior node"),
		EventSheetL10n.translate("A node carrying the pack's script under the object - how every pack works."), 0)
	EventSheetPopupUI.add_described_item(_where, EventSheetL10n.translate("written into this script"),
		EventSheetL10n.translate("The pack's knobs become this script's own variables. Only packs that say their shape can be written in offer it."), 1)
	_where.item_selected.connect(func(_index: int) -> void: _refresh_reading())
	detail.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("Where"), _where))
	band.add_child(detail)
	page.add_child(band)
	_strip = EventSheetPopupUI.help_strip("", "", "", "", EventSheetPalette.scaled_f(600.0))
	page.add_child(_strip)
	_strip.follow(_search, EventSheetL10n.translate("search"),
		EventSheetL10n.translate("Reads every pack's name, its one-line pitch and its folder, so \"jump\" finds the platformer pack."))
	_strip.follow_option(_where, func(index: int) -> Dictionary:
		return {"heading": EventSheetL10n.translate("Where"), "body": _where.get_item_tooltip(index)})
	return page


func _rebuild_shelves() -> void:
	for child: Node in _shelf_bar.get_children():
		child.queue_free()
	var all_button: Button = Button.new()
	all_button.text = EventSheetL10n.translate("All")
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
	# Your own behaviours lead, under their own heading, ahead of the packs that ship. What each pack
	# is refused for is worked out once per rebuild - one walk of the Autoload list for all of them.
	var autoloads: Dictionary = autoload_bases()
	var refusals: Dictionary = {}
	var yours: Array[Dictionary] = []
	var shipped: Array[Dictionary] = []
	for pack: Dictionary in shown:
		var source: String = _source_of(pack)
		refusals[str(pack.get("dir", ""))] = refusal(pack, _host, autoloads, source)
		(yours if EventSheetBehaviourAddonScaffold.is_yours(source) else shipped).append(pack)
	if not yours.is_empty():
		_list.add_child(EventSheetPopupUI.small_caps_label(EventSheetL10n.translate("Your behaviours")))
		for pack: Dictionary in yours:
			_list.add_child(_build_card(pack, refusals[str(pack.get("dir", ""))]))
		if not shipped.is_empty():
			_list.add_child(EventSheetPopupUI.small_caps_label(EventSheetL10n.translate("Packs")))
	for pack: Dictionary in shipped:
		_list.add_child(_build_card(pack, refusals[str(pack.get("dir", ""))]))
	if shown.is_empty():
		_list.add_child(EventSheetPopupUI.hint_label(EventSheetL10n.translate("No pack here matches that."), 260.0))
	# The card on the right always belongs to a pack the list shows: a search that hides the chosen one
	# moves the choice to the first match.
	var still_shown: bool = false
	var first_addable: Dictionary = {}
	for pack: Dictionary in yours + shipped:
		still_shown = still_shown or str(pack.get("dir", "")) == _selected_dir
		if first_addable.is_empty() and str(refusals[str(pack.get("dir", ""))]).is_empty():
			first_addable = pack
	if not first_addable.is_empty() and not still_shown:
		_select_pack(first_addable)


func _source_of(pack: Dictionary) -> String:
	var path: String = str(pack.get("path", ""))
	if not _pack_sources.has(path):
		_pack_sources[path] = FileAccess.get_file_as_string(path) if not path.is_empty() else ""
	return _pack_sources[path]


func _build_card(pack: Dictionary, why_not: String) -> Control:
	var button: Button = Button.new()
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.toggle_mode = true
	# The card knows WHICH pack it is by folder, so the selection highlight never has to guess it
	# from the label (a name that begins another pack's name would light up both).
	button.set_meta("pack_dir", str(pack.get("dir", "")))
	button.button_pressed = _selected_dir == str(pack.get("dir", ""))
	var pitch: String = str(pack.get("pitch", "")).strip_edges()
	button.text = str(pack.get("name", "")) if pitch.is_empty() else "%s  -  %s" % [str(pack.get("name", "")), pitch]
	button.tooltip_text = pitch
	button.pressed.connect(func() -> void: _select_pack(pack))
	if not why_not.is_empty():
		button.disabled = true
		button.tooltip_text = why_not
	return button


## Why `pack` cannot be added to `host`, or "" when it can: it is a global (turned on in Godot's
## Autoload list, never added to an object), or it was made for another kind of object. A caller
## asking for many packs passes `autoloads` (from `autoload_bases`) and the pack's `source` it already
## read, so neither the project settings nor the file are read again per pack.
static func refusal(pack: Dictionary, host: Node, autoloads: Variant = null, source: Variant = null) -> String:
	var path: String = str(pack.get("path", ""))
	var globals: Dictionary = autoloads if autoloads is Dictionary else autoload_bases()
	if globals.has(path.get_basename()):
		return EventSheetL10n.translate("%s is a global: it is turned on in Project Settings > Globals > Autoload, not added to an object.") % str(pack.get("name", ""))
	if host == null:
		return ""
	var text: String = str(source) if source is String else FileAccess.get_file_as_string(path)
	var needs: String = EventSheetBehaviourAddonScaffold.host_class_of(text)
	if needs.is_empty():
		needs = EventSheetAddBehavior.requirement_in(text)
	if needs.is_empty() or not ClassDB.class_exists(needs) or host.is_class(needs):
		return ""
	return EventSheetL10n.translate("Made for a %s - %s is a %s.") % [needs, host.name, host.get_class()]


## Every script Godot's Autoload list turns on, by path without its extension - one walk of the
## project settings.
static func autoload_bases() -> Dictionary:
	var bases: Dictionary = {}
	for property_info: Dictionary in ProjectSettings.get_property_list():
		var setting: String = str(property_info.get("name", ""))
		if setting.begins_with("autoload/"):
			bases[str(ProjectSettings.get_setting(setting, "")).trim_prefix("*").get_basename()] = true
	return bases


## One knob as the Inspector would show it: a tick for a bool, a number field (its label scrubs it)
## for an int or a float, a text field for anything else - all seeded with the pack's default.
static func knob_field(knob: Dictionary) -> Control:
	var default_text: String = str(knob.get("default", ""))
	match str(knob.get("type", "")):
		"bool":
			var tick: CheckBox = CheckBox.new()
			tick.button_pressed = default_text == "true"
			return tick
		"int", "float":
			var number: SpinBox = SpinBox.new()
			number.allow_greater = true
			number.allow_lesser = true
			number.step = 1.0 if str(knob.get("type", "")) == "int" else 0.0
			number.value = float(default_text) if default_text.is_valid_float() else 0.0
			return number
	var edit: LineEdit = LineEdit.new()
	edit.text = default_text
	return edit


## A knob field's value as the text the pack's property is set from.
static func knob_text(field: Control) -> String:
	if field is CheckBox:
		return "true" if (field as CheckBox).button_pressed else "false"
	if field is SpinBox:
		var number: SpinBox = field as SpinBox
		return str(int(number.value)) if number.step >= 1.0 else str(number.value)
	return (field as LineEdit).text if field is LineEdit else ""


func _select_pack(pack: Dictionary) -> void:
	_selected_dir = str(pack.get("dir", ""))
	_fields.clear()
	for child: Node in _properties.get_children():
		child.queue_free()
	_strip.followed.clear()
	_strip.follow(_search, EventSheetL10n.translate("search"),
		EventSheetL10n.translate("Reads every pack's name, its one-line pitch and its folder, so \"jump\" finds the platformer pack."))
	var knobs: Array[Dictionary] = EventSheetAddBehavior.exported_properties(str(pack.get("path", "")))
	for knob: Dictionary in knobs:
		var field: Control = knob_field(knob)
		_properties.add_child(EventSheetPopupUI.form_row(str(knob.get("name", "")), field))
		_fields[str(knob.get("id", ""))] = field
		var said: String = str(knob.get("description", "")).strip_edges()
		_strip.follow(field, str(knob.get("name", "")), said if not said.is_empty() \
			else EventSheetL10n.translate("{type}, starting at {value}.").replace("{type}", str(knob.get("type", ""))).replace(
				"{value}", str(knob.get("default", ""))))
	if knobs.is_empty():
		_properties.add_child(EventSheetPopupUI.hint_label(EventSheetL10n.translate("This pack has no knobs to set."), 320.0))
	if _where != null:
		var inline_capable: bool = bool(pack.get("inline_capable", false))
		_where.set_item_disabled(_where.get_item_index(1), not inline_capable)
		if not inline_capable and _where.get_selected_id() == 1:
			_where.select(_where.get_item_index(0))
	_strip.describe(str(pack.get("name", "")), str(pack.get("pitch", "")))
	_refresh_reading()
	_rebuild_list_selection()


## Where the pack will land, said in the strip: under the object as a node, or into this script.
func _refresh_reading() -> void:
	var pack: Dictionary = selected_pack()
	if pack.is_empty() or _strip == null:
		return
	var script_file: String = str(pack.get("path", "")).get_file()
	var landing: String = "%s ▸ %s  %s" % [_object_label, str(pack.get("name", "")), script_file] \
		if _where.get_selected_id() == 0 else "%s  %s" % [_object_label, EventSheetL10n.translate("written into this script")]
	_strip.set_reading("", landing)


func _rebuild_list_selection() -> void:
	for child: Node in _list.get_children():
		if child is Button:
			(child as Button).set_pressed_no_signal(str(child.get_meta("pack_dir", "")) == _selected_dir)


## The pack the dialog is on, or an empty Dictionary. Public so the dock (and a test) can ask.
func selected_pack() -> Dictionary:
	for pack: Dictionary in _packs:
		if str(pack.get("dir", "")) == _selected_dir:
			return pack
	return {}


## The values set in the property fields, id -> text.
func property_values() -> Dictionary:
	var out: Dictionary = {}
	for key: Variant in _fields.keys():
		out[str(key)] = knob_text(_fields[key] as Control)
	return out


func _on_confirmed() -> void:
	var pack: Dictionary = selected_pack()
	if pack.is_empty() or not _on_add.is_valid():
		return
	_on_add.call(pack, property_values(), _where != null and _where.get_selected_id() == 1, _object_label)
