@tool
class_name EventSheetCompletionPopup
extends RefCounted

# THE completion popup - one component, one keyboard model, everywhere a field completes.
#
# Before this there were three habits in the plugin: a code box with the engine's own completion, a
# ▾ button whose menu you had to click, and - in the sheet itself - a bare text field with nothing.
# Typing in the row was therefore blinder than typing in the dialog showing the same parameter, and
# a reader who learned one gesture could not use it in the next field along.
#
# The model is Godot's own, deliberately: Tab and Enter accept the highlighted entry, Escape closes
# and KEEPS what was typed, Up and Down move. A reader who already writes GDScript in this editor
# knows it before they meet it, and one who does not learns it once.
#
# WHAT IT RIDES. Any LineEdit. Attach it with a field kind and it asks the completion seam
# (EventSheetCompletions) on every keystroke - the seam holds a built list per kind and only
# filters, so this never scans anything. Attach it with a list of your own and it shows that.
#
# WHERE THE WINDOW IS OPTIONAL. Everything that decides behaviour - what the entries are, which one
# is highlighted, what the field becomes when it is accepted - is a plain method on this object,
# testable with no display server at all. The Window is drawn when there is one to draw into, and
# skipped when there is not.


## What a keypress means. The one keyboard model, written down once.
const ACT_ACCEPT := "accept"
const ACT_CANCEL := "cancel"
const ACT_UP := "up"
const ACT_DOWN := "down"
const ACT_NONE := ""

## Rows the list shows before it scrolls, and how wide it opens. The list is scrollable, so these
## are about the shape of a popup over a form rather than about how many answers there are.
const VISIBLE_ROWS: int = 8
const ROW_HEIGHT: int = 22
const MIN_WIDTH: int = 320

## The mark a completing field wears, holding the popup that rides it. On the FIELD rather than in a
## list here, because the field is what another handler on the same keys already has in hand.
const FIELD_META := "eventsheet_completion_popup"

## The field this rides, and how it asks for entries.
var field: LineEdit = null
var _entries_provider: Callable = Callable()
## True when accepting replaces only the word under the caret (an expression box), false when it
## replaces the whole field (a name, a file, a class - one value, wholly chosen).
var replaces_word: bool = false

## What is on offer right now, and which of them is highlighted.
var entries: Array[Dictionary] = []
var index: int = 0

var _window: PopupPanel = null
var _list: ItemList = null
## True while an accepted entry is being written into the field. The write announces itself as a
## change (a dialog watching the field has to hear it), and this is what stops that announcement
## from re-opening the popup on the value it has just finished choosing.
var _accepting: bool = false


## Rides `line_edit` with the completions for one field kind - the seam answers, so a pack's own
## parameter hint completes without this file knowing about it. `sheet_provider` returns the sheet
## in context (the dock's current sheet, usually); it is asked per keystroke because the sheet the
## funnel hands back after an edit is a different object from the one before it.
static func attach(line_edit: LineEdit, field_kind: String, sheet_provider: Callable) -> EventSheetCompletionPopup:
	var popup: EventSheetCompletionPopup = attach_entries(line_edit,
		func(typed: String) -> Array[Dictionary]:
			var sheet: EventSheetResource = null
			if sheet_provider.is_valid():
				sheet = sheet_provider.call() as EventSheetResource
			return EventSheetCompletions.for_field(sheet, field_kind, typed))
	popup.replaces_word = field_kind.get_slice(":", 0) == EventSheetCompletions.FIELD_EXPRESSION
	return popup


## The same popup over a list the caller owns - a descriptor's own `autocomplete` suggestions, a
## pack's live list. `entries_provider` takes what is typed and returns entries (or plain Strings).
static func attach_entries(line_edit: LineEdit, entries_provider: Callable) -> EventSheetCompletionPopup:
	var popup: EventSheetCompletionPopup = EventSheetCompletionPopup.new()
	popup.field = line_edit
	popup._entries_provider = entries_provider
	if line_edit == null:
		return popup
	# The field says it completes, so anything else wired to the same keys stands aside - the ▾
	# combo's own Down-arrow opener would otherwise pop its menu on the same press that moves this
	# highlight. The mark is on the field rather than in a list here, because the field is what the
	# other handler already has.
	line_edit.set_meta(FIELD_META, popup)
	line_edit.text_changed.connect(func(typed: String) -> void: popup.refresh(typed))
	line_edit.gui_input.connect(popup._on_field_input)
	line_edit.focus_exited.connect(popup.close)
	return popup


## True when this field already completes. The question every OTHER keyboard handler on the same
## field asks before claiming Up, Down, Tab or Escape.
static func rides(line_edit: LineEdit) -> bool:
	return line_edit != null and line_edit.has_meta(FIELD_META)


## Re-asks for entries and shows (or hides) the popup. The only thing a keystroke costs: the seam
## holds each kind's list and filters it, so nothing is scanned here.
func refresh(typed: String) -> void:
	if _accepting:
		return
	entries = _ask(typed)
	index = 0
	if entries.is_empty():
		close()
		return
	_show()


## Moves the highlight, wrapping at both ends so Up from the first entry reaches the last.
func move(delta: int) -> void:
	if entries.is_empty():
		return
	index = wrapi(index + delta, 0, entries.size())
	if _list != null and index < _list.item_count:
		_list.select(index)
		_list.ensure_current_is_visible()


## What the field becomes when the highlighted entry is accepted. An expression field keeps
## everything the reader wrote and swaps only the word under the caret; every other field is one
## value, so the entry replaces it whole.
func accepted_text(current: String) -> String:
	if entries.is_empty():
		return current
	var insert: String = str(entries[index].get("text", ""))
	if not replaces_word:
		return insert
	var word: String = EventSheetCompletions.trailing_word(current)
	return current.substr(0, current.length() - word.length()) + insert


## Accepts the highlight into the field, leaving the caret at the end of what it inserted. Returns
## false when there was nothing to accept, so a caller can let the key do its ordinary job.
func accept() -> bool:
	if field == null or entries.is_empty():
		return false
	var accepted: String = accepted_text(field.text)
	close()
	_accepting = true
	field.text = accepted
	field.caret_column = accepted.length()
	# Setting `text` from code does not announce itself, and a dialog watching this field for its
	# live preview would go on showing what was there before the completion landed. So the write
	# says so, exactly as typing the same characters would have.
	field.text_changed.emit(accepted)
	_accepting = false
	return true


## Closes the popup and leaves the field exactly as it is - which is what Escape means here.
func close() -> void:
	entries = []
	if _window != null and _window.visible:
		_window.hide()


## What one keypress means, apart from any widget. Tab and Enter accept, Escape cancels, Up and
## Down move, everything else is ordinary typing.
static func key_action(event: InputEvent) -> String:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed:
		return ACT_NONE
	match key.keycode:
		KEY_TAB, KEY_ENTER, KEY_KP_ENTER:
			return ACT_ACCEPT
		KEY_ESCAPE:
			return ACT_CANCEL
		KEY_UP:
			return ACT_UP
		KEY_DOWN:
			return ACT_DOWN
	return ACT_NONE


## The keypress, applied. Every key it acts on is swallowed, so Enter does not also confirm the
## dialog behind the popup and Tab does not also leave the field - both of which would be the
## reader's keystroke doing two things at once.
func _on_field_input(event: InputEvent) -> void:
	if entries.is_empty() or field == null:
		return
	match key_action(event):
		ACT_ACCEPT:
			if accept():
				field.accept_event()
		ACT_CANCEL:
			close()
			field.accept_event()
		ACT_UP:
			move(-1)
			field.accept_event()
		ACT_DOWN:
			move(1)
			field.accept_event()


## The provider's answer, as entries. A provider handing back plain Strings is answering the
## simplest case (a fixed list of values) and is not made to write out a Dictionary to do it.
func _ask(typed: String) -> Array[Dictionary]:
	var asked: Array[Dictionary] = []
	if not _entries_provider.is_valid():
		return asked
	var raw: Variant = _entries_provider.call(typed)
	if not (raw is Array):
		return asked
	for item: Variant in (raw as Array):
		if item is Dictionary:
			asked.append(item as Dictionary)
		elif item is String:
			asked.append({"text": str(item), "detail": "", "kind": ""})
	return asked


## What one entry reads as in the list: the value, then the line that explains it.
static func item_text(entry: Dictionary) -> String:
	var detail: String = str(entry.get("detail", "")).strip_edges()
	var text: String = str(entry.get("text", ""))
	return text if detail.is_empty() else "%s    %s" % [text, detail]


## Builds the window on first use and fills it. Skipped wholly when there is no tree or no display
## server to open one in - the model above is what a test drives, and it has already run.
func _show() -> void:
	if field == null or not field.is_inside_tree() or DisplayServer.get_name() == "headless":
		return
	if _window == null:
		_build_window()
	_list.clear()
	for entry: Dictionary in entries:
		# An entry may carry the editor's own icon for what it names (a class, a file kind); one
		# that does not is drawn as text, which is every entry the seam itself builds.
		_list.add_item(item_text(entry), entry.get("icon") as Texture2D)
	_list.select(index)
	var size: Vector2i = Vector2i(maxi(MIN_WIDTH, int(field.size.x)),
		mini(entries.size(), VISIBLE_ROWS) * ROW_HEIGHT + 28)
	_window.popup(Rect2i(Vector2i(field.get_screen_position() + Vector2(0.0, field.size.y)), size))
	field.grab_focus()


func _build_window() -> void:
	_window = PopupPanel.new()
	# No focus of its own: the reader is typing in the field, and a popup that took the keyboard
	# would end the sentence it is there to help finish.
	_window.set_flag(Window.FLAG_NO_FOCUS, true)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.allow_reselect = true
	_list.focus_mode = Control.FOCUS_NONE
	_list.item_clicked.connect(func(clicked: int, _at: Vector2, _button: int) -> void:
		index = clicked
		accept())
	column.add_child(_list)
	# The model, said under the list it applies to - the one line a reader needs to learn once.
	# Built here rather than through the shared hint label: the dialog toolkit reaches back to this
	# popup to stand its own Down-arrow aside, and two files naming each other is a knot worth not
	# tying for three lines of Label.
	var keys: Label = Label.new()
	keys.text = EventSheetL10n.translate("Tab or Enter accepts, Escape keeps what you typed")
	keys.modulate = Color(1.0, 1.0, 1.0, 0.65)
	keys.add_theme_font_size_override("font_size", EventSheetPalette.scaled(10))
	column.add_child(keys)
	_window.add_child(column)
	field.add_child(_window)
