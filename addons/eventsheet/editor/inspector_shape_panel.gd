# Godot EventSheets - the Inspector Designer's "Shape this field" panel: the picked field's six tabs
# (Look, Layout, Show when, Check, Help, Button), each naming its current choice, the options of the
# open tab that fit the field's type with the sentence that describes each, and the picked or hovered
# option's code and what it is without the plugin.
#
#   Shape this field: shield_amount  int
#   [Look      ] [Layout     ] [Show when       ] [Check   ] [Help    ] [Button   ]
#    Plain number  In its group   Only when has_shield…  No check   Hover text…  No button
#   ● Always                         | Only when has_shield is on              chosen for shield_amount
#     Always shown.                  | Hidden while has_shield is off, ...
#   ● Only when has_shield is on     | IN CODE   @tool ... func _validate_property(...)
#     Hidden while has_shield ...    | WITHOUT THE PLUGIN   The same: ...
#
# The panel only DRAWS and asks. A pick is handed up as `chose(category, option_id, answers)`; the
# Designer routes it through the dock's undo funnel and rebuilds, and this panel is told the field
# again with what the file now says. An option that can stand on its details' defaults is written
# the moment it is clicked; one whose detail is the point (a function name, a note, a dropdown's
# choices) shows its fields under the code first and is chosen with them. The chosen option keeps its
# fields under the code, so its details change with Apply - one more undo step.
#
# DELIBERATELY NO `class_name`: the Designer loads it by path when it first opens.
@tool
extends VBoxContainer

signal chose(category: String, option_id: String, answers: Dictionary)

const SHAPE_PATH := "res://addons/eventsheet/editor/inspector_shape.gd"

var _shape: GDScript = null
var _sheet: EventSheetResource = null
var _field: Dictionary = {}
var _fields: Array = []
var _category: String = "look"
var _reading: Dictionary = {}
var _options: Array[Dictionary] = []
var _chosen: String = ""
var _hovered: String = ""
# The option whose details are being filled in before it is written, and the fields for them.
var _pending: String = ""
var _ask_fields: Dictionary = {}

var _title_name: Label = null
var _title_type: Label = null
var _notice: EventSheetPopupUI.StateNote = null
var _tabs: HBoxContainer = null
var _list: VBoxContainer = null
var _shown_label: Label = null
var _shown_state: Label = null
var _shown_tip: Label = null
var _code_heading: Label = null
var _code_text: String = ""
var _code_label: Label = null
var _plain_label: Label = null
var _lift_label: Label = null
var _asks: VBoxContainer = null
var _ask_note: EventSheetPopupUI.StateNote = null
var _ask_note_text: String = ""


func _init() -> void:
	_shape = load(SHAPE_PATH)
	add_theme_constant_override("separation", int(EventSheetPalette.scaled_f(6.0)))
	var title: HBoxContainer = HBoxContainer.new()
	var lead: Label = Label.new()
	lead.text = EventSheetL10n.translate("Shape this field:")
	title.add_child(lead)
	_title_name = Label.new()
	var mono: Font = EventSheetPopupUI.editor_font("doc_source")
	if mono != null:
		_title_name.add_theme_font_override("font", mono)
	title.add_child(_title_name)
	_title_type = Label.new()
	_title_type.add_theme_color_override("font_color", EventSheetPopupUI.muted_text_color())
	title.add_child(_title_type)
	add_child(title)
	_notice = EventSheetPopupUI.StateNote.new(560.0)
	add_child(_notice)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", int(EventSheetPalette.scaled_f(2.0)))
	add_child(_tabs)
	var body: HBoxContainer = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(body)
	var list_scroll: ScrollContainer = ScrollContainer.new()
	list_scroll.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(270.0), EventSheetPalette.scaled_f(300.0))
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(list_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 0)
	list_scroll.add_child(_list)
	var detail: VBoxContainer = VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(300.0), 0.0)
	detail.add_theme_constant_override("separation", int(EventSheetPalette.scaled_f(6.0)))
	body.add_child(EventSheetPopupUI.margined(detail, int(EventSheetPalette.scaled_f(8.0))))
	var head: HBoxContainer = HBoxContainer.new()
	_shown_label = Label.new()
	_shown_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shown_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(_shown_label)
	_shown_state = Label.new()
	_shown_state.add_theme_color_override("font_color", EventSheetPopupUI.muted_text_color())
	_shown_state.add_theme_font_size_override("font_size", EventSheetPalette.scaled(11))
	head.add_child(_shown_state)
	detail.add_child(head)
	_shown_tip = _wrapped("")
	detail.add_child(_shown_tip)
	var code_head: HBoxContainer = HBoxContainer.new()
	code_head.add_child(EventSheetPopupUI.small_caps_label(EventSheetL10n.translate("In code"), EventSheetPopupUI.muted_text_color()))
	_code_heading = Label.new()
	_code_heading.add_theme_color_override("font_color", EventSheetPopupUI.muted_text_color())
	_code_heading.add_theme_font_size_override("font_size", EventSheetPalette.scaled(11))
	code_head.add_child(_code_heading)
	detail.add_child(code_head)
	_code_label = _wrapped("")
	if mono != null:
		_code_label.add_theme_font_override("font", mono)
	_code_label.add_theme_font_size_override("font_size", EventSheetPalette.scaled(11))
	detail.add_child(EventSheetPopupUI.panel_section(_code_label))
	_asks = VBoxContainer.new()
	detail.add_child(_asks)
	_ask_note = EventSheetPopupUI.StateNote.new(300.0)
	detail.add_child(_ask_note)
	var notes: GridContainer = GridContainer.new()
	notes.columns = 2
	notes.add_theme_constant_override("h_separation", int(EventSheetPalette.scaled_f(8.0)))
	notes.add_child(EventSheetPopupUI.small_caps_label(EventSheetL10n.translate("Without the plugin"), EventSheetPopupUI.muted_text_color()))
	_plain_label = _wrapped("")
	notes.add_child(_plain_label)
	notes.add_child(EventSheetPopupUI.small_caps_label(EventSheetL10n.translate("From code"), EventSheetPopupUI.muted_text_color()))
	_lift_label = _wrapped(EventSheetL10n.translate("Opening a script that already has this code shows the same choice here, and saving untouched writes the same bytes."))
	notes.add_child(_lift_label)
	detail.add_child(notes)


## Shows `field` (a Designer entry) of `sheet` on the tab `category`. `fields` is every exported entry,
## for the tick boxes a Show when can follow.
func show_field(sheet: EventSheetResource, field: Dictionary, fields: Array, category: String = "") -> void:
	_sheet = sheet
	_field = field
	_fields = fields
	if _shape.CATEGORIES.has(category):
		_category = category
	_reading = _shape.reading(sheet)
	_hovered = ""
	_pending = ""
	_title_name.text = str(field.get("name", ""))
	_title_type.text = str(field.get("type_name", ""))
	var own: Dictionary = _reading.get(str(field.get("name", "")), {})
	if own.has("own"):
		_notice.say(EventSheetL10n.translate("shaped by your own code: edit it in the script") + "  (%s)" % str(own["own"]), EventSheetPopupUI.TONE_WARNING)
	else:
		_notice.say("")
	_rebuild_tabs()
	_rebuild_list()


## The tab being shown and the option chosen on it - test seams.
func category() -> String:
	return _category


func chosen_option() -> String:
	return _chosen


## The ids and reasons of the options listed, in order - test seam.
func listed() -> Array:
	return _options.map(func(option: Dictionary) -> Array: return [str(option.get("id")), str(option.get("reason"))])


## Every tab's name and the choice under it, in order - test seam.
func tab_texts() -> PackedStringArray:
	var texts: PackedStringArray = PackedStringArray()
	for tab: Node in _tabs.get_children():
		texts.append((tab as Button).text)
	return texts


## The code the shown option writes - test seam.
func shown_code() -> String:
	return _code_text


## Picks `option_id` as a click would (test seam and the click's own path).
func pick(option_id: String) -> void:
	var option: Dictionary = _option(option_id)
	if option.is_empty():
		return
	var reason: String = _blocked(option)
	if not reason.is_empty():
		_hovered = option_id
		_show_detail()
		_say(reason, EventSheetPopupUI.TONE_WARNING)
		return
	# An option whose detail is the point shows its fields first; the code under them follows the typing.
	if not bool(option.get("ready", true)) and option_id != _chosen:
		_pending = option_id
		_show_detail()
		return
	if option_id != _chosen:
		chose.emit(_category, option_id, {})


## Types the answers into the shown option's fields and chooses it (test seam for Choose and Apply).
func answer(values: Dictionary) -> void:
	for key: Variant in values:
		var control: Control = _ask_fields.get(key) as Control
		if control is LineEdit:
			(control as LineEdit).text = str(values[key])
		elif control is CheckBox:
			(control as CheckBox).button_pressed = bool(values[key])
		elif control is OptionButton:
			EventSheetPopupUI.select_option(control as OptionButton, str(values[key]))
	_choose_shown()


## The sentence the note under the fields says - test seam.
func ask_note() -> String:
	return _ask_note_text


## Whether the panel only reads this field (its shape is the reader's own code) - test seam.
func read_only() -> bool:
	return (_reading.get(str(_field.get("name", "")), {}) as Dictionary).has("own")


func _rebuild_tabs() -> void:
	for old: Node in _tabs.get_children():
		_tabs.remove_child(old)
		old.free()
	var group: ButtonGroup = ButtonGroup.new()
	for category_id: String in _shape.CATEGORIES:
		var tab: Button = Button.new()
		tab.toggle_mode = true
		tab.button_group = group
		tab.focus_mode = Control.FOCUS_ALL
		var now: String = _label_of(category_id, _shape.chosen(category_id, _field, _reading.get(str(_field.get("name", "")), {})))
		tab.text = "%s\n%s" % [_shape.category_name(category_id), now]
		tab.tooltip_text = _shape.category_tip(category_id)
		tab.alignment = HORIZONTAL_ALIGNMENT_LEFT
		tab.button_pressed = category_id == _category
		tab.pressed.connect(func() -> void:
			_category = category_id
			_hovered = ""
			_pending = ""
			_rebuild_list())
		_tabs.add_child(tab)


func _label_of(category_id: String, option_id: String) -> String:
	for option: Dictionary in _shape.options(category_id, _field, _fields):
		if str(option.get("id")) == option_id:
			return str(option.get("label"))
	return option_id


func _rebuild_list() -> void:
	for old: Node in _list.get_children():
		_list.remove_child(old)
		old.free()
	_options = _shape.options(_category, _field, _fields)
	_chosen = _shape.chosen(_category, _field, _reading.get(str(_field.get("name", "")), {}))
	for option: Dictionary in _options:
		_list.add_child(_option_row(option))
	_show_detail()


## One option as a row: the dot when it is chosen, its label, and its sentence under it. A row that
## cannot be chosen says why in place of its sentence.
func _option_row(option: Dictionary) -> Control:
	var option_id: String = str(option.get("id"))
	var row: PanelContainer = PanelContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.focus_mode = Control.FOCUS_ALL
	row.tooltip_text = str(option.get("tip"))
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(EventSheetPopupUI.accent_color(), 0.16) if option_id == _chosen else Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = EventSheetPopupUI.accent_color() if option_id == _chosen else Color(0.0, 0.0, 0.0, 0.0)
	style.border_width_left = EventSheetPalette.scaled(3)
	style.border_width_bottom = 1
	style.content_margin_left = EventSheetPalette.scaled_f(8.0)
	style.content_margin_right = EventSheetPalette.scaled_f(8.0)
	style.content_margin_top = EventSheetPalette.scaled_f(5.0)
	style.content_margin_bottom = EventSheetPalette.scaled_f(5.0)
	row.add_theme_stylebox_override("panel", style)
	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line: Label = Label.new()
	line.text = ("● " if option_id == _chosen else "    ") + str(option.get("label"))
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(line)
	var reason: String = _blocked(option)
	var tip: Label = _wrapped(reason if not reason.is_empty() else str(option.get("tip")), 240.0)
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip.add_theme_color_override("font_color", EventSheetPopupUI.muted_text_color())
	tip.add_theme_font_size_override("font_size", EventSheetPalette.scaled(11))
	column.add_child(tip)
	if not reason.is_empty():
		row.modulate = Color(1.0, 1.0, 1.0, 0.55)
	row.add_child(column)
	row.gui_input.connect(func(event: InputEvent) -> void:
		if (event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) \
				or (event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode in [KEY_ENTER, KEY_SPACE]):
			pick(option_id))
	row.mouse_entered.connect(_hover.bind(option_id))
	row.focus_entered.connect(_hover.bind(option_id))
	row.mouse_exited.connect(_hover.bind(""))
	return row


func _hover(option_id: String) -> void:
	if not _pending.is_empty():
		return
	_hovered = option_id
	_show_detail()


## Why `option` cannot be chosen for this field now, or "": its own reason, else the field's code.
func _blocked(option: Dictionary) -> String:
	if not str(option.get("reason", "")).is_empty():
		return str(option.get("reason"))
	var own: Dictionary = _reading.get(str(_field.get("name", "")), {})
	if own.has("own"):
		return EventSheetL10n.translate("shaped by your own code: edit it in the script")
	if _category == "show" and own.has("show"):
		return EventSheetL10n.translate("Read from your own _validate_property: change it there.")
	if _category == "show" and _reading.has("__owns_validate"):
		return EventSheetL10n.translate("This script writes its own _validate_property, so Show when is edited there.")
	return ""


func _option(option_id: String) -> Dictionary:
	for option: Dictionary in _options:
		if str(option.get("id")) == option_id:
			return option
	return {}


## The detail side: the pending, hovered or chosen option, its sentence, its code and its plain line.
func _show_detail() -> void:
	var shown_id: String = _pending if not _pending.is_empty() else (_hovered if not _hovered.is_empty() else _chosen)
	var option: Dictionary = _option(shown_id)
	if option.is_empty() and not _options.is_empty():
		option = _options[0]
		shown_id = str(option.get("id"))
	var var_name: String = str(_field.get("name", ""))
	_shown_label.text = str(option.get("label", ""))
	if shown_id == _chosen:
		_shown_state.text = EventSheetL10n.translate("read from your code") if (_reading.get(var_name, {}) as Dictionary).has("show") and _category == "show" \
			else EventSheetL10n.translate("chosen for %s") % var_name
	else:
		_shown_state.text = EventSheetL10n.translate("hovered: click to choose")
	_shown_tip.text = str(option.get("tip", ""))
	var file: String = _sheet.external_source_path.get_file() if _sheet != null and not _sheet.external_source_path.is_empty() else EventSheetL10n.translate("the script")
	_code_heading.text = EventSheetL10n.translate("(what the Designer writes into %s)") % file
	var with_fields: bool = (shown_id == _pending or shown_id == _chosen) and _blocked(option).is_empty()
	_rebuild_asks(option if with_fields else {}, shown_id == _pending)
	_set_code(_shape.code(_sheet, var_name, _category, shown_id, _answers()) if _sheet != null else "")
	_plain_label.text = str(option.get("plain", ""))
	_say(_missing_function(shown_id), EventSheetPopupUI.TONE_WARNING)


func _rebuild_asks(option: Dictionary, pending: bool) -> void:
	for old: Node in _asks.get_children():
		_asks.remove_child(old)
		old.free()
	_ask_fields = {}
	if option.is_empty() or option.get("asks", []).is_empty():
		return
	var held: Dictionary = {} if pending else _shape.current_answers(_category, str(option.get("id")), _field.get("attributes", {}))
	for ask: Array in option.get("asks", []):
		var key: String = str(ask[0])
		var value: Variant = held.get(key, ask[3])
		var control: Control = null
		match str(ask[2]):
			"tick":
				var tick: CheckBox = CheckBox.new()
				tick.text = str(ask[4])
				tick.button_pressed = bool(value)
				tick.toggled.connect(func(_on: bool) -> void: _follow_typing())
				control = tick
			"pick":
				var pick_list: OptionButton = OptionButton.new()
				for choice: Variant in ask[4]:
					pick_list.add_item(EventSheetL10n.translate(str(choice)))
					pick_list.set_item_metadata(pick_list.item_count - 1, str(choice))
					if str(choice) == str(value):
						pick_list.select(pick_list.item_count - 1)
				pick_list.item_selected.connect(func(_index: int) -> void: _follow_typing())
				control = pick_list
			_:
				var edit: LineEdit = LineEdit.new()
				edit.text = str(value)
				edit.placeholder_text = str(ask[4]) if ask.size() > 4 else ""
				edit.text_submitted.connect(func(_typed: String) -> void: _choose_shown())
				edit.text_changed.connect(func(_typed: String) -> void: _follow_typing())
				control = edit
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_ask_fields[key] = control
		_asks.add_child(EventSheetPopupUI.form_row(str(ask[1]), control, 110.0))
	var choose: Button = Button.new()
	choose.text = EventSheetL10n.translate("Choose") if pending else EventSheetL10n.translate("Apply")
	choose.size_flags_horizontal = Control.SIZE_SHRINK_END
	choose.pressed.connect(_choose_shown)
	_asks.add_child(choose)


func _follow_typing() -> void:
	var shown_id: String = _pending if not _pending.is_empty() else _chosen
	_set_code(_shape.code(_sheet, str(_field.get("name", "")), _category, shown_id, _answers()))


## The code under the option, its tabs drawn as four spaces: a Label draws a tab as nothing.
func _set_code(text: String) -> void:
	_code_text = text
	_code_label.text = text.replace("\t", "    ")


func _answers() -> Dictionary:
	var answers: Dictionary = {}
	for key: Variant in _ask_fields:
		var control: Control = _ask_fields[key] as Control
		if control is LineEdit:
			answers[key] = (control as LineEdit).text
		elif control is CheckBox:
			answers[key] = (control as CheckBox).button_pressed
		elif control is OptionButton and (control as OptionButton).selected >= 0:
			answers[key] = str((control as OptionButton).get_item_metadata((control as OptionButton).selected))
	return answers


## Chooses the option the fields are shown for - the pending one, else the chosen one with new details.
func _choose_shown() -> void:
	var option_id: String = _pending if not _pending.is_empty() else _chosen
	var answers: Dictionary = _answers()
	var refused: String = _shape.refusal(_category, option_id, answers)
	if not refused.is_empty():
		_say(refused)
		return
	chose.emit(_category, option_id, answers)


func _say(sentence: String, level: String = EventSheetPopupUI.TONE_ERROR) -> void:
	_ask_note_text = sentence
	_ask_note.say(sentence, level)


## A note when the chosen option names a function the script does not have yet: the field would ask
## nothing of it.
func _missing_function(option_id: String) -> String:
	if option_id != _chosen or _sheet == null:
		return ""
	var key: String = {"check": "validate", "button": "action", "look": "choices_function"}.get(_category, "")
	var named: String = str((_field.get("attributes", {}) as Dictionary).get(key, "")) if not key.is_empty() else ""
	if named.is_empty() or _has_function(named):
		return ""
	return EventSheetL10n.translate("%s is not a function of this script yet: add it on the sheet, or the field has nothing to ask.") % named


func _has_function(function_name: String) -> bool:
	for entry: Variant in _sheet.functions:
		if entry is EventFunction and (entry as EventFunction).function_name == function_name:
			return true
	for entry: Variant in _sheet.events:
		if entry is RawCodeRow and (entry as RawCodeRow).code.contains("func %s(" % function_name):
			return true
	return false


static func _wrapped(text: String, width: float = 300.0) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(width), 0.0)
	return label
