# Godot EventSheets - Paste Special (paste copied rows retargeted, in one step).
#
# Copy already puts a portable snippet on the system clipboard (event_sheet_snippet.gd) and Paste
# already creates the sheet variables that snippet needs. What was missing is choosing what the
# pasted rows point AT: retargeting used to be a SECOND gesture (Replace Object References... after
# the paste). This is the remap half - pure data in, pure data out - so the dialog can preview it,
# tests can drive it headless, and the insertion keeps using the one shipped paste path.
#
# Nothing here is new refactoring machinery: object references go through
# EventSheetRefactor.replace_node_reference (token-safe - $Enemy never touches $EnemySpawner) and
# variable names through EventSheetRefactor.rename_symbol on a TEMPORARY sheet holding the snippet's
# own rows + declarations, which is exactly what "Rename Everywhere..." runs on the open sheet. The
# rename therefore rewrites the declaration key AND every reference inside params, templates, raw
# code and pick filters, with no second implementation to keep in step.
#
# CREATE-MISSING vs REUSE-EXISTING needs no flag: paste creates a required variable only when the
# target sheet lacks that name and NEVER overwrites one it has (clipboard.gd), so renaming a
# snippet's `speed` to an existing `enemy_speed` reuses the sheet's declaration, and leaving a name
# that the sheet lacks creates it. `describe_variable_target` is the sentence the dialog shows so
# the user reads which of the two will happen before pressing OK.
#
# EVERY RETARGET HAPPENS AT ONCE, not one after another. Applying the mappings in sequence would
# feed each one's OUTPUT to the next: swapping $Player and $Enemy would turn both into $Player, and
# renaming `speed` to `enemy_speed` in a snippet that also declares `enemy_speed` would merge two
# distinct variables into one. So each source is first rewritten to a private sentinel and only
# then to its final name, and a mapping that would land two different sources on the SAME final
# name is refused outright (the dialog says so beside the field) rather than silently merging them.
@tool
class_name EventSheetPasteSpecial
extends RefCounted

## The sentinel names the two-phase rewrite parks a reference on between its old name and its new
## one. Long and namespaced, so a snippet cannot already contain one.
const OBJECT_SENTINEL := "$__eventsheet_paste_special_%d"
const VARIABLE_SENTINEL := "__eventsheet_paste_special_%d"


## What a snippet can be retargeted BY: every object reference its rows use ($Path, %Unique, self)
## and every sheet variable it declares a need for. Both sorted, so the dialog's rows are stable.
static func targets(snippet: Dictionary) -> Dictionary:
	var rows: Array = snippet.get("rows", []) if snippet.get("rows") is Array else []
	var variables: Array[String] = []
	var required: Dictionary = snippet.get("required_variables", {}) if snippet.get("required_variables") is Dictionary else {}
	for key: Variant in required.keys():
		variables.append(str(key))
	variables.sort()
	return {"objects": EventSheetRefactor.collect_node_references(rows), "variables": variables}


## The retargeted snippet: same shape as EventSheetSnippet.deserialize returns, so it drops straight
## into the shipped paste path. Rows are DEEP COPIES - the clipboard snippet stays untouched, so a
## cancelled or repeated Paste Special always starts from the original.
##
## `mapping` is {"objects": {from: to}, "variables": {from: to}}; a blank, unchanged or invalid
## target is skipped rather than applied, so a half-filled dialog can never corrupt a paste. Two
## sources aimed at the same variable name are refused for the same reason: that is a merge, not a
## retarget. Every accepted mapping is applied SIMULTANEOUSLY (see the header), so a swap is a swap.
static func remap(snippet: Dictionary, mapping: Dictionary) -> Dictionary:
	var rows: Array[Resource] = []
	for row: Variant in (snippet.get("rows", []) if snippet.get("rows") is Array else []):
		if row is Resource:
			rows.append((row as Resource).duplicate(true))
	var variables: Dictionary = {}
	var required: Dictionary = snippet.get("required_variables", {}) if snippet.get("required_variables") is Dictionary else {}
	for key: Variant in required.keys():
		var descriptor: Variant = required[key]
		variables[str(key)] = descriptor.duplicate(true) if descriptor is Dictionary else descriptor
	var counts: Dictionary = {"objects": 0, "variables": 0}
	# Phase 1 parks every source on its own sentinel; phase 2 moves each sentinel to its target. The
	# count comes from phase 1 - that is the number of references the snippet really carried.
	var object_pairs: Array = _accepted_object_pairs(mapping)
	for index: int in range(object_pairs.size()):
		var pair: Array = object_pairs[index]
		counts["objects"] = int(counts["objects"]) + EventSheetRefactor.replace_node_reference(rows, str(pair[0]), OBJECT_SENTINEL % index)
	for index: int in range(object_pairs.size()):
		EventSheetRefactor.replace_node_reference(rows, OBJECT_SENTINEL % index, str((object_pairs[index] as Array)[1]))
	# The temporary sheet is what lets the shipped rename run here: rename_symbol renames a variables
	# KEY plus every reference in the rows it is given, which is precisely the snippet's own scope.
	var scratch: EventSheetResource = EventSheetResource.new()
	scratch.variables = variables
	scratch.events = rows
	var variable_pairs: Array = _accepted_variable_pairs(snippet, mapping)
	for index: int in range(variable_pairs.size()):
		var pair: Array = variable_pairs[index]
		counts["variables"] = int(counts["variables"]) + EventSheetRefactor.rename_symbol(scratch, str(pair[0]), VARIABLE_SENTINEL % index)
	for index: int in range(variable_pairs.size()):
		EventSheetRefactor.rename_symbol(scratch, VARIABLE_SENTINEL % index, str((variable_pairs[index] as Array)[1]))
	return {
		"rows": scratch.events,
		"required_variables": scratch.variables,
		"providers": snippet.get("providers", []),
		"remapped": counts
	}


## The object retargets that will really be applied, as [from, to] pairs in a stable order. Blank,
## unchanged and UNUSABLE targets drop out here: the header promises a half-filled dialog cannot
## corrupt a paste, and `not a node!` pasted verbatim produces a row that will not even parse.
static func _accepted_object_pairs(mapping: Dictionary) -> Array:
	var pairs: Array = []
	var object_map: Dictionary = mapping.get("objects", {}) if mapping.get("objects") is Dictionary else {}
	var sources: Array = object_map.keys()
	sources.sort()
	for from_reference: Variant in sources:
		var to_reference: String = str(object_map[from_reference]).strip_edges()
		if to_reference.is_empty() or to_reference == str(from_reference) or not is_object_target(to_reference):
			continue
		pairs.append([str(from_reference), to_reference])
	return pairs


## The variable renames that will really be applied, as [from, to] pairs in a stable order. A
## target that is not an identifier is refused, and so is one that would COLLIDE: two sources
## landing on one name, or a name another copied variable keeps, merges two declarations into one
## and quietly loses whichever value the second one held.
static func _accepted_variable_pairs(snippet: Dictionary, mapping: Dictionary) -> Array:
	var pairs: Array = []
	var variable_map: Dictionary = mapping.get("variables", {}) if mapping.get("variables") is Dictionary else {}
	var sources: Array = variable_map.keys()
	sources.sort()
	var claimed: Dictionary = {}
	for declared: String in _declared_names(snippet):
		# A name only stays claimed while its own variable keeps it.
		if str(variable_map.get(declared, declared)).strip_edges() == declared:
			claimed[declared] = true
	for from_name: Variant in sources:
		var to_name: String = str(variable_map[from_name]).strip_edges()
		if to_name.is_empty() or to_name == str(from_name) or not to_name.is_valid_identifier() or claimed.has(to_name):
			continue
		claimed[to_name] = true
		pairs.append([str(from_name), to_name])
	return pairs


## Every variable name the snippet itself declares, sorted.
static func _declared_names(snippet: Dictionary) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	var required: Dictionary = snippet.get("required_variables", {}) if snippet.get("required_variables") is Dictionary else {}
	for key: Variant in required.keys():
		names.append(str(key))
	names.sort()
	return names


## True when `text` is something a row can point AT: `self`, a node-reference token ($Path,
## $"Odd Name", %Unique - the grammar collect_node_references reads), or a plain identifier
## naming a variable that holds a node. Everything else is a typo, and a typo pasted verbatim
## produces a row that will not parse.
static func is_object_target(text: String) -> bool:
	var trimmed: String = text.strip_edges()
	if trimmed == "self" or trimmed.is_valid_identifier():
		return true
	var regex: RegEx = RegEx.create_from_string("^(?:%s)$" % EventSheetRefactor.NODE_REF_PATTERN)
	return regex != null and regex.search(trimmed) != null


## "points at $Enemy2" / "not a node reference" - the live answer beside each object field, so a
## refusal is READ rather than discovered by a row that will not compile.
static func describe_object_target(target_name: String) -> String:
	var trimmed: String = target_name.strip_edges()
	if trimmed.is_empty():
		return "name it to point it somewhere"
	if not is_object_target(trimmed):
		return "not something to point at - try $Node, %Unique or self"
	return "points at %s" % trimmed


## "reuses this sheet's enemy_speed" / "creates enemy_speed" - the live answer the dialog puts beside
## each variable field, so create-missing vs reuse-existing is read, never guessed. `sheet` may be
## null (no sheet open yet), which always reads as a create. Pass the snippet and the field's own
## source name to have the COLLISION refusal read out too (remap refuses exactly this case, so the
## sentence and the button always agree).
static func describe_variable_target(sheet: EventSheetResource, target_name: String, snippet: Dictionary = {}, from_name: String = "") -> String:
	var trimmed: String = target_name.strip_edges()
	if trimmed.is_empty():
		return "name it to paste it"
	if not trimmed.is_valid_identifier():
		return "not a usable name - letters, digits and underscores"
	if trimmed != from_name and Array(_declared_names(snippet)).has(trimmed):
		return "another copied variable is already called %s - left as %s" % [trimmed, from_name]
	if sheet != null and sheet.variables.has(trimmed):
		return "reuses this sheet's %s" % trimmed
	return "creates %s" % trimmed


## The status sentence after a Paste Special ("3 row(s), 2 reference(s) and 1 name retargeted.").
static func summary(row_count: int, remapped: Dictionary) -> String:
	return "Paste Special: %d row(s), %d reference(s) and %d name(s) retargeted." % [
		row_count, int(remapped.get("objects", 0)), int(remapped.get("variables", 0))
	]
