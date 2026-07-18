@tool
class_name EventSheetConnectSignalDialog
extends RefCounted

# The "Connect Signal to Event Sheet" dialog (the Node-dock flow): pick one of the
# selected node's signals - script signals and its native class's alike, searchable -
# and an On <Signal> trigger event lands in the node's sheet, arguments pre-baked.
# Meeting Godot users where they already work: the same gesture as connecting a signal
# to a script method, except the handler is an event row instead of a code stub.

var _dialog: AcceptDialog = null
var _search: LineEdit = null
var _list: ItemList = null
var _signals: Array[Dictionary] = []
var _filtered: Array[Dictionary] = []
var _node: Node = null
var _sheet_path: String = ""
var _parent: Node = null


## Opens for one scene node whose script pairs with (or is) a sheet. `sheet_path` is that
## sheet; `parent` hosts the dialog window.
func open(node: Node, sheet_path: String, parent: Node) -> void:
	_node = node
	_sheet_path = sheet_path
	_parent = parent
	_signals = EventSheets.signals_of(node)
	_build()
	_apply_filter("")
	_dialog.popup_centered(Vector2i(460, 420))
	_search.grab_focus()


func _build() -> void:
	if _dialog != null and is_instance_valid(_dialog):
		_dialog.queue_free()
	_dialog = AcceptDialog.new()
	_dialog.title = "Connect Signal to Event Sheet"
	_dialog.ok_button_text = "Connect"
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	content.add_child(EventSheetPopupUI.hint_label("An On <Signal> event is added to the node's sheet; its actions run when the signal fires.", 420.0))
	_search = LineEdit.new()
	_search.placeholder_text = "Filter signals..."
	_search.text_changed.connect(_apply_filter)
	content.add_child(_search)
	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(420, 260)
	_list.item_activated.connect(func(_index: int) -> void: _dialog.get_ok_button().pressed.emit())
	content.add_child(_list)
	_dialog.add_child(EventSheetPopupUI.titled_card("%s - pick a signal" % _node.name, content))
	_dialog.confirmed.connect(_on_confirmed)
	# This dialog parents to the editor base control (outside the dock's translation
	# domain), so it claims the plugin domain itself - its strings auto-translate.
	EventSheetL10n.apply_to(_dialog)
	_parent.add_child(_dialog)


func _apply_filter(query: String) -> void:
	_filtered = []
	_list.clear()
	var needle: String = query.strip_edges().to_lower()
	for signal_info: Dictionary in _signals:
		var signal_name: String = str(signal_info.get("name", ""))
		if not needle.is_empty() and not signal_name.to_lower().contains(needle):
			continue
		_filtered.append(signal_info)
		var args: String = str(signal_info.get("args", ""))
		_list.add_item("%s(%s)" % [signal_name, args] if not args.is_empty() else "%s()" % signal_name)
	if _list.item_count > 0:
		_list.select(0)


func _on_confirmed() -> void:
	var selected: PackedInt32Array = _list.get_selected_items()
	if selected.is_empty() or selected[0] >= _filtered.size():
		return
	var signal_info: Dictionary = _filtered[selected[0]]
	# The trigger lands in the node's sheet: open it in the workspace first (a no-op when
	# already open), then append through the one mutation funnel - undoable, refreshed.
	EventSheets.open_sheet(_sheet_path)
	if EventSheets.add_trigger_for_signal(str(signal_info.get("name", "")), str(signal_info.get("args", ""))):
		EventSheets.set_status("Connected %s - add actions to the new event." % str(signal_info.get("name", "")))
	else:
		EventSheets.set_status("Open the EventSheet workspace to connect signals.", true)
