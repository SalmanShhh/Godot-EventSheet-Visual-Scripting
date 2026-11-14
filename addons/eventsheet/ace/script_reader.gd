# Godot EventSheets - ONE reading of a script of yours, whichever door it came in by.
#
# A script reached the picker through two separate readings that disagreed: a registered script was read
# by its annotations (the generator), and a class listed under "Your classes" was read by plain reflection,
# so the same function came out as "Dead" in one place and "Is Dead" in another, with a different id
# for its variables, a different call and no way to say what it should read as. This is the single reading
# the second door now goes through: the generator's, with the rules a registered script has always had -
# its names, its kinds, its annotations, its authored sentences, and the aimed calls of the commit before.
#
# What stays true of the old door:
#   * nothing is instantiated and nothing is loaded just to be listed - a script is reflected from its
#     own member lists and its source, so a non-@tool script is read as well as a tool one;
#   * every id the old door published still resolves. Its two property ids (`property:get:x`,
#     `property:set:x`) are kept as hidden, deprecated aliases that carry the old call and point at the
#     id the generator publishes (`property:x`, `set:x`), so a row already placed keeps reading and a
#     side-file entry written against the old id still finds its verb;
#   * a member the script hides stays resolvable for rows already placed and is simply not offered.
#
# No class_name, like the other readers a boot never needs: callers preload it by path.
@tool
extends RefCounted

## The id the old door gave a property's reader and writer, by the id the generator gives it now.
const LEGACY_PROPERTY_PREFIX: String = "property:get:"
const LEGACY_SET_PREFIX: String = "property:set:"


## Every definition the one reading publishes for a script, for the class card `target_class`:
## the generator's, flagged as reflected (so the project's side file may still refine what the script
## did not say itself), plus the hidden aliases of the old ids. `target_prefix` is the autoload name
## when the script is a global, "" otherwise.
static func definitions_for(target_class: String, script: Script, target_prefix: String) -> Array[ACEDefinition]:
	var output: Array[ACEDefinition] = []
	if script == null:
		return output
	var read: Array[ACEDefinition] = EventSheetACEGenerator.new().generate_from_script(script, true, target_prefix.strip_edges())
	var authored: Dictionary = _authored_facets(script)
	for definition: ACEDefinition in read:
		definition.provider_id = target_class
		definition.metadata["reflected"] = true
		definition.metadata["reflect_class"] = target_class
		definition.metadata["authored"] = authored.get("%s:%s" % [definition.metadata.get("source_kind", ""),
			definition.metadata.get("source_name", "")], {})
		output.append(definition)
	for definition: ACEDefinition in read.duplicate():
		var alias: ACEDefinition = _legacy_alias(definition, target_prefix)
		if alias != null:
			output.append(alias)
	return output


## The ids the old door used for the same verb, newest first: what a side-file entry written against an
## older id is looked up under. Empty for an id that never changed.
static func legacy_ids_for(ace_id: String) -> PackedStringArray:
	if ace_id.begins_with("set:"):
		return PackedStringArray([LEGACY_SET_PREFIX + ace_id.trim_prefix("set:")])
	if ace_id.begins_with("property:") and ace_id.count(":") == 1:
		return PackedStringArray([LEGACY_PROPERTY_PREFIX + ace_id.trim_prefix("property:")])
	return PackedStringArray()


## `kind:member` -> which facets the script's own `##` lines authored: {"name", "category", "sentence"}.
static func _authored_facets(script: Script) -> Dictionary:
	var metadata: Dictionary = EventSheetSemanticAnalyzer.new().parse_source_metadata(script)
	var facets: Dictionary = {}
	for section: Array in [["method", "methods"], ["signal", "signals"], ["property", "properties"], ["property_action", "properties"]]:
		for member: Variant in (metadata.get(str(section[1]), {}) as Dictionary):
			var overrides: Dictionary = (metadata[str(section[1])] as Dictionary)[member]
			facets["%s:%s" % [section[0], member]] = {
				"name": not str(overrides.get("name", "")).is_empty(),
				"category": not str(overrides.get("category", "")).is_empty(),
				"sentence": not str(overrides.get("display_template", "")).is_empty(),
			}
	return facets


## The old door's twin of a property verb, hidden and deprecated, carrying the call it always carried.
static func _legacy_alias(definition: ACEDefinition, target_prefix: String) -> ACEDefinition:
	var ids: PackedStringArray = legacy_ids_for(definition.id)
	if ids.is_empty():
		return null
	var prefix: String = EventSheetClassDBSource.member_prefix(target_prefix)
	var member: String = str(definition.metadata.get("source_name", ""))
	var alias: ACEDefinition = definition.copy()
	alias.id = ids[0]
	alias.metadata = definition.metadata.duplicate(true)
	alias.metadata["codegen_template"] = "%s%s = {value}" % [prefix, member] if definition.id.begins_with("set:") else "%s%s" % [prefix, member]
	if definition.id.begins_with("set:"):
		alias.parameters = [{"id": "value", "display_name": "Value", "description": "", "type": TYPE_STRING,
			"default_value": "0", "hint": "expression", "options": [], "autocomplete": []}]
		alias.metadata["display_template"] = "%s {value}" % definition.display_name.trim_suffix(" {value}")
	else:
		alias.parameters = []
	alias.metadata["deprecated"] = true
	alias.metadata["hidden_member"] = true
	alias.metadata["authored"] = {}
	alias.metadata["successor"] = {"id": definition.id, "renames": {}, "defaults": {}}
	alias.metadata["replacement_ace_id"] = definition.id
	return alias
