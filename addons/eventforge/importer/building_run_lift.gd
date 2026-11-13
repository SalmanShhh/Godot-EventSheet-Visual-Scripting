# EventForge - the Building runs that are several statements and one sentence.
#
# Making a node by hand is a few lines that only mean something together: a local made from a type, a
# name given to it, a parent that takes it. Written a line at a time they are three unrelated rows (a
# typed local, a property, an Add Child); read as a run they are the one Building row that emits them:
#
#     var marker := Marker2D.new()                          Add a new Marker2D named "Spawn" under
#     marker.name = "Spawn"                                 the running scene, into marker
#     get_tree().current_scene.add_child(marker)
#
# THE ENTRIES ARE DERIVED, not written out. Each row's template carries the optional lines and the
# choice a row can make; an entry here is that template with them collapsed to ONE combination, turned
# into patterns mechanically (every character outside a `{slot}` escaped, every slot a named capture,
# a slot spelled twice a back reference to the first). The shape an entry stores is therefore the exact
# text the row emits, which is what makes the byte round trip the shape of the mechanism and not a
# promise this file keeps.
#
# THE BAKED PER-ROW ID. A part row names its throwaway locals `__sprite_<id>`, `__shape_<id>` and so on,
# where the editor bakes a short id when the row is dropped. The id is not a value of the row: it is
# captured as one token that has to read the same on every line of the run, and rides back out as the
# author's own spelling, exactly like the temporary a swap uses.
#
# WHAT IS NOT CLAIMED. A run that is short of the whole shape (a node made and parented with no extra
# line between is the shape; a node made with `.new(argument)` is not), a node added with a bare
# `add_child(...)` and no receiver, a behaviour looked up under another name. Each keeps the reading it
# already had, which is the intended failure: an honest run of ordinary rows, never a mangled one.
@tool
class_name EventForgeBuildingRunLift
extends RefCounted

## The module the shapes come from, by path so the importer never waits on the editor's class cache, and
## read only when the entries are first built, so a first open of a sheet does not compile the module.
const BUILDING_PATH := "res://addons/eventforge/registration/modules/building_aces.gd"
const SPAWN_LIFT := preload("res://addons/eventforge/importer/spawn_run_lift.gd")

## The id a shape is written with. A token no template or sample contains, replaced in each pattern
## by a capture that reads any run of letters and digits.
const TOKEN: String = "uq9z"

## The value spans a slot can hold, as the spawn runs use them.
const IDENTIFIER: String = EventForgeLiftGrammar.IDENTIFIER

## Built once for the life of the session.
static var _entries: Array[Dictionary] = []


## The row a run of statements means, or {} when nothing here claims it.
static func match_run(lines: PackedStringArray, index: int, depth: int) -> Dictionary:
	return EventForgeLiftTable.match_run(lift_entries(), lines, index, depth)


## The rows, one entry per combination of their optional lines. The longer run of a pair comes first,
## so the shorter one cannot claim the front of it and leave its last line stranded.
static func lift_entries() -> Array[Dictionary]:
	if not _entries.is_empty():
		return _entries
	var built: Array[Dictionary] = []
	built.append(_entry("building_new_node_named", "AddNewNodeInto", {"label": "x"}, ".new()", {
		"type": "Marker2D", "label": "\"Spawn\"", "parent": "get_tree().current_scene", "name": "marker"}))
	built.append(_entry("building_new_node", "AddNewNodeInto", {"label": ""}, ".new()", {
		"type": "Marker2D", "parent": "get_tree().current_scene", "name": "marker"}))
	built.append(_entry("building_behaviour_only_one", "AddBehaviourInto", {"once": "yes"}, ".get_node_or_null(", {
		"behaviour": "Timer", "target": "self", "name": "clock"}))
	# Add Behaviour with Allow another has NO entry of its own: its three lines are, character for
	# character, Add New Node with a name that is the class's own (`var b := X.new()`, `b.name = "X"`,
	# `parent.add_child(b)`), and two entries for one spelling would split every such run by table
	# order alone. The run opens as Add New Node, which re-emits the author's own bytes either way.
	built.append(_entry("building_remove_behaviour", "RemoveBehaviour", {}, ".get_node_or_null(", {
		"behaviour": "Timer", "target": "self"}))
	built.append(_entry("building_sprite", "AddSpriteTo", {}, "Sprite2D.new()", {
		"texture": "load(\"res://icon.svg\")", "target": "self"}))
	built.append(_entry("building_sprite_3d", "AddSprite3DTo", {}, "Sprite3D.new()", {
		"texture": "load(\"res://icon.svg\")", "target": "self"}))
	built.append(_entry("building_circle_shape", "AddCircleShapeTo", {}, "CollisionShape2D.new()", {
		"radius": "16.0", "target": "self"}))
	built.append(_entry("building_rectangle_shape", "AddRectangleShapeTo", {}, "CollisionShape2D.new()", {
		"size": "Vector2(32, 32)", "target": "self"}))
	built.append(_entry("building_capsule_shape", "AddCapsuleShapeTo", {}, "CollisionShape2D.new()", {
		"radius": "16.0", "height": "48.0", "target": "self"}))
	built.append(_entry("building_sphere_shape", "AddSphereShapeTo", {}, "CollisionShape3D.new()", {
		"radius": "0.5", "target": "self"}))
	built.append(_entry("building_box_shape", "AddBoxShapeTo", {}, "CollisionShape3D.new()", {
		"size": "Vector3(1, 1, 1)", "target": "self"}))
	built.append(_entry("building_capsule_shape_3d", "AddCapsuleShape3DTo", {}, "CollisionShape3D.new()", {
		"radius": "0.5", "height": "2.0", "target": "self"}))
	built.append(_entry("building_timer", "AddTimerTo", {}, "Timer.new()", {
		"seconds": "2.0", "callable": "tick", "target": "self"}))
	built.append(_entry("building_prefab", "KeepAsPrefab", {}, "var __branch_", {
		"node": "self", "prefab": "my_prefab"}))
	_entries = built
	return _entries


## One entry, from the row's template with its optional lines collapsed to one combination. `chosen`
## is what the collapse reads (a non-blank label keeps the name line, `once` picks a shape); `samples`
## are the values the harness fills the shape's slots with.
static func _entry(id: String, ace_id: String, chosen: Dictionary, mark: String, samples: Dictionary) -> Dictionary:
	var descriptor: ACEDescriptor = _descriptor(ace_id)
	var template: String = descriptor.codegen_template if descriptor != null else ""
	var shape: String = EventSheetActionCodegen.collapse_optional_segments(template, chosen).replace("{uid}", TOKEN)
	var statements: Array[Dictionary] = []
	for line: String in shape.split("\n"):
		var bare: String = line.lstrip("\t")
		statements.append({"pattern": _pattern(bare),
			EventForgeLiftTable.INDENT_KEY: line.length() - bare.length()})
	var params: PackedStringArray = EventForgeLiftTable.shape_slot_names(shape)
	var slots: Dictionary = {}
	for slot: String in params:
		slots[slot] = samples.get(slot, "")
	var remaining: Dictionary = _defaults_of(descriptor)
	remaining.merge(chosen, true)
	for slot: String in params:
		remaining.erase(slot)
	return {
		"id": id,
		"ace_id": ace_id,
		EventForgeLiftTable.MARK_KEY: mark,
		EventForgeLiftTable.STATEMENTS_KEY: statements,
		"params": params,
		"defaults": remaining,
		"shape": shape.replace(TOKEN, "a1"),
		"slots": slots,
	}


## One statement of a shape as a pattern. The slots become captures the way the spawn runs make them
## (the name an identifier, a slot that ends its line the rest of it, any other the shortest run that
## lets the line finish), and the baked id becomes a capture that every later use must repeat.
static func _pattern(line: String) -> String:
	var pattern: String = SPAWN_LIFT.statement_pattern(line)
	var marker: String = "_" + TOKEN
	var at: int = pattern.find(marker)
	if at < 0:
		return pattern
	var first: String = "_(?<uid>[A-Za-z0-9]+)"
	pattern = pattern.substr(0, at) + first + pattern.substr(at + marker.length())
	return pattern.replace(marker, "_\\k<uid>")


static func _descriptor(ace_id: String) -> ACEDescriptor:
	var building: GDScript = load(BUILDING_PATH)
	for descriptor: ACEDescriptor in building.get_descriptors():
		if descriptor.ace_id == ace_id:
			return descriptor
	return null


static func _defaults_of(descriptor: ACEDescriptor) -> Dictionary:
	var values: Dictionary = {}
	if descriptor == null:
		return values
	for parameter: ACEParam in descriptor.params:
		values[parameter.id] = parameter.default_value
	return values
