# Godot EventSheets - the scene-trust note, anchored at the row that earns it.
#
# The Doctor's Files section reads the project's scripts as text and files one warning about a scene
# built from a file the game did not ship with. That sentence was written for the inbox; this file
# asks the very same question of the rows of ONE sheet, so the canvas can put that event - and only
# that event - into the quiet amber state, and the help strip can say the section's own sentence once
# the row is selected.
#
# THE QUIET SHEET LAW. Nothing here renders in the sheet. A finding sets the amber state and stops:
# no note row, no icon, no inline sentence, no hover. The words live in the Doctor's triage inbox and
# in the help strip under the selected row, and a sheet with nothing wrong says nothing at all.
#
# THE DOOR IS THE QUESTION ITSELF. Unlike the outside-content finding beside it in the same section,
# this one has a one-click answer, because the file is named in the line and the answer is a row that
# ships: Scene File Is Data-Only, over that same file, put in FRONT of the questions the event
# already asks. It is an ordinary condition row afterwards - visible, editable, deletable, a plain
# `if` on disk - which is the same rule the removal guard and the still-here guard state about
# themselves. Nothing is added behind the row.
#
# THE GUARD IS COUNTED BY THE CALL IT COMPILES TO, not by an ace_id, so a question somebody typed by
# hand into a verbatim block counts exactly as the picked row does. And a question asked by a PARENT
# event stands over the rows beneath it, because that is what the emitted `if` inside an `if` really
# does - the Doctor's own reading walks the same blocks outwards for the same reason.
#
# NOTHING IS STORED. Every finding is derived on every ask, so a sheet that has been guarded stops
# reporting with no state to clean up, and a sheet that never builds a scene runs no rule at all.
#
# PURE + STATIC: no viewport, no dialog, no display server, so every word is pinned headless.
@tool
class_name EventSheetSceneTrustFindings
extends RefCounted

## The one finding, by the same id the Doctor files it under - the amber state, the help strip and
## the inbox line are one finding under three roofs.
const KIND_UNTRUSTED_SCENE := EventSheetFilesDoctor.CHECK_UNTRUSTED_SCENE

## Where the note hangs. The finding is about a row inside an event, so it anchors at the event -
## the same anchor the spawning and networking notes use for the same reason.
const ANCHOR_EVENT := "event"

## The one-click answer, by the id the dock's door and the inbox chip both dispatch on.
const FIX_ASK_FIRST := "ask_whether_it_is_data"

## How many questions one gesture will write before it stops. A sheet needing more than this is a
## sheet whose loads want reading rather than a chip pressed once more, and a repair that cannot end
## is worse than one that stops and says so.
const GUARD_CEILING: int = 64


## Every scene-trust note this sheet earns, one per event that builds a scene nobody asked about.
## `script_path` is the file the sheet lives in and is only the label the sentence leads with; a
## sheet with no file yet leads with nothing rather than with a guess.
static func findings(sheet: EventSheetResource, script_path: String = "") -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if sheet == null:
		return found
	var label_path: String = script_path if not script_path.is_empty() else str(sheet.resource_path)
	var label: String = label_path.get_file()
	_walk(sheet.events, label, PackedStringArray(), found)
	for entry: Variant in sheet.functions:
		var event_function: EventFunction = entry as EventFunction
		if event_function != null:
			_walk(_function_rows(event_function), label, PackedStringArray(), found)
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


## What asking the question first WOULD do to this sheet, as before/after pairs: the file the event
## builds, and the question it would ask about it. The reading the inbox chip shows before the reader
## is told anything worked, so a count is never the whole receipt.
static func receipt(sheet: EventSheetResource) -> Array[Dictionary]:
	var pairs: Array[Dictionary] = []
	for finding: Dictionary in findings(sheet):
		pairs.append({
			"before": str(finding.get("subject", "")),
			"after": "%s(%s)" % [EventForgeSceneTrust.HELPER_NAME, str(finding.get("subject", ""))],
		})
	return pairs


## The same events, with the question put in front of the ones they already ask. Returns how many
## events really gained one, so a caller reports only real work.
##
## THE FINDINGS ARE RE-READ AFTER EVERY INSERT, because inserting one question changes the answer for
## every row under it: an event that builds two files needs two questions, and an event whose parent
## has just been guarded needs none. Reading once and writing the whole list would ask the same
## question twice on the same event.
static func guard_scene_loads(sheet: EventSheetResource) -> int:
	var written: int = 0
	while written < GUARD_CEILING:
		var found: Array[Dictionary] = findings(sheet)
		if found.is_empty():
			break
		if not ask_first(found[0]):
			break
		written += 1
	return written


## One finding's answer: the data-only question about that finding's own file, in FRONT of the
## questions its event already asks - a question asked after something has already been built is a
## question asked too late. False when there is nothing to write, which is how the caller above ends.
static func ask_first(finding: Dictionary) -> bool:
	var event_row: EventRow = finding.get("event", null) as EventRow
	var path_expression: String = str(finding.get("subject", "")).strip_edges()
	if event_row == null or path_expression.is_empty():
		return false
	if EventForgeSceneTrust.guarded_paths(_conditions_text(event_row)).has(path_expression):
		return false
	var guard: ACECondition = ACECondition.new()
	guard.provider_id = "Core"
	guard.ace_id = EventForgeSceneTrust.GUARD_ACE_ID
	guard.params = {EventForgeSceneTrust.GUARD_PARAM: path_expression}
	event_row.conditions.insert(0, guard)
	return true


## One row's emitted code with its own values filled in - the text every rule here reads. A row's
## BAKED template is preferred over its descriptor's, because the baked copy is the one whose `{uid}`
## was filled in when the row was applied; a row built in memory (which is what a test does) falls
## back to the descriptor's. A verbatim block is its own code and is read exactly as written, which
## is what lets a load somebody typed by hand earn the same note as a picked row.
static func emitted_text(entry: Variant) -> String:
	if entry is RawCodeRow:
		return (entry as RawCodeRow).code
	var ace: Resource = entry as Resource
	if ace == null:
		return ""
	var baked: String = str(ace.get("codegen_template"))
	var text: String = baked
	if text.strip_edges().is_empty():
		var descriptor: ACEDescriptor = ACERegistry.find_descriptor(
			str(ace.get("provider_id")), str(ace.get("ace_id")))
		text = "" if descriptor == null else descriptor.codegen_template
	var params: Variant = ace.get("params")
	if params is Dictionary:
		for key: Variant in (params as Dictionary).keys():
			text = text.replace("{%s}" % str(key), str((params as Dictionary)[key]))
	return text


## One walk of the rows. `asked` is every scene file the events ABOVE this one already ask about,
## which is what makes a question on a parent event stand over the rows beneath it.
static func _walk(items: Array, label: String, asked: PackedStringArray,
		found: Array[Dictionary]) -> void:
	for item: Variant in items:
		if item is EventGroup:
			_walk(EventSheetGroupFacts.children(item as EventGroup), label, asked, found)
			continue
		var event_row: EventRow = item as EventRow
		if event_row == null:
			continue
		var here: PackedStringArray = asked.duplicate()
		for path_expression: String in EventForgeSceneTrust.guarded_paths(
				_conditions_text(event_row)):
			if not here.has(path_expression):
				here.append(path_expression)
		_note_this_event(event_row, label, here, found)
		_walk(event_row.sub_events, label, here, found)


## The findings ONE event earns: one per scene file it builds that nothing around it asks about. The
## same file built twice by two rows of one event is one note, because it is one thing to fix.
static func _note_this_event(event_row: EventRow, label: String, asked: PackedStringArray,
		found: Array[Dictionary]) -> void:
	var unasked: PackedStringArray = PackedStringArray()
	var first_line: Dictionary = {}
	for entry: Variant in event_row.actions:
		for line: String in emitted_text(entry).split("\n"):
			var text: String = line.strip_edges()
			for path_expression: String in EventForgeSceneTrust.untrusted_scene_paths(text):
				if asked.has(path_expression) or unasked.has(path_expression):
					continue
				unasked.append(path_expression)
				first_line[path_expression] = text
	for path_expression: String in unasked:
		found.append({
			"kind": KIND_UNTRUSTED_SCENE, "severity": "warning",
			"anchor": ANCHOR_EVENT, "event": event_row,
			"subject": path_expression,
			"message": EventSheetFilesDoctor.untrusted_scene_message(label,
				str(first_line[path_expression]), 1),
			"fix": FIX_ASK_FIRST,
			"fix_label": EventSheetL10n.translate("Ask whether it is data first"),
		})


## Every line one event's QUESTIONS compile to, joined - what the guard is counted off. Conditions
## only: a question asked in the action lane would be asked after the build it was meant to stand in
## front of.
static func _conditions_text(event_row: EventRow) -> String:
	var lines: PackedStringArray = PackedStringArray()
	for entry: Variant in event_row.conditions:
		lines.append(emitted_text(entry))
	return "\n".join(lines)


## One function's rows. A function built by the editor holds `events`; one lifted out of a
## hand-written file may hold `rows` instead, and every walk in this plugin reads both - a reader
## that read one of them would go quiet on exactly the files this plugin is for.
static func _function_rows(event_function: EventFunction) -> Array:
	return event_function.events if not event_function.events.is_empty() else event_function.rows
