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


## The words a variable sentence names its type with, as the type the code writes. The longest match
## wins, so "number with decimals" is never read as "number".
const TYPE_WORDS: Dictionary = {
	"whole number": "int", "integer": "int", "int": "int", "number with decimals": "float", "decimal": "float",
	"number": "float", "float": "float", "text": "String", "string": "String", "true or false": "bool",
	"boolean": "bool", "bool": "bool", "colour": "Color", "color": "Color", "vector": "Vector2",
}


## A variable sentence: "max_jumps is a whole number from 1 to 3, in the Inspector" ->
## {variable: max_jumps, type: int, min: 1, max: 3, exported: true, storage: false, group: ""}. The
## clauses after the type, in any order: "from A to B" (a number's slider), "in the Inspector",
## "saved but hidden", "in group Bullet". Any other words mean this is not the sentence: {}.
static func variable_offer_for(text: String) -> Dictionary:
	var typed: String = text.strip_edges()
	var said_at: int = typed.find(" is ")
	if said_at <= 0 or not typed.substr(0, said_at).is_valid_identifier():
		return {}
	var rest: String = typed.substr(said_at + 4).strip_edges()
	for article: String in ["a ", "an "]:
		if rest.to_lower().begins_with(article):
			rest = rest.substr(article.length())
	var matched: String = ""
	for words: String in TYPE_WORDS:
		if rest.to_lower().begins_with(words) and words.length() > matched.length():
			matched = words
	if matched.is_empty():
		return {}
	var offer: Dictionary = {"variable": typed.substr(0, said_at), "type": TYPE_WORDS[matched], "min": "", "max": "",
		"exported": false, "storage": false, "group": ""}
	for clause: String in rest.substr(matched.length()).split(","):
		var words: String = clause.strip_edges()
		var lowered: String = words.to_lower()
		if words.is_empty():
			continue
		if lowered.begins_with("from ") and lowered.contains(" to ") and offer["type"] in ["int", "float"]:
			offer["min"] = words.substr(5).get_slice(" to ", 0).strip_edges()
			offer["max"] = words.get_slice(" to ", 1).strip_edges()
			if not (offer["min"] as String).is_valid_float() or not (offer["max"] as String).is_valid_float():
				return {}
		elif lowered in ["in the inspector", "shown in the inspector"]:
			offer["exported"] = true
		elif lowered == "saved but hidden":
			offer["storage"] = true
		elif lowered.begins_with("in group ") and words.substr(9).strip_edges().length() > 0:
			offer["group"] = words.substr(9).strip_edges()
		else:
			return {}
	# A slider, a hidden save and a group are all things the Inspector does, so each puts it there.
	offer["exported"] = bool(offer["exported"]) or not str(offer["min"]).is_empty() or bool(offer["storage"]) \
		or not str(offer["group"]).is_empty()
	return offer


## The variable a sentence declares: its type, its value (the slider's low end, else the type's
## empty value) and the Inspector look, group and save the sentence named.
static func variable_for(offer: Dictionary) -> LocalVariable:
	var made: LocalVariable = LocalVariable.new()
	made.name = str(offer.get("variable", ""))
	made.type_name = str(offer.get("type", "int"))
	made.exported = bool(offer.get("exported", false))
	var low: String = str(offer.get("min", ""))
	var empty_values: Dictionary = {"int": 0, "float": 0.0, "String": "", "bool": false, "Color": Color.WHITE, "Vector2": Vector2.ZERO}
	made.default_value = empty_values.get(made.type_name)
	var attributes: Dictionary = {}
	if not low.is_empty():
		made.default_value = low.to_int() if made.type_name == "int" else low.to_float()
		# A whole number's step is Godot's default, so it stays unwritten: `@export_range(1, 3)`.
		attributes["range"] = {"min": low, "max": str(offer.get("max", "")), "step": "" if made.type_name == "int" else "0.01"}
	if bool(offer.get("storage", false)):
		attributes["storage"] = true
	if not str(offer.get("group", "")).is_empty():
		attributes["group"] = str(offer["group"])
	made.attributes = attributes
	return made


## The line the Ghost Row shows for a variable sentence: the row it adds, in the sheet's words.
static func variable_label_for(offer: Dictionary) -> String:
	var where: String = EventSheetL10n.translate("saved but hidden") if bool(offer.get("storage", false)) \
		else (EventSheetL10n.translate("in the Inspector") if bool(offer.get("exported", false)) else EventSheetL10n.translate("not in the Inspector"))
	var said: String = "⊕  %s %s · %s" % [str(offer.get("type", "")), str(offer.get("variable", "")), where]
	if not str(offer.get("min", "")).is_empty():
		said += " · " + EventSheetL10n.translate("a slider from %s to %s") % [str(offer["min"]), str(offer["max"])]
	if not str(offer.get("group", "")).is_empty():
		said += " · " + EventSheetL10n.translate("in group %s") % str(offer["group"])
	return said


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
