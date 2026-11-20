@tool
extends RefCounted

# The facts behind the head's migration band, read off the rows: how many rows are written in a
# spelling the vocabulary has replaced, and how many ask somebody for a decision. The second count has
# two sources, a verb the vocabulary no longer has at all (the migration findings) and a verb it
# still has but retired with nothing to take its place - both are rows the Migrate window lists as
# left alone, so both are rows the band must be there for. Loaded by path from the row builder, which
# is on the boot path.


## The band's facts for one sheet: `builder` is the row builder that is walking it. Both counts are
## ROWS (a condition, an action or a trigger), the unit the Migrate window lists and the Doctor's
## per-sheet line counts, so the head, the window and the Doctor say the same number.
static func facts(builder: RefCounted, sheet: EventSheetResource, gone_findings: Array[Dictionary]) -> Dictionary:
	var retired: int = _count_retired(builder, sheet.events)
	for function: Variant in sheet.functions:
		if function != null and function.get("events") is Array:
			retired += _count_retired(builder, function.get("events") as Array)
	return EventForgeVocabularyRecord.band_facts(builder._rows_with_a_newer_spelling(sheet),
		EventSheetMigrationFindings.rows_asking(gone_findings) + retired)


## Rows holding a retired verb, following groups and sub-events down. A row whose verb is gone from
## the vocabulary has no definition to be retired in, so it is never counted here as well.
static func _count_retired(builder: RefCounted, rows: Array) -> int:
	var counted: int = 0
	for row: Variant in rows:
		if row is EventRow:
			var event_row: EventRow = row
			counted += _retired_rows_in(builder, event_row)
			counted += _count_retired(builder, event_row.sub_events)
		elif row != null and row.get("events") is Array:
			counted += _count_retired(builder, row.get("events") as Array)
	return counted


## How many of one event's own rows hold a retired verb. A retired verb is one the vocabulary flags as
## deprecated and gives no forwarding address.
static func _retired_rows_in(builder: RefCounted, event_row: EventRow) -> int:
	var counted: int = 0
	for candidate: Array in builder._successor_candidates(event_row):
		var here: ACEDefinition = builder._viewport._find_definition(str(candidate[0]), str(candidate[1]))
		if here != null and bool(here.metadata.get("deprecated", false)) and EventForgeSuccessors.map_of(here).is_empty():
			counted += 1
	return counted
