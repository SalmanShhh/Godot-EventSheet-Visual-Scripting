# EventForge - when a denial can be written without brackets.
#
# `not (x)` and `not x` mean the same thing, and the second is what a person writes by hand. A condition
# row placed today writes it whenever the text being denied is ONE plain operand - a name, a member
# access, a call or an index, joined only by dots - so that dropping the brackets cannot change which
# part the `not` applies to. Anything with an operator, a keyword or a space outside its brackets keeps
# the brackets it always had.
@tool
extends RefCounted

## Words that start an expression which is not one operand: `not` itself, the operators spelled as words,
## the ternary and the ones that take a whole expression after them.
const _KEYWORDS: PackedStringArray = [
	"not", "and", "or", "in", "is", "as", "if", "else", "await", "func", "var", "const", "match", "for",
	"while", "return", "pass", "break", "continue", "class", "extends", "signal", "enum", "static",
	"yield", "assert", "breakpoint",
]


## True when `text` is one plain operand that `not` can sit directly in front of.
static func is_plain(text: String) -> bool:
	var length: int = text.length()
	if length == 0 or text != text.strip_edges():
		return false
	var at: int = _identifier_end(text, 0)
	if at <= 0 or _KEYWORDS.has(text.substr(0, at)):
		return false
	while at < length:
		var mark: String = text[at]
		if mark == ".":
			var next_end: int = _identifier_end(text, at + 1)
			if next_end <= at + 1:
				return false
			at = next_end
		elif mark == "(" or mark == "[":
			at = _closing(text, at)
			if at < 0:
				return false
		else:
			return false
	return true


## The index just past the identifier starting at `start`, or `start` when none starts there.
static func _identifier_end(text: String, start: int) -> int:
	var at: int = start
	while at < text.length():
		var code: int = text.unicode_at(at)
		var letter: bool = (code >= 65 and code <= 90) or (code >= 97 and code <= 122) or code == 95
		var digit: bool = code >= 48 and code <= 57
		if not (letter or (digit and at > start)):
			break
		at += 1
	return at


## The index just past the bracket that closes the one at `open`, skipping strings, or -1 when it does not close.
static func _closing(text: String, open: int) -> int:
	var depth: int = 0
	var quote: String = ""
	var at: int = open
	while at < text.length():
		var mark: String = text[at]
		if not quote.is_empty():
			if mark == "\\":
				at += 1
			elif mark == quote:
				quote = ""
		elif mark == "\"" or mark == "'":
			quote = mark
		elif mark == "(" or mark == "[" or mark == "{":
			depth += 1
		elif mark == ")" or mark == "]" or mark == "}":
			depth -= 1
			if depth == 0:
				return at + 1
		at += 1
	return -1
