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
## The checked text-to-number pair is authored here, next to the condition that guards it, but it
## SHIPS in "Variables: String" - beside Text To Int and Text To Float, the silent-zero conversions
## it exists to replace. A picker section is where an author goes looking, not where a file lives.
const CAT_STRING := "Variables: String"

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
	_add_text_to_number(descriptors)
	_add_numbers(descriptors)
	_add_vectors(descriptors)
	_add_types(descriptors)
	_add_objects(descriptors)
	return descriptors


# ── Text ──
static func _add_text(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.cond("TextEqualsIgnoreCase", "Text Equals (ignore case)", "{a}.to_lower() == {b}.to_lower()", CAT_TEXT, "{a} equals {b} (ignoring case)", "True when two pieces of text are the same, treating capitals and lowercase as identical - what you want for a typed-in name or a cheat code.").param("a", "\"\"", "First", "Left text.", "expression").param("b", "\"\"", "Second", "Right text.", "expression").featured())
	descriptors.append(F.cond("TextBeginsWith", "Text Begins With", "{text}.begins_with({prefix})", CAT_TEXT, "{text} begins with {prefix}", "True when text starts with something - filtering commands, ids with a prefix, or file paths.").param("text", "\"\"", "Text", "Text to test.", "expression").param("prefix", "\"\"", "Prefix", "What it should start with.", "expression"))
	descriptors.append(F.cond("TextIsEmpty", "Text Is Empty", "{text}.is_empty()", CAT_TEXT, "{text} is empty", "True when text has no characters at all. Note that a single space is NOT empty.").param("text", "\"\"", "Text", "Text to test.", "expression"))
	descriptors.append(F.cond("TextIsBlank", "Text Is Blank", "{text}.strip_edges().is_empty()", CAT_TEXT, "{text} is blank", "True when text is empty OR only spaces - the check a name-entry box actually wants, since \"   \" should not count as a name.").param("text", "\"\"", "Text", "Text to test.", "expression"))
	descriptors.append(F.cond("TextMatchesPattern", "Text Matches Pattern", "{text}.match({pattern})", CAT_TEXT, "{text} matches {pattern}", "True when text fits a wildcard pattern, where * stands for any run of characters and ? for one - simpler than a regular expression for things like \"level_*\".").param("text", "\"\"", "Text", "Text to test.", "expression").param("pattern", "\"*\"", "Pattern", "Wildcard pattern: * is any run of characters, ? is any single one.", "expression"))
	descriptors.append(F.cond("TextIsOneOf", "Text Is One Of", "{text} in {options}", CAT_TEXT, "{text} is one of {options}", "True when text is one of a list of accepted values - one row instead of a chain of \"or equals\" conditions.").param("text", "\"\"", "Text", "Text to test.", "expression").param("options", "[\"a\", \"b\"]", "Options", "List of accepted values.", "expression"))
	descriptors.append(F.cond("TextSortsBefore", "Text Sorts Before", "{a}.casecmp_to({b}) < 0", CAT_TEXT, "{a} sorts before {b}", "True when the first text comes before the second alphabetically, ignoring case - for ordering names or building a sorted list.").param("a", "\"\"", "First", "Left text.", "expression").param("b", "\"\"", "Second", "Right text.", "expression"))
	descriptors.append(F.expr("TextNaturalOrder", "Text Natural Order", "{a}.naturalnocasecmp_to({b})", CAT_TEXT, "natural order of {a} vs {b}", "Compares two pieces of text the way a person would read numbers in them, so \"item2\" comes before \"item10\". Negative if the first sorts earlier, 0 if equal, positive if later.").param("a", "\"\"", "First", "Left text.", "expression").param("b", "\"\"", "Second", "Right text.", "expression"))
	# Ask-before-you-convert. Every silent-zero bug starts with text becoming a number without anyone
	# checking first, so the question gets its own row and the conversion gets a fallback (below).
	# str() wraps the value because the text a sheet tests is rarely typed as text: it arrives out of a
	# save slot, a JSON field or a table cell as a Variant, and `.strip_edges()` on a raw int crashes.
	descriptors.append(F.cond("TextIsANumber", "Text Is A Number", "str({text}).strip_edges().is_valid_float()", CAT_TEXT, "{text} is a number", "True when this text would convert to a number cleanly. Ask it BEFORE converting, so a typo can never arrive as a silent 0 and the sheet bet nothing. Spaces around the number are ignored; empty text is not a number.").param("text", "\"12\"", "Text", "Text to test - a typed-in field, a value read back out of a save, a CSV or JSON cell.", "expression").featured())
	descriptors.append(F.cond("TextIsAWholeNumber", "Text Is A Whole Number", "str({text}).strip_edges().is_valid_int()", CAT_TEXT, "{text} is a whole number", "True when this text would convert to a WHOLE number cleanly - a count, a level, a slot index. \"12\" passes and \"12.5\" does not, which is the only difference from Text Is A Number.").param("text", "\"12\"", "Text", "Text to test - a count, a level number, a save slot, a seed.", "expression"))
	# One row instead of an Or block of Text Contains. Array(…) around the list is load-bearing: Split
	# Text hands back a PackedStringArray, which has no any()/all(), so a bare {options}.any(…) would
	# crash on the single most natural input.
	descriptors.append(F.cond("ContainsAnyOf", "Contains Any Of", "Array({options}).any(func(__needle): return {text}.contains(__needle))", CAT_TEXT, "{text} contains any of {options}", "True when the text contains at least ONE of the listed pieces - a chat filter, a keyword-triggered line, a tag-gated card. Unlike Text Is One Of, which needs the WHOLE text to equal an entry, this looks INSIDE the text. Matching is case-sensitive, and an empty list is never a match.").param("text", "\"\"", "Text", "Text to search.", "expression").param("options", "[\"fire\", \"ice\"]", "Any Of", "List of pieces to look for - written here, or a sheet variable someone can edit without touching this row.", "expression").featured())
	descriptors.append(F.cond("ContainsAllOf", "Contains All Of", "Array({options}).all(func(__needle): return {text}.contains(__needle))", CAT_TEXT, "{text} contains all of {options}", "True only when the text contains EVERY listed piece - a combo whose rule text names two keywords, a search box where all the words must match. An empty list counts as true, because nothing is missing.").param("text", "\"\"", "Text", "Text to search.", "expression").param("options", "[\"fire\", \"ice\"]", "All Of", "List of pieces that must ALL appear.", "expression"))
	descriptors.append(F.cond("ContainsNoneOf", "Contains None Of", "(not Array({options}).any(func(__needle): return {text}.contains(__needle)))", CAT_TEXT, "{text} contains none of {options}", "True when the text contains none of the listed pieces - the accept-this-name branch, written as the thing you want to act on instead of an Else. An empty list always passes.").param("text", "\"\"", "Text", "Text to search.", "expression").param("options", "[\"fire\", \"ice\"]", "None Of", "List of pieces that must NOT appear.", "expression"))


# ── Text to numbers, checked ──
# The pair that reports failure. Text To Int and Text To Float both answer 0 for "abc", for "" and for
# "0" alike, so a typo in an amount box arrives as a real-looking bet of nothing. These read the number
# only when the text really holds one, and otherwise hand back a fallback the AUTHOR chose - which is
# also what makes the failure visible, because a chosen fallback can be a value that means "no".
static func _add_text_to_number(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.expr("NumberFromText", "Number From Text", "(str({text}).strip_edges().to_float() if str({text}).strip_edges().is_valid_float() else {fallback})", CAT_STRING, "number from {text} (or {fallback})", "Reads a number out of text, or hands back the fallback YOU chose - never a surprise zero. Pair it with Text Is A Number when the two cases need different rows. The text is read twice in the emitted line, so keep it a plain read and not something that changes the game.").param("text", "\"12\"", "Text", "Text to read a number out of.", "expression").param("fallback", "0.0", "Or", "What you get back when the text is not a number.", "expression").featured())
	descriptors.append(F.expr("WholeNumberFromText", "Whole Number From Text", "(str({text}).strip_edges().to_int() if str({text}).strip_edges().is_valid_int() else {fallback})", CAT_STRING, "whole number from {text} (or {fallback})", "Reads a whole number out of text, or hands back your fallback. \"12.5\" is not a whole number, so it lands on the fallback rather than quietly becoming 12 - when you want that rounding, use Number From Text and round the result yourself.").param("text", "\"12\"", "Text", "Text to read a whole number out of.", "expression").param("fallback", "0", "Or", "What you get back when the text is not a whole number.", "expression"))


# ── Numbers ──
static func _add_numbers(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.cond("ValuesAreNear", "Values Are Near", "absf({a} - {b}) <= {tolerance}", CAT_NUMBERS, "{a} is within {tolerance} of {b}", "True when two numbers are close enough to count as the same. Decimal numbers almost never land exactly equal after any arithmetic, so this is the comparison you usually want instead of ==.").param("a", "0.0", "First", "Left value.", "expression").param("b", "0.0", "Second", "Right value.", "expression").param("tolerance", "0.01", "Tolerance", "How far apart they may be and still count as equal.", "expression").featured())
	descriptors.append(F.cond("IsOutsideRange", "Is Outside Range", "({value} < {min} or {value} > {max})", CAT_NUMBERS, "{value} is outside {min}..{max}", "True when a value falls below the low bound or above the high one - the mirror of Is Between Values, for culling things that wandered off.").param("value", "0", "Value", "Value to test.", "expression").param("min", "0", "Min", "Lower bound (inclusive).", "expression").param("max", "10", "Max", "Upper bound (inclusive).", "expression"))
	descriptors.append(F.cond("IsPositive", "Is Positive", "{value} > 0", CAT_NUMBERS, "{value} is positive", "True when a number is greater than zero. Zero itself is neither positive nor negative.").param("value", "0", "Value", "Value to test.", "expression"))
	descriptors.append(F.cond("IsNegative", "Is Negative", "{value} < 0", CAT_NUMBERS, "{value} is negative", "True when a number is less than zero - a spent balance, a reversed direction, a debt.").param("value", "0", "Value", "Value to test.", "expression"))
	descriptors.append(F.cond("IsEven", "Is Even", "int({value}) % 2 == 0", CAT_NUMBERS, "{value} is even", "True for even whole numbers - alternating rows, checkerboards, every-other-turn rules.").param("value", "0", "Value", "Whole number to test.", "expression"))
	descriptors.append(F.cond("IsOdd", "Is Odd", "int({value}) % 2 != 0", CAT_NUMBERS, "{value} is odd", "True for odd whole numbers - the other half of an alternating pattern.").param("value", "0", "Value", "Whole number to test.", "expression"))
	descriptors.append(F.cond("IsMultipleOf", "Is Multiple Of", "(int({divisor}) != 0 and int({value}) % int({divisor}) == 0)", CAT_NUMBERS, "{value} is a multiple of {divisor}", "True every Nth number - a milestone at every 10 kills, a wave every 5 rounds. Guards against a divisor of zero, which would otherwise crash.").param("value", "0", "Value", "Whole number to test.", "expression").param("divisor", "5", "Multiple Of", "The step size, e.g. 5 for every fifth.", "expression"))
	descriptors.append(F.cond("IsWholeNumber", "Is A Whole Number", "is_equal_approx({value}, floor({value}))", CAT_NUMBERS, "{value} is a whole number", "True when a decimal number has nothing after the point - useful for snapping checks and grid alignment.").param("value", "0.0", "Value", "Value to test.", "expression"))
	descriptors.append(F.expr("CompareResult", "Compare Result", "signi(int(sign({a} - {b})))", CAT_NUMBERS, "compare {a} to {b}", "Gives -1, 0 or 1 for \"less than, equal to, greater than\" in one value - the shape a sort comparison wants, instead of branching twice.").param("a", "0", "First", "Left value.", "expression").param("b", "0", "Second", "Right value.", "expression"))


# ── Vectors ──
static func _add_vectors(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.cond("VectorsAreEqual", "Vectors Are Equal", "{a}.is_equal_approx({b})", CAT_VECTORS, "{a} equals {b}", "True when two vectors are the same allowing for rounding. Comparing positions with == almost never works, because any arithmetic leaves a tiny remainder.").param("a", "Vector2.ZERO", "First", "Left vector.", "expression").param("b", "Vector2.ZERO", "Second", "Right vector.", "expression").featured())
	descriptors.append(F.cond("IsWithinDistance", "Is Within Distance", "{a}.distance_to({b}) <= {distance}", CAT_VECTORS, "{a} is within {distance} of {b}", "True when two points are no further apart than a distance - proximity, aggro range, \"close enough to interact\".").param("a", "Vector2.ZERO", "From", "First point, e.g. global_position.", "expression").param("b", "Vector2.ZERO", "To", "Second point.", "expression").param("distance", "100.0", "Distance", "How close counts.", "expression").featured())
	descriptors.append(F.cond("IsFartherThan", "Is Farther Than", "{a}.distance_to({b}) > {distance}", CAT_VECTORS, "{a} is farther than {distance} from {b}", "True when two points are further apart than a distance - despawning strays, dropping a chase, culling what nobody can see.").param("a", "Vector2.ZERO", "From", "First point, e.g. global_position.", "expression").param("b", "Vector2.ZERO", "To", "Second point.", "expression").param("distance", "600.0", "Distance", "How far is too far.", "expression"))
	descriptors.append(F.cond("PointsSameDirection", "Points The Same Way", "{a}.normalized().dot({b}.normalized()) >= {threshold}", CAT_VECTORS, "{a} points the same way as {b}", "True when two directions broadly agree - is the enemy facing me, am I moving the way I am aiming, is this surface a floor. The Agreement number is how forgiving to be.").param("a", "Vector2.RIGHT", "First", "First direction.", "expression").param("b", "Vector2.RIGHT", "Second", "Second direction.", "expression").param("threshold", "0.7", "Agreement", "1.0 is identical, 0.0 is a right angle, -1.0 is opposite. 0.7 is roughly within 45 degrees.", "expression"))
	descriptors.append(F.cond("IsLongerThan", "Is Longer Than", "{vector}.length() > {length}", CAT_VECTORS, "{vector} is longer than {length}", "True when a vector's length beats a number - \"am I actually moving\", \"is this push hard enough\".").param("vector", "Vector2.ZERO", "Vector", "Vector to measure, e.g. velocity.", "expression").param("length", "0.0", "Length", "Length to beat.", "expression"))
	descriptors.append(F.cond("ColorsAreEqual", "Colors Are Equal", "{a}.is_equal_approx({b})", CAT_VECTORS, "{a} equals {b}", "True when two colors match allowing for rounding - the same reason vectors need it, since colors are four decimal numbers.").param_suggesting("a", "Color.WHITE", "First", "Left color.", PackedStringArray(), "expression").param("b", "Color.WHITE", "Second", "Right color.", "expression"))


# ── Types ──
static func _add_types(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.cond("ValueIsOfType", "Value Is Of Type", "typeof({value}) == {type}", CAT_TYPES, "{value} is {type}", "True when a value is of a particular kind - guarding code that is about to treat something as a number, a list, or text.").param("value", "0", "Value", "Value to test.", "expression").param_choice("type", "TYPE_INT", "Type", "The type it should be.", _type_options()).featured())
	descriptors.append(F.cond("ValuesSameType", "Values Are The Same Type", "typeof({a}) == typeof({b})", CAT_TYPES, "{a} and {b} are the same type", "True when two values are of the same kind, so comparing them means anything. Text and a number are never equal, however similar they look.").param("a", "0", "First", "Left value.", "expression").param("b", "0", "Second", "Right value.", "expression"))
	descriptors.append(F.expr("ValueTypeName", "Value Type Name", "type_string(typeof({value}))", CAT_TYPES, "type of {value}", "The name of a value's type as readable text (\"int\", \"Vector2\", \"Dictionary\") - handy in a debug print when something is not what you expected.").param("value", "0", "Value", "Value to name.", "expression"))
	descriptors.append(F.cond("ObjectIsClass", "Object Is Class", "({object} != null and {object}.is_class({class_name}))", CAT_TYPES, "{object} is a {class_name}", "True when an object is of an engine class, or something derived from it - so a CharacterBody2D also counts as a Node2D. Checks for nothing-there first, so it is safe on an empty reference.").param("object", "self", "Object", "Object to test.", "expression").param("class_name", "\"CharacterBody2D\"", "Class", "Engine class name, e.g. \"CharacterBody2D\".", "expression"))
	# One question - "is there anything there" - that used to need four rows and prior knowledge of the
	# value's type (Text Is Empty, Array Is Empty, Dictionary Is Empty, Is Null).
	#
	# Nothing is spelled as the four empty values a sheet actually meets: no value at all, empty text,
	# an empty list, an empty record. NOT 0 and NOT false, deliberately - a score of zero and a switch
	# that is off are real values, and a guard that swallowed them would be a bug factory.
	#
	# The `in` form is load-bearing, not a style choice: the obvious `{value} is Array and
	# {value}.is_empty()` chain is a PARSE ERROR the moment the value is statically typed
	# ("Expression is of type String so it can't be of type Array"), and so is a cross-type `==`.
	# `in` against an untyped list compiles for every operand type and compares by value.
	#
	# The packed arrays need their own clause, and they are not optional: an empty PackedStringArray
	# does NOT equal an empty Array, and Split Text - the most common way a sheet ever makes a list -
	# returns exactly that, so without this an empty split read as "there is something". They are
	# caught by RANGE rather than by naming nine constants: TYPE_PACKED_BYTE_ARRAY is the first of
	# the packed families and TYPE_MAX sits past the last. `not {value}` is the emptiness test there
	# (Godot booleanizes an empty packed array to false) and, unlike `.is_empty()`, it compiles
	# against an operand of any static type - the same reason `in` was chosen above.
	descriptors.append(F.cond("IsNothing", "Is Nothing", "({value} in [null, \"\", [], {}] or (typeof({value}) >= TYPE_PACKED_BYTE_ARRAY and not {value}))", CAT_TYPES, "{value} is nothing", "True when there is nothing there: no value at all, empty text, an empty list (including an empty Split Text result), or an empty record - one row whatever the value turns out to be. A 0 is NOT nothing, because a score of zero is a real value, and neither is text made only of spaces (that is Text Is Blank).").param("value", "\"\"", "Value", "Anything - text, a list, a record, a reference.", "expression").featured())
	descriptors.append(F.cond("HasSomething", "Has Something", "(not ({value} in [null, \"\", [], {}] or (typeof({value}) >= TYPE_PACKED_BYTE_ARRAY and not {value})))", CAT_TYPES, "{value} has something", "True when there IS something there - a name was typed, the inventory has items, the save slot was written, the item slot is filled. The exact opposite of Is Nothing, for the times the filled case is the one you want to act on.").param("value", "\"\"", "Value", "Anything - text, a list, a record, a reference.", "expression"))


# ── Objects ──
static func _add_objects(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.cond("IsSameObject", "Is The Same Object", "{a} == {b}", CAT_OBJECTS, "{a} is the same object as {b}", "True when two references point at the very same object, not merely one that looks alike - \"did I just hit MYSELF\", \"is this the node I already picked\".").param("a", "self", "First", "Left object.", "expression").param("b", "self", "Second", "Right object.", "expression"))
	descriptors.append(F.cond("IsValidInstance", "Object Still Exists", "is_instance_valid({object})", CAT_OBJECTS, "{object} still exists", "True when an object has not been freed. A variable holding a deleted node is NOT null - it is a dangling reference, and touching it crashes. This is the check that catches it.").param("object", "self", "Object", "Object to test.", "expression").featured())
	descriptors.append(F.cond("ObjectHasMethod", "Object Has Method", "({object} != null and {object}.has_method({method}))", CAT_OBJECTS, "{object} has method {method}", "True when an object can do something - the duck-typing check that lets one hit apply to anything with take_damage, without caring what class it is.").param("object", "self", "Object", "Object to test.", "expression").param("method", "\"take_damage\"", "Method", "Method name to look for.", "expression"))
	descriptors.append(F.cond("ObjectHasProperty", "Object Has Property", "({object} != null and {property} in {object})", CAT_OBJECTS, "{object} has property {property}", "True when an object carries a named property, so a sheet can read it without risking an error on something that has no such field.").param("object", "self", "Object", "Object to test.", "expression").param("property", "\"health\"", "Property", "Property name to look for.", "expression"))


static func _type_options() -> Array:
	var options: Array = []
	for entry: Dictionary in VALUE_TYPES:
		options.append({"key": str(entry["key"]), "label": str(entry["label"])})
	return options
