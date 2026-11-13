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
	var box: VBoxContainer = VBoxContainer.new()
	_picker = EditorResourcePicker.new()
	_picker.base_type = "Curve"
	_picker.resource_changed.connect(_on_resource_changed)
	box.add_child(_picker)
	_preview = EventSheetAttributeDrawers.widgets().DrawerCurvePreview.new()
	box.add_child(_preview)
	add_child(box)
	set_bottom_editor(box)


func _value_shown(value: Variant) -> void:
	_picker.edited_resource = value as Resource
	_preview.call("set_curve", value as Curve)


func _on_resource_changed(resource: Resource) -> void:
	_preview.call("set_curve", resource as Curve)
	set_field_value(resource)
