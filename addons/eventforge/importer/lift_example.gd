# EventForge - ENTRIES BY EXAMPLE: write the line, mark the values, get the recogniser.
#
# A lift entry is four columns and one of them is a regex. The regex is where they go wrong: an
# unescaped dot, a group nobody named, an anchor left off, a value span so wide it swallows the one
# after it. None of that is interesting, and all of it is mechanical - so a table author can hand over
# the LINE instead, exactly as a person writes it, with the value spans marked:
#
#     get_tree().create_timer([[seconds|argument: 2.0]]).timeout.connect([[object|receiver: $Enemy]].queue_free)
#
# and get back the whole entry: the pattern anchored at both ends with everything outside a mark
# escaped literally, the captures named after the marks, the shape that re-emits the example with
# slots where the marks were, the sample values the harness generates its fixture line from, and a
# blank default for every span that may be left unwritten. The existing harness then picks the entry
# up exactly as it picks up a hand-written one, because it IS one.
#
# THE MARKER. A value span is `[[name: text]]`, or `[[name|fragment: text]]` to say which of the
# capture grammar's fragments it is (`EventForgeLiftGrammar` - node, receiver, name, literal, word,
# argument, expression). `name` is what the row calls the value; `text` is what a real line would have
# there, and it doubles as the sample the fixture is generated from. Unnamed, the fragment is
# `expression` - the whole of the rest of the value, which is what a person means by "a value goes
# here". A receiver span is written without its dot (`[[object|node: $Enemy]].queue_free`), the
# dot after it is taken into the fragment, and the slot comes back as `{object.}`, which is how a row
# with the field cleared writes the bare member operation.
#
# WHICH RECEIVER WORD. `node` claims the three spellings a row addresses a node by - `$Path`,
# `%Unique`, `get_node("Path")` - and is what an example writes. `receiver` also claims a bare
# variable, which matches every receiver in the language, so an entry taking it claims the verb's
# name on ANY object, a bare self-call included; the grammar allows that only where the entry has a
# second way to be sure the variable really is the node it wants. Whether it has one is not something
# the example can say, so it is not refused here - `wide_receiver_in` names the span and the caller
# that knows where the entry came from decides (a pack's, which can carry no guard, is refused).
#
# TWO SPELLINGS ARE TWO EXAMPLES. `rpc("f", 1)` and `f.rpc(1)` are not one example with a choice in
# it - a choice is the thing this cannot check - so each is its own entry, exactly as the hand-written
# tables already write them.
#
# IT NEVER GUESSES. Every question this cannot answer mechanically is a REFUSAL carrying the sentence
# that says why: a span with no name, a name used twice, a fragment word that does not exist, text
# that is not the fragment it claims to be, two spans wide enough to swallow each other, two spans
# with nothing between them, a receiver with no dot after it. The refusal comes back as an entry
# carrying the reason (see EventForgeLiftTable.REFUSAL_KEY), so a table that asked for something
# impossible fails the suite naming itself rather than shipping a spelling that never matches.
@tool
class_name EventForgeLiftExample
extends RefCounted

const G := preload("res://addons/eventforge/importer/lift_grammar.gd")

## The marks around a value span, and the two characters inside it that separate the name from the
## fragment and the fragment from the text. Doubled brackets because a doubled bracket is not
## something GDScript writes: `a[[0]]` is an index of an array literal, which is not a line anybody
## writes into a lift example, and every other pairing (braces, angles, single brackets) is ordinary
## code.
const OPEN: String = "[["
const CLOSE: String = "]]"
const FRAGMENT_MARK: String = "|"
const TEXT_MARK: String = ":"

## The key a refusal travels back under, inside this file. It becomes the table's own refusal key on
## the way out, which is what the validator reads.
const REFUSED: String = "refused"

## The key the walk names a WIDE receiver span under, inside this file. It never reaches an entry:
## whether a wide span is allowed depends on what else the entry carries - a `guard`, or a family a
## person reviewed - which the example itself cannot say. `wide_receiver_in` is how a caller that
## does know asks.
const WIDE: String = "wide"

## One capture name, as a name may be spelled. The same identifier the grammar matches in a line,
## asked here of the marker rather than of the code.
const NAME_PATTERN: String = "^[A-Za-z_][A-Za-z0-9_]*$"


## The lift-table entry one marked example means. `extras` is merged in afterwards for the columns an
## example cannot say - a `guard`, a `provider`, extra `defaults` - and a `defaults` there is merged
## with the ones the spans asked for rather than replacing them.
##
## A refusal comes back as `{id, ace_id, error}`: an entry the validator names and the suite fails on,
## never an empty dictionary that a table would carry as a hole.
static func entry(id: String, ace_id: String, example: String, extras: Dictionary = {}) -> Dictionary:
	var built: Dictionary = _build(example)
	if built.has(REFUSED):
		return {"id": id, "ace_id": ace_id, EventForgeLiftTable.REFUSAL_KEY: str(built[REFUSED])}
	var made: Dictionary = {
		"id": id,
		"ace_id": ace_id,
		"pattern": "^%s$" % str(built["pattern"]),
		"shape": str(built["shape"]),
		"slots": built["slots"]
	}
	var params: PackedStringArray = built["params"]
	if not params.is_empty():
		made["params"] = params
	var defaults: Dictionary = (built["defaults"] as Dictionary).duplicate()
	defaults.merge(extras.get("defaults", {}) as Dictionary, true)
	if not defaults.is_empty():
		made["defaults"] = defaults
	for key: Variant in extras.keys():
		if str(key) == "defaults":
			continue
		made[str(key)] = extras[key]
	return made


## The sentence this example would be refused with, or "" when it builds. Asked through `entry`
## itself rather than beside it, so a caller checking an example before it builds - a test table, a
## tool checking something somebody typed - is told the same thing the entry would have said.
static func refusal(example: String, extras: Dictionary = {}) -> String:
	return str(entry("", "", example, extras).get(EventForgeLiftTable.REFUSAL_KEY, ""))


## The name of the first span in this example that asks for the WIDE receiver, or "" when none does.
## The wide word also matches a bare variable, so an entry taking it claims its verb on every object
## in the language; the grammar allows that only where the entry has a second way to be sure, and the
## only caller that can answer that question is the one that knows where the entry came from.
static func wide_receiver_in(example: String) -> String:
	return str(_build(example).get(WIDE, ""))


# ── the pieces ──────────────────────────────────────────────────────────────────


## The example walked once, left to right: literal runs escaped into the pattern and copied into the
## shape, marked spans turned into their fragment's pattern and its slot. Returns the four columns, or
## `{refused: why}` at the first thing it cannot answer mechanically.
static func _build(example: String) -> Dictionary:
	if example.strip_edges().is_empty():
		return {REFUSED: "the example is empty"}
	var pattern: String = ""
	var shape: String = ""
	var params: PackedStringArray = PackedStringArray()
	var slots: Dictionary = {}
	var defaults: Dictionary = {}
	var wide: String = ""
	var expressions: int = 0
	var after_a_span: bool = false
	var index: int = 0
	while index < example.length():
		var open: int = example.find(OPEN, index)
		if open < 0:
			pattern += G.escaped_run(example.substr(index))
			shape += example.substr(index)
			break
		var run: String = example.substr(index, open - index)
		if run.is_empty() and after_a_span:
			return {REFUSED: "two spans meet with nothing between them to tell them apart"}
		pattern += G.escaped_run(run)
		shape += run
		var close: int = example.find(CLOSE, open + OPEN.length())
		if close < 0:
			return {REFUSED: "a span is never closed: %s" % example.substr(open)}
		var inner: String = example.substr(open + OPEN.length(), close - open - OPEN.length())
		var span: Dictionary = _span(inner, slots)
		if span.has(REFUSED):
			return span
		var fragment: String = str(span["fragment"])
		var name: String = str(span["name"])
		if fragment == G.FRAGMENT_EXPRESSION:
			expressions += 1
			if expressions > 1:
				return {REFUSED: "two spans are expressions, and a span that wide swallows the text"\
					+ " after it - name a narrower fragment on all but one"}
		if fragment == G.FRAGMENT_RECEIVER and wide.is_empty():
			wide = name
		index = close + CLOSE.length()
		if G.fragment_takes_a_dot(fragment):
			if example.substr(index, 1) != ".":
				return {REFUSED: "the receiver span %s is not followed by a dot" % name}
			index += 1
		var read: Dictionary = _read(span)
		if read.has(REFUSED):
			return read
		pattern += str(read["pattern"])
		shape += str(read["slot"])
		params.append(name)
		slots[name] = str(read["value"])
		if G.fragment_is_optional(fragment):
			defaults[name] = ""
		after_a_span = true
	return {"pattern": pattern, "shape": shape, "params": params, "slots": slots,
		"defaults": defaults, WIDE: wide}


## One span's three words - the capture's name, the fragment it is, and the text a real line would
## have there - or the reason it cannot be read as those.
static func _span(inner: String, named_already: Dictionary) -> Dictionary:
	if inner.contains(OPEN):
		return {REFUSED: "a span opens inside another: %s" % inner}
	var mark: int = inner.find(TEXT_MARK)
	if mark < 0:
		return {REFUSED: "the span %s says no text, which is what the fixture is generated from"\
			% inner}
	var head: String = inner.substr(0, mark).strip_edges()
	var text: String = inner.substr(mark + TEXT_MARK.length()).strip_edges()
	var fragment: String = G.FRAGMENT_EXPRESSION
	var name: String = head
	var bar: int = head.find(FRAGMENT_MARK)
	if bar >= 0:
		name = head.substr(0, bar).strip_edges()
		fragment = head.substr(bar + FRAGMENT_MARK.length()).strip_edges()
	if fragment.contains(FRAGMENT_MARK):
		return {REFUSED: "the span %s names more than one fragment" % head}
	if RegEx.create_from_string(NAME_PATTERN).search(name) == null:
		return {REFUSED: "%s is not a name a capture can take" % (name if not name.is_empty()\
			else "a span with no name before the colon")}
	if named_already.has(name):
		return {REFUSED: "two spans are named %s" % name}
	if text.is_empty():
		return {REFUSED: "the span %s says no text, which is what the fixture is generated from"\
			% name}
	if not G.FRAGMENT_NAMES.has(fragment):
		return {REFUSED: "there is no %s fragment - the fragments are %s"\
			% [fragment, ", ".join(G.FRAGMENT_NAMES)]}
	return {"name": name, "fragment": fragment, "text": text}


## One span as the three things the walk needs: the pattern its fragment spells, the slot its shape
## re-emits as, and the value the fixture is generated with. Refused when the text is not an instance
## of the fragment it says it is - which is the whole of "it never guesses", asked of the example
## itself rather than of the author.
static func _read(span: Dictionary) -> Dictionary:
	var name: String = str(span["name"])
	var fragment: String = str(span["fragment"])
	var pattern: String = G.fragment_pattern(fragment, name)
	var text: String = str(span["text"]) + ("." if G.fragment_takes_a_dot(fragment) else "")
	var regex: RegEx = RegEx.create_from_string("^%s$" % pattern)
	var hit: RegExMatch = regex.search(text) if regex != null else null
	if hit == null or hit.get_start(name) < 0:
		return {REFUSED: "the %s span reads %s, which is not a %s"\
			% [name, str(span["text"]), fragment]}
	if G.fragment_takes_a_dot(fragment):
		return {"pattern": pattern, "slot": G.optional_prefix_slot(name),
			"value": hit.get_string(name)}
	# The slot is the span's own text with the captured span spliced out for it, so an example whose
	# fragment carries scenery of its own (`&"take_damage"` is a name in a quoting) re-emits that
	# scenery verbatim - which is the same splice the engine does when it stores a matched line.
	var slot: String = text.substr(0, hit.get_start(name)) + "{%s}" % name\
		+ text.substr(hit.get_end(name))
	return {"pattern": pattern, "slot": slot, "value": hit.get_string(name)}
