# EventForge — Variable parser
# Parses top-level `@export var`/`var` declarations from GDScript source into the sheet
# variable dictionary format ({ name: {type, default, exported, options, hint} }). Indented
# declarations (function locals) are ignored. This handles the var line itself only — the standalone
# `@export_group`/`@export_subgroup` lines that precede a variable are recovered separately, by the
# importer's `_absorb_tree_variable_group()` (which folds them onto the lifted variable's attributes).
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
		var hint: String = ""
		var combo_options: PackedStringArray = PackedStringArray()
		if line.begins_with("@export_enum(") and line.find(") ") != -1:
			exported = true
			var close_index: int = line.find(") ")
			for raw_option: String in line.substr("@export_enum(".length(), close_index - "@export_enum(".length()).split(", "):
				combo_options.append(raw_option.strip_edges().trim_prefix("\"").trim_suffix("\""))
			line = line.substr(close_index + 2).strip_edges()
		elif line.begins_with("@export_") and line.find(" var ") != -1:
			# Generic hinted export (@export_range / @export_file / @export_flags / …): keep the whole
			# annotation up to " var " verbatim so it round-trips; _try_lift_variable's byte-verify gates it.
			exported = true
			var var_index: int = line.find(" var ")
			hint = line.substr(0, var_index)
			line = line.substr(var_index + 1).strip_edges()
		elif line.begins_with("@export "):
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
			"exported": exported,
			"options": combo_options,
			"hint": hint
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
	# Constructor literals for game-value types (Vector2/Color): str_to_var yields the typed value, whose
	# canonical re-emission (sheet_compiler._to_code_literal) the verify-lift gates byte-for-byte.
	if value.ends_with(")") and (value.begins_with("Vector2(") or value.begins_with("Color(")):
		var built: Variant = str_to_var(value)
		if built is Vector2 or built is Color:
			return built
	return value
