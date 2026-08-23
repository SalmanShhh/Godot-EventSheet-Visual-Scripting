# Godot EventSheets - the CODE ECHO a variable row carries at its right edge.
#
# A sheet IS a script here, and a variable row should not pretend otherwise: beside the sentence it
# reads ("Instance whole number hp = 100") the row shows the exact declaration the compiler emits
# for it (`var hp: int = 100`). The line is never formatted here - it comes from the compiler's own
# emitter over the very variable the row stands for - so the echo can never drift from the file.
#
# The colours are the script editor's own. A small tokeniser splits the line into eight classes
# (keyword / annotation / type / member / number / string / symbol / comment) and each class takes
# its colour from the user's Editor Settings (text_editor/theme/highlighting/*), falling back to the
# sheet theme's own tokens when there is no editor to ask - so a headless build, a preview render
# and a custom script theme all paint something sensible.
#
# PURE + STATIC. Nothing here reads a viewport or a dock; it takes a line and returns runs of
# coloured text, which is what makes the echo testable without a canvas.
@tool
class_name EventSheetCodeEcho
extends RefCounted

## The token classes, frozen: the colour table, the tests and the theme fallbacks address them by
## these names.
const TOKEN_KEYWORD: String = "keyword"
const TOKEN_ANNOTATION: String = "annotation"
const TOKEN_TYPE: String = "type"
const TOKEN_MEMBER: String = "member"
const TOKEN_NUMBER: String = "number"
const TOKEN_STRING: String = "string"
const TOKEN_SYMBOL: String = "symbol"
const TOKEN_COMMENT: String = "comment"
## Whitespace and anything the scanner does not claim - drawn in the row's own quiet tone.
const TOKEN_PLAIN: String = "plain"

## The View dial: how much of a variable row is drawn. `both` is the shipped default - the sentence
## leads and the declaration echoes at the right edge; `sentence` is the beginner reading (Simple
## Mode pins it there) and `code` makes the row the line it stands for. Frozen: the toolbar, the
## viewport and the tests address a mode by these.
const VIEW_SENTENCE: int = 0
const VIEW_BOTH: int = 1
const VIEW_CODE: int = 2

## The dial's words, in mode order - the labels the View menu shows.
const VIEW_LABELS: PackedStringArray = ["sentence", "both", "code"]

## How loud a resting code echo is. Full colour on the hovered row; this everywhere else, so the
## sentence stays the thing being read.
const REST_ALPHA: float = 0.6

## The GDScript words that read as keywords in a DECLARATION. Deliberately short: this is a
## declaration echo, not a syntax highlighter for whole function bodies.
const KEYWORDS: PackedStringArray = [
	"var", "const", "static", "func", "class", "class_name", "extends", "enum", "signal",
	"true", "false", "null", "self", "super", "preload", "load", "await", "not", "and", "or",
	"in", "is", "as", "if", "else", "elif", "for", "while", "return", "pass", "break", "continue",
]

## The built-in type names that are not engine classes, so `ClassDB` cannot answer for them.
const BUILTIN_TYPES: PackedStringArray = [
	"int", "float", "bool", "String", "StringName", "NodePath", "Variant", "Array", "Dictionary",
	"Vector2", "Vector2i", "Vector3", "Vector3i", "Vector4", "Vector4i", "Rect2", "Rect2i",
	"Transform2D", "Transform3D", "Basis", "Quaternion", "Plane", "AABB", "Projection", "Color",
	"Callable", "Signal", "RID", "PackedByteArray", "PackedInt32Array", "PackedInt64Array",
	"PackedFloat32Array", "PackedFloat64Array", "PackedStringArray", "PackedVector2Array",
	"PackedVector3Array", "PackedColorArray",
]

## Editor Settings key per token class - the same eight the script editor colours GDScript with.
const EDITOR_SETTING_KEYS: Dictionary = {
	TOKEN_KEYWORD: "text_editor/theme/highlighting/keyword_color",
	TOKEN_ANNOTATION: "text_editor/theme/highlighting/gdscript/annotation_color",
	TOKEN_TYPE: "text_editor/theme/highlighting/base_type_color",
	TOKEN_MEMBER: "text_editor/theme/highlighting/member_variable_color",
	TOKEN_NUMBER: "text_editor/theme/highlighting/number_color",
	TOKEN_STRING: "text_editor/theme/highlighting/string_color",
	TOKEN_SYMBOL: "text_editor/theme/highlighting/symbol_color",
	TOKEN_COMMENT: "text_editor/theme/highlighting/comment_color",
}


## The line split into runs: [{"text": ..., "token": ...}], in order, concatenating back to the
## input exactly. A run is never empty, and adjacent runs of the same class are kept apart only
## where the scanner met them apart - the colour is the same either way.
static func tokens(line: String) -> Array[Dictionary]:
	var runs: Array[Dictionary] = []
	var cursor: int = 0
	var length: int = line.length()
	while cursor < length:
		var character: String = line[cursor]
		if character == "#":
			runs.append({"text": line.substr(cursor), "token": TOKEN_COMMENT})
			break
		if character == "\"" or character == "'":
			var closed: int = _string_end(line, cursor)
			runs.append({"text": line.substr(cursor, closed - cursor), "token": TOKEN_STRING})
			cursor = closed
			continue
		if character == "@":
			var annotation_end: int = _identifier_end(line, cursor + 1)
			runs.append({"text": line.substr(cursor, annotation_end - cursor), "token": TOKEN_ANNOTATION})
			cursor = annotation_end
			continue
		if _is_identifier_start(character):
			var word_end: int = _identifier_end(line, cursor)
			var word: String = line.substr(cursor, word_end - cursor)
			runs.append({"text": word, "token": word_token(word)})
			cursor = word_end
			continue
		if character.is_valid_int() or (character == "." and cursor + 1 < length and line[cursor + 1].is_valid_int()):
			var number_end: int = _number_end(line, cursor)
			runs.append({"text": line.substr(cursor, number_end - cursor), "token": TOKEN_NUMBER})
			cursor = number_end
			continue
		if character == " " or character == "\t":
			var space_end: int = cursor
			while space_end < length and (line[space_end] == " " or line[space_end] == "\t"):
				space_end += 1
			runs.append({"text": line.substr(cursor, space_end - cursor), "token": TOKEN_PLAIN})
			cursor = space_end
			continue
		runs.append({"text": character, "token": TOKEN_SYMBOL})
		cursor += 1
	return runs


## The class a bare word reads as: a language word, a type name, or the thing being declared.
static func word_token(word: String) -> String:
	if KEYWORDS.has(word):
		return TOKEN_KEYWORD
	if BUILTIN_TYPES.has(word) or ClassDB.class_exists(word):
		return TOKEN_TYPE
	return TOKEN_MEMBER


## Token class -> Color. The user's script-editor theme where there is an editor to ask, the sheet
## theme's own tokens otherwise, so a headless render and a custom script theme both paint.
static func palette(reading: EventSheetReadingStyle, event_style: EventSheetEventStyle) -> Dictionary:
	var colours: Dictionary = _theme_palette(reading, event_style)
	if not Engine.is_editor_hint() or not Engine.has_singleton("EditorInterface"):
		return colours
	var editor_interface: Object = Engine.get_singleton("EditorInterface")
	if not editor_interface.has_method("get_editor_settings"):
		return colours
	var settings: Object = editor_interface.call("get_editor_settings")
	if settings == null:
		return colours
	for token_name: String in EDITOR_SETTING_KEYS:
		var key: String = str(EDITOR_SETTING_KEYS[token_name])
		if settings.has_method("has_setting") and not bool(settings.call("has_setting", key)):
			continue
		var value: Variant = settings.call("get_setting", key)
		if value is Color:
			colours[token_name] = value as Color
	return colours


## The fallback table: every class answered from tokens the sheet theme already dresses, so a
## preset the user picked colours the echo even with no editor in sight.
static func _theme_palette(reading: EventSheetReadingStyle, event_style: EventSheetEventStyle) -> Dictionary:
	var marks: EventSheetReadingStyle = reading if reading != null else EventSheetReadingStyle.new()
	var sheet: EventSheetEventStyle = event_style if event_style != null else EventSheetEventStyle.new()
	return {
		TOKEN_KEYWORD: marks.boolean_value_color,
		TOKEN_ANNOTATION: marks.category_chip_foreground_color,
		TOKEN_TYPE: sheet.column_header_conditions_color,
		TOKEN_MEMBER: marks.primary_text_color,
		TOKEN_NUMBER: sheet.value_highlight_color,
		TOKEN_STRING: marks.string_value_color,
		TOKEN_SYMBOL: marks.muted_text_color,
		TOKEN_COMMENT: sheet.comment_text_color,
		TOKEN_PLAIN: marks.secondary_text_color,
	}


## The line as draw-ready segments (the shape the renderer's styled-cell path takes), each run at
## `alpha` of its class colour. Built DIRECTLY, never through the BBCode parser: code text is full
## of square brackets and a parser eats them as tags.
static func segments(line: String, colours: Dictionary, alpha: float) -> Array[Dictionary]:
	var built: Array[Dictionary] = []
	for run: Dictionary in tokens(line):
		var token_name: String = str(run.get("token", TOKEN_PLAIN))
		var base: Color = colours.get(token_name, colours.get(TOKEN_PLAIN, Color.WHITE))
		built.append({
			"text": str(run.get("text", "")),
			"color": Color(base.r, base.g, base.b, base.a * clampf(alpha, 0.0, 1.0)),
			"bold": false,
			"italic": false,
		})
	return built


## The declaration line for a member/tree variable: the compiler's own emitter, so the echo is the
## file. "" when the variable has no name to declare.
static func line_for(variable: LocalVariable) -> String:
	if variable == null:
		return ""
	return declaration_line(SheetCompiler._emit_tree_variable_line(variable))


## The declaration line for a sheet-level (dictionary) variable: the compiler's OWN emitter for those
## variables, handed a one-entry dictionary. A sheet variable is not emitted by the tree-variable
## path, and the two disagree about several facts a descriptor can carry - `@export_multiline`, the
## read-only export, the `set(value):` block a clamp or an On Changed writes - so building a stand-in
## LocalVariable here echoed a line the file does not contain. There is one formatter, and it is the
## one that writes the file.
static func line_for_descriptor(var_name: String, descriptor: Dictionary) -> String:
	if var_name.strip_edges().is_empty():
		return ""
	return declaration_line("\n".join(SheetCompiler._emit_variables({var_name: descriptor})))


## The DECLARATION out of what the emitter wrote for a variable. The emitter also writes the doc
## comment above the line and the `@export_group` header that opens an Inspector section - both true
## of the file, neither a declaration - so the echo takes the first line that declares something and
## leaves the rest where it belongs (the description already sits on the row; the group names the
## folder strip above it).
static func declaration_line(emitted: String) -> String:
	for line: String in emitted.split("\n"):
		var bare: String = line.strip_edges()
		if bare.is_empty() or bare.begins_with("#"):
			continue
		if bare.begins_with("@export_group(") or bare.begins_with("@export_subgroup(") \
				or bare.begins_with("@export_category("):
			continue
		return line
	return ""


## How a GLOBAL read in this sheet is written here: `Game.Score`, the form you would type in an
## expression. The autoload's own declaration lives on its own sheet, and echoing it here would
## claim a line this file does not have.
static func reference_line(autoload_name: String, var_name: String) -> String:
	var owner_name: String = autoload_name.strip_edges()
	if owner_name.is_empty() or var_name.strip_edges().is_empty():
		return ""
	return "%s.%s" % [owner_name, var_name.strip_edges()]


## True for a character an identifier may start with.
static func _is_identifier_start(character: String) -> bool:
	return character == "_" or (character.to_lower() != character.to_upper())


## One past the end of the identifier starting at `from`.
static func _identifier_end(line: String, from: int) -> int:
	var cursor: int = from
	while cursor < line.length():
		var character: String = line[cursor]
		if character == "_" or character.is_valid_int() or character.to_lower() != character.to_upper():
			cursor += 1
			continue
		break
	return maxi(cursor, from + 1)


## One past the end of the number starting at `from` (digits, one decimal point, an exponent).
static func _number_end(line: String, from: int) -> int:
	var cursor: int = from
	while cursor < line.length():
		var character: String = line[cursor]
		if character.is_valid_int() or character == "." or character == "_":
			cursor += 1
			continue
		if (character == "e" or character == "E") and cursor + 1 < line.length():
			cursor += 1
			continue
		if (character == "-" or character == "+") and cursor > from and (line[cursor - 1] == "e" or line[cursor - 1] == "E"):
			cursor += 1
			continue
		break
	return maxi(cursor, from + 1)


## One past the closing quote of the string starting at `from`, or the end of the line when the
## quote is never closed (an echo is a reading, so it never refuses to draw).
static func _string_end(line: String, from: int) -> int:
	var quote: String = line[from]
	var cursor: int = from + 1
	while cursor < line.length():
		if line[cursor] == "\\":
			cursor += 2
			continue
		if line[cursor] == quote:
			return cursor + 1
		cursor += 1
	return line.length()
