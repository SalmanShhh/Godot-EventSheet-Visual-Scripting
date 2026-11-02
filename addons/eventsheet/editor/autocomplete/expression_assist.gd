@tool
class_name EventSheetExpressionAssist
extends RefCounted

# Everything an expression field does to help the person writing in it, in one place - so the
# parameters dialog's box and the sheet's inline value editor cannot drift apart.
#
# - the completion list (EventSheetCompletionPopup) asked with the text before the caret, opening on
#   the first letter, on a dot, on a quote, and on Ctrl+Space;
# - the signature hint above the field: the call the caret is inside, its arguments, the one under
#   the caret marked;
# - the note that says "worked out while the game runs" where a step has no type to read.
#
# It rides a LineEdit or a CodeEdit and owns nothing about the dialog around it: the caller gives it
# the sheet (and the event the field belongs to) as providers, because the sheet the undo funnel hands
# back after an edit is a different object from the one before it.

const ClassReference := preload("res://addons/eventsheet/ace/class_reference.gd")

var popup: EventSheetCompletionPopup = null
## The strip above the field that shows the signature hint; the caller places it.
var hint_box: PanelContainer = null
var _hint: RichTextLabel = null
var _field: Control = null
var _sheet_provider: Callable = Callable()
var _within_provider: Callable = Callable()
var _kind: String = EventSheetCompletions.FIELD_EXPRESSION


## Rides `field`. `extras_provider` (optional) returns entries offered beside the sheet's own names in
## plain-name position - the expression dictionary's words, for the dialog.
static func attach(field: Control, sheet_provider: Callable, within_provider: Callable = Callable(), extras_provider: Callable = Callable()) -> EventSheetExpressionAssist:
	var assist: EventSheetExpressionAssist = EventSheetExpressionAssist.new()
	assist._field = field
	assist._sheet_provider = sheet_provider
	assist._within_provider = within_provider
	assist.popup = EventSheetCompletionPopup.attach_entries(field,
		func(typed: String) -> Array[Dictionary]:
			if assist._kind != EventSheetCompletions.FIELD_EXPRESSION:
				return EventSheetCompletions.for_field(assist.sheet(), assist._kind, typed)
			var answer: Dictionary = EventSheetCompletions.expression_answer(assist.sheet(), typed, assist.within())
			var pool: Array[Dictionary] = answer["entries"]
			if bool(answer.get("flat", false)) and extras_provider.is_valid():
				pool = pool.duplicate()
				pool.append_array(extras_provider.call())
			return EventSheetCompletions.rank(pool, str(answer["needle"])))
	assist.popup.replaces_word = true
	assist.popup.note_provider = func(typed: String) -> String:
		return EventSheetCompletions.empty_note(assist.sheet(), typed, assist.within())
	assist._build_hint()
	if field is LineEdit:
		(field as LineEdit).text_changed.connect(func(_text: String) -> void: assist.update_hint())
	elif field is TextEdit:
		(field as TextEdit).text_changed.connect(assist.update_hint)
	field.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventKey and (event as InputEventKey).pressed:
			assist.update_hint.call_deferred())
	field.focus_exited.connect(func() -> void: assist.hint_box.visible = false)
	# The reference for built-in value types is built once in the background, the first time any
	# expression field is used; until it exists the lists just lack those types.
	ClassReference.request_build()
	return assist


## Tells the assist what kind of field it rides now. A field that holds one parameter for good (the
## dialog's expression box) never calls this; the sheet's inline value editor, which serves every
## parameter in turn, calls it on each open. Anything but an expression completes as one whole value and
## shows no hint.
func set_kind(kind: String) -> void:
	_kind = kind
	popup.replaces_word = kind == EventSheetCompletions.FIELD_EXPRESSION
	popup.close()
	if hint_box != null:
		hint_box.visible = false


func sheet() -> EventSheetResource:
	return _sheet_provider.call() as EventSheetResource if _sheet_provider.is_valid() else null


func within() -> Resource:
	return _within_provider.call() as Resource if _within_provider.is_valid() else null


func _build_hint() -> void:
	hint_box = PanelContainer.new()
	hint_box.visible = false
	hint_box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(1.0, 1.0, 1.0, 0.07)
	style.border_color = Color(1.0, 1.0, 1.0, 0.2)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 7.0
	style.content_margin_right = 7.0
	style.content_margin_top = 2.0
	style.content_margin_bottom = 2.0
	hint_box.add_theme_stylebox_override("panel", style)
	_hint = RichTextLabel.new()
	_hint.bbcode_enabled = true
	_hint.fit_content = true
	_hint.scroll_active = false
	_hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mono: Font = _field.get_theme_font("font", "CodeEdit") if _field != null else null
	if mono != null:
		_hint.add_theme_font_override("normal_font", mono)
		_hint.add_theme_font_override("bold_font", mono)
	_hint.add_theme_font_size_override("normal_font_size", EventSheetPalette.scaled(11))
	_hint.add_theme_font_size_override("bold_font_size", EventSheetPalette.scaled(11))
	hint_box.add_child(_hint)


## Re-reads the call the caret is in and shows (or hides) its signature.
func update_hint() -> void:
	if hint_box == null or _field == null or not is_instance_valid(_field):
		return
	if _kind != EventSheetCompletions.FIELD_EXPRESSION:
		hint_box.visible = false
		return
	var shown: Dictionary = EventSheetExpressionWalk.hint(popup._text().substr(0, popup._caret()), sheet(),
		EventSheetCompletions.scope_types(sheet(), within()))
	hint_box.visible = not shown.is_empty()
	if not shown.is_empty():
		_hint.text = EventSheetExpressionWalk.hint_bbcode(shown)


## The hint as plain text, "" when there is none - what a test pins.
func hint_text() -> String:
	return str(EventSheetExpressionWalk.hint(popup._text().substr(0, popup._caret()), sheet(),
		EventSheetCompletions.scope_types(sheet(), within())).get("text", ""))
