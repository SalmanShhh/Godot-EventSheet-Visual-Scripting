# EventForge - THE VOCABULARY AS ONE SORTED TEXT.
#
# Every verb the project publishes, one line each, in a form two machines produce identically and a
# reader can diff with any tool: `key, type, category, params, param_types, param_defaults,
# successor, template`, tab separated, sorted by key. Nothing else - no counts, no timestamps, no
# machine paths, no ordering that depends on which module happened to register first.
#
# WHY A TEXT RATHER THAN A REPORT. Two questions in this plugin are the same question underneath:
# "what does this pack's new version retire and add?" (the pack update dialog diffs the installed
# version's dump against the incoming one's) and "did this refactor change any verb's identity?"
# (a gate diffs the dump before against the dump after). Both are answered by comparing two of these
# texts line for line, so both get the same answer and neither needs a second reflection pass over
# the registry.
#
# THE LINE IS THE IDENTITY. A verb's key, its type, its shelf, the parameters it takes in order with
# the type and the DEFAULT each declares, the address it forwards to, and the line it writes. Those
# are what a sheet written against this verb depends on; anything else about a descriptor (its
# wording, its icon, its examples) may change without a single emitted byte changing, so it is
# deliberately not here.
#
# A DEFAULT IS NOT DECORATION, which is why it is on the line. It lands in every freshly picked row,
# and it decides whether a forwarding address has to answer that parameter at all - a verb whose
# default goes blank starts asking rows for a value nobody gave it. A dump that listed parameter
# names alone said "nothing changed" about a version that re-typed or re-defaulted every one of them.
#
# ESCAPING, ONCE. A template is usually several lines and may hold tabs, so every field escapes
# backslash, tab, carriage return and newline before it is joined. That keeps one verb on one line,
# which is what makes the diff a line diff.
#
# NOTHING HERE READS OR WRITES A SHEET. It reads the vocabulary and returns a string.
@tool
class_name EventForgeRegistryDump
extends RefCounted

## Bumped only when the LINE SHAPE changes. A diff between two dumps of different versions is
## refused rather than answered wrongly, so an old dump kept beside a project cannot quietly
## report every verb as changed.
##
## 2 added the two parameter-detail fields. Nothing keeps a dump on disk - both sides of every diff
## are written fresh from a live reflection - so the bump costs nobody a stored file.
const FORMAT_VERSION: int = 2

## The one line that is not a verb. Comment-led, so a diff can skip it without a special case.
const HEADER: String = "# eventsheets registry dump %d" % FORMAT_VERSION

## Between fields. A tab rather than a comma or a pipe because a template is full of both.
const SEPARATOR: String = "\t"

## The fields of a line, in order, named so a reader and a test spell them the same way.
const FIELDS: PackedStringArray = ["key", "type", "category", "params", "param_types",
	"param_defaults", "successor", "template"]


# ── Writing ───────────────────────────────────────────────────────────────────────────────────


## The whole vocabulary as one text. `catalog` is the `EventForgeSuccessors.catalog()` shape - the
## one place the built-in descriptors and the installed packs are already reduced to the same facts.
static func text(catalog: Dictionary) -> String:
	var keys: PackedStringArray = PackedStringArray()
	for key: Variant in catalog.keys():
		keys.append(str(key))
	keys.sort()
	var lines: PackedStringArray = PackedStringArray([HEADER])
	for key: String in keys:
		var entry: Variant = catalog[key]
		if entry is Dictionary:
			lines.append(line_for(key, entry))
	return "\n".join(lines) + "\n"


## One verb's line. Pure over its arguments, so a test pins the format without a registry.
static func line_for(key: String, entry: Dictionary) -> String:
	var params: PackedStringArray = PackedStringArray()
	var types: PackedStringArray = PackedStringArray()
	var defaults: PackedStringArray = PackedStringArray()
	var declared_types: Dictionary = entry.get("declared_types", {})
	var declared_defaults: Dictionary = entry.get("declared_defaults", {})
	for param: String in PackedStringArray(entry.get("params", PackedStringArray())):
		params.append(param)
		types.append("%s=%s" % [param, str(declared_types.get(param, ""))])
		defaults.append("%s=%s" % [param, str(declared_defaults.get(param, ""))])
	var successor: Dictionary = EventForgeSuccessors.normalize_map(entry.get("map", {}))
	var fields: PackedStringArray = PackedStringArray([
		_escape(key),
		type_name(int(entry.get("ace_type", ACEDefinition.ACEType.ACTION))),
		_escape(str(entry.get("category", ""))),
		_escape(",".join(params)),
		_escape(",".join(types)),
		_escape(",".join(defaults)),
		_escape(str(successor.get(EventForgeSuccessors.KEY_ID, ""))),
		_escape(str(entry.get("template", ""))),
	])
	return SEPARATOR.join(fields)


## An `ACEDefinition.ACEType` as the word the dump writes. Always that enum: `EventForgeSuccessors`
## normalizes a descriptor's own enum into it, so a dump never has to ask which of the two it holds.
static func type_name(ace_type: int) -> String:
	match ace_type:
		ACEDefinition.ACEType.CONDITION:
			return "condition"
		ACEDefinition.ACEType.EXPRESSION:
			return "expression"
		ACEDefinition.ACEType.TRIGGER:
			return "trigger"
		_:
			return "action"


# ── Reading ───────────────────────────────────────────────────────────────────────────────────


## A dump back as {key: {type, category, params, successor, template}}. Unreadable lines and the
## header are skipped rather than guessed at.
static func parse(dump_text: String) -> Dictionary:
	var out: Dictionary = {}
	for line: String in dump_text.split("\n"):
		if line.is_empty() or line.begins_with("#"):
			continue
		var fields: PackedStringArray = line.split(SEPARATOR)
		if fields.size() < FIELDS.size():
			continue
		out[_unescape(fields[0])] = {
			"type": fields[1],
			"category": _unescape(fields[2]),
			"params": _unescape(fields[3]),
			"param_types": _unescape(fields[4]),
			"param_defaults": _unescape(fields[5]),
			"successor": _unescape(fields[6]),
			"template": _unescape(fields[7]),
		}
	return out


## True when a dump was written by this format version - the one thing a diff checks before it
## compares anything, because a shape change would otherwise read as "every verb changed".
static func is_current_format(dump_text: String) -> bool:
	return dump_text.begins_with(HEADER)


# ── Diffing ───────────────────────────────────────────────────────────────────────────────────


## What moved between two dumps, as
## {"retired": [{key, successor, gone}], "added": [key], "changed": [{key, fields}], "readable": bool}
## - every list sorted by key.
##
## RETIRED means one of two things, and the row says which: the newer dump forwards this verb to a
## successor it did not forward to before (`gone` false - the verb is still there, still compiles,
## and now has an address), or the newer dump does not publish it at all (`gone` true - which is a
## frozen-contract break, and worth saying out loud before anybody takes the update).
##
## CHANGED lists the fields of a verb both sides publish that do not match, so a gate can tell "the
## template moved" from "the shelf moved".
static func diff(old_text: String, new_text: String) -> Dictionary:
	if not is_current_format(old_text) or not is_current_format(new_text):
		return {"retired": [], "added": [], "changed": [], "readable": false}
	var old_entries: Dictionary = parse(old_text)
	var new_entries: Dictionary = parse(new_text)
	var retired: Array[Dictionary] = []
	var added: PackedStringArray = PackedStringArray()
	var changed: Array[Dictionary] = []
	var old_keys: PackedStringArray = PackedStringArray()
	for key: Variant in old_entries.keys():
		old_keys.append(str(key))
	old_keys.sort()
	for key: String in old_keys:
		var before: Dictionary = old_entries[key]
		if not new_entries.has(key):
			retired.append({"key": key, "successor": "", "gone": true})
			continue
		var after: Dictionary = new_entries[key]
		var successor: String = str(after.get("successor", ""))
		if not successor.is_empty() and str(before.get("successor", "")).is_empty():
			retired.append({"key": key, "successor": successor, "gone": false})
		var moved: PackedStringArray = PackedStringArray()
		for field: String in FIELDS:
			if field == "key":
				continue
			if str(before.get(field, "")) != str(after.get(field, "")):
				moved.append(field)
		if not moved.is_empty():
			changed.append({"key": key, "fields": moved})
	var new_keys: PackedStringArray = PackedStringArray()
	for key: Variant in new_entries.keys():
		new_keys.append(str(key))
	new_keys.sort()
	for key: String in new_keys:
		if not old_entries.has(key):
			added.append(key)
	return {"retired": retired, "added": added, "changed": changed, "readable": true}


# ── One pack's own vocabulary ──────────────────────────────────────────────────────────────────


## The verbs ONE pack script publishes, catalog-shaped. This is how the update dialog gets a dump of
## a version that is not installed: the incoming file is written somewhere harmless and reflected
## here, exactly the way the live registry reflects an installed one.
##
## REFLECTING A PACK RUNS IT, and that is a property to know rather than a bug to hide: the script is
## loaded and instantiated, so its `_init` and any static initialiser execute. The live registry does
## exactly this for every installed pack, and the difference here is that an INCOMING version is one
## the reader has not accepted yet. Nothing of it reaches `res://` - the copy is written under
## `user://` and removed again - and the reader is told, in the dry run's own tooltip, that asking
## the question runs the file. An archive whose code you would not run is an archive not to open.
##
## The analyzer reads `## @ace_*` annotations off DISK, so `script_path` must be a real file - a
## GDScript built from a source string in memory carries no annotations at all and would dump a
## pack's verbs stripped of every forwarding address.
static func entries_of_script(script_path: String) -> Dictionary:
	var built: Dictionary = {}
	var script: Script = load(script_path) as Script
	if script == null or not script.can_instantiate():
		return built
	var instance: Object = script.new()
	if instance == null:
		return built
	var analyzer: EventSheetSemanticAnalyzer = EventSheetSemanticAnalyzer.new()
	analyzer.parse_source_metadata(script)
	var generator: EventSheetACEGenerator = EventSheetACEGenerator.new()
	for definition: ACEDefinition in generator.generate_from_object(instance):
		var entry: Dictionary = EventForgeSuccessors.entry_of(definition)
		if not entry.is_empty():
			built[str(entry["key"])] = entry
	if instance is Node:
		(instance as Node).free()
	return built


## The same, as the text a diff takes.
static func for_script(script_path: String) -> String:
	return text(entries_of_script(script_path))


# ── Escaping ──────────────────────────────────────────────────────────────────────────────────


static func _escape(value: String) -> String:
	return value.replace("\\", "\\\\").replace("\t", "\\t").replace("\r", "\\r").replace("\n", "\\n")


## The inverse, walked character by character so a literal `\\n` in a template (two characters a
## reader typed) does not come back as a newline. A chain of `replace` calls cannot tell those apart.
static func _unescape(value: String) -> String:
	var out: String = ""
	var index: int = 0
	while index < value.length():
		var here: String = value[index]
		if here != "\\" or index + 1 >= value.length():
			out += here
			index += 1
			continue
		var next: String = value[index + 1]
		match next:
			"n":
				out += "\n"
			"r":
				out += "\r"
			"t":
				out += "\t"
			"\\":
				out += "\\"
			_:
				out += "\\" + next
		index += 2
	return out
