# EventForge - ONE READING OF AN ANNOTATION SPEC LINE, for everything that writes or reads one.
#
# A pack's `## @ace_param(<id>, key: value, ...)` line is read TWICE by different code: the importer's
# lifter reads it when the file is opened as a sheet, and the provider scanner (the semantic analyzer)
# reads it when the pack publishes its vocabulary. The compiler WRITES it, from what the lifter read.
#
# Three readings of one grammar is three chances to disagree, and a disagreement here is invisible in
# both directions. The pack publishes the vocabulary the scanner read; the sheet opens on the one the
# lifter read; and because the byte gate only asks whether the COMPILER reproduces the file - and the
# compiler writes back what the LIFTER holds - a line the scanner alone reads wrongly re-emits byte for
# byte and ships the wrong starting value to the picker with every gate green.
#
# That is exactly what a `default_code:` holding a single-quoted string did. `default_code: 'a, b'`
# opened as `'a, b'` and published as `'a`, because one of the two splitters toggled on `"` alone;
# `default_code: "\""` published nothing at all and swallowed the help text beside it. So the split is
# ONE function, in one file, and the three callers hold no copy of it.
#
# THE GRAMMAR, in one paragraph. A separator (`,` between the keys of a spec, `|` between the entries
# of an `options:` list) divides the text only when it is outside every quoted string and outside every
# bracketed value. A quote is `"` or `'`, opened by the first one seen and closed by its own kind, and
# a backslash inside a string escapes whatever follows it - so `'a, b'`, `"it's fine, really"` and
# `"\""` are each one value and not two. Brackets are `{[(` / `}])`, so `default: {"verb": "shake",
# "amount": 0.4}` is one segment rather than three. A text whose brackets do NOT balance is split the
# older, bracket-blind way, so a malformed line - prose with a stray `(`, a truncated annotation -
# reads exactly as it read before groups were understood at all, rather than swallowing the rest of
# the line into one runaway segment.
#
# Named by `const` and `preload`, never by class name: the lifter, the compiler and the analyzer all
# reach this on paths a boot may take, and a leaf of statics loaded by path costs nothing to name.
@tool
extends RefCounted

## The brackets a value may be WRITTEN with - a Dictionary or Array literal, a constructor call. A
## separator between them belongs to that literal, not to the line around it.
const VALUE_OPENERS: String = "{[("
const VALUE_CLOSERS: String = "}])"


## True when every bracket outside a quoted string in `text` is closed by its own kind, in order.
## Asked BEFORE the split so a malformed line reads exactly the way it read before groups were
## understood at all, rather than swallowing the rest of the line into one runaway segment.
static func brackets_balance(text: String) -> bool:
	var open_kinds: Array[String] = []
	var quote: String = ""
	var index: int = 0
	while index < text.length():
		var here: String = text[index]
		if not quote.is_empty():
			# A backslash escapes the next character, so a quote behind one does not close the string.
			if here == "\\" and index + 1 < text.length():
				index += 2
				continue
			if here == quote:
				quote = ""
			index += 1
			continue
		if here == "\"" or here == "'":
			quote = here
		elif VALUE_OPENERS.contains(here):
			open_kinds.append(VALUE_CLOSERS[VALUE_OPENERS.find(here)])
		elif VALUE_CLOSERS.contains(here):
			if open_kinds.is_empty() or open_kinds[open_kinds.size() - 1] != here:
				return false
			open_kinds.remove_at(open_kinds.size() - 1)
		index += 1
	return quote.is_empty() and open_kinds.is_empty()


## One text split on a separator that is OUTSIDE any quoted string AND outside any bracketed value.
## A separator inside a string literal, or between the braces of a Dictionary default, is a character
## of that value and nothing else: `default: {"verb": "shake", "amount": 0.4}` is ONE segment, not
## three, and a default cut at its first comma is a line the byte gate then refuses, which degrades
## the whole verb to a verbatim block.
##
## The segments keep their own leading and trailing spaces - a caller that wants a value strips it -
## because the emitter writes `, ` between keys and a reader that trimmed here could not tell a line
## it must reproduce from one it may reformat.
static func split_outside_quotes(text: String, separator: String) -> PackedStringArray:
	var respect_groups: bool = brackets_balance(text)
	var parts: PackedStringArray = PackedStringArray()
	var held: String = ""
	var quote: String = ""
	var depth: int = 0
	var index: int = 0
	while index < text.length():
		var here: String = text[index]
		if not quote.is_empty():
			held += here
			if here == "\\" and index + 1 < text.length():
				held += text[index + 1]
				index += 2
				continue
			if here == quote:
				quote = ""
			index += 1
			continue
		if here == "\"" or here == "'":
			quote = here
			held += here
			index += 1
			continue
		if respect_groups and VALUE_OPENERS.contains(here):
			depth += 1
			held += here
			index += 1
			continue
		if respect_groups and VALUE_CLOSERS.contains(here) and depth > 0:
			depth -= 1
			held += here
			index += 1
			continue
		if depth == 0 and text.substr(index, separator.length()) == separator:
			parts.append(held)
			held = ""
			index += separator.length()
			continue
		held += here
		index += 1
	parts.append(held)
	return parts


## One surrounding pair of double quotes off a value, and no more.
##
## This is what makes a WORD a word: the quotes an emitted value wears are the escape that lets it
## hold a separator, wear quotes of its own, or be empty at all - never characters of the word. Both
## readers do exactly this and nothing more, so the vocabulary a pack PUBLISHES and the sheet an
## author OPENS can never disagree about a starting value.
static func unquoted_once(value: String) -> String:
	if value.length() >= 2 and value.begins_with("\"") and value.ends_with("\""):
		return value.substr(1, value.length() - 2)
	return value
