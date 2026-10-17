@tool
class_name EventSheetShortcutsDialog
extends RefCounted
# Tools ▸ Keyboard Shortcuts - an editable remapper for the authoring keys (click a binding, then press
# the new combo). Built on EventSheetShortcuts (per-user persistence); the structural keys from the dock's
# FIXED_KEYS table are shown read-only. A clash - with another changeable key or with a fixed one - is
# said in a note under the row, but allowed (you resolve it by rebinding one). The rows are built once
# and only repainted after a change, so a button that is listening for a key is never freed under it.
# The dock keeps a one-line _open_shortcuts_help delegate for the Tools menu.

var _dock: Control = null
var _shortcuts_dialog: AcceptDialog = null
## action -> {"button": Button, "note": StateNote}, one entry per changeable key.
var _rows: Dictionary = {}
var _shortcuts_capturing_action: String = ""
var _preset_picker: OptionButton = null
var _strip: EventSheetPopupUI.HelpStrip = null


func init(dock: Control) -> void:
	_dock = dock


## Click a shortcut, then press the new key combination. Built on EventSheetShortcuts (per-user
## persistence); the structural keys are shown read-only. Clashes are flagged inline but allowed.
func open() -> void:
	if _shortcuts_dialog == null:
		_build()
		_dock.add_child(_shortcuts_dialog)
	_refresh_shortcuts_editor()
	_shortcuts_dialog.popup_centered()


func _build() -> void:
	_shortcuts_dialog = AcceptDialog.new()
	_shortcuts_dialog.title = "Change the keyboard shortcuts"
	_shortcuts_dialog.ok_button_text = "Done"
	EventSheetPopupUI.main_button(_shortcuts_dialog.get_ok_button())
	_shortcuts_dialog.min_size = Vector2i(EventSheetPalette.scaled(540), EventSheetPalette.scaled(640))
	var reset_all_button: Button = _shortcuts_dialog.add_button(EventSheetL10n.translate("Reset all to defaults"), false)
	reset_all_button.pressed.connect(func() -> void:
		EventSheetShortcuts.reset_all()
		_refresh_shortcuts_editor())
	var outer: VBoxContainer = EventSheetPopupUI.form_box()
	outer.add_child(EventSheetPopupUI.hint_label(
		EventSheetL10n.translate("Click a shortcut, then press the new key combination (Esc cancels). Custom keys are saved per-user, not in the project."),
		EventSheetPalette.scaled_f(500.0)))
	# Preset ▾. A whole keyboard in one pick, for an author whose fingers already know
	# another event-sheet editor's keys. The preset only rebinds what DIFFERS, and every key it
	# touches stays rebindable underneath.
	_preset_picker = OptionButton.new()
	_preset_picker.name = "EventSheetShortcutPreset"
	_preset_picker.tooltip_text = EventSheetL10n.translate("Pick a whole set of keys at once. Only the keys that differ are rebound - everything stays rebindable afterwards, and Reset all to defaults comes back here.")
	for preset_index: int in EventSheetShortcuts.PRESET_ORDER.size():
		_preset_picker.add_item(
			EventSheetShortcuts.preset_label_for(str(EventSheetShortcuts.PRESET_ORDER[preset_index])),
			preset_index)
	_preset_picker.item_selected.connect(func(index: int) -> void:
		if index < 0 or index >= EventSheetShortcuts.PRESET_ORDER.size():
			return
		EventSheetShortcuts.apply_preset(str(EventSheetShortcuts.PRESET_ORDER[index]))
		_refresh_shortcuts_editor())
	outer.add_child(EventSheetPopupUI.titled_card("Preset", EventSheetPopupUI.form_row("Preset", _preset_picker)))
	_strip = EventSheetPopupUI.help_strip()
	_strip.follow(_preset_picker, EventSheetL10n.translate("Preset"), _preset_picker.tooltip_text)
	var stored: Label = _strip.add_line(EventSheetL10n.translate("STORED"))
	_strip.set_line(stored, EventSheetL10n.translate("per user, on this machine - not in the project"))
	var changeable: VBoxContainer = VBoxContainer.new()
	for action: String in EventSheetShortcuts.ORDER:
		changeable.add_child(_key_row(action))
	var fixed: GridContainer = GridContainer.new()
	fixed.columns = 2
	fixed.add_theme_constant_override("h_separation", int(EventSheetPalette.scaled_f(12.0)))
	for pair: Array in _dock.FIXED_KEYS:
		var what: Label = Label.new()
		what.text = EventSheetL10n.translate(str(pair[1]))
		what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fixed.add_child(what)
		var keys: Label = Label.new()
		keys.text = str(pair[0])
		keys.add_theme_color_override("font_color", EventSheetPopupUI.muted_text_color())
		fixed.add_child(keys)
	var lists: VBoxContainer = EventSheetPopupUI.form_box()
	lists.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lists.add_child(EventSheetPopupUI.titled_card("Keys you can change", changeable))
	lists.add_child(EventSheetPopupUI.titled_card("Fixed keys (not rebindable)", fixed))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0.0, EventSheetPalette.scaled_f(380.0))
	scroll.add_child(lists)
	outer.add_child(scroll)
	outer.add_child(_strip)
	_shortcuts_dialog.add_child(EventSheetPopupUI.margined(outer))


## One changeable key: its name, the binding button, a Reset, and the clash note under them.
func _key_row(action: String) -> VBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", EventSheetPopupUI.ROW_SEPARATION)
	var label: Label = Label.new()
	label.text = EventSheetL10n.translate(EventSheetShortcuts.label_for(action))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var capture: Button = Button.new()
	capture.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(150.0), 0.0)
	capture.pressed.connect(_begin_shortcut_capture.bind(action))
	capture.gui_input.connect(_shortcut_capture_gui_input.bind(action))
	_strip.follow(capture, label.text, "", func() -> String:
		return EventSheetL10n.translate("Press the new key combination now. Esc cancels.") \
			if _shortcuts_capturing_action == action \
			else EventSheetL10n.translate("Click, then press the new key combination."))
	row.add_child(capture)
	var reset_button: Button = Button.new()
	reset_button.text = "Reset"
	reset_button.tooltip_text = EventSheetL10n.translate("Reset to default (%s)") % str(EventSheetShortcuts.DEFAULTS.get(action, ""))
	reset_button.pressed.connect(func() -> void:
		EventSheetShortcuts.reset(action)
		_refresh_shortcuts_editor())
	_strip.follow(reset_button, EventSheetL10n.translate("Reset"), reset_button.tooltip_text)
	row.add_child(reset_button)
	var note: EventSheetPopupUI.StateNote = EventSheetPopupUI.StateNote.new(EventSheetPalette.scaled_f(460.0))
	var box: VBoxContainer = VBoxContainer.new()
	box.add_child(row)
	box.add_child(note)
	_rows[action] = {"button": capture, "note": note}
	return box


## Repaints every row from the live bindings - called on open and after every change, so the
## displayed keys and clash notes always reflect EventSheetShortcuts.
func _refresh_shortcuts_editor() -> void:
	_shortcuts_capturing_action = ""
	# The picker follows the LIVE bindings, so rebinding one key by hand honestly drops the dialog
	# back to "Godot EventSheets" rather than claiming a preset that is no longer in force.
	if _preset_picker != null:
		var active: int = EventSheetShortcuts.PRESET_ORDER.find(EventSheetShortcuts.active_preset())
		_preset_picker.select(active if active >= 0 else 0)
	for action: String in _rows:
		_paint_capture(action)


## Shows one action's binding on its button, and under it the clash it makes with another
## changeable key or with one of the fixed keys.
func _paint_capture(action: String) -> void:
	var capture: Button = _rows[action]["button"]
	var binding: String = EventSheetShortcuts.binding_for(action)
	capture.text = binding if not binding.is_empty() else "(none)"
	var conflict: String = EventSheetShortcuts.conflicting_action(action, binding)
	var fixed_conflict: String = EventSheetShortcuts.conflicting_fixed_key(binding)
	var clash: String = ""
	if not conflict.is_empty():
		clash = EventSheetL10n.translate("%s is also '%s' - one of them won't fire. Rebind one.") \
			% [binding, EventSheetL10n.translate(EventSheetShortcuts.label_for(conflict))]
	elif not fixed_conflict.is_empty():
		clash = EventSheetL10n.translate("%s is also %s, a fixed key - one of them won't fire. Rebind this one.") \
			% [binding, EventSheetL10n.translate(fixed_conflict)]
	(_rows[action]["note"] as EventSheetPopupUI.StateNote).say(clash, EventSheetPopupUI.TONE_WARNING)
	if clash.is_empty():
		capture.remove_theme_color_override("font_color")
	else:
		capture.add_theme_color_override("font_color", EventSheetPopupUI.tone_color(EventSheetPopupUI.TONE_WARNING))


## Click-to-rebind: the binding button enters "listening" mode; the next real key press is captured
## by _shortcut_capture_gui_input (a lone modifier keeps listening; Esc cancels).
func _begin_shortcut_capture(action: String) -> void:
	# Another binding was listening: put THAT button back to its key.
	if not _shortcuts_capturing_action.is_empty() and _shortcuts_capturing_action != action:
		_paint_capture(_shortcuts_capturing_action)
	_shortcuts_capturing_action = action
	var capture: Button = _rows[action]["button"]
	capture.text = "Press a key…"
	capture.grab_focus()
	_strip.show_note(EventSheetL10n.translate(EventSheetShortcuts.label_for(action)),
		EventSheetL10n.translate("Press the new key combination now. Esc cancels."))


func _shortcut_capture_gui_input(event: InputEvent, action: String) -> void:
	if _shortcuts_capturing_action != action or not (event is InputEventKey):
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	(_rows[action]["button"] as Button).accept_event()
	if key_event.keycode == KEY_ESCAPE:
		_refresh_shortcuts_editor()
		return
	var binding: String = EventSheetShortcuts.format_event(key_event)
	if binding.is_empty():
		return
	EventSheetShortcuts.set_binding(action, binding)
	_refresh_shortcuts_editor()
