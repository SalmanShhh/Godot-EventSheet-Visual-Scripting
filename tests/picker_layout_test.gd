# Godot EventSheets - the ACE picker is a single muted column (Godot Create-New-Node style).
#
# The redundant "Type" column and the per-row type tint are gone; an ACE's type is read from its row
# icon, its tooltip, and the description panel instead. This pins the structure (one column) and that
# populating the tree does NOT error - a missed column-1 setter (set_text/custom_color/selectable(1,…))
# would crash on a single-column Tree, so the populate step is the real regression guard.
@tool
class_name PickerLayoutTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	# Section descriptions registry: core categories are seeded, and describe() adds/overrides.
	ok = _check("a core category has a seeded description",
		not EventSheetSectionInfo.description_for("Editor Tools").is_empty(), true) and ok
	EventSheetSectionInfo.describe("__picker_test_section__", "a test blurb")
	ok = _check("describe() registers a custom section description",
		EventSheetSectionInfo.description_for("__picker_test_section__"), "a test blurb") and ok

	var parent: Node = Node.new()
	var registry := EventSheetACERegistry.new()
	registry.refresh_from_sources([], true)  # built-in ACEs only
	var picker := ACEPickerDialog.new()
	picker.init_dialog(parent, registry)

	ok = _check("tree is single-column (Type column removed)", picker._tree.columns, 1) and ok

	# Populate in append_action mode - a leftover set_*(1, …) would error on a one-column Tree.
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

	# Section headers are now selectable and carry a {"section": name} marker, so selecting one shows a
	# group description instead of an ACE (and Add stays disabled - a header is not addable).
	var header: TreeItem = _first_section_header(picker._tree.get_root())
	ok = _check("category headers carry a selectable section marker",
		header != null and header.is_selectable(0) and header.get_metadata(0) is Dictionary and (header.get_metadata(0) as Dictionary).has("section"), true) and ok
	if header != null and first != null:
		var section_name: String = str((header.get_metadata(0) as Dictionary)["section"])
		picker._selected_definition = first.get_metadata(0)
		picker._add_button.disabled = false
		picker._show_section_info(header, section_name)
		ok = _check("selecting a section header shows its description and disables Add",
			picker._info_label.text.contains(section_name) and picker._add_button.disabled and picker._selected_definition == null, true) and ok

	parent.free()
	return ok


## Depth-first search for the first section-header row (its metadata is a {"section": name} marker).
static func _first_section_header(item: TreeItem) -> TreeItem:
	var child: TreeItem = item.get_first_child()
	while child != null:
		var meta: Variant = child.get_metadata(0)
		if meta is Dictionary and (meta as Dictionary).has("section"):
			return child
		var nested: TreeItem = _first_section_header(child)
		if nested != null:
			return nested
		child = child.get_next()
	return null


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] picker_layout_test: %s" % label)
		return true
	print("[FAIL] picker_layout_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
