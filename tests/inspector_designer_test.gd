# Godot EventSheets - the Inspector Designer (whole-sheet Inspector view, P3 slice one).
#
# Pins the entry collection (dict variables alphabetical then tree variables in sheet order,
# EXPORTED only, combo options riding along) and the dialog's row build - both through the same
# preview-card builders the Variable dialog uses, so the whole-sheet view cannot drift from the
# per-variable one.
@tool
class_name InspectorDesignerTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true

	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.variables = {
		"speed": {"type": "int", "default": 5, "exported": true, "attributes": {"header": "Motion"}},
		"debug_seed": {"type": "int", "default": 0, "exported": false},
		"difficulty": {"type": "String", "default": "normal", "exported": true, "options": ["easy", "normal", "hard"]}
	}
	var tree_var: LocalVariable = LocalVariable.new()
	tree_var.name = "loot"
	tree_var.type_name = "Array"
	tree_var.default_value = []
	tree_var.exported = true
	tree_var.attributes = {"drawer": "table", "table_columns": [{"name": "item", "type": "String"}]}
	sheet.events.append(tree_var)
	var hidden_tree: LocalVariable = LocalVariable.new()
	hidden_tree.name = "internal_cache"
	hidden_tree.type_name = "Dictionary"
	hidden_tree.exported = false
	sheet.events.append(hidden_tree)

	var entries: Array[Dictionary] = EventSheetInspectorDesignerDialog.collect_entries(sheet)
	var entry_names: PackedStringArray = PackedStringArray()
	for entry: Dictionary in entries:
		entry_names.append(str(entry.get("name")))
	all_passed = _eq("dict vars come alphabetical, then tree vars; unexported ones are skipped",
		entry_names, PackedStringArray(["difficulty", "speed", "loot"])) and all_passed
	all_passed = _eq("combo options ride into the entry's attributes (the mock shows the dropdown)",
		(entries[0].get("attributes") as Dictionary).get("options"), ["easy", "normal", "hard"]) and all_passed
	all_passed = _eq("a tree var's attributes carry through (the table's columns)",
		((entries[2].get("attributes") as Dictionary).get("table_columns") as Array).size(), 1) and all_passed
	all_passed = _eq("a null sheet collects nothing",
		EventSheetInspectorDesignerDialog.collect_entries(null).is_empty(), true) and all_passed

	var dialog: EventSheetInspectorDesignerDialog = EventSheetInspectorDesignerDialog.new()
	dialog.rebuild_for_sheet(sheet)
	all_passed = _eq("the dialog shows one card per Inspector-visible variable", dialog.row_count(), 3) and all_passed
	dialog.rebuild_for_sheet(EventSheetResource.new())
	all_passed = _eq("an empty sheet shows the empty hint (no cards)", dialog.row_count(), 0) and all_passed
	dialog.free()

	return all_passed


static func _eq(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] inspector_designer_test: %s" % label)
		return true
	print("[FAIL] inspector_designer_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
