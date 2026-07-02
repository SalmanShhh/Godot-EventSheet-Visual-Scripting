@tool
extends RefCounted
class_name EventSheetVariableGrouping
# Variable "folders": drag one variable onto another and they fold into a shared Inspector group —
# the Discord-folder gesture — then a small popup opens already select-all'd so typing names the
# fresh group immediately (Enter confirms; renaming later is a double-click on the group chip, and
# clearing the name in that popup ungroups every member).
#
# The group is the SHIPPED @export_group attribute (descriptor.attributes.group for dict globals,
# LocalVariable.attributes.group for tree variables), so folders round-trip through the .gd exactly
# like groups set from the Variable dialog — this class adds gestures, not a new data model. All
# writes go through the dock's undo funnel; the funnel's commit REPLACES sheet resources, so member
# lookups always walk the LIVE sheet rather than holding references.

var _dock: Control = null
var _rename_popup: PopupPanel = null
var _rename_field: LineEdit = null
var _rename_from: String = ""

func init(dock: Control) -> void:
	_dock = dock

# ── The pure group model (static → headless-testable) ────────────────────────────────────────────

## The group a variable row belongs to ("" when ungrouped). `scope`/`name` come from the row's span
## metadata; tree variables resolve through their LocalVariable resource.
static func group_of(sheet: EventSheetResource, scope: String, var_name: String, resource: Resource) -> String:
	if scope == "global":
		var descriptor: Variant = sheet.variables.get(var_name, {})
		if descriptor is Dictionary and (descriptor as Dictionary).get("attributes") is Dictionary:
			return str(((descriptor as Dictionary)["attributes"] as Dictionary).get("group", "")).strip_edges()
		return ""
	if resource is LocalVariable:
		var attributes: Variant = (resource as LocalVariable).attributes
		return str((attributes as Dictionary).get("group", "")).strip_edges() if attributes is Dictionary else ""
	return ""

## Writes a variable's group ("" clears it). Returns true when something changed.
static func set_group(sheet: EventSheetResource, scope: String, var_name: String, resource: Resource, group: String) -> bool:
	var clean: String = group.strip_edges()
	if scope == "global":
		var descriptor: Variant = sheet.variables.get(var_name)
		if not (descriptor is Dictionary):
			return false
		var attributes: Dictionary = (descriptor as Dictionary).get("attributes") if (descriptor as Dictionary).get("attributes") is Dictionary else {}
		if str(attributes.get("group", "")).strip_edges() == clean:
			return false
		if clean.is_empty():
			attributes.erase("group")
		else:
			attributes["group"] = clean
		(descriptor as Dictionary)["attributes"] = attributes
		return true
	if resource is LocalVariable:
		var variable: LocalVariable = resource as LocalVariable
		var tree_attributes: Dictionary = variable.attributes if variable.attributes is Dictionary else {}
		if str(tree_attributes.get("group", "")).strip_edges() == clean:
			return false
		if clean.is_empty():
			tree_attributes.erase("group")
		else:
			tree_attributes["group"] = clean
		variable.attributes = tree_attributes
		return true
	return false

## Renames a group across EVERY member — dict globals and tree variables (recursing groups and
## sub-events) — so the folder renames as one thing. An empty new name dissolves the folder
## (every member ungroups). Returns how many variables changed.
static func rename_group(sheet: EventSheetResource, old_group: String, new_group: String) -> int:
	var from: String = old_group.strip_edges()
	if from.is_empty():
		return 0
	var changed: int = 0
	for var_name: Variant in sheet.variables:
		if group_of(sheet, "global", str(var_name), null) == from:
			if set_group(sheet, "global", str(var_name), null, new_group):
				changed += 1
	changed += _rename_tree_groups(sheet.events, from, new_group)
	return changed

static func _rename_tree_groups(rows: Array, from: String, to: String) -> int:
	var changed: int = 0
	for row: Variant in rows:
		if row is LocalVariable:
			if group_of(null, "tree", "", row as LocalVariable) == from \
					and set_group(null, "tree", "", row as LocalVariable, to):
				changed += 1
		elif row is EventRow:
			changed += _rename_tree_groups((row as EventRow).sub_events, from, to)
		elif row is EventGroup:
			var group: EventGroup = row as EventGroup
			changed += _rename_tree_groups(group.events if not group.events.is_empty() else group.rows, from, to)
	return changed

## The identity a variable row's spans carry: {scope, name, resource} — resource only for tree vars
## (a global row's source_resource is the sheet itself).
static func row_identity(row_data: EventRowData) -> Dictionary:
	if row_data == null or row_data.spans.is_empty() or not (row_data.spans[0].metadata is Dictionary):
		return {}
	var metadata: Dictionary = row_data.spans[0].metadata
	if str(metadata.get("kind", "")) != "variable":
		return {}
	return {
		"scope": str(metadata.get("variable_scope", "")),
		"name": str(metadata.get("variable_name", "")),
		"resource": row_data.source_resource if row_data.source_resource is LocalVariable else null,
	}

# ── The gestures ──────────────────────────────────────────────────────────────────────────────────

## Drop-onto-variable: fold both into the target's folder (or a fresh "New Group" when the target
## has none), then open the naming popup select-all'd — drag, type the name, Enter.
func on_group_requested(source_row: EventRowData, target_row: EventRowData) -> void:
	var source: Dictionary = row_identity(source_row)
	var target: Dictionary = row_identity(target_row)
	if source.is_empty() or target.is_empty():
		return
	var sheet: EventSheetResource = _dock._current_sheet
	var group: String = group_of(sheet, str(target.get("scope")), str(target.get("name")), target.get("resource"))
	var fresh: bool = group.is_empty()
	if fresh:
		group = "New Group"
	var changed: bool = _dock._perform_undoable_sheet_edit("Group Variables", func() -> bool:
		var any: bool = false
		# The funnel snapshot duplicates tree resources on commit, but THIS lambda runs against the
		# live objects the rows referenced — safe; later gestures re-resolve via the live sheet.
		if set_group(_dock._current_sheet, str(target.get("scope")), str(target.get("name")), target.get("resource"), group):
			any = true
		if set_group(_dock._current_sheet, str(source.get("scope")), str(source.get("name")), source.get("resource"), group):
			any = true
		return any)
	if not changed:
		return
	_dock._refresh_after_edit()
	_dock._mark_dirty("Grouped %s with %s." % [str(source.get("name")), str(target.get("name"))])
	if fresh:
		open_rename_popup(group)  # name the new folder right away, Discord-style

## Double-clicking a group chip renames the folder (empty name ungroups all members).
func on_rename_requested(group_name: String) -> void:
	open_rename_popup(group_name)

func open_rename_popup(group_name: String) -> void:
	_rename_from = group_name
	if _rename_popup == null:
		_rename_popup = PopupPanel.new()
		var box: VBoxContainer = VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		_rename_field = LineEdit.new()
		_rename_field.custom_minimum_size = Vector2(220.0, 0.0)
		_rename_field.text_submitted.connect(func(_t: String) -> void: commit_rename())
		box.add_child(_rename_field)
		var hint: Label = Label.new()
		hint.text = "⏎ names the group · empty ungroups"
		hint.add_theme_font_size_override("font_size", 10)
		hint.modulate = Color(1.0, 1.0, 1.0, 0.65)
		box.add_child(hint)
		_rename_popup.add_child(box)
		_dock.add_child(_rename_popup)
	_rename_field.text = group_name
	if not _rename_popup.is_inside_tree():
		return  # headless tests: state is set, there is no window to pop
	_rename_popup.popup(Rect2i(Vector2i(DisplayServer.mouse_get_position()), Vector2i(240, 40)))
	_rename_field.grab_focus()
	_rename_field.select_all()

func commit_rename() -> void:
	var new_name: String = _rename_field.text.strip_edges()
	var old_name: String = _rename_from
	if _rename_popup != null:
		_rename_popup.hide()
	if old_name.is_empty() or new_name == old_name:
		return
	var count := {"changed": 0}
	var changed: bool = _dock._perform_undoable_sheet_edit("Rename Variable Group", func() -> bool:
		count["changed"] = rename_group(_dock._current_sheet, old_name, new_name)
		return int(count["changed"]) > 0)
	if changed:
		_dock._refresh_after_edit()
		var note: String = "Ungrouped %d variable%s." if new_name.is_empty() else "Renamed the group for %d variable%s."
		_dock._mark_dirty(note % [int(count["changed"]), "" if int(count["changed"]) == 1 else "s"])
