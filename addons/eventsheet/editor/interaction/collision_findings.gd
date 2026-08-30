# Godot EventSheets - the four ways a collision row is right and still never runs.
#
# Every one of these is silent. The row is correct, the sheet compiles, the game starts, and the
# trigger never fires - because the answer is in the `.tscn` and the question was asked in the `.gd`:
#
#   nothing can reach it   - the trigger waits on a touch, and the node's mask does not cover the
#                            layer the bodies it is waiting for actually sit on. Named by LAYER, so
#                            the sentence says which tick box is missing.
#   monitoring is off      - the Area's own switch is off. Every mask is right, every layer is right,
#                            and Godot never emits the signal at all.
#   it has no shape        - a collision object with no CollisionShape child has no extent. Godot
#                            says so in the Scene dock; nothing said it to the sheet that depends on
#                            it, which is where the row was written.
#   the one-way faces down - a one-way platform turned over lets bodies through from above and stops
#                            them from below, which is the opposite of what a platform is for.
#
# THE QUIET SHEET LAW. None of this renders in the sheet. A finding puts the affected row into the
# quiet amber state and stops: no note row, no icon, no inline sentence, nothing at all on a sheet
# with nothing wrong. The WORDS live in two places a reader goes on purpose - the Doctor's triage
# inbox, and the help strip under the row once the row is selected. A sheet is a place to read what
# the game does, not a place to be told off in.
#
# THE SCENE IS THE AUTHORITY AND THE SHEET IS THE QUESTION. Everything about layers, masks, switches
# and shapes is read through EventSheetSceneCollisionFacts, which reads the project's ONE parse of
# scene text; everything about what the sheet is waiting for is read off the rows. Neither half
# guesses at the other's.
#
# NOTHING IS STORED. Every finding is derived on every ask, so a fixed sheet stops reporting with
# nothing to clean up, and a sheet with no touch trigger and no named collidable never runs a single
# rule - which is the gate that keeps a project that does not think about collision exactly as it was.
#
# PURE + STATIC: no viewport, no dialog, no display server, so every word is pinned headless.
@tool
class_name EventSheetCollisionFindings
extends RefCounted

## The four findings, by id. Frozen: the amber state, the help strip, the Doctor and the tests all
## address one by these.
const KIND_CANNOT_SEE := "nothing-can-reach-it"
const KIND_MONITORING_OFF := "monitoring-off"
const KIND_NO_SHAPE := "no-collision-shape"
const KIND_ONE_WAY_FACING := "one-way-faces-down"

## The doors a finding offers. Two of them write one property of the scene, with the receipt either
## side of it; the third only takes the reader to the node, because "add a shape" is a decision about
## the game's geometry and no tool can make it for anybody.
const FIX_SEE_THE_LAYER := "see_the_layer"
const FIX_MONITORING_ON := "turn_monitoring_on"
const FIX_SHOW_IN_SCENE := "show_in_scene"

## Where a finding hangs. Three of the four are about a row, so they anchor at the event that holds
## it; a sheet whose node has no shape and no touch trigger has nothing to point at, and says so
## against the sheet instead of picking a row at random.
const ANCHOR_EVENT := "event"
const ANCHOR_SHEET := "sheet"

## WHICH TRIGGERS WAIT ON A TOUCH is asked of the vocabulary itself rather than listed here. A list
## is a copy, and a copy of this one went stale the moment the filtered and edge triggers shipped:
## the four bare ids were all it held, so writing the flagship sentence ("On overlap with enemies")
## instead of a bare trigger plus a group question switched every rule in this file off - no amber
## state, no help strip, no line in the Doctor, on the sheet most likely to have the bug.
##
## EventForgeCollisionFilters is where the census lives, because "is this row about a touch" is a
## question about MEANING and that file is the one place the meaning of these ids is written down.
## A trigger added to that vocabulary tomorrow is watched by these rules the day it ships.
const TouchTriggers := preload("res://addons/eventforge/registration/collision_filters.gd")

## The condition that filters a touch trigger by group, and the parameter holding the group's name.
## This is the ONE table in the file, and it is here because a group filter is a row somebody chose:
## the rule cannot derive which condition means "only the enemies" from the emitted line, since the
## line it compiles to is a plain `is_in_group` that any row could have written. The filtered
## triggers' own With field is read beside it - same question, asked on the trigger instead of under
## it - which is why both readings meet in _groups_filtered_by rather than in two rules.
const GROUP_FILTER_ACE_IDS: PackedStringArray = ["IsInGroup"]
const GROUP_FILTER_PARAM := "group"

## The ways a sheet asks whether something LANDED on a surface: the engine's own standing question,
## and the two calls the floor edge rows compile to. What turns a one-way platform's facing from a
## fact into a contradiction is a sheet asking one of these beside an upside-down one-way shape - a
## sheet waiting for a landing that cannot happen.
##
## A one-way shape turned over is not a fault on its own: a wall that only blocks from one side is
## turned deliberately every day. So this is the whole gate on that rule, and a sheet that never asks
## about landing hears nothing about the facing of anything.
const LANDING_WORDS: PackedStringArray = ["is_on_floor", "__just_landed_", "__just_left_the_ground_"]

## The two properties a sheet changes when it decides at RUN TIME what it collides with - the layer
## it sits on and the mask it watches. Both bare names, because every spelling that writes them
## contains one: `set_collision_mask_value(3, true)` (which is what the Collide With Layer row
## emits), `set_collision_layer_value`, and the plain `collision_mask = 6` a hand-written line uses.
##
## A sheet that writes either of them has told the truth about itself and the `.tscn` has not: the
## numbers in the scene file are where the node STARTS, not what it watches while the game runs. So
## the dead-trigger rule stands down for that sheet rather than accusing the very rows this
## vocabulary teaches people to write.
const LAYER_WRITE_WORDS: PackedStringArray = ["collision_mask", "collision_layer"]


## Every finding this sheet earns, in the order the rules run. `script_path` is what resolves the
## sheet's own node in the scene that runs it - a sheet nobody passed one for never earns a finding
## rather than earning a guess. `scenes` is the corpus the project-wide questions are asked of, and
## an empty one means the project's own, which is what the editor always passes.
static func findings(sheet: EventSheetResource, script_path: String = "",
		scenes: PackedStringArray = PackedStringArray()) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if sheet == null:
		return found
	var own: Array[Dictionary] = EventSheetSceneCollisionFacts.for_script(script_path)
	if own.is_empty():
		return found
	var events: Array[Dictionary] = touch_events(sheet)
	var lines: String = all_lines(sheet)
	var sets_its_own_layers: bool = writes_its_own_layers(lines)
	for collidable: Dictionary in own:
		if not sets_its_own_layers:
			_nothing_can_reach_it(collidable, events, scenes, found)
		_monitoring_is_off(collidable, events, found)
		_it_has_no_shape(collidable, events, found)
		_the_one_way_faces_down(collidable, events, lines, found)
	return found


## The findings anchored at one event row - what the canvas puts into the amber state, and what the
## help strip says once that row is selected. Matched by IDENTITY, so the caller never has to name a
## row that has no name.
static func for_event(found: Array[Dictionary], event_row: EventRow) -> Array[Dictionary]:
	var mine: Array[Dictionary] = []
	if event_row == null:
		return mine
	for entry: Dictionary in found:
		if str(entry.get("anchor", "")) == ANCHOR_EVENT and entry.get("event") == event_row:
			mine.append(entry)
	return mine


## The one sentence a selected row's help strip says about it, "" when the row has nothing wrong.
## Several findings on one row read as one strip, joined the way the sheet joins facts elsewhere.
static func strip_text(found: Array[Dictionary], event_row: EventRow) -> String:
	var said: PackedStringArray = PackedStringArray()
	for entry: Dictionary in for_event(found, event_row):
		said.append(str(entry.get("message", "")))
	return " · ".join(said)


## Every event of the sheet that waits on a touch, with what the walk saw about it: the trigger, the
## groups its conditions filter by, and the event row itself. ONE walk, four rules.
static func touch_events(sheet: EventSheetResource) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if sheet == null:
		return events
	_walk(sheet.events, events)
	for entry: Variant in sheet.functions:
		var event_function: EventFunction = entry as EventFunction
		if event_function != null:
			_walk(event_function.events, events)
	return events


## Everything the sheet's rows compile to, joined - what the rules that ask "does this sheet ever
## mention it" read. One walk of the whole sheet, because four rules asking separately would be four
## walks for one answer.
static func all_lines(sheet: EventSheetResource) -> String:
	var written: PackedStringArray = PackedStringArray()
	_collect_lines(sheet.events, written)
	for entry: Variant in sheet.functions:
		var event_function: EventFunction = entry as EventFunction
		if event_function != null:
			_collect_lines(event_function.events, written)
	return "\n".join(written)


## True when the sheet's own rows change the layer it sits on or the mask it watches. The scene file
## is then the STARTING position rather than the answer, and no rule here may say what this node can
## reach - a sheet whose first action is "Collide with Enemies" is right, and telling it that nothing
## can reach its trigger is the check crying wolf at the code the vocabulary taught.
## True when the sheet asks, anywhere in it, whether something is standing on a floor. The one
## question that makes a turned-over one-way shape a contradiction rather than a choice.
static func asks_about_landing(lines: String) -> bool:
	for word: String in LANDING_WORDS:
		if lines.contains(word):
			return true
	return false


static func writes_its_own_layers(lines: String) -> bool:
	for word: String in LAYER_WRITE_WORDS:
		if lines.contains(word):
			return true
	return false


# -- The four rules ------------------------------------------------------------------------------


## A touch trigger whose node cannot see the layer the bodies it waits for are on. Two readings of
## "the bodies it waits for", and the finding says which one it used: a group-filtered trigger is
## measured against the layers that group's members really sit on, and a bare one against every layer
## anything at all sits on - which is weaker, so the sentence says so.
static func _nothing_can_reach_it(collidable: Dictionary, events: Array[Dictionary],
		scenes: PackedStringArray, found: Array[Dictionary]) -> void:
	var dimension: String = str(collidable.get("dimension", EventForgePhysicsLayers.DIMENSION_2D))
	var mask: int = int(collidable.get("mask_bits", 0))
	var seen: Dictionary = {}
	for event: Dictionary in events:
		var groups: PackedStringArray = event.get("groups", PackedStringArray())
		var wanted: int = 0
		var named_group: String = ""
		for group_name: String in groups:
			var bits: int = EventSheetSceneCollisionFacts.group_bits(group_name, dimension, scenes)
			if bits != 0 and named_group.is_empty():
				# The BARE word, not the row's GDScript spelling of it: a sentence saying
				# `""enemies""` is a sentence about the quotation marks.
				named_group = EventSheetSceneCollisionFacts.group_word(group_name)
			wanted |= bits
		# A group with no collidables in it at all is a group this cannot judge - the members may be
		# spawned at run time - so the trigger falls back to the weaker project-wide reading rather
		# than being reported against an empty answer.
		if wanted == 0:
			wanted = EventSheetSceneCollisionFacts.occupied_bits(dimension, scenes)
			named_group = ""
		if wanted == 0 or mask & wanted != 0:
			continue
		var subject: String = "%s|%s" % [str(collidable.get("name", "")), named_group]
		if seen.has(subject):
			continue
		seen[subject] = true
		var layer_words: String = EventSheetSceneCollisionFacts.all_words_for_bits(wanted, dimension)
		var message: String = ""
		if named_group.is_empty():
			message = EventSheetL10n.translate("%s watches %s, and everything in this project that can collide sits on %s - so nothing can reach this trigger. This reads every layer in use, because the trigger names no group.") % [
				str(collidable.get("name", "")),
				EventSheetSceneCollisionFacts.all_words_for_bits(mask, dimension), layer_words]
		else:
			message = EventSheetL10n.translate("%s watches %s, and the members of \"%s\" sit on %s - so this trigger never fires.") % [
				str(collidable.get("name", "")),
				EventSheetSceneCollisionFacts.all_words_for_bits(mask, dimension),
				named_group, layer_words]
		var first_layer: int = EventSheetSceneCollisionFacts.layer_numbers(wanted)[0]
		var finding: Dictionary = _finding(KIND_CANNOT_SEE, "warning", event.get("event") as EventRow,
			subject, message, FIX_SEE_THE_LAYER,
			EventSheetL10n.translate("Watch %s") % EventForgePhysicsLayers.words_for(first_layer, dimension),
			collidable)
		finding["layer"] = first_layer
		found.append(finding)


## An Area whose own switch is off, in a sheet that waits on its touches. Nothing about the mask or
## the layers matters while this is false: Godot emits no signal at all.
static func _monitoring_is_off(collidable: Dictionary, events: Array[Dictionary],
		found: Array[Dictionary]) -> void:
	if not bool(collidable.get("is_area", false)) or bool(collidable.get("monitoring", true)):
		return
	if events.is_empty():
		return
	found.append(_finding(KIND_MONITORING_OFF, "warning", events[0].get("event") as EventRow,
		str(collidable.get("name", "")),
		EventSheetL10n.translate("%s has monitoring switched off in the scene, so it reports no touches at all - every row waiting on one here is unreachable.") % str(collidable.get("name", "")),
		FIX_MONITORING_ON, EventSheetL10n.translate("Switch monitoring on"), collidable))


## A collision object with no shape under it. This is Godot's OWN configuration warning, carried to
## the sheet that depends on the node: the Scene dock shows it beside a node nobody is looking at
## while the row that needs it is being written somewhere else.
static func _it_has_no_shape(collidable: Dictionary, events: Array[Dictionary],
		found: Array[Dictionary]) -> void:
	if bool(collidable.get("has_shape", false)):
		return
	var anchor: EventRow = _first_event(events)
	found.append(_finding(KIND_NO_SHAPE, "warning", anchor, str(collidable.get("name", "")),
		EventSheetL10n.translate("%s has no shape, so it cannot collide or interact with anything. Add a CollisionShape or a CollisionPolygon under it in the scene.") % str(collidable.get("name", "")),
		FIX_SHOW_IN_SCENE, EventSheetL10n.translate("Show me in the scene"), collidable))


## A one-way shape turned over. One-way collision blocks from ONE side, and the side is the shape's
## own upright: a shape rotated past a quarter turn blocks from underneath, so a body lands nowhere
## and falls straight through. Advisory, because a shape can be turned on purpose - so it is only
## said at all when the sheet is plainly expecting the landing that cannot happen.
static func _the_one_way_faces_down(collidable: Dictionary, events: Array[Dictionary],
		lines: String, found: Array[Dictionary]) -> void:
	# The gate is the sentence: this is only said where the sheet is plainly expecting the landing
	# the shape blocks. Admitting any sheet with a touch trigger admitted sheets with no landing
	# question anywhere in them, and then told them their rows were waiting for one.
	if not asks_about_landing(lines):
		return
	var anchor: EventRow = _first_event(events)
	for shape: Variant in collidable.get("one_way", []) as Array:
		var one_way: Dictionary = shape
		if not bool(one_way.get("faces_down", false)):
			continue
		found.append(_finding(KIND_ONE_WAY_FACING, "info", anchor,
			"%s|%s" % [str(collidable.get("name", "")), str(one_way.get("name", ""))],
			EventSheetL10n.translate("%s is one-way and turned over, so bodies fall through it from above and are stopped from below. The rows here are waiting for the landing it blocks.") % str(one_way.get("name", "")),
			FIX_SHOW_IN_SCENE, EventSheetL10n.translate("Show me in the scene"), collidable))


# -- What the sheet says --------------------------------------------------------------------------


## Every event that waits on a touch, with the groups its own conditions filter by. Recursive,
## because a sub-event runs inside its parent's handler: the trigger that reaches it is the parent's,
## and the parent's group filter is its filter too.
static func _walk(items: Array, into: Array[Dictionary], trigger_id: String = "",
		groups: PackedStringArray = PackedStringArray()) -> void:
	for item: Variant in items:
		if item is EventGroup:
			_walk(EventSheetGroupFacts.children(item as EventGroup), into, trigger_id, groups)
			continue
		var event_row: EventRow = item as EventRow
		if event_row == null:
			continue
		var reached_by: String = event_row.trigger_id.strip_edges()
		if reached_by.is_empty():
			reached_by = trigger_id
		var filtered: PackedStringArray = groups.duplicate()
		for group_name: String in _groups_filtered_by(event_row):
			if not filtered.has(group_name):
				filtered.append(group_name)
		if TouchTriggers.is_touch_trigger(reached_by):
			into.append({"event": event_row, "trigger": reached_by, "groups": filtered})
		_walk(event_row.sub_events, into, reached_by, filtered)


## The event a finding with no row of its own hangs on: the sheet's first touch trigger, or null when
## the sheet has none - which is the state that files the finding against the sheet instead.
static func _first_event(events: Array[Dictionary]) -> EventRow:
	return null if events.is_empty() else events[0].get("event") as EventRow


## The groups one event filters its trigger by, in row order - from BOTH places a sheet can say it.
## A bare trigger says it in a group question underneath; a filtered trigger says it in its own With
## field, and that is the sentence the picker offers first. Read from one only, the flagship row
## measures against every layer in the project instead of against the layers its group really sits
## on, which is the weaker reading and the wrong one.
static func _groups_filtered_by(event_row: EventRow) -> PackedStringArray:
	var groups: PackedStringArray = PackedStringArray()
	var on_the_trigger: String = TouchTriggers.group_of(event_row)
	if not on_the_trigger.is_empty():
		groups.append(on_the_trigger)
	for entry: Variant in event_row.conditions:
		var condition: Resource = entry as Resource
		if condition == null or not GROUP_FILTER_ACE_IDS.has(str(condition.get("ace_id"))):
			continue
		var params: Variant = condition.get("params")
		if not (params is Dictionary):
			continue
		var written: String = str((params as Dictionary).get(GROUP_FILTER_PARAM, "")).strip_edges()
		if not written.is_empty() and not groups.has(written):
			groups.append(written)
	return groups


## Every line the rows of one list compile to, appended in row order. The emitted line is read
## through the spawning family's reader rather than through a copy of it, because "what does this row
## write" has exactly one right answer and two of them would be one too many.
static func _collect_lines(items: Array, into: PackedStringArray) -> void:
	for item: Variant in items:
		if item is EventGroup:
			_collect_lines(EventSheetGroupFacts.children(item as EventGroup), into)
			continue
		var event_row: EventRow = item as EventRow
		if event_row == null:
			continue
		for lane: Array in [event_row.conditions, event_row.actions]:
			for entry: Variant in lane:
				if entry is Resource:
					into.append(EventSheetSpawnFindings.emitted_lines(entry))
		_collect_lines(event_row.sub_events, into)


## One finding, with every key its three readers address filled in. `scene` and `node` are how a door
## finds the node again in the scene the fact came from.
static func _finding(kind: String, severity: String, event_row: EventRow, subject: String,
		message: String, fix: String, fix_label: String, collidable: Dictionary) -> Dictionary:
	return {
		"kind": kind, "severity": severity,
		"anchor": ANCHOR_EVENT if event_row != null else ANCHOR_SHEET,
		"event": event_row, "subject": subject, "message": message,
		"fix": fix, "fix_label": fix_label,
		"scene": str(collidable.get("scene_path", "")),
		"node": str(collidable.get("path", "")),
		"node_name": str(collidable.get("name", "")),
		"dimension": str(collidable.get("dimension", "")),
		"layer": 0,
	}
