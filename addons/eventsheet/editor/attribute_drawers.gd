# Godot EventSheets - Inspector attribute drawers (Tier 3)
#
# One EditorInspectorPlugin recognizes the `eventsheet:<drawer>` marker that the compiler bakes into
# @export_custom hint strings, and swaps in a richer editor control. THE DEGRADATION CONTRACT: generated
# scripts stay plain GDScript - without this plugin (or in exported games) the property renders as a normal
# field, so the parity covenant is untouched. The actual widgets live in drawer_widgets.gd (reused by the
# Variable dialog's live preview); here we only map a marker+type to the right EditorProperty and forward edits.
#
# Drawers + marker forms:
#   progress_bar   eventsheet:progress_bar:<min>:<max>   int / float
#   min_max        eventsheet:min_max:<min>:<max>        Vector2 (x = low end, y = high end)
#   vector_dial    eventsheet:vector_dial:<max>          Vector2
#   swatch_row     eventsheet:swatch_row                 Color
#   texture_preview eventsheet:texture_preview           Texture2D / String (path)
#   curve_editor   eventsheet:curve_editor               Curve
@tool
class_name EventSheetAttributeDrawers
extends EditorInspectorPlugin


func _can_handle(_object: Object) -> bool:
	return true  # cheap: the per-property marker check below does the real filtering


func _parse_property(_object: Object, type: Variant.Type, name: String, _hint_type: PropertyHint, hint_string: String, _usage_flags: int, _wide: bool) -> bool:
	# Decor first: `# @inspector_header` / `# @inspector_info` comments above the var render as a section
	# label / info panel ABOVE the property, composing with any drawer (or the default field) below.
	for entry: Variant in decor_for(_object, name):
		var decor_entry: Dictionary = entry as Dictionary
		match str(decor_entry.get("kind", "")):
			"header":
				add_custom_control(EventSheetDrawerWidgets.build_header_label(str(decor_entry.get("text", "")), str(decor_entry.get("color", ""))))
			"required":
				add_custom_control(EventSheetDrawerWidgets.RequiredBadge.new(_object, name))
			_:
				add_custom_control(EventSheetDrawerWidgets.build_info_panel(str(decor_entry.get("text", ""))))
	var drawer: Dictionary = parse_drawer_hint(hint_string)
	var kind: String = str(drawer.get("drawer", ""))
	match kind:
		"progress_bar":
			if type != TYPE_INT and type != TYPE_FLOAT:
				return false
			add_property_editor(name, ProgressBarProperty.new(float(drawer.get("min", 0.0)), float(drawer.get("max", 100.0))))
			return true
		"min_max":
			if type != TYPE_VECTOR2:
				return false
			add_property_editor(name, MinMaxSliderProperty.new(float(drawer.get("min", 0.0)), float(drawer.get("max", 100.0))))
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
			# Resource-class guard: a generated sheet only ever pairs this marker with a Texture2D (the compiler
			# type-gates it), but a hand-edited marker on another resource would otherwise attach a wrong picker.
			if type != TYPE_OBJECT or not _value_is_kind(_object, name, "Texture2D"):
				return false
			add_property_editor(name, TexturePreviewProperty.new())
			return true
		"curve_editor":
			if type != TYPE_OBJECT or not _value_is_kind(_object, name, "Curve"):
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


# Decor maps parsed per script, cached by source length (cosmetic-only, so a same-length edit missing
# the cache costs nothing worse than one stale render until the next real edit).
static var _decor_cache: Dictionary = {}


## The decor entries for one property, parsed from the object's script source. Decor comments are plain
## `#` lines (never `##` - those merge into the hover tooltip), so they reach the editor only through
## the source text, exactly like the parity covenant wants: inert in the exported game.
static func decor_for(object: Object, property: String) -> Array:
	if object == null:
		return []
	var script: GDScript = object.get_script() as GDScript
	if script == null:
		return []
	var source: String = script.source_code
	if source.find("# @inspector_") == -1:
		return []
	var key: int = script.get_instance_id()
	var cached: Variant = _decor_cache.get(key)
	if cached is Dictionary and int((cached as Dictionary).get("len", -1)) == source.length():
		return ((cached as Dictionary).get("map") as Dictionary).get(property, [])
	var map: Dictionary = build_decor_map(source)
	_decor_cache[key] = {"len": source.length(), "map": map}
	return map.get(property, [])


## property name -> Array of decor dicts ({kind:"header", text, color} / {kind:"info", text}), from raw
## script source. Decor binds to the next `var` declaration; tooltips (`##`) and `@export_*` annotation
## lines may sit between them (the canonical emission order); anything else orphans the decor.
static func build_decor_map(source: String) -> Dictionary:
	var map: Dictionary = {}
	var pending: Array = []
	for raw_line: String in source.split("\n"):
		var line: String = raw_line.strip_edges()
		if line.begins_with("# @inspector_header "):
			pending.append(_parse_header_decor(line.substr(20).strip_edges()))
		elif line.begins_with("# @inspector_info "):
			pending.append({"kind": "info", "text": line.substr(18).strip_edges()})
		elif line == "# @inspector_required":
			pending.append({"kind": "required"})
		elif line.begins_with("var ") or (line.begins_with("@") and line.contains(" var ")):
			if not pending.is_empty():
				var var_name: String = _var_name_from_line(line)
				if not var_name.is_empty():
					map[var_name] = pending.duplicate()
				pending = []
		elif line.begins_with("#") or line.begins_with("@"):
			continue
		else:
			pending = []
	return map


## "Combat #e06666" -> {kind:"header", text:"Combat", color:"#e06666"}; a trailing token only counts as
## the accent when it is a full #rrggbb - anything else stays part of the title.
static func _parse_header_decor(text: String) -> Dictionary:
	var tokens: PackedStringArray = text.split(" ")
	var last: String = tokens[tokens.size() - 1] if tokens.size() > 1 else ""
	if last.length() == 7 and last.begins_with("#") and last.substr(1).is_valid_hex_number():
		return {"kind": "header", "text": text.substr(0, text.length() - last.length()).strip_edges(), "color": last}
	return {"kind": "header", "text": text, "color": ""}


## The declared name out of "var health: int = 100" or "@export(...) var health := 1".
static func _var_name_from_line(line: String) -> String:
	var after: String = line.substr(line.find("var ") + 4).strip_edges()
	for terminator: String in [":", "=", " "]:
		var at: int = after.find(terminator)
		if at != -1:
			after = after.substr(0, at)
	return after.strip_edges()


## Best-effort resource-class guard for the TYPE_OBJECT drawers. A generated sheet only ever pairs the marker
## with the right resource type (the compiler type-gates emission), but a hand-edited marker could mismatch -
## e.g. a curve_editor on a Texture2D var. A null value (the default) is allowed (can't tell yet, and the
## picker is harmless); a present value of the wrong class fails, so we degrade to a plain field.
static func _value_is_kind(object: Object, name: String, type_class: String) -> bool:
	if object == null:
		return true
	var value: Variant = object.get(name)
	if value == null:
		return true
	return value is Object and (value as Object).is_class(type_class)

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


## Vector2 min-max range: drag either handle to set the low (x) / high (y) end.
class MinMaxSliderProperty:
	extends EditorProperty
	var _slider: EventSheetDrawerWidgets.DrawerMinMaxSlider

	func _init(min_value: float, max_value: float) -> void:
		_slider = EventSheetDrawerWidgets.DrawerMinMaxSlider.new(min_value, max_value)
		_slider.value_changed.connect(_on_changed)
		add_child(_slider)
		add_focusable(_slider)

	func _on_changed(v: Vector2) -> void:
		emit_changed(get_edited_property(), v)

	func _update_property() -> void:
		_slider.set_value(get_edited_object().get(get_edited_property()))


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


## Texture preview: a Texture2D resource picker above a live thumbnail.
class TexturePreviewProperty:
	extends EditorProperty
	var _preview: EventSheetDrawerWidgets.DrawerTexturePreview
	var _picker: EditorResourcePicker

	func _init() -> void:
		var box: VBoxContainer = VBoxContainer.new()
		_picker = EditorResourcePicker.new()
		_picker.base_type = "Texture2D"
		_picker.resource_changed.connect(_on_resource_changed)
		box.add_child(_picker)
		_preview = EventSheetDrawerWidgets.DrawerTexturePreview.new()
		box.add_child(_preview)
		add_child(box)
		set_bottom_editor(box)

	func _on_resource_changed(resource: Resource) -> void:
		_preview.set_texture(resource as Texture2D)
		emit_changed(get_edited_property(), resource)

	func _update_property() -> void:
		var value: Variant = get_edited_object().get(get_edited_property())
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
