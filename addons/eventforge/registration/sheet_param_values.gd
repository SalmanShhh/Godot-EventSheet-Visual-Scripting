# EventForge - what a sheet's rows have typed into one KIND of field.
#
# Several facts about a sheet are the same question asked of a different hint: which animations does
# it play, which groups does it name, which input actions does it use. Each of those used to mean a
# walk of events, groups and functions written again beside the fact that wanted it - the same
# fifteen lines, four times, each with its own idea of whether a function's rows count.
#
# One walk answers all of them: give it the hint and it hands back every value any row holds in a
# parameter carrying that hint, in sheet order, with the row it came from. What a caller does with
# the values is the caller's business; finding them is not.
#
# PURE + STATIC: a sheet in, plain Dictionaries out. Reads the shipped descriptors for the hints, so
# a pack's own hint is answered exactly as a builtin one is.
@tool
class_name EventForgeSheetParamValues
extends RefCounted


## Every value the sheet's rows hold in a parameter of one hint, as
##   {"value", "param", "provider_id", "ace_id", "event"}
## in sheet order - the sheet's own events first, then its functions'. A row whose verb this build
## has no descriptor for contributes nothing rather than a guess.
static func of_hint(sheet: EventSheetResource, hint: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if sheet == null or hint.strip_edges().is_empty():
		return found
	_walk(sheet.events, hint, found)
	for entry: Variant in sheet.functions:
		var event_function: EventFunction = entry as EventFunction
		if event_function != null:
			_walk(event_function.events, hint, found)
	return found


## The distinct values of one hint, first mention first - the form a band or a picker wants, where
## the same animation played by six rows is one name.
static func distinct(sheet: EventSheetResource, hint: String) -> PackedStringArray:
	var values: PackedStringArray = PackedStringArray()
	for entry: Dictionary in of_hint(sheet, hint):
		var value: String = str(entry.get("value", "")).strip_edges()
		if not value.is_empty() and not values.has(value):
			values.append(value)
	return values


## The rows of one list, groups walked into. A group's rows are the sheet's rows - it is a bracket
## around them, not another sheet - so a fact about the sheet counts them.
static func _walk(items: Array, hint: String, found: Array[Dictionary]) -> void:
	for item: Variant in items:
		if item is EventGroup:
			_walk((item as EventGroup).child_rows(), hint, found)
			continue
		var event_row: EventRow = item as EventRow
		if event_row == null:
			continue
		for entry: Variant in event_row.conditions:
			_collect(entry as Resource, hint, event_row, found)
		for entry: Variant in event_row.actions:
			_collect(entry as Resource, hint, event_row, found)
		_walk(event_row.sub_events, hint, found)


## One row's values for the hint. The descriptor says which parameters carry it; the row says what
## is in them.
static func _collect(ace: Resource, hint: String, event_row: EventRow, found: Array[Dictionary]) -> void:
	if ace == null:
		return
	var provider_id: String = str(ace.get("provider_id"))
	var ace_id: String = str(ace.get("ace_id"))
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor(provider_id, ace_id)
	if descriptor == null:
		return
	var params: Dictionary = ace.get("params") if ace.get("params") is Dictionary else {}
	for entry: Variant in descriptor.params:
		var param: ACEParam = entry as ACEParam
		if param == null or param.hint != hint:
			continue
		found.append({
			"value": str(params.get(param.id, param.default_value)),
			"param": param.id,
			"provider_id": provider_id,
			"ace_id": ace_id,
			"event": event_row,
		})
