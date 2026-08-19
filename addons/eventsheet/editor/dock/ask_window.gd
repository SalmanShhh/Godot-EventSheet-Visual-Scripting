@tool
class_name EventSheetAskWindow
extends RefCounted

# The Ask box (View ▸ Ask…): type what you want to happen, read what it proposes, decide.
#
# Three states and no fourth. The box opens saying whether Ask is on; pressing Ask sends the one
# request EventSheetAsk builds and shows the proposal as a plain listing in the sheet's own words;
# and the proposal sits there until the reader presses "Add these events", "Try in a scratch sheet"
# or "Discard". Arriving applies nothing.
#
# All the judgement - what is sent, what a reply must look like, which rows survive the registry -
# lives in EventSheetAsk, so it is pinned headless. This class is the window, the three buttons and
# the status line, the same shape as the other dock/ helpers: it reaches dock state through _dock.

var _dock: Control = null
var _window: Window = null
var _prompt_edit: TextEdit = null
var _proposal_label: RichTextLabel = null
var _add_button: Button = null
var _scratch_button: Button = null
var _mode_label: Label = null
## Built on the first live call and kept: the one socket this plugin ever opens.
var _http: HTTPRequest = null
## The checked rows the last reply proposed. Empty until a reply arrives; emptied by Discard.
var _proposal: Array = []


func init(dock: Control) -> void:
	_dock = dock


func open() -> void:
	if _dock._current_sheet == null:
		_dock._set_status("Open or create a sheet first.", true)
		return
	if _window == null:
		_build()
	_refresh_mode()
	_window.popup_centered()
	_prompt_edit.grab_focus()


func _build() -> void:
	_window = Window.new()
	_window.title = "Ask"
	_window.size = Vector2i(620, 560)
	_window.close_requested.connect(func() -> void: _window.hide())
	var box: VBoxContainer = EventSheetPopupUI.form_box()
	_mode_label = Label.new()
	_mode_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(EventSheetPopupUI.panel_section(_mode_label))
	_prompt_edit = TextEdit.new()
	_prompt_edit.placeholder_text = "when the player presses jump and is on the floor, jump and play the jump sound"
	_prompt_edit.custom_minimum_size = Vector2(0, 62)
	_prompt_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	box.add_child(EventSheetPopupUI.titled_card("What do you want to happen?", _prompt_edit))
	_proposal_label = RichTextLabel.new()
	_proposal_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_proposal_label.custom_minimum_size = Vector2(0, 150)
	var proposal_card: PanelContainer = EventSheetPopupUI.titled_card("Proposed", _proposal_label)
	proposal_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(proposal_card)
	var buttons: HBoxContainer = HBoxContainer.new()
	var ask_button: Button = Button.new()
	ask_button.text = "Ask"
	ask_button.tooltip_text = "Nothing is sent until you press this."
	ask_button.pressed.connect(_ask_pressed)
	buttons.add_child(ask_button)
	_add_button = Button.new()
	_add_button.text = "Add these events"
	_add_button.disabled = true
	_add_button.pressed.connect(_add_pressed)
	buttons.add_child(_add_button)
	_scratch_button = Button.new()
	_scratch_button.text = "Try in a scratch sheet"
	_scratch_button.disabled = true
	_scratch_button.pressed.connect(_scratch_pressed)
	buttons.add_child(_scratch_button)
	var discard_button: Button = Button.new()
	discard_button.text = "Discard"
	discard_button.pressed.connect(_discard_pressed)
	buttons.add_child(discard_button)
	box.add_child(buttons)
	var body: MarginContainer = EventSheetPopupUI.margined(box)
	body.set_anchors_preset(Control.PRESET_FULL_RECT)
	_window.add_child(body)
	_dock.add_child(_window)


## The one line that says, before anything is typed, whether this box can send at all.
func _refresh_mode() -> void:
	if EventSheetAsk.is_on():
		_mode_label.text = "Ask is on (%s). Your sentence, this sheet's objects and the words this sheet can write go to %s when you press Ask. Nothing else, and nothing until then." % [EventSheetAsk.mode(), EventSheetAsk.endpoint()]
	else:
		_mode_label.text = "Ask is off, so nothing will be sent. Turn it on in Project Settings ▸ EventSheets ▸ Ask and give it an endpoint that speaks the common chat format."


func _ask_pressed() -> void:
	var registry: EventSheetACERegistry = _dock.get_ace_registry()
	var definitions: Array = registry.get_all_definitions() if registry != null else []
	var answer: Dictionary = EventSheetAsk.ask(_prompt_edit.text, _dock._current_sheet, definitions)
	if not bool(answer.get("sent", false)):
		if not str(answer.get("error", "")).is_empty():
			_proposal_label.text = str(answer.get("error", ""))
			_set_proposal([])
			return
		# Ask is on and the request is built, but nothing was injected to carry it - so this is the
		# live call. It waits, which is why it lives in the window and not in the static seam.
		_send_live(answer.get("request", {}) as Dictionary, definitions)
		return
	_show_answer(str(answer.get("reply", "")), definitions)


## The live call: one POST of the request EventSheetAsk built, to the endpoint the reader chose.
## Deliberately the only place in the plugin that opens a socket, and it is only ever reached from
## the Ask button.
func _send_live(request: Dictionary, definitions: Array) -> void:
	if _http == null:
		_http = HTTPRequest.new()
		_dock.add_child(_http)
	_proposal_label.text = "Asking %s…" % EventSheetAsk.endpoint()
	_set_proposal([])
	var error: int = _http.request(EventSheetAsk.endpoint(), EventSheetAsk.request_headers(),
		HTTPClient.METHOD_POST, JSON.stringify(request))
	if error != OK:
		_proposal_label.text = "Could not reach %s (error %d). Nothing was sent." \
			% [EventSheetAsk.endpoint(), error]
		return
	var result: Array = await _http.request_completed
	var status: int = int(result[1])
	var body: String = (result[3] as PackedByteArray).get_string_from_utf8()
	if status < 200 or status >= 300:
		_proposal_label.text = "%s answered %d:\n%s" % [EventSheetAsk.endpoint(), status, body]
		return
	_show_answer(EventSheetAsk.reply_text_from_body(body), definitions)


## One reply, checked and shown. Shared by the injected seam and the live call so a test and a real
## endpoint land in exactly the same place.
func _show_answer(reply: String, definitions: Array) -> void:
	var checked: Dictionary = EventSheetAsk.validate(reply, definitions)
	if not str(checked.get("error", "")).is_empty():
		_proposal_label.text = str(checked.get("error"))
		_set_proposal([])
		return
	_set_proposal(checked.get("rows", []) as Array)
	var lines: PackedStringArray = EventSheetAsk.proposal_lines(_proposal)
	var dropped: PackedStringArray = checked.get("dropped", PackedStringArray())
	if not dropped.is_empty():
		lines.append("")
		lines.append("Dropped, because this project has no words for them:")
		for reason: String in dropped:
			lines.append("  %s" % reason)
	_proposal_label.text = "\n".join(lines) if not lines.is_empty() else "Nothing this sheet can say came back."


func _set_proposal(rows: Array) -> void:
	_proposal = rows
	_add_button.disabled = _proposal.is_empty()
	_scratch_button.disabled = _proposal.is_empty()


func _add_pressed() -> void:
	var registry: EventSheetACERegistry = _dock.get_ace_registry()
	var definitions: Array = registry.get_all_definitions() if registry != null else []
	var events: Array = EventSheetAsk.proposal_events(_proposal, definitions,
		Callable(EventSheetDock, "_fresh_uid_token"))
	if events.is_empty():
		_dock._set_status("Nothing to add.", true)
		return
	var added: bool = _dock._perform_undoable_sheet_edit("Add asked events",
		func() -> bool:
			for event: Variant in events:
				_dock._current_sheet.events.append(event)
			return true)
	if added:
		_dock._set_status("Added %d event(s) from Ask." % events.size())
		_window.hide()


func _scratch_pressed() -> void:
	var registry: EventSheetACERegistry = _dock.get_ace_registry()
	var definitions: Array = registry.get_all_definitions() if registry != null else []
	var scratch: EventSheetResource = EventSheetAsk.proposal_sheet(_proposal, definitions,
		_dock._current_sheet, Callable(EventSheetDock, "_fresh_uid_token"))
	if _dock.open_scratch_sheet("Ask", scratch):
		_window.hide()
	else:
		_dock._set_status("Could not open a scratch sheet for the proposal.", true)


func _discard_pressed() -> void:
	_set_proposal([])
	_proposal_label.text = ""
	_prompt_edit.text = ""
