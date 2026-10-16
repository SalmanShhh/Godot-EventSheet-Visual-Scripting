# Godot EventSheets - the translation table: one catalog at a time, and only the rows on screen.
#
# A toolbar (which catalog, find, and All lines / Missing only / Fake language), a custom-drawn grid
# and a status line. The grid is ONE Control that draws the forty-odd rows it has room for straight
# from the table model, so a catalog of a million lines costs what a catalog of forty does: no Tree
# item or ItemList entry exists per line, and a row is only split into cells when it scrolls into
# view. Columns: the line number, the key ("Text in the game"), then the source and every language
# a player can be offered; a cell still empty reads "missing" in amber. Fake language swaps the
# languages for the source beside its pseudo text - a test column, never one a player sees.
#
# THE API A WINDOW BINDS TO: show_catalogs() fills the picker, open_catalog() shows one file,
# set_filter() / set_search() drive the toolbar from code (a Check button showing Missing only),
# line_opened(row) fires when a line is clicked or entered, step_line() moves to the next or
# previous shown line, and `table` is the model to read and write the line through (key, cells,
# cell, set_cell).
#
# DELIBERATELY NO `class_name`: the window that shows it loads it by path when it opens.
@tool
extends VBoxContainer

## A line was clicked, or Enter was pressed on it. `row` is the line's index in the catalog file.
signal line_opened(row: int)

const ReadingDoors := preload("res://addons/eventsheet/editor/interaction/reading_doors.gd")
const TABLE_PATH := "res://addons/eventsheet/editor/translation_table.gd"
## The line-number column, in 1x pixels. The key column then takes KEY_SHARE of a language column.
const NUMBER_WIDTH := 64.0
const KEY_SHARE := 1.1
const CELL_PAD := 7.0
const WHEEL_ROWS := 3

## The model: the catalog on show, read in pages.
var table: RefCounted = null
## The folder the catalogs live under, so the picker can name each by its place in it.
var catalog_root: String = ""

var _picker: OptionButton = null
var _search: LineEdit = null
var _filter_buttons: Dictionary = {}
var _canvas: Control = null
var _scroll: VScrollBar = null
var _status: Label = null
var _filter: String = "all"
## True while every row is shown; otherwise `_rows` lists the shown ones in file order.
var _every: bool = true
var _rows: PackedInt32Array = PackedInt32Array()
var _selected: int = -1
var _hovered: int = -1
## source text -> pseudo text for the rows on screen, filled before each redraw in Fake language.
var _pseudo: Dictionary = {}


func _init() -> void:
	table = load(TABLE_PATH).new()
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var bar: HBoxContainer = HBoxContainer.new()
	_picker = EventSheetPopupUI.described_option()
	_picker.item_selected.connect(func(index: int) -> void: open_catalog(str(_picker.get_item_metadata(index))))
	bar.add_child(_picker)
	_search = LineEdit.new()
	_search.placeholder_text = EventSheetL10n.translate("Find text or key…")
	_search.clear_button_enabled = true
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_changed.connect(func(_text: String) -> void: _refilter())
	bar.add_child(_search)
	var group: ButtonGroup = ButtonGroup.new()
	for choice: Array in [
		["all", EventSheetL10n.translate("All lines"), EventSheetL10n.translate("Every line in this file.")],
		["missing", EventSheetL10n.translate("Missing only"), EventSheetL10n.translate("Only the lines a language still has no text for. Their empty cells read \"missing\" in amber.")],
		["pseudo", EventSheetL10n.translate("Fake language"), EventSheetL10n.translate("Each line beside a fake version of it: accented and longer, to find text that gets cut off or was never sent for translation. A test column only - players are never offered it.")],
	]:
		var button: Button = Button.new()
		button.text = str(choice[1])
		button.tooltip_text = str(choice[2])
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = choice[0] == _filter
		button.pressed.connect(set_filter.bind(str(choice[0])))
		bar.add_child(button)
		_filter_buttons[choice[0]] = button
	_paint_filters()
	add_child(bar)
	var body: HBoxContainer = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas = Control.new()
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.custom_minimum_size = Vector2(0.0, EventSheetPalette.scaled_f(160.0))
	_canvas.clip_contents = true
	_canvas.focus_mode = Control.FOCUS_ALL
	_canvas.draw.connect(_draw_rows)
	_canvas.gui_input.connect(_on_canvas_input)
	_canvas.resized.connect(_redraw)
	_canvas.mouse_exited.connect(func() -> void:
		_hovered = -1
		_canvas.queue_redraw())
	body.add_child(_canvas)
	_scroll = VScrollBar.new()
	_scroll.step = 1.0
	_scroll.value_changed.connect(func(_value: float) -> void: _redraw())
	body.add_child(_scroll)
	add_child(body)
	var footer: HBoxContainer = HBoxContainer.new()
	_status = EventSheetPopupUI.hint_label("", 0.0)
	var speed: Label = EventSheetPopupUI.hint_label(EventSheetL10n.translate("Only these rows are drawn · scroll, search and filters stay instant"), 0.0)
	speed.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# Both lines give way with an ellipsis rather than widening the window around them.
	for label: Label in [_status, speed]:
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		footer.add_child(label)
	add_child(footer)


## Fills the catalog picker with `paths` (each named by its place under `root`) and opens `chosen`,
## or the first one.
func show_catalogs(paths: PackedStringArray, root: String = "", chosen: String = "") -> void:
	catalog_root = root
	_picker.clear()
	for path: String in paths:
		var place: String = path.trim_prefix(root.rstrip("/")).lstrip("/") if not root.is_empty() else path.get_file()
		var folder: String = place.get_basename()
		EventSheetPopupUI.add_described_item(_picker, place,
			EventSheetL10n.translate("The text the files at the top of the project say.") if folder == "strings"
			else EventSheetL10n.translate("The text the files in %s say.") % ("res://%s/" % folder), path)
	_picker.visible = paths.size() > 1
	var start: String = chosen if paths.has(chosen) else (paths[0] if not paths.is_empty() else "")
	if not start.is_empty():
		_picker.select(paths.find(start))
		EventSheetPopupUI.follow_description(_picker)
	open_catalog(start)


## Shows one catalog. {ok, message, rows} from the model.
func open_catalog(path: String) -> Dictionary:
	var outcome: Dictionary = table.open(path)
	_selected = -1
	_refilter()
	return outcome


func set_filter(filter: String) -> void:
	_filter = filter
	if _filter_buttons.has(filter):
		(_filter_buttons[filter] as Button).set_pressed_no_signal(true)
	_paint_filters()
	_refilter()


## The chosen filter is the window's filled blue button and the others are plain, so which lines are
## on show reads at a glance.
func _paint_filters() -> void:
	for choice: String in _filter_buttons:
		var button: Button = _filter_buttons[choice]
		if choice == _filter:
			EventSheetPopupUI.main_button(button)
		else:
			for state: String in ["normal", "hover", "pressed", "focus"]:
				button.remove_theme_stylebox_override(state)
			for color_name: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
				button.remove_theme_color_override(color_name)


func set_search(text: String) -> void:
	_search.text = text
	_refilter()


## How many lines the toolbar choice shows, and the catalog row of the n-th of them.
func shown_count() -> int:
	return table.row_count() if _every else _rows.size()


func shown_row(index: int) -> int:
	return index if _every else _rows[index]


## Selects the next (step 1) or previous (step -1) shown line, scrolls it into view, opens it, and
## returns its row (-1 when nothing is shown). Previous from the first wraps to the last.
func step_line(step: int) -> int:
	var count: int = shown_count()
	if count == 0:
		return -1
	var at: int = _shown_index(_selected)
	at = posmod(at + step, count) if at >= 0 else (0 if step > 0 else count - 1)
	select_row(shown_row(at))
	line_opened.emit(_selected)
	return _selected


## Marks `row` as the chosen line and scrolls it into view.
func select_row(row: int) -> void:
	_selected = row
	var at: int = _shown_index(row)
	if at >= 0 and (at < int(_scroll.value) or at >= int(_scroll.value) + _visible_rows()):
		_scroll.value = clampi(at - _visible_rows() / 2, 0, maxi(0, count_scrollable()))
	_redraw()


## The status line as it reads now - what the suite and a window's own summary quote.
func status_text() -> String:
	return _status.text


func count_scrollable() -> int:
	return shown_count() - _visible_rows()

# ── Drawing ─────────────────────────────────────────────────────────────────────────


func _refilter() -> void:
	var shown: Dictionary = table.shown(_search.text, _filter)
	_every = bool(shown.get("every", true))
	_rows = shown.get("rows", PackedInt32Array())
	_scroll.value = 0.0
	_redraw()


## Brings the scroll range, the pseudo text and the status line up to date, then asks for a draw.
## The pseudo text is made HERE, for the rows on screen in one batch, because making it changes a
## project setting for a moment - never something to do in the middle of a draw.
func _redraw() -> void:
	var count: int = shown_count()
	_scroll.max_value = float(count)
	_scroll.page = float(_visible_rows())
	_scroll.visible = count > _visible_rows()
	var first: int = int(_scroll.value)
	var last: int = mini(count, first + _visible_rows())
	if _filter == "pseudo":
		var sources: PackedStringArray = PackedStringArray()
		for index: int in range(first, last):
			sources.append(_source(shown_row(index)))
		var pseudo: PackedStringArray = EventSheetGameCatalog.pseudolocalize_all(sources)
		_pseudo.clear()
		for index: int in sources.size():
			_pseudo[sources[index]] = pseudo[index]
	_status.text = _status_line(first, last)
	_status.tooltip_text = _status.text
	_canvas.queue_redraw()


func _status_line(first: int, last: int) -> String:
	var file: String = table.path.trim_prefix(catalog_root.rstrip("/")).lstrip("/") if not catalog_root.is_empty() else table.path.get_file()
	if table.row_count() == 0:
		return EventSheetL10n.translate("No lines in %s yet - Find text fills it.") % file
	if _filter == "missing" and _search.text.strip_edges().is_empty():
		var counts: PackedStringArray = PackedStringArray()
		var lacking: Dictionary = table.missing_by_language()
		for language: String in lacking:
			counts.append("%s %s" % [_grouped(int(lacking[language])), _language_name(language)])
		return EventSheetL10n.translate("Missing only: %s lines · in %s") % [", ".join(counts), file]
	if not _every:
		return EventSheetL10n.translate("%s of %s lines hold \"%s\" · in %s") % [_grouped(shown_count()), _grouped(table.row_count()), _search.text.strip_edges(), file]
	return EventSheetL10n.translate("Lines %s to %s of %s · in %s") % [_grouped(first + 1), _grouped(last), _grouped(table.row_count()), file]


func _draw_rows() -> void:
	var font: Font = _canvas.get_theme_font("font", "Label")
	var font_size: int = _canvas.get_theme_font_size("font_size", "Label")
	var row_height: float = _row_height()
	var text: Color = EventSheetPopupUI.text_color()
	var muted: Color = EventSheetPopupUI.muted_text_color()
	var warn: Color = EventSheetPopupUI.tone_color(EventSheetPopupUI.TONE_WARNING)
	var accent: Color = EventSheetPopupUI.accent_color()
	var hairline: Color = Color(text, 0.12)
	var pad: float = EventSheetPalette.scaled_f(CELL_PAD)
	var columns: Array = _layout(_canvas.size.x)
	_canvas.draw_rect(Rect2(0.0, 0.0, _canvas.size.x, row_height), Color(text, 0.07))
	for column: Dictionary in columns:
		_draw_cell(font, font_size, str(column.title), Rect2(float(column.x) + pad, 0.0, float(column.width) - pad * 2.0, row_height),
			muted if column.kind == "number" else text)
	var first: int = int(_scroll.value)
	var source_column: String = _scan().SOURCE_COLUMN
	for index: int in range(first, mini(shown_count(), first + _visible_rows())):
		var row: int = shown_row(index)
		var top: float = row_height * float(index - first + 1)
		if row == _selected:
			_canvas.draw_rect(Rect2(0.0, top, _canvas.size.x, row_height), Color(accent, 0.22))
		elif row == _hovered:
			_canvas.draw_rect(Rect2(0.0, top, _canvas.size.x, row_height), Color(text, 0.05))
		_canvas.draw_line(Vector2(0.0, top), Vector2(_canvas.size.x, top), hairline)
		var cells: PackedStringArray = table.cells(row)
		for column: Dictionary in columns:
			var value: String = ""
			var color: Color = text
			match str(column.kind):
				"number":
					value = _grouped(row + 1)
					color = muted
				"key":
					value = table.key(row)
					color = muted
				"pseudo":
					value = str(_pseudo.get(_source(row), ""))
					color = accent
				_:
					value = cells[int(column.index)] if int(column.index) >= 0 else ""
			if str(column.kind) == "language" and str(column.column) != source_column and value.strip_edges().is_empty():
				_canvas.draw_rect(Rect2(float(column.x), top, float(column.width), row_height), Color(warn, 0.14))
				value = EventSheetL10n.translate("missing")
				color = warn
			_draw_cell(font, font_size, value, Rect2(float(column.x) + pad, top, float(column.width) - pad * 2.0, row_height), color)


## One cell's words on one line, centred in the row and cut with an ellipsis where they run out of
## room - the way a spreadsheet shows a long line.
func _draw_cell(font: Font, font_size: int, value: String, box: Rect2, color: Color) -> void:
	var line: TextLine = TextLine.new()
	line.add_string(value.replace("\n", " "), font, font_size)
	line.width = maxf(0.0, box.size.x)
	line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	line.draw(_canvas.get_canvas_item(), Vector2(box.position.x, box.position.y + (box.size.y - line.get_size().y) / 2.0), color)


## The columns across `width`: [{kind, title, x, width, column, index}].
func _layout(width: float) -> Array:
	var source_column: String = _scan().SOURCE_COLUMN
	var columns: Array = [{"kind": "number", "title": "#"}, {"kind": "key", "title": EventSheetL10n.translate("Text in the game")}]
	var languages: PackedStringArray = PackedStringArray([source_column]) if _filter == "pseudo" else table.languages
	for language: String in languages:
		columns.append({"kind": "language", "column": language, "index": table.columns.find(language),
			"title": _language_name(language)})
	if _filter == "pseudo":
		columns.append({"kind": "pseudo", "title": EventSheetL10n.translate("Fake (test only)")})
	var number_width: float = EventSheetPalette.scaled_f(NUMBER_WIDTH)
	var unit: float = maxf(0.0, width - number_width) / (KEY_SHARE + float(columns.size() - 2))
	var x: float = 0.0
	for column: Dictionary in columns:
		column["x"] = x
		column["width"] = number_width if column.kind == "number" else (unit * KEY_SHARE if column.kind == "key" else unit)
		x += float(column.width)
	return columns


func _on_canvas_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var button: InputEventMouseButton = event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_WHEEL_DOWN or button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll.value += WHEEL_ROWS * (1 if button.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1)
			_canvas.accept_event()
		elif button.button_index == MOUSE_BUTTON_LEFT and _row_at(button.position.y) >= 0:
			_canvas.grab_focus()
			select_row(_row_at(button.position.y))
			line_opened.emit(_selected)
	elif event is InputEventMouseMotion:
		var hovered: int = _row_at((event as InputEventMouseMotion).position.y)
		if hovered != _hovered:
			_hovered = hovered
			var notes: String = table.cell(hovered, _scan().NOTES_COLUMN) if hovered >= 0 else ""
			_canvas.tooltip_text = EventSheetL10n.translate("Where it is said: %s") % notes if not notes.is_empty() else ""
			_canvas.queue_redraw()
	elif event is InputEventKey and (event as InputEventKey).pressed:
		match (event as InputEventKey).keycode:
			KEY_DOWN, KEY_UP:
				var at: int = _shown_index(_selected)
				var count: int = shown_count()
				if count > 0:
					select_row(shown_row(clampi(at + (1 if (event as InputEventKey).keycode == KEY_DOWN else -1), 0, count - 1)))
				_canvas.accept_event()
			KEY_ENTER, KEY_KP_ENTER:
				if _selected >= 0:
					line_opened.emit(_selected)
				_canvas.accept_event()


## The catalog row under a y position on the grid, or -1 (the header, or past the last line).
func _row_at(y: float) -> int:
	var index: int = int(_scroll.value) + int(floor(y / _row_height())) - 1
	return shown_row(index) if y >= _row_height() and index < shown_count() else -1


## Where `row` sits among the shown lines, or -1.
func _shown_index(row: int) -> int:
	if row < 0:
		return -1
	if _every:
		return row if row < table.row_count() else -1
	var at: int = _rows.bsearch(row)
	return at if at < _rows.size() and _rows[at] == row else -1


func _row_height() -> float:
	return _canvas.get_theme_font("font", "Label").get_height(_canvas.get_theme_font_size("font_size", "Label")) \
		+ EventSheetPalette.scaled_f(CELL_PAD)


## Lines that fit under the header.
func _visible_rows() -> int:
	return maxi(1, int(floor(_canvas.size.y / _row_height())) - 1)


## A language column's name as a reader says it ("French" for fr), or the code when Godot has none.
static func _language_name(code: String) -> String:
	var name: String = TranslationServer.get_locale_name(code)
	return name if not name.is_empty() else code


func _source(row: int) -> String:
	var source: String = table.cell(row, _scan().SOURCE_COLUMN)
	return source if not source.is_empty() else table.key(row)


## The translation scanner, for its column names - reached by path like everything this window reads.
func _scan() -> Script:
	return ReadingDoors.translation_scan()


## 1234567 -> "1,234,567": a line count a reader takes in at a glance.
static func _grouped(number: int) -> String:
	var digits: String = str(absi(number))
	var grouped: String = ""
	while digits.length() > 3:
		grouped = ",%s%s" % [digits.right(3), grouped]
		digits = digits.left(digits.length() - 3)
	return "%s%s%s" % ["-" if number < 0 else "", digits, grouped]
