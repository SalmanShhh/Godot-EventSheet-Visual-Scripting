@tool
class_name HierarchyReadingTest
extends RefCounted

# Pins the batch-thirteen HIERARCHY readings - the words an event sheet has always used for putting
# one object under another, now said about Godot's own spellings of it:
#
#   X10  reparent / remove_child + add_child: Add child (said by the PARENT) with the keep-its-place
#        choice spelled out, Remove from parent, and Take out of the layout for a bare removal
#   X11  the four follow-flags a hierarchy row carries, read back off whatever plumbing wrote them
#        (a RemoteTransform with a switch off, a top_level beside it) as ONE flagged row
#   X12  the picks and the counts: For each c in x's children, x.ChildCount, x's parent, x's first
#        child, every T among x's descendants, x contains y, and the two child triggers
#   X13  the escape hatches: ignore parent's movement, copy its place to, stop copying
#
# Six gates, in the order the failures actually happen:
#   1. the grammar's own values - one shape, one sentence, asserted literally;
#   2. the T10 line that must NOT move: a reparent onto a KNOWN drawing layer keeps the layer words,
#      because that reading is what a 2D project is actually looking at;
#   3. the runs - the two-line move and the flags shape - read as one row in an OPENED file;
#   4. every pattern claimed on the row that owns it;
#   5. the authoring half: each picked row emits EXACTLY the line the reading above recognises, and
#      the two triggers compile to the signals they name (the two-way gate);
#   6. the promise all of it rests on - the file still saves byte-identically, because every reading
#      here is a lens over a line the row already holds.
#
# The source lives here as a string rather than in tests/fixtures/ for the reason its sibling reading
# tests give: the lifter's byte gate compares against what the COMPILER would emit, and the compiler
# puts ONE blank line between functions, so a checked-in two-blank-line file could never lift.

const SOURCE_PATH := "user://eventforge_hierarchy_reading.gd"

const SOURCE: String = """extends Node3D

@onready var hud_layer: CanvasLayer = $HUD
@onready var follower: RemoteTransform3D = $Follow

func pick_up(item: Node3D) -> void:
	item.reparent($Hand)

func drop_item(item: Node3D) -> void:
	item.reparent(get_tree().current_scene)

func holster(item: Node3D) -> void:
	item.get_parent().remove_child(item)
	$Back.add_child(item)

func mount(rider: Node3D) -> void:
	rider.reparent($Saddle, false)

func equip(hat: Node3D) -> void:
	hat.reparent($Head)
	hat.top_level = true
	var __follow_hat := RemoteTransform3D.new()
	__follow_hat.update_scale = false
	$Head.add_child(__follow_hat)
	__follow_hat.remote_path = __follow_hat.get_path_to(hat)

func stow(card: Node3D) -> void:
	card.reparent(hud_layer)

func lone_follower() -> void:
	var __follow_solo := RemoteTransform3D.new()
	__follow_solo.update_scale = false
	add_child(__follow_solo)

func heal_squad(leader: Node3D) -> void:
	for unit in leader.get_children():
		unit.hp += 10
"""

## X10 / X13. The statements whose sentence this parcel settles, as "object ▸ sentence".
static var STATEMENT_READINGS: Dictionary = {
	# X10 - a move in the hierarchy, said by the parent that gained the child
	"item.reparent($Hand)": "Hand ▸ Add child item keeping its place",
	"rider.reparent($Saddle, false)": "Saddle ▸ Add child rider, snapping to it",
	"item.reparent(get_tree().current_scene)":
		"item ▸ Remove from parent keeping its place in the layout",
	"item.reparent(get_tree().root)": "item ▸ Remove from parent keeping its place in the layout",
	# X10 - a receiver-less reparent is the script's own object moving itself
	"reparent($Hand)": "Hand ▸ Add child Player keeping its place",
	# X10 - taken out and kept, which is a different thing from destroyed
	"item.get_parent().remove_child(item)": "item ▸ Take out of the layout (kept in memory)",
	"$Bag.remove_child(item)": "item ▸ Take out of the layout (kept in memory)",
	# X13 - the two escape hatches, in the words the answers to "why does my child not follow" use
	"item.top_level = true": "item ▸ Set ignore parent's movement on",
	"item.top_level = false": "item ▸ Set ignore parent's movement off",
	"follower.remote_path = NodePath(\"../Target\")": "follower ▸ Copy its place to Target",
	"follower.remote_path = NodePath(\"\")": "follower ▸ Stop copying",
	"follower.update_scale = false": "follower ▸ Copy size off",
	"follower.update_position = true": "follower ▸ Copy position on"
}

## X12 / X13. The conditions the grammar must answer on its own, as "object ▸ sentence".
static var CONDITION_READINGS: Dictionary = {
	"squad.is_ancestor_of(unit)": "squad ▸ contains unit",
	"item.top_level": "item ▸ ignores parent's movement"
}

## X12. The value expressions, as the possessives a reader says them with out loud.
static var EXPRESSION_READINGS: Dictionary = {
	"unit.get_parent()": "unit's parent",
	"squad.get_child_count()": "squad.ChildCount",
	"squad.get_child(0)": "squad's first child",
	"squad.get_child(2)": "squad's child #2",
	"squad.find_children(\"*\", \"Enemy\")": "every Enemy among squad's descendants"
}

## The readings the opened file must contain - the runs above all, because a run is the one thing a
## per-line pin cannot see.
static var EXPECTED_READINGS: PackedStringArray = PackedStringArray([
	"Hand ▸ Add child item keeping its place",
	"item ▸ Remove from parent keeping its place in the layout",
	"Back ▸ Add child item, snapping to it",
	"Saddle ▸ Add child rider, snapping to it",
	"Head ▸ Add child hat keeping its place",
	"transform position ✓ transform angle ✓ transform size ✗ destroy with parent ✓",
	"card ▸ Move to layer hud layer",
	"System ▸ For each unit in leader's children"
])

## Readings the file must NOT contain: the words each new shape replaced, and the plumbing the
## flagged row now stands for. A reading that silently stopped firing would otherwise pass the list
## above by never being asked about.
static var FORBIDDEN_READINGS: PackedStringArray = PackedStringArray([
	"System ▸ move to layer $Hand",
	"System ▸ move to layer $Saddle, false",
	"Local object __follow_hat",
	"item ▸ Move to layer Hand",
	# X11 - a follower with nothing beside it is NOT a flagged Add child row. An ordinary child
	# already inherits its parent's whole transform, so a follower on its own changes nothing about
	# the parenting: it is the standalone "copies its place to" of X13, and reads as its own lines.
	"__follow_solo ▸ Add child follow solo keeping its place"
])

## X10 / X13. The authoring half: each row and the ONE line it must emit - which is exactly a line
## the readings above recognise, so a picked row and a typed line are one row and one file.
static var EMITTED_LINES: Array = [
	["HierarchyAddChild", {"child": "item", "parent": "$Hand", "keep": ""}, "item.reparent($Hand)"],
	["HierarchyAddChild", {"child": "rider", "parent": "$Saddle", "keep": "false"},
		"rider.reparent($Saddle, false)"],
	["HierarchyRemoveFromParent", {"child": "item"}, "item.reparent(get_tree().current_scene)"],
	["SetIgnoreParentMovement", {"target": "$Flash", "ignore": "true"}, "$Flash.top_level = true"],
	["CopyPlaceTo", {"follower": "$Follow", "path": "\"../Target\""},
		"$Follow.remote_path = NodePath(\"../Target\")"],
	["StopCopyingPlace", {"follower": "$Follow"}, "$Follow.remote_path = NodePath(\"\")"]
]


static func run() -> bool:
	var ok: bool = true
	ok = _grammar_values() and ok
	ok = _layer_words_stay() and ok
	var readings: PackedStringArray = _open_and_read()
	for expected: String in EXPECTED_READINGS:
		ok = _check("opened row reads \"%s\"" % expected, readings.has(expected), true) and ok
	for forbidden: String in FORBIDDEN_READINGS:
		ok = _check("no row still reads \"%s\"" % forbidden, readings.has(forbidden), false) and ok
	ok = _claims() and ok
	ok = _authored_rows() and ok
	ok = _child_triggers() and ok
	ok = _round_trip() and ok
	return ok


## The sentence context an opened script hands the grammar.
static func _context() -> Dictionary:
	return {
		"self_object": "Player",
		"script_object": "Player",
		"self_class": "Node3D",
		"engine_properties": {"position": true, "top_level": true},
		"object_classes": {"hud_layer": "CanvasLayer", "follower": "RemoteTransform3D"}
	}


## Gate one: the grammar answering on its own, value by value.
static func _grammar_values() -> bool:
	var ok: bool = true
	var context: Dictionary = _context()
	for code: String in STATEMENT_READINGS:
		ok = _check("statement %s" % code,
			_joined_segments(EventSheetSentence.statement(code, context)),
			str(STATEMENT_READINGS[code])) and ok
	for expression: String in CONDITION_READINGS:
		ok = _check("condition %s" % expression,
			_joined_pieces(EventSheetSentence.condition_pieces(expression, context)),
			str(CONDITION_READINGS[expression])) and ok
	for value: String in EXPRESSION_READINGS:
		ok = _check("expression %s" % value,
			EventSheetSentence.expression_text(value, context),
			str(EXPRESSION_READINGS[value])) and ok
	# X10 - the two-line spelling is ONE move, and it does NOT keep the world place, which is the
	# difference between the two spellings and the whole reason the row says so.
	ok = _check("remove-then-add is one row",
		_joined_segments(EventSheetSentence.remove_then_add_sentence(
			"item.get_parent().remove_child(item)", "$Back.add_child(item)", context)),
		"Back ▸ Add child item, snapping to it") and ok
	# ...and two lines that only happen to name the same node are two steps, and stay two rows.
	ok = _check("an unrelated pair is not a move",
		EventSheetSentence.remove_then_add_sentence(
			"$Bag.remove_child(item)", "$Back.add_child(other)", context).is_empty(), true) and ok
	# X12 - the loop over another object's children, in the possessive the rest of the words use.
	ok = _check("a loop over children says whose they are",
		str(EventSheetViewportReadingRows.loop_words(
			PickFilter.CollectionKind.EXPRESSION, "unit", "leader.get_children()").get("text", "")),
		"For each unit in leader's children") and ok
	return ok


## Gate two: the T10 reading that must NOT move. A reparent onto a KNOWN drawing layer is a layer
## move and keeps the layer words; a reparent onto anything else is a move in the hierarchy. Both
## halves are pinned, because the interesting failure is either one swallowing the other.
static func _layer_words_stay() -> bool:
	var ok: bool = true
	var context: Dictionary = _context()
	ok = _check("a reparent onto a known layer keeps the layer words",
		_joined_segments(EventSheetSentence.statement("card.reparent(hud_layer)", context)),
		"card ▸ Move to layer hud_layer") and ok
	ok = _check("and a reparent onto anything else is a hierarchy move",
		_joined_segments(EventSheetSentence.statement("card.reparent(shelf)", context)),
		"shelf ▸ Add child card keeping its place") and ok
	return ok


## Gate four: every pattern the file holds is CLAIMED on the row that owns it, so the chip, the hover
## evidence and the Doctor all read one set of claims.
static func _claims() -> bool:
	var ok: bool = true
	ok = _check("the hierarchy pattern id is registered",
		Array(EventSheetPatternFacts.PATTERN_IDS).has("hierarchy"), true) and ok
	var context: Dictionary = _context()
	ok = _check("an Add child sentence claims it",
		str(EventSheetSentence.statement("item.reparent($Hand)", context).get("pattern", "")),
		"hierarchy") and ok
	ok = _check("so does Remove from parent",
		str(EventSheetSentence.statement(
			"item.reparent(get_tree().current_scene)", context).get("pattern", "")),
		"hierarchy") and ok
	ok = _check("and so does an escape hatch",
		str(EventSheetSentence.statement("item.top_level = true", context).get("pattern", "")),
		"hierarchy") and ok
	return ok


## Gate five: the authoring half. Each row emits EXACTLY one line, and it is a line the reading
## recognises - so dropping the row and typing the line put the same words on the canvas and the same
## bytes in the file.
static func _authored_rows() -> bool:
	var ok: bool = true
	var context: Dictionary = _context()
	for entry: Variant in EMITTED_LINES:
		var row: Array = entry
		var action: ACEAction = ACEAction.new()
		action.provider_id = "Core"
		action.ace_id = str(row[0])
		action.params = row[1]
		var emitted: String = ActionCodegen.generate_action(action).strip_edges()
		ok = _check("%s emits its line" % str(row[0]), emitted, str(row[2])) and ok
		ok = _check("...and the reading claims it",
			str(EventSheetSentence.statement(emitted, context).get("pattern", "")),
			"hierarchy") and ok
	# The loop row is a CONDITION that walks a node's children, and it emits the plain call the
	# reading above turns into "For each child in x's children".
	var loop: ACECondition = ACECondition.new()
	loop.provider_id = "Core"
	loop.ace_id = "ForEachChildOf"
	loop.params = {"target": "leader"}
	ok = _check("For Each Child walks the node's children",
		ConditionCodegen.generate_condition(loop).strip_edges(), "leader.get_children()") and ok
	return ok


## Gate five, second half: the two child triggers wire to the signals they are named after.
static func _child_triggers() -> bool:
	var ok: bool = true
	for pair: Array in [["OnChildEnteredTree", "child_entered_tree"],
			["OnChildExitingTree", "child_exiting_tree"]]:
		var sheet: EventSheetResource = EventSheetResource.new()
		sheet.host_class = "Node3D"
		var event_row: EventRow = EventRow.new()
		event_row.trigger_id = str(pair[0])
		var action: ACEAction = ACEAction.new()
		action.provider_id = "Core"
		action.ace_id = "SetVar"
		action.params = {"var_name": "joined", "value": "1"}
		event_row.actions = [action]
		sheet.events = [event_row]
		var output: String = str(SheetCompiler.compile(sheet, "user://x_trigger.gd").get("output", ""))
		ok = _check("%s connects %s" % [str(pair[0]), str(pair[1])],
			output.contains("%s.connect(_on_%s)" % [str(pair[1]), str(pair[1])]), true) and ok
		ok = _check("...and hands the row the node that moved",
			output.contains("func _on_%s(node: Node) -> void:" % str(pair[1])), true) and ok
	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] hierarchy_reading_test: %s" % label)
		return true
	print("[FAIL] hierarchy_reading_test: %s - expected %s, got %s" % [label, expected, actual])
	return false


## One condition reading as "object ▸ sentence", or the bare sentence when no object is named.
static func _joined_pieces(reading: Dictionary) -> String:
	var text: String = ""
	for piece: Variant in (reading.get("pieces", []) as Array):
		text += str((piece as Array)[0])
	var object_label: String = str(reading.get("object", ""))
	return "%s ▸ %s" % [object_label, text.strip_edges()] if not object_label.is_empty() else text.strip_edges()


## One statement reading as "object ▸ sentence".
static func _joined_segments(reading: Dictionary) -> String:
	var text: String = ""
	for segment: Variant in (reading.get("segments", []) as Array):
		text += str((segment as Dictionary).get("text", ""))
	var object_label: String = str(reading.get("object", ""))
	return "%s ▸ %s" % [object_label, text.strip_edges()] if not object_label.is_empty() else text.strip_edges()


## Writes the source, opens it as a sheet, and returns every cell reading.
static func _open_and_read() -> PackedStringArray:
	var handle: FileAccess = FileAccess.open(SOURCE_PATH, FileAccess.WRITE)
	handle.store_string(SOURCE)
	handle.close()
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(SOURCE_PATH)
	sheet.read_only = true
	var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
	style.ensure_defaults()
	sheet.editor_style = style
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_ace_registry(EventSheetACERegistry.new())
	viewport.set_sheet(sheet)
	viewport.set_reading_mode(true)
	var readings: PackedStringArray = PackedStringArray()
	for row_data: EventRowData in _walk(viewport._root_rows, viewport):
		for span: SemanticSpan in row_data.spans:
			var object_label: String = str(span.metadata.get("object_label", ""))
			var text: String = span.text.strip_edges()
			readings.append("%s ▸ %s" % [object_label, text] if not object_label.is_empty() else text)
	viewport.free()
	return readings


## Every row in the tree, parents before children.
static func _walk(rows: Array, viewport: EventSheetViewport) -> Array:
	var found: Array = []
	for row_data: EventRowData in rows:
		viewport._row_builder._ensure_event_spans(row_data)
		found.append(row_data)
		found.append_array(_walk(row_data.children, viewport))
	return found


## Gate six: every reading here is a lens over a line the row already holds, so opening the file and
## saving it untouched puts back every byte - including the four plumbing lines the flagged Add child
## row above stands for.
static func _round_trip() -> bool:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(SOURCE_PATH)
	var output: String = str(SheetCompiler.compile(sheet, SOURCE_PATH).get("output", ""))
	return _check("opening the file and saving it reproduces every byte", output, SOURCE)
