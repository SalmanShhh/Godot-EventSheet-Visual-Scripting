@tool
class_name EventSheetConnectSignalDialog
extends RefCounted

# The "Connect Signal to Event Sheet" window (the Node-dock flow): pick one of the selected node's
# signals - script signals and its native class's alike, searchable - and an On <signal> trigger
# event lands in the node's sheet. Meeting Godot users where they already work: the same gesture as
# connecting a signal to a script method, except the handler is an event row instead of a stub.
#
# On the window kit: a band showing the event that will land, the signal list with a note on the
# ones the sheet already handles, the help strip with the handler line it writes, Connect / Cancel.

var _dialog: ConfirmationDialog = null
var _band: EventSheetPopupUI.RowBand = null
var _search: LineEdit = null
var _list: Tree = null
var _note: EventSheetPopupUI.StateNote = null
var _strip: EventSheetPopupUI.HelpStrip = null
var _signals: Array[Dictionary] = []
var _filtered: Array[Dictionary] = []
var _handled: PackedStringArray = PackedStringArray()
var _node: Node = null
var _sheet_path: String = ""
var _parent: Node = null


## Opens for one scene node whose script pairs with (or is) a sheet. `sheet_path` is that sheet;
## `parent` hosts the window.
func open(node: Node, sheet_path: String, parent: Node) -> void:
	_node = node
	_sheet_path = sheet_path
	_parent = parent
	_signals = EventSheets.signals_of(node)
	_handled = handled_signals(FileAccess.get_file_as_string(sheet_path) if FileAccess.file_exists(sheet_path) else "")
	_build()
	_apply_filter("")
	if _parent.is_inside_tree():
		_dialog.popup_centered(Vector2i(int(EventSheetPalette.scaled_f(480.0)), int(EventSheetPalette.scaled_f(500.0))))
		_search.grab_focus()


## The signals a sheet's file already answers: every `func _on_<signal>(` it holds, which is the
## handler an On <signal> event compiles to.
static func handled_signals(source: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var handler: RegEx = RegEx.create_from_string("(?m)^func _on_([A-Za-z_][A-Za-z0-9_]*)\\(")
	for hit: RegExMatch in handler.search_all(source):
		found.append(hit.get_string(1))
	return found


## The event as the sheet will read it: the trigger's own name for the signals the vocabulary knows
## (On Body Entered), "On" and the signal's name as written for every other one.
static func event_reading(signal_name: String) -> String:
	if EventSheetACELifter.CORE_SIGNAL_TRIGGERS.has(signal_name):
		var trigger_id: String = str(EventSheetACELifter.CORE_SIGNAL_TRIGGERS[signal_name])
		var words: RegEx = RegEx.create_from_string("[A-Z][a-z0-9]*")
		var parts: PackedStringArray = PackedStringArray()
		for word: RegExMatch in words.search_all(trigger_id):
			parts.append(word.get_string())
		return " ".join(parts)
	return "%s %s" % [EventSheetL10n.translate("On"), signal_name]


## The handler line the event compiles to.
static func handler_line(signal_name: String, args: String) -> String:
	return "func _on_%s(%s) -> void:" % [signal_name, args]


func _build() -> void:
	if _dialog != null and is_instance_valid(_dialog):
		_dialog.queue_free()
	var parts: Dictionary = EventSheetPopupUI.panel_window(
		EventSheetL10n.translate("Connect a signal of {node}").replace("{node}", str(_node.name)), Vector2i.ZERO, _parent,
		EventSheetL10n.translate("Connect"), _on_confirmed, true)
	_dialog = parts["window"]
	var form: VBoxContainer = parts["box"]
	_band = EventSheetPopupUI.RowBand.new()
	form.add_child(_band)
	var content: VBoxContainer = EventSheetPopupUI.form_box()
	_search = LineEdit.new()
	_search.placeholder_text = EventSheetL10n.translate("Filter signals...")
	_search.right_icon = EventSheetPopupUI._editor_icon("Search")
	_search.text_changed.connect(_apply_filter)
	content.add_child(_search)
	_list = Tree.new()
	_list.columns = 2
	_list.hide_root = true
	_list.set_column_expand(1, false)
	_list.set_column_custom_minimum_width(1, int(EventSheetPalette.scaled_f(110.0)))
	_list.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(420.0), EventSheetPalette.scaled_f(220.0))
	_list.item_selected.connect(_refresh)
	_list.item_activated.connect(func() -> void: _dialog.get_ok_button().pressed.emit())
	content.add_child(_list)
	form.add_child(EventSheetPopupUI.titled_card(
		EventSheetL10n.translate("{node} - pick a signal").replace("{node}", str(_node.name)), content))
	_note = EventSheetPopupUI.StateNote.new(EventSheetPalette.scaled_f(400.0))
	form.add_child(_note)
	_strip = EventSheetPopupUI.help_strip("", "", "", "", EventSheetPalette.scaled_f(400.0))
	form.add_child(_strip)
	_strip.follow(_search, EventSheetL10n.translate("Filter signals..."),
		EventSheetL10n.translate("Narrows the list to the signals whose name holds what you type."))
	_strip.follow(_list, EventSheetL10n.translate("This signal"),
		EventSheetL10n.translate("An On <signal> event is added to the node's sheet; its actions run when the signal fires."))
	# This window parents to the editor base control (outside the dock's translation domain), so it
	# claims the plugin domain itself.
	EventSheetL10n.apply_to(_dialog)


func _apply_filter(query: String) -> void:
	_filtered = []
	_list.clear()
	var root: TreeItem = _list.create_item()
	var needle: String = query.strip_edges().to_lower()
	for signal_info: Dictionary in _signals:
		var signal_name: String = str(signal_info.get("name", ""))
		if not needle.is_empty() and not signal_name.to_lower().contains(needle):
			continue
		_filtered.append(signal_info)
		var item: TreeItem = _list.create_item(root)
		item.set_text(0, "%s(%s)" % [signal_name, str(signal_info.get("args", ""))])
		if _handled.has(signal_name):
			item.set_text(1, EventSheetL10n.translate("in {file}").replace("{file}", _sheet_path.get_file()))
			item.set_custom_color(1, EventSheetPopupUI.muted_text_color())
	if root.get_child_count() > 0:
		root.get_child(0).select(0)
	_refresh()


## The signal under the cursor, or {}.
func selected_signal() -> Dictionary:
	var item: TreeItem = _list.get_selected()
	if item == null or item.get_index() >= _filtered.size():
		return {}
	return _filtered[item.get_index()]


## Redraws the band and the handler line for the chosen signal, and says when the sheet answers it
## already - Connect then adds a second event for the same signal.
func _refresh() -> void:
	var chosen: Dictionary = selected_signal()
	_dialog.get_ok_button().disabled = chosen.is_empty()
	if chosen.is_empty():
		_band.show_row(str(_node.name), "")
		_strip.set_reading("", "")
		_note.say(EventSheetL10n.translate("No signal of {node} holds that.").replace("{node}", str(_node.name)), EventSheetPopupUI.TONE_WARNING)
		return
	var signal_name: String = str(chosen.get("name", ""))
	_band.show_row(str(_node.name), event_reading(signal_name))
	_strip.describe(EventSheetL10n.translate("This signal"),
		EventSheetL10n.translate("An {event} event is added to {file}; its actions run when the signal fires.").replace(
			"{event}", event_reading(signal_name)).replace("{file}", _sheet_path.get_file()))
	_strip.set_reading("", handler_line(signal_name, str(chosen.get("args", ""))))
	_note.say(EventSheetL10n.translate("{file} already handles {signal} - Connect adds a second event for it.").replace(
		"{file}", _sheet_path.get_file()).replace("{signal}", signal_name) if _handled.has(signal_name) else "",
		EventSheetPopupUI.TONE_WARNING)


func _on_confirmed() -> void:
	var signal_info: Dictionary = selected_signal()
	if signal_info.is_empty():
		return
	# The trigger lands in the node's sheet: open it in the workspace first (a no-op when already
	# open), then append through the one mutation funnel - undoable, refreshed.
	EventSheets.open_sheet(_sheet_path)
	if EventSheets.add_trigger_for_signal(str(signal_info.get("name", "")), str(signal_info.get("args", ""))):
		EventSheets.set_status("Connected %s - add actions to the new event." % str(signal_info.get("name", "")))
	else:
		EventSheets.set_status("Open the EventSheet workspace to connect signals.", true)
