# Godot EventSheets - the two quiet captions at the ends of a Drawing Prefab's list: the first card is
# drawn first, underneath; the last is drawn last, on top. They stay at the two ends however the list
# is changed, and an empty list shows neither.
@tool
class_name DrawingPrefabOrderCaptionsTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const PREFIX := "drawing_prefab_order_captions_test"
const PREFAB_STEPS := preload("res://addons/eventsheet/editor/inspector/drawing_prefab_steps_property.gd")

const FIRST := "Drawn first, underneath"
const LAST := "Drawn last, on top"


static func _step(kind: String, radius: float) -> Dictionary:
	return {"kind": kind, "x": 0.0, "y": 0.0, "p1": radius, "p2": 0.0, "p3": 0.0, "color": "#ffffff", "texture": ""}


static func _captions(editor: Object) -> String:
	return "|".join(PackedStringArray(editor.call("order_caption_texts")))


static func run() -> bool:
	var editor: PREFAB_STEPS.ShapeStepsEditor = PREFAB_STEPS.ShapeStepsEditor.new()
	var rows: Array = []
	rows.append(["an empty list says nothing about order", _captions(editor), ""])
	editor.set_steps([_step("circle", 1.0), _step("ring", 2.0), _step("rect", 3.0)])
	rows.append(["a list says which end is drawn first and which last", _captions(editor), FIRST + "|" + LAST])
	editor.move_card(2, 0)
	rows.append(["the captions stay at the two ends after a move", _captions(editor), FIRST + "|" + LAST])
	editor.select_card(1)
	editor.cut_selected()
	rows.append(["and after a cut", _captions(editor), FIRST + "|" + LAST])
	editor.select_card(0)
	editor.paste_after_selection(EventSheetCardSchemas.cards_to_text([_step("cone", 4.0)]))
	rows.append(["and after a paste", _captions(editor), FIRST + "|" + LAST])
	rows.append(["the list is unchanged by showing them", editor.get_steps().size(), 3])
	for _round: int in range(3):
		editor.select_card(0)
		editor.remove_selected()
	rows.append(["a list emptied by removing every card shows none", _captions(editor), ""])
	editor.free()
	var plain: EventSheetCardListDrawer = EventSheetCardListDrawer.new({"schema_dict": {"kinds": [{"kind": "a", "label": "A", "fields": []}]}})
	plain.set_value([{"kind": "a"}])
	rows.append(["a list whose schema asks for no captions shows none", "|".join(PackedStringArray(plain.call("order_caption_texts"))), ""])
	plain.free()
	return SUPPORT.pins(PREFIX, rows)
