# Godot EventSheets - the Bookmarks panel (dock subsystem)
#
# The Construct-style bookmarks bar: a toolbar (Previous / Next / Clear All) over a tree
# of every Ctrl+M'd row, grouped under a colored sheet header, each entry carrying its
# margin event number so "event 12" in the panel matches the number in the gutter.
# Clicking an entry jumps to (reveals + selects) the row; Previous/Next reuse the
# viewport's F4 / Shift+F4 cycling. The tree builds popup-free so tests pin it headless.
@tool
class_name EventSheetBookmarksPanel
extends RefCounted

# Section-header tint shared with the ACE picker's object headers, so panels read as one family.
const HEADER_COLOR := Color("#e0b070")
const ENTRY_NUMBER_COLOR := Color("#6f7580")

var _dock: Control = null

var window: Window = null
var tree: Tree = null
var _empty_hint: Label = null


func _init(dock: Control) -> void:
	_dock = dock


## Builds the window + tree without popping it (testable headless); open() pops it up.
func build() -> void:
	if window != null:
		return
	window = Window.new()
	window.title = "Bookmarks"
	window.size = Vector2i(400, 340)
	window.close_requested.connect(func() -> void: window.hide())
	var body_box: VBoxContainer = VBoxContainer.new()
	body_box.add_theme_constant_override("separation", 6)
	body_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	clear_button.pressed.connect(func() -> void:
		if _dock._viewport != null:
			_dock._viewport.clear_bookmarks()
		refresh())
	toolbar.add_child(clear_button)
	body_box.add_child(toolbar)
	tree = Tree.new()
	tree.hide_root = true
	tree.select_mode = Tree.SELECT_ROW
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.custom_minimum_size = Vector2(0.0, 180.0)
	tree.item_selected.connect(_on_entry_selected)
	body_box.add_child(tree)
	_empty_hint = EventSheetPopupUI.hint_label("No bookmarks yet - select a row and press Ctrl+M to mark it. F4 / Shift+F4 cycle through marks.", 360.0)
	body_box.add_child(_empty_hint)
	var card: Control = EventSheetPopupUI.titled_card("Bookmarks", body_box)
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var body: Control = EventSheetPopupUI.margined(card)
	body.set_anchors_preset(Control.PRESET_FULL_RECT)
	window.add_child(body)
	_dock.add_child(window)


## Lists every bookmarked row; activating one reveals it (Ctrl+M marks rows).
func open() -> void:
	build()
	refresh()
	window.popup_centered()


## Fills the bookmarks tree from the primary pane (popup-free; testable headless).
func refresh() -> void:
	if tree == null:
		return
	tree.clear()
	var root: TreeItem = tree.create_item()
	var marked: int = 0
	if _dock._viewport != null:
		var sheet_header: TreeItem = tree.create_item(root)
		sheet_header.set_text(0, _sheet_label())
		sheet_header.set_custom_color(0, HEADER_COLOR)
		sheet_header.set_selectable(0, false)
		for flat_entry: Dictionary in _dock._viewport.get_flat_rows():
			var row_data: EventRowData = flat_entry.get("row")
			if row_data == null or not row_data.bookmark_enabled or row_data.source_resource == null:
				continue
			var entry: TreeItem = tree.create_item(sheet_header)
			entry.set_text(0, entry_label(row_data))
			entry.set_tooltip_text(0, _full_row_text(row_data))
			entry.set_metadata(0, row_data.source_resource)
			marked += 1
		if marked == 0:
			sheet_header.free()
	if _empty_hint != null:
		_empty_hint.visible = marked == 0


## The C3-style entry line: the margin event number first (when the row has one), then the
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
	return "🔖 %s" % text


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
	if target != null and _dock._viewport != null:
		_dock._viewport.reveal_resource(target)
		_dock._viewport.select_resource(target)


func _cycle(direction: int) -> void:
	if _dock._viewport != null:
		_dock._viewport.jump_to_bookmark(direction)
		refresh()
