@tool
class_name EventSheetInspectorLooks
extends RefCounted

## The single source of truth for the "Inspector look" presets: the Variable dialog's
## dropdown, the Look Gallery's picture tiles, and the tests all read this table, so
## the three surfaces can never drift apart. Each preset maps to one structured
## attribute family the compiler emits and lifts canonically.
##
## types = the variable types the preset applies to (empty = any type);
## detail = the placeholder for the preset's one contextual field ("" = none);
## sentence = the gallery card's one-line explanation.
const PRESETS: Array[Dictionary] = [
	{"id": "file", "label": "File picker (project files)", "types": ["String"], "detail": "filters, e.g. *.ogg, *.wav", "sentence": "Pick a file from inside the project."},
	{"id": "global_file", "label": "File picker (any file on disk)", "types": ["String"], "detail": "filters, e.g. *.png", "sentence": "Pick a file from anywhere on the computer."},
	{"id": "dir", "label": "Folder picker (project)", "types": ["String"], "detail": "", "sentence": "Pick a folder from inside the project."},
	{"id": "global_dir", "label": "Folder picker (anywhere on disk)", "types": ["String"], "detail": "", "sentence": "Pick a folder from anywhere on the computer."},
	{"id": "suggestions", "label": "Dropdown with free typing (suggestions)", "types": ["String"], "detail": "choices, e.g. sword, bow, staff", "sentence": "A dropdown of suggestions - you can still type anything."},
	{"id": "flags", "label": "Checkbox flags (Fire, Ice…)", "types": ["int"], "detail": "labels, e.g. Fire:1, Ice:2", "sentence": "Several on/off boxes packed into one number."},
	{"id": "enum_values", "label": "Dropdown with numbers (Slow:30…)", "types": ["int"], "detail": "options, e.g. Slow:30, Fast:60", "sentence": "A dropdown where each word stands for a number."},
	{"id": "layers_2d_physics", "label": "2D physics layers grid", "types": ["int"], "detail": "", "sentence": "The little grid of 2D physics layer toggles."},
	{"id": "layers_2d_render", "label": "2D render layers grid", "types": ["int"], "detail": "", "sentence": "The little grid of 2D render layer toggles."},
	{"id": "layers_2d_navigation", "label": "2D navigation layers grid", "types": ["int"], "detail": "", "sentence": "The little grid of 2D navigation layer toggles."},
	{"id": "layers_3d_physics", "label": "3D physics layers grid", "types": ["int"], "detail": "", "sentence": "The little grid of 3D physics layer toggles."},
	{"id": "layers_3d_render", "label": "3D render layers grid", "types": ["int"], "detail": "", "sentence": "The little grid of 3D render layer toggles."},
	{"id": "layers_3d_navigation", "label": "3D navigation layers grid", "types": ["int"], "detail": "", "sentence": "The little grid of 3D navigation layer toggles."},
	{"id": "layers_avoidance", "label": "Avoidance layers grid", "types": ["int"], "detail": "", "sentence": "The little grid of avoidance layer toggles."},
	{"id": "node_path", "label": "Node picker with a type filter", "types": ["NodePath"], "detail": "types, e.g. Button, TouchScreenButton", "sentence": "Pick a scene node, limited to the types you list."},
	{"id": "preset_password", "label": "Password field (dots, not text)", "types": ["String"], "detail": "", "sentence": "Typed text shows as dots."},
	{"id": "preset_expression", "label": "Expression field (math input)", "types": ["String"], "detail": "", "sentence": "A field meant for a math expression."},
	{"id": "preset_link", "label": "Linked axes (one slider drives all)", "types": ["Vector2", "Vector2i", "Vector3", "Vector3i", "Vector4", "Vector4i"], "detail": "", "sentence": "Drag one axis and the others follow."},
	{"id": "easing_attenuation", "label": "Easing curve for attenuation", "types": ["float"], "detail": "", "sentence": "An ease curve tuned for falloff/attenuation."},
	{"id": "easing_positive", "label": "Easing curve (positive only)", "types": ["float"], "detail": "", "sentence": "An ease curve that never dips negative."},
	{"id": "storage", "label": "Saved but hidden (storage)", "types": [], "detail": "", "sentence": "Saved with the scene but not shown in the Inspector."},
]


## The presets that apply to a variable type - THE filter the dropdown, the gallery,
## and the tests share (empty types list on a preset = applies to any type).
static func for_type(type_name: String) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for preset: Dictionary in PRESETS:
		var preset_types: Array = preset.get("types", [])
		if preset_types.is_empty() or preset_types.has(type_name):
			output.append(preset)
	return output


static func preset_by_id(look_id: String) -> Dictionary:
	for preset: Dictionary in PRESETS:
		if str(preset.get("id")) == look_id:
			return preset
	return {}


## A non-interactive miniature of the Inspector widget a look produces - the gallery's
## "choose by picture" tiles. Every control is disabled/ignored so the tile button
## underneath receives the click. "" builds the plain default field.
static func build_preview(look_id: String) -> Control:
	var preview: Control = _build_preview_inner(look_id)
	_ignore_mouse(preview)
	return preview


static func _build_preview_inner(look_id: String) -> Control:
	match look_id:
		"file", "global_file":
			return _path_field("res://sfx/jump.ogg")
		"dir", "global_dir":
			return _path_field("res://levels/")
		"flags":
			var flags_row := HBoxContainer.new()
			for flag_spec: Array in [["Fire", true], ["Ice", false], ["Poison", true]]:
				var flag_check := CheckBox.new()
				flag_check.text = str(flag_spec[0])
				flag_check.button_pressed = bool(flag_spec[1])
				flag_check.disabled = true
				flags_row.add_child(flag_check)
			return flags_row
		"enum_values":
			var enum_option := OptionButton.new()
			enum_option.add_item("Slow (30)")
			enum_option.add_item("Fast (60)")
			enum_option.select(0)
			enum_option.disabled = true
			return enum_option
		"node_path":
			return _path_field("../Player")
		"suggestions":
			var suggestion_option := OptionButton.new()
			suggestion_option.add_item("sword")
			suggestion_option.add_item("bow")
			suggestion_option.add_item("(or type your own...)")
			suggestion_option.select(0)
			suggestion_option.disabled = true
			return suggestion_option
		"preset_password":
			var password_edit := LineEdit.new()
			password_edit.text = "hunter2"
			password_edit.secret = true
			password_edit.editable = false
			password_edit.custom_minimum_size = Vector2(150.0, 0.0)
			return password_edit
		"preset_expression":
			var expression_edit := LineEdit.new()
			expression_edit.text = "sin(time) * 4.0"
			expression_edit.editable = false
			expression_edit.custom_minimum_size = Vector2(150.0, 0.0)
			return expression_edit
		"preset_link":
			var link_box := VBoxContainer.new()
			for axis_value: float in [0.6, 0.6]:
				var axis_slider := HSlider.new()
				axis_slider.min_value = 0.0
				axis_slider.max_value = 1.0
				axis_slider.value = axis_value
				axis_slider.editable = false
				axis_slider.custom_minimum_size = Vector2(150.0, 0.0)
				link_box.add_child(axis_slider)
			var link_label := Label.new()
			link_label.text = "axes move together"
			link_label.add_theme_font_size_override("font_size", 10)
			link_label.modulate = Color(1.0, 1.0, 1.0, 0.6)
			link_box.add_child(link_label)
			return link_box
		"easing_attenuation":
			return _EasePreview.new(true)
		"easing_positive":
			return _EasePreview.new(false)
		"storage":
			var storage_label := Label.new()
			storage_label.text = "(saved, not shown)"
			storage_label.modulate = Color(1.0, 1.0, 1.0, 0.45)
			return storage_label
		_:
			if look_id.begins_with("layers_"):
				return _LayerGridPreview.new()
			var default_edit := LineEdit.new()
			default_edit.text = "100"
			default_edit.editable = false
			default_edit.custom_minimum_size = Vector2(150.0, 0.0)
			return default_edit


static func _path_field(path_text: String) -> Control:
	var path_row := HBoxContainer.new()
	var path_edit := LineEdit.new()
	path_edit.text = path_text
	path_edit.editable = false
	path_edit.custom_minimum_size = Vector2(130.0, 0.0)
	path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	path_row.add_child(path_edit)
	var browse_button := Button.new()
	browse_button.text = "..."
	browse_button.disabled = true
	path_row.add_child(browse_button)
	return path_row


static func _ignore_mouse(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)


## The Inspector's layer-matrix widget in miniature: two rows of toggle cells,
## a few lit, drawn directly (no per-cell Controls needed for a static preview).
class _LayerGridPreview:
	extends Control

	const CELL := 11.0
	const GAP := 2.0
	const LIT := [0, 3, 9, 12]


	func _init() -> void:
		custom_minimum_size = Vector2((CELL + GAP) * 8.0, (CELL + GAP) * 2.0)


	func _draw() -> void:
		var lit_color: Color = Color(0.38, 0.60, 0.92, 0.95)
		var off_color: Color = Color(1.0, 1.0, 1.0, 0.12)
		for cell_index in range(16):
			var column: int = cell_index % 8
			var row: int = int(cell_index / 8.0)
			var cell_rect := Rect2(column * (CELL + GAP), row * (CELL + GAP), CELL, CELL)
			draw_rect(cell_rect, lit_color if LIT.has(cell_index) else off_color)


## A tiny exponential-ease curve, the shape the Inspector's easing widget shows.
class _EasePreview:
	extends Control

	var _attenuation: bool = false


	func _init(attenuation: bool) -> void:
		_attenuation = attenuation
		custom_minimum_size = Vector2(110.0, 40.0)


	func _draw() -> void:
		var points: PackedVector2Array = []
		for step in range(25):
			var t: float = step / 24.0
			var eased: float = pow(t, 2.4)
			if _attenuation:
				eased = 1.0 - eased
			points.append(Vector2(t * size.x, size.y - eased * (size.y - 4.0) - 2.0))
		draw_polyline(points, Color(0.45, 0.75, 0.95, 0.95), 1.5, true)
