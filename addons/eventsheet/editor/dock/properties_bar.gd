@tool
class_name EventSheetPropertiesBar
extends RefCounted
# The PROPERTIES bar: whatever is selected on the sheet, said as fields you edit where you are
# reading.
#
#   PROPERTIES · Flash · action
#   Object      Player
#   Duration    0.2
#   Ease        Sine out
#
# A selected condition or action shows its parameters; typing in a field and pressing Enter applies
# it in ONE undo step through the same edit path as the Edit Parameter dialog, so an opened .gd
# stays byte-exact for every line the edit does not touch. A selected object shows the Object
# properties. A selected group shows its name and whether it is enabled.
#
# It sits to the right of the canvas, splitter-resizable like the Inspector, and is hidden by
# default in Simple mode - a beginner's sheet is the sheet. The Edit Parameter dialog stays for
# anyone who prefers it; nothing here replaces it.

var _dock: Control = null
var panel: VBoxContainer = null
var _heading: Label = null
var _form: GridContainer = null
# The ACE this form was built for, so a selection that did not change does not rebuild the fields
# under the user's cursor. Never used to WRITE - the write re-fetches, because the undo funnel
# replaces every resource on commit.
var _shown_resource: Resource = null


func init(dock: Control) -> void:
	_dock = dock


func is_open() -> bool:
	return panel != null and panel.visible


## View ▸ Properties Bar. Simple mode starts it hidden, so this is how it comes back.
func set_open(open: bool) -> void:
	if panel == null:
		return
	panel.visible = open
	if open:
		refresh()


## Rebuilds the form for whatever is selected now. Cheap and idempotent - called from the
## selection change and after every edit.
func refresh() -> void:
	if panel == null or not panel.visible:
		return
	var view: EventSheetViewport = _dock._active_view()
	if view == null:
		return
	var ace: Resource = view.get_selected_ace_resource()
	if ace != null:
		_show_ace(ace, view)
		return
	var selected: Resource = view.get_selected_context().get("source_resource", null)
	if selected is EventGroup:
		_show_group(selected as EventGroup)
		return
	var object_label: String = str(view.get_selected_context().get("span_metadata", {}).get("object_label", "")).strip_edges()
	if not object_label.is_empty():
		_show_object(object_label)
		return
	_show_nothing()


## The label the heading shows for a selected ACE: "PROPERTIES · Flash · action". Static so the
## wording is pinnable without a dock.
static func heading_for(display_name: String, kind: String) -> String:
	if display_name.strip_edges().is_empty():
		return "PROPERTIES"
	return "PROPERTIES · %s · %s" % [display_name.strip_edges(), kind]


func _show_nothing() -> void:
	_shown_resource = null
	_clear_form()
	_heading.text = "PROPERTIES"
	_form.add_child(EventSheetPopupUI.hint_label("Select a condition, an action, an object or a group.", 240.0))
	_form.add_child(Control.new())


func _show_ace(ace: Resource, view: EventSheetViewport) -> void:
	_shown_resource = ace
	_clear_form()
	var kind: String = "condition" if ace is ACECondition else "action"
	var definition: ACEDefinition = _dock._find_definition(str(ace.get("provider_id")), str(ace.get("ace_id")))
	var display_name: String = definition.display_name if definition != null else str(ace.get("ace_id"))
	_heading.text = heading_for(display_name, kind)
	var params: Dictionary = ace.get("params")
	if params.is_empty() and ace.get("parameters") is Dictionary:
		params = ace.get("parameters")
	var descriptors: Array = definition.parameters if definition != null else []
	if descriptors.is_empty():
		for key: Variant in params.keys():
			descriptors.append({"id": str(key), "display_name": str(key).capitalize()})
	for descriptor: Variant in descriptors:
		if not (descriptor is Dictionary):
			continue
		var param_id: String = str((descriptor as Dictionary).get("id", ""))
		if param_id.is_empty():
			continue
		var label: Label = Label.new()
		label.text = str((descriptor as Dictionary).get("display_name", param_id))
		label.tooltip_text = str((descriptor as Dictionary).get("description", ""))
		_form.add_child(label)
		_form.add_child(_build_field(ace, param_id, str(params.get(param_id, (descriptor as Dictionary).get("default_value", "")))))
	if definition != null and not definition.description.strip_edges().is_empty():
		_form.add_child(EventSheetPopupUI.hint_label("Description", 90.0))
		_form.add_child(EventSheetPopupUI.hint_label(definition.description, 190.0))


## One parameter's field: Enter applies it, nothing else does, and an unchanged value is not an
## edit. Anything the field cannot express stays a job for the Edit Parameter dialog.
func _build_field(ace: Resource, param_id: String, value: String) -> Control:
	var field: LineEdit = LineEdit.new()
	field.text = value
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.tooltip_text = "Enter applies. One undo step, the same edit as the Edit Parameter dialog."
	field.text_submitted.connect(func(text: String) -> void: _apply(ace, param_id, text))
	return field


func _apply(ace: Resource, param_id: String, text: String) -> void:
	# The funnel replaces every resource on commit, so the target is re-fetched from the live
	# selection rather than held from when the field was built.
	var view: EventSheetViewport = _dock._active_view()
	var live: Resource = view.get_selected_ace_resource() if view != null else null
	var target: Resource = live if live != null else ace
	if _dock._inline_params.apply_param_value(target, param_id, text):
		_dock._refresh_after_edit()
		_dock._mark_dirty("Parameter updated.")
	refresh()


func _show_group(group: EventGroup) -> void:
	_shown_resource = group
	_clear_form()
	_heading.text = heading_for(group.group_name, "group")
	var name_label: Label = Label.new()
	name_label.text = "Name"
	_form.add_child(name_label)
	var name_edit: LineEdit = LineEdit.new()
	name_edit.text = group.group_name
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.text_submitted.connect(func(text: String) -> void: _apply_group_name(text))
	_form.add_child(name_edit)
	var enabled_label: Label = Label.new()
	enabled_label.text = "Enabled"
	_form.add_child(enabled_label)
	var enabled_check: CheckBox = CheckBox.new()
	enabled_check.button_pressed = group.enabled
	enabled_check.toggled.connect(func(on: bool) -> void: _apply_group_enabled(on))
	_form.add_child(enabled_check)


func _apply_group_name(text: String) -> void:
	var view: EventSheetViewport = _dock._active_view()
	var group: EventGroup = view.get_selected_context().get("source_resource", null) as EventGroup if view != null else null
	if group == null or text.strip_edges().is_empty() or text == group.group_name:
		return
	if _dock._perform_undoable_sheet_edit("Rename Group", func() -> bool:
			group.group_name = text
			return true):
		_dock._refresh_after_edit()
		_dock._mark_dirty("Group renamed.")
	refresh()


func _apply_group_enabled(enabled: bool) -> void:
	var view: EventSheetViewport = _dock._active_view()
	var group: EventGroup = view.get_selected_context().get("source_resource", null) as EventGroup if view != null else null
	if group == null or group.enabled == enabled:
		return
	if _dock._perform_undoable_sheet_edit("Toggle Group", func() -> bool:
			group.enabled = enabled
			return true):
		_dock._refresh_after_edit()
		_dock._mark_dirty("Group %s." % ("enabled" if enabled else "disabled"))
	refresh()


## A selected object reads what the Object properties popup reads - the same facts, in the bar.
func _show_object(object_label: String) -> void:
	_shown_resource = null
	_clear_form()
	_heading.text = heading_for(object_label, "object")
	var entry: Dictionary = EventSheetObjectProperties.find_entry(_dock._current_sheet, object_label)
	for row: Variant in EventSheetObjectProperties.property_rows(entry, "", ""):
		if not (row is Dictionary):
			continue
		_form.add_child(EventSheetPopupUI.hint_label(str((row as Dictionary).get("label", "")), 90.0))
		_form.add_child(EventSheetPopupUI.hint_label(str((row as Dictionary).get("value", "")), 190.0))
	# R39 - the same instance-variable table Object properties carries, in the bar, whenever the
	# selected object is the one this file IS. Selecting an object and editing its variables
	# without opening a popup is the whole point of the bar.
	if EventSheetObjectProperties.owns_sheet_variables(entry):
		var table: Control = _dock._instance_variables.build_for(_dock._current_sheet)
		if table != null:
			_form.add_child(EventSheetPopupUI.hint_label(
				EventSheetL10n.translate("Instance variables"), 90.0))
			_form.add_child(table)
	var open_button: Button = Button.new()
	open_button.text = EventSheetL10n.translate("Object properties…")
	open_button.pressed.connect(func() -> void: _dock.open_object_properties(object_label))
	_form.add_child(Control.new())
	_form.add_child(open_button)


func _clear_form() -> void:
	for child: Node in Array(_form.get_children()):
		_form.remove_child(child)
		child.queue_free()


## Builds the bar and returns it, for the UI builder to put beside the canvas. Hidden in Simple
## mode: a beginner's sheet is the sheet.
func build() -> VBoxContainer:
	panel = VBoxContainer.new()
	panel.name = "EventSheetPropertiesBar"
	panel.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(270.0), 0.0)
	_heading = EventSheetPopupUI.small_caps_label("PROPERTIES")
	panel.add_child(_heading)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_form = GridContainer.new()
	_form.columns = 2
	_form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_form)
	panel.add_child(scroll)
	panel.visible = not _dock.is_simple_mode()
	_show_nothing()
	return panel
