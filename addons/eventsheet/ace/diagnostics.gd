# EventSheet — row-level diagnostics for the "error → row" deep-link.
#
# Walks the in-memory sheet and lints each row's free GDScript — inline blocks (RawCodeRow)
# and ƒx expression params — against the sheet context (via EventSheetGDScriptLint), returning
# one diagnostic per offending row. The editor uses these to jump to the row and paint a red
# marker, instead of surfacing a cryptic status-bar line you then have to hunt down.
#
# Row-based, not line-based: each diagnostic carries the offending resource's instance id, so
# the viewport can match it directly (no generated-line → row source-map mapping needed). The
# pass is pure + headless-safe, so it is fully unit-testable.
@tool
class_name EventSheetDiagnostics
extends RefCounted

## Returns [{ "uid": String, "message": String, "suggestion": String }], one per offending row.
## uid = str(resource.get_instance_id()). `registry` is optional: without it, ƒx expression
## params are skipped (inline GDScript blocks are still linted), keeping the pass usable in
## headless tests that have no ACE registry.
static func analyze(sheet: EventSheetResource, registry: EventSheetACERegistry = null) -> Array:
	var diagnostics: Array = []
	if sheet == null:
		return diagnostics
	_scan_entries(sheet.events, sheet, registry, diagnostics)
	for function_resource in sheet.functions:
		if function_resource is EventFunction:
			_scan_entries((function_resource as EventFunction).events, sheet, registry, diagnostics)
	return diagnostics

static func _scan_entries(entries: Array, sheet: EventSheetResource, registry: EventSheetACERegistry, diagnostics: Array) -> void:
	for entry in entries:
		if entry is EventGroup:
			var group: EventGroup = entry as EventGroup
			_scan_entries(group.events if not group.events.is_empty() else group.rows, sheet, registry, diagnostics)
		elif entry is RawCodeRow:
			_check_raw(entry as RawCodeRow, false, sheet, diagnostics)
		elif entry is EventRow:
			_check_event(entry as EventRow, sheet, registry, diagnostics)

static func _check_event(event: EventRow, sheet: EventSheetResource, registry: EventSheetACERegistry, diagnostics: Array) -> void:
	for condition in event.conditions:
		if condition is ACECondition:
			_check_ace(condition, event, "Condition", sheet, registry, diagnostics)
	for action in event.actions:
		if action is RawCodeRow:
			_check_raw(action as RawCodeRow, true, sheet, diagnostics)
		elif action is ACEAction:
			_check_ace(action, event, "Action", sheet, registry, diagnostics)
	_scan_entries(event.sub_events, sheet, registry, diagnostics)

static func _check_raw(raw: RawCodeRow, in_flow: bool, sheet: EventSheetResource, diagnostics: Array) -> void:
	var verdict: Dictionary = EventSheetGDScriptLint.lint(raw.code, in_flow, sheet)
	if not bool(verdict.get("ok", true)):
		diagnostics.append(_make(raw, "GDScript block doesn't compile: %s" % str(verdict.get("error", "")), ""))

## Lints an ACE's ƒx (expression-hinted) params. Flags the OWNING event row (ACEs render as
## spans inside it), with the first offending param's detail + a "did you mean?" for a bare
## typo'd identifier. Non-expression params (method/property/signal names, literals) are skipped
## so a valid `queue_free` method name never reads as a broken expression.
static func _check_ace(ace: Resource, owner: EventRow, kind: String, sheet: EventSheetResource, registry: EventSheetACERegistry, diagnostics: Array) -> void:
	if registry == null:
		return
	var definition: ACEDefinition = registry.find_definition(str(ace.get("provider_id")), str(ace.get("ace_id")))
	if definition == null:
		return
	var params: Dictionary = ace.get("params") if ace.get("params") is Dictionary else {}
	for parameter in definition.parameters:
		if not (parameter is Dictionary):
			continue
		if str((parameter as Dictionary).get("hint", "")) != "expression":
			continue
		var param_id: String = str((parameter as Dictionary).get("id", ""))
		var value: String = str(params.get(param_id, ""))
		if value.strip_edges().is_empty():
			continue
		# lint() in statement context (not lint_expression's `var x = (…)` wrap): some
		# "expression"-hinted params are statements (e.g. RunGDScript's code = `pass`), which a
		# value-wrap would wrongly reject. A bare value expression is a valid statement too.
		var verdict: Dictionary = EventSheetGDScriptLint.lint(value, true, sheet)
		if not bool(verdict.get("ok", true)):
			diagnostics.append(_make(owner, "%s \"%s\": the %s expression doesn't compile (%s)." % [kind, str(definition.display_name), param_id, value.strip_edges()], _suggest(value, sheet)))
			return

## "Did you mean …?" for a ƒx value that is a single bare identifier (a typo'd variable or
## function name); "" otherwise. Reuses the picker's closest-known-identifier matcher.
static func _suggest(expression: String, sheet: EventSheetResource) -> String:
	var token: String = expression.strip_edges()
	var identifier: RegEx = RegEx.new()
	if identifier.compile("^[A-Za-z_][A-Za-z0-9_]*$") != OK or identifier.search(token) == null:
		return ""
	var closest: String = ACEParamsDialog.closest_known_identifier(token, sheet)
	return ("Did you mean \"%s\"?" % closest) if not closest.is_empty() else ""

static func _make(resource: Object, message: String, suggestion: String) -> Dictionary:
	return {"uid": str(resource.get_instance_id()), "message": message, "suggestion": suggestion}
