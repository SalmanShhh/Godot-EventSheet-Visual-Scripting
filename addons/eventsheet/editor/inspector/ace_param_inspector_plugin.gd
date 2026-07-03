# EventSheet — ACE Param Inspector Plugin
# EditorInspectorPlugin for EventSheetExposedNode properties: renders custom widgets per
# `widget_hint` ("slider" → HSlider, "multiline" → TextEdit, "expression" → LineEdit with
# the ƒx tooltip) and falls back to Godot's default editors otherwise. Hints come from
# @ace_param_hint / parameter overrides and ride along on the exposed node's prop-map
# entries (get_property_entry).
#
# Registration: add_inspector_plugin() in the main EditorPlugin._enter_tree();
# remove_inspector_plugin() in _exit_tree().
@tool
class_name ACEParamInspectorPlugin
extends EditorInspectorPlugin

var _param_store: EditorParamStore = null


## Provide the EditorParamStore so the plugin can display current values.
func set_param_store(store: EditorParamStore) -> void:
	_param_store = store


## Only handle EventSheetExposedNode objects.
func _can_handle(object: Object) -> bool:
	return object is EventSheetExposedNode


## Called before the full property list is built.
func _parse_begin(object: Object) -> void:
	if not (object is EventSheetExposedNode):
		return
	var label: EditorProperty = _make_info_property("EventSheet ACE Parameters")
	add_custom_control(label)


## Per-property: substitute a widget_hint-specific editor when the entry asks for one.
func _parse_property(object: Object, _type: Variant.Type, name: String,
		_hint_type: PropertyHint, _hint_string: String,
		_usage_flags: int, _wide: bool) -> bool:
	if not (object is EventSheetExposedNode):
		return false
	var entry: Dictionary = (object as EventSheetExposedNode).get_property_entry(name)
	if entry.is_empty():
		return false
	var widget: EditorProperty = make_widget_for_hint(str(entry.get("widget_hint", "")), entry)
	if widget == null:
		return false
	add_property_editor(name, widget)
	return true


## Which editor class a widget_hint maps to (null = Godot's default). Split from
## construction because EditorProperty is editor-only-instantiable: headless tests assert
## the mapping; the editor constructs.
static func widget_class_for_hint(widget_hint: String) -> GDScript:
	match widget_hint:
		"slider", "range":
			return SliderParamProperty
		"multiline":
			return MultilineParamProperty
		"expression":
			return ExpressionParamProperty
	return null


## Factory for widget_hint editors (null = use Godot's default).
static func make_widget_for_hint(widget_hint: String, entry: Dictionary) -> EditorProperty:
	var widget_class: GDScript = widget_class_for_hint(widget_hint)
	if widget_class == null:
		return null
	if widget_class == SliderParamProperty:
		var bounds: PackedFloat64Array = _parse_range(entry)
		return SliderParamProperty.new(bounds[0], bounds[1], bounds[2])
	return widget_class.new()


## Range from param metadata: {"range": "min,max,step"} or hint_string, default 0..100/1.
static func _parse_range(entry: Dictionary) -> PackedFloat64Array:
	var text: String = str((entry.get("param_meta", {}) as Dictionary).get("range", entry.get("hint_string", "")))
	var parts: PackedStringArray = text.split(",", false)
	var minimum: float = float(parts[0]) if parts.size() > 0 and parts[0].strip_edges().is_valid_float() else 0.0
	var maximum: float = float(parts[1]) if parts.size() > 1 and parts[1].strip_edges().is_valid_float() else 100.0
	var step: float = float(parts[2]) if parts.size() > 2 and parts[2].strip_edges().is_valid_float() else 1.0
	return PackedFloat64Array([minimum, maximum, step])

# ── widget_hint editors ───────────────────────────────────────────────────────


class SliderParamProperty:
	extends EditorProperty
	var slider: HSlider = HSlider.new()
	func _init(minimum: float = 0.0, maximum: float = 100.0, step: float = 1.0) -> void:
		slider.min_value = minimum
		slider.max_value = maximum
		slider.step = step
		slider.custom_minimum_size = Vector2(80.0, 0.0)
		add_child(slider)
		add_focusable(slider)
		slider.value_changed.connect(func(value: float) -> void:
			emit_changed(get_edited_property(), value)
		)
	func _update_property() -> void:
		slider.set_value_no_signal(float(get_edited_object().get(get_edited_property())))


class MultilineParamProperty:
	extends EditorProperty
	var text_edit: TextEdit = TextEdit.new()
	func _init() -> void:
		text_edit.custom_minimum_size = Vector2(0.0, 72.0)
		text_edit.scroll_fit_content_height = true
		add_child(text_edit)
		add_focusable(text_edit)
		set_bottom_editor(text_edit)
		text_edit.focus_exited.connect(func() -> void:
			emit_changed(get_edited_property(), text_edit.text)
		)
	func _update_property() -> void:
		var value: String = str(get_edited_object().get(get_edited_property()))
		if text_edit.text != value:
			text_edit.text = value


class ExpressionParamProperty:
	extends EditorProperty
	var line_edit: LineEdit = LineEdit.new()
	func _init() -> void:
		line_edit.placeholder_text = "GDScript expression"
		line_edit.tooltip_text = "Plain GDScript — anything valid in an expression works here."
		add_child(line_edit)
		add_focusable(line_edit)
		line_edit.text_submitted.connect(func(value: String) -> void:
			emit_changed(get_edited_property(), value)
		)
		line_edit.focus_exited.connect(func() -> void:
			emit_changed(get_edited_property(), line_edit.text)
		)
	func _update_property() -> void:
		var value: String = str(get_edited_object().get(get_edited_property()))
		if line_edit.text != value:
			line_edit.text = value

# ── Helpers ──────────────────────────────────────────────────────────────────


## Build a simple read-only info label styled as an EditorProperty.
static func _make_info_property(text: String) -> EditorProperty:
	var prop := EditorProperty.new()
	prop.label = text
	var label := Label.new()
	label.text = ""
	prop.add_child(label)
	return prop
