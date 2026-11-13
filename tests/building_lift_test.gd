# Godot EventSheets - the Building rows, opened from hand-written code.
#
# A person who writes `var marker := Marker2D.new()`, names it and adds it to the scene has written
# the Add New Node row. These pins say that a run written by hand (and one written by the editor, with
# its baked id) opens as the row it means, that the row's values are the ones the lines said, and that
# saving the sheet untouched writes the very same bytes back. A run that is short of the shape keeps
# the ordinary rows it always read as.
@tool
class_name BuildingLiftTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const NAME: String = "building_lift_test"


## One handler holding the lines, in a script that extends `host`.
static func _source(host: String, lines: PackedStringArray) -> String:
	var body: String = ""
	for line: String in lines:
		body += "\t" + line + "\n"
	return "extends %s\n\n\nfunc _ready() -> void:\n%s" % [host, body]


## The ACE actions of the first handler of a reopened source, in order.
static func _actions(source: String) -> Array[ACEAction]:
	var found: Array[ACEAction] = []
	var sheet: EventSheetResource = SUPPORT.reopen(source)
	if sheet == null:
		return found
	for entry: Variant in sheet.events:
		if entry is EventRow:
			for action: Variant in (entry as EventRow).actions:
				if action is ACEAction:
					found.append(action)
	return found


static func _opens_as(source: String) -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	for action: ACEAction in _actions(source):
		ids.append(action.ace_id)
	return ids


static func _round_trips(source: String, label: String) -> bool:
	var path: String = "user://building_lift_%s.gd" % label.validate_filename()
	return SUPPORT.pin_value(NAME, "%s saves back byte for byte" % label, SUPPORT.reemit(source, path), source)


static func run() -> bool:
	var passed: bool = true
	passed = _hand_written_runs() and passed
	passed = _runs_the_editor_writes() and passed
	passed = _runs_that_keep_their_old_reading() and passed
	passed = _the_values() and passed
	return passed


## Each row's run as a person might type it, and the row it opens as.
static func _hand_written_runs() -> bool:
	var passed: bool = true
	for case: Array in [
		["a named node", "Node2D", ["var marker := Marker2D.new()", "marker.name = \"Spawn\"",
			"get_tree().current_scene.add_child(marker)"], "AddNewNodeInto"],
		["an unnamed node", "Node2D", ["var marker := Marker2D.new()",
			"get_tree().current_scene.add_child(marker)"], "AddNewNodeInto"],
		["a behaviour added once", "Node2D", ["var clock: Timer = self.get_node_or_null(\"Timer\") as Timer",
			"if clock == null:", "\tclock = Timer.new()", "\tclock.name = \"Timer\"", "\tself.add_child(clock)"], "AddBehaviourInto"],
		["a behaviour removed", "Node2D", ["var __behaviour_a1 := self.get_node_or_null(\"Timer\")",
			"if __behaviour_a1 != null:", "\tself.remove_child(__behaviour_a1)", "\t__behaviour_a1.queue_free()"], "RemoveBehaviour"],
		["a sprite", "Node2D", ["var __sprite_a1 := Sprite2D.new()", "__sprite_a1.texture = load(\"res://icon.svg\")",
			"self.add_child(__sprite_a1)"], "AddSpriteTo"],
		["a circle shape", "Node2D", ["var __shape_a1 := CollisionShape2D.new()", "var __circle_a1 := CircleShape2D.new()",
			"__circle_a1.radius = 12.0", "__shape_a1.shape = __circle_a1", "self.add_child(__shape_a1)"], "AddCircleShapeTo"],
		["a box shape in 3D", "Node3D", ["var __shape_a1 := CollisionShape3D.new()", "var __box_a1 := BoxShape3D.new()",
			"__box_a1.size = Vector3(1, 2, 1)", "__shape_a1.shape = __box_a1", "self.add_child(__shape_a1)"], "AddBoxShapeTo"],
		["a timer", "Node2D", ["var __timer_a1 := Timer.new()", "__timer_a1.wait_time = 2.0", "__timer_a1.autostart = true",
			"__timer_a1.timeout.connect(tick)", "self.add_child(__timer_a1)"], "AddTimerTo"],
	]:
		var source: String = _source(str(case[1]), PackedStringArray(case[2]))
		var ids: PackedStringArray = _opens_as(source)
		passed = SUPPORT.pin_value(NAME, "%s opens as one %s row" % [str(case[0]), str(case[3])], ids, PackedStringArray([str(case[3])])) and passed
		passed = _round_trips(source, str(case[0])) and passed
	return passed


## What the editor writes for a row with its id baked, reopened: the same row, the same bytes.
static func _runs_the_editor_writes() -> bool:
	var passed: bool = true
	for case: Array in [
		["AddNewNodeInto", {"type": "Area2D", "label": "\"Zone\"", "parent": "get_tree().current_scene", "name": "zone"}],
		["AddBehaviourInto", {"behaviour": "Timer", "target": "self", "once": "yes", "name": "clock"}],
		["RemoveBehaviour", {"behaviour": "Timer", "target": "self"}],
		["AddSpriteTo", {"texture": "load(\"res://icon.svg\")", "target": "self"}],
		["AddRectangleShapeTo", {"size": "Vector2(8, 8)", "target": "self"}],
		["AddCapsuleShapeTo", {"radius": "8.0", "height": "20.0", "target": "self"}],
		["AddTimerTo", {"seconds": "0.5", "callable": "tick", "target": "self"}],
	]:
		var ace_id: String = str(case[0])
		var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", ace_id)
		var params: Dictionary = {}
		for param: ACEParam in descriptor.params:
			params[param.id] = str(param.default_value)
		for key: Variant in (case[1] as Dictionary):
			params[key] = (case[1] as Dictionary)[key]
		params["uid"] = "c3f9"
		var lines: String = EventSheetActionCodegen._apply_template(descriptor.codegen_template, params)
		var source: String = _source(descriptor.node_type, lines.split("\n"))
		passed = SUPPORT.pin_value(NAME, "%s as the editor writes it opens as the same row" % ace_id,
			_opens_as(source), PackedStringArray([ace_id])) and passed
		passed = _round_trips(source, "editor " + ace_id) and passed
	return passed


## Short of the whole shape, a run stays the rows it always was.
static func _runs_that_keep_their_old_reading() -> bool:
	var passed: bool = true
	var with_arguments: String = _source("Node2D", PackedStringArray(["var marker := Marker2D.new(1)",
		"get_tree().current_scene.add_child(marker)"]))
	passed = SUPPORT.pin_value(NAME, "a node made with an argument is not claimed",
		_opens_as(with_arguments).has("AddNewNodeInto"), false) and passed
	passed = _round_trips(with_arguments, "made with an argument") and passed
	var bare_add: String = _source("Node2D", PackedStringArray(["var marker := Marker2D.new()", "add_child(marker)"]))
	passed = SUPPORT.pin_value(NAME, "a bare add_child is not claimed",
		_opens_as(bare_add).has("AddNewNodeInto"), false) and passed
	passed = _round_trips(bare_add, "bare add_child") and passed
	var follower: String = _source("Node3D", PackedStringArray(["var __follow_hat := RemoteTransform3D.new()",
		"%Head.add_child(__follow_hat)"]))
	passed = SUPPORT.pin_value(NAME, "a RemoteTransform made and parented is left to the follow reading",
		_opens_as(follower).has("AddNewNodeInto"), false) and passed
	passed = _round_trips(follower, "follow node") and passed
	var two_ids: String = _source("Node2D", PackedStringArray(["var __sprite_a1 := Sprite2D.new()",
		"__sprite_b2.texture = load(\"res://icon.svg\")", "self.add_child(__sprite_a1)"]))
	passed = SUPPORT.pin_value(NAME, "a run whose ids disagree is not claimed",
		_opens_as(two_ids).has("AddSpriteTo"), false) and passed
	return passed


## The values a lifted row holds are the ones the lines said.
static func _the_values() -> bool:
	var source: String = _source("Node2D", PackedStringArray(["var marker := Marker2D.new()", "marker.name = \"Spawn\"",
		"$Level.add_child(marker)"]))
	var actions: Array[ACEAction] = _actions(source)
	var params: Dictionary = actions[0].params if not actions.is_empty() else {}
	return SUPPORT.pins(NAME, [
		["the type is the class the node was made from", params.get("type", ""), "Marker2D"],
		["the name is the one the line gave it", params.get("label", ""), "\"Spawn\""],
		["the parent is whatever took it", params.get("parent", ""), "$Level"],
		["the variable is the author's own", params.get("name", ""), "marker"],
	])
