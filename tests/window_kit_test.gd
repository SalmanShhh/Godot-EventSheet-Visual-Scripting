@tool
extends RefCounted
# Godot EventSheets - the window kit's parts: the described dropdown (every choice carries its
# sentence as Godot's own item tooltip, and the closed dropdown's tooltip follows the chosen one),
# the result card, the state note and the one band every window and picker leads with.


const SUPPORT := preload("res://tests/support.gd")
const NAME := "window_kit_test"


static func run() -> bool:
	var passed: bool = true
	passed = _described_dropdown() and passed
	passed = _result_card() and passed
	passed = _state_note() and passed
	passed = _row_band() and passed
	passed = _window_backdrop() and passed
	passed = _table_keeps_names() and passed
	passed = _every_plain_window_paints() and passed
	passed = _described_sentences_are_translatable() and passed
	return passed


## Every hover sentence the Save studio's formats and the function dialog's value types show is a key
## the translation tables carry - a sentence spelled out inside its translate() call, which the
## harvest reads, rather than one looked up from a table, which it cannot.
static func _described_sentences_are_translatable() -> bool:
	var keys: Dictionary = {}
	var table: FileAccess = FileAccess.open("res://addons/eventsheet/translations/TEMPLATE.csv", FileAccess.READ)
	while not table.eof_reached():
		var cells: PackedStringArray = table.get_csv_line()
		if not cells.is_empty():
			keys[cells[0]] = true
	var missing: Array = []
	var sentences: Array = []
	for fmt: String in EventSheetSaveStudio.FORMATS:
		sentences.append(EventSheetSaveStudio.format_description(fmt))
	for entry: Dictionary in EventSheetFunctionDialog.VALUE_TYPES:
		sentences.append(EventSheetFunctionDialog.value_type_description(int(entry.get("type"))))
	for sentence: String in sentences:
		if sentence.is_empty() or not keys.has(sentence):
			missing.append(sentence)
	return SUPPORT.pins(NAME, [
		["thirteen hover sentences", sentences.size(), 13],
		["each one is in the translation tables", missing, []],
	])


static func _described_dropdown() -> bool:
	var dropdown: OptionButton = EventSheetPopupUI.described_option()
	EventSheetPopupUI.add_described_item(dropdown, "Auto", "Loaded when it enters, saved when it leaves.")
	EventSheetPopupUI.add_described_item(dropdown, "Manual", "Only when your events say so.", "manual")
	dropdown.add_item("Bare")
	var rows: Array = [
		["each choice carries its sentence as Godot's item tooltip", dropdown.get_item_tooltip(1),
			"Only when your events say so."],
		["a stored value rides as the item's metadata", dropdown.get_item_metadata(1), "manual"],
		["the closed dropdown says the chosen item's sentence", dropdown.tooltip_text,
			"Loaded when it enters, saved when it leaves."],
	]
	dropdown.select(1)
	dropdown.item_selected.emit(1)
	rows.append(["picking another choice moves the tooltip with it", dropdown.tooltip_text,
		"Only when your events say so."])
	# select() from code emits nothing - the pointer arriving brings the tooltip up to date.
	dropdown.select(0)
	dropdown.mouse_entered.emit()
	rows.append(["a choice made in code is said by the time the pointer arrives", dropdown.tooltip_text,
		"Loaded when it enters, saved when it leaves."])
	var told: OptionButton = OptionButton.new()
	told.tooltip_text = "What the field is for."
	EventSheetPopupUI.described_option(told)
	told.add_item("Plain")
	EventSheetPopupUI.follow_description(told)
	rows.append(["a choice with no sentence falls back to the field's own tooltip", told.tooltip_text,
		"What the field is for."])
	dropdown.free()
	told.free()
	return SUPPORT.pins(NAME, rows)


static func _result_card() -> bool:
	var card: EventSheetPopupUI.ResultCard = EventSheetPopupUI.ResultCard.new("What happened")
	card.report([
		{"text": "Wrote 12 rows.", "file": "res://data/items.csv", "tone": EventSheetPopupUI.TONE_OK},
		{"text": "3 cells were empty.", "tone": EventSheetPopupUI.TONE_WARNING},
	], PackedStringArray(["12 rows", "4 columns", "items.csv"]))
	var first: HBoxContainer = card.lines_box.get_child(0) as HBoxContainer
	var second: HBoxContainer = card.lines_box.get_child(1) as HBoxContainer
	var rows: Array = [
		["the figures read as one flow", card.figures_label.text, "12 rows  →  4 columns  →  items.csv"],
		["one line per outcome", card.lines_box.get_child_count(), 2],
		["an ok line leads with its mark", (first.get_node("Mark") as Label).text, "✓"],
		["a warning line leads with its own", (second.get_node("Mark") as Label).text, "!"],
		["the file it touched closes the line as a chip", first.get_node("File").tooltip_text,
			"res://data/items.csv"],
		["a line that touched no file has no chip", second.has_node("File"), false],
	]
	card.report([])
	rows.append(["an empty report clears the figures", card.figures_label.visible, false])
	rows.append(["and the lines", card.lines_box.get_children().filter(
		func(child: Node) -> bool: return not child.is_queued_for_deletion()).size(), 0])
	card.free()
	return SUPPORT.pins(NAME, rows)


static func _state_note() -> bool:
	var note: EventSheetPopupUI.StateNote = EventSheetPopupUI.StateNote.new()
	var rows: Array = [["a note with nothing to say is hidden", note.visible, false]]
	note.say("This name is already used by a function.")
	rows.append(["a sentence shows it", note.visible, true])
	rows.append(["and reads back", note.text, "This name is already used by a function."])
	rows.append(["a problem by default", note.tone, EventSheetPopupUI.TONE_ERROR])
	note.say("%Bullets is not in this scene yet.", EventSheetPopupUI.TONE_WARNING)
	rows.append(["a warning colours its edge amber", _edge(note), EventSheetPalette.COLOR_HEALTH_WARN])
	note.say("")
	rows.append(["saying nothing hides it again", note.visible, false])
	note.free()
	return SUPPORT.pins(NAME, rows)


## One band for the writing windows (the row they write) and the pickers (what the pick answers): it
## hides until it has something to name, and a picker's field shows what it holds in the code font.
static func _row_band() -> bool:
	var band: EventSheetPopupUI.RowBand = EventSheetPopupUI.RowBand.new()
	var code_band: EventSheetPopupUI.RowBand = EventSheetPopupUI.RowBand.new(true)
	var rows: Array = [["an unsaid band hides", band.visible, false]]
	band.show_row("System", "match state", "")
	rows.append(["a written row shows, object then words", [band.visible, band.object_label.text, band.words_label.text,
		band.note_label.visible], [true, "System", "match state", false]])
	band.show_row("", "", "the action you pick lands here")
	rows.append(["a note with nothing to name hides the band", band.visible, false])
	rows.append(["only a code band's words take the code font",
		[band.words_label.has_theme_font_override("font"), code_band.words_label.has_theme_font_override("font")],
		[false, EventSheetPopupUI.editor_font("doc_source") != null]])
	band.free()
	code_band.free()
	return SUPPORT.pins(NAME, rows)


## The height a 200-high window holding a 400-high form takes once it is shown and fitted.
static func _grown_height(window: Window) -> int:
	var tall: Control = Control.new()
	tall.custom_minimum_size = Vector2(10.0, 400.0)
	var body: Node = window.get_child(0)
	(body.get_child(0) as Control).add_child(tall)
	if body.has_method("fit_window"):
		body.call("fit_window")
	return window.size.y


## A table holds names as written: an object called Player stays Player in a German editor, where
## an auto-translated cell read it as the editor's own word for "player".
static func _table_keeps_names() -> bool:
	var table: Tree = EventSheetPopupUI.table(PackedStringArray(["Value"]))
	var mode: int = table.auto_translate_mode
	table.free()
	return SUPPORT.check(NAME, "a table never translates the names in its cells", mode, Node.AUTO_TRANSLATE_MODE_DISABLED)


## Esc pressed in the window, with nothing inside having used it: how many times the window was asked
## to close. A bare Window ignores the key, so its tool windows stayed open under it.
static func _escape_closes(window: Window) -> int:
	var asked: Array[int] = [0]
	window.close_requested.connect(func() -> void: asked[0] += 1)
	var escape: InputEventAction = InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	var body: Node = window.get_child(0)
	if body.has_method("_unhandled_key_input"):
		body.call("_unhandled_key_input", escape)
	return asked[0]


static func _edge(note: EventSheetPopupUI.StateNote) -> Color:
	return (note.get_theme_stylebox("panel") as StyleBoxFlat).border_color


## A kit window paints its own backdrop behind the margins, so a light editor theme never shows the
## renderer's grey clear colour around the cards.
static func _window_backdrop() -> bool:
	var host: Node = Node.new()
	var made: Dictionary = EventSheetPopupUI.panel_window("Outline", Vector2i(300, 200), host)
	var body: Node = (made["window"] as Window).get_child(0)
	var fill: StyleBox = (body as Control).get_theme_stylebox("panel") if body is PanelContainer else null
	var rows: Array = [
		["the window's body is a painted panel", body is PanelContainer, true],
		["painted opaque", (fill as StyleBoxFlat).bg_color.a if fill is StyleBoxFlat else 0.0, 1.0],
		["the box still sits inside it", body.is_ancestor_of(made["box"]), true],
		["the window grows to fit what it holds", _grown_height(made["window"]) >= 400, true],
		["and measures again each time it shows",
			(made["window"] as Window).visibility_changed.is_connected(Callable(body, "_fit_once_settled")), true],
		["Esc closes it through its own close request", _escape_closes(made["window"]), 1],
	]
	host.free()
	# The two debugger windows are built by hand rather than by panel_window, and paint the same body.
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.setup(EventSheetResource.new())
	var debugger: EventSheetDebuggerWindow = EventSheetDebuggerWindow.new(dock)
	debugger.ensure_window()
	var live: EventSheetLiveValuesPanel = EventSheetLiveValuesPanel.new(dock)
	live.ensure_window()
	for pair: Array in [["the Debugger", debugger.window], ["Live Values", live.window]]:
		var painted: Node = (pair[1] as Window).get_child(0)
		var paint: StyleBox = (painted as Control).get_theme_stylebox("panel") if painted is PanelContainer else null
		rows.append(["%s paints its body opaque" % pair[0],
			(paint as StyleBoxFlat).bg_color.a if paint is StyleBoxFlat else 0.0, 1.0])
	# The Lift Report was one bare Tree filling its window, so Esc did nothing there.
	dock._preview_glue._open_lift_report()
	rows.append(["Esc closes the Lift Report", _escape_closes(dock._preview_glue._lift_report_window), 1])
	dock.free()
	return SUPPORT.pins(NAME, rows)


## Every plain Window the editor builds hands its body to window_body, so no window shows the
## renderer's grey clear colour in a light editor theme. A file passes when it paints as many bodies
## as it builds windows, less the windows whose one child already paints its whole rect.
static func _every_plain_window_paints() -> bool:
	var paints_itself: Dictionary = {
		# The detached sheet: the sheet canvas paints its own background over the whole rect.
		"res://addons/eventsheet/editor/event_sheet_dock.gd": 1,
		# The completion list: a PanelContainer in the editor's own PopupPanel box fills the window, so
		# it reads as the floating list it is. The dialog toolkit already reaches into this file to stand
		# its own Down-arrow aside, so the list does not call back into the toolkit for its body.
		"res://addons/eventsheet/editor/autocomplete/completion_popup.gd": 1,
	}
	var rows: Array = []
	for path: String in _editor_scripts("res://addons/eventsheet/editor"):
		var source: String = FileAccess.get_file_as_string(path)
		var built: int = source.count("= Window.new()")
		if built == 0:
			continue
		var unpainted: int = built - int(paints_itself.get(path, 0)) - source.count("window_body(")
		if unpainted > 0:
			rows.append(["%s windows with no painted body" % path.get_file(), unpainted, 0])
	if rows.is_empty():
		rows.append(["every plain window paints its body", true, true])
	return SUPPORT.pins(NAME, rows)


static func _editor_scripts(folder: String) -> PackedStringArray:
	var found: PackedStringArray = []
	for file: String in DirAccess.get_files_at(folder):
		if file.ends_with(".gd"):
			found.append(folder.path_join(file))
	for sub: String in DirAccess.get_directories_at(folder):
		found.append_array(_editor_scripts(folder.path_join(sub)))
	return found
