# Godot EventSheets — Inspector attribute drawers (Tier 3, docs/INSPECTOR-ATTRIBUTES-SPEC.md)
#
# One EditorInspectorPlugin recognizes the `eventsheet:<drawer>` marker that the compiler bakes into
# @export_custom hint strings, and swaps in a richer editor control. THE DEGRADATION CONTRACT: generated
# scripts stay plain GDScript — without this plugin (or in exported games) the property renders as a normal
# field, so the parity covenant is untouched. The actual widgets live in drawer_widgets.gd (reused by the
# Variable dialog's live preview); here we only map a marker+type to the right EditorProperty and forward edits.
#
# Drawers + marker forms:
#   progress_bar   eventsheet:progress_bar:<min>:<max>   int / float
#   vector_dial    eventsheet:vector_dial:<max>          Vector2
#   swatch_row     eventsheet:swatch_row                 Color
#   texture_preview eventsheet:texture_preview           Texture2D / String (path)
#   curve_editor   eventsheet:curve_editor               Curve
@tool
extends EditorInspectorPlugin
class_name EventSheetAttributeDrawers

func _can_handle(_object: Object) -> bool:
	return true  # cheap: the per-property marker check below does the real filtering

func _parse_property(_object: Object, type: Variant.Type, name: String, _hint_type: PropertyHint, hint_string: String, _usage_flags: int, _wide: bool) -> bool:
	var drawer: Dictionary = parse_drawer_hint(hint_string)
	var kind: String = str(drawer.get("drawer", ""))
	match kind:
		"progress_bar":
			if type != TYPE_INT and type != TYPE_FLOAT:
				return false
			add_property_editor(name, ProgressBarProperty.new(float(drawer.get("min", 0.0)), float(drawer.get("max", 100.0))))
			return true
		"vector_dial":
			if type != TYPE_VECTOR2:
				return false
			var args: Array = drawer.get("args", [])
			var dial_max: float = str(args[0]).to_float() if args.size() > 0 else 100.0
			add_property_editor(name, VectorDialProperty.new(dial_max))
			return true
		"swatch_row":
			if type != TYPE_COLOR:
				return false
			add_property_editor(name, SwatchRowProperty.new())
			return true
		"texture_preview":
			if type != TYPE_OBJECT and type != TYPE_STRING:
				return false
			add_property_editor(name, TexturePreviewProperty.new(type == TYPE_STRING))
			return true
		"curve_editor":
			if type != TYPE_OBJECT:
				return false
			add_property_editor(name, CurveEditorProperty.new())
			return true
	return false

## "eventsheet:progress_bar:0:200" -> {drawer:"progress_bar", args:["0","200"], min:0.0, max:200.0}.
## Anything not starting with the marker prefix -> {}. Static + UI-free so the headless suite pins the contract.
static func parse_drawer_hint(hint_string: String) -> Dictionary:
	if not hint_string.begins_with("eventsheet:"):
		return {}
	var parts: PackedStringArray = hint_string.split(":")
	var parsed: Dictionary = {"drawer": parts[1] if parts.size() > 1 else "", "args": Array(parts.slice(2))}
	if parts.size() > 2:
		parsed["min"] = parts[2].to_float()
	if parts.size() > 3:
		parsed["max"] = parts[3].to_float()
	return parsed

# ── EditorProperty wrappers (each embeds a reusable widget and forwards edits) ──

## Numeric progress bar: drag to set; emits an int back for int properties, a float for floats.
class ProgressBarProperty:
	extends EditorProperty
	var _bar: EventSheetDrawerWidgets.DrawerProgressBar

	func _init(min_value: float, max_value: float) -> void:
		_bar = EventSheetDrawerWidgets.DrawerProgressBar.new(min_value, max_value)
		_bar.value_changed.connect(_on_changed)
		add_child(_bar)
		add_focusable(_bar)

	func _on_changed(v: float) -> void:
		var is_int: bool = typeof(get_edited_object().get(get_edited_property())) == TYPE_INT
		emit_changed(get_edited_property(), int(round(v)) if is_int else v)

	func _update_property() -> void:
		_bar.set_value(float(get_edited_object().get(get_edited_property())))

## Vector2 dial: drag the handle to set direction + magnitude.
class VectorDialProperty:
	extends EditorProperty
	var _dial: EventSheetDrawerWidgets.DrawerVectorDial

	func _init(max_magnitude: float) -> void:
		_dial = EventSheetDrawerWidgets.DrawerVectorDial.new(max_magnitude)
		_dial.value_changed.connect(_on_changed)
		add_child(_dial)
		set_bottom_editor(_dial)

	func _on_changed(v: Vector2) -> void:
		emit_changed(get_edited_property(), v)

	func _update_property() -> void:
		_dial.set_value(get_edited_object().get(get_edited_property()))

## Colour swatch row: click a preset (or the picker) to set the colour.
class SwatchRowProperty:
	extends EditorProperty
	var _row: EventSheetDrawerWidgets.DrawerSwatchRow

	func _init() -> void:
		_row = EventSheetDrawerWidgets.DrawerSwatchRow.new()
		_row.value_changed.connect(_on_changed)
		add_child(_row)
		set_bottom_editor(_row)

	func _on_changed(c: Color) -> void:
		emit_changed(get_edited_property(), c)

	func _update_property() -> void:
		_row.set_value(get_edited_object().get(get_edited_property()))

## Texture preview: a resource picker (Texture2D) or path field (String) above a live thumbnail.
class TexturePreviewProperty:
	extends EditorProperty
	var _preview: EventSheetDrawerWidgets.DrawerTexturePreview
	var _picker: EditorResourcePicker = null
	var _path_edit: LineEdit = null
	var _is_string: bool = false

	func _init(is_string: bool) -> void:
		_is_string = is_string
		var box: VBoxContainer = VBoxContainer.new()
		if is_string:
			_path_edit = LineEdit.new()
			_path_edit.placeholder_text = "res://path/to/texture.png"
			_path_edit.text_submitted.connect(_on_path_submitted)
			box.add_child(_path_edit)
		else:
			_picker = EditorResourcePicker.new()
			_picker.base_type = "Texture2D"
			_picker.resource_changed.connect(_on_resource_changed)
			box.add_child(_picker)
		_preview = EventSheetDrawerWidgets.DrawerTexturePreview.new()
		box.add_child(_preview)
		add_child(box)
		set_bottom_editor(box)

	func _on_path_submitted(text: String) -> void:
		_preview.set_path(text)
		emit_changed(get_edited_property(), text)

	func _on_resource_changed(resource: Resource) -> void:
		_preview.set_texture(resource as Texture2D)
		emit_changed(get_edited_property(), resource)

	func _update_property() -> void:
		var value: Variant = get_edited_object().get(get_edited_property())
		if _is_string:
			if _path_edit != null:
				_path_edit.text = str(value)
			_preview.set_path(str(value))
		else:
			if _picker != null:
				_picker.edited_resource = value as Resource
			_preview.set_texture(value as Texture2D)

## Curve editor: a Curve resource picker above a live inline render of the curve's shape.
class CurveEditorProperty:
	extends EditorProperty
	var _preview: EventSheetDrawerWidgets.DrawerCurvePreview
	var _picker: EditorResourcePicker

	func _init() -> void:
		var box: VBoxContainer = VBoxContainer.new()
		_picker = EditorResourcePicker.new()
		_picker.base_type = "Curve"
		_picker.resource_changed.connect(_on_resource_changed)
		box.add_child(_picker)
		_preview = EventSheetDrawerWidgets.DrawerCurvePreview.new()
		box.add_child(_preview)
		add_child(box)
		set_bottom_editor(box)

	func _on_resource_changed(resource: Resource) -> void:
		_preview.set_curve(resource as Curve)
		emit_changed(get_edited_property(), resource)

	func _update_property() -> void:
		var value: Variant = get_edited_object().get(get_edited_property())
		_picker.edited_resource = value as Resource
		_preview.set_curve(value as Curve)
