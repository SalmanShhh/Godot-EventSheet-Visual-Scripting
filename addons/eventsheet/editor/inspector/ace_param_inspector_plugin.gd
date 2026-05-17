# EventSheet — ACE Param Inspector Plugin
# EditorInspectorPlugin scaffold that will render custom widgets for
# ACE-driven parameters when an EventSheetExposedNode is selected.
#
# Registration: call add_inspector_plugin() in the main EditorPlugin._enter_tree().
# Deregistration: call remove_inspector_plugin() in _exit_tree().
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
## Can add header elements, category separators, or additional info labels.
func _parse_begin(object: Object) -> void:
	if not (object is EventSheetExposedNode):
		return
	var label: EditorProperty = _make_info_property("EventSheet ACE Parameters")
	add_custom_control(label)

## Called for each individual property.
## Return true to suppress the default widget and add a custom one instead.
func _parse_property(object: Object, type: Variant.Type, name: String,
		hint_type: PropertyHint, hint_string: String,
		usage_flags: int, wide: bool) -> bool:
	if not (object is EventSheetExposedNode):
		return false
	# Future: add per-property custom widgets here (color pickers, node paths, etc.)
	# For now, fall through so Godot renders the default widget.
	return false

# ── Helpers ──────────────────────────────────────────────────────────────────

## Build a simple read-only info label styled as an EditorProperty.
static func _make_info_property(text: String) -> EditorProperty:
	var prop := EditorProperty.new()
	prop.label = text
	var label := Label.new()
	label.text = ""
	prop.add_child(label)
	return prop
