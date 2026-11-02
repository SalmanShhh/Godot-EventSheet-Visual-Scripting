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
# WHAT IT RIDES. A LineEdit or a CodeEdit. Attach it with a field kind and it asks the completion
# seam (EventSheetCompletions) on every keystroke - the seam holds a built list per kind and only
# filters, so this never scans anything. Attach it with a list of your own and it shows that.
#
# WHAT A ROW SHOWS. An icon for what the entry is, its name, and its type on the right in Godot's
# spelling; the highlighted entry's one line of explanation sits under the list. An entry carries
# {text, detail, kind} and may add {label, type, desc}: `label` is what the row shows when it differs
# from what is inserted (`limit_length(length)` shows, `limit_length()` is written), `type` the right
# column, `desc` the line under the list. An entry with only a detail shows the detail under the list.
#
# WHERE THE WINDOW IS OPTIONAL. Everything that decides behaviour - what the entries are, which one
# is highlighted, what the field becomes when it is accepted - is a plain method on this object,
# testable with no display server at all. The Window is drawn when there is one to draw into, and
# skipped when there is not.


const ReadingDoors := preload("res://addons/eventsheet/editor/interaction/reading_doors.gd")

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
const MIN_WIDTH: int = 360

## The mark a completing field wears, holding the popup that rides it. On the FIELD rather than in a
## list here, because the field is what another handler on the same keys already has in hand.
const FIELD_META := "eventsheet_completion_popup"

## The field this rides, and how it asks for entries.
var field: Control = null
var _entries_provider: Callable = Callable()
## True when accepting replaces only the word under the caret (an expression box), false when it
## replaces the whole field (a name, a file, a class - one value, wholly chosen).
var replaces_word: bool = false
## Asked, when the list is empty, for the sentence that says why (an expression whose step cannot be
## typed). Takes the text before the caret and returns "" for nothing to say.
var note_provider: Callable = Callable()

## What is on offer right now, and which of them is highlighted.
var entries: Array[Dictionary] = []
var index: int = 0
## The sentence the window shows instead of a list, while there is one.
var note: String = ""

var _window: Window = null
var _tree: Tree = null
var _description: Label = null
var _keys: Label = null
var _note_label: Label = null
## The dialog the field sits in, while the list holds its Escape, and what its own Escape setting was.
## A dialog takes Escape before any field inside it sees the key, so with the list open Escape would
## close the whole dialog instead of the list; the dialog's Escape is held while the list is shown
## and handed back when it closes.
var _held_dialog: AcceptDialog = null
var _dialog_escape_was: bool = true
## True while an accepted entry is being written into the field. The write announces itself as a
## change (a dialog watching the field has to hear it), and this is what stops that announcement
## from re-opening the popup on the value it has just finished choosing.
var _accepting: bool = false


## Rides `line_edit` with the completions for one field kind - the seam answers, so a pack's own
## parameter hint completes without this file knowing about it. `sheet_provider` returns the sheet
## in context (the dock's current sheet, usually); it is asked per keystroke because the sheet the
## funnel hands back after an edit is a different object from the one before it.
static func attach(line_edit: Control, field_kind: String, sheet_provider: Callable, within_provider: Callable = Callable()) -> EventSheetCompletionPopup:
	# A field that completes towards a folder the GAME writes to is asked here, at the moment it
	# starts completing - once per dialog, never once per keystroke. Nothing in the editor watches
	# `user://`, so a list held for the session would keep answering with the folder as it was two
	# test runs ago.
	EventSheetCompletions.forget_live_folders(field_kind)
	var popup: EventSheetCompletionPopup = attach_entries(line_edit,
		func(typed: String) -> Array[Dictionary]:
			var sheet: EventSheetResource = null
			if sheet_provider.is_valid():
				sheet = sheet_provider.call() as EventSheetResource
			var within: Resource = null
			if within_provider.is_valid():
				within = within_provider.call() as Resource
			return EventSheetCompletions.for_field(sheet, field_kind, typed, within))
	popup.replaces_word = field_kind.get_slice(":", 0) == EventSheetCompletions.FIELD_EXPRESSION
	if popup.replaces_word:
		popup.note_provider = func(typed: String) -> String:
			var sheet: EventSheetResource = sheet_provider.call() as EventSheetResource if sheet_provider.is_valid() else null
			var within: Resource = within_provider.call() as Resource if within_provider.is_valid() else null
			return EventSheetCompletions.empty_note(sheet, typed, within)
	return popup


## The same popup over a list the caller owns - a descriptor's own `autocomplete` suggestions, a
## pack's live list. `entries_provider` takes what is typed and returns entries (or plain Strings).
static func attach_entries(line_edit: Control, entries_provider: Callable) -> EventSheetCompletionPopup:
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
	if line_edit is LineEdit:
		(line_edit as LineEdit).text_changed.connect(func(typed: String) -> void: popup.refresh(typed))
	elif line_edit is TextEdit:
		(line_edit as TextEdit).text_changed.connect(func() -> void: popup.refresh(popup._text()))
	line_edit.gui_input.connect(popup._on_field_input)
	line_edit.focus_exited.connect(popup.close)
	return popup


## True when this field already completes. The question every OTHER keyboard handler on the same
## field asks before claiming Up, Down, Tab or Escape.
static func rides(line_edit: Control) -> bool:
	return line_edit != null and line_edit.has_meta(FIELD_META)


# ── The field, whichever kind it is ──────────────────────────────────────────────────────


func _text() -> String:
	if field is LineEdit:
		return (field as LineEdit).text
	if field is TextEdit:
		return (field as TextEdit).text
	return ""


## Where the caret is, as an index into the field's text.
func _caret() -> int:
	if field is LineEdit:
		return (field as LineEdit).caret_column
	if field is TextEdit:
		var edit: TextEdit = field as TextEdit
		var before: int = 0
		for line: int in range(edit.get_caret_line()):
			before += edit.get_line(line).length() + 1
		return before + edit.get_caret_column()
	return 0


func _write(text: String, caret: int) -> void:
	if field is LineEdit:
		(field as LineEdit).text = text
		(field as LineEdit).caret_column = caret
		(field as LineEdit).text_changed.emit(text)
	elif field is TextEdit:
		var edit: TextEdit = field as TextEdit
		edit.text = text
		edit.set_caret_line(0)
		edit.set_caret_column(caret)
		edit.text_changed.emit()


# ── Asking ───────────────────────────────────────────────────────────────────────────────


## Re-asks for entries and shows (or hides) the popup. The only thing a keystroke costs: the seam
## holds each kind's list and filters it, so nothing is scanned here.
##
## An expression is asked with the text BEFORE THE CARET, not the whole field: `hp.` and `hp` want
## different answers, and a caret in the middle of a long expression is asking about the word it sits
## in, not about the end of the line.
func refresh(typed: String, forced: bool = false) -> void:
	if _accepting:
		return
	var asked: String = typed
	if replaces_word and field != null:
		asked = _text().substr(0, _caret())
		if not forced and not wants_list(asked):
			close()
			return
	entries = _ask(asked)
	index = _first_choosable()
	note = ""
	if entries.is_empty() or index < 0:
		if replaces_word and note_provider.is_valid():
			note = str(note_provider.call(asked))
		if note.is_empty():
			close()
			return
		entries = []
		_show_note()
		return
	_show()


## Opens the list for the word at the caret now - Ctrl+Space, however little is typed.
func open_now() -> void:
	refresh(_text(), true)


## True when the text before the caret is somewhere a name is being written: a word has been started,
## or a dot, a node sigil or an open quote just asked for one. A caret after a space, an operator or an
## opening bracket is not, and a list there would only be in the way of the next key.
static func wants_list(text_before_caret: String) -> bool:
	if text_before_caret.is_empty():
		return false
	if not EventSheetCompletions.trailing_word(text_before_caret).is_empty():
		return true
	var head: String = text_before_caret
	if head.ends_with(".") or not EventSheetCompletions.node_sigil(head).is_empty():
		return true
	return not EventSheetExpressionWalk.string_context(head).is_empty()


## True when this entry is a HEADING - a line that says what the entries under it are, and is not
## one of them. A list long enough to need grouping needs the group said somewhere, and a heading
## that could be chosen would be a door to nothing.
static func is_heading(entry: Dictionary) -> bool:
	return bool(entry.get("heading", false))


## The first entry a reader can actually choose, or -1 when there is none. A list that is all
## headings is a list with nothing in it.
func _first_choosable() -> int:
	for at: int in range(entries.size()):
		if not is_heading(entries[at]):
			return at
	return -1


## Moves the highlight, wrapping at both ends so Up from the first entry reaches the last, and
## stepping OVER headings in whichever direction it is travelling.
func move(delta: int) -> void:
	if entries.is_empty() or delta == 0:
		return
	var step: int = 1 if delta > 0 else -1
	var at: int = index
	for _attempt: int in range(entries.size()):
		at = wrapi(at + step, 0, entries.size())
		if not is_heading(entries[at]):
			index = at
			break
	_select_row()


## What the field becomes when the highlighted entry is accepted. An expression field keeps
## everything the reader wrote and swaps only the word under the caret; every other field is one
## value, so the entry replaces it whole.
##
## `caret` is where the caret is (-1 for the end): what follows it is kept, and inside a string literal
## the whole of what is typed after the opening quote is the word, since a path is not one identifier.
func accepted_text(current: String, caret: int = -1) -> String:
	if entries.is_empty():
		return current
	var insert: String = str(entries[index].get("text", ""))
	if not replaces_word:
		return insert
	var at: int = current.length() if caret < 0 else clampi(caret, 0, current.length())
	var before: String = current.substr(0, at)
	var span: int = replace_length(before)
	return current.substr(0, at - span) + insert + current.substr(at)


## How many characters before the caret an accepted entry replaces: the word being typed, or - inside
## a string literal - everything typed since the quote.
static func replace_length(text_before_caret: String) -> int:
	var quoted: Dictionary = EventSheetExpressionWalk.string_context(text_before_caret)
	if not quoted.is_empty():
		return str(quoted["text"]).length()
	return EventSheetCompletions.trailing_word(text_before_caret).length()


## Accepts the highlight into the field, leaving the caret at the end of what it inserted. Returns
## false when there was nothing to accept, so a caller can let the key do its ordinary job.
##
## An entry may carry an `open` Callable instead of being text to insert, and then accepting it RUNS
## that rather than writing anything into the field. It is the same list, the same highlight and the
## same Enter: a field that answers as well as completes needs one keyboard model, not two.
func accept() -> bool:
	if field == null or entries.is_empty() or index < 0 or index >= entries.size():
		return false
	if is_heading(entries[index]):
		return false
	var door: Variant = entries[index].get("open")
	if door is Callable and (door as Callable).is_valid():
		close()
		(door as Callable).call()
		return true
	var caret_at: int = _caret() if replaces_word else -1
	var current: String = _text()
	var accepted: String = accepted_text(current, caret_at)
	# Where the caret lands: right after what was written, or - for a call with arguments - between its
	# parentheses, ready for the first one.
	var landing: int = accepted.length() - (current.length() - (current.length() if caret_at < 0 else caret_at))
	landing -= int(entries[index].get("caret_back", 0))
	close()
	_accepting = true
	_write(accepted, landing)
	_accepting = false
	return true


## Closes the popup and leaves the field exactly as it is - which is what Escape means here.
func close() -> void:
	entries = []
	note = ""
	if _window != null and _window.visible:
		_window.hide()
	release_dialog_escape()


## While the list is open, Escape closes the list and not the dialog around the field.
func hold_dialog_escape(dialog: AcceptDialog) -> void:
	if dialog == null or _held_dialog != null:
		return
	_held_dialog = dialog
	_dialog_escape_was = dialog.dialog_close_on_escape
	dialog.dialog_close_on_escape = false


## Hands the dialog its own Escape back. Safe to call when nothing is held.
func release_dialog_escape() -> void:
	if _held_dialog != null and is_instance_valid(_held_dialog):
		_held_dialog.dialog_close_on_escape = _dialog_escape_was
	_held_dialog = null


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


## True for Ctrl+Space, Godot's own key for "complete here".
static func is_open_key(event: InputEvent) -> bool:
	var key: InputEventKey = event as InputEventKey
	return key != null and key.pressed and key.keycode == KEY_SPACE and (key.ctrl_pressed or key.meta_pressed)


## The keypress, applied. Every key it acts on is swallowed, so Enter does not also confirm the
## dialog behind the popup and Tab does not also leave the field - both of which would be the
## reader's keystroke doing two things at once.
func _on_field_input(event: InputEvent) -> void:
	if field == null:
		return
	if replaces_word and is_open_key(event):
		open_now()
		field.accept_event()
		return
	if entries.is_empty():
		# A note has no entries to move through; Escape still dismisses it.
		if not note.is_empty() and key_action(event) == ACT_CANCEL:
			close()
			field.accept_event()
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


## What one entry reads as in a plain list: the value, then the line that explains it.
static func item_text(entry: Dictionary) -> String:
	var detail: String = str(entry.get("detail", "")).strip_edges()
	var text: String = str(entry.get("text", ""))
	return text if detail.is_empty() else "%s    %s" % [text, detail]


## What a row shows as its name: the label where an entry has one, else what it inserts.
static func row_name(entry: Dictionary) -> String:
	return str(entry.get("label", entry.get("text", "")))


## The right column of a row: the type where an entry names one. An entry that only has a detail
## shows it under the list, not in the row, so the list stays short.
static func row_type(entry: Dictionary) -> String:
	return str(entry.get("type", ""))


## The line under the list for one entry: what it is, in one sentence.
static func description_of(entry: Dictionary) -> String:
	if entry.has("desc"):
		return str(entry["desc"])
	if entry.has("owner") and entry.has("member_kind"):
		return EventSheetMemberCatalog.describe(entry)
	return str(entry.get("detail", ""))


# ── Drawing ──────────────────────────────────────────────────────────────────────────────


## The editor's icon for a kind of entry, null where the editor has none (or there is no editor).
func _kind_icon(kind: String) -> Texture2D:
	var icon_name: String = str(KIND_ICONS.get(kind, ""))
	if icon_name.is_empty() or field == null or not field.has_theme_icon(icon_name, "EditorIcons"):
		return null
	return field.get_theme_icon(icon_name, "EditorIcons")


## Which editor icon each kind of entry wears - Godot's own member badges where it has them.
const KIND_ICONS: Dictionary = {
	"variable": "MemberProperty", "local": "Variable", "function": "MemberMethod", "property": "MemberProperty",
	"method": "MemberMethod", "member": "MemberProperty", "signal": "MemberSignal", "constant": "MemberConstant",
	"enum": "MemberConstant", "builtin": "MemberMethod", "action": "InputEventAction", "animation": "Animation",
	"group": "Groups", "file": "File", "class": "Object", "node": "Node",
}

## The colour of each kind's badge on a dark and a light editor: the family each kind belongs to,
## kept apart so the list can be scanned by colour as well as by icon.
const KIND_COLORS_DARK: Dictionary = {
	"variable": Color("E8A0C8"), "local": Color("F2B8D6"), "function": Color("8DA5F3"), "property": Color("7FD6C2"),
	"method": Color("A9BDF7"), "member": Color("7FD6C2"), "signal": Color("E8C27A"), "constant": Color("C8A0F0"),
	"enum": Color("C8A0F0"), "builtin": Color("A9BDF7"), "action": Color("E8C27A"), "animation": Color("8EEF97"),
	"group": Color("F0A878"), "file": Color("C8C8C8"), "class": Color("8DA5F3"), "node": Color("8DA5F3"),
}
const KIND_COLORS_LIGHT: Dictionary = {
	"variable": Color("8A1F5C"), "local": Color("A3306E"), "function": Color("2F4FB0"), "property": Color("0F6B5A"),
	"method": Color("2A4596"), "member": Color("0F6B5A"), "signal": Color("7A4E00"), "constant": Color("5B2A8C"),
	"enum": Color("5B2A8C"), "builtin": Color("2A4596"), "action": Color("7A4E00"), "animation": Color("1F6B2A"),
	"group": Color("8A3B0A"), "file": Color("3F3F3F"), "class": Color("2F4FB0"), "node": Color("2F4FB0"),
}


func _is_dark() -> bool:
	if field == null:
		return true
	return field.get_theme_color("font_color", "Label").get_luminance() > 0.5


func _kind_color(kind: String) -> Color:
	var table: Dictionary = KIND_COLORS_DARK if _is_dark() else KIND_COLORS_LIGHT
	return table.get(kind, field.get_theme_color("font_color", "Label"))


## Builds the window on first use and fills it. Skipped wholly when there is no tree or no display
## server to open one in - the model above is what a test drives, and it has already run.
func _show() -> void:
	if not _can_draw():
		return
	if _window == null:
		_build_window()
	_note_label.visible = false
	_tree.visible = true
	_description.visible = true
	_tree.clear()
	var root: TreeItem = _tree.create_item()
	var muted: Color = field.get_theme_color("font_color", "Label")
	muted.a = 0.62
	for entry: Dictionary in entries:
		var row: TreeItem = _tree.create_item(root)
		row.set_text(0, row_name(entry))
		var kind: String = str(entry.get("kind", ""))
		var icon: Texture2D = entry.get("icon") as Texture2D
		if icon == null:
			icon = _kind_icon(kind)
			if icon != null:
				row.set_icon_modulate(0, _kind_color(kind))
		if icon != null:
			row.set_icon(0, icon)
		row.set_text(1, row_type(entry))
		row.set_text_alignment(1, HORIZONTAL_ALIGNMENT_RIGHT)
		row.set_custom_color(1, muted)
		row.set_text_overrun_behavior(1, TextServer.OVERRUN_TRIM_ELLIPSIS)
		# A heading is a place-marker in the list, not an entry of it: it cannot be selected, cannot
		# be clicked, and the highlight steps over it.
		if is_heading(entry):
			row.set_selectable(0, false)
			row.set_selectable(1, false)
	_select_row()
	var width: int = maxi(MIN_WIDTH, mini(int(field.size.x), 640))
	var list_height: int = mini(entries.size(), VISIBLE_ROWS) * ROW_HEIGHT + 8
	var size: Vector2i = Vector2i(width, list_height + 72)
	_tree.custom_minimum_size = Vector2(width - 16, list_height)
	_place(size)
	hold_dialog_escape(field.get_window() as AcceptDialog)
	field.grab_focus()


## Shows only the sentence, for a list with nothing to offer but a reason.
func _show_note() -> void:
	if not _can_draw():
		return
	if _window == null:
		_build_window()
	_tree.visible = false
	_description.visible = false
	_note_label.visible = true
	_note_label.text = note
	_keys.text = EventSheetL10n.translate("Escape closes")
	_place(Vector2i(maxi(MIN_WIDTH, 280), 56))
	hold_dialog_escape(field.get_window() as AcceptDialog)
	field.grab_focus()


func _can_draw() -> bool:
	return field != null and field.is_inside_tree() and DisplayServer.get_name() != "headless"


## Opens the window below the word being completed, not below the whole field: a long expression
## wraps, and the list belongs where the reader is looking.
func _place(size: Vector2i) -> void:
	var anchor: Rect2i = Rect2i(Vector2i(field.get_screen_position()), Vector2i(field.size))
	if replaces_word:
		var before: String = _text().substr(0, _caret())
		var word_start: int = before.length() - replace_length(before)
		if field is TextEdit:
			var edit: TextEdit = field as TextEdit
			var line_position: Vector2 = edit.get_caret_draw_pos()
			var column_x: float = line_position.x - _word_width(before.substr(word_start))
			anchor = Rect2i(Vector2i(edit.get_screen_position() + Vector2(maxf(column_x, 0.0), line_position.y - edit.get_line_height())), Vector2i(0, edit.get_line_height() + 4))
		elif field is LineEdit:
			var line: LineEdit = field as LineEdit
			var left: float = line.get_theme_stylebox("normal").get_content_margin(SIDE_LEFT)
			var x: float = left + _word_width(before.substr(0, word_start)) - float(line.get_scroll_offset())
			anchor = Rect2i(Vector2i(line.get_screen_position() + Vector2(clampf(x, 0.0, maxf(line.size.x - 40.0, 0.0)), 0.0)), Vector2i(0, int(line.size.y)))
	# Below the word, so the list reads as hanging from it; above it when there is no room below, never over it.
	EventSheetWindowPlacement.popup_below(_window, anchor, size)


func _word_width(text: String) -> float:
	var font: Font = field.get_theme_font("font", "LineEdit" if field is LineEdit else "CodeEdit")
	var font_size: int = field.get_theme_font_size("font_size", "LineEdit" if field is LineEdit else "CodeEdit")
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


## Moves the tree's highlight to `index` and writes its line under the list.
func _select_row() -> void:
	if _tree == null or _tree.get_root() == null or index < 0 or index >= entries.size():
		return
	var row: TreeItem = _tree.get_root().get_child(index)
	if row != null:
		row.select(0)
		_tree.scroll_to_item(row)
	var entry: Dictionary = entries[index]
	var said: String = description_of(entry)
	_description.text = said
	_description.visible = not said.is_empty()
	_keys.text = EventSheetL10n.translate("Tab or Enter accepts, Escape keeps what you typed")
	if not said.is_empty() and EventSheetMemberCatalog.is_engine_prose(entry):
		_keys.text += "  -  " + str(ReadingDoors.engine_reference().CREDIT_LINE)


## The window the list floats in: transient, borderless, never focused, and not a popup.
static func new_list_window() -> Window:
	var window: Window = Window.new()
	window.transient = true
	window.borderless = true
	window.unresizable = true
	window.wrap_controls = true
	# No focus of its own: the reader is typing in the field, and a list that took the keyboard would
	# end the sentence it is there to help finish.
	window.set_flag(Window.FLAG_NO_FOCUS, true)
	window.visible = false
	return window


func _build_window() -> void:
	# A plain transient Window, NOT a Popup. While a popup window is open the display server sends
	# every key to it rather than to the window that has keyboard focus, and this list holds no
	# focused control - so the moment it opened, Backspace and every letter after it were swallowed
	# and the field stopped taking typing. A window without the popup flag leaves the keyboard with the
	# dialog and the field the reader is typing in.
	_window = new_list_window()
	# The look a popup panel has in the editor theme, so it reads as the same kind of floating list.
	var backdrop: PanelContainer = PanelContainer.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel_style: StyleBox = field.get_theme_stylebox("panel", "PopupPanel")
	if panel_style != null:
		backdrop.add_theme_stylebox_override("panel", panel_style)
	_window.add_child(backdrop)
	# Not a popup, so a click elsewhere does not close it by itself: the field losing focus does, and
	# so does its window losing focus (the reader moved to another window altogether).
	if not field.get_window().focus_exited.is_connected(close):
		field.get_window().focus_exited.connect(close)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	_tree = Tree.new()
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.columns = 2
	_tree.hide_root = true
	_tree.column_titles_visible = false
	_tree.hide_folding = true
	_tree.select_mode = Tree.SELECT_ROW
	_tree.scroll_horizontal_enabled = false
	_tree.focus_mode = Control.FOCUS_NONE
	_tree.set_column_expand(0, true)
	_tree.set_column_expand(1, false)
	_tree.set_column_custom_minimum_width(1, 130)
	_tree.add_theme_constant_override("item_margin", 0)
	_tree.add_theme_constant_override("v_separation", 0)
	_tree.item_mouse_selected.connect(func(_at: Vector2, button: int) -> void:
		if button != MOUSE_BUTTON_LEFT or _tree.get_selected() == null:
			return
		index = _tree.get_selected().get_index()
		accept())
	column.add_child(_tree)
	# The one line that says what the highlighted entry is, under the list it belongs to.
	_description = Label.new()
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description.custom_minimum_size = Vector2(MIN_WIDTH - 24, 0.0)
	_description.modulate = Color(1.0, 1.0, 1.0, 0.78)
	_description.add_theme_font_size_override("font_size", EventSheetPalette.scaled(11))
	column.add_child(_description)
	_note_label = Label.new()
	_note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note_label.visible = false
	_note_label.modulate = Color(1.0, 1.0, 1.0, 0.78)
	column.add_child(_note_label)
	# The model, said under the list it applies to - the one line a reader needs to learn once.
	# Built here rather than through the shared hint label: the dialog toolkit reaches back to this
	# popup to stand its own Down-arrow aside, and two files naming each other is a knot worth not
	# tying for three lines of Label.
	_keys = Label.new()
	_keys.text = EventSheetL10n.translate("Tab or Enter accepts, Escape keeps what you typed")
	_keys.modulate = Color(1.0, 1.0, 1.0, 0.65)
	_keys.add_theme_font_size_override("font_size", EventSheetPalette.scaled(10))
	column.add_child(_keys)
	backdrop.add_child(column)
	field.add_child(_window)
