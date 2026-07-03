# EventSheet — GDScript block lint + completion support
# Compile-checks block snippets against the sheet's context: the scratch script extends the
# sheet's host class and stubs the sheet's variables/functions, so references to them (and
# host members) resolve. Godot does not expose the ScriptEditor analyzer to plugins; this
# parse+analyze pass is the supported approximation.
@tool
class_name EventSheetGDScriptLint
extends RefCounted

## Override for tests / non-editor hosts: a Callable returning the scene root used for
## $Node completion. Defaults to the editor's edited scene when inside the editor.
static var scene_root_provider: Callable = Callable()


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


## A purely STRUCTURAL GDScript syntax error in `code` — unbalanced ()/[]/{}, a mismatched bracket, or an
## unterminated string — or "" when structurally sound. These are ALWAYS errors regardless of whether the
## identifiers are declared, so the editor can hard-block committing them with ZERO false positives (unlike
## the symbol-aware lint, which flags runtime-only refs like a $spawned node or a dynamic var). Brackets
## and quotes inside strings and `#` comments are skipped so they don't miscount; `\` escapes and triple
## quoted strings are handled. Context-free + pure → unit-testable; the always-on companion to lint().
static func structural_syntax_error(code: String) -> String:
	var openers: PackedStringArray = PackedStringArray()   # stack of open-bracket chars
	var open_lines: PackedInt32Array = PackedInt32Array()  # the line each opener sits on (for the message)
	var closer_to_opener: Dictionary = {")": "(", "]": "[", "}": "{"}
	var i: int = 0
	var n: int = code.length()
	var line: int = 1
	while i < n:
		var ch: String = code[i]
		if ch == "\n":
			line += 1
			i += 1
		elif ch == "#":
			while i < n and code[i] != "\n":
				i += 1  # skip the comment to end of line
		elif ch == "\"" or ch == "'":
			var start_line: int = line
			var quote: String = ch
			if code.substr(i, 3) == quote.repeat(3):
				# Triple-quoted (multi-line) string.
				i += 3
				var triple_closed: bool = false
				while i < n:
					if code.substr(i, 3) == quote.repeat(3):
						i += 3
						triple_closed = true
						break
					if code[i] == "\\":
						i += 2
						continue
					if code[i] == "\n":
						line += 1
					i += 1
				if not triple_closed:
					return "Unterminated multi-line string starting on line %d." % start_line
			else:
				i += 1
				var closed: bool = false
				while i < n:
					if code[i] == "\\":
						i += 2
						continue
					if code[i] == quote:
						i += 1
						closed = true
						break
					if code[i] == "\n":
						break  # a single-line string can't span lines
					i += 1
				if not closed:
					return "Unterminated string (missing closing %s) on line %d." % [quote, start_line]
		elif ch == "(" or ch == "[" or ch == "{":
			openers.append(ch)
			open_lines.append(line)
			i += 1
		elif ch == ")" or ch == "]" or ch == "}":
			if openers.is_empty():
				return "Unmatched closing \"%s\" on line %d." % [ch, line]
			if openers[openers.size() - 1] != str(closer_to_opener[ch]):
				return "Mismatched bracket \"%s\" on line %d." % [ch, line]
			openers.remove_at(openers.size() - 1)
			open_lines.remove_at(open_lines.size() - 1)
			i += 1
		else:
			i += 1
	if not openers.is_empty():
		return "Unclosed \"%s\" from line %d — add its closing bracket." % [openers[openers.size() - 1], open_lines[open_lines.size() - 1]]
	return ""


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
		# Not a registered class: try the OPEN SCENE's actual nodes ($Child completes its
		# script members, signals and class members).
		if candidates.is_empty():
			var scene_root: Node = _resolve_scene_root()
			if scene_root != null:
				var child: Node = scene_root.get_node_or_null(NodePath(token.substr(1)))
				if child != null:
					var child_script: Script = child.get_script() as Script
					if child_script != null:
						for method_info in child_script.get_script_method_list():
							var script_method: String = str(method_info.get("name", ""))
							if not script_method.is_empty() and not script_method.begins_with("_"):
								_add_candidate(candidates, seen, CodeEdit.KIND_FUNCTION, script_method)
						for signal_info in child_script.get_script_signal_list():
							_add_candidate(candidates, seen, CodeEdit.KIND_SIGNAL, str(signal_info.get("name", "")))
					_add_class_members(candidates, seen, child.get_class())
		return candidates
	# A sheet variable with a declared class type → that class's members.
	if sheet != null:
		var type_name: String = ""
		if sheet.variables.has(token):
			type_name = str((sheet.variables[token] as Dictionary).get("type", ""))
		for entry in sheet.events:
			if entry is LocalVariable and (entry as LocalVariable).name == token:
				type_name = (entry as LocalVariable).type_name
		# Typed collections (Array[T], Dictionary[K,V]) still complete their CONTAINER
		# members: strip the generic suffix so `my_list.` resolves.
		var container_type: String = type_name
		var generic_index: int = container_type.find("[")
		if generic_index != -1:
			container_type = container_type.substr(0, generic_index).strip_edges()
		if ClassDB.class_exists(container_type):
			_add_class_members(candidates, seen, container_type)
		else:
			# Array/Dictionary/Packed*Array are Variant built-ins, not ClassDB classes, so
			# ClassDB can't enumerate them — offer a curated method set (the same vocabulary
			# the collection Helper ACEs wrap, so completion and the picker agree).
			for member: String in _builtin_collection_members(container_type):
				_add_candidate(candidates, seen, CodeEdit.KIND_FUNCTION, member)
	return candidates


## Curated method names for the Variant collection types (which ClassDB does not expose).
static func _builtin_collection_members(type_name: String) -> PackedStringArray:
	if type_name == "Dictionary":
		return PackedStringArray(["has", "get", "set", "erase", "clear", "keys", "values",
			"size", "is_empty", "merge", "duplicate", "has_all", "get_or_add"])
	if type_name == "Array" or (type_name.begins_with("Packed") and type_name.ends_with("Array")):
		return PackedStringArray(["append", "append_array", "push_back", "push_front",
			"pop_back", "pop_front", "insert", "remove_at", "erase", "clear", "size",
			"is_empty", "has", "find", "count", "front", "back", "slice", "duplicate",
			"reverse", "sort", "shuffle", "fill", "resize", "max", "min", "pick_random"])
	return PackedStringArray()


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


## The scene root for $-completion: the injected provider (tests), else the editor's
## edited scene, else null (headless/runtime).
static func _resolve_scene_root() -> Node:
	if scene_root_provider.is_valid():
		return scene_root_provider.call() as Node
	if Engine.is_editor_hint():
		return EditorInterface.get_edited_scene_root()
	return null


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
	# Direct children of the open scene complete as $Name references.
	var scene_root: Node = _resolve_scene_root()
	if scene_root != null:
		for child in scene_root.get_children():
			_add_candidate(candidates, seen, CodeEdit.KIND_NODE_PATH, "$%s" % child.name)
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
			# build_scratch_source already declares `var host: <Type>` for behaviour sheets, and opening a
			# behaviour .gd recovers that accessor as a `host` variable row — skip it here so the scratch
			# script doesn't get a duplicate `var host` (which fails to parse and spuriously errors the lint).
			if sheet.behavior_mode and (entry as LocalVariable).name == "host":
				continue
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
