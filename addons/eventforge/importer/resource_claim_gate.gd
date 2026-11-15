# EventForge - the byte gate for a block kind that claims a line with a ready-made row.
#
# Loaded by path, only when a kind actually makes such a claim. A kind that returns
# {"resource": row, "consumed": n} hands the importer an instance instead of fields, so there is no
# schema to re-emit from; the gate asks the kind to write that row back out and compares it with the
# lines it consumed. A claim that does not reproduce them exactly is dropped and the lines stay a
# verbatim block, so the promise to the user's file does not depend on the kind's own care.
@tool
extends RefCounted


## The importer's row dictionary ({"row": Resource, "consumed": int}) when `kind` reproduces the lines
## it claimed starting at `index`, or {} when the claim must be dropped.
static func gate(kind: EventSheetBlockKind, claim: Dictionary, lines: PackedStringArray, index: int) -> Dictionary:
	var row: Variant = claim["resource"]
	var count: int = maxi(1, int(claim.get("consumed", 1)))
	if not (row is Resource) or index + count > lines.size():
		return {}
	var emitted: PackedStringArray = kind.emit_lines(row as Resource)
	if emitted.size() != count:
		return {}
	for offset: int in range(count):
		if emitted[offset] != lines[index + offset]:
			return {}
	return {"row": row, "consumed": count}
