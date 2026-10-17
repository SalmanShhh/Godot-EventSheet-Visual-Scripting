@tool
extends EditorInspectorPlugin
# The fields of a selected function, drawn for Godot's Inspector. It claims ONE object: the proxy
# dock/function_inspector.gd hands the Inspector. Every other object is left to Godot.
#
#   Returns        int ▾
#                  A whole number: counts, health, coins.
#                  ┃ take_damage hands back int, but no event in it says Return yet. Add a Return ...
#
# A dropdown describes each of its choices as the pointer rests on one (the window kit's described
# dropdown), and keeps the chosen choice's sentence in view under the field as a muted line. Under
# that sits the field's line with a coloured edge, in the strength the proxy gives it: red for a
# refusal (nothing was written), the accent for a hint, green for what leaving the field will do.
# What the choices are, what they say and what is wrong are all asked of the proxy, so this file
# only draws.
#
# Registered on the first function selection (the dock hands the proxy a door the plugin opened), so
# neither the editor's boot nor a sheet's first open loads it.

const FUNCTION_INSPECTOR_PATH := "res://addons/eventsheet/editor/dock/function_inspector.gd"


## True only for the function proxy. Static so a headless test can ask it: an EditorInspectorPlugin
## can only be made by the editor.
static func handles(object: Object) -> bool:
	if object == null or not (object.get_script() is Script):
		return false
	return (object.get_script() as Script).resource_path == FUNCTION_INSPECTOR_PATH


func _can_handle(object: Object) -> bool:
	return handles(object)


func _parse_property(object: Object, _type: Variant.Type, name: String, _hint_type: PropertyHint,
		_hint_string: String, _usage_flags: int, _wide: bool) -> bool:
	var key: String = str(object.call("field_of", name))
	var shape: String = shape_of(key)
	if shape.is_empty():
		return false
	add_property_editor(name, FunctionField.new(shape))
	return true


## How a field is drawn: "choice" (a described dropdown), "text" (a line), "long" (a box for the
## description), "suggested" (a line with a described dropdown of ready answers beside it), or "" for
## the ones Godot's own editors draw (the buttons).
static func shape_of(key: String) -> String:
	match key:
		"returns", "in_add_action", "waits", "shared":
			return "choice"
		"name":
			return "text"
		"description":
			return "long"
		"category":
			return "suggested"
	match key.get_slice(":", 2):
		"type":
			return "choice"
		"name", "default":
			return "text"
	return ""


## One field: the control beside its label, then the chosen choice's sentence and the warning under it.
class FunctionField:
	extends EditorProperty

	var _shape: String = ""
	var _dropdown: OptionButton = null
	var _line: LineEdit = null
	var _box: TextEdit = null
	var _note: Label = null
	var _warning: EventSheetPopupUI.StateNote = null
	# A yes/no setting is a dropdown of two whose second choice is "on".
	var _stores_bool: bool = false

	func _init(shape: String) -> void:
		_shape = shape
		var row: HBoxContainer = HBoxContainer.new()
		if shape == "long":
			_box = TextEdit.new()
			_box.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
			_box.custom_minimum_size = Vector2(0.0, EventSheetPalette.scaled_f(56.0))
			_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_box.text_changed.connect(func() -> void: _typed(_box.text))
			row.add_child(_box)
			add_focusable(_box)
		if shape == "text" or shape == "suggested":
			_line = LineEdit.new()
			_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_line.text_changed.connect(_typed)
			_line.text_submitted.connect(_typed)
			row.add_child(_line)
			add_focusable(_line)
		if shape == "choice" or shape == "suggested":
			_dropdown = EventSheetPopupUI.described_option()
			_dropdown.clip_text = true
			_dropdown.fit_to_longest_item = shape == "choice"
			_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL if shape == "choice" else Control.SIZE_SHRINK_END
			if shape == "suggested":
				# Beside a line the dropdown is only the arrow that opens the ready answers.
				_dropdown.custom_minimum_size.x = EventSheetPalette.scaled_f(36.0)
			_dropdown.item_selected.connect(_picked)
			row.add_child(_dropdown)
			add_focusable(_dropdown)
		add_child(row)
		var under: VBoxContainer = VBoxContainer.new()
		_note = _quiet_line(EventSheetPopupUI.muted_text_color())
		_warning = EventSheetPopupUI.StateNote.new(0.0)
		under.add_child(_note)
		under.add_child(_warning)
		add_child(under)
		set_bottom_editor(under)

	## Fills a dropdown with [word, sentence] choices, each sentence the item's own tooltip, and picks
	## `chosen`. The dropdown's tooltip and the note under it follow the pick.
	static func fill_choices(dropdown: OptionButton, choices: Array, chosen: int) -> void:
		dropdown.clear()
		for choice: Array in choices:
			EventSheetPopupUI.add_described_item(dropdown, str(choice[0]), str(choice[1]))
		if chosen >= 0 and chosen < dropdown.item_count:
			dropdown.select(chosen)
		EventSheetPopupUI.follow_description(dropdown)

	static func _quiet_line(colour: Color) -> Label:
		var line: Label = Label.new()
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.add_theme_color_override("font_color", colour)
		line.visible = false
		return line

	func _key() -> String:
		return str(get_edited_object().call("field_of", get_edited_property()))

	func _update_property() -> void:
		var proxy: Object = get_edited_object()
		var key: String = _key()
		# The label says what the field is for; the dropdown's own tooltip says what its choice means.
		tooltip_text = str(proxy.call("purpose", key))
		var value: Variant = proxy.get(get_edited_property())
		if _line != null and _line.text != str(value):
			_line.text = str(value)
		if _box != null and _box.text != str(value):
			_box.text = str(value)
		if _line != null:
			_line.editable = not proxy.call("is_read_only", key)
			_line.placeholder_text = EventSheetL10n.translate("required") if key.ends_with(":default") else ""
		if _dropdown != null:
			_stores_bool = value is bool
			var chosen: int = (1 if bool(value) else 0) if _stores_bool else (int(value) if _shape == "choice" else -1)
			fill_choices(_dropdown, proxy.call("choices", key), chosen)
			if _shape == "suggested":
				EventSheetPopupUI.select_option(_dropdown, str(value))
				EventSheetPopupUI.follow_description(_dropdown)
		_say(_dropdown.get_item_text(_dropdown.selected) if _shape == "choice" and _dropdown.selected >= 0 else str(value))

	## The note under the field (the chosen choice's sentence) and its line, for what is shown now:
	## the typed text, or the chosen choice's word.
	func _say(text: String) -> void:
		var proxy: Object = get_edited_object()
		var key: String = _key()
		var note: String = str(proxy.call("note", key, text))
		if note.is_empty() and _dropdown != null and _dropdown.selected >= 0:
			note = _dropdown.get_item_tooltip(_dropdown.selected)
		_note.text = note
		_note.visible = not note.is_empty()
		var line: Array = proxy.call("warning", key, text)
		_warning.say(str(line[1]), str(line[0]))

	func _typed(text: String) -> void:
		emit_changed(get_edited_property(), text)
		_say(text)

	func _picked(index: int) -> void:
		if _shape == "suggested":
			# A ready answer is typed into the line for the reader, then written like typed text.
			_line.text = _dropdown.get_item_text(index)
			_typed(_line.text)
			return
		emit_changed(get_edited_property(), index == 1 if _stores_bool else index)
