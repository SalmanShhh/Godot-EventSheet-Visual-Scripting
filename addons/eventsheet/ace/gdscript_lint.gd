# EventSheet — GDScript block lint + completion support
# Compile-checks block snippets against the sheet's context: the scratch script extends the
# sheet's host class and stubs the sheet's variables/functions, so references to them (and
# host members) resolve. Godot does not expose the ScriptEditor analyzer to plugins; this
# parse+analyze pass is the supported approximation (see GDSCRIPT-PAIRING-SPEC).
@tool
class_name EventSheetGDScriptLint
extends RefCounted

## Compile-checks `code`. in_flow=true validates statements (wrapped in a function body, as
## emitted inside an event); false validates class-level code (helper funcs, vars, signals).
## Returns {"ok": bool, "error": String}.
static func lint(code: String, in_flow: bool, sheet: EventSheetResource) -> Dictionary:
	if code.strip_edges().is_empty():
		return {"ok": true, "error": ""}
	var scratch: GDScript = GDScript.new()
	scratch.source_code = build_scratch_source(code, in_flow, sheet)
	var error: Error = scratch.reload(true)
	if error == OK:
		return {"ok": true, "error": ""}
	return {"ok": false, "error": "Does not compile (parse/analyze failed — see Output for details)."}

## Validates a ƒx field as a plain GDScript expression against the sheet context (sheet
## variables, host members, the behavior `host` accessor). Empty text is valid.
static func lint_expression(expression: String, sheet: EventSheetResource) -> Dictionary:
	if expression.strip_edges().is_empty():
		return {"ok": true, "error": ""}
	return lint("var __expression_check__ = (%s)" % expression.strip_edges(), true, sheet)

## The scratch script used for linting: host-class extends + sheet symbol stubs + the code.
static func build_scratch_source(code: String, in_flow: bool, sheet: EventSheetResource) -> String:
	var lines: PackedStringArray = PackedStringArray()
	var host_class: String = sheet.host_class if sheet != null and ClassDB.class_exists(sheet.host_class) else "RefCounted"
	# Behavior sheets compile to Node components with a typed `host` accessor — the scratch
	# script mirrors that so `host.member` references lint correctly.
	if sheet != null and sheet.behavior_mode:
		lines.append("extends Node")
		lines.append("var host: %s = null" % host_class)
	else:
		lines.append("extends %s" % host_class)
	for variable_name in _sheet_variable_names(sheet):
		lines.append("var %s" % variable_name)
	for function_name in _sheet_function_names(sheet):
		lines.append("func %s(_a = null, _b = null, _c = null, _d = null, _e = null, _f = null, _g = null, _h = null) -> Variant: return null" % function_name)
	if in_flow:
		lines.append("func __eventsheet_lint() -> void:")
		for code_line: String in code.split("\n"):
			lines.append("\t" + code_line)
		lines.append("\tpass")
	else:
		for code_line: String in code.split("\n"):
			lines.append(code_line)
	return "\n".join(lines)

## Completion candidates for the block editor: sheet variables, sheet functions, and the
## host class's properties/methods. [{kind: CodeEdit.CodeCompletionKind, label: String}]
static func completion_candidates(sheet: EventSheetResource) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	var seen: Dictionary = {}
	for variable_name in _sheet_variable_names(sheet):
		_add_candidate(candidates, seen, CodeEdit.KIND_VARIABLE, variable_name)
	for function_name in _sheet_function_names(sheet):
		_add_candidate(candidates, seen, CodeEdit.KIND_FUNCTION, function_name)
	if sheet != null and ClassDB.class_exists(sheet.host_class):
		for property_info in ClassDB.class_get_property_list(sheet.host_class):
			var property_name: String = str(property_info.get("name", ""))
			if not property_name.is_empty() and not property_name.begins_with("_") and not property_name.contains("/"):
				_add_candidate(candidates, seen, CodeEdit.KIND_MEMBER, property_name)
		for method_info in ClassDB.class_get_method_list(sheet.host_class):
			var method_name: String = str(method_info.get("name", ""))
			if not method_name.is_empty() and not method_name.begins_with("_"):
				_add_candidate(candidates, seen, CodeEdit.KIND_FUNCTION, method_name)
	return candidates

static func _add_candidate(candidates: Array[Dictionary], seen: Dictionary, kind: int, label: String) -> void:
	if seen.has(label):
		return
	seen[label] = true
	candidates.append({"kind": kind, "label": label})

static func _sheet_variable_names(sheet: EventSheetResource) -> Array[String]:
	var names: Array[String] = []
	if sheet == null:
		return names
	for key in sheet.variables.keys():
		names.append(str(key))
	for entry in sheet.events:
		if entry is LocalVariable and not (entry as LocalVariable).name.strip_edges().is_empty():
			names.append((entry as LocalVariable).name)
	names.sort()
	return names

static func _sheet_function_names(sheet: EventSheetResource) -> Array[String]:
	var names: Array[String] = []
	if sheet == null:
		return names
	for function_resource in sheet.functions:
		if function_resource is EventFunction and not (function_resource as EventFunction).function_name.strip_edges().is_empty():
			names.append((function_resource as EventFunction).function_name)
	names.sort()
	return names
