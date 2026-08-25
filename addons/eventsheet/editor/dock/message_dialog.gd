@tool
class_name EventSheetMessageDialog
extends RefCounted
# The two dialogs a MESSAGE is authored through.
#
# Godot's `@rpc` takes three choices and a channel, spelled as strings in an annotation most people
# copy without reading. The MESSAGE dialog asks the three questions in words - who may send it,
# where it runs, how it travels - and writes the annotation; the row then reads those words back and
# echoes the very line that was written.
#
# The SEND dialog is the other half. Sending a message is one decision - which message, with what,
# to whom - but the vocabulary answers it with three separate actions, one per destination. So this
# asks those three things and the To dropdown decides which of the existing `ace_id`s the row
# becomes, exactly the way the Compare dialog decides between the comparison conditions. No ids
# change and no templates change: the mapping is `EventSheetMessageFacts.send_choices()`.
#
# Everything worth pinning is static and lives in `EventSheetMessageFacts` - the words table both
# directions, the annotation writer with its byte-exact rule, the send mapping. This file is the
# shell: two forms, one help strip each, and the undo funnel.

## Emitted when the Send dialog is confirmed. `ace_id` is one of the three shipped Send ids; the
## dock resolves it against the registry and applies it through the ordinary ACE apply path, so
## undo, replace-in-place and the `{uid}` bake behave exactly as for a row picked from the picker.
signal send_confirmed(ace_id: String, params: Dictionary, context: Dictionary)

var _dock: Control = null

# ── The Message dialog (right-click a function ▸ Make it a message…) ──────────────────────────
var _message_dialog: ConfirmationDialog = null
var _message_signature: Label = null
var _message_options: Dictionary = {}
var _message_channel: LineEdit = null
var _message_strip: EventSheetPopupUI.HelpStrip = null
## The function being marked, held BY NAME: the undo funnel replaces resources on commit, so a held
## reference would point at a discarded snapshot by the time Apply runs.
var _message_target: String = ""

# ── The Send dialog (Add action ▸ Multiplayer ▸ Send …) ───────────────────────────────────────
var _send_dialog: ConfirmationDialog = null
var _send_owner: Label = null
var _send_message: LineEdit = null
var _send_args_box: VBoxContainer = null
var _send_to: OptionButton = null
var _send_peer_row: Control = null
var _send_peer: LineEdit = null
var _send_strip: EventSheetPopupUI.HelpStrip = null
var _send_context: Dictionary = {}
## One LineEdit per parameter of the named message, rebuilt whenever the message changes.
var _send_arg_edits: Array[LineEdit] = []


func init(dock: Control) -> void:
	_dock = dock


## The sheet being authored, or null.
func _sheet() -> EventSheetResource:
	return _dock._current_sheet if _dock != null else null


# ── What the two dialogs SAY (static + pure, so the suite pins them without a window) ─────────


## The sentence a message's own row reads as, which is the Message dialog's READS AS line:
## "message take_damage(amount)  from the owner · also here · reliable".
static func message_reading(function_name: String, params: PackedStringArray, annotation: String) -> String:
	var reads: String = "%s %s(%s)" % [
		EventSheetL10n.translate("message"), function_name, ", ".join(params)]
	var mode_words: String = EventSheetMessageFacts.words(annotation)
	return reads if mode_words.is_empty() else "%s  %s" % [reads, mode_words]


## The sentence a Send row reads as, filled from the very `display_text` the ROW is drawn from - so
## the strip can never promise a reading the canvas will not show. "" when the id names no shipped
## descriptor.
static func send_reading(ace_id: String, message: String, args: String, peer: String) -> String:
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor(EventSheetMessageFacts.PROVIDER, ace_id)
	if descriptor == null:
		return ""
	var text: String = descriptor.display_text
	var filled: Dictionary = EventSheetMessageFacts.send_params(ace_id, message, args, peer)
	for slot: String in filled:
		text = text.replace("{%s}" % slot, str(filled[slot]))
	return text.strip_edges()


## The line under the Message field while a name that is not a message stands in it, and "" while
## the name is one. A Send row naming an unmarked function compiles and then silently never travels,
## which is exactly the kind of quiet failure the strip exists to catch at keystroke time.
static func unmarked_message_note(sheet: EventSheetResource, message: String) -> String:
	var wanted: String = message.strip_edges()
	if wanted.is_empty():
		return ""
	for entry: Dictionary in EventSheetMessageFacts.messages_in(sheet):
		if str(entry.get("name", "")) == wanted:
			return ""
	return EventSheetL10n.translate("%s is not marked as a message yet, so nothing would travel. Right-click its function row and choose Make it a message.") % wanted


## The parameter names a Send row fills in for the named message, or an empty list when the sheet
## knows no such message (the row then takes one free-text Values field, as it always did).
static func message_parameters(sheet: EventSheetResource, message: String) -> PackedStringArray:
	var wanted: String = message.strip_edges()
	for entry: Dictionary in EventSheetMessageFacts.messages_in(sheet):
		if str(entry.get("name", "")) == wanted:
			return entry.get("params", PackedStringArray())
	return PackedStringArray()


# ── The Message dialog ────────────────────────────────────────────────────────────────────────


## Right-click a function ▸ Make it a message… - and the same dialog for a message that already has
## its annotation, opened on the answers the annotation already gives.
func open_message(event_function: EventFunction) -> void:
	if event_function == null or _sheet() == null:
		return
	_ensure_message_dialog()
	_message_target = event_function.function_name.strip_edges()
	var annotation: String = EventSheetMessageFacts.annotation_of(event_function)
	var said: Dictionary = EventSheetMessageFacts.parse(annotation) if not annotation.is_empty() \
		else EventSheetMessageFacts.NEW_MESSAGE
	for field: String in [EventSheetMessageFacts.FIELD_SENDER, EventSheetMessageFacts.FIELD_WHERE,
			EventSheetMessageFacts.FIELD_DELIVERY]:
		(_message_options[field] as OptionButton).select(
			EventSheetMessageFacts.choice_index(field, str(said.get(field, ""))))
	_message_channel.text = str(int(said.get("channel", 0)))
	_message_signature.text = "%s(%s)" % [
		_message_target, ", ".join(EventSheetMessageFacts.parameter_names(event_function))]
	# The strip opens on the first question, describing the answer THIS message gives - not the first
	# item of the list, which would explain a choice the dialog is not showing.
	var opening: Dictionary = _choice_note(EventSheetMessageFacts.FIELD_SENDER,
		(_message_options[EventSheetMessageFacts.FIELD_SENDER] as OptionButton).selected)
	_message_strip.show_note(str(opening.get("heading", "")), str(opening.get("body", "")))
	_refresh_message_reading()
	_message_dialog.popup_centered(Vector2i(
		int(EventSheetPalette.scaled_f(520.0)), int(EventSheetPalette.scaled_f(380.0))))


func _ensure_message_dialog() -> void:
	if _message_dialog != null:
		return
	_message_dialog = ConfirmationDialog.new()
	_message_dialog.title = "Message"
	_message_dialog.ok_button_text = "OK"
	_message_dialog.visible = false
	_message_dialog.confirmed.connect(_apply_message)
	_dock.add_child(_message_dialog)
	var form: VBoxContainer = EventSheetPopupUI.form_box()
	_message_dialog.add_child(EventSheetPopupUI.margined(form))
	# Whose message this is, said once at the top - the same line the Add variable dialog leads with.
	_message_signature = EventSheetPopupUI.hint_label("")
	form.add_child(_message_signature)
	_message_strip = EventSheetPopupUI.help_strip()
	# The three questions, each a dropdown whose CHOICES are described - what "anyone" lets a cheating
	# client do is a different paragraph from what "only the owner" costs, and the strip follows
	# whichever is highlighted.
	for field: String in [EventSheetMessageFacts.FIELD_SENDER, EventSheetMessageFacts.FIELD_WHERE,
			EventSheetMessageFacts.FIELD_DELIVERY]:
		var dropdown: OptionButton = OptionButton.new()
		dropdown.clip_text = true
		for choice: Dictionary in EventSheetMessageFacts.choices(field):
			dropdown.add_item(str(choice.get("label", "")))
			dropdown.set_item_metadata(dropdown.item_count - 1, str(choice.get("value", "")))
		dropdown.item_selected.connect(func(_index: int) -> void: _refresh_message_reading())
		_message_options[field] = dropdown
		form.add_child(EventSheetPopupUI.form_row(field, dropdown))
		_message_strip.follow_option(dropdown, func(index: int) -> Dictionary:
			return _choice_note(field, index))
	_message_channel = LineEdit.new()
	_message_channel.placeholder_text = "0"
	_message_channel.text_changed.connect(func(_text: String) -> void: _refresh_message_reading())
	form.add_child(EventSheetPopupUI.form_row(EventSheetMessageFacts.FIELD_CHANNEL, _message_channel))
	_message_strip.follow(_message_channel, EventSheetMessageFacts.FIELD_CHANNEL,
		EventSheetMessageFacts.field_help(EventSheetMessageFacts.FIELD_CHANNEL))
	form.add_child(_message_strip)


## One choice's heading and paragraph for the strip: "Who may send - Only the owner".
static func _choice_note(field: String, index: int) -> Dictionary:
	var listed: Array[Dictionary] = EventSheetMessageFacts.choices(field)
	if index < 0 or index >= listed.size():
		return {}
	return {
		"heading": "%s - %s" % [field, str(listed[index].get("label", ""))],
		"body": str(listed[index].get("description", ""))
	}


## The answers the three dropdowns and the channel field currently hold.
func _message_answers() -> Dictionary:
	var answers: Dictionary = {"channel": maxi(0, int(_message_channel.text.strip_edges()))}
	for field: String in _message_options:
		var dropdown: OptionButton = _message_options[field] as OptionButton
		answers[field] = EventSheetMessageFacts.choice_value(field, dropdown.selected)
	return answers


## The strip's two lines: the row this dialog is about to write, and the annotation it writes it with.
func _refresh_message_reading() -> void:
	if _message_strip == null:
		return
	var answers: Dictionary = _message_answers()
	var line: String = EventSheetMessageFacts.annotation_line(answers)
	_message_strip.set_reading(message_reading(
		_message_target, _signature_parameters(), line), line)


## The parameter names shown in the signature line, read back off the label so the dialog holds no
## second copy of them.
func _signature_parameters() -> PackedStringArray:
	var text: String = _message_signature.text
	var open_at: int = text.find("(")
	if open_at < 0 or not text.ends_with(")"):
		return PackedStringArray()
	var inside: String = text.substr(open_at + 1, text.length() - open_at - 2).strip_edges()
	return PackedStringArray() if inside.is_empty() else inside.split(", ")


## Writes the annotation onto the function, in one undo step. An answer that still MEANS what the
## file already said hands the original line straight back (EventSheetMessageFacts.rewrite), so
## opening a message and pressing OK cannot rewrite the `.gd`.
func _apply_message() -> void:
	var function_name: String = _message_target
	if function_name.is_empty():
		return
	var answers: Dictionary = _message_answers()
	var changed: bool = _dock._perform_undoable_sheet_edit("Make It A Message", func() -> bool:
		var target: EventFunction = _function_named(function_name)
		if target == null:
			return false
		var lines: PackedStringArray = EventSheetMessageFacts.annotation_lines_with(target, answers)
		if lines == target.annotation_lines:
			return false
		target.annotation_lines = lines
		return true
	)
	if changed:
		_dock._mark_dirty("%s is a message." % function_name)


## The function of this name on the LIVE sheet, or null. Always re-fetched: the undo funnel replaces
## resources on commit, so a reference held across an edit points at a discarded snapshot.
func _function_named(function_name: String) -> EventFunction:
	var sheet: EventSheetResource = _sheet()
	if sheet == null:
		return null
	for entry: Variant in sheet.functions:
		if entry is EventFunction and (entry as EventFunction).function_name.strip_edges() == function_name:
			return entry as EventFunction
	return null


# ── The Send dialog ───────────────────────────────────────────────────────────────────────────


## Opens the Send dialog for a row that does not exist yet, or for one being edited. `context` is
## the ACE apply context and is handed straight back on confirm.
func open_send(context: Dictionary, ace_id: String = "", params: Dictionary = {}) -> void:
	_ensure_send_dialog()
	_send_context = context.duplicate(true)
	_send_message.text = str(params.get("message", ""))
	_send_to.select(EventSheetMessageFacts.send_index(
		ace_id if not ace_id.is_empty() else EventSheetMessageFacts.SEND_TO_EVERYONE))
	_send_peer.text = str(params.get("peer", "1"))
	var owner: String = EventSheetVariableOwners.owner_of_sheet(_sheet())
	_send_owner.text = "" if owner.is_empty() \
		else EventSheetL10n.translate("on {object}").replace("{object}", owner)
	_rebuild_send_args(str(params.get("args", "")), false)
	_refresh_send_reading()
	_send_dialog.popup_centered(Vector2i(
		int(EventSheetPalette.scaled_f(560.0)), int(EventSheetPalette.scaled_f(400.0))))


func _ensure_send_dialog() -> void:
	if _send_dialog != null:
		return
	_send_dialog = ConfirmationDialog.new()
	_send_dialog.title = "Send message"
	_send_dialog.ok_button_text = "OK"
	_send_dialog.visible = false
	_send_dialog.confirmed.connect(_apply_send)
	_dock.add_child(_send_dialog)
	var form: VBoxContainer = EventSheetPopupUI.form_box()
	_send_dialog.add_child(EventSheetPopupUI.margined(form))
	_send_owner = EventSheetPopupUI.hint_label("")
	form.add_child(_send_owner)
	_send_strip = EventSheetPopupUI.help_strip()
	# WHICH message. Only the functions this sheet marks as messages are suggested - a function that
	# is not marked compiles into a call that silently never travels - but free text stays allowed,
	# because the message may belong to another object.
	_send_message = LineEdit.new()
	_send_message.placeholder_text = "take_damage"
	_send_message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_send_message.text_changed.connect(func(_text: String) -> void:
		_rebuild_send_args("", true)
		_refresh_send_reading())
	var message_row: HBoxContainer = HBoxContainer.new()
	message_row.add_theme_constant_override("separation", EventSheetPopupUI.ROW_SEPARATION)
	message_row.add_child(_send_message)
	message_row.add_child(EventSheetPopupUI.autocomplete_combo(_send_message,
		func() -> PackedStringArray:
			var names: PackedStringArray = PackedStringArray()
			for entry: Dictionary in EventSheetMessageFacts.messages_in(_sheet()):
				names.append(str(entry.get("name", "")))
			return names,
		func(suggestion: String) -> String:
			for entry: Dictionary in EventSheetMessageFacts.messages_in(_sheet()):
				if str(entry.get("name", "")) == suggestion:
					return str(entry.get("words", ""))
			return ""))
	form.add_child(EventSheetPopupUI.form_row(EventSheetMessageFacts.FIELD_MESSAGE, message_row))
	# WITH WHAT: one field per parameter of the named message, so the dialog asks for `amount` rather
	# than for a comma-separated list nobody can check.
	_send_args_box = VBoxContainer.new()
	_send_args_box.add_theme_constant_override("separation", EventSheetPopupUI.ROW_SEPARATION)
	form.add_child(_send_args_box)
	# TO WHOM - and this is what decides which of the three shipped Send actions the row becomes.
	_send_to = OptionButton.new()
	_send_to.clip_text = true
	for choice: Dictionary in EventSheetMessageFacts.send_choices():
		_send_to.add_item(str(choice.get("label", "")))
		_send_to.set_item_metadata(_send_to.item_count - 1, str(choice.get("value", "")))
	_send_to.item_selected.connect(func(_index: int) -> void: _refresh_send_reading())
	form.add_child(EventSheetPopupUI.form_row(EventSheetMessageFacts.FIELD_TO, _send_to))
	_send_peer = LineEdit.new()
	_send_peer.placeholder_text = "1"
	_send_peer.text_changed.connect(func(_text: String) -> void: _refresh_send_reading())
	_send_peer_row = EventSheetPopupUI.form_row(EventSheetMessageFacts.FIELD_PLAYER, _send_peer)
	form.add_child(_send_peer_row)
	form.add_child(_send_strip)
	for followed: Array in [
		[_send_message, EventSheetMessageFacts.FIELD_MESSAGE],
		[_send_peer, EventSheetMessageFacts.FIELD_PLAYER],
	]:
		_send_strip.follow(followed[0] as Control, str(followed[1]),
			EventSheetMessageFacts.field_help(str(followed[1])))
	_send_strip.follow_option(_send_to, func(index: int) -> Dictionary:
		var listed: Array[Dictionary] = EventSheetMessageFacts.send_choices()
		if index < 0 or index >= listed.size():
			return {}
		return {
			"heading": "%s - %s" % [EventSheetMessageFacts.FIELD_TO, str(listed[index].get("label", ""))],
			"body": str(listed[index].get("description", ""))
		})


## The per-parameter value fields for whichever message is named now. `seed_args` is the row's
## existing comma-separated values, split back out into the fields they came from. `keep_typed` is
## what tells retyping the message name (which rebuilds the fields) apart from opening the dialog on
## another row: the first keeps what was filled in, the second must not inherit it.
func _rebuild_send_args(seed_args: String, keep_typed: bool) -> void:
	var seeded: PackedStringArray = _kept_send_args(seed_args, keep_typed)
	for child: Node in _send_args_box.get_children():
		_send_args_box.remove_child(child)
		child.queue_free()
	_send_arg_edits.clear()
	var names: PackedStringArray = message_parameters(_sheet(), _send_message.text)
	# A message the sheet does not know keeps the one free-text field the row always had.
	if names.is_empty():
		names = PackedStringArray([EventSheetMessageFacts.FIELD_VALUES])
	for index: int in names.size():
		var edit: LineEdit = LineEdit.new()
		edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		edit.text = seeded[index] if index < seeded.size() else ""
		edit.text_changed.connect(func(_text: String) -> void: _refresh_send_reading())
		_send_arg_edits.append(edit)
		_send_args_box.add_child(EventSheetPopupUI.form_row(names[index], edit))
		_send_strip.follow(edit, names[index],
			EventSheetMessageFacts.field_help(EventSheetMessageFacts.FIELD_VALUES))


## The values to seed the rebuilt fields with: the ones passed in, else the ones already typed when
## the caller asked to keep them, else nothing.
func _kept_send_args(seed_args: String, keep_typed: bool) -> PackedStringArray:
	if not seed_args.strip_edges().is_empty():
		return EventSheetSentence.split_top_level(seed_args, ",")
	var typed: PackedStringArray = PackedStringArray()
	if not keep_typed:
		return typed
	for edit: LineEdit in _send_arg_edits:
		typed.append(edit.text.strip_edges())
	return typed


## The comma-separated `args` value the three templates take.
func _send_args() -> String:
	var values: PackedStringArray = PackedStringArray()
	for edit: LineEdit in _send_arg_edits:
		var text: String = edit.text.strip_edges()
		if not text.is_empty():
			values.append(text)
	return ", ".join(values)


## The strip's two lines plus the one warning worth catching at keystroke time: the row this dialog
## is about to write, the line it writes, and whether the named function is a message at all.
func _refresh_send_reading() -> void:
	if _send_strip == null:
		return
	var ace_id: String = EventSheetMessageFacts.send_ace_id(_send_to.selected)
	_send_peer_row.visible = ace_id == EventSheetMessageFacts.SEND_TO_PEER
	var message: String = _send_message.text.strip_edges()
	var args: String = _send_args()
	var peer: String = _send_peer.text.strip_edges()
	_send_strip.set_reading(
		send_reading(ace_id, message, args, peer),
		EventSheetMessageFacts.send_code_line(ace_id, message, args, peer))
	var warning: String = unmarked_message_note(_sheet(), message)
	if warning.is_empty():
		# Back to the ordinary voice: an amber rule left standing over a message that IS marked would
		# accuse a row that is now fine.
		_send_strip.set_tone(EventSheetPopupUI.HelpStrip.TONE_NORMAL)
		return
	_send_strip.show_note(EventSheetMessageFacts.FIELD_MESSAGE, warning,
		EventSheetPopupUI.HelpStrip.TONE_WARNING)


## Hands the chosen id and its params to the dock, which applies them through the ordinary ACE path.
func _apply_send() -> void:
	var message: String = _send_message.text.strip_edges()
	if message.is_empty():
		_dock._set_status("A Send row needs the message to send.", true)
		return
	var ace_id: String = EventSheetMessageFacts.send_ace_id(_send_to.selected)
	send_confirmed.emit(ace_id, EventSheetMessageFacts.send_params(
		ace_id, message, _send_args(), _send_peer.text.strip_edges()), _send_context)
