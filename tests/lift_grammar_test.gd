# Godot EventSheets - the capture grammar, and the entries derived from an example.
#
# The recogniser tables are patterns with holes in them, and the holes repeat: a receiver that may not
# be written, a name in either quoting, one argument of a call, the expression that runs to the end.
# `EventForgeLiftGrammar` is those spans as one vocabulary, and this file is what says the vocabulary
# means what it claims - each fragment pinned on a table of what it ACCEPTS and what it REFUSES,
# because a fragment that quietly widened would widen every family at once.
#
# Then the builder. `EventForgeLiftExample` derives a whole entry from the line as a person writes it
# with the value spans marked, and the proof it is right is not a pattern comparison - it is that two
# entries derived from EXISTING shipped spellings behave like the hand-written ones they were derived
# from: the same shape, the same samples, the same values pulled out of the same lines, and the same
# bytes re-emitted from them.
@tool
class_name LiftGrammarTest
extends RefCounted

const Pins := preload("res://tests/pin_table.gd")
const G := preload("res://addons/eventforge/importer/lift_grammar.gd")

## What a fragment table answers when the text is not that fragment at all. A sentinel rather than
## "", because "" is a real answer: an optional fragment matches nothing and captures nothing.
const NO_MATCH: String = "(no match)"

## The two shipped spellings the by-example builder is proved against, by the family that ships them
## and the entry id inside it. Both are entries somebody wrote by hand before this builder existed.
const PROVEN_AGAINST: Array[Dictionary] = [
	{
		"id": "send_everyone_with_arguments",
		"example": "rpc([[message|name: \"take_damage\"]], [[args|expression: 10]])",
		"lines": ["rpc(\"take_damage\", 10)", "rpc(&\"take_damage\", 10)", "rpc(\"take_damage\",10)",
			"rpc(\"take_damage\")", "rpc(\"take_damage\", Vector2(1, 2), 3)"]
	},
	{
		"id": "remove_after_timer",
		"example": "get_tree().create_timer([[seconds|argument: 2.0]]).timeout.connect("\
			+ "[[object|receiver: $Enemy]].queue_free)",
		"lines": ["get_tree().create_timer(2.0).timeout.connect(queue_free)",
			"get_tree().create_timer(2.0).timeout.connect($Enemy.queue_free)",
			"get_tree().create_timer(fuse).timeout.connect(%Hud.queue_free)",
			"get_tree().create_timer(2.0).timeout.connect(other)"]
	}
]


static func run() -> bool:
	var ok: bool = true
	ok = _test_the_fragments() and ok
	ok = _test_a_literal_run() and ok
	ok = _test_an_example_becomes_an_entry() and ok
	ok = _test_a_bad_example_is_refused() and ok
	ok = _test_derived_entries_behave_like_the_shipped_ones() and ok
	return ok


## Every fragment, on a table of what it accepts and what it refuses. The answer is the VALUE the
## fragment captures, so a table that accepted the right text for the wrong reason (the whole literal
## where the row wants the name inside it) still fails here.
static func _test_the_fragments() -> bool:
	var ok: bool = Pins.check("lift_grammar_test/receiver", {
		"$Torch.": "$Torch",
		"%Hud.": "%Hud",
		"get_node(\"Room/Lamp\").": "get_node(\"Room/Lamp\")",
		"torch.": "torch",
		"": "",
		"2torch.": NO_MATCH,
		"state.machine.": NO_MATCH,
		"$Torch": NO_MATCH
	}, func(text: String) -> String: return _captured(G.receiver("target"), "target", text))
	# The widest receiver, taken where nothing has to be true about it: a chain matches, and captures
	# nothing, because the row never shows it.
	ok = Pins.check("lift_grammar_test/receiver_chain", {
		"state.machine.": "",
		"$Ui/Panel.": "",
		"": "",
		"2 + 2.": NO_MATCH
	}, func(text: String) -> String:
		return _captured(G.receiver("", G.NODE_CHAIN), "target", text)) and ok
	ok = Pins.check("lift_grammar_test/name", {
		"\"take_damage\"": "take_damage",
		"&\"take_damage\"": "take_damage",
		"\"take-damage\"": NO_MATCH,
		"\"\"": NO_MATCH,
		"take_damage": NO_MATCH,
		"&take_damage": NO_MATCH
	}, func(text: String) -> String: return _captured(G.quoted_name("m"), "m", text)) and ok
	ok = Pins.check("lift_grammar_test/literal", {
		"\"attack\"": "\"attack\"",
		"&\"idle\"": "&\"idle\"",
		"\"\"": "\"\"",
		"\"hit hard\"": "\"hit hard\"",
		"attack": NO_MATCH
	}, func(text: String) -> String: return _captured(G.quoted_literal("a"), "a", text)) and ok
	# Between the two above, and the difference is the whole reason it exists: the value is the quoted
	# text WITH its quotes and WITHOUT the ampersand, because that is what an `&{action}` template
	# writes back and what the action field's own dropdown offers.
	ok = Pins.check("lift_grammar_test/text", {
		"\"jump\"": "\"jump\"",
		"&\"jump\"": "\"jump\"",
		"\"ui_page_down\"": "\"ui_page_down\"",
		"\"\"": "\"\"",
		"\"move left\"": "\"move left\"",
		"jump": NO_MATCH,
		"&jump": NO_MATCH
	}, func(text: String) -> String: return _captured(G.quoted_text("a"), "a", text)) and ok
	ok = Pins.check("lift_grammar_test/word", {
		"peer": "peer",
		"_was_on_floor": "_was_on_floor",
		"2peer": NO_MATCH,
		"peer.host": NO_MATCH,
		"": NO_MATCH
	}, func(text: String) -> String: return _captured(G.word("w"), "w", text)) and ok
	ok = Pins.check("lift_grammar_test/argument", {
		"2.0": "2.0",
		"fuse": "fuse",
		"a + b": "a + b",
		"Vector2(1, 2)": NO_MATCH,
		"a, b": NO_MATCH,
		"": NO_MATCH
	}, func(text: String) -> String: return _captured(G.argument("v"), "v", text)) and ok
	ok = Pins.check("lift_grammar_test/expression", {
		"10": "10",
		"Color(0.3, 0.3, 0.36)": "Color(0.3, 0.3, 0.36)",
		"a, b": "a, b",
		"": NO_MATCH
	}, func(text: String) -> String: return _captured(G.expression("v"), "v", text)) and ok
	return ok


## The author's own text as a pattern: metacharacters escaped so a dot means a dot, and a comma
## widened to the separator so the spacing after it is matched rather than demanded.
static func _test_a_literal_run() -> bool:
	return Pins.check("lift_grammar_test/escaped_run", {
		"create_timer(": "create_timer\\(",
		"a.b": "a\\.b",
		", ": ",[ \\t]*",
		",": ",[ \\t]*",
		").timeout.connect(": "\\)\\.timeout\\.connect\\(",
		"[1]": "\\[1\\]",
		"\"a, b\"": "\"a, b\""
	}, func(text: String) -> String: return G.escaped_run(text))


## One example, whole. Every column of the entry is pinned, because the entry is what ships: the
## anchored pattern, the shape that re-emits the example with slots, the samples the harness generates
## its fixture from, and the blank default the optional span asked for.
static func _test_an_example_becomes_an_entry() -> bool:
	var entry: Dictionary = EventForgeLiftExample.entry("torch_brightness", "LightSetBrightness",
		"[[target|receiver: $Torch]].energy = [[value: 1.2]]")
	var ok: bool = Pins.check("lift_grammar_test/derived", {
		"pattern": "^(?:(?<target>%s)\\.)?energy = (?<value>.+)$" % G.NODE_REFERENCE,
		"shape": "{target.}energy = {value}",
		"slots": {"target": "$Torch", "value": "1.2"},
		"defaults": {"target": ""},
		"params": PackedStringArray(["target", "value"]),
		"ace_id": "LightSetBrightness"
	}, func(key: String) -> Variant: return entry.get(key, "(missing)"))
	ok = Pins.check_value("lift_grammar_test", "a derived entry is a sound table entry",
		EventForgeLiftTable.validate([entry]), PackedStringArray()) and ok
	# The fixture the harness would generate from it, and the row that line means - the same walk the
	# shipped entries take, on an entry nobody wrote a pattern for.
	var line: String = _emit(str(entry["shape"]), entry["slots"] as Dictionary)
	ok = Pins.check_value("lift_grammar_test", "its fixture line", line, "$Torch.energy = 1.2") and ok
	ok = Pins.check_value("lift_grammar_test", "which it claims, with the values the line says",
		EventForgeLiftTable.match_line([entry], line), {
			"entry_id": "torch_brightness", "ace_id": "LightSetBrightness", "provider": "Core",
			"params": {"target": "$Torch", "value": "1.2"}, "template": "{target.}energy = {value}"
		}) and ok
	# And the spelling that leaves the optional span out, which is the commonest one a sheet attached
	# to its own node writes.
	ok = Pins.check_value("lift_grammar_test", "the receiver-less spelling is the same row",
		EventForgeLiftTable.match_line([entry], "energy = 3.0"), {
			"entry_id": "torch_brightness", "ace_id": "LightSetBrightness", "provider": "Core",
			"params": {"target": "", "value": "3.0"}, "template": "{target.}energy = {value}"
		}) and ok
	return ok


## Every question the builder cannot answer mechanically, and the sentence it refuses with. A builder
## that guessed once would be a builder nobody could trust with the other fifteen families.
static func _test_a_bad_example_is_refused() -> bool:
	return Pins.check("lift_grammar_test/refusals", {
		"": "the example is empty",
		"rpc([[message: \"x\"]": "a span is never closed: [[message: \"x\"]",
		"rpc([[me[[ss: x]])": "a span opens inside another: me[[ss: x",
		"rpc([[message]])": "the span message says no text, which is what the fixture is generated from",
		"rpc([[message: ]])": "the span message says no text, which is what the fixture is generated from",
		"rpc([[: x]])": "a span with no name before the colon is not a name a capture can take",
		"rpc([[my message: x]])": "my message is not a name a capture can take",
		"rpc([[m: x]], [[m: y]])": "two spans are named m",
		"rpc([[m|noun: x]])": "there is no noun fragment - the fragments are receiver, name, literal,"\
			+ " text, word, argument, expression",
		"rpc([[m|name|word: x]])": "the span m|name|word names more than one fragment",
		"rpc([[m|name: take_damage]])": "the m span reads take_damage, which is not a name",
		"rpc([[a: 1]], [[b: 2]])": "two spans are expressions, and a span that wide swallows the text"\
			+ " after it - name a narrower fragment on all but one",
		"[[a|word: x]][[b|word: y]]": "two spans meet with nothing between them to tell them apart",
		"[[t|receiver: $Enemy]]queue_free()": "the receiver span t is not followed by a dot"
	}, func(example: String) -> String: return EventForgeLiftExample.refusal(example))


## THE PROOF. Two entries derived from spellings this plugin already ships, against the hand-written
## entries they were derived from: the same shape, the same samples, the same defaults, the same
## params, and on every line either of them could meet, the same values and the same bytes back.
static func _test_derived_entries_behave_like_the_shipped_ones() -> bool:
	var ok: bool = true
	var shipped: Dictionary = _shipped_entries()
	for proof: Dictionary in PROVEN_AGAINST:
		var id: String = str(proof["id"])
		var hand_written: Dictionary = shipped.get(id, {})
		if hand_written.is_empty():
			ok = Pins.check_value("lift_grammar_test", "%s is a shipped entry" % id, false, true)
			continue
		var derived: Dictionary = EventForgeLiftExample.entry(id, str(hand_written["ace_id"]),
			str(proof["example"]))
		ok = Pins.check("lift_grammar_test/%s" % id, {
			"shape": str(hand_written["shape"]),
			"slots": hand_written["slots"],
			"defaults": hand_written.get("defaults", {}),
			"params": _sorted(EventForgeLiftTable.param_names(hand_written))
		}, func(key: String) -> Variant:
			if key == "params":
				return _sorted(EventForgeLiftTable.param_names(derived))
			return derived.get(key, {} if key != "shape" else "")) and ok
		ok = Pins.check_value("lift_grammar_test", "%s derives a sound entry" % id,
			EventForgeLiftTable.validate([derived]), PackedStringArray()) and ok
		for line: String in proof["lines"] as Array:
			ok = _same_reading(id, hand_written, derived, line) and ok
	return ok


## One line, read by both entries. The entry ids differ by construction (the derived one is built
## here), so everything else is compared: the row, the values, the stored spelling, and the bytes that
## spelling writes back.
static func _same_reading(id: String, hand_written: Dictionary, derived: Dictionary,
		line: String) -> bool:
	var by_hand: Dictionary = _reading(hand_written, line)
	var by_example: Dictionary = _reading(derived, line)
	var ok: bool = Pins.check_value("lift_grammar_test", "%s reads %s the same way" % [id, line],
		by_example, by_hand)
	if by_hand.is_empty():
		return ok
	return Pins.check_value("lift_grammar_test", "%s re-emits %s byte for byte" % [id, line],
		_emit(str(by_hand["template"]), by_hand["params"] as Dictionary), line) and ok


## What one entry says a line is, without the entry's own name in it.
static func _reading(entry: Dictionary, line: String) -> Dictionary:
	var hit: Dictionary = EventForgeLiftTable.match_line([entry], line)
	if hit.is_empty():
		return {}
	return {"ace_id": hit["ace_id"], "params": hit["params"], "template": hit["template"]}


## The shipped entries this file is proved against, by id, out of the families that ship them.
static func _shipped_entries() -> Dictionary:
	var found: Dictionary = {}
	for entries: Variant in EventForgeLiftTable.families().values():
		for entry: Dictionary in entries as Array:
			found[str(entry.get("id", ""))] = entry
	return found


## The value one fragment captures out of one text, or the sentinel when the text is not that
## fragment. Anchored at both ends, because a fragment is asked to BE the span rather than to appear
## somewhere in it.
static func _captured(fragment: String, name: String, text: String) -> String:
	var regex: RegEx = RegEx.create_from_string("^%s$" % fragment)
	if regex == null or not regex.is_valid():
		return NO_MATCH
	var hit: RegExMatch = regex.search(text)
	if hit == null:
		return NO_MATCH
	return hit.get_string(name) if hit.get_start(name) >= 0 else ""


static func _sorted(names: PackedStringArray) -> PackedStringArray:
	var copy: PackedStringArray = PackedStringArray(names)
	copy.sort()
	return copy


## One row's line, through the compiler's own emitter - never a copy of the substitution.
static func _emit(template: String, params: Dictionary) -> String:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.codegen_template = template
	action.params = params.duplicate()
	return ActionCodegen.generate_action(action)
