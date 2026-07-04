# Godot EventSheets - identifier guardrails
# Event-sheet-style "you can't enter broken stuff": names that reach GDScript (variables, enums)
# are auto-corrected where possible (spaces/invalid chars → underscores, digit-led names
# prefixed) and BLOCKED with a clear message where not (keywords, empty results). Shared
# by the variable and enum dialogs so every commit point behaves the same.
@tool
class_name EventSheetIdentifierRules
extends RefCounted

const RESERVED: PackedStringArray = [
	"if", "elif", "else", "for", "while", "match", "when", "break", "continue", "pass",
	"return", "class", "class_name", "extends", "is", "in", "as", "self", "super",
	"signal", "func", "static", "const", "enum", "var", "await", "void",
	"true", "false", "null", "and", "or", "not", "breakpoint", "preload", "PI", "TAU", "INF", "NAN"
]


## Best-effort auto-correction toward a valid GDScript identifier ("" = unsalvageable).
static func sanitize(raw_name: String) -> String:
	var cleaned: String = ""
	for character in raw_name.strip_edges():
		if (character >= "a" and character <= "z") or (character >= "A" and character <= "Z") 				or (character >= "0" and character <= "9") or character == "_":
			cleaned += character
		elif character == " " or character == "-":
			cleaned += "_"
		# anything else is dropped
	if cleaned.is_empty():
		return ""
	if cleaned[0] >= "0" and cleaned[0] <= "9":
		cleaned = "_" + cleaned
	return cleaned


## True for a usable identifier (valid shape AND not a GDScript keyword/constant).
static func is_valid(name: String) -> bool:
	if name.is_empty() or RESERVED.has(name):
		return false
	var regex: RegEx = RegEx.new()
	if regex.compile("^[A-Za-z_][A-Za-z0-9_]*$") != OK:
		return false
	return regex.search(name) != null
