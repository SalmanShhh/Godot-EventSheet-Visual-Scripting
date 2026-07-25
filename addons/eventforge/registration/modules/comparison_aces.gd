# EventForge module - comparing values of every kind
#
# Compare Variable and Compare Values already handle `a == b`, `a < b` and friends for anything that
# compares with an operator. This module is the rest: the comparisons that need a METHOD, a tolerance,
# or a type test, and which a sheet author would otherwise have to write as an ƒx expression.
#
# Grouped by what is being compared, because the right question depends on the type:
#   Text    - case-insensitive matching, prefixes, wildcards, sort order
#   Numbers - tolerance, ranges, parity, multiples, sign
#   Vectors - approximate equality, distance, direction (never `==`, see below)
#   Types   - what IS this value, and are two values even comparable
#   Objects - identity, liveness, and what a node can do
#
# The recurring trap this exists to close: `==` on floats and vectors is a coin flip, because tiny
# rounding differences survive arithmetic. Vectors Are Equal and Values Are Near use Godot's approx
# comparisons instead, which is what you almost always meant.
#
# Module contract: see ace_factory.gd - ace_ids/templates are API (compatibility
# covenant); this file only changes where the descriptors are AUTHORED.
@tool
class_name EventForgeComparisonACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

const CAT_TEXT := "Compare: Text"
const CAT_NUMBERS := "Compare: Numbers"
const CAT_VECTORS := "Compare: Vectors"
const CAT_TYPES := "Compare: Types"
const CAT_OBJECTS := "Compare: Objects"

## The Variant types a sheet author actually tests for, as their real constant names.
const VALUE_TYPES: Array = [
	{"key": "TYPE_NIL", "label": "Nothing (null)"},
	{"key": "TYPE_BOOL", "label": "true / false"},
	{"key": "TYPE_INT", "label": "Whole number (int)"},
	{"key": "TYPE_FLOAT", "label": "Decimal number (float)"},
	{"key": "TYPE_STRING", "label": "Text"},
	{"key": "TYPE_VECTOR2", "label": "Vector2"},
	{"key": "TYPE_VECTOR3", "label": "Vector3"},
	{"key": "TYPE_COLOR", "label": "Color"},
	{"key": "TYPE_ARRAY", "label": "List (Array)"},
	{"key": "TYPE_DICTIONARY", "label": "Dictionary"},
	{"key": "TYPE_OBJECT", "label": "Object / Node"}
]


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []
	_add_text(descriptors)
	_add_numbers(descriptors)
	_add_vectors(descriptors)
	_add_types(descriptors)
	_add_objects(descriptors)
	return descriptors


# ── Text ──
static func _add_text(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.make_descriptor("Core", "TextEqualsIgnoreCase", "Text Equals (ignore case)", ACEDescriptor.ACEType.CONDITION, "{a}.to_lower() == {b}.to_lower()", "", [F.make_param("a", "String", "\"\"", "First", "Left text.", "expression"), F.make_param("b", "String", "\"\"", "Second", "Right text.", "expression")], CAT_TEXT, "{a} equals {b} (ignoring case)")
		.described("True when two pieces of text are the same, treating capitals and lowercase as identical - what you want for a typed-in name or a cheat code.").featured())
	descriptors.append(F.make_descriptor("Core", "TextBeginsWith", "Text Begins With", ACEDescriptor.ACEType.CONDITION, "{text}.begins_with({prefix})", "", [F.make_param("text", "String", "\"\"", "Text", "Text to test.", "expression"), F.make_param("prefix", "String", "\"\"", "Prefix", "What it should start with.", "expression")], CAT_TEXT, "{text} begins with {prefix}")
		.described("True when text starts with something - filtering commands, ids with a prefix, or file paths."))
	descriptors.append(F.make_descriptor("Core", "TextIsEmpty", "Text Is Empty", ACEDescriptor.ACEType.CONDITION, "{text}.is_empty()", "", [F.make_param("text", "String", "\"\"", "Text", "Text to test.", "expression")], CAT_TEXT, "{text} is empty")
		.described("True when text has no characters at all. Note that a single space is NOT empty."))
	descriptors.append(F.make_descriptor("Core", "TextIsBlank", "Text Is Blank", ACEDescriptor.ACEType.CONDITION, "{text}.strip_edges().is_empty()", "", [F.make_param("text", "String", "\"\"", "Text", "Text to test.", "expression")], CAT_TEXT, "{text} is blank")
		.described("True when text is empty OR only spaces - the check a name-entry box actually wants, since \"   \" should not count as a name."))
	descriptors.append(F.make_descriptor("Core", "TextMatchesPattern", "Text Matches Pattern", ACEDescriptor.ACEType.CONDITION, "{text}.match({pattern})", "", [F.make_param("text", "String", "\"\"", "Text", "Text to test.", "expression"), F.make_param("pattern", "String", "\"*\"", "Pattern", "Wildcard pattern: * is any run of characters, ? is any single one.", "expression")], CAT_TEXT, "{text} matches {pattern}")
		.described("True when text fits a wildcard pattern, where * stands for any run of characters and ? for one - simpler than a regular expression for things like \"level_*\"."))
	descriptors.append(F.make_descriptor("Core", "TextIsOneOf", "Text Is One Of", ACEDescriptor.ACEType.CONDITION, "{text} in {options}", "", [F.make_param("text", "String", "\"\"", "Text", "Text to test.", "expression"), F.make_param("options", "String", "[\"a\", \"b\"]", "Options", "List of accepted values.", "expression")], CAT_TEXT, "{text} is one of {options}")
		.described("True when text is one of a list of accepted values - one row instead of a chain of \"or equals\" conditions."))
	descriptors.append(F.make_descriptor("Core", "TextSortsBefore", "Text Sorts Before", ACEDescriptor.ACEType.CONDITION, "{a}.casecmp_to({b}) < 0", "", [F.make_param("a", "String", "\"\"", "First", "Left text.", "expression"), F.make_param("b", "String", "\"\"", "Second", "Right text.", "expression")], CAT_TEXT, "{a} sorts before {b}")
		.described("True when the first text comes before the second alphabetically, ignoring case - for ordering names or building a sorted list."))
	descriptors.append(F.make_descriptor("Core", "TextNaturalOrder", "Text Natural Order", ACEDescriptor.ACEType.EXPRESSION, "{a}.naturalnocasecmp_to({b})", "", [F.make_param("a", "String", "\"\"", "First", "Left text.", "expression"), F.make_param("b", "String", "\"\"", "Second", "Right text.", "expression")], CAT_TEXT, "natural order of {a} vs {b}")
		.described("Compares two pieces of text the way a person would read numbers in them, so \"item2\" comes before \"item10\". Negative if the first sorts earlier, 0 if equal, positive if later."))


# ── Numbers ──
static func _add_numbers(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.make_descriptor("Core", "ValuesAreNear", "Values Are Near", ACEDescriptor.ACEType.CONDITION, "absf({a} - {b}) <= {tolerance}", "", [F.make_param("a", "String", "0.0", "First", "Left value.", "expression"), F.make_param("b", "String", "0.0", "Second", "Right value.", "expression"), F.make_param("tolerance", "String", "0.01", "Tolerance", "How far apart they may be and still count as equal.", "expression")], CAT_NUMBERS, "{a} is within {tolerance} of {b}")
		.described("True when two numbers are close enough to count as the same. Decimal numbers almost never land exactly equal after any arithmetic, so this is the comparison you usually want instead of ==.").featured())
	descriptors.append(F.make_descriptor("Core", "IsOutsideRange", "Is Outside Range", ACEDescriptor.ACEType.CONDITION, "({value} < {min} or {value} > {max})", "", [F.make_param("value", "String", "0", "Value", "Value to test.", "expression"), F.make_param("min", "String", "0", "Min", "Lower bound (inclusive).", "expression"), F.make_param("max", "String", "10", "Max", "Upper bound (inclusive).", "expression")], CAT_NUMBERS, "{value} is outside {min}..{max}")
		.described("True when a value falls below the low bound or above the high one - the mirror of Is Between Values, for culling things that wandered off."))
	descriptors.append(F.make_descriptor("Core", "IsPositive", "Is Positive", ACEDescriptor.ACEType.CONDITION, "{value} > 0", "", [F.make_param("value", "String", "0", "Value", "Value to test.", "expression")], CAT_NUMBERS, "{value} is positive")
		.described("True when a number is greater than zero. Zero itself is neither positive nor negative."))
	descriptors.append(F.make_descriptor("Core", "IsNegative", "Is Negative", ACEDescriptor.ACEType.CONDITION, "{value} < 0", "", [F.make_param("value", "String", "0", "Value", "Value to test.", "expression")], CAT_NUMBERS, "{value} is negative")
		.described("True when a number is less than zero - a spent balance, a reversed direction, a debt."))
	descriptors.append(F.make_descriptor("Core", "IsEven", "Is Even", ACEDescriptor.ACEType.CONDITION, "int({value}) % 2 == 0", "", [F.make_param("value", "String", "0", "Value", "Whole number to test.", "expression")], CAT_NUMBERS, "{value} is even")
		.described("True for even whole numbers - alternating rows, checkerboards, every-other-turn rules."))
	descriptors.append(F.make_descriptor("Core", "IsOdd", "Is Odd", ACEDescriptor.ACEType.CONDITION, "int({value}) % 2 != 0", "", [F.make_param("value", "String", "0", "Value", "Whole number to test.", "expression")], CAT_NUMBERS, "{value} is odd")
		.described("True for odd whole numbers - the other half of an alternating pattern."))
	descriptors.append(F.make_descriptor("Core", "IsMultipleOf", "Is Multiple Of", ACEDescriptor.ACEType.CONDITION, "(int({divisor}) != 0 and int({value}) % int({divisor}) == 0)", "", [F.make_param("value", "String", "0", "Value", "Whole number to test.", "expression"), F.make_param("divisor", "String", "5", "Multiple Of", "The step size, e.g. 5 for every fifth.", "expression")], CAT_NUMBERS, "{value} is a multiple of {divisor}")
		.described("True every Nth number - a milestone at every 10 kills, a wave every 5 rounds. Guards against a divisor of zero, which would otherwise crash."))
	descriptors.append(F.make_descriptor("Core", "IsWholeNumber", "Is A Whole Number", ACEDescriptor.ACEType.CONDITION, "is_equal_approx({value}, floor({value}))", "", [F.make_param("value", "String", "0.0", "Value", "Value to test.", "expression")], CAT_NUMBERS, "{value} is a whole number")
		.described("True when a decimal number has nothing after the point - useful for snapping checks and grid alignment."))
	descriptors.append(F.make_descriptor("Core", "CompareResult", "Compare Result", ACEDescriptor.ACEType.EXPRESSION, "signi(int(sign({a} - {b})))", "", [F.make_param("a", "String", "0", "First", "Left value.", "expression"), F.make_param("b", "String", "0", "Second", "Right value.", "expression")], CAT_NUMBERS, "compare {a} to {b}")
		.described("Gives -1, 0 or 1 for \"less than, equal to, greater than\" in one value - the shape a sort comparison wants, instead of branching twice."))


# ── Vectors ──
static func _add_vectors(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.make_descriptor("Core", "VectorsAreEqual", "Vectors Are Equal", ACEDescriptor.ACEType.CONDITION, "{a}.is_equal_approx({b})", "", [F.make_param("a", "String", "Vector2.ZERO", "First", "Left vector.", "expression"), F.make_param("b", "String", "Vector2.ZERO", "Second", "Right vector.", "expression")], CAT_VECTORS, "{a} equals {b}")
		.described("True when two vectors are the same allowing for rounding. Comparing positions with == almost never works, because any arithmetic leaves a tiny remainder.").featured())
	descriptors.append(F.make_descriptor("Core", "IsWithinDistance", "Is Within Distance", ACEDescriptor.ACEType.CONDITION, "{a}.distance_to({b}) <= {distance}", "", [F.make_param("a", "String", "Vector2.ZERO", "From", "First point, e.g. global_position.", "expression"), F.make_param("b", "String", "Vector2.ZERO", "To", "Second point.", "expression"), F.make_param("distance", "String", "100.0", "Distance", "How close counts.", "expression")], CAT_VECTORS, "{a} is within {distance} of {b}")
		.described("True when two points are no further apart than a distance - proximity, aggro range, \"close enough to interact\".").featured())
	descriptors.append(F.make_descriptor("Core", "IsFartherThan", "Is Farther Than", ACEDescriptor.ACEType.CONDITION, "{a}.distance_to({b}) > {distance}", "", [F.make_param("a", "String", "Vector2.ZERO", "From", "First point, e.g. global_position.", "expression"), F.make_param("b", "String", "Vector2.ZERO", "To", "Second point.", "expression"), F.make_param("distance", "String", "600.0", "Distance", "How far is too far.", "expression")], CAT_VECTORS, "{a} is farther than {distance} from {b}")
		.described("True when two points are further apart than a distance - despawning strays, dropping a chase, culling what nobody can see."))
	descriptors.append(F.make_descriptor("Core", "PointsSameDirection", "Points The Same Way", ACEDescriptor.ACEType.CONDITION, "{a}.normalized().dot({b}.normalized()) >= {threshold}", "", [F.make_param("a", "String", "Vector2.RIGHT", "First", "First direction.", "expression"), F.make_param("b", "String", "Vector2.RIGHT", "Second", "Second direction.", "expression"), F.make_param("threshold", "String", "0.7", "Agreement", "1.0 is identical, 0.0 is a right angle, -1.0 is opposite. 0.7 is roughly within 45 degrees.", "expression")], CAT_VECTORS, "{a} points the same way as {b}")
		.described("True when two directions broadly agree - is the enemy facing me, am I moving the way I am aiming, is this surface a floor. The Agreement number is how forgiving to be."))
	descriptors.append(F.make_descriptor("Core", "IsLongerThan", "Is Longer Than", ACEDescriptor.ACEType.CONDITION, "{vector}.length() > {length}", "", [F.make_param("vector", "String", "Vector2.ZERO", "Vector", "Vector to measure, e.g. velocity.", "expression"), F.make_param("length", "String", "0.0", "Length", "Length to beat.", "expression")], CAT_VECTORS, "{vector} is longer than {length}")
		.described("True when a vector's length beats a number - \"am I actually moving\", \"is this push hard enough\"."))
	descriptors.append(F.make_descriptor("Core", "ColorsAreEqual", "Colors Are Equal", ACEDescriptor.ACEType.CONDITION, "{a}.is_equal_approx({b})", "", [F.make_param("a", "String", "Color.WHITE", "First", "Left color.", "expression", [], PackedStringArray()), F.make_param("b", "String", "Color.WHITE", "Second", "Right color.", "expression")], CAT_VECTORS, "{a} equals {b}")
		.described("True when two colors match allowing for rounding - the same reason vectors need it, since colors are four decimal numbers."))


# ── Types ──
static func _add_types(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.make_descriptor("Core", "ValueIsOfType", "Value Is Of Type", ACEDescriptor.ACEType.CONDITION, "typeof({value}) == {type}", "", [F.make_param("value", "String", "0", "Value", "Value to test.", "expression"), F.make_param("type", "String", "TYPE_INT", "Type", "The type it should be.", "", _type_options())], CAT_TYPES, "{value} is {type}")
		.described("True when a value is of a particular kind - guarding code that is about to treat something as a number, a list, or text.").featured())
	descriptors.append(F.make_descriptor("Core", "ValuesSameType", "Values Are The Same Type", ACEDescriptor.ACEType.CONDITION, "typeof({a}) == typeof({b})", "", [F.make_param("a", "String", "0", "First", "Left value.", "expression"), F.make_param("b", "String", "0", "Second", "Right value.", "expression")], CAT_TYPES, "{a} and {b} are the same type")
		.described("True when two values are of the same kind, so comparing them means anything. Text and a number are never equal, however similar they look."))
	descriptors.append(F.make_descriptor("Core", "ValueTypeName", "Value Type Name", ACEDescriptor.ACEType.EXPRESSION, "type_string(typeof({value}))", "", [F.make_param("value", "String", "0", "Value", "Value to name.", "expression")], CAT_TYPES, "type of {value}")
		.described("The name of a value's type as readable text (\"int\", \"Vector2\", \"Dictionary\") - handy in a debug print when something is not what you expected."))
	descriptors.append(F.make_descriptor("Core", "ObjectIsClass", "Object Is Class", ACEDescriptor.ACEType.CONDITION, "({object} != null and {object}.is_class({class_name}))", "", [F.make_param("object", "String", "self", "Object", "Object to test.", "expression"), F.make_param("class_name", "String", "\"CharacterBody2D\"", "Class", "Engine class name, e.g. \"CharacterBody2D\".", "expression")], CAT_TYPES, "{object} is a {class_name}")
		.described("True when an object is of an engine class, or something derived from it - so a CharacterBody2D also counts as a Node2D. Checks for nothing-there first, so it is safe on an empty reference."))


# ── Objects ──
static func _add_objects(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.make_descriptor("Core", "IsSameObject", "Is The Same Object", ACEDescriptor.ACEType.CONDITION, "{a} == {b}", "", [F.make_param("a", "String", "self", "First", "Left object.", "expression"), F.make_param("b", "String", "self", "Second", "Right object.", "expression")], CAT_OBJECTS, "{a} is the same object as {b}")
		.described("True when two references point at the very same object, not merely one that looks alike - \"did I just hit MYSELF\", \"is this the node I already picked\"."))
	descriptors.append(F.make_descriptor("Core", "IsValidInstance", "Object Still Exists", ACEDescriptor.ACEType.CONDITION, "is_instance_valid({object})", "", [F.make_param("object", "String", "self", "Object", "Object to test.", "expression")], CAT_OBJECTS, "{object} still exists")
		.described("True when an object has not been freed. A variable holding a deleted node is NOT null - it is a dangling reference, and touching it crashes. This is the check that catches it.").featured())
	descriptors.append(F.make_descriptor("Core", "ObjectHasMethod", "Object Has Method", ACEDescriptor.ACEType.CONDITION, "({object} != null and {object}.has_method({method}))", "", [F.make_param("object", "String", "self", "Object", "Object to test.", "expression"), F.make_param("method", "String", "\"take_damage\"", "Method", "Method name to look for.", "expression")], CAT_OBJECTS, "{object} has method {method}")
		.described("True when an object can do something - the duck-typing check that lets one hit apply to anything with take_damage, without caring what class it is."))
	descriptors.append(F.make_descriptor("Core", "ObjectHasProperty", "Object Has Property", ACEDescriptor.ACEType.CONDITION, "({object} != null and {property} in {object})", "", [F.make_param("object", "String", "self", "Object", "Object to test.", "expression"), F.make_param("property", "String", "\"health\"", "Property", "Property name to look for.", "expression")], CAT_OBJECTS, "{object} has property {property}")
		.described("True when an object carries a named property, so a sheet can read it without risking an error on something that has no such field."))


static func _type_options() -> Array:
	var options: Array = []
	for entry: Dictionary in VALUE_TYPES:
		options.append({"key": str(entry["key"]), "label": str(entry["label"])})
	return options
