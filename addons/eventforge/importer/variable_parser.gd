# EventForge — Variable parser
# Parses top-level `@export var`/`var` declarations from GDScript source into the sheet
# variable dictionary format ({ name: {type, default, exported} }). Indented declarations
# (function locals) are ignored.
@tool
extends RefCounted
class_name VariableParser

func parse(source: String) -> Dictionary:
	var variables: Dictionary = {}
	for raw_line: String in source.split("\n"):
		# Only column-0 declarations are sheet variables; indented `var`s are function locals.
		if raw_line.begins_with("\t") or raw_line.begins_with(" "):
			continue
		var line: String = raw_line.strip_edges()
		var exported: bool = false
		if line.begins_with("@export "):
			exported = true
			line = line.substr("@export ".length()).strip_edges()
		if not line.begins_with("var "):
			continue
		var rest: String = line.substr(4).strip_edges()
		var equals_index: int = rest.find("=")
		var declaration: String = rest.substr(0, equals_index).strip_edges() if equals_index >= 0 else rest
		var default_text: String = rest.substr(equals_index + 1).strip_edges() if equals_index >= 0 else ""
		var variable_name: String = declaration
		var type_name: String = "Variant"
		var colon_index: int = declaration.find(":")
		if colon_index >= 0:
			variable_name = declaration.substr(0, colon_index).strip_edges()
			type_name = declaration.substr(colon_index + 1).strip_edges()
		if variable_name.is_empty():
			continue
		variables[variable_name] = {
			"type": type_name,
			"default": _parse_literal(default_text),
			"exported": exported
		}
	return variables

## Parses a GDScript literal into a typed Variant (primitives round-trip through the
## compiler's _to_code_literal; complex expressions are kept as raw strings).
func _parse_literal(text: String) -> Variant:
	var value: String = text.strip_edges()
	if value.is_empty() or value == "null":
		return null
	if value == "true":
		return true
	if value == "false":
		return false
	if value.length() >= 2 and value.begins_with("\"") and value.ends_with("\""):
		return value.substr(1, value.length() - 2)
	if value.is_valid_int():
		return value.to_int()
	if value.is_valid_float():
		return value.to_float()
	# Container literals (canonical compiler emissions are str_to_var-parseable; the
	# verify-lift byte check rejects anything whose re-emission differs).
	if (value.begins_with("[") and value.ends_with("]")) or (value.begins_with("{") and value.ends_with("}")):
		var parsed: Variant = str_to_var(value)
		if parsed != null:
			return parsed
	return value
