# Godot EventSheets - a 3D file reads a line as the 3D verb, not as the 2D verb that registered first.
#
# A 2D verb and its 3D twin write the same line (`$Ray.collision_mask = 1`), and the reverse index
# gave the line to whichever registered first, so a 3D file showed a RayCast2D row. A file that
# extends a 3D class now gets the 3D twin; a 2D file and a file that extends neither (a plain Node)
# keep the answer they always had, and the bytes are the same line either way.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "lift_dimension_twins_test"


static func run() -> bool:
	var rows: Array = []
	for host: String in ["Node3D", "Node2D", "Node"]:
		var source: String = "extends %s\n\n\nfunc _ready() -> void:\n\t$Ray.collision_mask = 1\n" % host
		var sheet: EventSheetResource = SUPPORT.reopen(source)
		rows.append(["%s file: the line is one lifted row" % host, _ace_ids(sheet).size(), 1])
		rows.append(["%s file: reads as" % host, _ace_ids(sheet), ["RayCast3DSetMask"] if host == "Node3D" else ["RayCast2DSetMask"]])
		rows.append(["%s file: still the same bytes" % host, SUPPORT.reemit(source, SUPPORT.own_path("twin_%s.gd" % host)), source])
	# A verb with no twin is read the same in both.
	var lone: EventSheetResource = SUPPORT.reopen("extends Node3D\n\n\nfunc _ready() -> void:\n\t$Body.velocity += Vector3.UP\n")
	rows.append(["a verb with no 3D twin keeps its reading in a 3D file", _ace_ids(lone), ["AddVelocity"]])
	# The state is the read's own: a 2D file read right after a 3D one is not shown in 3D.
	var after: EventSheetResource = SUPPORT.reopen("extends Node2D\n\n\nfunc _ready() -> void:\n\t$Ray.collision_mask = 1\n")
	rows.append(["a 2D file read after a 3D one reads in 2D", _ace_ids(after), ["RayCast2DSetMask"]])
	return SUPPORT.pins(P, rows)


## The ace ids of every action in the file's functions and events, in order.
static func _ace_ids(sheet: EventSheetResource) -> Array:
	var found: Array = []
	if sheet == null:
		return found
	var pending: Array = []
	pending.append_array(sheet.events)
	pending.append_array(sheet.functions)
	while not pending.is_empty():
		var entry: Variant = pending.pop_front()
		if entry is EventRow:
			for action: Variant in (entry as EventRow).actions:
				if action is ACEAction:
					found.append(str((action as ACEAction).ace_id))
			pending.append_array((entry as EventRow).sub_events)
		elif entry is EventFunction:
			pending.append_array((entry as EventFunction).events)
	return found
