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
	for enum_row in _sheet_enums(sheet):
		lines.append(SheetCompiler._emit_enum_line(enum_row))
	if sheet != null:
		for entry in sheet.events:
			if entry is SignalRow and (entry as SignalRow).enabled:
				lines.append(SheetCompiler._emit_signal_line(entry))
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

## Context-aware completion: when the text before the caret ends in `<identifier>.`, the
## resolved type's members are offered (dot-context); otherwise the flat sheet/host
## candidates. This is the single choke point both the block editor and ƒx fields use.
static func completion_for_context(text_before_caret: String, sheet: EventSheetResource) -> Array[Dictionary]:
	var dot_regex: RegEx = RegEx.new()
	if dot_regex.compile("([$]?[A-Za-z_][A-Za-z0-9_]*)\\.$") == OK:
		var dot_match: RegExMatch = dot_regex.search(text_before_caret)
		if dot_match != null:
			return dot_completion_candidates(dot_match.get_string(1), sheet)
	return completion_candidates(sheet)

## Members of the type the dotted token resolves to:
## - `host` (behavior sheets) → the declared host class
## - a sheet variable with a known class type → that class
## - `$NodeName` → the global script class of the same name (the behavior child-node
##   convention), including its script-declared methods/properties + base class members
## Unresolvable tokens return [] (no wrong suggestions).
static func dot_completion_candidates(token: String, sheet: EventSheetResource) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	var seen: Dictionary = {}
	if token == "host" and sheet != null and sheet.behavior_mode:
		_add_class_members(candidates, seen, sheet.host_class)
		return candidates
	# Sheet enums: `State.` offers the members.
	if sheet != null:
		for enum_row in _sheet_enums(sheet):
			if enum_row.enum_name == token:
				for member: String in enum_row.members:
					_add_candidate(candidates, seen, CodeEdit.KIND_CONSTANT, member.get_slice("=", 0).strip_edges())
				return candidates
	if token.begins_with("$"):
		var class_path: String = _global_class_path(token.substr(1))
		if not class_path.is_empty():
			var script: Script = load(class_path) as Script
			if script != null:
				for method_info in script.get_script_method_list():
					var method_name: String = str(method_info.get("name", ""))
					if not method_name.is_empty() and not method_name.begins_with("_"):
						_add_candidate(candidates, seen, CodeEdit.KIND_FUNCTION, method_name)
				for signal_info in script.get_script_signal_list():
					var script_signal: String = str(signal_info.get("name", ""))
					if not script_signal.is_empty():
						_add_candidate(candidates, seen, CodeEdit.KIND_SIGNAL, script_signal)
				for property_info in script.get_script_property_list():
					var property_name: String = str(property_info.get("name", ""))
					if not property_name.is_empty() and not property_name.begins_with("_") and not property_name.ends_with(".gd"):
						_add_candidate(candidates, seen, CodeEdit.KIND_MEMBER, property_name)
				_add_class_members(candidates, seen, script.get_instance_base_type())
		return candidates
	# A sheet variable with a declared class type → that class's members.
	if sheet != null:
		var type_name: String = ""
		if sheet.variables.has(token):
			type_name = str((sheet.variables[token] as Dictionary).get("type", ""))
		for entry in sheet.events:
			if entry is LocalVariable and (entry as LocalVariable).name == token:
				type_name = (entry as LocalVariable).type_name
		if ClassDB.class_exists(type_name):
			_add_class_members(candidates, seen, type_name)
	return candidates

## Signature hint for the innermost unclosed call before the caret ("" = none): sheet
## functions show their declared params, host/dotted-class methods come from ClassDB.
static func signature_hint(text_before_caret: String, sheet: EventSheetResource) -> String:
	var call_regex: RegEx = RegEx.new()
	if call_regex.compile("([A-Za-z_][A-Za-z0-9_]*)\\(([^()]*)$") != OK:
		return ""
	var call_match: RegExMatch = call_regex.search(text_before_caret)
	if call_match == null:
		return ""
	var function_name: String = call_match.get_string(1)
	if sheet != null:
		for function_resource in sheet.functions:
			if function_resource is EventFunction and (function_resource as EventFunction).function_name == function_name:
				var parts: PackedStringArray = PackedStringArray()
				for param in (function_resource as EventFunction).params:
					if param is ACEParam:
						parts.append("%s: %s" % [(param as ACEParam).id, (param as ACEParam).type_name])
				return "%s(%s)" % [function_name, ", ".join(parts)]
	var host_class: String = sheet.host_class if sheet != null and ClassDB.class_exists(sheet.host_class) else ""
	if not host_class.is_empty():
		for method_info in ClassDB.class_get_method_list(host_class):
			if str(method_info.get("name", "")) != function_name:
				continue
			var arg_parts: PackedStringArray = PackedStringArray()
			for argument in method_info.get("args", []):
				var arg_type: int = int((argument as Dictionary).get("type", TYPE_NIL))
				var arg_name: String = str((argument as Dictionary).get("name", ""))
				arg_parts.append(arg_name if arg_type == TYPE_NIL else "%s: %s" % [arg_name, type_string(arg_type)])
			return "%s(%s)" % [function_name, ", ".join(arg_parts)]
	return ""

## Path of a registered global script class (class_name), "" when unknown.
static func _global_class_path(global_class: String) -> String:
	for entry in ProjectSettings.get_global_class_list():
		if str((entry as Dictionary).get("class", "")) == global_class:
			return str((entry as Dictionary).get("path", ""))
	return ""

static func _add_class_members(candidates: Array[Dictionary], seen: Dictionary, member_class: String) -> void:
	if not ClassDB.class_exists(member_class):
		return
	for property_info in ClassDB.class_get_property_list(member_class):
		var property_name: String = str(property_info.get("name", ""))
		if not property_name.is_empty() and not property_name.begins_with("_") and not property_name.contains("/"):
			_add_candidate(candidates, seen, CodeEdit.KIND_MEMBER, property_name)
	for method_info in ClassDB.class_get_method_list(member_class):
		var method_name: String = str(method_info.get("name", ""))
		if not method_name.is_empty() and not method_name.begins_with("_"):
			_add_candidate(candidates, seen, CodeEdit.KIND_FUNCTION, method_name)
	for signal_info in ClassDB.class_get_signal_list(member_class):
		var signal_name: String = str(signal_info.get("name", ""))
		if not signal_name.is_empty():
			_add_candidate(candidates, seen, CodeEdit.KIND_SIGNAL, signal_name)

## Completion candidates for the block editor: sheet variables, sheet functions, and the
## host class's properties/methods. [{kind: CodeEdit.CodeCompletionKind, label: String}]
static func completion_candidates(sheet: EventSheetResource) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	var seen: Dictionary = {}
	for variable_name in _sheet_variable_names(sheet):
		_add_candidate(candidates, seen, CodeEdit.KIND_VARIABLE, variable_name)
	for function_name in _sheet_function_names(sheet):
		_add_candidate(candidates, seen, CodeEdit.KIND_FUNCTION, function_name)
	for enum_row in _sheet_enums(sheet):
		_add_candidate(candidates, seen, CodeEdit.KIND_CLASS, enum_row.enum_name)
	if sheet != null:
		for entry in sheet.events:
			if entry is SignalRow and (entry as SignalRow).enabled:
				_add_candidate(candidates, seen, CodeEdit.KIND_SIGNAL, (entry as SignalRow).signal_name)
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

## Sheet-declared enums (top level and inside groups), enabled only.
static func _sheet_enums(sheet: EventSheetResource) -> Array[EnumRow]:
	var enums: Array[EnumRow] = []
	if sheet != null:
		_collect_sheet_enums(sheet.events, enums)
	return enums

static func _collect_sheet_enums(entries: Array, into: Array[EnumRow]) -> void:
	for entry in entries:
		if entry is EnumRow and (entry as EnumRow).enabled:
			into.append(entry)
		elif entry is EventGroup:
			var group: EventGroup = entry as EventGroup
			_collect_sheet_enums(group.events if not group.events.is_empty() else group.rows, into)

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
