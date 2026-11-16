# Godot EventSheets - a shape that draws nothing says so: one quiet amber line of at most two short
# sentences, on the open card and in the folded card's summary. And a list holding entries the card does
# not understand keeps them through an edit.
@tool
class_name DrawingPrefabFindingsTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const PREFIX := "drawing_prefab_findings_test"
const PREFAB_STEPS := preload("res://addons/eventsheet/editor/inspector/drawing_prefab_steps_property.gd")


static func _step(kind: String, extra: Dictionary) -> Dictionary:
	var step: Dictionary = {"kind": kind, "x": 0.0, "y": 0.0, "p1": 10.0, "p2": 10.0, "p3": 4.0, "color": "#ffffff", "texture": ""}
	for key: Variant in extra:
		step[str(key)] = extra[key]
	return step


static func _sentences(text: String) -> int:
	return text.count(". ") + (1 if text.ends_with(".") else 0)


static func run() -> bool:
	var editor_class: GDScript = PREFAB_STEPS.ShapeStepsEditor
	var rows: Array = []
	var cases: Array = [
		["a stamp with no texture", _step("stamp", {}), true],
		["a stamp whose texture does not load", _step("stamp", {"texture": "res://nothing/here.png"}), true],
		["a stamp with a texture that loads", _step("stamp", {"texture": "res://eventsheet_addons/drawing_prefab_stamp/icon.svg"}), false],
		["a circle of radius 0", _step("circle", {"p1": 0.0}), true],
		["a ring of radius 0", _step("ring", {"p1": 0.0}), true],
		["a ring with a radius", _step("ring", {}), false],
		["a rectangle of width 0", _step("rect", {"p1": 0.0}), true],
		["a rectangle of height 0", _step("rect", {"p2": 0.0}), true],
		["a rectangle with a size", _step("rect", {}), false],
		["a line with no length", _step("line", {"x": 5.0, "y": 5.0, "p1": 5.0, "p2": 5.0}), true],
		["a line with a length", _step("line", {"p1": 5.0, "p2": 5.0}), false],
		["a cone with a field of view of 0", _step("cone", {"p2": 0.0}), true],
		["a cone with a field of view", _step("cone", {}), false],
		["a shape this list does not know", _step("blob", {}), true],
	]
	for case: Array in cases:
		var finding: String = str(editor_class.call("finding_of", case[1]))
		rows.append(["%s: %s" % [case[0], "has a finding" if case[2] else "has none"], not finding.is_empty(), case[2]])
		rows.append(["%s: at most two short sentences" % case[0], _sentences(finding) <= 2 and finding.length() <= 110, true])
	rows.append(["the textureless stamp's finding says why", editor_class.call("finding_of", _step("stamp", {})), "No texture yet, so this shape draws nothing."])
	rows.append(["a zero width names the field", editor_class.call("finding_of", _step("rect", {"p1": 0.0})), "Width is 0, so this rectangle draws nothing."])
	rows.append(["a lengthless line names the cause", editor_class.call("finding_of", _step("line", {"x": 5.0, "p1": 5.0, "y": 5.0, "p2": 5.0})), "The start and the end are the same point, so this line has no length."])
	# The folded card says it too, in its summary.
	rows.append(["the folded summary of a textureless stamp", editor_class.call("summary_of", _step("stamp", {})), "no texture"])
	rows.append(["the folded summary of a missing file", editor_class.call("summary_of", _step("stamp", {"texture": "res://nothing/here.png"})), "here.png (not found)"])
	rows.append(["the folded summary of a flat rectangle", editor_class.call("summary_of", _step("rect", {"p1": 0.0, "p2": 16.0})), "0 x 16"])
	# An unknown kind is a card that says so, with a Shape row to repair it, and it is kept as it is.
	var editor: PREFAB_STEPS.ShapeStepsEditor = PREFAB_STEPS.ShapeStepsEditor.new()
	var unknown: Dictionary = _step("blob", {"wobble": 3.0})
	editor.set_steps([_step("circle", {}), unknown])
	rows.append(["an unknown shape's card says so", editor.card_labels()[1], "Unknown shape"])
	editor.call("set_unfolded", 1, true)
	var notes: PackedStringArray = PackedStringArray(editor.call("visible_notes"))
	rows.append(["its open card carries the finding", ",".join(notes).contains("blob"), true])
	rows.append(["its open card keeps a Shape row so it can be repaired", editor.call("field_keys_of", 1).has("kind"), true])
	editor.write_card_key(0, "p1", 7.0)
	rows.append(["an edit elsewhere keeps the unknown card exactly as it was", editor.get_steps()[1], unknown])
	editor.free()
	# Junk in the list (not a Dictionary at all) survives an edit instead of being dropped.
	var junk: PREFAB_STEPS.ShapeStepsEditor = PREFAB_STEPS.ShapeStepsEditor.new()
	junk.set_steps([_step("circle", {}), 5, "words", null, _step("ring", {})])
	junk.write_card_key(0, "p1", 9.0)
	var kept: Array = junk.get_steps()
	rows.append(["an edit keeps every entry it does not understand", kept.size(), 5])
	rows.append(["the junk is where it was", [kept[1], kept[2], kept[3]], [5, "words", null]])
	rows.append(["the edit reached the card it was for", float((kept[0] as Dictionary).get("p1")), 9.0])
	junk.move_card(0, 1)
	rows.append(["a move keeps them too", junk.get_steps().size(), 5])
	junk.remove_card(0)
	rows.append(["and removing a card removes only that card", junk.get_steps().size(), 4])
	rows.append(["only the cards are cards", junk.card_labels().size(), 1])
	junk.free()
	return SUPPORT.pins(PREFIX, rows)
