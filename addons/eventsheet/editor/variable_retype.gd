# Godot EventSheets - "Change Type Everywhere..." (the variable-retype refactor).
#
# Retyping a variable used to mean editing the declaration and then hunting every Set / Compare /
# fx field that still holds the old shape - the refactor beginners avoid, so wrong types calcify.
# This is the model half: ONE scan that both PREVIEWS what would be rewritten and PERFORMS it, so
# the list the dialog shows can never disagree with what the OK button does.
#
# WHICH FIELDS COUNT. Not "every literal in an ACE that mentions the name" - that would retype a
# Dictionary KEY next to the variable. The scan reads the ACE's own BAKED codegen template and
# takes only the field standing in an ASSIGNMENT or COMPARISON with the variable's field:
# `{var_name} = {value}` and `{var_name} {op} {value}` both hand back `value`, while
# `{var_name}.get({key}, {default})` hands back nothing. That rule is the ACE's own grammar, so a
# pack's verb of the same shape is retyped too, with no list of ace_ids to maintain.
#
# WHAT IT REFUSES TO GUESS. A field holding an EXPRESSION (`Text To Int(score) + 10`) or a literal
# that has no honest conversion (`"gold"` to a number) is never rewritten - it is REPORTED, so the
# dialog says "left as written, check this row" instead of quietly corrupting code. That honesty is
# the whole reason the preview exists.
#
# Everything here is static and UI-free: the dialog previews with `plan`, the undo funnel commits
# with `apply`, and the suite drives both headless. `apply` re-walks the LIVE sheet it is given
# (never a cached row - the commit replaces resources with snapshot duplicates).
@tool
class_name EventSheetVariableRetype
extends RefCounted

## The operator tokens that make a neighbouring field "the value of this variable". Assignments and
## comparisons only: `+` or `.` neighbours are arithmetic/member syntax, not a value slot.
const VALUE_OPERATORS: Array[String] = ["=", "==", "!=", "<", "<=", ">", ">=", "+=", "-=", "*=", "/=", "%="]
## `{left} <op> {right}` inside a codegen template, where <op> is either a literal operator or a
## placeholder whose stored value is one (Compare Variable's `{var_name} {op} {value}`).
const PAIR_PATTERN := "\\{([A-Za-z_][A-Za-z0-9_]*)\\}\\s*(\\{[A-Za-z_][A-Za-z0-9_]*\\}|[-+*/%<>=!]{1,2})\\s*\\{([A-Za-z_][A-Za-z0-9_]*)\\}"
## Types whose literals this refactor can rewrite. Anything else (Vector2, Array, a custom class)
## still retypes the DECLARATION - its value fields are reported for review instead of guessed at.
const CONVERTIBLE_TYPES: Array[String] = ["int", "float", "String", "bool"]


## Preview: what "Change Type Everywhere" would do, without touching anything. `ordinal` picks WHICH
## declaration of that name (see `ordinal_of`); -1 keeps the historic "the first one" behaviour.
static func plan(sheet: EventSheetResource, variable_name: String, new_type: String, ordinal: int = -1) -> Dictionary:
	return _scan(sheet, variable_name, new_type, false, ordinal)


## Commit: the same scan, applied. Returns the same report, with "edits" counting the declaration
## plus every rewritten field. Call it INSIDE the dock's undo funnel, on the live sheet.
static func apply(sheet: EventSheetResource, variable_name: String, new_type: String, ordinal: int = -1) -> Dictionary:
	return _scan(sheet, variable_name, new_type, true, ordinal)


## Every declaration carrying this name, in a stable order: the sheet's own variables dictionary
## first, then each variable ROW and event-local depth-first. One name can be declared several times
## over (two events may each have their own `i`), so a retype needs to say WHICH - the position in
## this list is that answer, and it survives the undo funnel's snapshot duplication because it is
## structural, never a resource reference.
static func declarations(sheet: EventSheetResource, variable_name: String) -> Array:
	var found: Array = []
	if sheet == null or variable_name.is_empty():
		return found
	if sheet.variables.has(variable_name):
		found.append({"scope": "sheet", "resource": null})
	_collect_variable_resources(sheet.events, variable_name, found)
	return found


## The position in `declarations` of the declaration a variable-menu entry points at, or -1 when the
## entry names none of them. Computed while the sheet is still LIVE (the click), then carried into
## the funnel as a plain number.
static func ordinal_of(sheet: EventSheetResource, entry: Dictionary) -> int:
	var all_declarations: Array = declarations(sheet, str(entry.get("name", "")))
	var scope: String = str(entry.get("scope", ""))
	var resource: Variant = entry.get("resource", null)
	if not (resource is LocalVariable):
		# An event-local's own resource is reachable through the clicked event and its index.
		var owner: Variant = entry.get("event_row", null)
		var index: int = int(entry.get("index", -1))
		if owner is EventRow and index >= 0 and index < (owner as EventRow).local_variables.size():
			resource = (owner as EventRow).local_variables[index]
	for position: int in range(all_declarations.size()):
		var candidate: Dictionary = all_declarations[position]
		if resource is LocalVariable:
			if candidate.get("resource", null) == resource:
				return position
		elif str(candidate.get("scope", "")) == "sheet" and scope in ["sheet", "global"]:
			return position
	return -1


## Where the variable is declared: "sheet" (the variables dictionary), "tree" (a variable ROW placed
## between events) or "local" (an event's own). "" when the name is declared nowhere. `ordinal` picks
## one of several same-named declarations; -1 takes the first.
static func find_declaration(sheet: EventSheetResource, variable_name: String, ordinal: int = -1) -> Dictionary:
	var all_declarations: Array = declarations(sheet, variable_name)
	if all_declarations.is_empty():
		return {}
	var chosen: Dictionary = all_declarations[ordinal] if ordinal >= 0 and ordinal < all_declarations.size() else all_declarations[0]
	if str(chosen.get("scope", "")) == "sheet":
		var descriptor: Dictionary = sheet.variables[variable_name] if sheet.variables[variable_name] is Dictionary else {}
		return {
			"scope": "sheet",
			"type": str(descriptor.get("type", "Variant")),
			"default": descriptor.get("default", null)
		}
	var variable: LocalVariable = chosen.get("resource", null)
	return {
		"scope": str(chosen.get("scope", "tree")),
		"type": variable.type_name,
		"default": variable.default_value,
		"resource": variable
	}


## Every LocalVariable carrying this name under `rows`, in the same depth-first order the single
## lookup used to walk - so position 0 is still the declaration the old code would have found.
static func _collect_variable_resources(rows: Array, variable_name: String, into: Array) -> void:
	for row: Variant in rows:
		if row is LocalVariable and (row as LocalVariable).name == variable_name:
			into.append({"resource": row as LocalVariable, "scope": "tree"})
		if row is EventGroup:
			var group: EventGroup = row as EventGroup
			_collect_variable_resources(group.events if not group.events.is_empty() else group.rows, variable_name, into)
		if row is EventRow:
			var event_row: EventRow = row as EventRow
			for local: Variant in event_row.local_variables:
				if local is LocalVariable and (local as LocalVariable).name == variable_name:
					into.append({"resource": local as LocalVariable, "scope": "local"})
			_collect_variable_resources(event_row.sub_events, variable_name, into)


static func _scan(sheet: EventSheetResource, variable_name: String, new_type: String, mutate: bool, ordinal: int = -1) -> Dictionary:
	var report: Dictionary = {
		"found": false,
		"scope": "",
		"old_type": "",
		"new_type": new_type,
		"default_before": "",
		"default_after": "",
		"default_changed": false,
		"changes": [],
		"reviews": [],
		"edits": 0
	}
	var declaration: Dictionary = find_declaration(sheet, variable_name, ordinal)
	if declaration.is_empty():
		return report
	report["found"] = true
	report["scope"] = str(declaration.get("scope", ""))
	report["old_type"] = str(declaration.get("type", "Variant"))
	var old_default: Variant = declaration.get("default", null)
	var new_default: Variant = coerce_default(old_default, new_type)
	report["default_before"] = var_to_str(old_default)
	report["default_after"] = var_to_str(new_default)
	report["default_changed"] = str(report["default_before"]) != str(report["default_after"])
	if str(report["old_type"]) != new_type or bool(report["default_changed"]):
		report["edits"] = int(report["edits"]) + 1
	if mutate:
		if str(declaration.get("scope", "")) == "sheet":
			var descriptor: Dictionary = sheet.variables[variable_name] if sheet.variables[variable_name] is Dictionary else {}
			descriptor["type"] = new_type
			descriptor["default"] = new_default
			sheet.variables[variable_name] = descriptor
		else:
			var resource: LocalVariable = declaration.get("resource", null)
			if resource != null:
				resource.type_name = new_type
				resource.type = variant_type_for(new_type)
				resource.default_value = new_default
	var usages: Array = []
	_collect_usages(sheet.events, "", usages)
	for function_entry: Variant in sheet.functions:
		if function_entry is EventFunction:
			var event_function: EventFunction = function_entry as EventFunction
			var body: Array = event_function.events if not event_function.events.is_empty() else event_function.rows
			_collect_usages(body, "%s() > " % event_function.function_name, usages)
	for usage: Dictionary in usages:
		var ace: Resource = usage.get("ace", null)
		if ace == null:
			continue
		var params: Dictionary = _params_of(ace)
		for param_name: String in value_params_for(ace, variable_name):
			var current: String = str(params.get(param_name, ""))
			var conversion: Dictionary = convert_literal(current, new_type)
			var entry: Dictionary = {
				"where": str(usage.get("where", "")),
				"provider_id": str(ace.get("provider_id")),
				"ace_id": str(ace.get("ace_id")),
				"param": param_name,
				"before": current
			}
			if not bool(conversion.get("ok", false)):
				entry["why"] = str(conversion.get("why", ""))
				(report["reviews"] as Array).append(entry)
				continue
			var after: String = str(conversion.get("value", current))
			if after == current.strip_edges():
				continue
			entry["after"] = after
			(report["changes"] as Array).append(entry)
			report["edits"] = int(report["edits"]) + 1
			if mutate:
				params[param_name] = after
	return report


## The parameter names this ACE puts in an assignment/comparison with `variable_name` - the fields
## that hold a VALUE of the variable's type. Reads the ACE's baked codegen template, so it answers
## for any verb (builtin or pack) of that shape and for none of the others.
static func value_params_for(ace: Resource, variable_name: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	if ace == null:
		return found
	var params: Dictionary = _params_of(ace)
	if params.is_empty():
		return found
	var template: String = str(ace.get("codegen_template"))
	if template.is_empty():
		return found
	var pair_regex: RegEx = RegEx.create_from_string(PAIR_PATTERN)
	if pair_regex == null:
		return found
	for pair: RegExMatch in pair_regex.search_all(template):
		var left: String = pair.get_string(1)
		var middle: String = pair.get_string(2)
		var right: String = pair.get_string(3)
		if middle.begins_with("{"):
			middle = str(params.get(middle.substr(1, middle.length() - 2), ""))
		if not VALUE_OPERATORS.has(middle.strip_edges()):
			continue
		if str(params.get(left, "")).strip_edges() == variable_name and not _names_a_member(template, pair.get_start(1)) and not found.has(right):
			found.append(right)
		elif str(params.get(right, "")).strip_edges() == variable_name and not _names_a_member(template, pair.get_start(3)) and not found.has(left):
			found.append(left)
	return found


## True when a placeholder stands in a MEMBER position - `{property}` in Set Property's
## `{target}.{property} = {value}`. Its text is the name of a field on another object, not the
## variable, so a node property that happens to be spelled like the sheet variable must not drag
## the value beside it into the retype. The brace opens one character before the captured name.
static func _names_a_member(template: String, group_start: int) -> bool:
	var brace: int = group_start - 1
	return brace >= 1 and template.substr(brace - 1, 1) == "."


## Rewrites one field's LITERAL into `to_type`'s form. {"ok": true, "value": "..."} on success;
## {"ok": false, "why": "..."} when the field is an expression or the literal has no honest
## conversion - the caller reports those rather than guessing.
static func convert_literal(text: String, to_type: String) -> Dictionary:
	var trimmed: String = text.strip_edges()
	if trimmed.is_empty():
		return {"ok": false, "why": "the field is empty"}
	if not CONVERTIBLE_TYPES.has(to_type):
		# Variant accepts what is already there; every other type (Vector2, Array, a class) has no
		# literal grammar this refactor can safely invent.
		if to_type == "Variant":
			return {"ok": true, "value": trimmed}
		return {"ok": false, "why": "no automatic conversion to %s" % to_type}
	if not is_literal(trimmed):
		return {"ok": false, "why": "it is an expression, not a plain value"}
	var numeric: String = _numeric_text(trimmed)
	var boolean: String = _boolean_text(trimmed)
	match to_type:
		"int":
			if not numeric.is_empty():
				return {"ok": true, "value": numeric if numeric.is_valid_int() else str(int(numeric.to_float()))}
			if not boolean.is_empty():
				return {"ok": true, "value": "1" if boolean == "true" else "0"}
			return {"ok": false, "why": "%s is not a number" % trimmed}
		"float":
			if not numeric.is_empty():
				return {"ok": true, "value": "%s.0" % numeric if numeric.is_valid_int() else numeric}
			if not boolean.is_empty():
				return {"ok": true, "value": "1.0" if boolean == "true" else "0.0"}
			return {"ok": false, "why": "%s is not a number" % trimmed}
		"String":
			if is_string_literal(trimmed):
				return {"ok": true, "value": trimmed}
			return {"ok": true, "value": "\"%s\"" % trimmed}
		"bool":
			if not boolean.is_empty():
				return {"ok": true, "value": boolean}
			if not numeric.is_empty():
				return {"ok": true, "value": "false" if numeric.to_float() == 0.0 else "true"}
			return {"ok": false, "why": "%s is not a yes/no value" % trimmed}
	return {"ok": false, "why": "no automatic conversion to %s" % to_type}


## The declared default, carried across the type change (a real VALUE, not source text - that is
## what a variable descriptor stores).
static func coerce_default(value: Variant, to_type: String) -> Variant:
	match to_type:
		"int":
			if value is String:
				return int(str(value).to_float()) if str(value).is_valid_float() else 0
			if value is float or value is int or value is bool:
				return int(value)
			return 0
		"float":
			if value is String:
				return str(value).to_float() if str(value).is_valid_float() else 0.0
			if value is float or value is int or value is bool:
				return float(value)
			return 0.0
		"String":
			if value is String:
				return value
			return "" if value == null else str(value)
		"bool":
			if value is String:
				return str(value).strip_edges().to_lower() in ["true", "1", "yes", "on"]
			if value is float or value is int or value is bool:
				return bool(value)
			return false
		"Vector2":
			return value if value is Vector2 else Vector2.ZERO
		"Color":
			return value if value is Color else Color(1.0, 1.0, 1.0, 1.0)
	if to_type.begins_with("Array"):
		return value if value is Array else []
	if to_type.begins_with("Dictionary"):
		return value if value is Dictionary else {}
	return value


## The Variant.Type a LocalVariable row stores alongside its type name (the four the sheet model
## tracks; everything else stays TYPE_NIL, exactly as the variable dialog stores it).
static func variant_type_for(type_name: String) -> int:
	match type_name:
		"int":
			return TYPE_INT
		"float":
			return TYPE_FLOAT
		"bool":
			return TYPE_BOOL
		"String":
			return TYPE_STRING
	return TYPE_NIL


static func is_string_literal(text: String) -> bool:
	var trimmed: String = text.strip_edges()
	return trimmed.length() >= 2 and trimmed.begins_with("\"") and trimmed.ends_with("\"")


## True for a plain value the user could have typed into a cell: "text", 12, -3.5, true.
static func is_literal(text: String) -> bool:
	var trimmed: String = text.strip_edges()
	if is_string_literal(trimmed):
		return not trimmed.substr(1, trimmed.length() - 2).contains("\"")
	return trimmed.is_valid_int() or trimmed.is_valid_float() or trimmed == "true" or trimmed == "false"


## The bare number inside a literal ("12" and 12 both give 12), or "" when there is none.
static func _numeric_text(text: String) -> String:
	var trimmed: String = text.strip_edges()
	var inner: String = trimmed.substr(1, trimmed.length() - 2).strip_edges() if is_string_literal(trimmed) else trimmed
	return inner if inner.is_valid_int() or inner.is_valid_float() else ""


## "true" / "false" for a yes-no literal in either form ("true" and true), else "".
static func _boolean_text(text: String) -> String:
	var trimmed: String = text.strip_edges()
	var inner: String = trimmed.substr(1, trimmed.length() - 2).strip_edges().to_lower() if is_string_literal(trimmed) else trimmed
	if inner in ["true", "yes", "on"]:
		return "true"
	if inner in ["false", "no", "off"]:
		return "false"
	return ""


static func _params_of(ace: Resource) -> Dictionary:
	if ace == null or not (ace.get("params") is Dictionary):
		return {}
	var params: Dictionary = ace.get("params")
	if params.is_empty() and ace.get("parameters") is Dictionary:
		return ace.get("parameters")
	return params


## Every condition/action/trigger under `rows`, each with a readable breadcrumb ("Group Loot >
## Event 2"), so the preview names the row a change lands on.
static func _collect_usages(rows: Array, trail: String, out: Array) -> void:
	var event_index: int = 0
	for row: Variant in rows:
		if row is EventGroup:
			var group: EventGroup = row as EventGroup
			var group_trail: String = "%s%s > " % [trail, group.group_name if not group.group_name.is_empty() else "Group"]
			_collect_usages(group.events if not group.events.is_empty() else group.rows, group_trail, out)
			continue
		if not (row is EventRow):
			continue
		event_index += 1
		var event_row: EventRow = row as EventRow
		var where: String = "%sEvent %d" % [trail, event_index]
		if event_row.trigger != null:
			out.append({"where": where, "ace": event_row.trigger})
		for condition: Variant in event_row.conditions:
			if condition is Resource and condition.get("params") is Dictionary:
				out.append({"where": where, "ace": condition as Resource})
		for action_entry: Variant in event_row.actions:
			if action_entry is Resource and action_entry.get("params") is Dictionary:
				out.append({"where": where, "ace": action_entry as Resource})
		_collect_usages(event_row.sub_events, "%s > " % where, out)
