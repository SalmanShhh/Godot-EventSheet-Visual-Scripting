# EventForge module — JSON (serialize, parse, validate, and save / load JSON files).
#
# The JSON text boundary as one coherent set: turn a value into JSON text (compact or pretty), parse
# JSON text back into a value (into a variable or inline), validate it, and read / write JSON files.
# Once parsed, the result is a normal Dictionary / Array — use the Variables: Dictionary / Array ACEs
# to read and edit it; this module only crosses the text boundary. Every op is a direct native
# JSON / FileAccess one-liner. Grouped under JSON.
#
# Consolidated out of the Collections module so JSON is its own thing. The moved ACEs keep their
# ace_ids AND codegen templates (the compatibility covenant) — only their picker category changed
# from "Variables: JSON" to "JSON". Path hints nudge user:// (res:// is read-only when exported).
@tool
extends RefCounted
class_name EventForgeJsonACEs

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	# ── Serialize: value -> JSON text ──
	descriptors.append(F.make_descriptor("Core", "JsonStringify", "To JSON Text", ACEDescriptor.ACEType.EXPRESSION, "JSON.stringify({value})", "", [F.make_param("value", "String", "data", "Value", "Value to serialize (Dictionary / Array / number / String / bool).", "expression")], "JSON", "JSON.stringify({value})"))
	descriptors.append(F.make_descriptor("Core", "JsonStringifyPretty", "To JSON Text (pretty)", ACEDescriptor.ACEType.EXPRESSION, "JSON.stringify({value}, \"\\t\")", "", [F.make_param("value", "String", "data", "Value", "Value to serialize as indented, human-readable JSON (for logs / readable save files).", "expression")], "JSON", "pretty JSON of {value}"))
	# ── Parse: JSON text -> value (Dictionary / Array / …; null when the text is invalid) ──
	descriptors.append(F.make_descriptor("Core", "JsonParse", "From JSON Text", ACEDescriptor.ACEType.EXPRESSION, "JSON.parse_string({text})", "", [F.make_param("text", "String", "\"{}\"", "Text", "JSON text to parse (returns null when invalid).", "expression")], "JSON", "JSON.parse_string({text})"))
	descriptors.append(F.make_descriptor("Core", "JsonParseToVar", "Parse JSON Into Variable", ACEDescriptor.ACEType.ACTION, "{var_name} = JSON.parse_string({text})", "", [F.make_param("var_name", "String", "data", "Into Variable", "Variable receiving the parsed value (null when the text is invalid).", "variable_reference"), F.make_param("text", "String", "\"{}\"", "Text", "JSON text to parse (e.g. from a server response or the clipboard).", "expression")], "JSON", "Parse {text} into {var_name}"))
	# ── Validate ──
	descriptors.append(F.make_descriptor("Core", "JsonIsValid", "JSON Is Valid", ACEDescriptor.ACEType.CONDITION, "JSON.parse_string({text}) != null", "", [F.make_param("text", "String", "\"{}\"", "Text", "JSON text to validate.", "expression")], "JSON", "{text} is valid JSON"))
	# ── Files: serialize straight to / from disk ──
	descriptors.append(F.make_descriptor("Core", "JsonSaveFile", "Save JSON File", ACEDescriptor.ACEType.ACTION, "FileAccess.open({path}, FileAccess.WRITE).store_string(JSON.stringify({value}, \"\\t\"))", "", [F.make_param("path", "String", "\"user://save.json\"", "Path", "File path (user:// is the writable location in exports).", "expression"), F.make_param("value", "String", "data", "Value", "Value to serialize and save (pretty-printed).", "expression")], "JSON", "Save {value} as JSON to {path}"))
	descriptors.append(F.make_descriptor("Core", "JsonLoadFile", "Load JSON File", ACEDescriptor.ACEType.ACTION, "{var_name} = JSON.parse_string(FileAccess.get_file_as_string({path}))", "", [F.make_param("var_name", "String", "data", "Into Variable", "Variable receiving the parsed value (null when missing / invalid).", "variable_reference"), F.make_param("path", "String", "\"user://save.json\"", "Path", "File path to read.", "expression")], "JSON", "Load JSON {path} into {var_name}"))

	return descriptors
