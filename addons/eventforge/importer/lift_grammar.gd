# EventForge - the CAPTURE GRAMMAR: the handful of spans every recogniser table keeps re-spelling.
#
# A lift entry is a pattern with holes in it, and across every family in this folder the holes turn
# out to be the same seven things. A receiver that may or may not be written. A message name in either
# of the two quotings Godot accepts. A whole quoted literal, quotes and all, because some rows hold
# the literal rather than the word inside it. The same literal WITHOUT the ampersand, because the
# fields that name an action or a group hold `"jump"` and let the template write the `&`. One argument
# of a call. The expression that runs to the end of the line. And one bare identifier.
#
# Written per family that is six regex fragments copied six times, each with its own private idea of
# what an identifier is - and the day one of them widens, the others silently do not. Written here it
# is one vocabulary, pinned on tables of what it accepts and what it refuses, and a family that says
# `quoted_name("message")` cannot drift from the family beside it that says the same thing.
#
# EVERY FRAGMENT HAS TWO HALVES, and they are here together on purpose: the PATTERN it matches, and
# the SHAPE slot it re-emits as. The receiver is the one that differs between them - it matches
# `$Torch.` including the dot and re-emits as `{target.}`, dot inside the braces, so that a row with
# the field cleared writes `energy = 1.2` rather than a line beginning with a dot. Keeping the two
# halves in one place is what stops a pattern being widened without its shape following.
#
# WHAT IS NOT HERE. A fragment used by exactly one family and meaning nothing anywhere else - the
# enumerated compression codecs, the lambda parameter matched twice and back-referenced, the words a
# name reads as "the footing last step" by - stays in the family that means it. This is the vocabulary
# the families REPEAT, not every span they have.
@tool
class_name EventForgeLiftGrammar
extends RefCounted

## One identifier, as the author may have spelled it. The atom under half the fragments below, and
## the reason a family never writes its own: `[A-Za-z_][A-Za-z0-9_]*` written out per family is a
## definition of what a name is, kept in nine places.
const IDENTIFIER: String = "[A-Za-z_][A-Za-z0-9_]*"

## The node spellings a row can address a node by, as a pattern fragment: `$Path`, `%Unique` and
## `get_node("Path")`. All three are the author's own text and ride back out untouched, which is why
## the receiver they sit in is not part of any sentence.
const NODE_PATHS: String = "\\$[A-Za-z_][A-Za-z0-9_/]*|%[A-Za-z_][A-Za-z0-9_]*"\
	+ "|get_node\\(\"[A-Za-z_][A-Za-z0-9_/]*\"\\)"

## The same, plus the bare variable a node was held in. A family takes this WIDER set only when it
## has a second way to be sure the variable really is the node it wants (the shader table asks the
## scene which variables hold a material-wearing node); a family with no such check takes the paths
## above, because a bare identifier matches every receiver in the language and claiming those on a
## call name alone would take lines away from the readings that already say more about them.
const NODE_REFERENCE: String = NODE_PATHS + "|[A-Za-z_][A-Za-z0-9_]*"

## The widest receiver spelling: a dotted chain (`state.machine.`), on top of the paths above. Taken
## ONLY where the receiver is not a value of the row and is therefore never resolved to a node - a
## send says nothing about who sent it, so whatever stood in front of the call rides back out
## verbatim and nothing has to be true about it. A family that resolves its receiver takes
## NODE_REFERENCE instead, because a chain is not a name any scene map can answer for.
const NODE_CHAIN: String = "\\$[A-Za-z0-9_/]+|%[A-Za-z0-9_]+|[A-Za-z_][A-Za-z0-9_.]*"

## The separator between two arguments, as WRITTEN. A comma and whatever spacing followed it, matched
## rather than required, so a call spelled `f(a,b)` re-emits without the space instead of being
## canonicalised into a byte-gate failure.
const SEPARATOR: String = ",[ \\t]*"

## The fragments by the word a table author asks for them by. Seven, because these are the spans the
## families actually repeat; the list doubles as what a by-example builder may name.
const FRAGMENT_RECEIVER: String = "receiver"
const FRAGMENT_NAME: String = "name"
const FRAGMENT_LITERAL: String = "literal"
const FRAGMENT_TEXT: String = "text"
const FRAGMENT_WORD: String = "word"
const FRAGMENT_ARGUMENT: String = "argument"
const FRAGMENT_EXPRESSION: String = "expression"

## Every fragment name, in the order a reader meets them. Sorted by nothing on purpose: this is the
## order the header above explains them in, and it is the same on every machine.
const FRAGMENT_NAMES: PackedStringArray = [FRAGMENT_RECEIVER, FRAGMENT_NAME, FRAGMENT_LITERAL,
	FRAGMENT_TEXT, FRAGMENT_WORD, FRAGMENT_ARGUMENT, FRAGMENT_EXPRESSION]

## The metacharacters a literal run of the author's own text has to be protected from. An unescaped
## `.` matches any character at all, which is how a pattern for `create_timer(` quietly also claims
## `createXtimer(`.
const METACHARACTERS: String = "\\^$.|?*+()[]{}"


## The OPTIONAL RECEIVER a node-scoped line opens with, as one capture. Optional because "On node" is
## optional on every one of these rows - leave it blank and the line is the bare member operation,
## `energy = 1.2` or `material.set_shader_parameter(...)`, which is the commonest shape a sheet
## attached to its own node writes. `name` is the capture, so a line naming the same node twice can be
## matched with one group per mention and a guard asked whether they agree.
##
## An EMPTY name spells the same fragment without capturing anything - what a family takes when the
## receiver is not a value of any row and there is nothing to ask about it.
static func receiver(name: String = "target", spellings: String = NODE_REFERENCE) -> String:
	if name.is_empty():
		return "(?:(?:%s)\\.)?" % spellings
	return "(?:(?<%s>%s)\\.)?" % [name, spellings]


## The OPTIONAL-PREFIX spelling of a param - `{target.}`, the receiver idiom every node-scoped
## descriptor writes. The dot lives INSIDE the braces, so the emitter writes it only along with a
## value: a row whose receiver is cleared emits `energy = 1.2`, where `{target}.` would leave the
## dot behind and hand the author a line that does not parse.
static func optional_prefix_slot(name: String) -> String:
	return "{%s.}" % name


## A message name in EITHER QUOTING, as one capture of the name itself. Godot takes a StringName or a
## plain String wherever a message or a property is named, and everybody picks by habit - so the `&`
## and the quotes are the author's spelling rather than the row's value, and stay outside the capture
## precisely so they ride back out untouched.
static func quoted_name(name: String) -> String:
	return "&?\"(?<%s>%s)\"" % [name, IDENTIFIER]


## The WHOLE quoted literal as the value, quotes and ampersand included - what a row holds when the
## field it shows is a text field rather than a name field. The animation rows are the specimen: their
## parameter really does contain `&"idle"`, which is what lets a lifted row and a picked row be
## edited by the same field.
static func quoted_literal(name: String) -> String:
	return "(?<%s>&?\"[^\"]*\")" % name


## THE QUOTED LITERAL WITH THE AMPERSAND LEFT OUTSIDE IT: the value is `"jump"`, quotes and all, and
## a leading `&` is the author's spelling rather than the row's value. This is the span an input
## action, a group name and a property name are held in all over the shipped vocabulary, whose
## templates spell the field as `&{action}` - the `&` belongs to the TEMPLATE, so a lift that took it
## into the value would hand the row a chip the field's own dropdown does not offer.
##
## Between the other two on purpose: `quoted_name` gives the bare word inside the quotes and
## `quoted_literal` gives everything including the `&`, and neither is what a `&{slot}` template wants
## back.
static func quoted_text(name: String) -> String:
	return "&?(?<%s>\"[^\"]*\")" % name


## One bare identifier as the value - a variable the line names, a group, a word the row shows.
static func word(name: String) -> String:
	return "(?<%s>%s)" % [name, IDENTIFIER]


## ONE ARGUMENT of a call: everything up to the comma or the bracket that ends it. The narrow value
## span, taken wherever an argument has another one after it.
static func argument(name: String) -> String:
	return "(?<%s>[^,)]+)" % name


## THE EXPRESSION a value really is: whatever the author wrote, commas and brackets and all. The wide
## span - `Color(0.3, 0.3, 0.36)` is one value and not three - and the reason a table never wants two
## of them in one pattern, where each could swallow the other's text.
static func expression(name: String) -> String:
	return "(?<%s>.+)" % name


## The pattern one fragment spells for one capture, or "" for a word this vocabulary does not have.
## The one dispatch, so a builder naming fragments by their word and a family calling them directly
## can never be given two different answers.
static func fragment_pattern(fragment: String, name: String) -> String:
	match fragment:
		FRAGMENT_RECEIVER:
			return receiver(name)
		FRAGMENT_NAME:
			return quoted_name(name)
		FRAGMENT_LITERAL:
			return quoted_literal(name)
		FRAGMENT_TEXT:
			return quoted_text(name)
		FRAGMENT_WORD:
			return word(name)
		FRAGMENT_ARGUMENT:
			return argument(name)
		FRAGMENT_EXPRESSION:
			return expression(name)
	return ""


## True when a fragment may match nothing at all, so the row still needs a value for it when the line
## does not say one. The receiver alone, today: "On node" left blank is a spelling too.
static func fragment_is_optional(fragment: String) -> bool:
	return fragment == FRAGMENT_RECEIVER


## True when a fragment takes the separator AFTER it into itself. The receiver alone: the dot belongs
## to the idiom rather than to the line, which is what `{target.}` says.
static func fragment_takes_a_dot(fragment: String) -> bool:
	return fragment == FRAGMENT_RECEIVER


## True when a shape answers for a param - under either spelling, the plain `{name}` or the optional
## prefix `{name.}`. The one question a validator and a splice both ask, so a shape written in the
## receiver idiom cannot be sound to one of them and unknown to the other.
static func shape_answers(shape: String, name: String) -> bool:
	return shape.contains("{%s}" % name) or shape.contains(optional_prefix_slot(name))


## One run of the author's own text as a PATTERN: every character verbatim, with two exceptions that
## are the same exception twice. A regex metacharacter is escaped, so a `.` the author wrote means a
## dot and not "any character at all". And a comma is widened to the separator above, because the
## spacing after a comma is the one piece of an author's own spelling that varies without meaning
## anything - and the matched line is what gets stored, so `f(a,b)` still saves back as itself.
##
## A comma INSIDE a quoted run is a character in somebody's text and is escaped like any other.
static func escaped_run(text: String) -> String:
	var pattern: String = ""
	var quote: String = ""
	var index: int = 0
	while index < text.length():
		var character: String = text[index]
		if not quote.is_empty():
			pattern += escaped(character)
			if character == quote:
				quote = ""
			index += 1
			continue
		if character == "\"" or character == "'":
			quote = character
			pattern += escaped(character)
			index += 1
			continue
		if character == ",":
			pattern += SEPARATOR
			index += 1
			while index < text.length() and (text[index] == " " or text[index] == "\t"):
				index += 1
			continue
		pattern += escaped(character)
		index += 1
	return pattern


## One character as a pattern matches it: itself, backslashed when the language would otherwise read
## it as an instruction.
static func escaped(character: String) -> String:
	return "\\" + character if METACHARACTERS.contains(character) else character
