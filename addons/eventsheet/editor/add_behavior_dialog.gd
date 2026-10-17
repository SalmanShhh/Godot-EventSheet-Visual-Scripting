@tool
class_name EventSheetAddBehaviorDialog
extends ConfirmationDialog

# Add behavior: one window for every pack.
#
# Object bar > right-click an object > Add behavior…, and the head's Behaviors folder "+". Under the
# search the packs sit on shelves of tiles - the project's own behaviours first, then one shelf per
# kind of object the packs work on - each tile its icon, its name and that kind. One made for another
# kind of object is greyed, with the reason on hover. A click shows the pack's knobs, a double-click
# adds it straight away. The Properties card shows the pack's knobs the way the Inspector will - a
# number you can scrub, a tick for a true/false, under the names exactly as the pack wrote them. "Where" offers the
# node (always) and writing it into this script (only where the pack says its shape can be). The help
# strip says what the focused knob is for, from the pack's own doc comment, and where it will land.
#
# After adding, the picker under the object lists the behavior's conditions, actions and
# expressions, the head's Behaviors folder shows it, and the Doctor checks the host the pack needs.
#
# The list ends with "+ New behaviour…", which makes one for this object (Works on is already its
# kind, and the new behaviour is added to it), and right-clicking a behaviour offers its settings or
# its file opened as a sheet - the doors to a behaviour that live where the behaviours are listed.

## A tile's width before display scaling; the shelves are three tiles wide.
const TILE_WIDTH := 160.0
## The shelf key of the project's own behaviours (a kind of object is a class name, never this).
const YOURS := "@yours"

var _object_label: String = ""
## The node the behaviour is being added to, when the scene is open - what the cards are measured against.
var _host: Node = null
var _packs: Array[Dictionary] = []
var _selected_dir: String = ""
var _search: LineEdit = null
var _list: VBoxContainer = null
var _properties: VBoxContainer = null
var _where: OptionButton = null
var _strip: EventSheetPopupUI.HelpStrip = null
var _fields: Dictionary = {}
var _on_add: Callable = Callable()
## (object_label, host_class) - "+ New behaviour…" for this object.
var _on_new: Callable = Callable()
## (script_path, settings) - a behaviour's right-click: its settings, or its file opened as a sheet.
var _on_open: Callable = Callable()
var _card_menu: PopupMenu = null
var _card_menu_path: String = ""
## Each listed pack's script text, read once per opening: a big project has well over a hundred
## packs, and each is asked what it works on, whether it is yours and what it is refused for.
var _pack_sources: Dictionary = {}
## Said under the search when it matches nothing.
var _no_match: Label = null


func _init() -> void:
	title = EventSheetL10n.translate("Add behavior")
	ok_button_text = EventSheetL10n.translate("Add")
	add_child(EventSheetPopupUI.margined(_build_body()))
	confirmed.connect(_on_confirmed)


## `on_add` is called with (pack: Dictionary, values: Dictionary, inline: bool) - the dock does
## the scene write and the undo, because a window has no business touching either. `on_new` and
## `on_open` are the list's doors to the New behaviour form and to a behaviour's own file.
func configure(on_add: Callable, on_new: Callable = Callable(), on_open: Callable = Callable()) -> void:
	_on_add = on_add
	_on_new = on_new
	_on_open = on_open


## Opens for one object. The label is the object the picker and the head will show it under; `host` is
## its node in the open scene, when there is one, so a behaviour made for another kind of object is greyed.
func open_for(object_label: String, host: Node = null) -> void:
	_object_label = object_label
	_host = host
	title = EventSheetL10n.translate("Add behavior to {object}").replace("{object}", object_label) \
		if not object_label.is_empty() else EventSheetL10n.translate("Add behavior")
	_packs = EventSheetPackCatalog.packs()
	_pack_sources.clear()
	_selected_dir = ""
	if _search != null:
		_search.text = ""
	_rebuild_list()
	popup_centered(Vector2i(int(EventSheetPalette.scaled_f(900.0)), int(EventSheetPalette.scaled_f(580.0))))


func _build_body() -> Control:
	var page: VBoxContainer = EventSheetPopupUI.form_box()
	page.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(840.0), EventSheetPalette.scaled_f(460.0))
	var band: HBoxContainer = HBoxContainer.new()
	band.add_theme_constant_override("separation", int(EventSheetPalette.scaled_f(10.0)))
	band.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var shelves: VBoxContainer = VBoxContainer.new()
	shelves.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search = LineEdit.new()
	_search.placeholder_text = EventSheetL10n.translate("search")
	_search.right_icon = EventSheetPopupUI._editor_icon("Search")
	_search.text_changed.connect(func(_text: String) -> void: _filter_shelves())
	shelves.add_child(_search)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", int(EventSheetPalette.scaled_f(4.0)))
	var list_scroll: ScrollContainer = ScrollContainer.new()
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_scroll.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(3.0 * TILE_WIDTH + 24.0), EventSheetPalette.scaled_f(300.0))
	list_scroll.add_child(_list)
	shelves.add_child(list_scroll)
	shelves.add_child(EventSheetPopupUI.hint_label(EventSheetL10n.translate(
		"Click one to see its properties, double-click to add it. Ones made for another kind of object are greyed, with the reason on hover."),
		EventSheetPalette.scaled_f(3.0 * TILE_WIDTH)))
	band.add_child(shelves)
	var detail: VBoxContainer = EventSheetPopupUI.form_box()
	detail.custom_minimum_size.x = EventSheetPalette.scaled_f(280.0)
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


func _rebuild_list() -> void:
	if _list == null:
		return
	for child: Node in _list.get_children():
		child.free()
	# Your own behaviours lead on their own shelf; the packs sit on one shelf per kind of object they
	# work on, the kinds this object is first, then the ones for any node, then the rest (greyed). What
	# each pack is refused for is worked out once per opening - one walk of the Autoload list for all.
	# The search then only shows and hides tiles, so a keystroke builds nothing.
	var autoloads: Dictionary = autoload_bases()
	var shelves: Dictionary = {}
	for pack: Dictionary in _packs:
		var source: String = _source_of(pack)
		pack["refusal"] = refusal(pack, _host, autoloads, source)
		var shelf: String = YOURS if EventSheetBehaviourAddonScaffold.is_yours(source) else works_on(source)
		if not shelves.has(shelf):
			shelves[shelf] = []
		(shelves[shelf] as Array).append(pack)
	var shelf_names: Array = shelves.keys()
	shelf_names.sort_custom(func(first: String, second: String) -> bool:
		return shelf_rank(first, _host) < shelf_rank(second, _host) \
			or (shelf_rank(first, _host) == shelf_rank(second, _host) and first < second))
	for shelf: String in shelf_names:
		var heading: String = EventSheetL10n.translate("Your behaviours") if shelf == YOURS \
			else (shelf if not shelf.is_empty() else EventSheetL10n.translate("Any node"))
		_list.add_child(EventSheetPopupUI.section_header(heading))
		var grid: GridContainer = GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", int(EventSheetPalette.scaled_f(6.0)))
		grid.add_theme_constant_override("v_separation", int(EventSheetPalette.scaled_f(6.0)))
		for pack: Dictionary in shelves[shelf]:
			grid.add_child(_build_tile(pack, str(pack["refusal"])))
		_list.add_child(grid)
	_no_match = EventSheetPopupUI.hint_label(EventSheetL10n.translate("No pack here matches that."), 260.0)
	_list.add_child(_no_match)
	if _on_new.is_valid():
		var make: Button = Button.new()
		make.text = EventSheetL10n.translate("+ New behaviour…")
		make.alignment = HORIZONTAL_ALIGNMENT_LEFT
		make.flat = true
		make.tooltip_text = EventSheetL10n.translate("Make a behaviour of your own for this object: Works on is already its kind, and it is added here once made.")
		make.pressed.connect(func() -> void:
			hide()
			_on_new.call(_object_label, _host.get_class() if _host != null else ""))
		_list.add_child(make)
	_filter_shelves()


## Shows the tiles the search matches and the shelves that keep one. The card on the right always
## belongs to a tile on show: a search that hides the chosen pack moves the choice to the first match.
func _filter_shelves() -> void:
	var matching: Dictionary = {}
	for pack: Dictionary in EventSheetPackCatalog.filtered(_packs, "", _search.text if _search != null else ""):
		matching[str(pack.get("dir", ""))] = pack
	var heading: Control = null
	var still_shown: bool = false
	var first_addable: Dictionary = {}
	for child: Node in _list.get_children():
		if child == _no_match or child is Button:
			continue
		if not child is GridContainer:
			heading = child as Control
			continue
		var any_shown: bool = false
		for tile: Button in (child as GridContainer).get_children():
			var pack_dir: String = str(tile.get_meta("pack_dir"))
			tile.visible = matching.has(pack_dir)
			if tile.visible:
				any_shown = true
				still_shown = still_shown or pack_dir == _selected_dir
				if first_addable.is_empty() and not tile.disabled:
					first_addable = matching[pack_dir]
		(child as GridContainer).visible = any_shown
		heading.visible = any_shown
	_no_match.visible = matching.is_empty()
	if not first_addable.is_empty() and not still_shown:
		_select_pack(first_addable)


## Where a shelf sits: your own behaviours first, then a kind this object is, then any node, then
## kinds made for other objects. `shelf` is YOURS, a class name, or "" for any node. A kind Godot
## does not know (a script's class_name) is never greyed by refusal(), so it is never filed with the
## greyed kinds either: beside this object's own kinds when its script is that class, else with any
## node.
static func shelf_rank(shelf: String, host: Node) -> int:
	if shelf == YOURS:
		return 0
	if shelf.is_empty():
		return 2
	if not ClassDB.class_exists(shelf):
		var script: Script = host.get_script() as Script if host != null else null
		while script != null and script.get_global_name() != StringName(shelf):
			script = script.get_base_script()
		return 1 if script != null else 2
	return 1 if host != null and host.is_class(shelf) else 3


## Every tile on the shelves, in the order they read.
func tiles() -> Array[Button]:
	var out: Array[Button] = []
	for shelf: Node in _list.get_children():
		if shelf is GridContainer:
			for tile: Node in shelf.get_children():
				out.append(tile as Button)
	return out


func _source_of(pack: Dictionary) -> String:
	var path: String = str(pack.get("path", ""))
	if not _pack_sources.has(path):
		_pack_sources[path] = FileAccess.get_file_as_string(path) if not path.is_empty() else ""
	return _pack_sources[path]


## One tile: the pack's icon, its name as the pack wrote it, and the kind of object it works on. A
## greyed tile says on hover why it cannot go on this object.
func _build_tile(pack: Dictionary, why_not: String) -> Button:
	var source: String = _source_of(pack)
	var tile: Button = Button.new()
	tile.toggle_mode = true
	tile.clip_contents = true
	tile.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(TILE_WIDTH), EventSheetPalette.scaled_f(48.0))
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# The tile knows WHICH pack it is by folder, so the selection highlight never has to guess it
	# from the name (a name that begins another pack's name would light up both).
	tile.set_meta("pack_dir", str(pack.get("dir", "")))
	tile.button_pressed = _selected_dir == str(pack.get("dir", ""))
	tile.disabled = not why_not.is_empty()
	# The name as written leads the hover, because a long one is clipped on the tile itself.
	var pitch: String = str(pack.get("pitch", "")).strip_edges()
	tile.tooltip_text = why_not if tile.disabled else str(pack.get("name", "")) + (" - " + pitch if not pitch.is_empty() else "")
	tile.pressed.connect(func() -> void: _select_pack(pack))
	tile.gui_input.connect(func(event: InputEvent) -> void:
		var click: InputEventMouseButton = event as InputEventMouseButton
		if click != null and click.pressed and click.button_index == MOUSE_BUTTON_RIGHT:
			open_card_menu(str(pack.get("path", "")))
		elif click != null and click.double_click and not tile.disabled:
			_select_pack(pack)
			_on_confirmed()
			hide())
	var inset: MarginContainer = MarginContainer.new()
	inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["margin_left", "margin_right"]:
		inset.add_theme_constant_override(side, int(EventSheetPalette.scaled_f(8.0)))
	var line: HBoxContainer = HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.modulate.a = 0.45 if tile.disabled else 1.0
	inset.add_child(line)
	var icon: TextureRect = TextureRect.new()
	icon.texture = tile_icon(pack, source)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2.ONE * EventSheetPalette.scaled_f(20.0)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(icon)
	var words: VBoxContainer = VBoxContainer.new()
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_theme_constant_override("separation", 0)
	line.add_child(words)
	var on_kind: String = works_on(source)
	for said: Array in [[str(pack.get("name", "")), EventSheetPopupUI.text_color(), 0],
			[on_kind if not on_kind.is_empty() else EventSheetL10n.translate("Any node"), EventSheetPopupUI.muted_text_color(), EventSheetPalette.scaled(11)]]:
		var label: Label = Label.new()
		label.text = str(said[0])
		label.clip_text = true
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_color_override("font_color", said[1])
		if int(said[2]) > 0:
			label.add_theme_font_size_override("font_size", int(said[2]))
		words.add_child(label)
	tile.add_child(inset)
	return tile


## A behaviour's right-click: Behaviour settings… or Open as sheet, for the script at `path`. Offered
## on a greyed one too, because changing what it works on is how one made for another object fits.
func open_card_menu(path: String) -> void:
	if not _on_open.is_valid() or path.is_empty():
		return
	_card_menu_path = path
	if _card_menu == null:
		_card_menu = PopupMenu.new()
		_card_menu.add_item(EventSheetL10n.translate("Behaviour settings…"), 0)
		_card_menu.add_item(EventSheetL10n.translate("Open as sheet"), 1)
		_card_menu.id_pressed.connect(func(id: int) -> void:
			hide()
			_on_open.call(_card_menu_path, id == 0))
		add_child(_card_menu)
	if is_inside_tree():
		_card_menu.popup(Rect2i(Vector2i(get_mouse_position()) + position, Vector2i.ZERO))


## The kind of object a pack's script works on - its typed `host`, else what it says it requires -
## or "" when any node will do.
static func works_on(source: String) -> String:
	var needs: String = EventSheetBehaviourAddonScaffold.host_class_of(source)
	return needs if not needs.is_empty() else EventSheetAddBehavior.requirement_in(source)


## A tile's picture: the script's own @icon, else the pack's icon, else the editor icon of the kind
## of object it works on - what Godot's Scene dock would show for it.
static func tile_icon(pack: Dictionary, source: String) -> Texture2D:
	var drawn: RegExMatch = RegEx.create_from_string("(?m)^@icon\\(\"([^\"]+)\"\\)").search(source)
	var path: String = drawn.get_string(1) if drawn != null else str(pack.get("icon", ""))
	# Through the picker's own cache: loading every pack's picture costs about half a second the
	# first time, and the window is opened again and again while a scene is put together.
	var drawn_icon: Texture2D = EventSheetACEIcons.path_icon(path)
	if drawn_icon != null:
		return drawn_icon
	var kind: String = works_on(source)
	return EventSheetPopupUI._editor_icon(kind if not kind.is_empty() else "Node")


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
	var needs: String = works_on(str(source) if source is String else FileAccess.get_file_as_string(path))
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
	for tile: Button in tiles():
		tile.set_pressed_no_signal(str(tile.get_meta("pack_dir", "")) == _selected_dir)


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
