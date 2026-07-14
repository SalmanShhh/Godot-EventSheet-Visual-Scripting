@tool
class_name EventSheetInspectorPreviewCard
extends PanelContainer

## A live mock of what the Inspector will actually show for the variable being
## edited: the group header, the subgroup indent, the property name, and the
## chosen widget - one glance answers "what will this look like in Godot".
## Below the mock, describe() renders the same choices as one plain sentence
## ("A whole number from 0 to 100, shown as a progress bar, grouped under
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
	_caption.text = "Inspector preview"
	_caption.add_theme_font_size_override("font_size", 10)
	_caption.modulate = Color(1.0, 1.0, 1.0, 0.5)
	column.add_child(_caption)
	_rows = VBoxContainer.new()
	column.add_child(_rows)
	_sentence_label = Label.new()
	_sentence_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sentence_label.add_theme_font_size_override("font_size", 11)
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
	if not group_name.is_empty():
		var group_label := Label.new()
		group_label.text = group_name
		group_label.add_theme_font_size_override("font_size", 12)
		group_label.add_theme_color_override("font_color", Color(0.85, 0.87, 0.92))
		_rows.add_child(group_label)
	if not subgroup_name.is_empty():
		var subgroup_label := Label.new()
		subgroup_label.text = "    %s" % subgroup_name
		subgroup_label.add_theme_font_size_override("font_size", 11)
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
	name_label.add_theme_font_size_override("font_size", 12)
	property_row.add_child(name_label)
	var widget: Control = _build_widget(type_name, default_text, attributes)
	widget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	property_row.add_child(widget)
	_rows.add_child(property_row)


## One plain sentence naming the type, the widget, the bounds, and the grouping -
## in C3-first language. Pinned by tests as exact strings.
static func describe(type_name: String, attributes: Dictionary, exported: bool, constant: bool) -> String:
	if constant:
		return "A constant - fixed while the game runs, not editable in the Inspector."
	if not exported:
		return "Only the sheet uses it - it does not appear in the Inspector."
	var fragments: Array[String] = [_type_phrase(type_name)]
	var range_spec: Variant = attributes.get("range")
	if range_spec is Dictionary:
		var bounds: String = "from %s to %s" % [str((range_spec as Dictionary).get("min", "0")), str((range_spec as Dictionary).get("max", "100"))]
		if bool((range_spec as Dictionary).get("or_greater", false)):
			bounds += " or more"
		var suffix: String = str((range_spec as Dictionary).get("suffix", ""))
		if not suffix.is_empty():
			bounds += " (in %s)" % suffix
		fragments.append(bounds)
	var widget_phrase: String = _widget_phrase(attributes)
	if not widget_phrase.is_empty():
		fragments.append(widget_phrase)
	var group_name: String = str(attributes.get("group", ""))
	var subgroup_name: String = str(attributes.get("subgroup", ""))
	if not group_name.is_empty() and not subgroup_name.is_empty():
		fragments.append("grouped under %s > %s" % [group_name, subgroup_name])
	elif not group_name.is_empty():
		fragments.append("grouped under %s" % group_name)
	if not str(attributes.get("header", "")).is_empty():
		fragments.append("under a \"%s\" section header" % str(attributes.get("header")))
	if not str(attributes.get("info", "")).is_empty():
		fragments.append("with an info note")
	if bool(attributes.get("required", false)):
		fragments.append("required (warns while unset)")
	if not str(attributes.get("validate", "")).is_empty():
		fragments.append("validated by %s()" % str(attributes.get("validate")))
	if not str(attributes.get("action", "")).is_empty():
		fragments.append("with a \"%s\" button" % str(attributes.get("action_label", str(attributes.get("action")).capitalize())))
	if bool(attributes.get("clamp", false)):
		fragments.append("clamped to the range")
	if bool(attributes.get("read_only", false)):
		fragments.append("read-only")
	if bool(attributes.get("storage", false)):
		return "%s, saved with the scene but hidden in the Inspector." % fragments[0]
	return "%s." % ", ".join(fragments)


static func _type_phrase(type_name: String) -> String:
	match type_name:
		"int":
			return "A whole number"
		"float":
			return "A number"
		"String":
			return "Text"
		"bool":
			return "A yes/no switch"
		"Color":
			return "A color"
		"NodePath":
			return "A node path"
		"Vector2", "Vector2i":
			return "A 2D vector"
		"Vector3", "Vector3i":
			return "A 3D vector"
		"Texture2D":
			return "A texture"
		"Curve":
			return "A curve"
		_:
			return "A %s value" % type_name


static func _widget_phrase(attributes: Dictionary) -> String:
	match str(attributes.get("drawer", "")):
		"progress_bar":
			return "shown as a progress bar"
		"vector_dial":
			return "shown as a direction dial"
		"min_max":
			return "shown as a min-max range slider"
		"table":
			return "shown as an editable table"
		"toggle_row":
			return "shown as toggle buttons"
		"swatch_row":
			return "shown as color swatches"
		"texture_preview":
			return "shown with a texture preview"
		"curve_preview", "curve_editor":
			return "shown with a curve preview"
	if attributes.get("file") is Dictionary:
		return "picked with a %s picker" % ("folder" if str((attributes.get("file") as Dictionary).get("mode", "")) == "dir" else "file")
	if attributes.has("flags"):
		return "shown as checkbox flags"
	if attributes.has("enum_values") or attributes.has("options"):
		return "shown as a dropdown"
	if attributes.has("suggestions"):
		return "shown as a dropdown that also accepts typing"
	if attributes.has("layers"):
		return "shown as a layers grid"
	if attributes.has("node_path_types"):
		return "picked from matching scene nodes"
	if str(attributes.get("custom_preset", "")) == "password":
		return "typed as dots (password)"
	if str(attributes.get("custom_preset", "")) == "expression":
		return "typed as a math expression"
	if str(attributes.get("custom_preset", "")) == "link":
		return "with linked axes"
	if bool(attributes.get("exp_easing", false)):
		return "shown as an easing curve"
	if bool(attributes.get("multiline", false)):
		return "with a big text box"
	if attributes.get("range") is Dictionary:
		return "shown as a slider"
	return ""


## The widget miniature: drawers win, then look-derived widgets (reusing the
## gallery's builders so the two previews can't diverge), then a slider for
## ranges, then per-type defaults.
func _build_widget(type_name: String, default_text: String, attributes: Dictionary) -> Control:
	var drawer_kind: String = str(attributes.get("drawer", ""))
	if drawer_kind == "progress_bar":
		var progress := ProgressBar.new()
		progress.min_value = 0.0
		progress.max_value = 100.0
		progress.value = 65.0
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
		var range_slider := EventSheetDrawerWidgets.DrawerMinMaxSlider.new(0.0, 100.0)
		range_slider.editable = false
		range_slider.set_value(Vector2(25.0, 75.0))
		range_slider.custom_minimum_size = Vector2(120.0, 18.0)
		return _ignored(range_slider)
	if drawer_kind == "toggle_row":
		var toggle_options: Array = attributes.get("toggle_options") if attributes.get("toggle_options") is Array else ["easy", "normal", "hard"]
		var toggle_texts: PackedStringArray = PackedStringArray()
		for toggle_option: Variant in toggle_options:
			toggle_texts.append(str(toggle_option))
		var toggle_row := EventSheetDrawerWidgets.DrawerToggleRow.new(toggle_texts)
		toggle_row.editable = false
		if not toggle_texts.is_empty():
			toggle_row.set_value(toggle_texts[0])
		return _ignored(toggle_row)
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
		return _ignored(EventSheetInspectorLooks.build_preview("easing_positive"))
	var look_id: String = _look_id_from_attributes(attributes)
	if not look_id.is_empty():
		return _ignored(EventSheetInspectorLooks.build_preview(look_id))
	if attributes.get("range") is Dictionary and (type_name == "int" or type_name == "float"):
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.value = 0.62
		slider.editable = false
		slider.custom_minimum_size = Vector2(120.0, 0.0)
		return _ignored(slider)
	if type_name == "bool":
		var check := CheckBox.new()
		check.text = "On"
		check.button_pressed = default_text.strip_edges() == "true"
		check.disabled = true
		return _ignored(check)
	if type_name == "Color":
		var color_swatch := ColorRect.new()
		color_swatch.color = Color(0.35, 0.55, 0.9)
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


## Maps the folded attribute families back to a gallery look id, so the card's
## widget and the gallery tile for the same choice are literally the same control.
static func _look_id_from_attributes(attributes: Dictionary) -> String:
	if attributes.get("file") is Dictionary:
		var file_spec: Dictionary = attributes.get("file")
		return "dir" if str(file_spec.get("mode", "")) == "dir" else "file"
	if attributes.has("flags"):
		return "flags"
	if attributes.has("enum_values"):
		return "enum_values"
	if attributes.has("layers"):
		return "layers_%s" % str(attributes.get("layers"))
	if attributes.has("node_path_types"):
		return "node_path"
	if attributes.has("suggestions"):
		return "suggestions"
	match str(attributes.get("custom_preset", "")):
		"password":
			return "preset_password"
		"expression":
			return "preset_expression"
		"link":
			return "preset_link"
	if bool(attributes.get("exp_easing", false)):
		var easing_flags: Array = attributes.get("exp_easing_flags", [])
		return "easing_attenuation" if easing_flags.has("attenuation") else "easing_positive"
	if bool(attributes.get("storage", false)):
		return "storage"
	return ""


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
