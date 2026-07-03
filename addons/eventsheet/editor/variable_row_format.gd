# EventForge — Variable row text formatting helpers.
# Pure, stateless formatters for variable summaries and tooltips used by the
# virtualized event sheet editor (and covered by variable_row_format_test.gd).
@tool
class_name VariableRowFormat
extends RefCounted


## Returns a formatted summary string for a variable.
## info may contain: type (String), default (Variant), value (Variant)
static func format_summary(name: String, info: Dictionary) -> String:
	var type_str: String = str(info.get("type", "Variant"))
	var raw_default: Variant = info.get("default", info.get("value", null))
	var default_str: String = _format_default(type_str, raw_default)
	return "%s (%s) = %s" % [name, type_str, default_str]


## Returns compact tooltip text for a variable row.
## Includes optional description when present.
static func format_tooltip(name: String, info: Dictionary) -> String:
	var type_str: String = str(info.get("type", "Variant"))
	var raw_default: Variant = info.get("default", info.get("value", null))
	var default_str: String = _format_default(type_str, raw_default)
	var lines: Array[String] = []
	lines.append("%s (%s)" % [name, type_str])
	lines.append("Default: %s" % default_str)
	var description: String = str(info.get("description", "")).strip_edges()
	if not description.is_empty():
		lines.append("")
		lines.append(description)
	return "\n".join(lines)


## Formats a default value for display.
static func _format_default(type_str: String, raw: Variant) -> String:
	if raw == null:
		return "null"
	if type_str == "String" or type_str == "StringName":
		var s: String = str(raw)
		if s.begins_with('"') and s.ends_with('"') and s.length() >= 2:
			s = s.substr(1, s.length() - 2)
		s = s.replace('"', '\\"')
		return '"%s"' % s
	if type_str == "float":
		var f: float = float(raw)
		var s: String = str(f)
		if not "." in s and not "e" in s and not "inf" in s and not "nan" in s:
			s = s + ".0"
		return s
	return str(raw)
