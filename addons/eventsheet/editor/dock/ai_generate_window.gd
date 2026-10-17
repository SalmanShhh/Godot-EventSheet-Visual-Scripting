@tool
class_name EventSheetAIGenerateWindow
extends RefCounted
# "Generate Events from a Description": a plain-English prompt -> grounded GDScript (an LLM) -> losslessly
# lifted into editable events. The provider is injected in tests; live it makes a configured HTTP call to
# the endpoint in Project Settings (eventsheets/ai/*). Extracted from event_sheet_dock.gd to keep that
# file maintainable; this owns its own window + prompt widgets and reaches dock state (current sheet, undo /
# dirty / status) through the _dock back-reference, the same pattern as the other dock/ helpers.

var _dock: Control = null
var _ai_window: ConfirmationDialog = null
var _ai_prompt_edit: TextEdit = null
## Left of the buttons: why Generate cannot run, or what went wrong with the last request.
var _note: EventSheetPopupUI.StateNote = null
## True while a live request is out; a click meanwhile sends nothing.
var _request_in_flight: bool = false


func init(dock: Control) -> void:
	_dock = dock


## Generate from Description: plain-English prompt → grounded GDScript (an LLM) → losslessly
## lifted into editable events. Injected provider in tests; a configured HTTP call live.
func open() -> void:
	if _dock._current_sheet == null:
		_dock._set_status("Open or create a sheet first.", true)
		return
	if _ai_window == null:
		_build()
	_refresh_gate()
	_ai_window.popup_centered()
	_ai_prompt_edit.grab_focus()


## The window says where the description goes and, beside a greyed Generate, why it cannot run.
func _build() -> void:
	var parts: Dictionary = EventSheetPopupUI.action_window(EventSheetL10n.translate("Generate Events from a Description"), "Generate",
		"Cancel", Vector2i(580, 340), _dock)
	_ai_window = parts["window"]
	_note = parts["note"]
	_ai_window.confirmed.connect(_ai_generate_clicked)
	EventSheetPopupUI.main_button(_ai_window.get_ok_button())
	var box: VBoxContainer = parts["box"]
	box.add_child(EventSheetPopupUI.hint_label(
		EventSheetL10n.translate("Describe the behavior in plain English - it becomes GDScript, then editable events you can tweak."),
		EventSheetPalette.scaled_f(540.0)))
	_ai_prompt_edit = TextEdit.new()
	_ai_prompt_edit.placeholder_text = EventSheetL10n.translate("e.g. When the player presses jump and is on the floor, set velocity.y to -400 and play the jump sound.")
	_ai_prompt_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_ai_prompt_edit.custom_minimum_size = Vector2(0.0, EventSheetPalette.scaled_f(70.0))
	_ai_prompt_edit.text_changed.connect(_refresh_gate)
	box.add_child(EventSheetPopupUI.titled_card("Description", _ai_prompt_edit))
	var strip: EventSheetPopupUI.HelpStrip = EventSheetPopupUI.help_strip()
	strip.follow(_ai_prompt_edit, EventSheetL10n.translate("Description"),
		EventSheetL10n.translate("The rows land in this sheet at once, as one undo step."))
	strip.set_line(strip.add_line(EventSheetL10n.translate("SENDS TO")), "eventsheets/ai/endpoint")
	box.add_child(strip)


## Why Generate cannot run right now, or "" when it can. An injected provider (the suite's seam)
## sends nothing, so nothing stands in its way.
func _blocked_reason() -> String:
	if EventSheetAIGeneration.response_provider.is_valid():
		return ""
	# Ask's switch is the one switch for anything leaving this machine: off means nothing is sent,
	# whatever key this window's own settings hold.
	if EventSheetAsk.mode() == EventSheetAsk.MODE_OFF:
		return EventSheetL10n.translate("Ask is off, so nothing will be sent. Turn it on in Project Settings ▸ EventSheets ▸ Ask to generate in-editor - or use the MCP server.")
	if not EventSheetAIGeneration.is_live_configured():
		return EventSheetL10n.translate("Set eventsheets/ai/api_key in Project Settings first.")
	# One request at a time: a second click while the first is out would append its rows twice.
	if _request_in_flight:
		return EventSheetL10n.translate("Still generating from your description…")
	return ""


## Greys Generate while there is nothing to send or it cannot be sent, and says the second on the window.
func _refresh_gate() -> void:
	var reason: String = _blocked_reason()
	_note.say(reason, EventSheetPopupUI.TONE_WARNING)
	_ai_window.get_ok_button().disabled = not reason.is_empty() or _ai_prompt_edit.text.strip_edges().is_empty()


func _ai_generate_clicked() -> void:
	var description: String = _ai_prompt_edit.text.strip_edges()
	if description.is_empty() or not _blocked_reason().is_empty():
		_refresh_gate()
		return
	if EventSheetAIGeneration.response_provider.is_valid():
		_apply_ai_gdscript(EventSheetAIGeneration.resolve_gdscript(description, _dock._current_sheet))
		return
	_ai_request_live(description)


## Lifts generated GDScript into events and appends them undoably. Returns rows added (testable).
func _apply_ai_gdscript(gdscript_text: String) -> int:
	var outcome: Dictionary = EventSheetAIGeneration.generate_rows("", _dock._current_sheet, gdscript_text)
	if str(outcome.get("error", "")) != "":
		_note.say(str(outcome.get("error")))
		return 0
	var rows: Array = outcome.get("rows", [])
	if _dock._perform_undoable_sheet_edit("Generate Events (AI)", func() -> bool:
		for row: Variant in rows:
			if row is Resource:
				_dock._current_sheet.events.append(row)
		return true):
		_dock._mark_dirty("Generated %d row(s) from your description." % rows.size())
		_ai_window.hide()
	return rows.size()


func _ai_request_live(description: String) -> void:
	var key: String = str(ProjectSettings.get_setting("eventsheets/ai/api_key", "")).strip_edges()
	var endpoint: String = str(ProjectSettings.get_setting("eventsheets/ai/endpoint", "https://api.anthropic.com/v1/messages"))
	var model: String = str(ProjectSettings.get_setting("eventsheets/ai/model", "claude-opus-4-8"))
	var prompt: String = EventSheetAIGeneration.build_prompt(description, _dock._current_sheet)
	var http: HTTPRequest = HTTPRequest.new()
	_dock.add_child(http)
	http.request_completed.connect(func(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
		_request_in_flight = false
		_refresh_gate()
		_on_ai_live_response(code, body)
		http.queue_free())
	var headers: PackedStringArray = PackedStringArray([
		"content-type: application/json",
		"x-api-key: %s" % key,
		"anthropic-version: 2023-06-01"
	])
	var payload: String = JSON.stringify({
		"model": model, "max_tokens": 1024,
		"messages": [{"role": "user", "content": prompt}]
	})
	var error: Error = http.request(endpoint, headers, HTTPClient.METHOD_POST, payload)
	if error != OK:
		# A request that never started never completes, so nothing else would ever free this node.
		http.free()
		_note.say(EventSheetL10n.translate("AI request could not start (%s). Nothing was sent.") % error_string(error))
		return
	_request_in_flight = true
	_refresh_gate()


func _on_ai_live_response(code: int, body: PackedByteArray) -> void:
	if code != 200:
		_note.say(EventSheetL10n.translate("AI request failed (HTTP %d). Check eventsheets/ai/* settings.") % code)
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary):
		_note.say(EventSheetL10n.translate("AI response could not be parsed."))
		return
	var content: Variant = (parsed as Dictionary).get("content", [])
	var text: String = ""
	if content is Array and not (content as Array).is_empty() and (content[0] is Dictionary):
		text = str((content[0] as Dictionary).get("text", ""))
	if text.is_empty():
		_note.say(EventSheetL10n.translate("AI returned no usable text."))
		return
	_apply_ai_gdscript(text)
