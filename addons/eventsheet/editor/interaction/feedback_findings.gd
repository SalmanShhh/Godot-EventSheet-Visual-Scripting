# Godot EventSheets - the one thing a row about a feedback can get wrong: a label nobody has.
#
# Every row on a Feedback Player addresses one card by its LABEL - the name typed on it in the
# Inspector, or, for a card nobody named, its own word. That is what makes a list tuned in the
# Inspector and a list retuned by rows agree about which step is meant, and it is also the one place
# the two can silently drift apart: rename a card and the row that named it goes on compiling, goes
# on running, and does nothing at all.
#
# So the mistake is found where it can be fixed - in the editor, against the scene the sheet's script
# actually runs in. The evidence is the scene's own saved bytes: a Feedback Player in it holds its
# list as a plain property, so the labels are read out of the packed scene without instancing
# anything and without a game running.
#
# THE QUIET SHEET LAW. Nothing here renders in the sheet. A finding sets the amber state on the row
# that names the label and stops: the words live in the Doctor's triage inbox and in the row's help
# strip once it is selected.
#
# NO DOOR. The fix is either a rename in the Inspector or a different label in the row, and neither
# is a one-property write a strip button can make on somebody's behalf - so the finding offers no
# fix and the strip shows the sentence alone.
#
# EVIDENCE, NOT SUSPICION. A sheet whose script no scene runs, or a scene with no Feedback Player in
# it, earns NOTHING: without a list to hold the row up against there is no way to know the label is
# wrong, and a finding that fires on no evidence is noise the reader learns to skip.
#
# NOTHING IS STORED. Every finding is derived on every ask, so a fixed label stops reporting with
# nothing to clean up.
#
# PURE + STATIC: no viewport, no dialog, no display server, so every word is pinned headless.
@tool
class_name EventSheetFeedbackFindings
extends RefCounted

## The one finding, by id. Frozen: the amber state, the help strip, the Doctor's line and the tests
## all address it by this.
const KIND_UNKNOWN_LABEL := "feedback-label-nobody-has"

## Where a finding hangs. Always under the event whose row names the label.
const ANCHOR_EVENT := "event"

## The provider every row this file is about comes from - the pack's own class name, which is what
## an ACE row carries.
const PLAYER_PROVIDER := "FeedbackPlayer"

## The pack's file name, which is how a node in a saved scene is recognised as a Feedback Player
## without this file naming the pack's class (naming it would compile the pack into every editor
## boot, in projects that hold no player at all).
const PLAYER_FILE := "feedback_player.gd"

## The property a player holds its list in, and the keys one card names itself with.
const STEPS_PROPERTY := "steps"
const LABEL_KEY := "label"
const WORD_KEY := "verb"

## The parameters that hold a LABEL. A prefix parameter is deliberately not one of them: Pick One
## Feedback Of names the start of several labels, and a start that matches nothing is a choice the
## reader may be about to fill in rather than a mistake.
const LABEL_PARAMS: PackedStringArray = ["label", "after_label", "before_label", "first_label",
	"last_label"]


## Every unknown-label note this sheet earns, one per row that names one. `script_path` is the file
## the sheet lives in - it is how the scene that runs the sheet is found, and the label the sentence
## leads with. A sheet with no file yet earns nothing rather than earning a guess.
static func findings(sheet: EventSheetResource, script_path: String = "") -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if sheet == null or script_path.strip_edges().is_empty():
		return found
	var scenes: PackedStringArray = EventSheetSceneReplication.scenes_using(script_path)
	if scenes.is_empty():
		return found
	var known: PackedStringArray = labels_in_scene(scenes[0])
	# No player in the scene is no evidence, not a clean bill: every row would be reported, and the
	# reader would be told a hundred times about a node they have not added yet.
	if known.is_empty():
		return found
	_walk(sheet.events, known, scenes[0].get_file(), found)
	for entry: Variant in sheet.functions:
		var event_function: EventFunction = entry as EventFunction
		if event_function != null:
			_walk(event_function.events, known, scenes[0].get_file(), found)
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


## Every label every Feedback Player in one saved scene holds, sorted and without repeats. Read off
## the scene's own state rather than out of an instance: a packed scene answers what its nodes were
## saved with, which is exactly the list the reader is looking at in the Inspector, and reading it
## costs no tree, no physics and no running game.
static func labels_in_scene(scene_path: String) -> PackedStringArray:
	var known: Dictionary = {}
	if scene_path.strip_edges().is_empty() or not ResourceLoader.exists(scene_path):
		return PackedStringArray()
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		return PackedStringArray()
	var state: SceneState = packed.get_state()
	for node_index: int in range(state.get_node_count()):
		var carried: Variant = null
		var is_player: bool = false
		for property_index: int in range(state.get_node_property_count(node_index)):
			var property: String = str(state.get_node_property_name(node_index, property_index))
			var value: Variant = state.get_node_property_value(node_index, property_index)
			if property == "script" and value is Script:
				is_player = (value as Script).resource_path.get_file() == PLAYER_FILE
			elif property == STEPS_PROPERTY and value is Array:
				carried = value
		if not is_player or not (carried is Array):
			continue
		for entry: Variant in carried as Array:
			if not (entry is Dictionary):
				continue
			var named: String = label_of(entry as Dictionary)
			if not named.is_empty():
				known[named] = true
	var sorted: PackedStringArray = PackedStringArray(known.keys())
	sorted.sort()
	return sorted


## The name one card answers to, the same way the running player derives it: what it was called, or
## its own word when it was never named.
static func label_of(card: Dictionary) -> String:
	var named: String = str(card.get(LABEL_KEY, "")).strip_edges()
	return named if not named.is_empty() else str(card.get(WORD_KEY, "")).strip_edges()


## The labels ONE row names, in parameter order - what the rule is asked about. A value that is not
## a plain quoted word is left out: a row whose label comes from an expression is answered at run
## time, and guessing at it here would report a mistake nobody made.
static func labels_named(row_resource: Resource) -> PackedStringArray:
	var named: PackedStringArray = PackedStringArray()
	if row_resource == null or str(row_resource.get("provider_id")) != PLAYER_PROVIDER:
		return named
	var params: Variant = row_resource.get("params")
	if not (params is Dictionary):
		return named
	for key: String in LABEL_PARAMS:
		var written: String = str((params as Dictionary).get(key, "")).strip_edges()
		if written.length() < 3 or not written.begins_with("\"") or not written.ends_with("\""):
			continue
		named.append(written.substr(1, written.length() - 2))
	return named


## The sentence the inbox and the help strip say. One function, so the two can never drift.
static func message_for(label: String, scene_file: String) -> String:
	return "This row plays a feedback called \"%s\", and no Feedback Player in %s has one. Rename the card, or name a card the player has." % [
		label, scene_file]


## One walk of the rows. Each row is asked about ITS OWN parameters only, which is what pins the
## note to the row that says the label; sub-events answer for themselves when the walk reaches them.
static func _walk(items: Array, known: PackedStringArray, scene_file: String,
		found: Array[Dictionary]) -> void:
	for item: Variant in items:
		if item is EventGroup:
			_walk(EventSheetGroupFacts.children(item as EventGroup), known, scene_file, found)
			continue
		var event_row: EventRow = item as EventRow
		if event_row == null:
			continue
		for lane: Array in [event_row.conditions, event_row.actions]:
			for entry: Variant in lane:
				for label: String in labels_named(entry as Resource):
					if known.has(label):
						continue
					found.append({
						"kind": KIND_UNKNOWN_LABEL, "severity": "warning",
						"anchor": ANCHOR_EVENT, "event": event_row, "subject": label,
						"message": message_for(label, scene_file), "fix": "", "fix_label": ""
					})
		_walk(event_row.sub_events, known, scene_file, found)
