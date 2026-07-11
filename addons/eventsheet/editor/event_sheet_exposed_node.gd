# EventSheet - EventSheetExposedNode
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
## Emitted when a SELECTED-ROW param is edited in the inspector (per-row scope). The dock
## performs the actual undoable write - this node never mutates sheet resources itself.
signal row_param_changed(target: Resource, param_id: String, value: Variant)

var _registry: EventSheetACERegistry = null
var _param_store: EditorParamStore = null
var _resolver: ParamDefaultResolver = null
var _undo_redo_adapter: EventSheetUndoRedoAdapter = EventSheetUndoRedoAdapter.new()
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
	if resolver != null:
		_resolver = resolver
	elif _resolver == null:
		_resolver = ParamDefaultResolver.new()
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
	if not _row_prop_map.is_empty():
		result.append({"name": "Selected Cell", "type": TYPE_NIL, "usage": PROPERTY_USAGE_CATEGORY})
		for row_key: String in _row_prop_map.keys():
			var row_entry: Dictionary = _row_prop_map[row_key]
			result.append({
				"name": row_key,
				"type": int(row_entry.get("type", TYPE_NIL)),
				"hint": PROPERTY_HINT_NONE,
				"hint_string": "",
				"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR
			})
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
	if _row_prop_map.has(key) and _row_target != null:
		var row_entry: Dictionary = _row_prop_map[key]
		var params: Dictionary = _row_target.get("params")
		return params.get(row_entry.get("param_id"), (row_entry.get("param_meta", {}) as Dictionary).get("default_value"))
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
	if _row_prop_map.has(key) and _row_target != null:
		row_param_changed.emit(_row_target, str((_row_prop_map[key] as Dictionary).get("param_id")), value)
		return true
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
	if _undo_redo_adapter.has_manager():
		var action_label: String = "Set EventSheet param %s/%s/%s" % [provider_id, ace_id, param_id]
		_undo_redo_adapter.create_action(action_label)
		_undo_redo_adapter.add_do_method(self, "_set_store_param", [provider_id, ace_id, param_id, value])
		if has_previous:
			_undo_redo_adapter.add_undo_method(self, "_set_store_param", [provider_id, ace_id, param_id, previous_value])
		else:
			_undo_redo_adapter.add_undo_method(self, "_clear_store_param", [provider_id, ace_id, param_id])
		_undo_redo_adapter.commit_action()
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

# ── Per-row scope: the SELECTED condition/trigger/action's params as live properties ──
const ROW_PROP_PREFIX := "selected_ace/"
var _row_target: Resource = null
var _row_prop_map: Dictionary = {}


## Points the "Selected ACE" inspector section at a condition/trigger/action resource
## (null clears it). Param metadata (types, widget hints) comes from the registry
## definition when available; otherwise types derive from the current values.
func set_row_context(target: Resource) -> void:
	_row_target = target if (target is ACECondition or target is ACEAction) else null
	_row_prop_map.clear()
	if _row_target != null:
		var definition: ACEDefinition = null
		if _registry != null:
			definition = _registry.find_definition(_row_target.get("provider_id"), _row_target.get("ace_id"))
		var params: Dictionary = _row_target.get("params")
		if definition != null:
			for parameter: Variant in definition.parameters:
				if parameter is Dictionary and not str((parameter as Dictionary).get("id", "")).is_empty():
					var param_id: String = str((parameter as Dictionary).get("id", ""))
					_row_prop_map[ROW_PROP_PREFIX + param_id] = {
						"param_id": param_id,
						"type": int((parameter as Dictionary).get("type", TYPE_NIL)),
						# @ace_param_hint values ("expression"…) double as widget hints, so
						# ƒx params get the expression editor in the Inspector too. (An
						# explicit empty check: get()'s fallback only fires on MISSING keys.)
						"widget_hint": str((parameter as Dictionary).get("widget_hint", "")) if not str((parameter as Dictionary).get("widget_hint", "")).is_empty() else str((parameter as Dictionary).get("hint", "")),
						"param_meta": (parameter as Dictionary).duplicate(true)
					}
		for param_id: Variant in params.keys():
			var key: String = ROW_PROP_PREFIX + str(param_id)
			if not _row_prop_map.has(key):
				_row_prop_map[key] = {
					"param_id": str(param_id),
					"type": typeof(params[param_id]),
					"widget_hint": "",
					"param_meta": {}
				}
	notify_property_list_changed()


## The prop-map entry behind an inspector property name ({} when unknown). Used by the
## inspector plugin to pick widget_hint-specific editors.
func get_property_entry(property_name: String) -> Dictionary:
	if _row_prop_map.has(property_name):
		return _row_prop_map[property_name]
	return _prop_map.get(property_name, {})


func set_undo_redo_manager(undo_redo: Variant) -> void:
	_undo_redo_adapter.set_manager(undo_redo)


func set_undo_redo(undo_redo: Variant) -> void:
	set_undo_redo_manager(undo_redo)


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
