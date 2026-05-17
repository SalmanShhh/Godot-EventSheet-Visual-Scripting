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
var _resolver: ParamDefaultResolver = null
var _undo_redo: UndoRedo = null
var _sheet: EventSheetResource = null
var _provider_filter: Dictionary = {}
var _connected_store: EditorParamStore = null
## Cache of (property_name -> {provider_id, ace_id, param_id, type}) built in setup().
var _prop_map: Dictionary = {}

## Attach the registry and param store, then rebuild the property map.
func setup(registry: EventSheetACERegistry, param_store: EditorParamStore,
		sheet: EventSheetResource = null, resolver: ParamDefaultResolver = null) -> void:
	_registry = registry
	if _connected_store != null and _connected_store != param_store:
		if _connected_store.override_changed.is_connected(_on_store_changed):
			_connected_store.override_changed.disconnect(_on_store_changed)
		if _connected_store.override_removed.is_connected(_on_store_removed):
			_connected_store.override_removed.disconnect(_on_store_removed)
		if _connected_store.overrides_cleared.is_connected(_on_store_cleared):
			_connected_store.overrides_cleared.disconnect(_on_store_cleared)
	_param_store = param_store
	_connected_store = param_store
	_sheet = sheet
	_resolver = resolver if resolver != null else ParamDefaultResolver.new()
	_resolver.set_param_store(_param_store)
	if _param_store != null and not _param_store.override_changed.is_connected(_on_store_changed):
		_param_store.override_changed.connect(_on_store_changed)
	if _param_store != null and not _param_store.override_removed.is_connected(_on_store_removed):
		_param_store.override_removed.connect(_on_store_removed)
	if _param_store != null and not _param_store.overrides_cleared.is_connected(_on_store_cleared):
		_param_store.overrides_cleared.connect(_on_store_cleared)
	_rebuild_prop_map()
	notify_property_list_changed()

## Rebuild the prop_map from all editor_exposed definitions in the registry.
func _rebuild_prop_map() -> void:
	_prop_map.clear()
	if _registry == null:
		return
	var active_providers: Dictionary = _compute_active_provider_ids()
	for definition: ACEDefinition in _registry.get_all_definitions():
		if not definition.editor_exposed:
			continue
		if not active_providers.is_empty() and not active_providers.has(definition.provider_id):
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
				"hint": int(param_dict.get("property_hint", definition.property_hint)),
				"hint_string": str(param_dict.get("hint_string", definition.hint_string)),
				"widget_hint": str(param_dict.get("widget_hint", definition.widget_hint)),
				"display_name": str(param_dict.get("display_name", param_id)),
				"category": definition.get_inspector_category(),
				"param_meta": param_dict.duplicate(true)
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
	var provider_id: String = str(entry.get("provider_id", ""))
	var ace_id: String = str(entry.get("ace_id", ""))
	var param_id: String = str(entry.get("param_id", ""))
	return _resolver.resolve(provider_id, ace_id, param_id, entry.get("param_meta", {}), null)

## Called by Godot's property system to set a property value.
func _set(property: StringName, value: Variant) -> bool:
	var key: String = str(property)
	if not _prop_map.has(key):
		return false
	var entry: Dictionary = _prop_map[key]
	if _param_store == null:
		return false
	var provider_id: String = str(entry.get("provider_id", ""))
	var ace_id: String = str(entry.get("ace_id", ""))
	var param_id: String = str(entry.get("param_id", ""))
	var has_previous: bool = _param_store.has_param(provider_id, ace_id, param_id)
	var previous_value: Variant = _param_store.get_param(provider_id, ace_id, param_id, null)
	if has_previous and previous_value == value:
		return true
	if _undo_redo != null:
		var action_label: String = "Set EventSheet param %s/%s/%s" % [provider_id, ace_id, param_id]
		_undo_redo.create_action(action_label)
		_undo_redo.add_do_method(self, "_set_store_param", provider_id, ace_id, param_id, value)
		if has_previous:
			_undo_redo.add_undo_method(self, "_set_store_param", provider_id, ace_id, param_id, previous_value)
		else:
			_undo_redo.add_undo_method(self, "_clear_store_param", provider_id, ace_id, param_id)
		_undo_redo.commit_action()
	else:
		_set_store_param(provider_id, ace_id, param_id, value)
	param_changed.emit(
		provider_id,
		ace_id,
		param_id,
		value
	)
	return true

## Trigger a full refresh after the registry is hot-reloaded.
func on_registry_refreshed() -> void:
	_rebuild_prop_map()
	notify_property_list_changed()

func set_undo_redo(undo_redo: UndoRedo) -> void:
	_undo_redo = undo_redo

func set_context_sheet(sheet: EventSheetResource) -> void:
	_sheet = sheet
	_rebuild_prop_map()
	notify_property_list_changed()

func set_provider_filter(provider_ids: PackedStringArray) -> void:
	_provider_filter.clear()
	for provider_id in provider_ids:
		if provider_id.is_empty():
			continue
		_provider_filter[provider_id] = true
	_rebuild_prop_map()
	notify_property_list_changed()

func _set_store_param(provider_id: String, ace_id: String, param_id: String, value: Variant) -> void:
	if _param_store == null:
		return
	_param_store.set_param(provider_id, ace_id, param_id, value)

func _clear_store_param(provider_id: String, ace_id: String, param_id: String) -> void:
	if _param_store == null:
		return
	_param_store.clear_param(provider_id, ace_id, param_id)

func _compute_active_provider_ids() -> Dictionary:
	if not _provider_filter.is_empty():
		return _provider_filter.duplicate()
	var active_providers: Dictionary = {}
	if _sheet == null:
		return active_providers
	for event_entry: Variant in _sheet.events:
		_collect_providers_from_resource(event_entry, active_providers)
	return active_providers

func _collect_providers_from_resource(entry: Variant, providers: Dictionary) -> void:
	if entry is EventRow:
		var row: EventRow = entry as EventRow
		if row.trigger != null and not row.trigger.provider_id.is_empty():
			providers[row.trigger.provider_id] = true
		for condition in row.conditions:
			if condition is ACECondition and not (condition as ACECondition).provider_id.is_empty():
				providers[(condition as ACECondition).provider_id] = true
		for action in row.actions:
			if action is ACEAction and not (action as ACEAction).provider_id.is_empty():
				providers[(action as ACEAction).provider_id] = true
		for child in row.sub_events:
			_collect_providers_from_resource(child, providers)
	elif entry is EventGroup:
		var group: EventGroup = entry as EventGroup
		var children: Array = group.events if not group.events.is_empty() else group.rows
		for child_entry in children:
			_collect_providers_from_resource(child_entry, providers)

func _on_store_changed(_provider_id: String, _ace_id: String, _param_id: String, _value: Variant) -> void:
	notify_property_list_changed()

func _on_store_removed(_provider_id: String, _ace_id: String, _param_id: String) -> void:
	notify_property_list_changed()

func _on_store_cleared() -> void:
	notify_property_list_changed()

static func _make_prop_key(provider_id: String, ace_id: String, param_id: String) -> String:
	return "%s/%s/%s" % [provider_id, ace_id, param_id]
