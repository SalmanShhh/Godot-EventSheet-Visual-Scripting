# Godot EventSheets - the whole game on one page, and the search that reaches all of it.
#
# A project of forty sheets has no place that says what it consists of. Each sheet knows itself, the
# Doctor knows its findings, a profiler run knows its milliseconds, and nobody joins them - so the
# person who has to decide what to work on next opens sheets one at a time and guesses. This is the
# join: one row per sheet, with the numbers each of those places already computed.
#
# IT ADDS NO SCAN. Every column here is DATA THAT ALREADY EXISTS somewhere else - the sheet's own
# rows, the Doctor's findings, the stored profiler run, the reading coverage the opened-script banner
# shows. The join happens once, when the page is opened, over things already in hand; it is not a
# walk of res://, it does not re-open files, and it never runs per frame. Handing the caller's own
# findings and timings IN is what makes that true, and is why every function here is pure over its
# arguments and can be pinned by a test with two sheets and no project.
#
# WHAT AN EMPTY COLUMN MEANS. A sheet with no stored profiler run shows no milliseconds at all rather
# than a zero, because zero milliseconds is a claim and "nobody measured" is the truth. The same goes
# for findings when the Doctor has not been run.
#
# THE SEARCH is the other half. A name is not one thing: `hp` written is a different fact from `hp`
# read and from `hp` compared, and a person hunting a bug usually knows which one they want. So the
# find takes a facet, every hit says which sheet and which row it is in, and the caller opens it.
#
# MERGE DEFENCE. A sheet opened from a file that a merge damaged must not quietly pick a side. The
# guard here re-asks the byte question on open: an unresolved region is reported with BOTH parents'
# spellings, so the row can be shown amber with the two readings side by side and a person decides.
# Silently keeping one parent is the one outcome this rules out.
@tool
class_name EventSheetProjectViewModel
extends RefCounted

## The facets a project-wide find can be narrowed to. "any" is every surface; the rest each answer a
## different question about the same name, which is why they are separate rather than one search with
## a checkbox. Frozen: the panel's dropdown and the tests address a facet by these words.
const FACET_ANY := "any"
const FACET_WRITTEN := "written"
const FACET_READ := "read"
const FACET_COMPARED := "compared"
const FACET_NODE := "node"
const FACET_ANIMATION := "animation"
const FACET_MODE := "mode"

## Every facet, in the order the panel offers them.
const FACETS: PackedStringArray = [FACET_ANY, FACET_WRITTEN, FACET_READ, FACET_COMPARED,
	FACET_NODE, FACET_ANIMATION, FACET_MODE]


## THE JOIN, once per open. `sheets` maps a path to its loaded EventSheetResource; `findings` is a
## Doctor report's findings array (empty when nobody has run it); `timings` maps a sheet path to the
## milliseconds a stored profiler run measured for it (empty when nobody has profiled). Returns one
## row per sheet, sorted by path - a caller's dictionary keeps insertion order, and a directory walk
## produces a different one on every filesystem, so the page's order is decided here rather than by
## whoever happened to fill the dictionary.
static func rows(sheets: Dictionary, findings: Array = [], timings: Dictionary = {}) -> Array[Dictionary]:
	var by_path: Dictionary = _findings_by_path(findings)
	var paths: PackedStringArray = PackedStringArray()
	for key: Variant in sheets.keys():
		paths.append(str(key))
	paths.sort()
	var built: Array[Dictionary] = []
	for path: String in paths:
		var sheet: Variant = sheets.get(path)
		if sheet is EventSheetResource:
			built.append(row_for(path, sheet as EventSheetResource,
				by_path.get(path, 0), timings.get(path)))
	return built


## One sheet's row. `finding_count` and `milliseconds` are handed in rather than computed, because
## both belong to runs this page does not perform: a page that started a Doctor run to draw itself
## would be a page nobody could afford to open.
static func row_for(path: String, sheet: EventSheetResource, finding_count: int = 0,
		milliseconds: Variant = null) -> Dictionary:
	var coverage: Dictionary = EventSheetDescriptions.coverage(sheet)
	var reading: Dictionary = EventSheetReadingCoverage.measure(sheet)
	return {
		"path": path,
		"scene": _scene_of(sheet),
		"events": _event_count(sheet),
		"functions": sheet.functions.size(),
		"variables": sheet.variables.size(),
		"described": int(coverage.get("described", 0)),
		"describable": int(coverage.get("total", 0)),
		"unreadable_rows": int(reading.get("block_rows", 0)),
		"adoption_percent": int(reading.get("percent", 100)),
		"findings": finding_count,
		# Absent, not zero: a sheet nobody profiled has no millisecond number to show, and showing 0
		# would read as "this sheet is free", which is a claim nobody made.
		"milliseconds": milliseconds,
	}


## The sentence one row states, in the order a reader scans it: what it is, how big, how much of it
## is described, and only then the numbers that exist. Built here so the panel, a text dump and a test
## all say it the same way.
static func row_sentence(row: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	parts.append("%d event(s)" % int(row.get("events", 0)))
	parts.append("%d of %d described" % [int(row.get("described", 0)), int(row.get("describable", 0))])
	if int(row.get("unreadable_rows", 0)) > 0:
		parts.append("%d script block(s)" % int(row.get("unreadable_rows", 0)))
	if int(row.get("findings", 0)) > 0:
		parts.append("%d finding(s)" % int(row.get("findings", 0)))
	if row.get("milliseconds") != null:
		parts.append("%.1f ms measured" % float(row.get("milliseconds")))
	return ", ".join(parts)


## PROJECT-WIDE FIND: every hit for one name across every sheet handed in, narrowed to one facet.
## Each hit is {path, kind, name, where, text} - `where` naming the function or group the row sits in,
## so a result row can be clicked straight through to it. Sorted by path then by where then by text,
## so the same project always lists the same hits in the same order.
static func find(sheets: Dictionary, needle: String, facet: String = FACET_ANY) -> Array[Dictionary]:
	var query: String = needle.strip_edges().to_lower()
	var hits: Array[Dictionary] = []
	if query.is_empty():
		return hits
	var paths: PackedStringArray = PackedStringArray()
	for key: Variant in sheets.keys():
		paths.append(str(key))
	paths.sort()
	for path: String in paths:
		var sheet: Variant = sheets.get(path)
		if sheet is EventSheetResource:
			_find_in_sheet(path, sheet as EventSheetResource, query, facet, hits)
	return hits


## MERGE DEFENCE, asked on every open of a code-backed sheet. Returns one entry per damaged place,
## each carrying BOTH parents' spellings ({heading, ours, theirs, ours_label, theirs_label}) so the
## row can be shown amber with the two readings rather than silently resolved. Empty when the file is
## clean, which is the ordinary case and costs one scan of the text for a marker prefix.
static func merge_damage(source: String) -> Array[Dictionary]:
	var damaged: Array[Dictionary] = []
	if not EventSheetConflictRegions.has_conflicts(source):
		return damaged
	for region: Dictionary in EventSheetConflictRegions.find(source):
		damaged.append({
			"heading": EventSheetConflictRegions.region_heading(region),
			"ours": "\n".join(region.get("ours", PackedStringArray()) as PackedStringArray),
			"theirs": "\n".join(region.get("theirs", PackedStringArray()) as PackedStringArray),
			"ours_label": str(region.get("ours_label", "")),
			"theirs_label": str(region.get("theirs_label", "")),
		})
	return damaged


## The sentence an amber merge-damaged row states: what was damaged, and that both spellings are kept
## until somebody chooses. Deliberately says nothing about which side is likely right - the plugin
## does not know, and a guess printed here would be taken for an answer.
static func merge_damage_sentence(entry: Dictionary) -> String:
	return "%s came back from a merge with two spellings (%s and %s). Both are kept until you pick one." % [
		str(entry.get("heading", "This row")),
		_label_or(str(entry.get("ours_label", "")), "this branch"),
		_label_or(str(entry.get("theirs_label", "")), "the other branch"),
	]


## A merge label, or the plain words for a side that the merge left unlabelled.
static func _label_or(label: String, fallback: String) -> String:
	return label.strip_edges() if not label.strip_edges().is_empty() else fallback


## How many findings each path has, out of a Doctor report's findings array.
static func _findings_by_path(findings: Array) -> Dictionary:
	var counts: Dictionary = {}
	for entry: Variant in findings:
		if entry is Dictionary:
			var path: String = str((entry as Dictionary).get("path", ""))
			counts[path] = int(counts.get(path, 0)) + 1
	return counts


## The scene or host this sheet runs on, in the words the sheet itself carries: its class name when it
## declares one, else the host type it is attached to.
static func _scene_of(sheet: EventSheetResource) -> String:
	if not sheet.custom_class_name.strip_edges().is_empty():
		return sheet.custom_class_name.strip_edges()
	if sheet.autoload_mode and not sheet.autoload_name.strip_edges().is_empty():
		return sheet.autoload_name.strip_edges()
	return sheet.host_class


## Every event row of a sheet, at any depth, including the ones inside its functions - the number a
## reader means by "how big is this sheet".
static func _event_count(sheet: EventSheetResource) -> int:
	var total: int = _count_events(sheet.events)
	for function_entry: Variant in sheet.functions:
		if function_entry is EventFunction:
			var event_function: EventFunction = function_entry as EventFunction
			total += _count_events(event_function.events if not event_function.events.is_empty() else event_function.rows)
	return total


## The recursive half of the count above.
static func _count_events(rows: Array) -> int:
	var total: int = 0
	for entry: Variant in rows:
		if entry is EventGroup:
			var group: EventGroup = entry as EventGroup
			total += _count_events(group.events if not group.events.is_empty() else group.rows)
		elif entry is EventRow:
			total += 1
			total += _count_events((entry as EventRow).sub_events)
	return total


## Every hit in one sheet, appended in sheet order: its declarations first (a name's declaration is
## the hit a searcher most often wants), then its rows.
static func _find_in_sheet(path: String, sheet: EventSheetResource, query: String, facet: String,
		hits: Array[Dictionary]) -> void:
	if facet == FACET_ANY or facet == FACET_MODE:
		for entry: Variant in sheet.events:
			if entry is EventGroup:
				var group: EventGroup = entry as EventGroup
				if group.runs_in.to_lower().contains(query):
					hits.append(_hit(path, "mode", group.runs_in,
						EventSheetDescriptions.group_name_of(group), "runs in %s" % group.runs_in))
	if facet == FACET_ANY:
		var variable_names: PackedStringArray = PackedStringArray()
		for key: Variant in sheet.variables.keys():
			variable_names.append(str(key))
		variable_names.sort()
		for variable_name: String in variable_names:
			if variable_name.to_lower().contains(query):
				hits.append(_hit(path, "variable", variable_name, "declarations",
					EventSheetDescriptions.display(EventSheetDescriptions.for_variable(sheet, variable_name))))
	_find_in_rows(path, sheet.events, "sheet", query, facet, hits)
	for function_entry: Variant in sheet.functions:
		if function_entry is EventFunction:
			var event_function: EventFunction = function_entry as EventFunction
			if facet == FACET_ANY and event_function.function_name.to_lower().contains(query):
				hits.append(_hit(path, "function", event_function.function_name, "declarations",
					EventSheetDescriptions.signature_of(event_function)))
			_find_in_rows(path, event_function.events if not event_function.events.is_empty() else event_function.rows,
				event_function.function_name, query, facet, hits)


## Every hit in one run of rows, at any depth. `where` is the function or group these rows sit in, and
## a group replaces it for its own children so a hit reads as the place a person would go to.
static func _find_in_rows(path: String, rows: Array, where: String, query: String, facet: String,
		hits: Array[Dictionary]) -> void:
	for entry: Variant in rows:
		if entry is EventGroup:
			var group: EventGroup = entry as EventGroup
			_find_in_rows(path, group.events if not group.events.is_empty() else group.rows,
				EventSheetDescriptions.group_name_of(group), query, facet, hits)
		elif entry is EventRow:
			var row: EventRow = entry as EventRow
			for action_entry: Variant in row.actions:
				if action_entry is ACEAction:
					var action: ACEAction = action_entry as ACEAction
					_match_params(path, where, query, facet, action.ace_id,
						_ordered_params(action.provider_id, action.ace_id, _params_of(action)), true, hits)
			for condition_entry: Variant in row.conditions:
				if condition_entry is ACECondition:
					var condition: ACECondition = condition_entry as ACECondition
					_match_params(path, where, query, facet, condition.ace_id,
						_ordered_params(condition.provider_id, condition.ace_id, _params_of(condition)), false, hits)
			_find_in_rows(path, row.sub_events, where, query, facet, hits)


## One action's or condition's parameter values against the query, filed under the facet the surface
## belongs to. An action's first parameter is what it WRITES; every other value it names it READS; a
## condition names what it COMPARES. That mapping is the whole difference between the facets, and it
## lives here rather than being re-derived by each caller.
static func _match_params(path: String, where: String, query: String, facet: String, ace_id: String,
		ordered: Array, is_action: bool, hits: Array[Dictionary]) -> void:
	for index: int in range(ordered.size()):
		var pair: Dictionary = ordered[index] as Dictionary
		var key: String = str(pair.get("key", ""))
		var value: String = str(pair.get("value", ""))
		if not value.to_lower().contains(query):
			continue
		var surface: String = FACET_COMPARED
		if is_action:
			surface = FACET_WRITTEN if index == 0 else FACET_READ
		var kinds: PackedStringArray = _surfaces_for(key, value, surface)
		if facet != FACET_ANY and not kinds.has(facet):
			continue
		hits.append(_hit(path, surface if facet == FACET_ANY else facet, value, where,
			"%s (%s)" % [ace_id, key]))


## Which facets one parameter value answers to. A value is always its written/read/compared surface,
## and ALSO a node name or an animation name when the parameter it sits in says so - a node path is
## looked for under the node facet whether it was written or read, because a person hunting a node
## does not care which side of the row it was on.
static func _surfaces_for(param_id: String, value: String, surface: String) -> PackedStringArray:
	var kinds: PackedStringArray = PackedStringArray([surface])
	var key: String = param_id.to_lower()
	if key.contains("node") or key.contains("target") or value.begins_with("$") or value.begins_with("%"):
		kinds.append(FACET_NODE)
	if key.contains("anim"):
		kinds.append(FACET_ANIMATION)
	if key.contains("mode") or key.contains("state"):
		kinds.append(FACET_MODE)
	return kinds


## One row's parameters as an ordered list of {key, value}, in the order the DESCRIPTOR declares them
## rather than the order a dictionary happens to hold them. That order is what decides which value is
## the one being written, so it cannot come from a hash. A row whose descriptor is not registered
## falls back to sorted keys, which at least never varies between machines.
static func _ordered_params(provider_id: String, ace_id: String, params: Dictionary) -> Array:
	var ordered: Array = []
	var used: PackedStringArray = PackedStringArray()
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor(provider_id, ace_id)
	if descriptor != null:
		for param_entry: Variant in descriptor.params:
			if not param_entry is ACEParam:
				continue
			var param: ACEParam = param_entry as ACEParam
			var key: String = param.id if not param.id.strip_edges().is_empty() else param.name
			if key.is_empty() or not params.has(key):
				continue
			ordered.append({"key": key, "value": str(params.get(key, ""))})
			used.append(key)
	var leftovers: PackedStringArray = PackedStringArray()
	for key_entry: Variant in params.keys():
		var leftover: String = str(key_entry)
		if not used.has(leftover):
			leftovers.append(leftover)
	leftovers.sort()
	for leftover: String in leftovers:
		ordered.append({"key": leftover, "value": str(params.get(leftover, ""))})
	return ordered


## An action's or condition's parameters through both the current field and the older alias.
static func _params_of(entry: Variant) -> Dictionary:
	var params: Variant = entry.get("params")
	if params is Dictionary and not (params as Dictionary).is_empty():
		return params as Dictionary
	var alias: Variant = entry.get("parameters")
	return alias as Dictionary if alias is Dictionary else {}


## One find hit.
static func _hit(path: String, kind: String, name: String, where: String, text: String) -> Dictionary:
	return {"path": path, "kind": kind, "name": name, "where": where, "text": text}
