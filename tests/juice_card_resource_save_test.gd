# Godot EventSheets - a new Curve a Shake card is about to keep is saved as a file with a uid first.
#
# THE ONE THING THIS FILE IS ABOUT: a card keeps the ADDRESS of a resource's file as text, never a copy inside
# the scene. Godot's own picker makes a new Curve with no file, so the card asks where to save it, writes it, gives
# the file an id of its own (a plain save writes none, so a moved file would be lost) and keeps that id. A new curve
# starts as a straight fall so it is a shape from the first moment, and a curve that already has points is kept as
# it is. The file dialog itself is the editor's and is proved in the real editor; this is what happens to the file.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const SAVER: String = "res://addons/eventsheet/editor/inspector/juice_card_resource_save.gd"
const TEST_NAME: String = "juice_card_resource_save"


static func run() -> bool:
	var saver: Script = load(SAVER) as Script
	var fresh: Curve = Curve.new()
	var fresh_path: String = SUPPORT.own_path("fresh_curve.tres")
	var fresh_uid: String = str(saver.call("keep", fresh, fresh_path))
	var drawn: Curve = Curve.new()
	drawn.add_point(Vector2(0.0, 0.0))
	drawn.add_point(Vector2(0.15, 1.0))
	drawn.add_point(Vector2(1.0, 0.0))
	var drawn_path: String = SUPPORT.own_path("drawn_curve.tres")
	var drawn_uid: String = str(saver.call("keep", drawn, drawn_path))
	var back: Curve = load(fresh_uid) as Curve if fresh_uid.begins_with("uid://") else null
	var back_drawn: Curve = load(drawn_uid) as Curve if drawn_uid.begins_with("uid://") else null
	var registered: String = ResourceUID.id_to_text(ResourceLoader.get_resource_uid(fresh_path))
	return SUPPORT.pins(TEST_NAME, [
		["a new curve is kept as the uid of its file", fresh_uid.begins_with("uid://"), true],
		["the file is known by that uid, which a plain save would not have given it", registered, fresh_uid],
		["the card's text loads the curve back", back != null, true],
		["a new curve starts as a straight fall from full to nothing", [back.point_count, back.get_point_position(0), back.get_point_position(1)] if back != null else [], [2, Vector2(0.0, 1.0), Vector2(1.0, 0.0)]],
		["a curve that already has points keeps them", back_drawn.point_count if back_drawn != null else -1, 3],
		["and keeps their places", back_drawn.get_point_position(1) if back_drawn != null else Vector2.ZERO, Vector2(0.15, 1.0)],
	])
