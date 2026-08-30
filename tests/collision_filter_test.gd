# Godot EventSheets - the touch, said with a filter on it.
#
# "On collision with <Group>" is the row a collision script is actually written from, and its whole
# claim is that the group is a PARAMETER and the filter is a visible line of code. This pins that
# claim from every side:
#
#   the rows      four triggers per dimension plus the standing question, filed under the class
#                 whose wording they are - a body BLOCKS, an area only NOTICES.
#   the code      the emitted handler's FIRST line is the early return, and two groups on one signal
#                 are two handlers rather than one that cannot say both.
#   the lift      a hand-written guard-first handler opens as that row, filter and all, and the file
#                 comes back byte-for-byte - in the author's own spelling, one-line or two.
#   the refusal   an `if` that guards on MORE than the group is not claimed, because a row that
#                 dropped the rest of it would not write the file back.
#   the question  Is touching <Group> compiles to the one-line ask, and both hand-written spellings
#                 of it open as that row byte-exact.
@tool
class_name CollisionFilterTest
extends RefCounted

const FILTERS := preload("res://addons/eventforge/registration/collision_filters.gd")
const MODULE := preload("res://addons/eventforge/registration/modules/collision_filter_aces.gd")

const LIFT_PATH := "user://collision_filter_lift.gd"

## A handler wired in code, guarded on a group in the two-line spelling the compiler writes.
const SOURCE_TWO_LINE: String = """extends Area2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("enemies"):
		return
	print(body.name)
"""

## The same handler, written the way a person in a hurry writes it.
const SOURCE_ONE_LINE: String = """extends Area2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("enemies"): return
	print(body.name)
"""

## A guard that asks MORE than the group. Nothing here may be claimed as a filter.
const SOURCE_WIDER_GUARD: String = """extends Area2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("enemies") or done:
		return
	print(body.name)
"""


static func run() -> bool:
	var ok: bool = _test_the_rows()
	ok = _test_what_is_emitted() and ok
	ok = _test_two_groups_are_two_handlers() and ok
	ok = _test_one_group_spelled_twice_is_one_handler() and ok
	ok = _test_the_lift() and ok
	ok = _test_the_refusal() and ok
	ok = _test_the_question() and ok
	ok = _test_the_help_strip() and ok
	ok = _test_the_filter_is_not_a_payload_chip() and ok
	return ok


## The row shows the payload the ENGINE hands the handler - the body that arrived - and the group is
## not one of those: it is the field the author filled in, and it is already in the row's sentence.
## Baked into the handler's argument list, a picked "On overlap with enemies" row drew `group` beside
## `body` as though the signal had handed it over.
static func _test_the_filter_is_not_a_payload_chip() -> bool:
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(EventSheetResource.new())
	var definition: ACEDefinition = dock._ace_registry.find_definition("Core", "OnOverlapWithGroup")
	var ok: bool = _check("the filtered trigger is registered", definition != null, true)
	if definition == null:
		dock.free()
		return false
	var event: EventRow = EventRow.new()
	var trigger: ACECondition = ACECondition.new()
	trigger.provider_id = "Core"
	trigger.ace_id = "OnOverlapWithGroup"
	trigger.params = {"group": "\"enemies\""}
	event.trigger = trigger
	dock._ace_apply._bake_trigger_signature(event, definition)
	ok = _check("the group the sentence already says is not baked as an argument",
		event.trigger_args.contains("group"), false) and ok
	ok = _check("while the arrival the engine hands over still is",
		event.trigger_args.contains("body"), true) and ok
	ok = _check("and the group itself still reaches the compiler as a trigger param",
		str(event.trigger_params.get("group", "")), "\"enemies\"") and ok
	dock.free()
	return ok


# ── the rows ─────────────────────────────────────────────────────────────────────


static func _test_the_rows() -> bool:
	var filed: Dictionary = {}
	var kinds: Dictionary = {}
	for descriptor: ACEDescriptor in MODULE.get_descriptors():
		filed[descriptor.ace_id] = descriptor.node_type
		kinds[descriptor.ace_id] = descriptor.ace_type
	var ok: bool = _check("the blocking pair is filed under the body that blocks",
		[filed.get("OnCollisionWithGroup"), filed.get("OnStoppedCollidingWithGroup")],
		["RigidBody2D", "RigidBody2D"])
	ok = _check("the noticing pair is filed under the area that notices",
		[filed.get("OnOverlapWithGroup"), filed.get("OnOverlapEndedWithGroup")],
		["Area2D", "Area2D"]) and ok
	ok = _check("every row has a 3D twin, filed under the 3D class",
		[filed.get("OnCollisionWithGroup3D"), filed.get("OnOverlapWithGroup3D"),
			filed.get("IsTouchingGroup3D")],
		["RigidBody3D", "Area3D", "Area3D"]) and ok
	ok = _check("the four arrivals are triggers and the standing one is a question",
		[kinds.get("OnCollisionWithGroup"), kinds.get("OnOverlapEndedWithGroup"),
			kinds.get("IsTouchingGroup")],
		[ACEDescriptor.ACEType.TRIGGER, ACEDescriptor.ACEType.TRIGGER,
			ACEDescriptor.ACEType.CONDITION]) and ok
	var trigger: ACEDescriptor = _descriptor("OnOverlapWithGroup")
	var fields: Array = []
	for parameter: ACEParam in trigger.params:
		fields.append([parameter.id, parameter.hint])
	ok = _check("the filter is a group FIELD and the hit is a payload beside it",
		fields, [["group", "group_reference"], ["body", ""]]) and ok
	ok = _check("the row reads as one sentence with the group in it",
		trigger.get_display_text(), "On overlap with {group}") and ok
	return ok


# ── what is emitted ──────────────────────────────────────────────────────────────


static func _test_what_is_emitted() -> bool:
	var output: String = _compiled(_sheet([["OnOverlapWithGroup", "\"enemies\""]]))
	var ok: bool = _check("the guard is the handler's FIRST line",
		_body_of(output, "_on_body_entered_enemies"),
		["\tif not body.is_in_group(\"enemies\"):", "\t\treturn", "\tprint(body.name)"])
	ok = _check("the connection names the filtered handler",
		output.contains("\tbody_entered.connect(_on_body_entered_enemies)"), true) and ok
	var blank: String = _compiled(_sheet([["OnOverlapWithGroup", ""]]))
	ok = _check("a row with no group yet guards on nothing, and stays out of the bare handler's name",
		_body_of(blank, "_on_body_entered_filtered"), ["\tprint(body.name)"]) and ok
	return ok


static func _test_two_groups_are_two_handlers() -> bool:
	var output: String = _compiled(_sheet([
		["OnOverlapWithGroup", "\"enemies\""], ["OnOverlapWithGroup", "\"pickups\""]]))
	var ok: bool = _check("each group gets its own handler, each opening with its own guard",
		[_body_of(output, "_on_body_entered_enemies")[0],
			_body_of(output, "_on_body_entered_pickups")[0]],
		["\tif not body.is_in_group(\"enemies\"):", "\tif not body.is_in_group(\"pickups\"):"])
	ok = _check("and both are connected",
		[output.contains("connect(_on_body_entered_enemies)"),
			output.contains("connect(_on_body_entered_pickups)")], [true, true]) and ok
	return ok


## THE OTHER HALF of the rule above, and the one that breaks the file rather than the reading: two
## rows that name ONE group in two spellings are one handler, because the name a filtered handler
## wears is the name the grouping key is made of. Keyed on the row's raw text instead, `"enemies"` and
## `&"enemies"` are two groups with one function name - two `func _on_body_entered_enemies` and two
## identical connect lines - and the emitted file does not parse at all.
static func _test_one_group_spelled_twice_is_one_handler() -> bool:
	var output: String = _compiled(_sheet([
		["OnOverlapWithGroup", "\"enemies\""], ["OnOverlapWithGroup", "&\"enemies\""]]))
	var ok: bool = _check("one group spelled two ways is ONE handler",
		_count(output, "func _on_body_entered_enemies("), 1)
	ok = _check("connected once", _count(output, "body_entered.connect(_on_body_entered_enemies)"), 1) and ok
	ok = _check("with one guard and both rows under it",
		_body_of(output, "_on_body_entered_enemies"),
		["\tif not body.is_in_group(\"enemies\"):", "\t\treturn", "\tprint(body.name)",
			"\tprint(body.name)"]) and ok
	# And the proof that matters: the emitted text is a script Godot will load. A duplicate function
	# name is a PARSE error, which every other assertion in this file would sail straight past.
	ok = _check("and the emitted script parses", _parses(output), "") and ok
	# The same rule from the other end: two groups that are really two must never collapse onto one
	# name, however their digests are made - an expression has no name to read, so the digest under it
	# is the whole hash rather than a few digits of it.
	var by_expression: String = _compiled(_sheet([
		["OnOverlapWithGroup", "self.name"], ["OnOverlapWithGroup", "self.get_class()"]]))
	ok = _check("and two expression-named groups stay two handlers",
		[_count(by_expression, "func _on_body_entered_filtered_"), _parses(by_expression)],
		[2, ""]) and ok
	return ok


# ── the lift ─────────────────────────────────────────────────────────────────────


static func _test_the_lift() -> bool:
	var ok: bool = true
	for spelling: Array in [["the two-line guard", SOURCE_TWO_LINE], ["the one-line guard", SOURCE_ONE_LINE]]:
		var opened: EventSheetResource = _opened(str(spelling[1]))
		var event: EventRow = _first_event(opened)
		ok = _check("%s opens as the filtered trigger" % str(spelling[0]),
			[event.trigger_id if event != null else "", FILTERS.group_of(event)],
			["OnOverlapWithGroup", "\"enemies\""]) and ok
		ok = _check("%s writes the file back byte-for-byte" % str(spelling[0]),
			str(SheetCompiler.compile(opened, LIFT_PATH).get("output", "")), str(spelling[1])) and ok
	return ok


static func _test_the_refusal() -> bool:
	var opened: EventSheetResource = _opened(SOURCE_WIDER_GUARD)
	var event: EventRow = _first_event(opened)
	var claimed: String = event.trigger_id if event != null else ""
	var ok: bool = _check("a guard that asks more than the group is not claimed as a filter",
		FILTERS.is_filtered(claimed), false)
	ok = _check("and the file still comes back byte-for-byte",
		str(SheetCompiler.compile(opened, LIFT_PATH).get("output", "")), SOURCE_WIDER_GUARD) and ok
	return ok


# ── the standing question ────────────────────────────────────────────────────────


static func _test_the_question() -> bool:
	var descriptor: ACEDescriptor = _descriptor("IsTouchingGroup")
	var ok: bool = _check("the question is the one-line ask a reader would write",
		descriptor.codegen_template.contains(
			"get_overlapping_bodies().any(func(__body: Node) -> bool: return __body.is_in_group({group}))"),
		true)
	var entries: Array = EventForgeCollisionFilterLift.condition_entries()
	var by_overlaps: Dictionary = EventForgeCollisionFilterLift.match_condition(
		"get_overlapping_bodies().any(func(b: Node) -> bool: return b.is_in_group(\"enemies\"))")
	ok = _check("the area-side spelling opens as the question, keeping the author's own words",
		[str(by_overlaps.get("ace_id", "")), str((by_overlaps.get("params", {}) as Dictionary).get("group", "")),
			str(by_overlaps.get("template", ""))],
		["IsTouchingGroup", "\"enemies\"",
			"get_overlapping_bodies().any(func(b: Node) -> bool: return b.is_in_group({group}))"]) and ok
	var by_group: Dictionary = EventForgeCollisionFilterLift.match_condition(
		"get_tree().get_nodes_in_group(\"enemies\").any(overlaps_body)")
	ok = _check("and so does the group-side spelling",
		[str(by_group.get("ace_id", "")), str((by_group.get("params", {}) as Dictionary).get("group", ""))],
		["IsTouchingGroup", "\"enemies\""]) and ok
	ok = _check("a lambda that asks about something other than what it was handed is not claimed",
		EventForgeCollisionFilterLift.match_condition(
			"get_overlapping_bodies().any(func(b: Node) -> bool: return other.is_in_group(\"enemies\"))"),
		{}) and ok
	ok = _check("the family declares only questions, so the verb side never asks it",
		[entries.size(), (load("res://addons/eventforge/importer/collision_filter_lift.gd") as GDScript).has_method("match_line")], [2, false]) and ok
	return ok


# ── the one-liner the dialog teaches ─────────────────────────────────────────────


static func _test_the_help_strip() -> bool:
	return _check("the strip teaches the lesson of the node the row is filed under",
		[FILTERS.side_note("Area2D") == FILTERS.AREA_NOTE,
			FILTERS.side_note("RigidBody3D") == FILTERS.BODY_NOTE,
			FILTERS.side_note("") == FILTERS.BODY_NOTE],
		[true, true, true])


# ── the fixtures ─────────────────────────────────────────────────────────────────


## One sheet on an Area2D, with one event per (trigger, group) pair, each printing the body's name -
## which is the point of the payload chip, used in the row underneath.
static func _sheet(events: Array) -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Area2D"
	for entry: Array in events:
		var event: EventRow = EventRow.new()
		event.trigger_provider_id = "Core"
		event.trigger_id = str(entry[0])
		event.trigger_params = {FILTERS.GROUP_PARAM: str(entry[1])}
		var action: ACEAction = ACEAction.new()
		action.provider_id = "Core"
		action.ace_id = "PrintMessage"
		action.codegen_template = "print({message})"
		action.params = {"message": "body.name"}
		event.actions.append(action)
		sheet.events.append(event)
	return sheet


static func _compiled(sheet: EventSheetResource) -> String:
	return str(SheetCompiler.compile(sheet).get("output", ""))


## The lines of one function in emitted output, without its header.
static func _body_of(output: String, function_name: String) -> Array:
	var body: Array = []
	var inside: bool = false
	for line: String in output.split("\n"):
		if line.begins_with("func %s(" % function_name):
			inside = true
			continue
		if inside:
			if line.strip_edges().is_empty() or not line.begins_with("\t"):
				break
			body.append(line)
	return body


## How many times a piece of text appears in the output. Counted rather than asked about, because
## "is this handler there" and "is this handler there TWICE" are different questions and only the
## second one catches a file that will not parse.
static func _count(output: String, needle: String) -> int:
	return output.count(needle)


## Whether the emitted text is a script the engine will really load, as "" when it is. Two functions
## of one name is a PARSE error, and every assertion about text in this file sails straight past one:
## the output still contains the handler, still contains the connect, and still reads correctly.
static func _parses(output: String) -> String:
	var script: GDScript = GDScript.new()
	script.source_code = output
	var result: int = script.reload()
	return "" if result == OK else "the emitted script does not load (error %d)" % result


static func _opened(source: String) -> EventSheetResource:
	var handle: FileAccess = FileAccess.open(LIFT_PATH, FileAccess.WRITE)
	handle.store_string(source)
	handle.close()
	return GDScriptImporter.new().import_external(LIFT_PATH)


static func _first_event(sheet: EventSheetResource) -> EventRow:
	for entry: Variant in sheet.events:
		if entry is EventRow:
			return entry as EventRow
	return null


static func _descriptor(ace_id: String) -> ACEDescriptor:
	for descriptor: ACEDescriptor in MODULE.get_descriptors():
		if descriptor.ace_id == ace_id:
			return descriptor
	return null


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] collision_filter_test: %s" % label)
		return true
	print("[FAIL] collision_filter_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
