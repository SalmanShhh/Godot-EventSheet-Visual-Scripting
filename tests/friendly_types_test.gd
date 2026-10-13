@tool
class_name FriendlyTypesTest
extends RefCounted
# The variable dialog's type list names every type as GDScript writes it, with the plain words beside
# it ("int · Whole number"), and stores the type itself as the item's metadata - so the .gd round
# trip never depends on the words. These pin the selection in both directions: a stored type lands
# on its own entry, a node or resource class lands on its slot entry with the class typed beside
# it, and a type the list does not name is added rather than lost.


const SUPPORT := preload("res://tests/support.gd")


static func run() -> bool:
	var host: Node = Node.new()
	var dlg: VariableDialog = VariableDialog.new()
	dlg.init_dialog(host)
	var rows: Array = []
	for type_name: String in ["int", "float", "String", "bool", "Vector3i", "StringName"]:
		dlg._select_stored_type(type_name)
		rows.append(["%s is stored as itself" % type_name, dlg._selected_stored_type(), type_name])
	dlg.open_for_edit("global", {}, "speed", "float", "200.0", false, "Edit", false, false)
	rows.append(["editing a float lands on float", dlg._type_option.get_item_text(dlg._type_option.selected), "float · Number with decimals"])
	dlg.open_for_edit("global", {}, "body", "Sprite2D", "", false, "Edit", false, true)
	rows.append(["a node class lands on the node entry", str(dlg._type_option.get_item_metadata(dlg._type_option.selected)), "Node2D"])
	rows.append(["…with the class typed beside it", dlg._class_edit.text, "Sprite2D"])
	rows.append(["…and the class is what is stored", dlg._selected_stored_type(), "Sprite2D"])
	dlg.open_for_edit("global", {}, "spots", "Array[Vector2i]", "[]", false, "Edit", false, true)
	rows.append(["a type the list does not name is kept", dlg._selected_stored_type(), "Array[Vector2i]"])
	rows.append(["every type option says what it holds", _undescribed(dlg._type_option), PackedStringArray()])
	host.free()
	return SUPPORT.pins("friendly_types_test", rows)


## The options of a dropdown that carry no hover sentence, by their words (separators excepted).
static func _undescribed(option: OptionButton) -> PackedStringArray:
	var bare: PackedStringArray = PackedStringArray()
	for index: int in range(option.item_count):
		if not option.is_item_separator(index) and option.get_item_tooltip(index).strip_edges().is_empty():
			bare.append(option.get_item_text(index))
	return bare
