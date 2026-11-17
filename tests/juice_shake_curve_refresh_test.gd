# Godot EventSheets - the Shake card's drawing follows its curve, and says when the curve has edits that are not saved.
#
# THE ONE THING THIS FILE IS ABOUT: the curve a Shake card names is drawn with Godot's own curve editor, and an
# edit made there changes the curve in memory at once while the file the game plays keeps the old shape until it
# is saved. So the card's little drawing listens to the curve and redraws when it changes, and one quiet sentence
# says so while the curve and its file differ.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const FIELDS: String = "res://addons/eventsheet/editor/inspector/juice_shake_fields.gd"
const TEST_NAME: String = "juice_shake_curve_refresh"


static func run() -> bool:
	var fields: GDScript = load(FIELDS) as GDScript
	var path: String = SUPPORT.own_path("shake_curve.tres")
	var curve: Curve = Curve.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(1.0, 1.0))
	ResourceSaver.save(curve, path)
	var card: Dictionary = {"verb": "shake", "amount": 0.5, "seconds": 0.4, "curve": path}
	var live: Curve = load(path) as Curve
	var box: Variant = fields.call("shape_strip", card, Callable(), null)
	var before_line: String = str(fields.call("unsaved_line", card))
	var before_note_shown: bool = bool(box.get("note").visible)
	live.add_point(Vector2(0.5, 1.0))
	var after_line: String = str(fields.call("unsaved_line", card))
	var after_note_shown: bool = bool(box.get("note").visible)
	var refreshes: int = int(box.get("refreshes"))
	ResourceSaver.save(live, path)
	live.emit_changed()
	var saved_line: String = str(fields.call("unsaved_line", card))
	var saved_note_shown: bool = bool(box.get("note").visible)
	var plain: Variant = fields.call("shape_strip", {"verb": "shake", "fade_out": true}, Callable(), null)
	var without_curve: String = str(fields.call("unsaved_line", {"verb": "shake", "fade_out": true}))
	box.free()
	plain.free()
	return SUPPORT.pins(TEST_NAME, [
		["a curve that matches its file says nothing", before_line, ""],
		["and the card shows no sentence", before_note_shown, false],
		["an edit made in memory is told at once", after_line.is_empty(), false],
		["the sentence says the game plays the saved file", after_line.contains("saved file"), true],
		["the card listened to the curve changing", refreshes >= 1, true],
		["and shows the sentence under the drawing", after_note_shown, true],
		["saved, the sentence goes", saved_line, ""],
		["and the card hides it again", saved_note_shown, false],
		["a card that names no curve has nothing to say", without_curve, ""],
	])
