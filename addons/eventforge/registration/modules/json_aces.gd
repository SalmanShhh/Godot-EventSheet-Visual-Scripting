# EventForge module - JSON (serialize, parse, validate, and save / load JSON files).
#
# The JSON text boundary as one coherent set: turn a value into JSON text (compact or pretty), parse
# JSON text back into a value (into a variable or inline), validate it, and read / write JSON files.
# Once parsed, the result is a normal Dictionary / Array - use the Variables: Dictionary / Array ACEs
# to read and edit it; this module only crosses the text boundary. Every op is a direct native
# JSON / FileAccess one-liner. Grouped under JSON.
#
# Consolidated out of the Collections module so JSON is its own thing. The moved ACEs keep their
# ace_ids AND codegen templates (the compatibility covenant) - only their picker category changed
# from "Variables: JSON" to "JSON". Path hints nudge user:// (res:// is read-only when exported).
@tool
class_name EventForgeJsonACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	# ── Serialize: value -> JSON text ──
	descriptors.append(F.expr("JsonStringify", "To JSON Text", "JSON.stringify({value})", "JSON", "JSON.stringify({value})", "Turns a value like a dictionary or array into compact JSON text for saving or sending.").param("value", "data", "Value", "Value to serialize (Dictionary / Array / number / String / bool).", "expression"))
	descriptors.append(F.expr("JsonStringifyPretty", "To JSON Text (pretty)", "JSON.stringify({value}, \"\\t\")", "JSON", "pretty JSON of {value}", "Turns a value into neatly indented JSON text that's easy for humans to read.").param("value", "data", "Value", "Value to serialize as indented, human-readable JSON (for logs / readable save files).", "expression"))
	# ── Parse: JSON text -> value (Dictionary / Array / …; null when the text is invalid) ──
	descriptors.append(F.expr("JsonParse", "From JSON Text", "JSON.parse_string({text})", "JSON", "JSON.parse_string({text})", "Reads JSON text back into a usable value, returning nothing if the text is invalid.").param("text", "\"{}\"", "Text", "JSON text to parse (returns null when invalid).", "expression"))
	descriptors.append(F.act("JsonParseToVar", "Parse JSON Into Variable", "{var_name} = JSON.parse_string({text})", "JSON", "Parse {text} into {var_name}", "Parses JSON text and stores the result in a variable (null if the text is bad).").param("var_name", "data", "Into Variable", "Variable receiving the parsed value (null when the text is invalid).", "variable_reference").param("text", "\"{}\"", "Text", "JSON text to parse (e.g. from a server response or the clipboard).", "expression"))
	# ── Validate ──
	descriptors.append(F.cond("JsonIsValid", "JSON Is Valid", "JSON.parse_string({text}) != null", "JSON", "{text} is valid JSON", "True when the given text is valid JSON, so you can check before parsing it.").param("text", "\"{}\"", "Text", "JSON text to validate.", "expression"))
	# ── Files: serialize straight to / from disk ──
	descriptors.append(F.act("JsonSaveFile", "Save JSON File", "var __json_{uid} = FileAccess.open({path}, FileAccess.WRITE)\nif __json_{uid}:\n\t__json_{uid}.store_string(JSON.stringify({value}, \"\\t\"))\n\t__json_{uid}.close()", "JSON", "Save {value} as JSON to {path}", "Serializes a value to pretty JSON and writes it to a file in one step.").param("path", "\"user://save.json\"", "Path", "File path (user:// is the writable location in exports).", "expression").param("value", "data", "Value", "Value to serialize and save (pretty-printed).", "expression"))
	descriptors.append(F.act("JsonLoadFile", "Load JSON File", "{var_name} = JSON.parse_string(FileAccess.get_file_as_string({path}))", "JSON", "Load JSON {path} into {var_name}", "Reads a JSON file and parses it straight into a variable.").param("var_name", "data", "Into Variable", "Variable receiving the parsed value (null when missing / invalid).", "variable_reference").param("path", "\"user://save.json\"", "Path", "File path to read.", "expression"))

	return descriptors
