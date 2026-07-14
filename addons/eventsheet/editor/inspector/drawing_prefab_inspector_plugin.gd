# Godot EventSheets - DrawingPrefabResource Inspector (editor-only).
#
# Two things for a DrawingPrefabResource:
#   1. A live preview panel at the top of the Inspector (PreviewPanel) - you SEE the composed drawing while
#      you edit the steps below, re-rendered on the resource's `changed` signal.
#   2. A shape-aware editor for the `steps` array (StepsProperty / ShapeStepsEditor): instead of the generic
#      grid's opaque p1/p2/p3 columns, each step is a titled card whose fields match its shape - a circle
#      shows "Radius", a rect shows "Width"/"Height", a line shows "End X"/"End Y"/"Thickness", and so on.
#      The stored keys (kind, x, y, p1, p2, p3, color, texture) are unchanged, so the pack, the rasterizer,
#      and the .tres bytes are all untouched - this only relabels and lays out the SAME data.
# Both are cosmetic: without this plugin a prefab still edits as a plain steps table and draws identically.
@tool
class_name EventSheetDrawingPrefabInspector
extends EditorInspectorPlugin


func _can_handle(object: Object) -> bool:
	return object is DrawingPrefabResource


func _parse_begin(object: Object) -> void:
	if object is DrawingPrefabResource:
		add_custom_control(PreviewPanel.new(object as Resource))


## Claim the `steps` array with the shape-aware editor. This plugin is registered BEFORE the generic
## attribute-drawers plugin, so returning true here wins the property before the opaque p1/p2/p3 grid runs.
func _parse_property(object: Object, type: Variant.Type, name: String, _hint_type: PropertyHint, _hint_string: String, _usage_flags: int, _wide: bool) -> bool:
	if object is DrawingPrefabResource and name == "steps" and type == TYPE_ARRAY:
		add_property_editor(name, StepsProperty.new())
		return true
	return false


## The preview surface: a fixed-size raster of the prefab, scaled to fit the Inspector column. Re-rasterizes
## on the resource's `changed` signal (so editing a step updates the picture) and cleans up its connection
## when freed.
class PreviewPanel:
	extends PanelContainer

	var _resource: Resource = null
	var _rect: TextureRect = null

	func _init(resource: Resource) -> void:
		_resource = resource
		# Height tracks the raster's own aspect (384x200) at a typical inspector-column width, so the
		# preview is a compact card instead of a tall box with big empty letterbox bands above and below.
		custom_minimum_size = Vector2(0, 158)
		var margin: MarginContainer = MarginContainer.new()
		for side: String in ["left", "right", "top", "bottom"]:
			margin.add_theme_constant_override("margin_" + side, 4)
		add_child(margin)
		_rect = TextureRect.new()
		_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
		margin.add_child(_rect)
		if _resource != null and not _resource.changed.is_connected(_refresh):
			_resource.changed.connect(_refresh)

	func _ready() -> void:
		_refresh()

	func _exit_tree() -> void:
		if _resource != null and _resource.changed.is_connected(_refresh):
			_resource.changed.disconnect(_refresh)

	func _refresh() -> void:
		if _rect == null:
			return
		var steps: Variant = _resource.get("steps") if _resource != null else []
		if not (steps is Array):
			steps = []
		var bg: Color = Color(0.11, 0.12, 0.15, 1.0)
		_rect.texture = EventSheetDrawingPrefabPreview.rasterize_texture(steps as Array, Vector2i(384, 200), bg)


## The EditorProperty wrapper around ShapeStepsEditor: reads the Array off the resource, writes edits back
## via emit_changed, and pokes the resource's `changed` signal so the PreviewPanel re-renders live (mirrors
## how the generic table drawer refreshes prefab previews on every cell edit).
class StepsProperty:
	extends EditorProperty

	var _editor: ShapeStepsEditor = null

	func _init() -> void:
		_editor = ShapeStepsEditor.new()
		_editor.value_changed.connect(_on_changed)
		add_child(_editor)
		set_bottom_editor(_editor)

	func _on_changed(steps: Array) -> void:
		emit_changed(get_edited_property(), steps)
		# A plain property write does not fire the resource's `changed` signal, so preview panels
		# (and the FileSystem thumbnail) would not repaint. Emit it explicitly on each edit.
		var edited: Object = get_edited_object()
		if edited is Resource:
			(edited as Resource).emit_changed()

	func _update_property() -> void:
		var incoming: Variant = get_edited_object().get(get_edited_property())
		if not (incoming is Array):
			incoming = []
		# Skip the write-back the emit_changed round-trip causes (values already match) so an open
		# SpinBox / picker keeps focus while you type.
		if (incoming as Array) == _editor.get_steps():
			return
		_editor.set_steps(incoming as Array)


## The shape-aware steps list: one titled card per step, its fields chosen by the step's `kind`. Editing a
## value updates the backing Dictionary in place and emits; changing the kind, adding, removing, or reordering
## rebuilds the list. Deliberately DrawingPrefab-specific (it knows the shape vocabulary), so it lives here
## rather than in the generic drawer widgets.
class ShapeStepsEditor:
	extends VBoxContainer
	signal value_changed(value: Array)

	const KINDS: Array[String] = ["circle", "ring", "rect", "line", "cone", "stamp"]
	## Per-shape fields, in display order. `key` is the frozen storage slot (p1/p2/p3/texture); `label` is
	## the human title shown above/beside it; `kind` picks the editor ("num" default, "text" for a path).
	## x, y (offset) and color are common to every shape and appended separately.
	const SHAPE_FIELDS: Dictionary = {
		"circle": [{"key": "p1", "label": "Radius"}],
		"ring": [{"key": "p1", "label": "Radius"}, {"key": "p2", "label": "Thickness"}],
		"rect": [{"key": "p1", "label": "Width"}, {"key": "p2", "label": "Height"}],
		"line": [{"key": "p1", "label": "End X"}, {"key": "p2", "label": "End Y"}, {"key": "p3", "label": "Thickness"}],
		"cone": [{"key": "p1", "label": "Facing"}, {"key": "p2", "label": "FOV"}, {"key": "p3", "label": "Radius"}],
		"stamp": [{"key": "p1", "label": "Scale"}, {"key": "p2", "label": "Spin"}, {"key": "texture", "label": "Texture", "kind": "text"}],
	}

	var _steps: Array = []
	var _add_button: Button = null

	func _init() -> void:
		add_theme_constant_override("separation", 4)
		_add_button = Button.new()
		_add_button.text = "+ Add shape"
		_add_button.tooltip_text = "Add a step. Pick its shape and only that shape's fields appear (Radius, Width, End X, etc.)."
		_add_button.pressed.connect(_on_add)
		_rebuild()

	func set_steps(steps: Array) -> void:
		_steps = []
		for step: Variant in steps:
			if step is Dictionary:
				_steps.append((step as Dictionary).duplicate())
		_rebuild()

	func get_steps() -> Array:
		return _steps.duplicate(true)

	func _on_add() -> void:
		# A fresh step defaults to a visible filled circle so the preview shows something immediately. All
		# storage slots are seeded so the Dictionary shape matches what the rasterizer and round-trip expect.
		_steps.append({"kind": "circle", "x": 0.0, "y": 0.0, "p1": 12.0, "p2": 0.0, "p3": 0.0, "color": "#ffffff", "texture": ""})
		_rebuild()
		value_changed.emit(get_steps())

	func _rebuild() -> void:
		for child: Node in get_children():
			remove_child(child)
			child.queue_free()
		if _steps.is_empty():
			var empty: Label = Label.new()
			empty.text = "No shapes yet. Add one and pick its shape."
			empty.add_theme_font_size_override("font_size", 11)
			empty.modulate = Color(0.72, 0.76, 0.84)
			add_child(empty)
		for index: int in range(_steps.size()):
			add_child(_build_step_card(index))
		add_child(_add_button)

	## One step as a titled card: a header row (shape dropdown + reorder / remove) over a wrapping field row
	## whose fields are chosen by the shape - so "Radius" / "Width" / "End X" are titled per shape, never p1.
	func _build_step_card(index: int) -> Control:
		var step: Dictionary = _steps[index]
		var kind: String = str(step.get("kind", "circle"))
		if not SHAPE_FIELDS.has(kind):
			kind = "circle"
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color(1, 1, 1, 0.04)
		style.set_corner_radius_all(4)
		style.set_content_margin_all(5)
		style.border_width_left = 2
		style.border_color = Color(0.36, 0.66, 1.0, 0.5)
		var card: PanelContainer = PanelContainer.new()
		card.add_theme_stylebox_override("panel", style)
		var body: VBoxContainer = VBoxContainer.new()
		body.add_theme_constant_override("separation", 3)
		card.add_child(body)
		# Header: the shape dropdown drives which fields show; reorder + remove sit at the end.
		var header: HBoxContainer = HBoxContainer.new()
		header.add_theme_constant_override("separation", 4)
		var kind_opt: OptionButton = OptionButton.new()
		kind_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		kind_opt.tooltip_text = "The shape drawn by this step. Circle is filled; Ring is an outline (its Thickness)."
		for kind_index: int in range(KINDS.size()):
			kind_opt.add_item(KINDS[kind_index].capitalize())
			if KINDS[kind_index] == kind:
				kind_opt.select(kind_index)
		kind_opt.item_selected.connect(func(idx: int) -> void:
			if idx >= 0 and idx < KINDS.size():
				step["kind"] = KINDS[idx]
				_rebuild()
				value_changed.emit(get_steps()))
		header.add_child(kind_opt)
		var up_button: Button = Button.new()
		up_button.text = "▲"
		up_button.tooltip_text = "Draw this shape earlier (higher in the list draws first, underneath)"
		up_button.disabled = index == 0
		up_button.pressed.connect(_on_move_up.bind(index))
		header.add_child(up_button)
		var remove_button: Button = Button.new()
		remove_button.text = "✕"
		remove_button.tooltip_text = "Remove this shape"
		remove_button.pressed.connect(_on_remove.bind(index))
		header.add_child(remove_button)
		body.add_child(header)
		# Fields: shape-specific first, then the common Offset X / Y and Color. HFlow wraps them in a narrow
		# Inspector instead of overflowing off the right edge.
		var fields: HFlowContainer = HFlowContainer.new()
		fields.add_theme_constant_override("h_separation", 8)
		fields.add_theme_constant_override("v_separation", 3)
		for field: Variant in SHAPE_FIELDS[kind]:
			var field_dict: Dictionary = field as Dictionary
			fields.add_child(_titled_field(str(field_dict.get("label", "")), _make_field(step, field_dict)))
		fields.add_child(_titled_field("Offset X", _make_number(step, "x")))
		fields.add_child(_titled_field("Offset Y", _make_number(step, "y")))
		fields.add_child(_titled_field("Color", _make_color(step)))
		body.add_child(fields)
		return card

	## A small muted title beside its editor, so a field reads as "Radius [ 12 ]" - the "titled on the row"
	## look, per shape.
	func _titled_field(label_text: String, control: Control) -> Control:
		var box: HBoxContainer = HBoxContainer.new()
		box.add_theme_constant_override("separation", 3)
		var label: Label = Label.new()
		label.text = label_text
		label.add_theme_font_size_override("font_size", 10)
		label.modulate = Color(0.72, 0.76, 0.84)
		box.add_child(label)
		box.add_child(control)
		return box

	func _make_field(step: Dictionary, field: Dictionary) -> Control:
		if str(field.get("kind", "num")) == "text":
			var key: String = str(field.get("key"))
			var edit: LineEdit = LineEdit.new()
			edit.custom_minimum_size = Vector2(120.0, 0.0)
			edit.placeholder_text = "res://path.png"
			edit.text = str(step.get(key, ""))
			edit.text_changed.connect(func(text: String) -> void:
				step[key] = text
				value_changed.emit(get_steps()))
			return edit
		return _make_number(step, str(field.get("key")))

	func _make_number(step: Dictionary, key: String) -> Control:
		var spin: SpinBox = SpinBox.new()
		spin.allow_greater = true
		spin.allow_lesser = true
		spin.step = 0.1
		spin.custom_minimum_size = Vector2(64.0, 0.0)
		spin.value = float(step.get(key, 0.0))
		spin.value_changed.connect(func(v: float) -> void:
			step[key] = v
			value_changed.emit(get_steps()))
		return spin

	func _make_color(step: Dictionary) -> Control:
		var swatch: ColorPickerButton = ColorPickerButton.new()
		swatch.custom_minimum_size = Vector2(44.0, 0.0)
		swatch.color = Color.from_string(str(step.get("color", "")), Color.WHITE)
		swatch.color_changed.connect(func(picked: Color) -> void:
			step["color"] = "#" + picked.to_html(picked.a < 1.0)
			value_changed.emit(get_steps()))
		return swatch

	func _on_move_up(index: int) -> void:
		if index <= 0 or index >= _steps.size():
			return
		var moved: Dictionary = _steps[index]
		_steps.remove_at(index)
		_steps.insert(index - 1, moved)
		_rebuild()
		value_changed.emit(get_steps())

	func _on_remove(index: int) -> void:
		if index < 0 or index >= _steps.size():
			return
		_steps.remove_at(index)
		_rebuild()
		value_changed.emit(get_steps())
