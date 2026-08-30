# EventForge - PACK-TAUGHT SPELLINGS: a pack teaches the reader the lines its verbs are written as.
#
# A pack ships verbs. Somebody who used that pack before the sheet existed wrote those verbs by hand,
# and their file says `flicker.start_flickering()` where the pack's own row says
# `$LightFlickerBehavior.start_flickering(0.0)`. Opened today, the hand-written line still reads - as
# the plainest reading there is, "call start_flickering on flicker" - because the generic reading
# claims every method call. That reading is honest and it is the floor, not the ceiling: the pack knows
# the sentence it would rather that line read as, and until now had no way to say so.
#
# So a verb may carry its spellings BESIDE it, as annotations in its own block:
#
#     ## @ace_action
#     ## @ace_name("Start Flickering")
#     ## @ace_lift_example("[[target|receiver: $LightFlickerBehavior]].start_flickering([[after_seconds|argument: 0.5]])")
#     func start_flickering(after_seconds: float = 0.0) -> void:
#
# The text inside is a marked EXAMPLE (EventForgeLiftExample) - the line as a person writes it, with
# the value spans marked - so a pack author never writes a regex. What comes back is an ordinary lift
# entry (EventForgeLiftTable), which is why these are held to the same gate the built-in tables are:
# the harness generates a fixture line from the entry's own canonical shape, asks the engine what it
# means, and re-emits it byte for byte. An entry that cannot re-emit its own fixture never ships.
#
# WHAT THIS CHANGES AND WHAT IT DOES NOT. A pack spelling upgrades the ROW - its provider, its verb,
# its parameter names, the sentence a reader sees. It never changes a single byte: the line the author
# wrote is baked onto the row as its template, so saving writes their file back exactly. That is the
# whole point of landing a table late - same bytes, better words.
#
# THREE RULES, ENFORCED RATHER THAN DOCUMENTED:
#   1. A pack may not SHADOW a built-in spelling. Where a pack's own fixture line is already claimed by
#      a table in the importer folder, that is an error at pack-build time naming both, because the
#      pack would be quietly re-labelling a row the engine already had a better name for. (The generic
#      reading is not a claim in this sense - it is the floor every unclaimed call lands on, and
#      upgrading it is exactly what a pack spelling is for.)
#   2. Two packs that answer to the same line are a NEAR-COLLISION, and the reader is told rather than
#      left guessing: the Doctor names both and states the rule, which is first claimant wins, in the
#      sorted pack order this file walks so the answer is the same on every machine.
#   3. An example this cannot build is a REFUSAL carrying its sentence, never a silent nothing. A verb
#      that is not an action refuses too: an example teaches the spelling of a VERB today, and a
#      condition or expression annotated with one would otherwise look wired and do nothing.
@tool
class_name EventForgePackSpellings
extends RefCounted

const Example := preload("res://addons/eventforge/importer/lift_example.gd")

## Where packs live. Walked recursively and sorted, so the order two packs are asked in - which is
## what "first claimant wins" resolves to - is the same on every machine.
const PACK_DIR: String = "res://eventsheet_addons/"

## The annotation a verb carries its spellings in, one per line, in its own `##` block.
const ANNOTATION: String = "@ace_lift_example"

## How a method's ACE id is spelled. The generator builds a method's id as `method:<name>`
## (EventSheetACEGenerator), and a spelling that named a row nothing published would match a line and
## then hand back an id the picker has never heard of - so this mirrors that shape, and
## `tests/pack_spellings_test.gd` pins the two against a real pack rather than trusting the mirror.
const METHOD_ACE_PREFIX: String = "method:"

## The annotations that say what KIND of verb a block publishes. Only an action may carry an example
## today; the other two refuse, out loud, rather than annotating something that never matches.
const ACTION_ANNOTATION: String = "@ace_action"
const NON_ACTION_ANNOTATIONS: Array[String] = ["@ace_condition", "@ace_expression", "@ace_trigger"]

## The parsed tables for the session, keyed by pack script path, and the flat list in walk order.
## Built once: a pack is compiler output that changes when somebody rebuilds it, and the ACE
## definition cache beside this one makes the same trade. `reset_cache_for_tests` is how a suite (or a
## rebuild) asks for them again.
static var _tables: Dictionary = {}
static var _entries: Array = []
static var _built: bool = false


## Every pack's entries, in the order packs are walked. This is the table the lifter matches against,
## so its order IS the first-claimant-wins rule.
static func entries() -> Array:
	_ensure_built()
	return _entries


## The entries per pack script path, for the gates and the Doctor - which need to name the pack a
## spelling came from, not only the spelling.
static func tables() -> Dictionary:
	_ensure_built()
	return _tables.duplicate(true)


## The row one statement means to some pack, or {} when no pack claims it. The same call the built-in
## spelling families answer, so the lifter asks this exactly as it asks them.
static func match_line(line: String) -> Dictionary:
	return EventForgeLiftTable.match_line(entries(), line)


## Every problem with the shipped pack spellings, as sentences - empty when they are sound. Three
## kinds, in one list because a pack author fixes them in one place: an entry that refused to build,
## an entry that is malformed or cannot re-emit its own fixture, and an entry that shadows a built-in.
## Run by the pack gate (tools/audit_addons.gd) and by tests/pack_spellings_test.gd.
static func problems() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var built: Dictionary = tables()
	for path: String in _sorted_keys(built):
		found.append_array(problems_for(path, built[path]))
	return found


## The same three questions asked of ONE table, named by the path it came from. Public so a pack
## author's tool - and the suite - can ask them of a table that is not installed yet.
static func problems_for(path: String, pack_entries: Array) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var builtin: Dictionary = EventForgeLiftTable.families()
	for problem: String in EventForgeLiftTable.validate(pack_entries):
		found.append("%s: %s" % [path.get_file(), problem])
	for problem: String in EventForgeLiftTable.round_trip_problems(pack_entries):
		found.append("%s: %s" % [path.get_file(), problem])
	for entry: Dictionary in pack_entries:
		var shadowed: String = _shadowing_family(builtin, entry)
		if not shadowed.is_empty():
			found.append("%s: %s spells a line %s already claims - a pack may not shadow a"\
				% [path.get_file(), str(entry.get("id", "")), shadowed.get_file()]\
				+ " built-in spelling")
	return found


## Near-collisions, as sentences - two packs whose spellings answer to the same line. Advisory, not an
## error: the answer is well defined (the pack walked first wins) and both spellings may be perfectly
## reasonable. Said out loud so the pack that lost finds out here rather than from a row that reads as
## somebody else's verb.
static func advisories() -> PackedStringArray:
	return advisories_for(tables())


## The same question asked of a given set of tables ({path: entries}), so the suite can put two
## packs in one room without installing either.
static func advisories_for(pack_tables: Dictionary) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var paths: PackedStringArray = _sorted_keys(pack_tables)
	for index: int in range(paths.size()):
		var path: String = paths[index]
		for entry: Dictionary in pack_tables[path]:
			var line: String = _fixture_line(entry)
			if line.is_empty():
				continue
			for other_index: int in range(paths.size()):
				if other_index == index:
					continue
				var other: String = paths[other_index]
				var hit: Dictionary = EventForgeLiftTable.match_line(pack_tables[other], line)
				if hit.is_empty():
					continue
				# Said once per pair, by the pack that LOSES, which is the one whose reader is
				# surprised: the earlier pack in the walk claims the line.
				if other_index > index:
					continue
				found.append("%s: %s reads as %s's %s - where two packs spell one line, the first"\
					% [path.get_file(), str(entry.get("id", "")), other.get_file(),
						str(hit.get("entry_id", ""))]\
					+ " pack in folder order claims it")
	return found


## Drops the parsed tables. The suite calls this before pinning cold state and after writing a pack,
## because the tables are read off disk once per session.
static func reset_cache_for_tests() -> void:
	_tables = {}
	_entries = []
	_built = false


## Answers with these tables instead of the installed packs', until the next reset. The one caller
## that needs it is a reader asking what a file looked like BEFORE a pack taught its spellings - the
## suite pinning that the same bytes read differently, and the preview harness showing it. Nothing in
## the editor sets this; `reset_cache_for_tests` puts the real packs back.
static func override_tables_for_tests(pack_tables: Dictionary) -> void:
	_tables = pack_tables.duplicate(true)
	_entries = []
	for path: String in _sorted_keys(_tables):
		_entries.append_array(_tables[path])
	_built = true


## The entries one pack SOURCE teaches, without touching the disk - the parser itself, so a test (or a
## pack author's tool) can ask what a file would publish before it ships. `path` only names the file in
## entry ids; nothing is read from it.
static func entries_in_source(source: String, path: String) -> Array:
	var found: Array = []
	var provider: String = _declared_class_name(source, path)
	var pending: PackedStringArray = PackedStringArray()
	var kind_annotations: PackedStringArray = PackedStringArray()
	for raw_line: String in source.split("\n"):
		var text: String = raw_line.strip_edges()
		if text.begins_with("func ") or text.begins_with("static func "):
			if not pending.is_empty():
				found.append_array(_entries_for(pending, kind_annotations, provider,
					_function_name(text)))
			pending = PackedStringArray()
			kind_annotations = PackedStringArray()
			continue
		var annotation: String = _annotation_argument(text)
		if not annotation.is_empty():
			pending.append(annotation)
			continue
		if text.begins_with("#"):
			for name: String in _kind_annotations_in(text):
				kind_annotations.append(name)
			continue
		# Anything else ends the block: an example is only ever read as belonging to the verb
		# DIRECTLY under it, so a stray annotation far from a `func` is dropped here and reported by
		# the loose-example check below rather than attaching itself to the next verb it finds.
		if not pending.is_empty():
			found.append(_loose(pending[0], provider, path))
		pending = PackedStringArray()
		kind_annotations = PackedStringArray()
	if not pending.is_empty():
		found.append(_loose(pending[0], provider, path))
	return found


# ── the pieces ──────────────────────────────────────────────────────────────────


static func _ensure_built() -> void:
	if _built:
		return
	_built = true
	_tables = {}
	_entries = []
	for path: String in _pack_scripts():
		var source: String = FileAccess.get_file_as_string(path)
		if not source.contains(ANNOTATION):
			continue
		var found: Array = entries_in_source(source, path)
		if found.is_empty():
			continue
		_tables[path] = found
		_entries.append_array(found)


## Every `.gd` under the pack folder, sorted, so discovery is the same on every machine.
static func _pack_scripts() -> PackedStringArray:
	var paths: PackedStringArray = PackedStringArray()
	_collect(PACK_DIR, paths)
	paths.sort()
	return paths


static func _collect(dir_path: String, into: PackedStringArray) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	var folders: PackedStringArray = PackedStringArray()
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while not entry.is_empty():
		if dir.current_is_dir():
			if not entry.begins_with("."):
				folders.append(dir_path.path_join(entry))
		else:
			var name: String = entry.trim_suffix(".remap")
			if name.ends_with(".gd"):
				into.append(dir_path.path_join(name))
		entry = dir.get_next()
	dir.list_dir_end()
	folders.sort()
	for folder: String in folders:
		_collect(folder, into)


## The entries one verb's annotation block teaches. One per example, numbered in the order they are
## written so two spellings of one verb never share an id.
static func _entries_for(examples: PackedStringArray, kinds: PackedStringArray, provider: String,
		function_name: String) -> Array:
	var found: Array = []
	for index: int in range(examples.size()):
		var id: String = "%s.%s#%d" % [provider, function_name, index + 1]
		var ace_id: String = METHOD_ACE_PREFIX + function_name
		var refusal: String = _kind_refusal(kinds)
		if function_name.is_empty():
			refusal = "the example is not above a function this can name"
		if not refusal.is_empty():
			found.append({"id": id, "ace_id": ace_id, EventForgeLiftTable.REFUSAL_KEY: refusal})
			continue
		found.append(Example.entry(id, ace_id, examples[index], {"provider": provider}))
	return found


## Why this block may not carry an example, or "" when it may. A verb with no kind annotation at all
## is an action (that is what the generator makes of a `-> void` method), so silence is consent here;
## a verb that says it is something else is refused by name.
static func _kind_refusal(kinds: PackedStringArray) -> String:
	for name: String in NON_ACTION_ANNOTATIONS:
		if kinds.has(name):
			return "a lift example teaches the spelling of an action, and this verb is %s" % name
	return ""


## An example with no verb under it, as the refusal it is. A pack author who wrote one in the wrong
## place gets a failing gate naming the example, rather than a spelling that never matches.
static func _loose(example: String, provider: String, path: String) -> Dictionary:
	return {
		"id": "%s.%s" % [provider, path.get_file().get_basename()],
		"ace_id": "",
		EventForgeLiftTable.REFUSAL_KEY: "an example sits above no function: %s" % example
	}


## The text inside `## @ace_lift_example("…")`, or "" when this line is not one. Read the way every
## other `@ace_*` line in a pack is read: the annotation, its parentheses, and one quoted argument.
static func _annotation_argument(text: String) -> String:
	var head: String = "## %s(\"" % ANNOTATION
	if not (text.begins_with(head) and text.ends_with("\")")):
		return ""
	return text.substr(head.length(), text.length() - head.length() - 2)


## The kind annotations named on one comment line (`## @ace_action` and friends), for the block scan.
static func _kind_annotations_in(text: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var stripped: String = text.trim_prefix("#").trim_prefix("#").strip_edges()
	if stripped == ACTION_ANNOTATION:
		found.append(ACTION_ANNOTATION)
	for name: String in NON_ACTION_ANNOTATIONS:
		if stripped == name:
			found.append(name)
	return found


## The function a `func …` line declares, or "" when the line is not shaped like one.
static func _function_name(text: String) -> String:
	var head: String = text.trim_prefix("static ").trim_prefix("func ").strip_edges()
	var open: int = head.find("(")
	if open <= 0:
		return ""
	var name: String = head.substr(0, open)
	return name if RegEx.create_from_string(Example.NAME_PATTERN).search(name) != null else ""


## The provider a pack publishes under: its declared `class_name`, falling back to the file's own name
## exactly as the zero-config scanner does when a script declares none.
static func _declared_class_name(source: String, path: String) -> String:
	for raw_line: String in source.split("\n"):
		var text: String = raw_line.strip_edges()
		if text.begins_with("class_name "):
			return text.substr("class_name ".length()).split(" ")[0].strip_edges()
	return path.get_file().get_basename()


## The built-in family that already claims an entry's own fixture line, or "" when none does.
static func _shadowing_family(builtin: Dictionary, entry: Dictionary) -> String:
	var line: String = _fixture_line(entry)
	if line.is_empty():
		return ""
	for path: String in _sorted_keys(builtin):
		if not EventForgeLiftTable.match_line(builtin[path], line).is_empty():
			return path
	return ""


## The line an entry generates for itself: its canonical shape filled with its own sample values,
## through the real emitter. Empty for a refused entry, which has no shape to fill.
static func _fixture_line(entry: Dictionary) -> String:
	if entry.has(EventForgeLiftTable.REFUSAL_KEY):
		return ""
	return EventForgeLiftTable.fixture_line(entry)


static func _sorted_keys(dictionary: Dictionary) -> PackedStringArray:
	var keys: PackedStringArray = PackedStringArray()
	for key: Variant in dictionary.keys():
		keys.append(str(key))
	keys.sort()
	return keys
