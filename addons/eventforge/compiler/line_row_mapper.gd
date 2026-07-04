# EventForge - generated-line ↔ sheet-row mapping over the compiler's source map.
#
# Every compile returns a source_map: [{uid, start, end, kind}] where uid is the emitting resource's
# instance id and start/end are 1-BASED line numbers in the generated .gd. Ranges NEST (an in-flow
# block sits inside its event's range, an event inside its trigger handler's), so "which row made
# this line" means "the most specific range containing it, walking outward when an inner resource
# has vanished or has no selectable row of its own".
#
# This is the ONE shared lookup for everything that joins generated code back to sheet rows: the
# GDScript panel's click-to-select and row-highlight (the dock), and - because errors and stack
# traces arrive as line numbers - runtime-error deep-links and debugger paused-at-row. Static + pure
# over the passed source_map, so it works headless and outside the editor UI.
@tool
class_name EventSheetLineRowMapper
extends RefCounted


## All source-map entries whose range contains the 1-based line, MOST SPECIFIC FIRST (smallest range
## wins, so an in-flow block beats its event and an event beats its trigger function).
static func entries_for_line(source_map: Array, line: int) -> Array:
	var containing: Array = []
	for entry: Variant in source_map:
		if not (entry is Dictionary):
			continue
		var start: int = int((entry as Dictionary).get("start", 0))
		var end: int = int((entry as Dictionary).get("end", 0))
		if line >= start and line <= end:
			containing.append(entry)
	containing.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (int(a.get("end", 0)) - int(a.get("start", 0))) < (int(b.get("end", 0)) - int(b.get("start", 0)))
	)
	return containing


## The most specific LIVE resource whose emission contains the line (null when every containing
## entry's resource has been freed - e.g. a stale map after the undo funnel replaced the sheet).
static func resource_for_line(source_map: Array, line: int) -> Resource:
	for entry: Variant in entries_for_line(source_map, line):
		var resource: Resource = instance_from_id(int(str((entry as Dictionary).get("uid", "0")))) as Resource
		if resource != null:
			return resource
	return null


## The 1-based (start, end) line range the resource emitted, or (-1, -1) when it isn't in the map
## (not compiled, or the map is from an older compile of different resources).
static func range_for_resource(source_map: Array, resource: Resource) -> Vector2i:
	if resource == null:
		return Vector2i(-1, -1)
	var uid: String = str(resource.get_instance_id())
	for entry: Variant in source_map:
		if entry is Dictionary and str((entry as Dictionary).get("uid", "")) == uid:
			return Vector2i(int((entry as Dictionary).get("start", 0)), int((entry as Dictionary).get("end", 0)))
	return Vector2i(-1, -1)
