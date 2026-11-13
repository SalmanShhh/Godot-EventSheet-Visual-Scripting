@tool
extends EventSheetInspectorLook

## Texture preview
## A bigger picture of the texture under the slot.

## The kinds of property this look can be put on.
@export var works_on: String = "Texture2D"

## The sentence the preview card says under a variable that wears this look.
const PREVIEW_SENTENCE := "Shown with a texture preview."

var _preview: Control
var _picker: EditorResourcePicker


func _look_built() -> void:
	_picker = EditorResourcePicker.new()
	_picker.base_type = "Texture2D"
	_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_picker.resource_changed.connect(_on_resource_changed)
	_preview = EventSheetAttributeDrawers.widgets().DrawerTexturePreview.new()
	add_under_field(EventSheetLookStyle.boxed(_picker), _preview)
	add_focusable(_picker)


func _value_shown(value: Variant) -> void:
	_picker.edited_resource = value as Resource
	_preview.call("set_texture", value as Texture2D)


func _on_resource_changed(resource: Resource) -> void:
	_preview.call("set_texture", resource as Texture2D)
	set_field_value(resource)
