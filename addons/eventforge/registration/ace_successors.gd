# EventForge - the forwarding addresses, resolved.
#
# A shipped verb is never renamed and never deleted: its id, its template and its display text are a
# compatibility promise, and a sheet written five versions ago has to keep compiling byte for byte.
# So when a verb is superseded, the old one stays exactly where it is and carries the ADDRESS of the
# newer spelling - `ACEDescriptor.succeeded_by(...)` for a built-in, `## @ace_succeeded_by(...)` for
# a pack. This file is the one place that address is read.
#
# THE MAP SAYS THREE THINGS AND NO MORE:
#   {"id": "<provider>::<ace_id>", "renames": {old: new}, "defaults": {new: value}}
# the successor, what this row's parameters are called over there, and a value for each parameter
# the old row never had. That is exactly enough for a rewritten row to land COMPLETE, and stops
# short of anything that would make a map a program.
#
# CHAINS RESOLVE TO THE END. A verb superseded twice (A -> B -> C) offers C, with the renames
# composed through B and the defaults carried along and re-keyed at each hop. A CYCLE answers
# nothing, and is a problem the pack gate FAILS on rather than a loop somebody meets at runtime.
#
# NOTHING HERE EDITS ANYTHING. `resolve()` and `rewrite_params()` answer questions; applying an
# answer is an edit a person approved in a dialog, made through the sheet's undo funnel. Opening and
# saving a sheet never consult this file at all.
@tool
class_name EventForgeSuccessors
extends RefCounted

## The three keys of a map, named once so the descriptor, the annotation reader and every consumer
## spell them the same way.
const KEY_ID: String = "id"
const KEY_RENAMES: String = "renames"
const KEY_DEFAULTS: String = "defaults"

## How deep a chain may be walked before it is called a cycle. A vocabulary that has genuinely moved
## a verb thirty-two times has a bigger problem than this limit.
const MAX_HOPS: int = 32

## The vocabulary, built once per session. Reflecting every installed pack costs real time, and the
## answer only changes when a pack file does - which is the same bargain the definition registry
## already strikes.
static var _catalog_cache: Dictionary = {}
static var _catalog_cache_key: String = ""


## The forwarding address carried by one vocabulary entry - an `ACEDescriptor` (a built-in) or an
## `ACEDefinition` (a pack verb, where it rides in metadata). {} when the entry has none.
static func map_of(entry: Variant) -> Dictionary:
	if entry is ACEDescriptor:
		return (entry as ACEDescriptor).successor_map()
	if entry is ACEDefinition:
		var carried: Variant = (entry as ACEDefinition).metadata.get("successor", {})
		return normalize_map(carried) if carried is Dictionary else {}
	return {}


## One map with every key present and of the right type, so a reader never has to guess. {} for
## anything that does not name a successor - an empty id is not a forwarding address.
static func normalize_map(raw: Dictionary) -> Dictionary:
	var successor: String = str(raw.get(KEY_ID, "")).strip_edges()
	if successor.is_empty():
		return {}
	var renames: Variant = raw.get(KEY_RENAMES, {})
	var defaults: Variant = raw.get(KEY_DEFAULTS, {})
	return {
		KEY_ID: successor,
		KEY_RENAMES: (renames as Dictionary).duplicate(true) if renames is Dictionary else {},
		KEY_DEFAULTS: (defaults as Dictionary).duplicate(true) if defaults is Dictionary else {},
	}


## "<provider>::<ace_id>" - the one spelling of a verb's identity everything here is keyed by.
static func key_of(provider_id: String, ace_id: String) -> String:
	return "%s::%s" % [provider_id, ace_id]


## One ACEDescriptor.ACEType as the ACEDefinition.ACEType that means the same thing. The two enums
## exist for two layers and do not agree on the numbers, so every entry above is normalized here.
static func _definition_type_of(descriptor_type: int) -> int:
	match descriptor_type:
		ACEDescriptor.ACEType.CONDITION:
			return ACEDefinition.ACEType.CONDITION
		ACEDescriptor.ACEType.EXPRESSION:
			return ACEDefinition.ACEType.EXPRESSION
		ACEDescriptor.ACEType.TRIGGER:
			return ACEDefinition.ACEType.TRIGGER
		_:
			return ACEDefinition.ACEType.ACTION


## A `Variant.Type` as the GDScript type name a descriptor would have spelled out. The two halves of
## the vocabulary declare a parameter's type differently - a descriptor writes the word, a pack
## definition carries the engine's enum - and a reader comparing them needs one spelling.
static func type_name_of(variant_type: Variant) -> String:
	match int(variant_type) if variant_type != null else TYPE_NIL:
		TYPE_BOOL:
			return "bool"
		TYPE_INT:
			return "int"
		TYPE_FLOAT:
			return "float"
		TYPE_STRING, TYPE_STRING_NAME:
			return "String"
	return ""


## The provider and ace halves of such a key, as [provider, ace_id]. A key with no "::" is all
## ace_id under the Core provider, which is how a map may name a built-in the short way.
static func split_key(key: String) -> PackedStringArray:
	var separator: int = key.find("::")
	if separator < 0:
		return PackedStringArray(["Core", key.strip_edges()])
	return PackedStringArray([key.substr(0, separator).strip_edges(), key.substr(separator + 2).strip_edges()])


# ── The catalogue ─────────────────────────────────────────────────────────────────────────────


## Every verb the project knows, keyed by "<provider>::<ace_id>", each already reduced to the facts a
## forwarding address is checked against: its display name, its parameters, which of those a row
## must answer for itself, its template, and its own map. Built from the built-in descriptors plus
## the installed packs, so the gate and the editor are asking about the same vocabulary.
static func catalog() -> Dictionary:
	var key: String = _catalog_key()
	if not key.is_empty() and key == _catalog_cache_key:
		return _catalog_cache
	var built: Dictionary = {}
	for descriptor: ACEDescriptor in ACERegistry.get_all_descriptors():
		var entry: Dictionary = entry_of(descriptor)
		if not entry.is_empty():
			built[str(entry["key"])] = entry
	for definition: ACEDefinition in _pack_definitions():
		var pack_entry: Dictionary = entry_of(definition)
		if not pack_entry.is_empty():
			built[str(pack_entry["key"])] = pack_entry
	_catalog_cache = built
	_catalog_cache_key = key
	return built


## Drops the remembered vocabulary. The cache keys on the pack listing, which does not change when a
## file's CONTENTS do - so a test that rewrites a pack in place calls this.
static func clear_cache() -> void:
	_catalog_cache = {}
	_catalog_cache_key = ""


## One vocabulary entry reduced to the facts this file checks, or {} for anything that is not a verb.
## `declared_defaults` is what each parameter starts on, and `answered_by_default` is the subset of
## those a row may leave alone because the value is usable as it stands; a parameter whose declared
## default is BLANK is not one of them - a blank default means "a row must say which", and a rewrite
## that left it blank would emit a hole. `declared_hints` is each parameter's UI hint, which is what
## decides the SHAPE of the value a row stores in it - a plain text parameter holds a quoted literal
## and a name-shaped one (a state, a variable, a node) holds a bare name - so a gate asking what a
## real row would carry has to ask this rather than the type alone. `declared_types` is each
## parameter's GDScript type name beside it, for the same reason: a blank number field holds `0`,
## not an empty string.
static func entry_of(source: Variant) -> Dictionary:
	if source is ACEDescriptor:
		var descriptor: ACEDescriptor = source
		var descriptor_params: PackedStringArray = PackedStringArray()
		var descriptor_answered: PackedStringArray = PackedStringArray()
		var descriptor_defaults: Dictionary = {}
		var descriptor_hints: Dictionary = {}
		var descriptor_types: Dictionary = {}
		for param: ACEParam in descriptor.params:
			if param == null:
				continue
			var param_id: String = param.id if not param.id.is_empty() else param.name
			if param_id.is_empty():
				continue
			descriptor_params.append(param_id)
			descriptor_defaults[param_id] = param.get_initial_value()
			descriptor_hints[param_id] = param.hint
			descriptor_types[param_id] = param.type_name
			if not str(param.get_initial_value()).strip_edges().is_empty():
				descriptor_answered.append(param_id)
		return {
			"key": key_of(descriptor.provider_id, descriptor.ace_id),
			"name": descriptor.get_list_name(),
			# The shelf the picker files this verb under. Nothing here resolves anything with it - it
			# rides along because the registry dump is written off this same reduction, and a second
			# reflection pass purely to read one string is a second answer waiting to disagree.
			"category": descriptor.category,
			"template": descriptor.codegen_template,
			# The reading a row applied on this verb would be baked under - slots and all, never a
			# finished sentence. A rewrite carries it over so the migrated row goes on reading as a
			# sentence rather than as an id, exactly as a freshly picked one does.
			"display_template": descriptor.get_display_text(),
			# Whether landing on this verb needs more than an id, a template and values: a per-instance
			# `{uid}`, a member of its own, a prelude, or a term the compiler hoists. Such a verb has to
			# be PICKED (the dock bakes the uid at apply time and the compiler never does), so a rewrite
			# that only copied ids and values onto it would emit an unbaked `{uid}` into somebody's file.
			"needs_baking": descriptor.codegen_template.contains("{uid}") \
				or not descriptor.member_template.strip_edges().is_empty() \
				or not descriptor.codegen_prelude.strip_edges().is_empty() \
				or not descriptor.codegen_on_true.strip_edges().is_empty() \
				or descriptor.evaluate_last,
			# ALWAYS an ACEDefinition.ACEType. The two enums number their members differently, so an
			# entry that carried whichever one its source happened to use would read ACTION as
			# CONDITION half the time; one spelling here means a reader never has to ask which.
			"ace_type": _definition_type_of(descriptor.ace_type),
			"params": descriptor_params,
			"declared_defaults": descriptor_defaults,
			"declared_hints": descriptor_hints,
			"declared_types": descriptor_types,
			"answered_by_default": descriptor_answered,
			"map": descriptor.successor_map(),
		}
	if source is ACEDefinition:
		var definition: ACEDefinition = source
		var definition_params: PackedStringArray = PackedStringArray()
		var definition_answered: PackedStringArray = PackedStringArray()
		var definition_defaults: Dictionary = {}
		var definition_hints: Dictionary = {}
		var definition_types: Dictionary = {}
		for parameter: Variant in definition.parameters:
			if not (parameter is Dictionary):
				continue
			var parameter_dict: Dictionary = parameter
			var parameter_id: String = str(parameter_dict.get("id", "")).strip_edges()
			if parameter_id.is_empty():
				continue
			definition_params.append(parameter_id)
			definition_defaults[parameter_id] = parameter_dict.get("default_value", "")
			definition_hints[parameter_id] = str(parameter_dict.get("hint", ""))
			definition_types[parameter_id] = type_name_of(parameter_dict.get("type", TYPE_NIL))
			if not str(parameter_dict.get("default_value", "")).strip_edges().is_empty():
				definition_answered.append(parameter_id)
		var pack_template: String = str(definition.metadata.get("codegen_template", ""))
		return {
			"key": key_of(definition.provider_id, definition.id),
			"name": definition.display_name,
			"category": definition.category,
			"template": pack_template,
			"display_template": str(definition.metadata.get("display_template", "")) \
				if not str(definition.metadata.get("display_template", "")).strip_edges().is_empty() \
				else definition.display_name,
			"needs_baking": pack_template.contains("{uid}") \
				or not str(definition.metadata.get("member_template", "")).strip_edges().is_empty() \
				or not str(definition.metadata.get("codegen_prelude", "")).strip_edges().is_empty() \
				or not str(definition.metadata.get("codegen_on_true", "")).strip_edges().is_empty() \
				or bool(definition.metadata.get("evaluate_last", false)),
			"ace_type": definition.ace_type,
			"params": definition_params,
			"declared_defaults": definition_defaults,
			"declared_hints": definition_hints,
			"declared_types": definition_types,
			"answered_by_default": definition_answered,
			"map": map_of(definition),
		}
	return {}


# ── Resolution ────────────────────────────────────────────────────────────────────────────────


## Where this verb's newer spelling actually is, after following the whole chain - {} when it has no
## successor, when the chain leaves the vocabulary, or when it cycles.
##
## The answer is a map of the same three keys, from the ORIGINAL row's point of view: renames go
## straight from this verb's parameter names to the final verb's, and defaults are keyed by the final
## verb's names. `hops` lists the keys walked through, first successor first, so a receipt can say
## the route rather than only the destination.
##
## Where two hops both supply a default for the same final parameter, the EARLIER one wins: it was
## authored knowing the row being rewritten, and the later hop's value was chosen for a different
## row that already had the parameter.
static func resolve(key: String, from_catalog: Dictionary = {}) -> Dictionary:
	var known: Dictionary = from_catalog if not from_catalog.is_empty() else catalog()
	var entry: Variant = known.get(key)
	if not (entry is Dictionary):
		return {}
	var map: Dictionary = normalize_map((entry as Dictionary).get("map", {}))
	if map.is_empty():
		return {}
	var renames: Dictionary = (map[KEY_RENAMES] as Dictionary).duplicate(true)
	var defaults: Dictionary = (map[KEY_DEFAULTS] as Dictionary).duplicate(true)
	var here: String = str(map[KEY_ID])
	var hops: PackedStringArray = PackedStringArray([here])
	var visited: Dictionary = {key: true, here: true}
	while hops.size() < MAX_HOPS:
		var next_entry: Variant = known.get(here)
		if not (next_entry is Dictionary):
			# The chain names a verb this project does not have. Answer nothing rather than offer an
			# address nobody is at; `problems()` is where that is said out loud.
			return {}
		var next_map: Dictionary = normalize_map((next_entry as Dictionary).get("map", {}))
		if next_map.is_empty():
			break
		var next_key: String = str(next_map[KEY_ID])
		if visited.has(next_key):
			return {}
		visited[next_key] = true
		var hop_renames: Dictionary = next_map[KEY_RENAMES]
		# Composition walks the MIDDLE verb's own parameters, because those are the values that
		# actually arrive at this hop: each one is reached from the original row either by an
		# earlier rename or by carrying its name unchanged, and leaves under whatever this hop
		# calls it. A rename whose middle name the intermediate does not have never carried
		# anything, and is dropped here (and named by `problems()`).
		var middle_params: PackedStringArray = (next_entry as Dictionary).get("params", PackedStringArray())
		var arrives_as: Dictionary = {}
		for old_name: Variant in renames.keys():
			arrives_as[str(renames[old_name])] = str(old_name)
		var composed: Dictionary = {}
		for middle_param: String in middle_params:
			# A PARAMETER THE FIRST HOP SUPPLIED AS A DEFAULT IS NOT A RENAME. It arrives at this hop
			# carrying a value, but not from the original row - the original row has no parameter of
			# that name at all - so putting it in `renames` composed an entry keyed by a name the first
			# verb never had, and `problems()` then reported the map as renaming a parameter it does
			# not have, failing the pack audit over a chain that is correct. It is carried and re-keyed
			# in `defaults` below instead, which is where it belongs and which already had it right.
			if defaults.has(middle_param) and not arrives_as.has(middle_param):
				continue
			var origin: String = str(arrives_as.get(middle_param, middle_param))
			var target: String = str(hop_renames.get(middle_param, middle_param))
			if origin != target:
				composed[origin] = target
		renames = composed
		var carried: Dictionary = {}
		for default_name: Variant in defaults.keys():
			carried[str(hop_renames.get(default_name, default_name))] = defaults[default_name]
		for hop_default: Variant in (next_map[KEY_DEFAULTS] as Dictionary).keys():
			if not carried.has(hop_default):
				carried[hop_default] = (next_map[KEY_DEFAULTS] as Dictionary)[hop_default]
		defaults = carried
		here = next_key
		hops.append(here)
	return {
		KEY_ID: here,
		KEY_RENAMES: renames,
		KEY_DEFAULTS: defaults,
		"hops": hops,
	}


## The parameters a rewritten row carries: every value this row already holds, under the name the
## successor calls it, plus a value for each parameter the old row never had. A parameter the
## successor does not have is left behind - the successor's template has no slot for it, so carrying
## it would only be baggage.
static func rewrite_params(old_params: Dictionary, map: Dictionary, successor_params: PackedStringArray = PackedStringArray()) -> Dictionary:
	var resolved: Dictionary = normalize_map(map)
	if resolved.is_empty():
		return old_params.duplicate(true)
	var renames: Dictionary = resolved[KEY_RENAMES]
	var written: Dictionary = {}
	for old_name: Variant in old_params.keys():
		var new_name: String = str(renames.get(old_name, old_name))
		if successor_params.is_empty() or successor_params.has(new_name):
			written[new_name] = old_params[old_name]
	for default_name: Variant in (resolved[KEY_DEFAULTS] as Dictionary).keys():
		if not written.has(default_name):
			written[default_name] = (resolved[KEY_DEFAULTS] as Dictionary)[default_name]
	return written


# ── Soundness ─────────────────────────────────────────────────────────────────────────────────


## Everything wrong with the forwarding addresses in a vocabulary, one sentence each, sorted so two
## machines print the same list. Empty is the only shipping state: a map that names a verb nobody
## has, or points at itself, or joins a cycle, is a build error here rather than a surprise in
## somebody's open sheet.
static func problems(from_catalog: Dictionary = {}) -> PackedStringArray:
	var known: Dictionary = from_catalog if not from_catalog.is_empty() else catalog()
	var said: PackedStringArray = PackedStringArray()
	var keys: PackedStringArray = PackedStringArray()
	for key: Variant in known.keys():
		keys.append(str(key))
	keys.sort()
	for key: String in keys:
		var entry: Dictionary = known[key]
		var map: Dictionary = normalize_map(entry.get("map", {}))
		if map.is_empty():
			continue
		var successor_key: String = str(map[KEY_ID])
		if successor_key == key:
			said.append("%s: succeeded by itself" % key)
			continue
		if not known.has(successor_key):
			said.append("%s: succeeded by %s, which no installed vocabulary has" % [key, successor_key])
			continue
		var cycle: PackedStringArray = _cycle_from(key, known)
		if not cycle.is_empty():
			said.append("%s: the chain comes back to itself (%s)" % [key, " -> ".join(cycle)])
			continue
		var resolved: Dictionary = resolve(key, known)
		if resolved.is_empty():
			said.append("%s: the chain from here reaches nothing" % key)
			continue
		said.append_array(_map_problems(key, entry, resolved, known))
	return said


## What is wrong with ONE resolved map, given the two verbs it joins: a rename that names a
## parameter neither side has, a default for a parameter the successor does not have or that a
## rename already answers, and - the one that matters most - a parameter of the successor that
## nothing answers, which is a rewritten row with a hole in it.
static func _map_problems(key: String, entry: Dictionary, resolved: Dictionary, known: Dictionary) -> PackedStringArray:
	var said: PackedStringArray = PackedStringArray()
	var successor_key: String = str(resolved[KEY_ID])
	var successor: Dictionary = known[successor_key]
	var old_params: PackedStringArray = entry.get("params", PackedStringArray())
	var new_params: PackedStringArray = successor.get("params", PackedStringArray())
	var renames: Dictionary = resolved[KEY_RENAMES]
	var defaults: Dictionary = resolved[KEY_DEFAULTS]
	var rename_sources: PackedStringArray = PackedStringArray()
	for source: Variant in renames.keys():
		rename_sources.append(str(source))
	rename_sources.sort()
	var answered: PackedStringArray = PackedStringArray()
	for source: String in rename_sources:
		var target: String = str(renames[source])
		if not old_params.has(source):
			said.append("%s: renames %s, which it has no parameter called" % [key, source])
		if not new_params.has(target):
			said.append("%s: renames %s to %s, which %s has no parameter called" % [key, source, target, successor_key])
			continue
		if old_params.has(source):
			answered.append(target)
	var default_names: PackedStringArray = PackedStringArray()
	for default_name: Variant in defaults.keys():
		default_names.append(str(default_name))
	default_names.sort()
	for default_name: String in default_names:
		if not new_params.has(default_name):
			said.append("%s: gives %s a value, which %s has no parameter called" % [key, default_name, successor_key])
			continue
		if answered.has(default_name):
			said.append("%s: gives %s both a renamed value and a default" % [key, default_name])
			continue
		answered.append(default_name)
	var its_own: PackedStringArray = successor.get("answered_by_default", PackedStringArray())
	for new_param: String in new_params:
		if answered.has(new_param) or its_own.has(new_param):
			continue
		# The parameter is carried through unchanged only if the old verb has one of that very name.
		if old_params.has(new_param) and not renames.has(new_param):
			continue
		said.append("%s: nothing answers %s's %s, so a rewritten row would land blank" % [key, successor_key, new_param])
	return said


## The chain out of `key` back to itself, as the keys it passes through, or empty when it does not
## come back. Named so `problems()` can print the route rather than only the verdict.
static func _cycle_from(key: String, known: Dictionary) -> PackedStringArray:
	var walked: PackedStringArray = PackedStringArray([key])
	var here: String = key
	for _hop: int in range(MAX_HOPS):
		var entry: Variant = known.get(here)
		if not (entry is Dictionary):
			return PackedStringArray()
		var map: Dictionary = normalize_map((entry as Dictionary).get("map", {}))
		if map.is_empty():
			return PackedStringArray()
		here = str(map[KEY_ID])
		walked.append(here)
		if here == key:
			return walked
		if walked.count(here) > 1:
			# A cycle further along the chain, which the verb that is IN it will report as its own.
			return PackedStringArray()
	return walked


# ── Where the vocabulary comes from ───────────────────────────────────────────────────────────


## Every installed pack's definitions, reflected the same way the live registry reflects them.
## Packs are the half of the vocabulary that ships from outside this plugin, and a forwarding
## address written in one has to be held to exactly the same gate as a built-in's.
static func _pack_definitions() -> Array[ACEDefinition]:
	var definitions: Array[ACEDefinition] = []
	var analyzer: EventSheetSemanticAnalyzer = EventSheetSemanticAnalyzer.new()
	var generator: EventSheetACEGenerator = EventSheetACEGenerator.new()
	for script_path: String in EventSheetAddonScanner.list_addon_scripts():
		var script: Script = load(script_path) as Script
		if script == null or not script.can_instantiate():
			continue
		var instance: Object = script.new()
		if instance == null:
			continue
		# The analyzer reads annotations off DISK, so the reflection below sees the same
		# `## @ace_succeeded_by(...)` a reader sees in the file.
		analyzer.parse_source_metadata(script)
		definitions.append_array(generator.generate_from_object(instance))
		if instance is Node:
			(instance as Node).free()
	return definitions


## What the remembered vocabulary is keyed on: every pack file and the moment it was last saved, so
## editing a pack's annotations self-invalidates instead of serving the vocabulary it used to have.
## Empty disables the cache rather than caching an absence.
static func _catalog_key() -> String:
	var scripts: Array[String] = EventSheetAddonScanner.list_addon_scripts()
	if scripts.is_empty():
		return ""
	var parts: PackedStringArray = PackedStringArray()
	for script_path: String in scripts:
		parts.append("%s|%d" % [script_path, FileAccess.get_modified_time(script_path)])
	return "|".join(parts)
