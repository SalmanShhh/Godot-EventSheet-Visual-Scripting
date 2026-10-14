@tool
class_name EventSheetInspectorPreviewCard
extends PanelContainer

## A live mock of what the Inspector will actually show for the variable being
## edited: the group header, the subgroup indent, the property name, and the
## chosen widget - one glance answers "what will this look like in Godot".
## Below the mock, describe() renders the same choices in plain words ("A whole
## number. It runs from 0 to 100. Shown as a progress bar. It is grouped under
## Combat > Defense."). The card is a picture for beginners; the "Ships as:"
## strip underneath stays the code truth for experts.

var _rows: VBoxContainer = null
var _sentence_label: Label = null
var _caption: Label = null


func _init() -> void:
	add_theme_stylebox_override("panel", EventSheetPopupUI.inset_panel_stylebox())
	var column := VBoxContainer.new()
	add_child(column)
	_caption = Label.new()
	_caption.text = EventSheetL10n.translate("Inspector preview")
	_caption.add_theme_font_size_override("font_size", EventSheetPalette.scaled(10))
	_caption.modulate = Color(1.0, 1.0, 1.0, 0.5)
	column.add_child(_caption)
	_rows = VBoxContainer.new()
	column.add_child(_rows)
	_sentence_label = Label.new()
	_sentence_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sentence_label.add_theme_font_size_override("font_size", EventSheetPalette.scaled(11))
	_sentence_label.modulate = Color(1.0, 1.0, 1.0, 0.72)
	column.add_child(_sentence_label)


## Hides the per-card "Inspector preview" caption - for surfaces that stack many cards into one
## whole-Inspector view (the Designer), where a caption per variable would read as noise.
func hide_caption() -> void:
	_caption.visible = false


## Rebuilds the mock + sentence. attributes carries the SAME keys the compiler
## reads (range/file/flags/layers/drawer/multiline/group/subgroup...), collected
## live by the dialog exactly like the "Ships as:" strip.
func update_preview(variable_name: String, type_name: String, default_text: String, attributes: Dictionary, exported: bool, constant: bool) -> void:
	while _rows.get_child_count() > 0:
		var stale_row: Node = _rows.get_child(0)
		_rows.remove_child(stale_row)
		stale_row.free()
	_sentence_label.text = describe(type_name, attributes, exported, constant)
	visible = exported
	if not exported:
		return
	# Decor mocks first - the same builders the Inspector plugin uses, so the preview can't lie.
	var header_text: String = str(attributes.get("header", ""))
	if not header_text.is_empty():
		_rows.add_child(EventSheetDrawerWidgets.build_header_label(header_text, str(attributes.get("header_color", ""))))
	var info_text: String = str(attributes.get("info", ""))
	if not info_text.is_empty():
		_rows.add_child(EventSheetDrawerWidgets.build_info_panel(info_text))
	if bool(attributes.get("required", false)):
		# Mocked in its shown state (target-less) - the point is what the warning looks like.
		_rows.add_child(EventSheetDrawerWidgets.RequiredBadge.new())
	if not str(attributes.get("validate", "")).is_empty():
		_rows.add_child(EventSheetDrawerWidgets.ValidateBadge.new(null, str(attributes.get("validate"))))
	if not str(attributes.get("action", "")).is_empty():
		_rows.add_child(EventSheetDrawerWidgets.ActionButton.new(null, str(attributes.get("action")), str(attributes.get("action_label", ""))))
	var group_name: String = str(attributes.get("group", ""))
	var subgroup_name: String = str(attributes.get("subgroup", ""))
	# A category is the Inspector's heavy band, its name centred, above every group in it.
	if not str(attributes.get("category", "")).is_empty():
		var band := Label.new()
		band.text = str(attributes.get("category"))
		band.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_rows.add_child(band)
	if not group_name.is_empty():
		var group_label := Label.new()
		# The chip the Inspector Designer shows on a group header: the whole section hides with this
		# switch, which is a fact about the SECTION, not about any one field under it.
		var group_predicate: String = str(attributes.get("group_show_if", ""))
		group_label.text = EventSheetL10n.translate("%s   (shown while %s)") % [group_name, group_predicate] if not group_predicate.is_empty() else group_name
		group_label.add_theme_font_size_override("font_size", EventSheetPalette.scaled(12))
		_rows.add_child(group_label)
	if not subgroup_name.is_empty():
		var subgroup_label := Label.new()
		subgroup_label.text = "    %s" % subgroup_name
		subgroup_label.add_theme_font_size_override("font_size", EventSheetPalette.scaled(11))
		subgroup_label.modulate = Color(1.0, 1.0, 1.0, 0.8)
		_rows.add_child(subgroup_label)
	var property_row := HBoxContainer.new()
	if not subgroup_name.is_empty():
		property_row.add_child(_spacer(24.0))
	elif not group_name.is_empty():
		property_row.add_child(_spacer(12.0))
	var name_label := Label.new()
	name_label.text = variable_name.capitalize()
	name_label.custom_minimum_size = Vector2(110.0, 0.0)
	name_label.add_theme_font_size_override("font_size", EventSheetPalette.scaled(12))
	property_row.add_child(name_label)
	var widget: Control = _build_widget(type_name, default_text, attributes)
	widget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	property_row.add_child(widget)
	# The link chip sits between the two neighbours, where the button will be - target-less, so it
	# is a picture of the tie rather than a live one (nothing to keep in a ratio in a preview).
	var link_partner: String = str(attributes.get("link_with", ""))
	if not link_partner.is_empty():
		property_row.add_child(_ignored(EventSheetDrawerWidgets.LinkToggle.new(null, variable_name, link_partner)))
	_rows.add_child(property_row)


## The type, the widget, the bounds and the grouping in plain words, one short sentence per fact -
## whole sentences so each one translates as a sentence. Pinned by tests as exact strings.
static func describe(type_name: String, attributes: Dictionary, exported: bool, constant: bool) -> String:
	if constant:
		return EventSheetL10n.translate("A constant - fixed while the game runs, not editable in the Inspector.")
	if not exported:
		return EventSheetL10n.translate("Only the sheet uses it - it does not appear in the Inspector.")
	var said: PackedStringArray = PackedStringArray([_type_sentence(type_name)])
	if bool(attributes.get("storage", false)):
		said.append(EventSheetL10n.translate("It is saved with the scene but hidden in the Inspector."))
		return _sentences(said)
	var range_spec: Variant = attributes.get("range")
	if range_spec is Dictionary:
		var low: String = str((range_spec as Dictionary).get("min", "0"))
		var high: String = str((range_spec as Dictionary).get("max", "100"))
		var unit: String = str((range_spec as Dictionary).get("suffix", ""))
		var or_more: bool = bool((range_spec as Dictionary).get("or_greater", false))
		if unit.is_empty():
			said.append((EventSheetL10n.translate("It runs from %s to %s or more.") if or_more
				else EventSheetL10n.translate("It runs from %s to %s.")) % [low, high])
		else:
			said.append((EventSheetL10n.translate("It runs from %s to %s %s or more.") if or_more
				else EventSheetL10n.translate("It runs from %s to %s %s.")) % [low, high, unit])
	var widget_sentence: String = _widget_sentence(attributes)
	if not widget_sentence.is_empty():
		said.append(widget_sentence)
	var group_name: String = str(attributes.get("group", ""))
	var subgroup_name: String = str(attributes.get("subgroup", ""))
	if not group_name.is_empty() and not subgroup_name.is_empty():
		said.append(EventSheetL10n.translate("It is grouped under %s > %s.") % [group_name, subgroup_name])
	elif not group_name.is_empty():
		said.append(EventSheetL10n.translate("It is grouped under %s.") % group_name)
	if not str(attributes.get("header", "")).is_empty():
		said.append(EventSheetL10n.translate("It sits under the section header \"%s\".") % str(attributes.get("header")))
	if not str(attributes.get("info", "")).is_empty():
		said.append(EventSheetL10n.translate("It has an info note."))
	if bool(attributes.get("required", false)):
		said.append(EventSheetL10n.translate("It is required, and warns while unset."))
	if not str(attributes.get("validate", "")).is_empty():
		said.append(EventSheetL10n.translate("It is checked by %s().") % str(attributes.get("validate")))
	if not str(attributes.get("action", "")).is_empty():
		said.append(EventSheetL10n.translate("It has a \"%s\" button.") % str(attributes.get("action_label", str(attributes.get("action")))))
	if not str(attributes.get("group_show_if", "")).is_empty() and not group_name.is_empty():
		said.append(EventSheetL10n.translate("Its group shows only while %s is on.") % str(attributes.get("group_show_if")))
	if not str(attributes.get("link_with", "")).is_empty():
		said.append(EventSheetL10n.translate("It is linked to %s.") % str(attributes.get("link_with")))
	if bool(attributes.get("clamp", false)):
		said.append(EventSheetL10n.translate("It is clamped to the range."))
	if bool(attributes.get("read_only", false)):
		said.append(EventSheetL10n.translate("It is read-only."))
	return _sentences(said)


## The sentences one after another: a space after a Latin full stop, none after the ideographic one,
## which carries its own.
static func _sentences(said: PackedStringArray) -> String:
	var text: String = ""
	for sentence: String in said:
		text += sentence if text.is_empty() or text.ends_with("。") else " " + sentence
	return text


static func _type_sentence(type_name: String) -> String:
	match type_name:
		"int":
			return EventSheetL10n.translate("A whole number.")
		"float":
			return EventSheetL10n.translate("A number.")
		"String":
			return EventSheetL10n.translate("Text.")
		"bool":
			return EventSheetL10n.translate("A yes/no switch.")
		"Color":
			return EventSheetL10n.translate("A color.")
		"NodePath":
			return EventSheetL10n.translate("A node path.")
		"Vector2", "Vector2i":
			return EventSheetL10n.translate("A 2D vector.")
		"Vector3", "Vector3i":
			return EventSheetL10n.translate("A 3D vector.")
		"Texture2D":
			return EventSheetL10n.translate("A texture.")
		"Curve":
			return EventSheetL10n.translate("A curve.")
	return EventSheetL10n.translate("A %s value.") % type_name


static func _widget_sentence(attributes: Dictionary) -> String:
	match str(attributes.get("drawer", "")):
		"progress_bar":
			return EventSheetL10n.translate("Shown as a progress bar.")
		"vector_dial":
			return EventSheetL10n.translate("Shown as a direction dial.")
		"min_max":
			return EventSheetL10n.translate("Shown as a min-max range slider.")
		"table":
			return EventSheetL10n.translate("Shown as an editable table.")
		"toggle_row":
			return EventSheetL10n.translate("Shown as toggle buttons.")
		"unit":
			return EventSheetL10n.translate("Shown with a unit dropdown.")
		"corners":
			return EventSheetL10n.translate("Shown as four corners.")
		"swatch_row":
			return EventSheetL10n.translate("Shown as color swatches.")
		"texture_preview":
			return EventSheetL10n.translate("Shown with a texture preview.")
		"curve_preview", "curve_editor":
			return EventSheetL10n.translate("Shown with a curve preview.")
	if attributes.get("file") is Dictionary:
		if str((attributes.get("file") as Dictionary).get("mode", "")) == "dir":
			return EventSheetL10n.translate("Picked with a folder picker.")
		return EventSheetL10n.translate("Picked with a file picker.")
	if attributes.has("flags"):
		return EventSheetL10n.translate("Shown as checkbox flags.")
	if attributes.has("enum_values") or attributes.has("options"):
		return EventSheetL10n.translate("Shown as a dropdown.")
	if attributes.has("suggestions"):
		return EventSheetL10n.translate("Shown as a dropdown that also accepts typing.")
	if attributes.has("layers"):
		return EventSheetL10n.translate("Shown as a layers grid.")
	if attributes.has("node_path_types"):
		return EventSheetL10n.translate("Picked from matching scene nodes.")
	match str(attributes.get("custom_preset", "")):
		"password":
			return EventSheetL10n.translate("Typed as dots, like a password.")
		"expression":
			return EventSheetL10n.translate("Typed as a math expression.")
		"link":
			return EventSheetL10n.translate("Its axes are linked.")
	if bool(attributes.get("exp_easing", false)):
		return EventSheetL10n.translate("Shown as an easing curve.")
	if bool(attributes.get("multiline", false)):
		return EventSheetL10n.translate("Edited in a big text box.")
	if attributes.get("range") is Dictionary:
		return EventSheetL10n.translate("Shown as a slider.")
	return ""


## The widget miniature: drawers win, then look-derived widgets (reusing the
## gallery's builders so the two previews can't diverge), then a slider for
## ranges, then per-type defaults.
func _build_widget(type_name: String, default_text: String, attributes: Dictionary) -> Control:
	if attributes.get("tool_button") is Dictionary:
		var button := Button.new()
		button.text = str((attributes.get("tool_button") as Dictionary).get("label", ""))
		return _ignored(button)
	var drawer_kind: String = str(attributes.get("drawer", ""))
	# Every widget below that has a value shows the variable's OWN value inside its own bounds, so a
	# health of 100 out of 0..200 reads half full, the way the Inspector will draw it.
	var bounds: Dictionary = attributes.get("range") if attributes.get("range") is Dictionary else {}
	var low: float = str(bounds.get("min", "0")).to_float()
	var high: float = str(bounds.get("max", "100")).to_float()
	var value: Variant = str_to_var(default_text) if not default_text.strip_edges().is_empty() else null
	if drawer_kind == "progress_bar":
		var progress := ProgressBar.new()
		progress.min_value = low
		progress.max_value = high
		progress.value = default_text.to_float()
		progress.custom_minimum_size = Vector2(120.0, 0.0)
		return _ignored(progress)
	if drawer_kind == "swatch_row":
		var swatches := HBoxContainer.new()
		for swatch_color: Color in [Color(0.9, 0.3, 0.3), Color(0.3, 0.8, 0.5), Color(0.35, 0.55, 0.9)]:
			var swatch := ColorRect.new()
			swatch.color = swatch_color
			swatch.custom_minimum_size = Vector2(18.0, 18.0)
			swatches.add_child(swatch)
		return _ignored(swatches)
	if drawer_kind == "vector_dial":
		return _ignored(_DialPreview.new())
	if drawer_kind == "min_max":
		var range_slider := EventSheetDrawerWidgets.DrawerMinMaxSlider.new(low, high)
		range_slider.editable = false
		range_slider.set_value(value if value is Vector2 else Vector2(low, high))
		range_slider.custom_minimum_size = Vector2(120.0, 18.0)
		return _ignored(range_slider)
	if drawer_kind == "toggle_row":
		var toggle_options: Array = attributes.get("toggle_options") if attributes.get("toggle_options") is Array else ["easy", "normal", "hard"]
		var toggle_texts: PackedStringArray = PackedStringArray()
		for toggle_option: Variant in toggle_options:
			toggle_texts.append(str(toggle_option))
		var toggle_row := EventSheetDrawerWidgets.DrawerToggleRow.new(toggle_texts,
			str(attributes.get("toggle_icons", "")), bool(attributes.get("toggle_segmented", false)))
		toggle_row.editable = false
		# A String keeps the chosen word; an int keeps its place in the list.
		var chosen: String = str(value) if value is String else ""
		if value is int and int(value) >= 0 and int(value) < toggle_texts.size():
			chosen = toggle_texts[int(value)]
		toggle_row.set_value(chosen)
		return _ignored(toggle_row)
	if drawer_kind == "corners":
		var corners_field := EventSheetDrawerWidgets.DrawerCorners.new()
		var corners_default: Variant = str_to_var(default_text)
		corners_field.set_value(corners_default if corners_default is Vector4 else Vector4.ZERO)
		corners_field.set_editable(false)
		corners_field.custom_minimum_size = Vector2(150.0, 0.0)
		return _ignored(corners_field)
	if drawer_kind == "unit":
		var unit_ids: PackedStringArray = PackedStringArray()
		for unit_kind: Variant in (attributes.get("unit_kinds") if attributes.get("unit_kinds") is Array else ["px", "world", "screen"]):
			unit_ids.append(str(unit_kind))
		var unit_field := EventSheetDrawerWidgets.DrawerUnitField.new(unit_ids, str(attributes.get("unit_store", "")))
		unit_field.set_value(default_text.to_float())
		unit_field.set_editable(false)
		unit_field.custom_minimum_size = Vector2(150.0, 0.0)
		return _ignored(unit_field)
	if drawer_kind == "table":
		var columns: Array = attributes.get("table_columns") if attributes.get("table_columns") is Array else [{"name": "item", "type": "String"}, {"name": "count", "type": "int"}]
		var table := EventSheetDrawerWidgets.DrawerTable.new(columns)
		table.editable = false
		var sample: Dictionary = {}
		for column: Variant in columns:
			if column is Dictionary:
				sample[str((column as Dictionary).get("name"))] = EventSheetDrawerWidgets.DrawerTable._default_for(column as Dictionary)
		table.set_value([sample])
		return _ignored(table)
	if drawer_kind == "texture_preview":
		var texture_box := ColorRect.new()
		texture_box.color = Color(0.45, 0.45, 0.5, 0.6)
		texture_box.custom_minimum_size = Vector2(42.0, 30.0)
		return _ignored(texture_box)
	if not drawer_kind.is_empty():
		# Remaining drawer kinds are curve-shaped (curve preview); the gallery's
		# ease miniature is the honest picture for them.
		return _ignored(EventSheetInspectorLooks.build_preview("easing"))
	# Flags and number choices draw the variable's own names, ticked or chosen by its own value, with
	# the values Godot gives them: a flag is 1 << its place, a choice one more than the one before,
	# unless the entry gives its own value.
	var labels: Variant = attributes.get("flags", attributes.get("enum_values", [])) if type_name == "int" else []
	if labels is Array and not labels.is_empty():
		var is_flags: bool = attributes.get("flags") is Array
		var labelled := HBoxContainer.new()
		var dropdown := OptionButton.new()
		dropdown.disabled = true
		var next_value: int = 0
		for index: int in labels.size():
			var entry: Dictionary = labels[index] if labels[index] is Dictionary else {"label": str(labels[index])}
			var own_value: String = str(entry.get("value", "")).strip_edges()
			next_value = own_value.to_int() if not own_value.is_empty() else (1 << index if is_flags else next_value)
			var label: String = str(entry.get("label", ""))
			if is_flags:
				var flag_check := CheckBox.new()
				flag_check.text = label
				flag_check.button_pressed = (default_text.to_int() & next_value) != 0
				flag_check.disabled = true
				labelled.add_child(flag_check)
			else:
				dropdown.add_item(label)
				if next_value == default_text.to_int():
					dropdown.select(dropdown.item_count - 1)
				next_value += 1
		if not is_flags:
			labelled.add_child(dropdown)
		return _ignored(labelled)
	var look_id: String = _look_id_from_attributes(attributes)
	var look_preview: Control = EventSheetInspectorLooks.build_preview(look_id) if not look_id.is_empty() else null
	if look_preview != null:
		# A text look (a path, a password, an expression) holds the variable's own text, not the sample.
		var text_field: LineEdit = look_preview as LineEdit
		if text_field == null and look_preview.get_child_count() > 0:
			text_field = look_preview.get_child(0) as LineEdit
		if text_field != null:
			text_field.text = str(value) if value != null else ""
		return _ignored(look_preview)
	if not bounds.is_empty() and (type_name == "int" or type_name == "float"):
		var slider := HSlider.new()
		slider.min_value = low
		slider.max_value = high
		slider.step = 0.0
		slider.value = default_text.to_float()
		slider.editable = false
		slider.custom_minimum_size = Vector2(120.0, 0.0)
		return _ignored(slider)
	if type_name == "bool":
		var check := CheckBox.new()
		check.text = EventSheetL10n.translate("On")
		check.button_pressed = default_text.strip_edges() == "true"
		check.disabled = true
		return _ignored(check)
	if type_name == "Color":
		var color_swatch := ColorRect.new()
		color_swatch.color = value if value is Color else Color(0.35, 0.55, 0.9)
		color_swatch.custom_minimum_size = Vector2(60.0, 18.0)
		return _ignored(color_swatch)
	var field := LineEdit.new()
	field.text = default_text
	field.editable = false
	if bool(attributes.get("multiline", false)):
		field.text = default_text + "  (multiline)"
	if attributes.has("placeholder") and default_text.strip_edges().is_empty():
		field.placeholder_text = str(attributes.get("placeholder"))
	return _ignored(field)


## The look the folded attributes wear, through the same table the dialog's dropdown reads, so the
## card's widget and the chosen look are literally the same control.
static func _look_id_from_attributes(attributes: Dictionary) -> String:
	return str(EventSheetInspectorLooks.unfold(attributes)[0])


func _ignored(widget: Control) -> Control:
	widget.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in widget.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	return widget


static func _spacer(width: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(width, 0.0)
	return spacer


## The direction-dial drawer in miniature: a circle with a needle.
class _DialPreview:
	extends Control


	func _init() -> void:
		custom_minimum_size = Vector2(30.0, 30.0)


	func _draw() -> void:
		var center: Vector2 = size / 2.0
		var radius: float = minf(size.x, size.y) / 2.0 - 2.0
		draw_arc(center, radius, 0.0, TAU, 24, Color(1.0, 1.0, 1.0, 0.35), 1.5, true)
		draw_line(center, center + Vector2.from_angle(-PI / 4.0) * radius, Color(0.45, 0.75, 0.95), 2.0, true)
