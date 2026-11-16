@tool
extends RefCounted

# The facts behind the head's migration band, read off the rows: how many rows are written in a
# spelling the vocabulary has replaced, and how many ask somebody for a decision. The second count has
# two sources, a verb the vocabulary no longer has at all (the migration findings) and a verb it
# still has but retired with nothing to take its place - both are rows the Migrate window lists as
# left alone, so both are rows the band must be there for. Loaded by path from the row builder, which
# is on the boot path.


## The band's facts for one sheet: `builder` is the row builder that is walking it.
static func facts(builder: RefCounted, sheet: EventSheetResource, gone_findings: Array[Dictionary]) -> Dictionary:
	var asking_events: Array = []
	for entry: Dictionary in gone_findings:
		var event_row: Variant = entry.get("event")
		if event_row != null and not asking_events.has(event_row):
			asking_events.append(event_row)
	var retired: int = _count_retired(builder, sheet.events, asking_events)
	for function: Variant in sheet.functions:
		if function != null and function.get("events") is Array:
			retired += _count_retired(builder, function.get("events") as Array, asking_events)
	return EventForgeVocabularyRecord.band_facts(builder._rows_with_a_newer_spelling(sheet), asking_events.size() + retired)


## Events holding a retired verb, following groups and sub-events down. An event already counted as
## asking (it holds a verb that is gone) is not counted twice.
static func _count_retired(builder: RefCounted, rows: Array, already_asking: Array) -> int:
	var counted: int = 0
	for row: Variant in rows:
		if row is EventRow:
			var event_row: EventRow = row
			if not already_asking.has(event_row) and _holds_retired_verb(builder, event_row):
				counted += 1
			counted += _count_retired(builder, event_row.sub_events, already_asking)
		elif row != null and row.get("events") is Array:
			counted += _count_retired(builder, row.get("events") as Array, already_asking)
	return counted


## A retired verb is one the vocabulary flags as deprecated and gives no forwarding address.
static func _holds_retired_verb(builder: RefCounted, event_row: EventRow) -> bool:
	for candidate: Array in builder._successor_candidates(event_row):
		var here: ACEDefinition = builder._viewport._find_definition(str(candidate[0]), str(candidate[1]))
		if here != null and bool(here.metadata.get("deprecated", false)) and EventForgeSuccessors.map_of(here).is_empty():
			return true
	return false
