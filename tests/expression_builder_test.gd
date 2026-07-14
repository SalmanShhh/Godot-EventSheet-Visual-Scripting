@tool
class_name ExpressionBuilderTest
extends RefCounted
# The "Insert Expression" window's operator palette and its tree results both insert at the caret of
# the expression field via _insert_into_expression_target(). That field is always a CodeEdit, but the
# old insert path only handled LineEdit - so picking a result (or, now, an operator) silently did
# nothing. These pin the shared helper for both the CodeEdit (the real case) and a LineEdit fallback.


static func run() -> bool:
	var all_passed: bool = true
	var host: Node = Node.new()
	var dlg: ACEParamsDialog = ACEParamsDialog.new()
	dlg.init_dialog(host)

	# A CodeEdit expression field, as registered by _create_expression_field (the fx picker's target).
	var edit: CodeEdit = CodeEdit.new()
	edit.text = "health"
	host.add_child(edit)
	dlg._fields["value"] = edit
	dlg._expression_picker._expression_target_key = "value"
	edit.set_caret_column(edit.text.length())  # caret at end, as after focusing the field

	# Operator palette (" + ") then a chained value ("10") compose at the caret - the regression guard:
	# before the fix this CodeEdit branch was missing, so both inserts were no-ops.
	dlg._insert_into_expression_target(" + ")
	dlg._insert_into_expression_target("10")
	all_passed = _check("inserts compose at the CodeEdit caret", edit.text, "health + 10") and all_passed

	# The LineEdit fallback still works (parity for any future LineEdit-backed expression field).
	var line: LineEdit = LineEdit.new()
	line.text = "x"
	host.add_child(line)
	dlg._fields["other"] = line
	dlg._expression_picker._expression_target_key = "other"
	line.caret_column = line.text.length()
	dlg._insert_into_expression_target(" > 5")
	all_passed = _check("inserts into a LineEdit target too", line.text, "x > 5") and all_passed
	host.free()

	# (c) Non-self reflection - a class-backed sheet variable's members are pickable as `enemy.member`.
	all_passed = _check("variable member fragment (property)",
		ACEParamsDialog.variable_member_fragment("enemy", "health", false), "enemy.health") and all_passed
	all_passed = _check("variable member fragment (method)",
		ACEParamsDialog.variable_member_fragment("enemy", "move_and_slide", true), "enemy.move_and_slide()") and all_passed

	# Build the Insert-Expression tree over a sheet with enemy: CharacterBody2D and assert the reflection.
	var host2: Node = Node.new()
	var dlg2: ACEParamsDialog = ACEParamsDialog.new()
	dlg2.init_dialog(host2, EventSheetACERegistry.new())
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.variables = {"enemy": {"type": "CharacterBody2D"}, "score": {"type": "int"}}
	dlg2.set_lint_context_provider(func() -> EventSheetResource: return sheet)
	dlg2._ensure_expression_window()  # builds _expression_search + _expression_tree (no popup, headless-safe)
	dlg2._expression_picker._expression_target_key = "value"

	# Empty search → the sheet's variables show as one-click leaves.
	dlg2._expression_picker._expression_search.text = ""
	dlg2._refresh_expression_tree()
	all_passed = _check("sheet variable leaf 'enemy' is listed", _tree_has_item(dlg2._expression_picker._expression_tree, "enemy"), true) and all_passed
	all_passed = _check("sheet variable leaf 'score' is listed", _tree_has_item(dlg2._expression_picker._expression_tree, "score"), true) and all_passed

	# Searching 'velocity' → enemy.velocity is offered (CharacterBody2D reflection); score (int) adds nothing.
	dlg2._expression_picker._expression_search.text = "velocity"
	dlg2._refresh_expression_tree()
	all_passed = _check("chained member 'enemy.velocity' is offered", _tree_has_item(dlg2._expression_picker._expression_tree, "enemy.velocity"), true) and all_passed

	# TREE variables (LocalVariable rows) - an opened .gd stores its @export/State vars and the host
	# binding this way, NOT in the `variables` dict. The picker must list them too, and a class-backed one
	# (host) chains like a dict var. This is the #5 fix: real packs showed nothing before.
	var host_var: LocalVariable = LocalVariable.new()
	host_var.name = "host"
	host_var.type_name = "CharacterBody2D"
	sheet.events.append(host_var)
	var speed_var: LocalVariable = LocalVariable.new()
	speed_var.name = "move_speed"
	speed_var.type_name = "float"
	sheet.events.append(speed_var)
	dlg2._expression_picker._expression_search.text = ""
	dlg2._refresh_expression_tree()
	all_passed = _check("tree variable 'host' is listed", _tree_has_item(dlg2._expression_picker._expression_tree, "host"), true) and all_passed
	all_passed = _check("tree variable 'move_speed' is listed", _tree_has_item(dlg2._expression_picker._expression_tree, "move_speed"), true) and all_passed
	dlg2._expression_picker._expression_search.text = "velocity"
	dlg2._refresh_expression_tree()
	all_passed = _check("tree variable 'host' chains 'host.velocity'", _tree_has_item(dlg2._expression_picker._expression_tree, "host.velocity"), true) and all_passed
	host2.free()
	return all_passed


## Recursively true when the tree contains an item whose column-0 text equals `text`.
static func _tree_has_item(tree: Tree, text: String) -> bool:
	return tree != null and _walk_item(tree.get_root(), text)


static func _walk_item(item: TreeItem, text: String) -> bool:
	if item == null:
		return false
	var child: TreeItem = item.get_first_child()
	while child != null:
		if child.get_text(0) == text or _walk_item(child, text):
			return true
		child = child.get_next()
	return false


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] expression_builder_test: %s" % label)
		return true
	print("[FAIL] expression_builder_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
