@tool
extends EventSheetInspectorLook

## Curve preview
## A picture of the curve in the slot, drawn under it (an empty slot draws nothing). Its points are shaped in Godot's own curve editor.

## The kinds of property this look can be put on.
@export var works_on: String = "Curve"

## The sentence the preview card says under a variable that wears this look.
const PREVIEW_SENTENCE := "Shown with a curve preview."

var _preview: Control
var _picker: EditorResourcePicker


func _look_built() -> void:
	_picker = EditorResourcePicker.new()
	_picker.base_type = "Curve"
	_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_picker.resource_changed.connect(_on_resource_changed)
	_preview = EventSheetAttributeDrawers.widgets().DrawerCurvePreview.new()
	_preview.call("make_clickable")
	_preview.connect("pressed", _on_picture_pressed)
	add_under_field(EventSheetLookStyle.boxed(_picker), _preview)
	add_focusable(_picker)


func _value_shown(value: Variant) -> void:
	_picker.edited_resource = value as Resource
	_preview.call("set_curve", value as Curve)


func _on_resource_changed(resource: Resource) -> void:
	_preview.call("set_curve", resource as Curve)
	set_field_value(resource)


## A click on the picture opens the curve in Godot's own curve editor, as a click on the slot does.
func _on_picture_pressed() -> void:
	var curve: Variant = field_value()
	if curve is Resource:
		emit_signal("resource_selected", str(get_edited_property()), curve)
