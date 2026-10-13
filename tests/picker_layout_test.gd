# Godot EventSheets - the ACE picker is a single muted column (Godot Create-New-Node style).
#
# The redundant "Type" column and the per-row type tint are gone; an ACE's type is read from its row
# icon, its tooltip, and the description panel instead. This pins the structure (one column) and that
# populating the tree does NOT error - a missed column-1 setter (set_text/custom_color/selectable(1,…))
# would crash on a single-column Tree, so the populate step is the real regression guard.
@tool
class_name PickerLayoutTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")


static func run() -> bool:
	var ok: bool = true

	# Section descriptions registry: describe() adds/overrides. The seeded core descriptions are
	# pinned by value in editor_tool_census_test.
	EventSheetSectionInfo.describe("__picker_test_section__", "a test blurb")
	ok = _check("describe() registers a custom section description",
		EventSheetSectionInfo.description_for("__picker_test_section__"), "a test blurb") and ok

	var parent: Node = Node.new()
	var registry := EventSheetACERegistry.new()
	registry.refresh_from_sources([], true)  # built-in ACEs only
	var picker := ACEPickerDialog.new()
	picker.init_dialog(parent, registry)

	ok = _check("tree is single-column (Type column removed)", picker._tree.columns, 1) and ok
	# The pin button wears the editor's Favorites icon; with no editor theme to ask (headless, as
	# here) it says what it does in a word - never an emoji the editor font may not even carry.
	ok = _check("the pin button falls back to a word, not an emoji", picker._favorite_button.text, "Pin") and ok

	# Populate in append_action mode - a leftover set_*(1, …) would error on a one-column Tree.
	picker._context = {"mode": "append_action", "signals_only": false, "selected_resource": null}
	picker._refresh_tree()
	var first: TreeItem = picker._first_definition_item(picker._tree.get_root())
	ok = _check("rows populate and carry their ACEDefinition metadata", first != null and first.get_metadata(0) is ACEDefinition, true) and ok
	# Featured verbs float to the top: in append_action mode the very first row is a featured action.
	ok = _check("a featured verb floats to the top of the list", first != null and picker._is_featured(first.get_metadata(0)), true) and ok

	# The help strip's IN CODE line carries a built-in ACE's template as written.
	if first != null and first.get_metadata(0) is ACEDefinition:
		var def: ACEDefinition = first.get_metadata(0)
		picker._update_info_panel(def)
		if not str(def.metadata.get("codegen_template", "")).is_empty():
			ok = _check("the strip's IN CODE line is the template", picker._help_strip.in_code_value.text,
				str(def.metadata.get("codegen_template", ""))) and ok

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
		ok = _check("selecting a section header names it in the strip", picker._help_strip.heading_label.text, section_name.to_upper()) and ok
		ok = _check("and disables Add", picker._add_button.disabled and picker._selected_definition == null, true) and ok

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
	return SUPPORT.check("picker_layout_test", label, actual, expected)
