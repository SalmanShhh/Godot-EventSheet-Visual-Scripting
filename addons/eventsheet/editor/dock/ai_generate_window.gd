@tool
class_name EventSheetAIGenerateWindow
extends RefCounted
# "Generate Events from a Description": a plain-English prompt -> grounded GDScript (an LLM) -> losslessly
# lifted into editable events. The provider is injected in tests; live it makes a configured HTTP call to
# the endpoint in Project Settings (eventsheets/ai/*). Extracted from event_sheet_dock.gd to keep that
# file maintainable; this owns its own window + prompt widgets and reaches dock state (current sheet, undo /
# dirty / status) through the _dock back-reference, the same pattern as the other dock/ helpers.

var _dock: Control = null
var _ai_window: Window = null
var _ai_prompt_edit: TextEdit = null


func init(dock: Control) -> void:
	_dock = dock


## Generate from Description: plain-English prompt → grounded GDScript (an LLM) → losslessly
## lifted into editable events. Injected provider in tests; a configured HTTP call live.
func open() -> void:
	if _dock._current_sheet == null:
		_dock._set_status("Open or create a sheet first.", true)
		return
	if _ai_window == null:
		_ai_window = Window.new()
		_ai_window.title = "Generate Events from a Description"
		_ai_window.size = Vector2i(580, 320)
		_ai_window.close_requested.connect(func() -> void: _ai_window.hide())
		var box: VBoxContainer = VBoxContainer.new()
		box.set_anchors_preset(Control.PRESET_FULL_RECT)
		box.add_theme_constant_override("separation", 8)
		var hint: Label = Label.new()
		hint.text = "Describe the behavior in plain English - it becomes GDScript, then editable events you can tweak."
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(hint)
		_ai_prompt_edit = TextEdit.new()
		_ai_prompt_edit.placeholder_text = "e.g. When the player presses jump and is on the floor, set velocity.y to -400 and play the jump sound."
		_ai_prompt_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.add_child(_ai_prompt_edit)
		var buttons: HBoxContainer = HBoxContainer.new()
		buttons.alignment = BoxContainer.ALIGNMENT_END
		var generate: Button = Button.new()
		generate.text = "Generate"
		generate.pressed.connect(_ai_generate_clicked)
		buttons.add_child(generate)
		box.add_child(buttons)
		_ai_window.add_child(box)
		_dock.add_child(_ai_window)
	_ai_window.popup_centered()
	_ai_prompt_edit.grab_focus()


func _ai_generate_clicked() -> void:
	var description: String = _ai_prompt_edit.text.strip_edges()
	if description.is_empty():
		_dock._set_status("Type a description first.", true)
		return
	if EventSheetAIGeneration.response_provider.is_valid():
		_apply_ai_gdscript(EventSheetAIGeneration.resolve_gdscript(description, _dock._current_sheet))
		return
	if not EventSheetAIGeneration.is_live_configured():
		_dock._set_status("Set eventsheets/ai/api_key (+ endpoint, model) in Project Settings to generate in-editor - or use the MCP server.", true)
		return
	_ai_request_live(description)


## Lifts generated GDScript into events and appends them undoably. Returns rows added (testable).
func _apply_ai_gdscript(gdscript_text: String) -> int:
	var outcome: Dictionary = EventSheetAIGeneration.generate_rows("", _dock._current_sheet, gdscript_text)
	if str(outcome.get("error", "")) != "":
		_dock._set_status(str(outcome.get("error")), true)
		return 0
	var rows: Array = outcome.get("rows", [])
	if _dock._perform_undoable_sheet_edit("Generate Events (AI)", func() -> bool:
		for row: Variant in rows:
			if row is Resource:
				_dock._current_sheet.events.append(row)
		return true):
		_dock._mark_dirty("Generated %d row(s) from your description." % rows.size())
		if _ai_window != null:
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
	_dock._set_status("Generating from your description…")
	http.request(endpoint, headers, HTTPClient.METHOD_POST, payload)


func _on_ai_live_response(code: int, body: PackedByteArray) -> void:
	if code != 200:
		_dock._set_status("AI request failed (HTTP %d). Check eventsheets/ai/* settings." % code, true)
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary):
		_dock._set_status("AI response could not be parsed.", true)
		return
	var content: Variant = (parsed as Dictionary).get("content", [])
	var text: String = ""
	if content is Array and not (content as Array).is_empty() and (content[0] is Dictionary):
		text = str((content[0] as Dictionary).get("text", ""))
	if text.is_empty():
		_dock._set_status("AI returned no usable text.", true)
		return
	_apply_ai_gdscript(text)
