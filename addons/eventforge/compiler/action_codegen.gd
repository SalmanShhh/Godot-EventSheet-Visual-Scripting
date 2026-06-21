# EventForge — Action code generation
# Emits GDScript statements for ACE actions.
@tool
extends RefCounted
class_name ActionCodegen

## Generates one action statement from an ACE action. target_default is an enclosing "With node X:"
## scope (see SheetCompiler): when set, it fills the action's "On node" target if the author left it on
## the host, so a scoped action inlines to that node.
static func generate_action(action: ACEAction, target_default: String = "") -> String:
	if action == null or not action.enabled:
		return ""

	# Resolve the template: a baked one (custom/addon ACEs) wins over the descriptor registry, so
	# reflection ACEs with @ace_codegen_template compile even though they have no ACEDescriptor.
	var template: String = action.codegen_template
	if template.strip_edges().is_empty():
		var descriptor: ACEDescriptor = ACERegistry.find_descriptor(action.provider_id, action.ace_id)
		if descriptor == null:
			return ""
		template = descriptor.codegen_template

	return _apply_template(template, _params_with_scope_target(action, target_default, template))

## Returns the action's params, with a "With node X:" scope's target folded in when applicable: the
## scope is active (target_default set), the template actually has a `{target.}` / `{target}` slot, and
## the author left the target on the host (blank, or the "self" default of the group/meta ACEs). An
## explicit target the author chose is never overridden, and non-targetable actions pass through
## untouched. Non-mutating — a copy is returned so the action resource is never altered.
static func _params_with_scope_target(action: ACEAction, target_default: String, template: String) -> Dictionary:
	var params: Dictionary = _get_params(action)
	if target_default.strip_edges().is_empty():
		return params
	if not (template.contains("{target.}") or template.contains("{target}")):
		return params
	var current: String = str(params.get("target", "")).strip_edges()
	if not (current.is_empty() or current == "self"):
		return params
	var injected: Dictionary = params.duplicate()
	injected["target"] = target_default
	return injected

## Applies `{param}`, optional-comma `{, param}`, and optional-prefix `{param.}` substitutions in a
## SINGLE left-to-right pass. The optional-prefix idiom (dot INSIDE the braces) emits `<value>.` only
## when the value is non-empty, else nothing — so `{target.}play()` is `play()` for an empty target
## (the host) and `$Enemy.play()` for a set one. The dot lives inside the braces precisely so it
## cannot collide with the ordinary `{target}.foo` pattern (dot outside), which keeps emitting `.foo`.
## Param VALUES are opaque — a value that itself contains `{...}` is emitted verbatim and never
## re-scanned (an earlier iterative replace() pass corrupted such values, e.g. "{a}-{b}" with
## a="{b}", b="X" produced "X-X" instead of "{b}-X"). Unknown plain `{key}` placeholders are kept
## literal; an unresolved optional `{, key}` or `{key.}` is dropped (matching the old trailing strip).
static var _template_re: RegEx

static func _apply_template(template: String, params: Dictionary) -> String:
	if _template_re == null:
		_template_re = RegEx.new()
		_template_re.compile("\\{(,?)\\s*([A-Za-z_][A-Za-z0-9_]*)(\\.?)\\}")
	var result: String = ""
	var cursor: int = 0
	for hit: RegExMatch in _template_re.search_all(template):
		result += template.substr(cursor, hit.get_start() - cursor)
		var is_optional_comma: bool = hit.get_string(1) == ","
		var key_name: String = hit.get_string(2)
		var is_optional_prefix: bool = hit.get_string(3) == "."
		if params.has(key_name):
			var value: String = str(params[key_name])
			if is_optional_prefix:
				var trimmed: String = value.strip_edges()
				result += "" if trimmed.is_empty() else trimmed + "."
			elif is_optional_comma:
				result += "" if value.is_empty() else ", " + value
			else:
				result += value
		elif not is_optional_comma and not is_optional_prefix:
			result += hit.get_string(0)  # leave an unknown plain {key} literal
		cursor = hit.get_end()
	result += template.substr(cursor)
	return result

## Returns action params while preserving backwards compatibility with the first PR scaffold.
static func _get_params(action: ACEAction) -> Dictionary:
	if not action.params.is_empty():
		return action.params
	return action.parameters
