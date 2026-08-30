# Godot EventSheets - the collision-layer notes, anchored at the rows that earn them.
#
# The Doctor's Collision Layers section reads the project's scripts as text and files two notes
# about a NUMBER the project cannot name: a layer nobody named, and a number that is not a layer at
# all. Those sentences were written for the inbox; this file asks the very same questions of the
# lines ONE sheet row emits, so the canvas can put that row - and only that row - into the quiet
# amber state and the help strip can say the section's own sentence once the row is selected.
#
# THE QUIET SHEET LAW. Nothing here renders in the sheet. A finding sets the amber state and stops:
# the words live in the Doctor's triage inbox and in the help strip under the selected row.
#
# NO DOOR. Naming a layer is a Project Settings decision and re-pointing a row is a re-pick; neither
# is a one-property write a strip button can make for anybody, so these findings offer no fix and
# the strip shows the sentence alone.
#
# NOTHING IS STORED. Every finding is derived on every ask, and a sheet that never addresses a
# layer by number never runs a single rule.
#
# PURE + STATIC: no viewport, no dialog, no display server, so every word is pinned headless.
@tool
class_name EventSheetLayerFindings
extends RefCounted

## The two findings, by the same ids the Doctor files them under - the amber state, the help strip
## and the inbox line are one finding under three roofs.
const KIND_UNNAMED := EventSheetCollisionLayerDoctor.CHECK_UNNAMED
const KIND_NOT_A_LAYER := EventSheetCollisionLayerDoctor.CHECK_NOT_A_LAYER

const ANCHOR_EVENT := "event"


## Every layer note this sheet earns, one per row that addresses the number. `script_path` is the
## file the sheet lives in - it names the dimension (a script extending a 3D body means the 3D list
## of names) and the label the sentence leads with. A sheet with no file yet has no label to speak
## with and earns nothing rather than earning a guess.
static func findings(sheet: EventSheetResource, script_path: String = "") -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if sheet == null:
		return found
	var label_path: String = script_path if not script_path.is_empty() else str(sheet.resource_path)
	if label_path.is_empty():
		return found
	# The whole sheet is pre-read once, so a sheet that never touches a layer walks nothing.
	if not EventSheetCollisionLayerDoctor.says_enough(EventSheetCollisionFindings.all_lines(sheet)):
		return found
	var dimension: String = EventForgePhysicsLayers.dimension_for_class(
		EventForgeCollisionLayerLift.extended_class(EventSheetProjectDoctor.source_of(script_path)))
	_walk(sheet.events, label_path.get_file(), dimension, found)
	for entry: Variant in sheet.functions:
		var event_function: EventFunction = entry as EventFunction
		if event_function != null:
			_walk(event_function.events, label_path.get_file(), dimension, found)
	return found


## The findings anchored at one event row - what the canvas puts into the amber state. Matched by
## IDENTITY, so the caller never has to name a row that has no name.
static func for_event(found: Array[Dictionary], event_row: EventRow) -> Array[Dictionary]:
	var mine: Array[Dictionary] = []
	if event_row == null:
		return mine
	for entry: Dictionary in found:
		if str(entry.get("anchor", "")) == ANCHOR_EVENT and is_same(entry.get("event"), event_row):
			mine.append(entry)
	return mine


## One walk of the rows. Each row is asked about ITS OWN emitted lines only, which is what pins the
## note to the row that says the number rather than to the sheet at large; sub-events answer for
## their own lines when the walk reaches them.
static func _walk(items: Array, label: String, dimension: String,
		found: Array[Dictionary]) -> void:
	for item: Variant in items:
		if item is EventGroup:
			_walk(EventSheetGroupFacts.children(item as EventGroup), label, dimension, found)
			continue
		var event_row: EventRow = item as EventRow
		if event_row == null:
			continue
		var lines: PackedStringArray = PackedStringArray()
		for lane: Array in [event_row.conditions, event_row.actions]:
			for entry: Variant in lane:
				if entry is Resource:
					lines.append(EventSheetSpawnFindings.emitted_lines(entry))
		for note: Dictionary in EventSheetCollisionLayerDoctor.line_findings(
				label, dimension, "\n".join(lines)):
			found.append({
				"kind": str(note.get("check", "")), "severity": str(note.get("severity", "")),
				"anchor": ANCHOR_EVENT, "event": event_row,
				"subject": str(note.get("subject", "")), "message": str(note.get("message", "")),
				"fix": "", "fix_label": "", "layer": int(note.get("layer", 0)),
			})
		_walk(event_row.sub_events, label, dimension, found)
