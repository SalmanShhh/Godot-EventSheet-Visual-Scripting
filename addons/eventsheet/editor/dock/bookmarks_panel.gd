# Godot EventSheets - the Bookmarks panel (dock subsystem)
#
# The event-sheet bookmarks bar: a toolbar (Previous / Next / Clear All) over a tree
# of every Ctrl+M'd row, grouped under a colored sheet header, each entry carrying its
# margin event number so "event 12" in the panel matches the number in the gutter.
# Clicking an entry jumps to (reveals + selects) the row; Previous/Next reuse the
# viewport's F4 / Shift+F4 cycling. The tree builds popup-free so tests pin it headless.
@tool
class_name EventSheetBookmarksPanel
extends RefCounted

# Section-header tint shared with the ACE picker's object headers, so panels read as one family.
const HEADER_COLOR := Color("#e0b070")
## The mark beside an entry with no event number to lead with (a comment, a group): the editor's own
## star, the one its FileSystem favorites wear (Godot 4.7's editor theme carries no icon named
## "Bookmark"). A numbered entry's number is its mark. Asked of the editor theme, so a run with no
## editor (the suite) simply shows the words.
const ENTRY_ICON := "Favorites"
## The sheet header's picture: the file the marks are in.
const SHEET_ICON := "Script"

var _dock: Control = null

var window: Window = null
var tree: Tree = null
var _empty_hint: Label = null
## The foot: what Clear All cannot get back, said where the list ends and not only in its confirmation.
var session_note: Label = null
## Asks before Clear All: the marks are not sheet edits, so there is no undo that brings them back.
var clear_confirm: ConfirmationDialog = null


func _init(dock: Control) -> void:
	_dock = dock


## Builds the window + tree without popping it (testable headless); open() pops it up.
func build() -> void:
	if window != null:
		return
	var parts: Dictionary = EventSheetPopupUI.panel_window("Bookmarks", Vector2i(400, 340), _dock)
	window = parts["window"]
	var body_box: VBoxContainer = parts["box"]
	var toolbar: HBoxContainer = HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 6)
	var previous_button: Button = Button.new()
	previous_button.text = "◂ Previous"
	previous_button.tooltip_text = "Jump to the previous bookmark (Shift+F4)."
	previous_button.pressed.connect(func() -> void: _cycle(-1))
	toolbar.add_child(previous_button)
	var next_button: Button = Button.new()
	next_button.text = "Next ▸"
	next_button.tooltip_text = "Jump to the next bookmark (F4)."
	next_button.pressed.connect(func() -> void: _cycle(1))
	toolbar.add_child(next_button)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(spacer)
	var clear_button: Button = Button.new()
	clear_button.text = "Clear All"
	clear_button.tooltip_text = "Remove every bookmark from this sheet."
	clear_button.pressed.connect(ask_clear_all)
	toolbar.add_child(clear_button)
	body_box.add_child(toolbar)
	tree = EventSheetPopupUI.table(PackedStringArray(), 180.0)
	tree.select_mode = Tree.SELECT_ROW
	tree.item_selected.connect(_on_entry_selected)
	body_box.add_child(tree)
	_empty_hint = EventSheetPopupUI.hint_label("No bookmarks yet - select a row and press Ctrl+M to mark it. F4 / Shift+F4 cycle through marks.", 360.0)
	body_box.add_child(_empty_hint)
	session_note = EventSheetPopupUI.hint_label(EventSheetL10n.translate("Bookmarks last for this session only."), 360.0)
	body_box.add_child(session_note)


## Lists every bookmarked row; activating one reveals it (Ctrl+M marks rows).
func open() -> void:
	build()
	refresh()
	window.popup_centered()


## Clear All asks first. Bookmarks live outside the undo stack, so a slip would cost every mark with
## no way back: OK (and Enter) KEEPS them, Esc keeps them too, and only the red Clear all removes them.
func ask_clear_all() -> void:
	clear_confirm = load(_dock.SMALL_PROMPT_PATH).open(_dock, {
		"title": EventSheetL10n.translate("Clear every bookmark?"),
		"say": EventSheetL10n.translate("Every bookmark in this sheet goes; the rows themselves stay as they are."),
		"note": EventSheetL10n.translate("Bookmarks are not part of undo, so Ctrl+Z cannot bring them back."),
		"main": EventSheetL10n.translate("Keep Bookmarks"),
		"cancel": "",
		"danger": EventSheetL10n.translate("Clear all"),
		"on_danger": _clear_all,
	})


func _clear_all() -> void:
	var view: EventSheetViewport = _view()
	if view != null:
		view.clear_bookmarks()
	refresh()


## The pane the reader is working in - in split view that is the one they last clicked, not always
## the left one. Bookmarks are shared between panes, but which rows are unfolded (and so listable)
## and where a jump lands are each pane's own.
func _view() -> EventSheetViewport:
	return _dock._active_view()


## Fills the bookmarks tree from the active pane (popup-free; testable headless).
func refresh() -> void:
	if tree == null:
		return
	tree.clear()
	var root: TreeItem = tree.create_item()
	var marked: int = 0
	var view: EventSheetViewport = _view()
	if view != null:
		var entry_icon: Texture2D = EventSheetEditorIcons.icon(ENTRY_ICON)
		var sheet_header: TreeItem = tree.create_item(root)
		sheet_header.set_text(0, _sheet_label())
		sheet_header.set_custom_color(0, EventSheetPopupUI.readable_on_panel(HEADER_COLOR))
		sheet_header.set_selectable(0, false)
		var sheet_icon: Texture2D = EventSheetEditorIcons.icon(SHEET_ICON)
		if sheet_icon != null:
			sheet_header.set_icon(0, sheet_icon)
		for flat_entry: Dictionary in view.get_flat_rows():
			var row_data: EventRowData = flat_entry.get("row")
			if row_data == null or not row_data.bookmark_enabled or row_data.source_resource == null:
				continue
			var entry: TreeItem = tree.create_item(sheet_header)
			entry.set_text(0, entry_label(row_data))
			if entry_icon != null and row_data.event_number <= 0:
				entry.set_icon(0, entry_icon)
			entry.set_tooltip_text(0, _full_row_text(row_data))
			entry.set_metadata(0, row_data.source_resource)
			marked += 1
		if marked == 0:
			sheet_header.free()
	if _empty_hint != null:
		_empty_hint.visible = marked == 0


## The event-sheet entry line: the margin event number first (when the row has one), then the
## row's readable text - so the panel and the gutter agree on what "event 12" is. Icon-only
## spans (the trigger glyph cell) are skipped so the entry reads as words, not "▶".
## Static-shaped for tests: pure function of the row data.
static func entry_label(row_data: EventRowData) -> String:
	var text: String = "(row)"
	for span: Variant in row_data.spans:
		var span_text: String = str(span.text).strip_edges()
		if span_text.length() > 2:
			text = span_text.left(60)
			break
	if row_data.event_number > 0:
		return "%d · %s" % [row_data.event_number, text]
	return text


func _sheet_label() -> String:
	var sheet: EventSheetResource = _dock._current_sheet
	if sheet == null:
		return "Current sheet"
	var path: String = sheet.external_source_path if not sheet.external_source_path.is_empty() else sheet.resource_path
	return path.get_file() if not path.is_empty() else "Current sheet"


func _full_row_text(row_data: EventRowData) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for span: Variant in row_data.spans:
		var span_text: String = str(span.text).strip_edges()
		if not span_text.is_empty():
			parts.append(span_text)
	return " | ".join(parts)


func _on_entry_selected() -> void:
	var selected: TreeItem = tree.get_selected()
	if selected == null:
		return
	var target: Resource = selected.get_metadata(0)
	var view: EventSheetViewport = _view()
	if target != null and view != null:
		view.reveal_resource(target)
		view.select_resource(target)


func _cycle(direction: int) -> void:
	var view: EventSheetViewport = _view()
	if view != null:
		view.jump_to_bookmark(direction)
		refresh()
