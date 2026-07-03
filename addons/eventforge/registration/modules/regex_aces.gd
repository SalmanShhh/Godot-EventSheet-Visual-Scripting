# EventForge module — RegEx text matching (Construct 3's Regex* functions, Godot-native).
#
# Pattern matching, search, replace, and capture-group extraction via Godot's RegEx — the catalogue's
# plain string verbs (Find / Replace / Token At / Split…) live in system_aces/collection_aces; this
# module adds the PATTERN-based ones C3 exposes as RegexReplace / RegexSearch / RegexMatchCount.
#
# Each compiles to a direct one-liner using RegEx.create_from_string({pattern}) (compiles the pattern
# inline) — parity-clean, no editor plugin and no pre-built RegEx object needed. The search_all-based
# verbs are NULL-SAFE: search_all returns [] on no match, so First Match / Capture Group fall back to
# "" instead of crashing on a miss (unlike a bare .search(...).get_string()).
@tool
class_name EventForgeRegexACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")


static func _pattern_param() -> ACEParam:
	return F.make_param("pattern", "String", "\"[0-9]+\"", "Pattern", "The regular expression to match, in Godot RegEx syntax.", "expression")


static func _text_param() -> ACEParam:
	return F.make_param("text", "String", "\"score: 42\"", "Text", "The text to search.", "expression")


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	descriptors.append(F.make_descriptor("Core", "RegexMatches", "Text Matches Regex", ACEDescriptor.ACEType.CONDITION,
		"RegEx.create_from_string({pattern}).search({text}) != null", "",
		[_pattern_param(), _text_param()], "Text: RegEx", "{text} matches {pattern}")
		.described("True when the text matches the regular expression anywhere (e.g. \"^[0-9]+$\" tests for digits only)."))

	descriptors.append(F.make_descriptor("Core", "RegexReplace", "Regex Replace", ACEDescriptor.ACEType.EXPRESSION,
		"RegEx.create_from_string({pattern}).sub({text}, {replacement}, true)", "",
		[_pattern_param(), _text_param(), F.make_param("replacement", "String", "\"#\"", "Replacement", "Text to substitute for each match ($1, $2… reuse capture groups).", "expression")], "Text: RegEx", "replace {pattern} in {text}")
		.described("Returns the text with EVERY match of the pattern replaced. Use $1/$2 in the replacement to reuse capture groups."))

	descriptors.append(F.make_descriptor("Core", "RegexFirstMatch", "Regex First Match", ACEDescriptor.ACEType.EXPRESSION,
		"(RegEx.create_from_string({pattern}).search_all({text}).map(func(__m): return __m.get_string()) + [\"\"]).front()", "",
		[_pattern_param(), _text_param()], "Text: RegEx", "first {pattern} in {text}")
		.described("Returns the first substring that matches the pattern, or an empty string when there's no match (never errors)."))

	descriptors.append(F.make_descriptor("Core", "RegexMatchCount", "Regex Match Count", ACEDescriptor.ACEType.EXPRESSION,
		"RegEx.create_from_string({pattern}).search_all({text}).size()", "",
		[_pattern_param(), _text_param()], "Text: RegEx", "count {pattern} in {text}")
		.described("Returns how many times the pattern matches in the text (0 if none)."))

	descriptors.append(F.make_descriptor("Core", "RegexAllMatches", "Regex All Matches", ACEDescriptor.ACEType.EXPRESSION,
		"RegEx.create_from_string({pattern}).search_all({text}).map(func(__m): return __m.get_string())", "",
		[_pattern_param(), _text_param()], "Text: RegEx", "all {pattern} in {text}")
		.described("Returns an array of every substring that matches the pattern (an empty array if none)."))

	descriptors.append(F.make_descriptor("Core", "RegexCaptureGroup", "Regex Capture Group", ACEDescriptor.ACEType.EXPRESSION,
		"(RegEx.create_from_string({pattern}).search_all({text}).map(func(__m): return __m.get_string({group})) + [\"\"]).front()", "",
		[_pattern_param(), _text_param(), F.make_param("group", "String", "1", "Group", "Which ( ) capture group to return (1 = the first parentheses).", "expression")], "Text: RegEx", "group {group} of {pattern} in {text}")
		.described("Returns capture group N from the first match — the text inside the Nth pair of parentheses — or empty if none."))

	# Godot format strings (the linked doc): a number to a fixed number of decimal places — the common
	# score/money/percentage display. The plain text verbs (upper/lower/split/pad-zeros/Format String)
	# already exist elsewhere; this fills the decimal-places gap.
	descriptors.append(F.make_descriptor("Core", "FormatDecimals", "Format Decimals", ACEDescriptor.ACEType.EXPRESSION,
		"String.num({value}, {decimals})", "",
		[F.make_param("value", "String", "3.14159", "Value", "Number to format.", "expression"), F.make_param("decimals", "String", "2", "Decimals", "Digits after the decimal point.", "expression")], "Text", "format {value} to {decimals} dp")
		.described("Returns a number as text with a fixed number of decimal places, e.g. 3.14159 → \"3.14\"."))

	return descriptors
