# Godot EventSheets — the ACE picker is a single muted column (Godot Create-New-Node style).
#
# The redundant "Type" column and the per-row type tint are gone; an ACE's type is read from its row
# icon, its tooltip, and the description panel instead. This pins the structure (one column) and that
# populating the tree does NOT error — a missed column-1 setter (set_text/custom_color/selectable(1,…))
# would crash on a single-column Tree, so the populate step is the real regression guard.
@tool
class_name PickerLayoutTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true
	var parent: Node = Node.new()
	var registry := EventSheetACERegistry.new()
	registry.refresh_from_sources([], true)  # built-in ACEs only
	var picker := ACEPickerDialog.new()
	picker.init_dialog(parent, registry)

	ok = _check("tree is single-column (Type column removed)", picker._tree.columns, 1) and ok

	# Populate in append_action mode — a leftover set_*(1, …) would error on a one-column Tree.
	picker._context = {"mode": "append_action", "signals_only": false, "selected_resource": null}
	picker._refresh_tree()
	var first: TreeItem = picker._first_definition_item(picker._tree.get_root())
	ok = _check("rows populate and carry their ACEDefinition metadata", first != null and first.get_metadata(0) is ACEDefinition, true) and ok
	# Featured verbs float to the top: in append_action mode the very first row is a featured action.
	ok = _check("a featured verb floats to the top of the list", first != null and picker._is_featured(first.get_metadata(0)), true) and ok

	# Codegen panel is visible-but-muted: a built-in ACE's template is shown color-wrapped, not raw [code].
	if first != null and first.get_metadata(0) is ACEDefinition:
		var def: ACEDefinition = first.get_metadata(0)
		picker._update_info_panel(def)
		if not str(def.metadata.get("codegen_template", "")).is_empty():
			ok = _check("codegen in the description is muted (color-wrapped)", picker._info_label.text.contains("[color=#") and picker._info_label.text.contains("[code]"), true) and ok

	parent.free()
	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] picker_layout_test: %s" % label)
		return true
	print("[FAIL] picker_layout_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
