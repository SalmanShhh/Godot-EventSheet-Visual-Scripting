# EventSheet — EventSheetExposedNode
# A @tool Node that surfaces ACE-driven editor-exposed parameters in the Godot
# inspector via _get_property_list() / _get() / _set().  This avoids static
# @export declarations for generated params and makes them feel like native
# Godot properties.
#
# Usage:
#   var node := EventSheetExposedNode.new()
#   node.setup(ace_registry, param_store)
#   add_child(node)           # attach so inspector picks it up
#   # or inspect it directly in the editor
@tool
class_name EventSheetExposedNode
extends Node

## Emitted whenever a param value is changed through the inspector.
signal param_changed(provider_id: String, ace_id: String, param_id: String, value: Variant)

var _registry: EventSheetACERegistry = null
var _param_store: EditorParamStore = null
## Cache of (property_name -> {provider_id, ace_id, param_id, type}) built in setup().
var _prop_map: Dictionary = {}

## Attach the registry and param store, then rebuild the property map.
func setup(registry: EventSheetACERegistry, param_store: EditorParamStore) -> void:
	_registry = registry
	_param_store = param_store
	_rebuild_prop_map()
	notify_property_list_changed()

## Rebuild the prop_map from all editor_exposed definitions in the registry.
func _rebuild_prop_map() -> void:
	_prop_map.clear()
	if _registry == null:
		return
	for definition: ACEDefinition in _registry.get_all_definitions():
		if not definition.editor_exposed:
			continue
		for parameter: Variant in definition.parameters:
			if not (parameter is Dictionary):
				continue
			var param_dict: Dictionary = parameter as Dictionary
			var param_id: String = str(param_dict.get("id", ""))
			if param_id.is_empty():
				continue
			var prop_key: String = _make_prop_key(definition.provider_id, definition.id, param_id)
			_prop_map[prop_key] = {
				"provider_id": definition.provider_id,
				"ace_id": definition.id,
				"param_id": param_id,
				"type": int(param_dict.get("type", TYPE_NIL)),
				"hint": definition.property_hint,
				"hint_string": definition.hint_string,
				"display_name": str(param_dict.get("display_name", param_id)),
				"category": definition.get_inspector_category()
			}

## Called by Godot's property system to list exposed properties.
func _get_property_list() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if _prop_map.is_empty():
		return result
	var seen_categories: Dictionary = {}
	for prop_key: String in _prop_map.keys():
		var entry: Dictionary = _prop_map[prop_key]
		var category: String = str(entry.get("category", "EventSheet"))
		if not seen_categories.has(category):
			result.append({
				"name": category,
				"type": TYPE_NIL,
				"usage": PROPERTY_USAGE_CATEGORY
			})
			seen_categories[category] = true
		result.append({
			"name": prop_key,
			"type": int(entry.get("type", TYPE_NIL)),
			"hint": int(entry.get("hint", PROPERTY_HINT_NONE)),
			"hint_string": str(entry.get("hint_string", "")),
			"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR
		})
	return result

## Called by Godot's property system to get a property value.
func _get(property: StringName) -> Variant:
	var key: String = str(property)
	if not _prop_map.has(key):
		return null
	var entry: Dictionary = _prop_map[key]
	if _param_store == null:
		return null
	return _param_store.get_param(
		str(entry.get("provider_id", "")),
		str(entry.get("ace_id", "")),
		str(entry.get("param_id", "")),
		null
	)

## Called by Godot's property system to set a property value.
func _set(property: StringName, value: Variant) -> bool:
	var key: String = str(property)
	if not _prop_map.has(key):
		return false
	var entry: Dictionary = _prop_map[key]
	if _param_store == null:
		return false
	_param_store.set_param(
		str(entry.get("provider_id", "")),
		str(entry.get("ace_id", "")),
		str(entry.get("param_id", "")),
		value
	)
	param_changed.emit(
		str(entry.get("provider_id", "")),
		str(entry.get("ace_id", "")),
		str(entry.get("param_id", "")),
		value
	)
	return true

## Trigger a full refresh after the registry is hot-reloaded.
func on_registry_refreshed() -> void:
	_rebuild_prop_map()
	notify_property_list_changed()

static func _make_prop_key(provider_id: String, ace_id: String, param_id: String) -> String:
	return "%s/%s/%s" % [provider_id, ace_id, param_id]
