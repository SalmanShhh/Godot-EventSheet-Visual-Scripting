# EventForge - the recogniser TABLE ENGINE: a lift is an ENTRY, not a function.
#
# Opening somebody's hand-written GDScript as a sheet means recognising the spellings they used and
# handing each one back as the row it means - and then writing the FILE'S OWN BYTES again when the
# sheet saves. Every recogniser therefore does the same four things: match a spelling, pull the
# values out of it, name the row it becomes, and remember the exact spelling it matched. Written by
# hand that is forty lines per family, four of which are the interesting ones; written here it is a
# table entry, and the four things are columns.
#
# One entry, in full:
#
#     {
#         "id": "send_to_everyone",                                 # stable, used by the harness
#         "ace_id": "SendMessageToEveryone",                        # the row this spelling means
#         "pattern": "^rpc\\(&?\"(?<message>[A-Za-z_][A-Za-z0-9_]*)\",[ \\t]*(?<args>.+)\\)$",
#         "params": ["message", "args"],                            # captures that become row values
#         "defaults": {"peer": ""},                                 # values the row has, the line doesn't
#         "guard": Callable(Family, "_is_peer_variable"),           # optional second opinion
#         "shape": "rpc(\"{message}\", {args})",                    # the canonical spelling
#         "slots": {"message": "take_damage", "args": "10"}         # what the harness fills it with
#     }
#
# A capture is only a PARAM if the row says it. Everything else the pattern catches - the `&` before
# a quoted name, a receiver in front of the call, the variable a connection was held in - is part of
# the author's spelling, and is left out of `params` precisely so that it rides back out untouched.
#
# THE SPELLING IS STORED BY CONSTRUCTION. The template handed back is the matched line with each
# PARAM capture spliced out and replaced by its `{name}` slot - everything else (that receiver, that
# `&`, the author's own spacing) rides along verbatim. Substituting the params back into that
# template is therefore the exact inverse of the splice, so the byte round-trip is not a hope the
# harness checks per case: it is the shape of the mechanism. What the harness checks is that a table
# AUTHOR did not break it - a param that is not a capture, a shape with no sample value, an entry
# with nothing to test it with.
#
# THE ONE SLOT THAT IS NOT A PLAIN CAPTURE: a receiver. A node-scoped row addresses its node with the
# optional prefix `{target.}` - dot inside the braces - so that clearing the field emits the bare
# member operation rather than a line beginning with a dot. An entry whose shape spells a param that
# way is spliced the same way, and the row a lift hands back is then the row the picker would have
# authored, down to the byte.
#
# WHAT DOES NOT BELONG HERE: a family whose spelling is several statements that only mean something
# together (the connection run: declare a peer, open it, hand it to the API), or one that has to read
# the scene to know whether it is even looking at the right kind of node. Those stay hand-written
# matchers. A table is for the shape a single statement can be recognised by - which, in practice, is
# most of them.
#
# ADDING A FAMILY: put a `static func lift_entries() -> Array[Dictionary]` on a script in this
# folder. The harness (tests/lift_table_test.gd) finds it by scanning, generates a fixture line per
# entry from `shape` + `slots`, and asserts the round trip. There is no list to add it to, and an
# entry that cannot be generated from cannot be committed.
@tool
class_name EventForgeLiftTable
extends RefCounted

## The static a family script declares to hand its entries to the engine and the harness alike.
const ENTRIES_METHOD: String = "lift_entries"

## The optional static a family declares when its guards read state a fixture has to set up first
## (the multiplayer table's peer variables are read off the file being lifted, and a generated
## fixture line has no file). Called once per family before its entries are probed.
const FIXTURE_CONTEXT_METHOD: String = "lift_fixture_context"

## Where families live. Scanned rather than listed so a family added by a later pass is covered by
## the harness the moment it exists (memory rule: derived over hand-maintained).
const FAMILY_DIR: String = "res://addons/eventforge/importer/"

## Keys every entry must carry, and the ones it may.
const REQUIRED_KEYS: Array[String] = ["id", "ace_id", "pattern", "shape", "slots"]
const OPTIONAL_KEYS: Array[String] = ["provider", "params", "defaults", "guard", "error", "origin"]

## HOW AN ENTRY WAS AUTHORED, and the one thing this engine will say about it that does not affect
## matching at all. A table entry is a table entry whichever way it was written, so nothing in
## `match_line` reads this - it exists because a reader asking WHAT CLAIMS THIS LINE deserves a
## truthful answer about which of the two authoring routes the claimant came down, and deriving that
## by inspecting a family's source would be a guess.
##
## `EventForgeLiftExample.entry` stamps ORIGIN_EXAMPLE on everything it derives (a built-in family
## written by example, a pack's `@ace_lift_example` spelling, a workbench draft). Everything else is
## ORIGIN_HAND by omission, which is what `origin_of` answers with.
const ORIGIN_KEY: String = "origin"
const ORIGIN_EXAMPLE: String = "example"
const ORIGIN_HAND: String = "hand"

## The key a REFUSED entry carries instead of a table. A builder that derives an entry from something
## (an example, a descriptor, a word map) and cannot do it mechanically says so here rather than
## guessing, and the validator turns that sentence into a failing suite naming the entry. An entry
## that refuses is never silently dropped: a table short of one spelling looks exactly like a table
## that was never asked for it.
const REFUSAL_KEY: String = "error"

## A shape's slots, as the emitter itself reads them - the plain `{name}`, the optional prefix
## `{name.}` and the optional comma `{,name}`. Compiled from the same three shapes ActionCodegen
## compiles, so a slot the emitter would fill and the validator would not see cannot exist.
const SLOT_PATTERN: String = "\\{(?:,?)\\s*(?<name>[A-Za-z_][A-Za-z0-9_]*)(?:\\.?)\\}"

## The provider an entry belongs to unless it says otherwise. Every builtin family is Core.
const DEFAULT_PROVIDER: String = "Core"

## The node spellings a row can address a node by, and the wider set that adds the bare variable a
## node was held in. Both live in the capture grammar beside the receiver fragment that spells them
## (`EventForgeLiftGrammar`); they are named here too because every node-scoped family already
## reaches for them through this class, and an ace_id is not the only thing a table author has
## learned by heart.
const NODE_PATHS: String = EventForgeLiftGrammar.NODE_PATHS
const NODE_REFERENCE: String = EventForgeLiftGrammar.NODE_REFERENCE

## One compiled RegEx per pattern for the life of the session: these run on every statement of every
## opened file, and recompiling per line was the entire cost of the hand-written matchers.
static var _compiled: Dictionary = {}


## The row one statement means, or {} when no entry claims it. `line` is a single statement, already
## dedented. Entries are tried IN ORDER and the first match wins, so a table puts its specific
## spellings above its general ones (`rpc_id(1, …)` before `rpc_id(<peer>, …)`).
##
## Returns {entry_id, ace_id, provider, params, template}: `params` is what the row shows, `template`
## the spelling to bake onto it so emission writes the author's bytes back.
##
## AN ENTRY WITH NO TABLE ON IT NEVER MATCHES. A refusal carries its sentence instead of a pattern,
## and the empty string is a pattern that matches every line ever written - so one malformed spelling
## in one installed pack would otherwise claim every statement in every opened file, and hand each
## one back under an ace_id no registry has heard of. The refusal is caught here rather than by each
## caller in turn, because `entries()` is walked off disk at run time by callers that have no
## validator between them and the match.
static func match_line(entries: Array, line: String) -> Dictionary:
	var text: String = line.strip_edges()
	if text.is_empty():
		return {}
	for entry: Dictionary in entries:
		if entry.has(REFUSAL_KEY):
			continue
		var pattern: String = str(entry.get("pattern", ""))
		if pattern.is_empty():
			continue
		var regex: RegEx = _regex(pattern)
		if regex == null:
			continue
		var hit: RegExMatch = regex.search(text)
		if hit == null:
			continue
		var guard: Variant = entry.get("guard", null)
		if guard is Callable and not (guard as Callable).call(_captures(hit)):
			continue
		var params: Dictionary = _params_of(entry, hit)
		return {
			"entry_id": str(entry.get("id", "")),
			"ace_id": str(entry.get("ace_id", "")),
			"provider": str(entry.get("provider", DEFAULT_PROVIDER)),
			"params": params,
			"template": _template_of(entry, hit, text, params)
		}
	return {}


## Every problem with a table, as sentences - empty when it is sound. Run by the harness over every
## family, so a malformed entry fails the suite instead of quietly never matching.
##
## Every entry, old and new, is asked the same five questions: does its pattern anchor to the whole
## statement, is every group in it named, is every value the shape shows backed by a capture and every
## capture the row shows answered by the shape, and is its fixture line its own rather than one an
## earlier entry in the same family already claims. A table author only ever gets one of those wrong
## once, because the answer arrives as a failing suite naming the entry rather than as a spelling that
## quietly never lifts.
static func validate(entries: Array) -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	var seen: Dictionary = {}
	var fixture_lines: Dictionary = {}
	for entry: Variant in entries:
		if not (entry is Dictionary):
			problems.append("an entry is not a Dictionary")
			continue
		var table_entry: Dictionary = entry
		var id: String = str(table_entry.get("id", ""))
		var named: String = id if not id.is_empty() else "(unnamed entry)"
		if table_entry.has(REFUSAL_KEY):
			problems.append("%s: refused - %s" % [named, str(table_entry[REFUSAL_KEY])])
			continue
		for key: String in REQUIRED_KEYS:
			if not table_entry.has(key):
				problems.append("%s: no %s" % [named, key])
		if id.is_empty():
			continue
		if seen.has(id):
			problems.append("%s: two entries share this id" % id)
		seen[id] = true
		for key: String in table_entry.keys():
			if not (REQUIRED_KEYS.has(key) or OPTIONAL_KEYS.has(key)):
				problems.append("%s: unknown key %s" % [id, key])
		problems.append_array(_validate_pattern(table_entry, id))
		problems.append_array(_validate_slots(table_entry, id))
		problems.append_array(_validate_fixture_line(table_entry, id, fixture_lines))
	return problems


## The line an entry writes for itself: its own canonical shape filled with its own sample values,
## through the real emitter. This is the fixture every entry is tested against, and it is generated
## rather than written down precisely so that an entry cannot exist untested.
static func fixture_line(entry: Dictionary) -> String:
	return ActionCodegen._apply_template(str(entry.get("shape", "")),
		entry.get("slots", {}) as Dictionary)


## The round trip, as sentences - empty when every entry keeps its promise. Each entry generates its
## own fixture line, the whole table is asked what that line means, and the row that comes back is
## emitted again: the id, the row, the values, the stored spelling and finally the BYTES have to be
## the ones it started from. `validate` asks whether a table is well formed; this asks whether it
## works, which is the question a pack's shipped spellings have to answer before they ship
## (EventForgePackSpellings) and the one tests/lift_table_test.gd asks of every built-in family.
static func round_trip_problems(entries: Array) -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	for entry: Variant in entries:
		if not (entry is Dictionary):
			continue
		var table_entry: Dictionary = entry
		if table_entry.has(REFUSAL_KEY):
			continue  # a refusal is already a problem, said by validate; it has no shape to test
		var id: String = str(table_entry.get("id", ""))
		var line: String = fixture_line(table_entry)
		var hit: Dictionary = match_line(entries, line)
		if str(hit.get("entry_id", "")) != id:
			var claimant: String = str(hit.get("entry_id", ""))
			problems.append("%s: its own spelling (%s) is claimed by %s"\
				% [id, line, claimant if not claimant.is_empty() else "nothing"])
			continue
		if str(hit.get("ace_id", "")) != str(table_entry.get("ace_id", "")):
			problems.append("%s: claims its line as %s, not %s"\
				% [id, str(hit.get("ace_id", "")), str(table_entry.get("ace_id", ""))])
		if hit.get("params", {}) != expected_params(table_entry):
			problems.append("%s: reads %s off its line, not %s"\
				% [id, str(hit.get("params", {})), str(expected_params(table_entry))])
		var re_emitted: String = emit_row(str(hit.get("template", "")), hit.get("params", {}),
			str(hit.get("provider", DEFAULT_PROVIDER)), str(hit.get("ace_id", "")))
		if re_emitted != line:
			problems.append("%s: re-emits %s, not %s" % [id, re_emitted, line])
	return problems


## One matched row's line, through the compiler's own emitter rather than a copy of the substitution -
## a re-emission the table wrote with its own `replace()` would agree with itself and prove nothing.
static func emit_row(template: String, params: Dictionary, provider: String, ace_id: String) -> String:
	var action: ACEAction = ACEAction.new()
	action.provider_id = provider
	action.ace_id = ace_id
	action.codegen_template = template
	action.params = params.duplicate()
	return ActionCodegen.generate_action(action)


## The parameter names an entry pulls out of a line: its captures, plus any value the ROW carries
## that the LINE does not say (`args` is empty in `rpc("ping")`, and the row still has the field).
static func param_names(entry: Dictionary) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for name: Variant in entry.get("params", PackedStringArray()):
		names.append(str(name))
	return names


## What the harness expects a generated fixture to read as: the sample values, plus the defaults for
## the params the shape has no slot for.
static func expected_params(entry: Dictionary) -> Dictionary:
	var expected: Dictionary = (entry.get("defaults", {}) as Dictionary).duplicate()
	expected.merge(entry.get("slots", {}) as Dictionary, true)
	return expected


## How one entry was authored - ORIGIN_EXAMPLE for an entry the by-example builder derived,
## ORIGIN_HAND for one somebody wrote the pattern of. Never blank, so a caller showing provenance
## never has to decide what an unstamped entry means.
static func origin_of(entry: Dictionary) -> String:
	var stamped: String = str(entry.get(ORIGIN_KEY, ""))
	return stamped if not stamped.is_empty() else ORIGIN_HAND


## Every family table in the folder, as {script_path: entries}. Found by scanning for the static, so
## a new family is covered by the harness on the strength of existing.
static func families() -> Dictionary:
	var found: Dictionary = {}
	for path: String in _family_paths():
		var script: GDScript = load(path)
		if script == null or not script.has_method(ENTRIES_METHOD):
			continue
		found[path] = script.call(ENTRIES_METHOD)
	return found


## The family script at a path, for the harness's fixture-context call. Null when there is none.
static func family_script(path: String) -> GDScript:
	var script: GDScript = load(path)
	return script if script != null and script.has_method(ENTRIES_METHOD) else null


# ── the pieces ──────────────────────────────────────────────────────────────────


## The row's values: one per param capture that took part. A capture that did not (an optional group
## the line had nothing for) contributes nothing, and the entry's default fills it in.
static func _params_of(entry: Dictionary, hit: RegExMatch) -> Dictionary:
	var params: Dictionary = (entry.get("defaults", {}) as Dictionary).duplicate()
	for name: String in param_names(entry):
		if hit.get_start(name) >= 0:
			params[name] = hit.get_string(name)
	return params


## The receiver fragment's two halves, as the families already ask this class for them: the shape
## slot `{target.}` and the optional capture that matches it. Both are the capture grammar's, and are
## answered through it rather than beside it, so widening one can never leave the other behind.
static func optional_prefix_slot(name: String) -> String:
	return EventForgeLiftGrammar.optional_prefix_slot(name)


static func receiver(name: String = "target", spellings: String = NODE_REFERENCE) -> String:
	return EventForgeLiftGrammar.receiver(name, spellings)


## True when a shape answers for a param - under either spelling, the plain `{name}` or the
## optional prefix `{name.}`. The one question the validator and the splice below both ask, so a
## shape written in the receiver idiom cannot be sound to one of them and unknown to the other.
static func shape_answers(shape: String, name: String) -> bool:
	return EventForgeLiftGrammar.shape_answers(shape, name)


## The matched line with every param capture spliced out for its slot. Spliced from the RIGHT so an
## earlier replacement cannot move a later span, which is what makes this the exact inverse of
## substituting the params back in. A param the entry's shape spells as the optional prefix takes
## the dot AFTER it into the slot, because that dot is part of the idiom rather than part of the
## line: the row a lift hands back must be the row the picker would have authored, and the picker's
## is `{target.}energy = {value}`.
##
## THE CANONICAL SPELLING WINS. When the author's own line IS what the shape emits with these values
## in it, the SHAPE is what gets stored rather than the splice of it. The two agree on the bytes
## either way - that is what the comparison asks - so this changes nothing about the round trip and
## everything about the row afterwards: a splice can only reinstate a slot the line had text for, and
## a spelling that leaves an optional receiver out (`energy = 1.2`) or repeats it
## (`$World.environment = $World.environment.duplicate()`) would otherwise come back carrying a
## template with no `{target.}` in it, or with one - and then changing "On node" on that row would
## write a line the author never asked for.
static func _template_of(entry: Dictionary, hit: RegExMatch, text: String, params: Dictionary) -> String:
	var shape: String = str(entry.get("shape", ""))
	if ActionCodegen._apply_template(shape, params) == text:
		return shape
	var spans: Array = []
	for name: String in param_names(entry):
		if hit.get_start(name) < 0:
			continue
		var prefix: bool = shape.contains(optional_prefix_slot(name)) \
			and text.substr(hit.get_end(name), 1) == "."
		spans.append([hit.get_start(name), hit.get_end(name) + (1 if prefix else 0), name, prefix])
	spans.sort_custom(func(left: Array, right: Array) -> bool: return int(left[0]) > int(right[0]))
	var template: String = text
	for span: Array in spans:
		var slot: String = optional_prefix_slot(str(span[2])) if bool(span[3]) else "{%s}" % str(span[2])
		template = template.substr(0, int(span[0])) + slot + template.substr(int(span[1]))
	return template


## Every named capture of one match, for a guard to read.
static func _captures(hit: RegExMatch) -> Dictionary:
	var captures: Dictionary = {}
	for name: Variant in hit.names.keys():
		captures[str(name)] = hit.get_string(str(name))
	return captures


static func _validate_pattern(entry: Dictionary, id: String) -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	var pattern: String = str(entry.get("pattern", ""))
	if pattern.is_empty():
		return problems
	var regex: RegEx = _regex(pattern)
	if regex == null or not regex.is_valid():
		problems.append("%s: the pattern does not compile" % id)
		return problems
	if not (pattern.begins_with("^") and pattern.ends_with("$")):
		problems.append("%s: the pattern must anchor to the whole statement (^…$)" % id)
	# A group with no name is a span nothing can read: the splice that stores the author's spelling
	# works from NAMED captures, so an unnamed one costs the same to match and can never become a
	# value. Write `(?:...)` for scenery and `(?<name>...)` for anything the row shows.
	if _has_an_unnamed_group(pattern):
		problems.append("%s: every group in the pattern must be named or non-capturing" % id)
	# A param is a NAMED capture by definition - it is the span the template splices out. The pattern
	# is read as text here rather than matched against the shape, because the shape is a template with
	# `{slots}` in it and no pattern of a real spelling would match one.
	for name: String in param_names(entry):
		if not pattern.contains("(?<%s>" % name):
			problems.append("%s: %s is a param with no capture group of that name" % [id, name])
	var guard: Variant = entry.get("guard", null)
	if entry.has("guard") and not (guard is Callable and (guard as Callable).is_valid()):
		problems.append("%s: the guard is not a callable" % id)
	return problems


## The shape is the canonical spelling and the slots are what a fixture fills it with, so between
## them every param must be answerable. An entry that cannot generate its own fixture line is an
## entry nothing can test.
static func _validate_slots(entry: Dictionary, id: String) -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	var shape: String = str(entry.get("shape", ""))
	var slots: Dictionary = entry.get("slots", {})
	var params: PackedStringArray = param_names(entry)
	for name: String in slots.keys():
		if not shape_answers(shape, name):
			problems.append("%s: the shape has no {%s} for the sample value" % [id, name])
	for name: String in params:
		if shape_answers(shape, name) and not slots.has(name):
			problems.append("%s: no sample value for {%s}" % [id, name])
		elif not shape_answers(shape, name) and not (entry.get("defaults", {}) as Dictionary).has(name):
			problems.append("%s: %s is neither in the shape nor given a default" % [id, name])
	# And the other way round. A slot the shape spells that no capture answers for is a `{name}` the
	# emitter would write into somebody's file verbatim, which is the one failure mode of this whole
	# mechanism that a byte gate cannot see: the entry never matched, so nothing ever generated it.
	for name: String in shape_slot_names(shape):
		if not params.has(name):
			problems.append("%s: the shape's {%s} is backed by no capture" % [id, name])
	return problems


## Every name a shape has a slot for, in the order it spells them, without repeats. Read with the
## emitter's own three slot spellings, so this and the fill cannot disagree about what a slot is.
static func shape_slot_names(shape: String) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	var regex: RegEx = _regex(SLOT_PATTERN)
	if regex == null:
		return names
	for hit: RegExMatch in regex.search_all(shape):
		var name: String = hit.get_string("name")
		if not names.has(name):
			names.append(name)
	return names


## Two entries in one family must not answer to the same generated line. Where they do, the harness
## would fail the second one with "its own spelling is claimed by it" and leave a table author
## looking at a regex; said here it names both entries and the line they are fighting over.
static func _validate_fixture_line(entry: Dictionary, id: String, seen: Dictionary) -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	var line: String = fixture_line(entry)
	if seen.has(line):
		problems.append("%s: its fixture line is already %s's" % [id, str(seen[line])])
		return problems
	seen[line] = id
	return problems


## True when a pattern has a capturing group with no name. Read as text, tracking the two places a
## bracket means something else: after a backslash it is a bracket the author wants matched, and
## inside a character class it is one of the characters allowed there.
static func _has_an_unnamed_group(pattern: String) -> bool:
	var index: int = 0
	var in_class: bool = false
	while index < pattern.length():
		var character: String = pattern[index]
		if character == "\\":
			index += 2
			continue
		if in_class:
			in_class = character != "]"
			index += 1
			continue
		if character == "[":
			in_class = true
			index += 1
			continue
		if character == "(" and pattern.substr(index + 1, 1) != "?":
			return true
		index += 1
	return false


## Every `.gd` in the family folder, sorted, so discovery is the same on every machine.
static func _family_paths() -> PackedStringArray:
	var paths: PackedStringArray = PackedStringArray()
	var dir: DirAccess = DirAccess.open(FAMILY_DIR)
	if dir == null:
		return paths
	for file_name: String in dir.get_files():
		var name: String = file_name.trim_suffix(".remap")
		if name.ends_with(".gd"):
			paths.append(FAMILY_DIR + name)
	paths.sort()
	return paths


static func _regex(pattern: String) -> RegEx:
	if not _compiled.has(pattern):
		_compiled[pattern] = RegEx.create_from_string(pattern)
	return _compiled[pattern]
