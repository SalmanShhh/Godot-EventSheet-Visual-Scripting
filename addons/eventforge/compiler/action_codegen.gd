# EventForge - Action code generation
# Emits GDScript statements for ACE actions.
@tool
class_name ActionCodegen
extends RefCounted


## Generates one action statement from an ACE action. target_default is an enclosing "With node X:"
## scope (see SheetCompiler): when set, it fills the action's "On node" target if the author left it on
## the host, so a scoped action inlines to that node.
static func generate_action(action: ACEAction, target_default: String = "", host_default: String = "") -> String:
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

	var params: Dictionary = _params_with_scope_target(action, target_default, template)
	params = _params_with_host(params, host_default, template)
	params = _params_with_blank_defaults(action, params)
	return _apply_template(template, params)


## Fills in the parameters a saved row never answered, but ONLY the ones whose shipped answer is
## nothing at all. This is what lets an already-shipped row grow an OPTIONAL trailing parameter
## without rewriting anybody's sheet: a row saved before the parameter existed has no value for it,
## and without this its slot would be left in the emitted file as the literal text `{name}`. Blank
## defaults only, so a row that omitted a parameter with a real default keeps whatever it emitted
## before - this can add nothing but emptiness where broken text used to go.
static func _params_with_blank_defaults(action: ACEAction, params: Dictionary) -> Dictionary:
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor(action.provider_id, action.ace_id)
	if descriptor == null:
		return params
	var filled: Dictionary = params
	for parameter: ACEParam in descriptor.params:
		if params.has(parameter.id) or not (parameter.default_value is String):
			continue
		if not str(parameter.default_value).is_empty():
			continue
		if filled == params:
			filled = params.duplicate()
		filled[parameter.id] = ""
	return filled


## Returns the action's params, with a "With node X:" scope's target folded in when applicable: the
## scope is active (target_default set), the template actually has a `{target.}` / `{target}` slot, and
## the author left the target on the host (blank, or the "self" default of the group/meta ACEs). An
## explicit target the author chose is never overridden, and non-targetable actions pass through
## untouched. Non-mutating - a copy is returned so the action resource is never altered.
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


## Folds the behavior-mode host accessor into the params for templates using the {host.}/{host}
## idiom, so a node-scoped ACE authored in a behavior calls on the parent host (e.g.
## `{host.}move_and_slide()` -> `host.move_and_slide()`). An empty host_default (every non-behavior
## sheet) leaves the key absent, so {host.} drops to nothing and the call stays bare - byte-stable.
## An author-supplied "host" param (none of the built-ins define one) is never overridden. The lifter
## already round-trips this idiom (ace_lifter._optional_prefix_variants), exactly as for {target.}.
static func _params_with_host(params: Dictionary, host_default: String, template: String) -> Dictionary:
	if host_default.strip_edges().is_empty():
		return params
	if not (template.contains("{host.}") or template.contains("{host}")):
		return params
	if params.has("host"):
		return params
	var injected: Dictionary = params.duplicate()
	injected["host"] = host_default
	return injected

## Applies `{param}`, optional-comma `{, param}`, and optional-prefix `{param.}` substitutions in a
## SINGLE left-to-right pass. The optional-prefix idiom (dot INSIDE the braces) emits `<value>.` only
## when the value is non-empty, else nothing - so `{target.}play()` is `play()` for an empty target
## (the host) and `$Enemy.play()` for a set one. The dot lives inside the braces precisely so it
## cannot collide with the ordinary `{target}.foo` pattern (dot outside), which keeps emitting `.foo`.
## Param VALUES are opaque - a value that itself contains `{...}` is emitted verbatim and never
## re-scanned (an earlier iterative replace() pass corrupted such values, e.g. "{a}-{b}" with
## a="{b}", b="X" produced "X-X" instead of "{b}-X"). Unknown plain `{key}` placeholders are kept
## literal; an unresolved optional `{, key}` or `{key.}` is dropped (matching the old trailing strip).
static var _template_re: RegEx

## The OPTIONAL SEGMENT idiom, in its two spellings:
##
##     {?key}…{/key}          keep this when `key` has a non-blank value
##     {?key=word}…{/key}     keep this when `key` reads exactly `word`
##
## and drop the whole segment - marks and all - when it does not. The second spelling is what a
## STATED CHOICE compiles through: a dropdown's two answers are both words a reader picked, so
## neither of them is "blank", and the row has to say which one it is either way.
##
## THE THREE SLOT IDIOMS ABOVE FILL A HOLE; THIS ONE CHOOSES A SHAPE. A read with a fallback is a
## different line from a read without one (`get_file_as_string(p)` against the file_exists ternary
## around it), and a write that makes its folder first is a different line from one that does not -
## so the choice cannot be spelled as a value dropped into a hole. It is spelled as a segment,
## because the alternative was two verbs for one sentence, and a reader who clears a field expects
## the sentence to go back to what it was rather than to need a different word.
##
## A SEGMENT IS NEVER NESTED and never re-scanned. The inner text is emitted through the ordinary
## slot pass exactly as if it had been written inline, so a param value that happens to contain
## `{?…}` is a value, not a segment - the same opacity the slot pass already promises.
static var _segment_re: RegEx


## Collapses every optional segment of a template against the values a row holds. Public because the
## expression picker fills a template too, and a shape that changed in one place and not the other
## would be two answers to one question.
static func collapse_optional_segments(template: String, params: Dictionary) -> String:
	if not template.contains("{?"):
		return template
	if _segment_re == null:
		_segment_re = RegEx.new()
		_segment_re.compile("\\{\\?([A-Za-z_][A-Za-z0-9_]*)(=[^}]*)?\\}([\\s\\S]*?)\\{/\\1\\}")
	var result: String = ""
	var cursor: int = 0
	for hit: RegExMatch in _segment_re.search_all(template):
		result += template.substr(cursor, hit.get_start() - cursor)
		var key_name: String = hit.get_string(1)
		var wanted: String = hit.get_string(2)
		var held: String = str(params.get(key_name, "")).strip_edges()
		var keep: bool = not held.is_empty()
		if wanted.begins_with("="):
			keep = held == wanted.substr(1)
		if keep:
			result += hit.get_string(3)
		cursor = hit.get_end()
	result += template.substr(cursor)
	return result


static func _apply_template(template: String, params: Dictionary) -> String:
	template = collapse_optional_segments(template, params)
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
