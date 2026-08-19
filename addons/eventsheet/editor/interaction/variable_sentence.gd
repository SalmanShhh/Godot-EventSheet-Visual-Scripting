# Godot EventSheets - the ONE sentence a variable reads with, wherever it appears.
#
# An event sheet says a variable exactly one way: `<scope> <type> <name> = <value>` - "Global number
# Score = 0", "Instance boolean alive = true", "Local text name = """, "Constant number MAX = 10".
# Godot has more scopes than the sheet does (a plain member, a `const`, a `static var`, a field on a
# Resource, an autoload's member) and more type spellings than a reader wants, so this maps every one
# of them onto that one shape. The head, the Local rows inside an event, Object properties, the Add
# variable dialog's preview and the Manual all compose their chip through here, which is why they can
# never disagree about how a variable is spelled.
#
# PURE + STATIC. Nothing here reads a viewport, a dock or a file; it takes the facts a variable
# already carries and returns words. That is what makes the one shape testable without a canvas.
@tool
class_name EventSheetVariableSentence
extends RefCounted

## The scope keys. Frozen: rows, tests and the dialog all address a scope by these.
const SCOPE_GLOBAL: String = "global"
const SCOPE_INSTANCE: String = "instance"
const SCOPE_LOCAL: String = "local"
const SCOPE_CONSTANT: String = "constant"
const SCOPE_STATIC: String = "static"
const SCOPE_FIELD: String = "field"

## The order the Add variable dialog offers them in - the sheet's own order, commonest first.
const SCOPE_ORDER: PackedStringArray = [
	SCOPE_INSTANCE, SCOPE_LOCAL, SCOPE_GLOBAL, SCOPE_CONSTANT, SCOPE_STATIC
]

## The type words a variable reads with, in the order the Add variable dialog offers them. The
## remainder ("scene", "any", a class name) live behind the dialog's "more" menu.
const TYPE_WORD_ORDER: PackedStringArray = [
	"number", "whole number", "text", "boolean", "vector", "color", "list", "table", "object"
]

## Type word -> the GDScript type it writes. "list" and "table" stay bare here; the dialog's
## element-type field turns a list into `Array[String]` when one is chosen.
const TYPE_WORD_TO_GDSCRIPT: Dictionary = {
	"number": "float",
	"whole number": "int",
	"text": "String",
	"boolean": "bool",
	"vector": "Vector2",
	"color": "Color",
	"list": "Array",
	"table": "Dictionary",
	"object": "Node",
	"scene": "PackedScene",
	"any": "Variant"
}


## The scope word a reader sees. Translated, because it is the first word of every variable row.
static func scope_word(scope: String) -> String:
	match scope:
		SCOPE_GLOBAL:
			return EventSheetL10n.translate("Global")
		SCOPE_INSTANCE:
			return EventSheetL10n.translate("Instance")
		SCOPE_LOCAL:
			return EventSheetL10n.translate("Local")
		SCOPE_CONSTANT:
			return EventSheetL10n.translate("Constant")
		SCOPE_STATIC:
			return EventSheetL10n.translate("Static")
		SCOPE_FIELD:
			return EventSheetL10n.translate("Field")
	return ""


## The chip that leads a variable row: the scope word, then the type in plain words. Either half
## alone still reads (a scope nothing settles keeps just the type).
static func chip_text(scope: String, type_word: String) -> String:
	var word: String = scope_word(scope)
	if word.is_empty():
		return type_word
	if type_word.strip_edges().is_empty():
		return word
	return "%s %s" % [word, type_word]


## The scope a MEMBER variable of a sheet has: `const` is a Constant, `static var` is Static, a
## member of an autoload is Global, a member of a Resource script is a Field, and everything else is
## an Instance variable of the object the script is.
static func member_scope(is_constant: bool, is_static: bool, autoload: bool, resource_host: bool) -> String:
	if is_constant:
		return SCOPE_CONSTANT
	if is_static:
		return SCOPE_STATIC
	if autoload:
		return SCOPE_GLOBAL
	if resource_host:
		return SCOPE_FIELD
	return SCOPE_INSTANCE


## True when the class a sheet's script extends is a Resource - the scripts whose members are Fields
## of a data asset rather than Instance variables of an object in the scene.
static func is_resource_host(host_class: String) -> bool:
	var bare: String = host_class.strip_edges()
	if bare.is_empty():
		return false
	return ClassDB.class_exists(bare) and ClassDB.is_parent_class(bare, "Resource")


## A colour as the sheet prints it: the word for the handful of colours anybody says out loud, else
## the hex everybody can read. Never raw floats - "0.31, 0.44, 0.29, 1" answers nothing the swatch
## beside it has not already answered.
static func color_text(colour: Color) -> String:
	var word: String = EventSheetSettingFacts.colour_word(colour)
	return word if not word.is_empty() else hex_text(colour)


## `#rrggbb`, or `#rrggbbaa` when the colour is not fully opaque.
static func hex_text(colour: Color) -> String:
	return EventSheetSettingFacts.colour_hex(colour)


## A picked colour written back in THE SPELLING THE LINE ALREADY USED, so writing a colour through
## the swatch moves the value and nothing else: `Color.RED` stays a named constant when the new
## colour has a name (and falls back to hex when it does not), `Color("#ff9b3c")` stays a hex string,
## `Color(1, 0.6, 0.2)` stays numbers with the argument count it was written with.
static func color_literal_in_spelling(colour: Color, source_text: String) -> String:
	var source: String = source_text.strip_edges()
	if source.begins_with("Color."):
		var name_constant: String = color_constant_name(colour)
		if not name_constant.is_empty():
			return "Color.%s" % name_constant
		return "Color(\"%s\")" % hex_text(colour)
	if source.begins_with("Color(\"") or source.begins_with("Color('"):
		return "Color(\"%s\")" % hex_text(colour)
	if source.begins_with("\"#") or source.begins_with("#"):
		return hex_text(colour)
	var keep_alpha: bool = not is_equal_approx(colour.a, 1.0) or _spelled_with_alpha(source)
	var numbers: PackedStringArray = PackedStringArray([
		_number_text(colour.r), _number_text(colour.g), _number_text(colour.b)
	])
	if keep_alpha:
		numbers.append(_number_text(colour.a))
	return "Color(%s)" % ", ".join(numbers)


## The `Color.NAME` constant a colour matches, "" when it matches none. Derived from the words the
## setting facts already name, so the swatch, the row and the write-back never name a colour three
## different ways.
static func color_constant_name(colour: Color) -> String:
	for key: String in EventSheetSettingFacts.COLOUR_WORDS:
		var parts: PackedStringArray = key.split(",")
		if parts.size() < 4:
			continue
		var candidate := Color(float(parts[0]), float(parts[1]), float(parts[2]), float(parts[3]))
		if candidate.is_equal_approx(colour):
			return str(EventSheetSettingFacts.COLOUR_WORDS[key]).to_upper()
	return ""


## True when the source literal spelled four arguments - a `Color(1, 1, 1, 1)` keeps its four.
static func _spelled_with_alpha(source: String) -> bool:
	if not source.begins_with("Color("):
		return false
	return source.trim_prefix("Color(").trim_suffix(")").split(",").size() >= 4


## A colour channel as GDScript spells it: no trailing zeroes a reader has to skip, but never an
## integer where a float was meant (`1` is a valid float literal in a Color call).
static func _number_text(value: float) -> String:
	var text: String = String.num(value, 4)
	while text.contains(".") and text.ends_with("0"):
		text = text.substr(0, text.length() - 1)
	if text.ends_with("."):
		text = text.substr(0, text.length() - 1)
	return text if not text.is_empty() else "0"
