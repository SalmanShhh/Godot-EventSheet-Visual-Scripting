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
# The bar's own splitter, so an empty selection can hand its width back to the canvas without the
# handle going with it, and a drag into the right edge can slide the bar off entirely.
var _split: HSplitContainer = null
# What the bar shows: _body is the heading + the form, _edge the narrow strip a tucked bar leaves
# behind with a chevron to bring it back.
var _body: VBoxContainer = null
var _edge: VBoxContainer = null
# True while nothing on the sheet is selected: the bar is its handle and nothing else.
var _empty: bool = true
# The empty bar's sentence is worth saying once per session, in the status bar, rather than for
# ever in a column of its own.
var _said_empty_hint: bool = false
# The ACE this form was built for, so a selection that did not change does not rebuild the fields
# under the user's cursor. Never used to WRITE - the write re-fetches, because the undo funnel
# replaces every resource on commit.
var _shown_resource: Resource = null
# The shared per-hint widget factory (ace_dialog/param_field_factory.gd) - the same builders the Edit
# Parameter dialog uses, so a colour, an enum, a node reference or an input action edits in place
# here exactly as it does there.
var _field_factory: EventSheetParamFieldFactory = EventSheetParamFieldFactory.new()


func init(dock: Control) -> void:
	_dock = dock
	_field_factory.init(dock)


func is_open() -> bool:
	return panel != null and panel.visible and not is_tucked()


## The bar slid off the right edge - off screen, not closed. The chevron on the strip it leaves
## brings it back, and so does View / Properties Bar.
func is_tucked() -> bool:
	return bool(EventSheetRailPanels.read_state().get("properties_tucked", false))


func set_tucked(tucked: bool) -> void:
	var state: Dictionary = EventSheetRailPanels.read_state()
	state["properties_tucked"] = tucked
	EventSheetRailPanels.save_state(state)
	_apply_width()


## The canvas-and-bar splitter, handed over by the UI builder. A drag that leaves the bar narrower
## than a handle has dragged it off the edge - the same gesture the rail's own grabber has.
func attach_split(split: HSplitContainer) -> void:
	_split = split
	_split.dragger_visibility = SplitContainer.DRAGGER_VISIBLE
	_split.add_theme_constant_override("autohide", 0)
	_split.add_theme_constant_override("separation", int(EventSheetPalette.scaled_f(6.0)))
	var bar: StyleBoxFlat = StyleBoxFlat.new()
	bar.bg_color = EventSheetPalette.TEXT_SECONDARY
	bar.bg_color.a = 0.22
	_split.add_theme_stylebox_override("split_bar_background", bar)
	_split.dragged.connect(func(offset: int) -> void:
		var width: float = maxf(0.0, _split.size.x - float(offset))
		if width <= EventSheetPalette.scaled_f(EventSheetRailPanels.EDGE_STRIP_WIDTH):
			set_tucked(true)
			return
		var state: Dictionary = EventSheetRailPanels.read_state()
		state["properties_tucked"] = false
		state["properties_width"] = width / maxf(0.001, EventSheetPalette.ui_scale())
		EventSheetRailPanels.save_state(state)
		_empty = false
		_apply_width())


## The bar's width, from what it has to say. Nothing selected and the bar is its splitter handle,
## so the canvas has the room until there is something to edit; a selection gives it back the width
## it was last dragged to. Tucked, it is the narrow strip with the chevron on it.
func _apply_width() -> void:
	if panel == null:
		return
	var tucked: bool = is_tucked()
	if _body != null:
		_body.visible = not tucked and not _empty
	if _edge != null:
		_edge.visible = tucked
	var width: float = 0.0
	if tucked:
		width = EventSheetPalette.scaled_f(EventSheetRailPanels.EDGE_STRIP_WIDTH)
	elif not _empty:
		width = EventSheetPalette.scaled_f(float(EventSheetRailPanels.read_state().get(
			"properties_width", EventSheetRailPanels.DEFAULT_PROPERTIES_WIDTH)))
	panel.custom_minimum_size = Vector2(width, 0.0)
	if _split != null:
		# Zero puts the split at its default position, which is the bar at its own minimum - so the
		# width above is the whole story, and the handle stays where it is in every state.
		_split.split_offset = 0


## View ▸ Properties Bar. Simple mode starts it hidden, so this is how it comes back - and it is
## also how a bar dragged off the right edge is brought back, since the menu entry and the strip's
## chevron mean the same thing.
func set_open(open: bool) -> void:
	if panel == null:
		return
	panel.visible = open
	if open:
		set_tucked(false)
		refresh()
	_apply_width()


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


## Nothing selected: the bar hands its width back to the canvas and waits as its handle. The
## sentence that used to fill a 280 px column is said once, in the status bar, the first time.
func _show_nothing() -> void:
	_shown_resource = null
	_clear_form()
	_heading.text = "PROPERTIES"
	if not _empty:
		_empty = true
		if not _said_empty_hint and _dock != null and _dock.has_method("_set_status"):
			_said_empty_hint = true
			_dock._set_status("Select a condition, an action, an object or a group to edit it here.", false)
	_apply_width()


func _show_ace(ace: Resource, view: EventSheetViewport) -> void:
	_shown_resource = ace
	_clear_form()
	_open_for_selection()
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
		_form.add_child(_build_field(ace, descriptor as Dictionary, str(params.get(param_id, (descriptor as Dictionary).get("default_value", "")))))
	if definition != null and not definition.description.strip_edges().is_empty():
		_form.add_child(EventSheetPopupUI.hint_label("Description", 90.0))
		_form.add_child(EventSheetPopupUI.hint_label(definition.description, 190.0))


## One parameter's field - the SAME widget the Edit Parameter dialog would give it, built through
## the shared factory. So a colour is a swatch, an enum is a dropdown, a node reference has its
## picker and an input action has the live Input Map list, right here in the bar; typing
## `Color("#ff9b3c")` by hand into a plain text box is over.
##
## Each widget commits on its own "the user changed this" signal (Enter for a text field, the picker
## closing for a colour, the choice for a dropdown), one undo step, exactly the edit the dialog
## would have made. A widget with no such single moment - the physics-layer mask, which commits
## through its own popup - stays a job for the dialog rather than being wired to a signal that means
## something else.
func _build_field(ace: Resource, descriptor: Dictionary, value: String) -> Control:
	var param_id: String = str(descriptor.get("id", ""))
	var built: Dictionary = _field_factory.build(descriptor, value)
	var control: Control = built.get("control") as Control
	var field: Control = built.get("field") as Control
	if control == null:
		control = LineEdit.new()
		field = control
		(control as LineEdit).text = value
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.tooltip_text = "Applies as you set it. One undo step, the same edit as the Edit Parameter dialog."
	var change_signal: String = EventSheetParamFieldFactory.change_signal_of(field)
	if not change_signal.is_empty() and field.has_signal(change_signal):
		# The signal's own arguments are ignored on purpose: the value is read back out of the WIDGET
		# through the factory, so every field kind commits through one conversion instead of each
		# signal's own idea of what it just handed over.
		field.connect(change_signal, func(_a: Variant = null, _b: Variant = null) -> void:
			_apply(ace, param_id, _field_factory.value_of(field)))
	return control


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
	_open_for_selection()
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
	_open_for_selection()
	_heading.text = heading_for(object_label, "object")
	var entry: Dictionary = EventSheetObjectProperties.find_entry(_dock._current_sheet, object_label)
	for row: Variant in EventSheetObjectProperties.property_rows(entry, "", ""):
		if not (row is Dictionary):
			continue
		_form.add_child(EventSheetPopupUI.hint_label(str((row as Dictionary).get("label", "")), 90.0))
		_form.add_child(EventSheetPopupUI.hint_label(str((row as Dictionary).get("value", "")), 190.0))
	# The same instance-variable table Object properties carries, in the bar, whenever the
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


## The first selection opens the bar at the width it was left at - the way the Godot Inspector
## fills when a node is picked.
func _open_for_selection() -> void:
	if not _empty:
		return
	_empty = false
	_apply_width()


func _clear_form() -> void:
	for child: Node in Array(_form.get_children()):
		_form.remove_child(child)
		child.queue_free()


## Builds the bar and returns it, for the UI builder to put beside the canvas. Hidden in Simple
## mode: a beginner's sheet is the sheet.
func build() -> VBoxContainer:
	panel = VBoxContainer.new()
	panel.name = "EventSheetPropertiesBar"
	_body = VBoxContainer.new()
	_body.name = "EventSheetPropertiesBarBody"
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(_body)
	_heading = EventSheetPopupUI.small_caps_label("PROPERTIES")
	_body.add_child(_heading)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_form = GridContainer.new()
	_form.columns = 2
	_form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_form)
	_body.add_child(scroll)
	# The strip a bar dragged off the right edge leaves behind: a chevron that brings it back.
	_edge = VBoxContainer.new()
	_edge.name = "EventSheetPropertiesBarEdge"
	_edge.visible = false
	var restore: Button = Button.new()
	restore.flat = true
	restore.text = "‹"
	restore.focus_mode = Control.FOCUS_NONE
	restore.tooltip_text = "Bring the Properties bar back at the width it had."
	restore.pressed.connect(func() -> void: set_tucked(false))
	_edge.add_child(restore)
	panel.add_child(_edge)
	panel.visible = not _dock.is_simple_mode()
	_show_nothing()
	return panel
