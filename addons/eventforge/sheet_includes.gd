# Godot EventSheets — include management helpers.
#
# The compiler already MERGES included sheets (see sheet_compiler._merge_includes). These
# helpers make includes usable from the editor:
#  - summarize(): what an included sheet contributes (events/functions/variables) for an
#    include-manager preview.
#  - extract_to_include(): move selected rows out into a new library sheet and wire the
#    source to include it — turning copy-paste into modularization in one action.
@tool
class_name EventSheetIncludes
extends RefCounted

## What an included sheet contributes, for the manager preview:
## {valid, error, class, events, functions: [name…], variables: [name…]}.
static func summarize(include_path: String) -> Dictionary:
	var empty: Dictionary = {"valid": false, "error": "", "class": "", "events": 0, "functions": [], "variables": []}
	if include_path.strip_edges().is_empty():
		empty["error"] = "empty path"
		return empty
	if not ResourceLoader.exists(include_path):
		empty["error"] = "file not found"
		return empty
	var sheet: EventSheetResource = load(include_path) as EventSheetResource
	if sheet == null:
		empty["error"] = "not an event sheet"
		return empty
	var functions: Array = []
	for function_entry: Variant in sheet.functions:
		if function_entry is EventFunction:
			functions.append((function_entry as EventFunction).function_name)
	var variables: Array = []
	for key: Variant in sheet.variables.keys():
		variables.append(str(key))
	variables.sort()
	return {
		"valid": true,
		"error": "",
		"class": sheet.custom_class_name,
		"events": _count_rows(sheet.events),
		"functions": functions,
		"variables": variables
	}

## Returns true if adding `candidate` to `sheet.includes` would create an include cycle
## (the candidate, directly or transitively, already includes this sheet's path).
static func would_create_cycle(sheet_path: String, candidate: String, visited: Dictionary = {}) -> bool:
	if candidate == sheet_path:
		return true
	if visited.has(candidate) or not ResourceLoader.exists(candidate):
		return false
	visited[candidate] = true
	var candidate_sheet: EventSheetResource = load(candidate) as EventSheetResource
	if candidate_sheet == null:
		return false
	for nested: String in candidate_sheet.includes:
		if would_create_cycle(sheet_path, nested, visited):
			return true
	return false

## Moves `rows` out of `source` into a NEW library EventSheetResource and adds `new_path` to
## source.includes. Returns {library, error}. The caller saves the library .tres at new_path
## and applies the source change undoably. Rows are MOVED (identity/uids preserved), so the
## merged result is byte-for-byte what the source had — just relocated.
static func extract_to_include(source: EventSheetResource, rows: Array, new_path: String) -> Dictionary:
	if source == null:
		return {"library": null, "error": "no source sheet"}
	if rows.is_empty():
		return {"library": null, "error": "select at least one row to extract"}
	if new_path.strip_edges().is_empty() or not new_path.ends_with(".tres"):
		return {"library": null, "error": "include path must be a res://….tres file"}
	var library: EventSheetResource = EventSheetResource.new()
	library.host_class = source.host_class
	library.behavior_mode = source.behavior_mode
	for row: Variant in rows:
		if row is Resource and source.events.has(row):
			library.events.append(row)  # move the original (keeps its uid)
	for row: Variant in rows:
		var index: int = source.events.find(row)
		if index != -1:
			source.events.remove_at(index)
	if not source.includes.has(new_path):
		source.includes.append(new_path)
	return {"library": library, "error": ""}

## Resolves the sheet's includes (transitively) into what each contributes — the backbone of
## include PROVENANCE in the editor: [{include, class, events: [Resource…], functions: [name…],
## variables: [name…]}]. The events are the actual rows from the included sheet; the editor
## renders them READ-ONLY (with jump-to-source), so a merged sheet reads as one whole.
static func included_rows(sheet: EventSheetResource, visited: Dictionary = {}) -> Array:
	var result: Array = []
	if sheet == null:
		return result
	for include_path: String in sheet.includes:
		if visited.has(include_path) or not ResourceLoader.exists(include_path):
			continue
		visited[include_path] = true
		var included: EventSheetResource = load(include_path) as EventSheetResource
		if included == null:
			continue
		var functions: Array = []
		for function_entry: Variant in included.functions:
			if function_entry is EventFunction:
				functions.append((function_entry as EventFunction).function_name)
		result.append({
			"include": include_path,
			"class": included.custom_class_name,
			"events": included.events.duplicate(),
			"functions": functions,
			"variables": included.variables.keys()
		})
		result.append_array(included_rows(included, visited))  # transitive includes
	return result

static func _count_rows(rows: Array) -> int:
	var total: int = rows.size()
	for row: Variant in rows:
		if row is EventGroup:
			total += _count_rows((row as EventGroup).events if not (row as EventGroup).events.is_empty() else (row as EventGroup).rows)
		elif row is EventRow:
			total += _count_rows((row as EventRow).sub_events)
	return total
