@tool
class_name EventSheetViewportLenses
extends RefCounted

# Reading lenses: pure display transforms over row text that NEVER touch the row model, the
# sheet resource or the emitted GDScript. Every function here takes a string (or a small
# descriptor) and returns a string; the row builder decides where to apply them and always
# keeps the raw form on the span's hover tooltip, so the exact code is one hover away.
#
# The lenses, and the reading each produces:
#   humanize_identifier   "_coyote_timer" -> "coyote timer";  an @export knob -> "Coyote Time"
#                         (Godot's own Inspector capitalisation, so the sheet mirrors what the
#                         Inspector shows for the same property)
#   possessive_chain      "host.velocity.x" -> "host's velocity X"
#   strip_leading_not     "not on floor"   -> "on floor"  (the NOT becomes the red mark the
#                         condition badge column already draws for an inverted condition)
#
# Everything is static and side-effect free: the builder calls these per span while spans are
# being built, and a view toggle decides whether they run at all.


## Axis suffixes shown as a capital letter rather than a word: Construct writes Player.X, and
## "velocity x" reads as a typo where "velocity X" reads as the axis it is.
const AXIS_COMPONENTS: PackedStringArray = ["x", "y", "z", "w"]


## True when `text` is a bare GDScript identifier (letters, digits, underscore; never starting
## with a digit). The lenses only ever rewrite tokens that pass this - anything else is left
## exactly as authored, because a lens that guesses at arbitrary text produces a fake sentence.
static func is_identifier(text: String) -> bool:
	if text.is_empty():
		return false
	for index: int in range(text.length()):
		var character: String = text[index]
		var is_word_character: bool = (
			character == "_"
			or (character >= "a" and character <= "z")
			or (character >= "A" and character <= "Z")
			or (character >= "0" and character <= "9")
		)
		if not is_word_character:
			return false
	return not (text[0] >= "0" and text[0] <= "9")


## M9. A variable/parameter identifier as a human would say it.
## `export_knob` shows the name with Godot's Inspector capitalisation, so a knob reads on the
## sheet exactly as it reads in the Inspector ("coyote_time" -> "Coyote Time"); everything else
## reads as lowercase words ("_coyote_timer" -> "coyote timer"). A leading underscore is a
## GDScript privacy convention, not part of the name, so it is dropped either way.
## Anything that is not a plain identifier comes back untouched.
static func humanize_identifier(raw_name: String, export_knob: bool = false) -> String:
	if not is_identifier(raw_name):
		return raw_name
	var trimmed: String = raw_name
	while trimmed.begins_with("_"):
		trimmed = trimmed.substr(1)
	if trimmed.is_empty():
		return raw_name
	if export_knob:
		# String.capitalize() IS the transform Godot's Inspector applies to a property name, so
		# borrowing it keeps the two surfaces from drifting as Godot tunes its own rules.
		return trimmed.capitalize()
	var words: PackedStringArray = trimmed.capitalize().split(" ", false)
	for index: int in range(words.size()):
		words[index] = words[index].to_lower()
	return " ".join(words)


## An axis component drawn as its capital letter, or "" when the part is not an axis.
static func axis_letter(part: String) -> String:
	var lowered: String = part.to_lower()
	if AXIS_COMPONENTS.has(lowered):
		return lowered.to_upper()
	return ""


## M10. A simple property chain read possessively, the way Construct writes Player.X.
##   host.velocity.x  -> host's velocity X
##   event.relative.x -> event's relative X
##   direction.x      -> direction X        (two parts ending in an axis: the axis is a
##                                           component OF direction, not a possession)
##   host.wall_normal -> host's wall normal
## Only simple identifier chains qualify. Anything holding a call, an index, an operator or a
## literal is returned verbatim: a half-translated expression reads worse than the code.
## `humanize` runs each non-axis part through humanize_identifier (so the lens composes with M9);
## pass false to keep the raw component names.
static func possessive_chain(raw_chain: String, humanize: bool = true) -> String:
	var text: String = raw_chain.strip_edges()
	if text.is_empty() or text.contains("("):
		return raw_chain
	var parts: PackedStringArray = text.split(".", false)
	if parts.size() < 2:
		return raw_chain
	for part: String in parts:
		if not is_identifier(part):
			return raw_chain
	var rendered: PackedStringArray = PackedStringArray()
	for index: int in range(parts.size()):
		var axis: String = axis_letter(parts[index]) if index > 0 else ""
		if not axis.is_empty():
			rendered.append(axis)
		elif humanize:
			rendered.append(humanize_identifier(parts[index]))
		else:
			rendered.append(parts[index])
	# The head owns the chain, so it takes the possessive - except when the chain is just a
	# value and its axis ("direction X"), where nothing is being possessed.
	var head_possesses: bool = parts.size() > 2 or axis_letter(parts[1]).is_empty()
	var head: String = rendered[0] + ("'s" if head_possesses else "")
	var tail: PackedStringArray = rendered.slice(1)
	return "%s %s" % [head, " ".join(tail)]


## Every simple identifier chain inside a value expression, read possessively (M10), with the
## rest of the expression left exactly as written. Used where a sentence shows a value: the
## chains become Construct's words and the operators around them stay code.
static func possessive_in_expression(expression: String, humanize: bool = true) -> String:
	if expression.is_empty() or expression.contains("("):
		return expression
	if not expression.contains("."):
		return expression
	var output: String = ""
	var token: String = ""
	for index: int in range(expression.length()):
		var character: String = expression[index]
		var is_token_character: bool = (
			character == "_"
			or character == "."
			or (character >= "a" and character <= "z")
			or (character >= "A" and character <= "Z")
			or (character >= "0" and character <= "9")
		)
		if is_token_character:
			token += character
		else:
			output += _rendered_token(token, humanize)
			token = ""
			output += character
	output += _rendered_token(token, humanize)
	return output


## One token from possessive_in_expression: a chain reads possessively, anything else (a bare
## name, a number, a float literal like 0.5) passes straight through.
static func _rendered_token(token: String, humanize: bool) -> String:
	if token.is_empty() or not token.contains("."):
		return token
	return possessive_chain(token, humanize)


## M12. The leading NOT of a condition sentence, removed so the red ✕ in the badge column can
## carry the inversion instead of the word. Returns the sentence unchanged when it does not
## start with a negation. `had_not` in the returned dictionary tells the caller whether to draw
## the mark: { "text": String, "negated": bool }.
static func strip_leading_not(sentence: String) -> Dictionary:
	var text: String = sentence.strip_edges()
	for prefix: String in ["not (", "not "]:
		if not text.begins_with(prefix):
			continue
		var remainder: String = text.substr(prefix.length()).strip_edges()
		if prefix == "not (":
			if not remainder.ends_with(")"):
				continue
			remainder = remainder.substr(0, remainder.length() - 1).strip_edges()
		if remainder.is_empty():
			continue
		return {"text": remainder, "negated": true}
	# "is not on floor" / "host is not empty": the negation sits mid-sentence, where the word
	# reads correctly and a badge would be ambiguous about WHICH clause it inverts.
	return {"text": sentence, "negated": false}


## M16. A function's snake_case name as its Construct display name ("add_look" -> "Add Look").
## A name the pack already published under an @ace_name keeps that name; the caller passes it
## as `published_name` and this is only the fallback.
static func function_display_name(function_name: String, published_name: String = "") -> String:
	if not published_name.strip_edges().is_empty():
		return published_name.strip_edges()
	return humanize_identifier(function_name, true)


## M16. One argument chip for a function call: "x = event's relative X" when the parameter name
## is known, otherwise the bare argument value. The value itself goes through the possessive
## lens so a chain argument reads the same as it would anywhere else.
static func call_argument_chip(parameter_name: String, argument_value: String, humanize: bool = true) -> String:
	var value: String = possessive_in_expression(argument_value.strip_edges(), humanize)
	if parameter_name.strip_edges().is_empty():
		return value
	return "%s = %s" % [parameter_name.strip_edges(), value]
