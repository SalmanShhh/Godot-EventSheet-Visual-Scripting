@tool
class_name CanvasDialogReadingTest
extends RefCounted

# Pins the two shapes a tool's own UI files are made of.
#
#   A Control made in code, configured and opened - `ConfirmationDialog.new()` is a Confirm
#       dialog, the popup helpers are the verbs they publish, and `popup_centered()` opens it.
#   A canvas painted by hand - the draw verbs at every arity a sentence can name honestly, the
#       redraw, the theme lookups, and a Control's own `_gui_input` read as the Mouse triggers the
#       same branches already read as inside `_unhandled_input`, scoped to the object they landed on.
#
# Four gates, in the order a failure matters:
#   1. the grammar's values - one line, one sentence, asserted literally;
#   2. the refusals - the arities and the flags that must KEEP their code rather than read with an
#      argument quietly dropped;
#   3. the whole path - a hand-written file opened as a sheet and walked row by row, which is where
#      the `_gui_input` trigger lives (the grammar never sees it; the lifter and the row builder do);
#   4. the byte promise - both readings are display only, so the opened file saves back exactly.

const SOURCE_PATH := "user://eventforge_canvas_dialog_reading_test.gd"

## The file the regroup gate opens: one dialog, made and then shaped, which is the shape every
## tool file repeats dozens of times.
const SETUP_PATH := "user://eventforge_dialog_setup_run_test.gd"
const SETUP_SOURCE: String = """extends Node


func _ask_keep_every_tick(uid: String, label: String) -> void:
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.title = "Keep as every tick?"
	dialog.ok_button_text = "Keep As Every Tick"
	dialog.confirmed.connect(_keep_every_tick.bind(uid))
	add_child(dialog)
	dialog.popup_centered()


func _keep_every_tick(uid: String) -> void:
	print(uid)
"""

## The checked-in file the guide figure is rendered from. Read by the whole-path gate too, so the
## picture in the docs and the words pinned here can never drift apart.
const FIXTURE_PATH := "res://tests/fixtures/canvas_dialog_reading_fixture.gd"

## The context an opened Control called Viewport produces.
const CONTEXT: Dictionary = {
	"self_object": "System",
	"script_object": "Viewport",
	"owner": "Viewport",
	"signals": {},
	"engine_properties": {"size": true, "visible": true},
	"object_classes": {"Viewport": "Control", "dialog": "ConfirmationDialog", "card": "VBoxContainer",
		"panel": "Window"}
}

## The file the whole-path gate opens. Every line of it is one of the two shapes.
const SOURCE: String = """@tool
extends Control


func _draw() -> void:
	var style := _get_reading_style()
	draw_rect(Rect2(Vector2.ZERO, size), style.background_color)
	draw_line(Vector2.ZERO, size, style.guide_color, 1.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_at(event.position)
		queue_redraw()
	elif event is InputEventMouseMotion:
		_hover_at(event.position)
"""

## What the opened file must read as, row by row.
static var OPENED_READINGS: PackedStringArray = PackedStringArray([
	"Control ▸ On draw",
	"Control ▸ Draw rectangle (0, 0) size size, style's background color",
	"Control ▸ Draw line (0, 0) to size, style's guide color width 1",
	"Mouse ▸ On left button clicked (on Control)",
	"Mouse ▸ On mouse moved (on Control)",
	"Control ▸ Redraw"
])


static func run() -> bool:
	var ok: bool = true
	ok = _drawing_values() and ok
	ok = _dialog_values() and ok
	ok = _refusals() and ok
	ok = _opened_file_reads() and ok
	ok = _setup_run_rows() and ok
	ok = _round_trip() and ok
	return ok


## In the action lane: every canvas verb at the arities a sentence can name.
static func _drawing_values() -> bool:
	var ok: bool = true
	for pair: Array in [
		["draw_line(a, b, Color.RED, 4.0)", "Viewport ▸ Draw line a to b, red width 4"],
		["draw_rect(Rect2(Vector2.ZERO, size), Color.BLUE)",
			"Viewport ▸ Draw rectangle (0, 0) size size, blue"],
		["draw_rect(box, Color.BLUE, false)", "Viewport ▸ Draw rectangle box, blue (outline)"],
		["draw_circle(Vector2(4, 4), 2.0, Color.GREEN, false)",
			"Viewport ▸ Draw circle at (4, 4), radius 2, green (outline)"],
		["draw_string(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)",
			"Viewport ▸ Draw text label at at, size 13"],
		["draw_string(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.RED)",
			"Viewport ▸ Draw text label at at, size 13, red"],
		["draw_texture(icon, at)", "Viewport ▸ Draw image icon at at"],
		["draw_polyline(points, Color.RED)", "Viewport ▸ Draw line along points, red"],
		["draw_polyline(points, Color.RED, 2.0)", "Viewport ▸ Draw line along points, red width 2"],
		["draw_arc(centre, 8.0, 0.0, TAU, 32, Color.RED)",
			"Viewport ▸ Draw ring at centre, radius 8, red"],
		["draw_arc(centre, 8.0, 0.0, TAU, 32, Color.RED, 2.0)",
			"Viewport ▸ Draw ring at centre, radius 8, red width 2"],
		["queue_redraw()", "Viewport ▸ Redraw"],
		["accept_event()", "Viewport ▸ Consume input"],
		["add_theme_stylebox_override(\"normal\", box)",
			"Viewport ▸ Set style \"normal\" to box"]
	]:
		ok = _check("\"%s\" reads \"%s\"" % [str(pair[0]), str(pair[1])],
			_read(str(pair[0])), str(pair[1])) and ok
	# The theme lookup is a VALUE, so it is pinned where a value is read rather than as a row.
	ok = _check("a theme colour reads as the Theme's own expression",
		EventSheetSentence.expression_text("get_theme_color(\"row_color\", \"EventSheet\")", CONTEXT),
		"Theme.Colour(\"row_color\")") and ok
	return ok


## In the action lane: the Control nouns, the popup builders and the two window verbs.
static func _dialog_values() -> bool:
	var ok: bool = true
	for pair: Array in [
		["dialog.popup_centered()", "dialog ▸ Open centered"],
		["dialog.popup()", "dialog ▸ Open"],
		["panel.hide()", "panel ▸ Close"],
		["EventSheetPopupUI.titled_card(dialog, \"Last condition removed\")",
			"dialog ▸ Add titled card \"Last condition removed\""],
		["EventSheetPopupUI.panel_section(card, \"Fields\")", "card ▸ Add section \"Fields\""],
		["EventSheetPopupUI.form_row(card, \"Event\", label)",
			"card ▸ Add form row \"Event\" label"],
		# The same builder KEPT under a name is still the one thing it does - the card added to the
		# dialog - with the name it was kept under muted beside it, because what the rows below do to
		# `card` is done to the card this row just made.
		["var card: VBoxContainer = EventSheetPopupUI.titled_card(dialog, \"Last condition removed\")",
			"dialog ▸ Add titled card \"Last condition removed\" as card"],
		["var card := EventSheetPopupUI.titled_card(dialog, \"Last condition removed\")",
			"dialog ▸ Add titled card \"Last condition removed\" as card"],
		["var fields := EventSheetPopupUI.panel_section(card, \"Fields\")",
			"card ▸ Add section \"Fields\" as fields"]
	]:
		ok = _check("\"%s\" reads \"%s\"" % [str(pair[0]), str(pair[1])],
			_read(str(pair[0])), str(pair[1])) and ok
	# The Control nouns, which are what a Local row says a new one of.
	for pair: Array in [
		["ConfirmationDialog", "Confirm dialog"],
		["AcceptDialog", "Accept dialog"],
		["Window", "Window"],
		["Button", "Button"],
		["CheckBox", "Check box"],
		["LineEdit", "Text input"],
		["ItemList", "List"],
		["TabContainer", "Tabs"],
		["Tree", "Tree"],
		["FileDialog", "File chooser"],
		["ColorPicker", "Colour picker"],
		["PopupMenu", "Popup menu"]
	]:
		ok = _check("%s.new() is \"a new %s\"" % [str(pair[0]), str(pair[1])],
			EventSheetSentence.expression_text("%s.new()" % str(pair[0]), CONTEXT),
			"a new %s" % str(pair[1])) and ok
	# A class the sheet has no word of its own for keeps the class name it was written with.
	ok = _check("an unnamed class keeps its own name",
		EventSheetSentence.expression_text("VBoxContainer.new()", CONTEXT),
		"a new VBoxContainer") and ok
	return ok


## The refusals. Each of these ALMOST fits one of the sentences above, and a sentence that drops an
## argument is worse than the line it replaced - so the code stays.
static func _refusals() -> bool:
	var ok: bool = true
	# A fill flag held in a variable is either state; no row can say which.
	ok = _check("a computed fill flag is refused", _read("draw_rect(box, Color.RED, filled)"), "") and ok
	# A rect whose corner and size are not written out is one value with one name.
	ok = _check("a rect in a variable keeps its one name",
		_read("draw_rect(box, Color.RED)"), "Viewport ▸ Draw rectangle box, red") and ok
	# A theme lookup whose slot is computed has no word to print, so the value keeps its own text
	# (which is what a value-level reading answers with when it declines).
	ok = _check("a computed theme slot keeps its call",
		EventSheetSentence.expression_text("get_theme_color(slot, \"EventSheet\")", CONTEXT),
		"get_theme_color(slot, \"EventSheet\")") and ok
	# A style override whose slot is computed keeps its call.
	ok = _check("a computed style slot is refused",
		_read("add_theme_stylebox_override(slot, box)"), "") and ok
	# `hide()` on something that is not a window is still a visibility flag.
	ok = _check("hiding a plain node is still invisibility",
		_read("hide()"), "Viewport ▸ Set invisible") and ok
	return ok


## The whole path: the file opened as a sheet, every row read off the canvas's own spans. This is
## where the `_gui_input` trigger lives - the grammar never sees it.
static func _opened_file_reads() -> bool:
	var ok: bool = true
	var readings: PackedStringArray = _render(_import())
	for expected: String in OPENED_READINGS:
		ok = _check("the opened file reads \"%s\"" % expected, readings.has(expected), true) and ok
	return ok


## Both readings are display only, so the file saves back byte for byte - the string this test wrote
## AND the checked-in fixture the guide figure is made from.
## A dialog built in code reads as a dialog and the rows that shape it: the lines that write its
## properties, put it in the tree and open it hang UNDER the Local row that made it, instead of
## standing as their own top-level steps. Pinned by the exact shape of the tree, because "the rows
## are somewhere" is the one thing a regroup can get wrong while every sentence still reads right.
##
## Display only, like every reading around it: the byte gate below opens this very file.
static func _setup_run_rows() -> bool:
	var ok: bool = true
	var handle: FileAccess = FileAccess.open(SETUP_PATH, FileAccess.WRITE)
	handle.store_string(SETUP_SOURCE)
	handle.close()
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(SETUP_PATH)
	var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
	style.ensure_defaults()
	sheet.editor_style = style
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_ace_registry(EventSheetACERegistry.new())
	viewport.set_sheet(sheet)
	viewport.set_reading_mode(true)
	var local_row: EventRowData = null
	var event_lines: PackedStringArray = PackedStringArray()
	for row_data: EventRowData in _walk(viewport._root_rows, viewport):
		if row_data.row_uid.begins_with("local_declaration_") and not row_data.row_uid.contains("_setup"):
			local_row = row_data
		for span: SemanticSpan in row_data.spans:
			if str(span.metadata.get("kind", "")) == "action" 					and span.text.contains("Wire On Confirmed"):
				event_lines.append(span.text.strip_edges())
	ok = _check("the dialog's declaration is a Local row", local_row != null, true) and ok
	if local_row != null:
		var under: PackedStringArray = PackedStringArray()
		for child: EventRowData in local_row.children:
			for span: SemanticSpan in child.spans:
				if str(span.metadata.get("kind", "")) == "action":
					under.append(span.text.strip_edges())
		ok = _check("the lines that shape the dialog hang under it", " | ".join(under),
			"Set title to \"Keep as every tick?\" | Set ok button text to \"Keep As Every Tick\" | add child dialog | Open centered") and ok
	# The wired-up signal is NOT swallowed: it keeps the trigger reading the sheet already gives it,
	# on the event itself, which is why the run steps over a connect instead of taking it.
	ok = _check("the wired-up signal keeps its own row, once", " | ".join(event_lines),
		"Wire On Confirmed to Keep Every Tick   uid = uid") and ok
	viewport.free()
	var output: String = str(SheetCompiler.compile(
		GDScriptImporter.new().import_external(SETUP_PATH), SETUP_PATH).get("output", ""))
	ok = _check("and the regrouped file still saves every byte back", output, SETUP_SOURCE) and ok
	return ok


static func _round_trip() -> bool:
	_write_source()
	var ok: bool = true
	var output: String = str(SheetCompiler.compile(
		GDScriptImporter.new().import_external(SOURCE_PATH), SOURCE_PATH).get("output", ""))
	ok = _check("the opened file saves every byte back", output, SOURCE) and ok
	var handle: FileAccess = FileAccess.open(FIXTURE_PATH, FileAccess.READ)
	var fixture_source: String = handle.get_as_text() if handle != null else ""
	if handle != null:
		handle.close()
	var fixture_output: String = str(SheetCompiler.compile(
		GDScriptImporter.new().import_external(FIXTURE_PATH), FIXTURE_PATH).get("output", ""))
	ok = _check("the figure's fixture saves every byte back", fixture_output, fixture_source) and ok
	return ok


static func _write_source() -> void:
	var handle: FileAccess = FileAccess.open(SOURCE_PATH, FileAccess.WRITE)
	if handle != null:
		handle.store_string(SOURCE)
		handle.close()


static func _import() -> EventSheetResource:
	_write_source()
	return GDScriptImporter.new().import_external(SOURCE_PATH)


## The readings of one sheet, straight off the canvas's own spans.
static func _render(sheet: EventSheetResource) -> PackedStringArray:
	sheet.read_only = true
	var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
	style.ensure_defaults()
	sheet.editor_style = style
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_ace_registry(EventSheetACERegistry.new())
	viewport.set_sheet(sheet)
	viewport.set_reading_mode(true)
	var readings: PackedStringArray = PackedStringArray()
	for row_data: EventRowData in _walk(viewport._root_rows, viewport):
		for span: SemanticSpan in row_data.spans:
			var label: String = str(span.metadata.get("object_label", ""))
			var text: String = span.text.strip_edges()
			readings.append("%s ▸ %s" % [label, text] if not label.is_empty() else text)
	viewport.free()
	return readings


## Every row in the tree, parents before children.
static func _walk(rows: Array, viewport: EventSheetViewport) -> Array:
	var found: Array = []
	for row_data: EventRowData in rows:
		viewport._row_builder._ensure_event_spans(row_data)
		found.append(row_data)
		found.append_array(_walk(row_data.children, viewport))
	return found


static func _read(code: String) -> String:
	var result: Dictionary = EventSheetSentence.statement(code, CONTEXT)
	return "" if result.is_empty() else "%s ▸ %s" % [str(result.get("object", "")), _joined(result)]


static func _joined(result: Dictionary) -> String:
	var text: String = ""
	for segment: Variant in (result.get("segments", []) as Array):
		text += str((segment as Dictionary).get("text", ""))
	return text


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] canvas_dialog_reading_test: %s" % label)
		return true
	print("[FAIL] canvas_dialog_reading_test: %s - expected %s, got %s" % [label, expected, actual])
	return false
