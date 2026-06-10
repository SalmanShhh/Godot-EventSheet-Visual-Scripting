# EventSheet — ParamDefaultResolver
# Resolves the effective value for an ACE parameter using this priority chain:
#   1. Per-row override (supplied by the caller at the top of the chain)
#   2. Editor override from EditorParamStore
#   3. ACE default from the parameter metadata
#   4. Type zero-value fallback
@tool
class_name ParamDefaultResolver
extends RefCounted

var _param_store: EditorParamStore = null

## Attach an EditorParamStore.  May be null (store level is skipped).
func set_param_store(store: EditorParamStore) -> void:
	_param_store = store

## Resolve the effective value for one parameter.
##
## provider_id / ace_id / param_id — identify the ACE parameter
## param_meta  — the parameter Dictionary from ACEDefinition.parameters
## row_override — value from the specific event row, or null to skip
func resolve(provider_id: String, ace_id: String, param_id: String,
		param_meta: Dictionary, row_override: Variant = null) -> Variant:
	# 1. Per-row override has highest priority.
	if row_override != null:
		return row_override

	# 2. Editor override from param store.
	if _param_store != null and _param_store.has_param(provider_id, ace_id, param_id):
		return _param_store.get_param(provider_id, ace_id, param_id)

	# 3. ACE default from metadata.  Use has() to preserve falsy defaults (0, false, "").
	if param_meta.has("default_value"):
		return param_meta["default_value"]

	# 4. Type zero-value fallback.
	return _zero_value(int(param_meta.get("type", TYPE_NIL)))

## Resolve all parameters for a definition at once.
## row_params is a Dictionary of already-stored per-row values; missing keys fall
## through to the lower priority levels.
func resolve_all(definition: ACEDefinition, row_params: Dictionary) -> Dictionary:
	var output: Dictionary = {}
	for parameter: Variant in definition.parameters:
		if not (parameter is Dictionary):
			continue
		var param_dict: Dictionary = parameter as Dictionary
		var param_id: String = str(param_dict.get("id", ""))
		if param_id.is_empty():
			continue
		# Use null only as sentinel for "not present"; this preserves falsy row values.
		var row_val: Variant = row_params[param_id] if row_params.has(param_id) else null
		output[param_id] = resolve(definition.provider_id, definition.id, param_id, param_dict, row_val)
	return output

static func _zero_value(value_type: int) -> Variant:
	match value_type:
		TYPE_BOOL:
			return false
		TYPE_INT:
			return 0
		TYPE_FLOAT:
			return 0.0
		TYPE_STRING:
			return ""
		_:
			return null
