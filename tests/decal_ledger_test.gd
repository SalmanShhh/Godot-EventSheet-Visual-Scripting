@tool
class_name DecalLedgerTest
extends RefCounted

## The Decal Painter keeps its ledger of stamped decals and blob shadows as two small classes instead
## of dictionaries. These pins drive the ledger through the rows that touch it: a stamp is counted, the
## cap drops the oldest first, a blob shadow is found by the node it follows, and clearing empties both.

const SUPPORT := preload("res://tests/support.gd")
const NAME: String = "decal_ledger_test"
const PATH: String = "res://eventsheet_addons/decal_painter/decal_painter_behavior.gd"


static func run() -> bool:
	var script: GDScript = load(PATH) as GDScript
	var painter: Node = script.new() as Node
	var first: Decal = Decal.new()
	var second: Decal = Decal.new()
	var third: Decal = Decal.new()
	painter.call("_track", first, 0.0)
	painter.call("_track", second, 1.5)
	painter.call("_track", third, 3.0)
	var ledger: Array = painter.get("_decals")
	var rows: Array = [
		["three stamps are counted", painter.call("decal_count"), 3],
		["a stamp keeps the node it was made for", ledger[1].node, second],
		["and the lifetime it was given", [ledger[0].lifetime, ledger[1].lifetime, ledger[2].lifetime], [0.0, 1.5, 3.0]],
		["and the clock it was born at", ledger[0].born, 0.0],
	]
	painter.call("set_max_decals", 2)
	rows.append(["a lower cap drops the oldest first", [ledger.size(), ledger[0].node], [2, second]])
	var blob_class: GDScript = script.get_script_constant_map().get("BlobShadow") as GDScript
	var followed: Node3D = Node3D.new()
	var shadow: Variant = blob_class.new()
	shadow.id = followed.get_instance_id()
	shadow.decal = Decal.new()
	shadow.mask = 5
	var blobs: Array = painter.get("_blobs")
	blobs.append(shadow)
	rows.append(["a blob shadow is held with its mask", [blobs.size(), blobs[0].mask], [1, 5]])
	painter.call("stop_blob_shadow", Node3D.new())
	rows.append(["a node nothing follows leaves the shadows alone", blobs.size(), 1])
	painter.call("stop_blob_shadow", followed)
	rows.append(["stopping the followed node's shadow removes it", (painter.get("_blobs") as Array).size(), 0])
	painter.call("clear_decals")
	rows.append(["clearing empties the ledger", [(painter.get("_decals") as Array).size(), painter.call("decal_count")], [0, 0]])
	var passed: bool = SUPPORT.pins(NAME, rows)
	painter.free()
	return passed
