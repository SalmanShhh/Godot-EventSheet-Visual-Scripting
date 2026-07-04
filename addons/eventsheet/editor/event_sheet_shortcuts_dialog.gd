@tool
class_name EventSheetShortcutsDialog
extends RefCounted
# Tools ▸ Keyboard Shortcuts - an editable remapper for the authoring keys (click a binding, then press
# the new combo). Built on EventSheetShortcuts (per-user persistence); the structural keys from the dock's
# FIXED_KEYS table are shown read-only. Clashes are flagged inline but allowed (you resolve them by
# rebinding one). Extracted from event_sheet_dock.gd; the only dock touch-points are add_child (to host
# the dialog) and FIXED_KEYS, reached through the _dock back-reference. The dock keeps a one-line
# _open_shortcuts_help delegate for the Tools menu.

var _dock: Control = null
var _shortcuts_dialog: AcceptDialog = null
var _shortcuts_list: VBoxContainer = null
var _shortcuts_capturing_action: String = ""


func init(dock: Control) -> void:
	_dock = dock


## Click a shortcut, then press the new key combination. Built on EventSheetShortcuts (per-user
## persistence); the structural keys are shown read-only. Clashes are flagged inline but allowed.
func open() -> void:
	if _shortcuts_dialog == null:
		_shortcuts_dialog = AcceptDialog.new()
		_shortcuts_dialog.title = "Keyboard Shortcuts"
		_shortcuts_dialog.ok_button_text = "Done"
		_shortcuts_dialog.min_size = Vector2i(540, 600)
		var outer: VBoxContainer = EventSheetPopupUI.form_box()
		var intro: Label = Label.new()
		intro.text = "Click a shortcut, then press the new key combination (Esc cancels). Custom keys are saved per-user, not in the project."
		intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# Width-bound so the autowrap label can't report a runaway min height and balloon the dialog.
		intro.custom_minimum_size = Vector2(500.0, 0.0)
		outer.add_child(intro)
		var scroll: ScrollContainer = ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.custom_minimum_size = Vector2(0.0, 460.0)
		_shortcuts_list = VBoxContainer.new()
		_shortcuts_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_shortcuts_list.add_theme_constant_override("separation", 4)
		scroll.add_child(_shortcuts_list)
		outer.add_child(scroll)
		var reset_all_button: Button = Button.new()
		reset_all_button.text = "Reset all to defaults"
		reset_all_button.pressed.connect(func() -> void:
			EventSheetShortcuts.reset_all()
			_refresh_shortcuts_editor())
		outer.add_child(reset_all_button)
		_shortcuts_dialog.add_child(EventSheetPopupUI.margined(outer))
		_dock.add_child(_shortcuts_dialog)
	_refresh_shortcuts_editor()
	_shortcuts_dialog.popup_centered()


## Rebuilds the editor rows from the live bindings - called on open and after every change, so the
## displayed keys and conflict flags always reflect EventSheetShortcuts.
func _refresh_shortcuts_editor() -> void:
	if _shortcuts_list == null:
		return
	_shortcuts_capturing_action = ""
	for child: Node in _shortcuts_list.get_children():
		child.queue_free()
	for action: String in EventSheetShortcuts.ORDER:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var label: Label = Label.new()
		label.text = EventSheetShortcuts.label_for(action)
		label.custom_minimum_size = Vector2(230.0, 0.0)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var binding: String = EventSheetShortcuts.binding_for(action)
		var capture: Button = Button.new()
		capture.text = binding if not binding.is_empty() else "(none)"
		capture.custom_minimum_size = Vector2(150.0, 0.0)
		capture.tooltip_text = "Click, then press the new key combination."
		var conflict: String = EventSheetShortcuts.conflicting_action(action, binding)
		if not conflict.is_empty():
			capture.modulate = Color(1.0, 0.7, 0.4)
			capture.tooltip_text = "Also bound to '%s' - one of them won't fire. Rebind one." % EventSheetShortcuts.label_for(conflict)
		capture.pressed.connect(_begin_shortcut_capture.bind(action, capture))
		capture.gui_input.connect(_shortcut_capture_gui_input.bind(action, capture))
		row.add_child(capture)
		var reset_button: Button = Button.new()
		reset_button.text = "Reset"
		reset_button.tooltip_text = "Reset to default (%s)" % str(EventSheetShortcuts.DEFAULTS.get(action, ""))
		reset_button.pressed.connect(func() -> void:
			EventSheetShortcuts.reset(action)
			_refresh_shortcuts_editor())
		row.add_child(reset_button)
		_shortcuts_list.add_child(row)
	_shortcuts_list.add_child(HSeparator.new())
	var fixed_header: Label = Label.new()
	fixed_header.text = "Fixed keys (not rebindable)"
	fixed_header.modulate = Color(1.0, 1.0, 1.0, 0.6)
	_shortcuts_list.add_child(fixed_header)
	for pair: Array in _dock.FIXED_KEYS:
		var fixed_row: HBoxContainer = HBoxContainer.new()
		fixed_row.add_theme_constant_override("separation", 8)
		var fixed_label: Label = Label.new()
		fixed_label.text = str(pair[1])
		fixed_label.custom_minimum_size = Vector2(230.0, 0.0)
		fixed_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fixed_row.add_child(fixed_label)
		var fixed_keys_label: Label = Label.new()
		fixed_keys_label.text = str(pair[0])
		fixed_keys_label.modulate = Color(1.0, 1.0, 1.0, 0.6)
		fixed_row.add_child(fixed_keys_label)
		_shortcuts_list.add_child(fixed_row)


## Click-to-rebind: the binding button enters "listening" mode; the next real key press is captured
## by _shortcut_capture_gui_input (a lone modifier keeps listening; Esc cancels).
func _begin_shortcut_capture(action: String, capture: Button) -> void:
	if not _shortcuts_capturing_action.is_empty() and _shortcuts_capturing_action != action:
		_refresh_shortcuts_editor()
	_shortcuts_capturing_action = action
	capture.text = "Press a key…  (Esc cancels)"
	capture.modulate = Color(0.6, 0.9, 1.0)
	capture.grab_focus()


func _shortcut_capture_gui_input(event: InputEvent, action: String, capture: Button) -> void:
	if _shortcuts_capturing_action != action or not (event is InputEventKey):
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	capture.accept_event()
	if key_event.keycode == KEY_ESCAPE:
		_shortcuts_capturing_action = ""
		_refresh_shortcuts_editor()
		return
	var binding: String = EventSheetShortcuts.format_event(key_event)
	if binding.is_empty():
		return
	EventSheetShortcuts.set_binding(action, binding)
	_shortcuts_capturing_action = ""
	_refresh_shortcuts_editor()
