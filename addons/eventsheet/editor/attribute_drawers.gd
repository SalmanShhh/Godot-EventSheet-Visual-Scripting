# Godot EventSheets — Inspector attribute drawers (Tier 3, docs/INSPECTOR-ATTRIBUTES-SPEC.md)
#
# One EditorInspectorPlugin recognizes the `eventsheet:<drawer>` marker that the
# compiler bakes into @export_custom hint strings, and swaps in a richer editor
# control. THE DEGRADATION CONTRACT: generated scripts stay plain GDScript — without
# this plugin (or in exported games) the property renders as a normal field, so the
# parity covenant is untouched. v1 ships one drawer (progress_bar); the marker format
# is "eventsheet:progress_bar:<min>:<max>".
@tool
extends EditorInspectorPlugin
class_name EventSheetAttributeDrawers

func _can_handle(_object: Object) -> bool:
	return true  # cheap: the per-property marker check below does the real filtering

func _parse_property(_object: Object, type: Variant.Type, name: String, _hint_type: PropertyHint, hint_string: String, _usage_flags: int, _wide: bool) -> bool:
	var drawer: Dictionary = parse_drawer_hint(hint_string)
	if str(drawer.get("drawer", "")) != "progress_bar":
		return false
	if type != TYPE_INT and type != TYPE_FLOAT:
		return false
	add_property_editor(name, ProgressBarProperty.new(float(drawer.get("min", 0.0)), float(drawer.get("max", 100.0))))
	return true

## "eventsheet:progress_bar:0:200" -> {drawer, min, max}; anything else -> {}.
## Static + UI-free so the headless suite can pin the contract.
static func parse_drawer_hint(hint_string: String) -> Dictionary:
	if not hint_string.begins_with("eventsheet:"):
		return {}
	var parts: PackedStringArray = hint_string.split(":")
	var parsed: Dictionary = {"drawer": parts[1] if parts.size() > 1 else ""}
	if parts.size() > 2:
		parsed["min"] = parts[2].to_float()
	if parts.size() > 3:
		parsed["max"] = parts[3].to_float()
	return parsed

## A read-friendly bar + value readout; edits still flow through the spin slider Godot
## adds for the numeric type (the bar replaces only the default display).
class ProgressBarProperty:
	extends EditorProperty
	var _bar: ProgressBar = ProgressBar.new()

	func _init(min_value: float, max_value: float) -> void:
		_bar.min_value = min_value
		_bar.max_value = max_value
		_bar.show_percentage = false
		_bar.custom_minimum_size = Vector2(0.0, 14.0)
		add_child(_bar)
		read_only = false

	func _update_property() -> void:
		var value: Variant = get_edited_object().get(get_edited_property())
		_bar.value = float(value)
		_bar.tooltip_text = str(value)
