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
const OPTIONAL_KEYS: Array[String] = ["provider", "params", "defaults", "guard"]

## The provider an entry belongs to unless it says otherwise. Every builtin family is Core.
const DEFAULT_PROVIDER: String = "Core"

## One compiled RegEx per pattern for the life of the session: these run on every statement of every
## opened file, and recompiling per line was the entire cost of the hand-written matchers.
static var _compiled: Dictionary = {}


## The row one statement means, or {} when no entry claims it. `line` is a single statement, already
## dedented. Entries are tried IN ORDER and the first match wins, so a table puts its specific
## spellings above its general ones (`rpc_id(1, …)` before `rpc_id(<peer>, …)`).
##
## Returns {entry_id, ace_id, provider, params, template}: `params` is what the row shows, `template`
## the spelling to bake onto it so emission writes the author's bytes back.
static func match_line(entries: Array, line: String) -> Dictionary:
	var text: String = line.strip_edges()
	if text.is_empty():
		return {}
	for entry: Dictionary in entries:
		var regex: RegEx = _regex(str(entry.get("pattern", "")))
		if regex == null:
			continue
		var hit: RegExMatch = regex.search(text)
		if hit == null:
			continue
		var guard: Variant = entry.get("guard", null)
		if guard is Callable and not (guard as Callable).call(_captures(hit)):
			continue
		return {
			"entry_id": str(entry.get("id", "")),
			"ace_id": str(entry.get("ace_id", "")),
			"provider": str(entry.get("provider", DEFAULT_PROVIDER)),
			"params": _params_of(entry, hit),
			"template": _template_of(entry, hit, text)
		}
	return {}


## Every problem with a table, as sentences - empty when it is sound. Run by the harness over every
## family, so a malformed entry fails the suite instead of quietly never matching.
static func validate(entries: Array) -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	var seen: Dictionary = {}
	for entry: Variant in entries:
		if not (entry is Dictionary):
			problems.append("an entry is not a Dictionary")
			continue
		var table_entry: Dictionary = entry
		var id: String = str(table_entry.get("id", ""))
		for key: String in REQUIRED_KEYS:
			if not table_entry.has(key):
				problems.append("%s: no %s" % [id if not id.is_empty() else "(unnamed entry)", key])
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
	return problems


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


## The matched line with every param capture spliced out for its slot. Spliced from the RIGHT so an
## earlier replacement cannot move a later span, which is what makes this the exact inverse of
## substituting the params back in.
static func _template_of(entry: Dictionary, hit: RegExMatch, text: String) -> String:
	var spans: Array = []
	for name: String in param_names(entry):
		if hit.get_start(name) >= 0:
			spans.append([hit.get_start(name), hit.get_end(name), name])
	spans.sort_custom(func(left: Array, right: Array) -> bool: return int(left[0]) > int(right[0]))
	var template: String = text
	for span: Array in spans:
		template = template.substr(0, int(span[0])) + "{%s}" % str(span[2]) + template.substr(int(span[1]))
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
	for name: String in slots.keys():
		if not shape.contains("{%s}" % name):
			problems.append("%s: the shape has no {%s} for the sample value" % [id, name])
	for name: String in param_names(entry):
		if shape.contains("{%s}" % name) and not slots.has(name):
			problems.append("%s: no sample value for {%s}" % [id, name])
		elif not shape.contains("{%s}" % name) and not (entry.get("defaults", {}) as Dictionary).has(name):
			problems.append("%s: %s is neither in the shape nor given a default" % [id, name])
	return problems


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
