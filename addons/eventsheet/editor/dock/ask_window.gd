@tool
class_name EventSheetAskWindow
extends RefCounted

# The Ask box (View ▸ Ask…): type what you want to happen, read what it proposes, decide.
#
# Three states and no fourth. The box opens saying whether Ask is on; pressing Ask sends the one
# request EventSheetAsk builds and shows the proposal as a plain listing in the sheet's own words;
# and the proposal sits there until the reader presses "Add these events" or "Discard". Arriving
# applies nothing.
#
# All the judgement - what is sent, what a reply must look like, which rows survive the registry -
# lives in EventSheetAsk, so it is pinned headless. This class is the window, the three buttons and
# the status line, the same shape as the other dock/ helpers: it reaches dock state through _dock.

var _dock: Control = null
var _window: ConfirmationDialog = null
var _prompt_edit: TextEdit = null
var _proposal_label: RichTextLabel = null
var _add_button: Button = null
var _mode_note: EventSheetPopupUI.StateNote = null
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
	_window.popup_centered(Vector2i(EventSheetPalette.scaled(620), EventSheetPalette.scaled(560)))
	_prompt_edit.grab_focus()


## The window: the mode line, the sentence, the proposal and one help strip, with Discard, Ask and
## the blue Add these events in the button row. Add these events is the window's OK, and it closes
## the window only once the rows are in.
func _build() -> void:
	var parts: Dictionary = EventSheetPopupUI.panel_window("Ask for events", Vector2i(620, 560), _dock,
		"Add these events", _add_pressed)
	_window = parts["window"]
	_window.exclusive = false
	_window.get_cancel_button().visible = false
	var box: VBoxContainer = parts["box"]
	_mode_note = EventSheetPopupUI.StateNote.new(EventSheetPalette.scaled_f(560.0))
	box.add_child(_mode_note)
	_prompt_edit = TextEdit.new()
	_prompt_edit.placeholder_text = "when the player presses jump and is on the floor, jump and play the jump sound"
	_prompt_edit.custom_minimum_size = Vector2(0, EventSheetPalette.scaled_f(62.0))
	_prompt_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	box.add_child(EventSheetPopupUI.titled_card("What do you want to happen?", _prompt_edit))
	_proposal_label = RichTextLabel.new()
	_proposal_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_proposal_label.custom_minimum_size = Vector2(0, EventSheetPalette.scaled_f(150.0))
	var proposal_card: PanelContainer = EventSheetPopupUI.titled_card("Proposed", _proposal_label)
	proposal_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(proposal_card)
	var strip: EventSheetPopupUI.HelpStrip = EventSheetPopupUI.help_strip(EventSheetL10n.translate("Proposed"),
		EventSheetL10n.translate("Nothing is added until you press Add these events - one undo step."))
	strip.follow(_prompt_edit, EventSheetL10n.translate("What do you want to happen?"),
		EventSheetL10n.translate("One sentence in your own words. Nothing is sent until you press Ask."))
	strip.follow(_proposal_label, EventSheetL10n.translate("Proposed"),
		EventSheetL10n.translate("Nothing is added until you press Add these events - one undo step."))
	strip.set_line(strip.add_line(EventSheetL10n.translate("SENDS TO")), EventSheetAsk.SETTING_ENDPOINT)
	box.add_child(strip)
	# add_button puts each new left-hand button first, so Ask goes in before Discard.
	var ask_button: Button = _window.add_button("Ask", false)
	ask_button.tooltip_text = "Nothing is sent until you press this."
	ask_button.pressed.connect(_ask_pressed)
	var discard_button: Button = _window.add_button("Discard", false)
	discard_button.tooltip_text = "Drops the proposal. Your sentence stays, so you can reword it and ask again."
	discard_button.pressed.connect(_discard_pressed)
	_add_button = EventSheetPopupUI.main_button(_window.get_ok_button())
	_add_button.disabled = true


## The one line that says, before anything is typed, whether this box can send at all: the ok edge
## while Ask is on, amber while it is off.
func _refresh_mode() -> void:
	if EventSheetAsk.is_on():
		_mode_note.say(EventSheetL10n.translate("Ask is on (%s). Your sentence, this sheet's objects and the words this sheet can write go to %s when you press Ask. Nothing else, and nothing until then.") % [EventSheetL10n.translate(EventSheetAsk.mode()), EventSheetAsk.endpoint()],
			EventSheetPopupUI.TONE_OK)
	else:
		_mode_note.say(EventSheetL10n.translate("Ask is off, so nothing will be sent. Turn it on in Project Settings ▸ EventSheets ▸ Ask and give it an endpoint that speaks the common chat format."),
			EventSheetPopupUI.TONE_WARNING)


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
	_proposal_label.text = EventSheetL10n.translate("Asking %s…") % EventSheetAsk.endpoint()
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
		_proposal_label.text = EventSheetL10n.translate("%s answered %d:") % [EventSheetAsk.endpoint(), status] + "\n" + body
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
		lines.append(EventSheetL10n.translate("Dropped, because this project has no words for them:"))
		for reason: String in dropped:
			lines.append("  %s" % reason)
	_proposal_label.text = "\n".join(lines) if not lines.is_empty() else "Nothing this sheet can say came back."


func _set_proposal(rows: Array) -> void:
	_proposal = rows
	_add_button.disabled = _proposal.is_empty()


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


## Drops the proposal only. The sentence stays, so the reader can reword it and ask again.
func _discard_pressed() -> void:
	_set_proposal([])
	_proposal_label.text = ""
