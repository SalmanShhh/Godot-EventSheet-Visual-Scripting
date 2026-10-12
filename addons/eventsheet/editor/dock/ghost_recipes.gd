@tool
extends RefCounted

# Ghost Row recipes: a few typed words that write SEVERAL ordinary rows at once.
#
# Some jobs a reader names in one breath are two rows here, because Godot spells them as two steps.
# "Move all the crate's children into the level" is a loop over the children and a reparent inside
# it - and both rows already ship: For Each Child and Add Child (existing node). A third row that did
# the same thing would split readers between two spellings of one idea, so there is no such row. The
# Ghost Row offers the two rows instead, already filled in, and what lands on the sheet is exactly
# what a person would have built by hand:
#
#     for child in $Crate.get_children():
#         child.reparent($Level)
#
# get_children() hands back a copy of the list, so reparenting inside the loop never skips a child.
#
# Static and pure: offer_for() reads the typed words and nothing else, and event_for() builds the
# event from the definitions it is handed, so a test pins both without an editor.

## The words that summon the move-children recipe - the names the job goes by in a reader's head, in
## an API they know, or in another event-sheet editor's two-step version of it. Matched at the start
## of what was typed, so "move children of $Crate to $Level" can name both ends.
const MOVE_CHILDREN_WORDS: PackedStringArray = [
	"move all children", "move children", "move the children", "reparent children",
	"reparent all children", "setparent", "set parent of children", "remove child, add child",
]

## The two rows the recipe is made of, by the ids they ship under.
const LOOP_ID: String = "ForEachChildOf"
const MOVE_ID: String = "HierarchyAddChild"

## Where the children come from and go to when the words do not say: this node's own children, moved
## up to its parent - the "unpack this container" a reader most often means.
const DEFAULT_FROM: String = "self"
const DEFAULT_TO: String = "get_parent()"


## What a typed sentence offers, or {}. "move children of $Crate to $Level" -> {recipe:
## "move_children", from: "$Crate", to: "$Level"}; "move children" alone offers the defaults. Words
## after the phrase that are neither "of ..." nor "to ..." mean this is not the recipe.
static func offer_for(text: String) -> Dictionary:
	var typed: String = text.strip_edges()
	var lowered: String = typed.to_lower()
	var matched: String = ""
	for phrase: String in MOVE_CHILDREN_WORDS:
		if lowered.begins_with(phrase) and phrase.length() > matched.length():
			matched = phrase
	if matched.is_empty():
		return {}
	var rest: String = typed.substr(matched.length()).strip_edges()
	var from_node: String = DEFAULT_FROM
	var to_node: String = DEFAULT_TO
	var to_at: int = rest.to_lower().find(" to ")
	if rest.to_lower().begins_with("to "):
		to_at = 0
	if to_at >= 0:
		var target: String = rest.substr(to_at + (3 if to_at == 0 else 4)).strip_edges()
		if target.is_empty():
			return {}
		to_node = target
		rest = rest.substr(0, to_at).strip_edges()
	if rest.to_lower().begins_with("of "):
		from_node = rest.substr(3).strip_edges()
		if from_node.is_empty():
			return {}
	elif not rest.is_empty():
		return {}
	return {"recipe": "move_children", "from": from_node, "to": to_node}


## The line the Ghost Row shows for an offer - what will be written, in the sheet's words.
static func label_for(offer: Dictionary) -> String:
	if offer.is_empty():
		return ""
	return "⟳  %s" % (EventSheetL10n.translate("Move every child of %s to %s") % [str(offer["from"]), str(offer["to"])])


## The event the recipe writes: For Each Child over the source, with Add Child (existing node) moving
## each `child` under the destination, keeping its place in the world. For Each Child is a looping
## row, so it lands the way picking it would land it - as the event's pick filter, its collection the
## row's own template filled in. `make_action` is the dock's apply maker (definition, params) -> row,
## so the action carries its baked template and reading exactly as a picked one would. Null when
## either row is missing.
static func event_for(offer: Dictionary, loop: ACEDefinition, move: ACEDefinition, event_uid: String,
		make_action: Callable) -> EventRow:
	if offer.is_empty() or loop == null or move == null:
		return null
	var pick: PickFilter = PickFilter.new()
	pick.collection_kind = PickFilter.CollectionKind.EXPRESSION
	pick.collection_value = EventSheetACEApply.build_looping_collection(loop, {"target": str(offer["from"])})
	pick.iterator_name = str(loop.metadata.get("looping_iterator", "child"))
	var event_row: EventRow = EventRow.new()
	event_row.event_uid = event_uid
	event_row.pick_filters.append(pick)
	event_row.actions.append(make_action.call(move, {"child": pick.iterator_name, "parent": str(offer["to"]), "keep": ""}))
	return event_row
