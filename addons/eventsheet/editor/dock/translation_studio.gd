@tool
class_name EventSheetTranslationStudio
extends RefCounted
# Translation Studio (Tools menu), the window "Your game in other languages": the handoff to a
# translator read top to bottom. A strip of language cards says how far along each language is and
# whether players can pick it yet (its .translation registered under Localization); four numbered
# steps find the text (a sweep of the scripts AND the .tres data assets Godot's POT route cannot
# see, merged so a finished cell is never clobbered), fill each language, check what is missing (or
# try a fake, longer, accented language) and turn the languages on. Each button reports in a result
# card under itself; the table (translation_table_view.gd, which draws only the rows on screen)
# lists every line, and a clicked line opens in its own window. The work is
# EventSheetTranslationScan / EventSheetGameCatalog on the grid codec: this is the form around it.

const TABLE_VIEW_PATH := "res://addons/eventsheet/editor/dock/translation_table_view.gd"
## Coverage at or above this reads as nearly done on a language card.
const NEARLY_DONE := 80

## The folder Find text sweeps; the sweep itself skips the plugin's own code and the bundled packs.
var scan_folder: String = "res://"
## The catalog every step works on: one .csv, or a folder of them (one per folder of the game).
## Empty is the project's own: its i18n/strings.csv when it has one, else the i18n folder.
var catalog_target: String = ""
var _dock: Control = null
var _window: Window = null
var _languages: HFlowContainer = null
var _steps_scroll: ScrollContainer = null
## Button id -> the ResultCard under that button. Only the last button pressed shows its card.
var _results: Dictionary = {}
## The table: one catalog file at a time, with its own picker, find and filters.
var _table: VBoxContainer = null
var _line_window: Window = null
var _line_box: VBoxContainer = null
## The catalog row the line window shows.
var _line_row: int = -1


func init(dock: Control) -> void:
	_dock = dock


func open() -> void:
	if _window == null:
		_build_window()
	refresh()
	_window.popup_centered(Vector2i(EventSheetPalette.scaled(780), EventSheetPalette.scaled(760)))


## The catalog every step works on, so the window can never find text into one file and turn on
## another by accident.
func catalog_path() -> String:
	return catalog_target if not catalog_target.strip_edges().is_empty() else EventSheetTranslationScan.default_catalog_target()


## Rereads the catalog into the language strip and the table.
func refresh() -> void:
	if _window == null:
		return
	_clear(_languages)
	for entry: Variant in EventSheetTranslationScan.coverage(catalog_path()):
		if not EventSheetGameCatalog.is_pseudo_locale(str((entry as Dictionary).get("locale", ""))):
			_languages.add_child(_language_card(entry as Dictionary))
	_languages.add_child(_button(EventSheetL10n.translate("+ Add a language"), _pick_language))
	var target: String = catalog_path()
	_table.show_catalogs(EventSheetTranslationScan.catalog_files(target),
		"" if EventSheetTranslationScan.is_single_catalog(target) else target, _table.table.path)


func _clear(parent: Node) -> void:
	for old: Node in parent.get_children():
		parent.remove_child(old)
		old.queue_free()


func _button(text: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.pressed.connect(action)
	return button

# ── The window ──────────────────────────────────────────────────────────────────────


func _build_window() -> void:
	_window = Window.new()
	_window.title = EventSheetL10n.translate("Your game in other languages")
	_window.close_requested.connect(_window.hide)
	var box: VBoxContainer = EventSheetPopupUI.form_box()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(EventSheetPopupUI.small_caps_label(EventSheetL10n.translate("Languages in this game"),
		EventSheetPopupUI.muted_text_color()))
	_languages = HFlowContainer.new()
	box.add_child(_languages)
	_step(box, "1", EventSheetL10n.translate("Find the text in your game"),
		EventSheetL10n.translate("Collects every piece of text players read (labels, dialogue, buttons) into the table."),
		[["find", EventSheetL10n.translate("Find text"), EventSheetL10n.translate("Found the text in your game"), run_extract]])
	_step(box, "2", EventSheetL10n.translate("Fill in each language"),
		EventSheetL10n.translate("Type the translations into the table, or bring in a spreadsheet from a translator."),
		[["add", EventSheetL10n.translate("Add a language"), EventSheetL10n.translate("Added a language"), _pick_language],
		["bring", EventSheetL10n.translate("Bring in a spreadsheet…"), EventSheetL10n.translate("Brought in a spreadsheet from a translator"),
			func() -> void: EventSheetPopupUI.browse_file(_window, PackedStringArray(["*.csv ; CSV"]), run_import)]])
	_step(box, "3", EventSheetL10n.translate("Check what is missing"),
		EventSheetL10n.translate("Shows how much of each language is done, and which text no longer appears in the game."),
		[["check", EventSheetL10n.translate("Check"), EventSheetL10n.translate("Checked what is missing"), run_check],
		["pseudo", EventSheetL10n.translate("Try a fake language"), EventSheetL10n.translate("Made a fake language to test with"), run_pseudo]])
	_step(box, "4", EventSheetL10n.translate("Use it in the game"),
		EventSheetL10n.translate("Tells Godot about the languages, so your events can switch the game into any of them."),
		[["ship", EventSheetL10n.translate("Turn on in the game"), EventSheetL10n.translate("Turned it on in the game"), run_register]])
	# The strip and the steps scroll in the top half; the table keeps the bottom half in view.
	_steps_scroll = ScrollContainer.new()
	_steps_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_steps_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_steps_scroll.size_flags_stretch_ratio = 1.4
	_steps_scroll.add_child(box)
	var page: VBoxContainer = VBoxContainer.new()
	page.add_child(_steps_scroll)
	page.add_child(_build_table())
	_window.add_child(EventSheetPopupUI.window_body(page))
	_dock.add_child(_window)


## One numbered step: its title and one sentence with its buttons beside them, and a result card
## under the step for each button. A button is [id, label, result card title, action].
func _step(box: VBoxContainer, number: String, title: String, words: String, buttons: Array) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", EventSheetPopupUI.ROW_SEPARATION)
	var badge: PanelContainer = EventSheetPopupUI.metadata_badge(number)
	badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(badge)
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var said: VBoxContainer = VBoxContainer.new()
	said.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	said.add_child(EventSheetPopupUI.section_header(title))
	said.add_child(EventSheetPopupUI.hint_label(words, EventSheetPalette.scaled_f(340.0)))
	var line: HBoxContainer = HBoxContainer.new()
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var head: HBoxContainer = HBoxContainer.new()
	head.add_child(said)
	head.add_child(line)
	column.add_child(head)
	for spec: Array in buttons:
		var button: Button = _button(str(spec[1]), spec[3] as Callable)
		# The step that starts the work and the step that finishes it are the window's main buttons.
		line.add_child(EventSheetPopupUI.main_button(button) if spec[0] in ["find", "ship"] else button)
		var card: EventSheetPopupUI.ResultCard = EventSheetPopupUI.ResultCard.new(str(spec[2]))
		card.visible = false
		column.add_child(card)
		_results[spec[0]] = card
	row.add_child(column)
	box.add_child(row)


func _build_table() -> Control:
	_table = load(TABLE_VIEW_PATH).new()
	# The cells are the GAME's text, never words of the editor to translate.
	_table.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_table.line_opened.connect(open_line)
	return _table


## Shows all lines ("all"), only the lines some language still misses ("missing"), or the fake
## column beside the English ("pseudo").
func show_filter(filter: String) -> void:
	_table.set_filter(filter)

# ── The language strip ─────────────────────────────────────────────────────────────


## What one language's card says, from its coverage entry: {name, percent, state, tone, detail,
## players}. `tone` is a window-kit tone; empty reads in the accent, for a language under way.
func language_state(entry: Dictionary) -> Dictionary:
	var locale: String = str(entry.get("locale", ""))
	var total: int = int(entry.get("total", 0))
	var covered: int = int(entry.get("covered", 0))
	var percent: int = 100 if total == 0 else floori(100.0 * covered / total)
	var source: bool = locale == EventSheetTranslationScan.SOURCE_COLUMN
	var state: Array = [EventSheetL10n.translate("Not started"), EventSheetPopupUI.TONE_WARNING]
	if source:
		state = [EventSheetL10n.translate("Source"), EventSheetPopupUI.TONE_OK]
	elif percent >= 100:
		state = [EventSheetL10n.translate("Done"), EventSheetPopupUI.TONE_OK]
	elif percent >= NEARLY_DONE:
		state = [EventSheetL10n.translate("Nearly done"), ""]
	elif percent > 0:
		state = [EventSheetL10n.translate("In progress"), ""]
	return {"name": TranslationServer.get_locale_name(locale), "percent": percent, "state": state[0], "tone": state[1],
		"detail": EventSheetL10n.translate("%d of %d lines. %d missing.") % [covered, total, total - covered],
		"players": EventSheetL10n.translate("Players see it: yes") if source or players_can_pick(locale)
			else EventSheetL10n.translate("Players see it: not yet (turn it on in step 4)")}


## True when the project registers a translation file for `locale`, which is what lets the game
## switch into it.
func players_can_pick(locale: String) -> bool:
	for path: String in EventSheetGameCatalog.registered_translations():
		if path.ends_with(".%s.translation" % locale) or path.get_file() == "%s.po" % locale:
			return true
	return false


func _language_card(entry: Dictionary) -> Control:
	var said: Dictionary = language_state(entry)
	var tone: Color = EventSheetPopupUI.tone_color(str(said["tone"]))
	var column: VBoxContainer = VBoxContainer.new()
	var head: HBoxContainer = HBoxContainer.new()
	head.add_child(_label(str(said["name"]), EventSheetPopupUI.text_color()))
	head.add_child(_label(str(entry.get("locale", "")), EventSheetPopupUI.muted_text_color()))
	var percent: Label = _label("%d%%" % int(said["percent"]), tone)
	percent.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(percent)
	column.add_child(head)
	var bar: ProgressBar = ProgressBar.new()
	bar.show_percentage = false
	bar.value = float(said["percent"])
	bar.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(110.0), EventSheetPalette.scaled_f(4.0))
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = tone
	bar.add_theme_stylebox_override("fill", fill)
	column.add_child(bar)
	column.add_child(_label(str(said["state"]), EventSheetPopupUI.muted_text_color()))
	var card: PanelContainer = EventSheetPopupUI.panel_section(column)
	card.tooltip_text = "%s (%s)\n%s\n%s" % [said["name"], entry.get("locale", ""), said["detail"], said["players"]]
	return card


## A label in one of the kit's text colours. Its words are already translated or are the game's own,
## so it never auto-translates them again.
func _label(text: String, colour: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.add_theme_color_override("font_color", colour)
	return label


## The language picker: every language Godot knows, searched as it is typed.
func _pick_language() -> void:
	var box: VBoxContainer = VBoxContainer.new()
	var search: LineEdit = LineEdit.new()
	search.placeholder_text = EventSheetL10n.translate("Search languages…")
	box.add_child(search)
	var list: ItemList = EventSheetPopupUI.sized_list(EventSheetPalette.scaled_f(220.0))
	box.add_child(list)
	var fill: Callable = func(wanted: String) -> void:
		list.clear()
		for code: String in TranslationServer.get_all_languages():
			var name: String = TranslationServer.get_language_name(code)
			if wanted.is_empty() or name.containsn(wanted) or code.containsn(wanted):
				list.set_item_metadata(list.add_item("%s  (%s)" % [name, code]), code)
		list.sort_items_by_text()
	search.text_changed.connect(fill)
	fill.call("")
	load("res://addons/eventsheet/editor/small_prompt.gd").open(_window, {"title": EventSheetL10n.translate("Add a language"),
		"say": EventSheetL10n.translate("Each language is one more column in the table, and one more translation file Godot makes from it."),
		"body": box, "glyph": "i", "main": EventSheetL10n.translate("Add"),
		"on_main": func() -> void:
			if not list.get_selected_items().is_empty():
				run_add_language(str(list.get_item_metadata(list.get_selected_items()[0])))})

# ── The buttons (each one is exactly what the suite drives) ─────────────────────────


## Step 1: sweeps and writes the translator CSV.
func run_extract() -> Dictionary:
	var outcome: Dictionary = EventSheetTranslationScan.extract(scan_folder, catalog_path())
	if _failed("find", outcome):
		return outcome
	var keys: int = int(outcome.get("keys", 0))
	var added: int = int(outcome.get("added", 0))
	var lines: Array = [_line(EventSheetL10n.translate("%d new lines were added, each with the file and line it came from, for the translator.") % added, EventSheetPopupUI.TONE_OK, catalog_path()),
		_line(EventSheetL10n.translate("%d lines already in the table were kept as they were: nothing is overwritten.") % (keys - added))]
	if int(outcome.get("kept", 0)) > 0:
		lines.append(_line(EventSheetL10n.translate("%d lines are no longer said anywhere. They stay in the table until you remove them (Check shows them).") % int(outcome["kept"]), EventSheetPopupUI.TONE_WARNING))
	_show_result("find", lines, PackedStringArray([EventSheetL10n.translate("%d lines") % keys, EventSheetL10n.translate("%d new") % added]))
	return outcome


## Step 2: one more empty language column.
func run_add_language(locale: String) -> Dictionary:
	var outcome: Dictionary = EventSheetTranslationScan.add_locale(catalog_path(), locale)
	if _failed("add", outcome):
		return outcome
	_show_result("add", [_line(EventSheetL10n.translate("Every line got an empty %s column. Godot makes a translation file for it, next to the others.") % locale,
			EventSheetPopupUI.TONE_OK, "%s.%s.translation" % [_first_catalog().get_basename(), locale]),
		_line(EventSheetL10n.translate("It shows as 0% until text is filled in. Players cannot pick it until it is turned on in step 4."), EventSheetPopupUI.TONE_WARNING)],
		PackedStringArray([TranslationServer.get_locale_name(locale), EventSheetL10n.translate("1 new column")]))
	return outcome


## Step 2: merges a file a translator sent back. A blank cell in it never overwrites anything.
func run_import(returned: String) -> Dictionary:
	var outcome: Dictionary = EventSheetTranslationScan.import_catalog(returned, catalog_path())
	if _failed("bring", outcome):
		return outcome
	var filled: int = int(outcome.get("filled", 0))
	var unknown: PackedStringArray = outcome.get("unknown", PackedStringArray())
	var lines: Array = [_line(EventSheetL10n.translate("%d cells were filled in from the translator's file.") % filled, EventSheetPopupUI.TONE_OK, catalog_path()),
		_line(EventSheetL10n.translate("Blank cells in that file left yours alone."))]
	if not unknown.is_empty():
		lines.append(_line(EventSheetL10n.translate("%d lines in that file are in no script, so they were not added: %s.") % [unknown.size(), _first_few(unknown)], EventSheetPopupUI.TONE_WARNING))
	_show_result("bring", lines, PackedStringArray([returned.get_file(), EventSheetL10n.translate("%d cells filled") % filled]))
	return outcome


## Step 3: how much of each language is done and which keys no script says any more; the table
## switches to the missing lines. Returns {ok, coverage, orphans}.
func run_check() -> Dictionary:
	var catalog: Dictionary = EventSheetTranslationScan.read_catalog(_first_catalog())
	if _failed("check", catalog):
		return catalog
	var report: Array = EventSheetTranslationScan.coverage(catalog_path())
	var orphans: PackedStringArray = EventSheetTranslationScan.orphans(catalog_path(), scan_folder)
	var lines: Array = []
	var figures: PackedStringArray = PackedStringArray()
	for entry: Variant in report:
		var locale: String = str((entry as Dictionary).get("locale", ""))
		if not _languages_of(PackedStringArray([locale])).has(locale):
			continue
		var said: Dictionary = language_state(entry as Dictionary)
		var missing: int = int((entry as Dictionary).get("missing", 0))
		figures.append("%s %d%%" % [locale, int(said["percent"])])
		lines.append(_line(EventSheetL10n.translate("%s: every line is done.") % said["name"]) if missing == 0
			else _line(EventSheetL10n.translate("%s: %d lines are missing.") % [said["name"], missing], EventSheetPopupUI.TONE_WARNING))
	if lines.is_empty():
		lines.append(_line(EventSheetL10n.translate("The table has no language besides the English yet: Add a language gives it one."), EventSheetPopupUI.TONE_WARNING))
	lines.append(_line(EventSheetL10n.translate("Every line in the table is still said somewhere.")) if orphans.is_empty()
		else _line(EventSheetL10n.translate("%d lines are no longer said anywhere: %s. A line your game builds while it runs cannot be seen from here, so read this list rather than deleting on it.") % [orphans.size(), _first_few(orphans)], EventSheetPopupUI.TONE_WARNING))
	show_filter("missing")
	_show_result("check", lines, figures)
	return {"ok": true, "coverage": report, "orphans": orphans}


## Step 3: writes the fake column and shows it. It refuses a real language's column, so fake text can
## never end up in a locale a player picks.
func run_pseudo() -> Dictionary:
	var outcome: Dictionary = EventSheetGameCatalog.write_pseudo_column(catalog_path())
	if _failed("pseudo", outcome):
		return outcome
	show_filter("pseudo")
	_show_result("pseudo", [_line(EventSheetL10n.translate("The table shows the fake column. Play the game in it with Set Language (qps): text still in plain English was never marked for translation, and anything cut off needs a wider box."), EventSheetPopupUI.TONE_OK, catalog_path()),
		_line(EventSheetL10n.translate("It is a test column: leave qps out of any language list your players see."), EventSheetPopupUI.TONE_WARNING)],
		PackedStringArray([EventSheetL10n.translate("%d lines") % int(outcome.get("rows", 0)), EventSheetL10n.translate("+40% longer, accented")]))
	return outcome


## Step 4: registers every translation file next to the table under Localization. `persist` writes
## project.godot; the suite drives the same button with it off, so a test never leaves a user://
## catalog registered in the user's project file.
func run_register(persist: bool = true) -> Dictionary:
	var target: String = catalog_path()
	var outcome: Dictionary = EventSheetGameCatalog.register_catalogs(target.get_base_dir()
		if EventSheetTranslationScan.is_single_catalog(target) else target, persist)
	if _failed("ship", outcome):
		return outcome
	var added: PackedStringArray = outcome.get("added", PackedStringArray())
	var names: PackedStringArray = PackedStringArray()
	for entry: Variant in EventSheetTranslationScan.coverage(target):
		var locale: String = str((entry as Dictionary).get("locale", ""))
		if _languages_of(PackedStringArray([locale])).has(locale) and players_can_pick(locale):
			names.append(TranslationServer.get_locale_name(locale))
	_show_result("ship", [_line(EventSheetL10n.translate("Every translation file next to the table was already turned on.")) if added.is_empty()
			else _line(EventSheetL10n.translate("Added to Project Settings > Localization, so Godot loads them when the game starts."), EventSheetPopupUI.TONE_OK, "project.godot"),
		_line(EventSheetL10n.translate("Players can pick: %s.") % ", ".join(names)) if not names.is_empty()
			else _line(EventSheetL10n.translate("No language has a translation file yet. Godot makes one per column when it imports the table."), EventSheetPopupUI.TONE_WARNING)],
		PackedStringArray([EventSheetL10n.translate("%d files") % added.size(), EventSheetL10n.translate("%d languages") % names.size(), "project.godot"]))
	return outcome


## Says a failed outcome in the button's own card and on the status line; true when it failed.
func _failed(id: String, outcome: Dictionary) -> bool:
	var ok: bool = bool(outcome.get("ok", false))
	if _dock != null:
		_dock._set_status(str(outcome.get("message", "")), not ok)
	if not ok:
		_show_result(id, [_line(str(outcome.get("message", "")), EventSheetPopupUI.TONE_ERROR)])
	return not ok


## Shows `id`'s card with `lines`, hides every other card, and rereads the strip and the table.
func _show_result(id: String, lines: Array, figures: PackedStringArray = PackedStringArray()) -> void:
	for key: String in _results:
		(_results[key] as Control).visible = key == id
	if _results.has(id):
		(_results[id] as EventSheetPopupUI.ResultCard).report(lines, figures)
		_steps_scroll.ensure_control_visible.call_deferred(_results[id])
	refresh()


func _line(text: String, tone: String = EventSheetPopupUI.TONE_OK, file: String = "") -> Dictionary:
	return {"text": text, "tone": tone, "file": file}


## The real languages of a column list: no source column, no fake one.
func _languages_of(locales: PackedStringArray) -> PackedStringArray:
	var real: PackedStringArray = PackedStringArray()
	for locale: String in locales:
		if locale != EventSheetTranslationScan.SOURCE_COLUMN and not EventSheetGameCatalog.is_pseudo_locale(locale):
			real.append(locale)
	return real


## The first catalog file the target names (the target itself while it has none), which is what a
## single-file step reads and what a result card names.
func _first_catalog() -> String:
	var files: PackedStringArray = EventSheetTranslationScan.catalog_files(catalog_path())
	return files[0] if not files.is_empty() else catalog_path()


## The first five of a list of keys, then an ellipsis: a big game can name thousands, and the card
## is a summary of them, not the list.
func _first_few(keys: PackedStringArray) -> String:
	return ", ".join(keys.slice(0, 5)) + (", …" if keys.size() > 5 else "")


func _source_of(record: Dictionary) -> String:
	var source: String = str(record.get(EventSheetTranslationScan.SOURCE_COLUMN, ""))
	return source if not source.is_empty() else str(record.get(EventSheetTranslationScan.KEY_COLUMN, ""))

# ── The line window ─────────────────────────────────────────────────────────────────


## What one line's window says: {key, source, where, who, note, room, languages: [{locale, text,
## status}]}. The notes column reads "file:line - note context: who"; who says it is the tr()
## context when the line has one, else the file that says it. The room a line has is the English
## plus the stretch the fake language tests, so a line that would be cut off says so before anyone
## plays it.
func line_details(record: Dictionary) -> Dictionary:
	var notes: String = str(record.get(EventSheetTranslationScan.NOTES_COLUMN, ""))
	var where: String = notes.get_slice(" - ", 0)
	var note: String = notes.substr(where.length() + 3).strip_edges()
	var context: String = note.get_slice("context: ", 1) if note.contains("context: ") else ""
	var room: int = ceili(_source_of(record).length() * (1.0 + EventSheetGameCatalog.DEFAULT_EXPANSION))
	var languages: Array = []
	for locale: String in _languages_of(EventSheetTranslationScan.locales_of(PackedStringArray(record.keys()))):
		var text: String = str(record.get(locale, ""))
		languages.append({"locale": locale, "text": text, "status": "missing" if text.strip_edges().is_empty()
			else ("too_long" if text.length() > room else "done")})
	return {"key": str(record.get(EventSheetTranslationScan.KEY_COLUMN, "")), "source": _source_of(record), "where": where,
		"who": context.strip_edges() if not context.is_empty() else where.get_slice(":", 0),
		"note": note.get_slice("context: ", 0).strip_edges(), "room": room, "languages": languages}


## Opens catalog row `row` of the file on show in its own window. Previous and Next walk the lines
## the table shows, so after Check they walk the missing ones.
func open_line(row: int) -> void:
	if row < 0 or row >= _table.table.row_count():
		return
	_line_row = row
	_table.select_row(row)
	if _line_window == null:
		_line_window = Window.new()
		_line_window.visible = false
		_line_window.close_requested.connect(_line_window.hide)
		var column: VBoxContainer = EventSheetPopupUI.form_box()
		_line_box = EventSheetPopupUI.form_box()
		_line_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var scroll: ScrollContainer = ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.add_child(_line_box)
		column.add_child(scroll)
		var buttons: HBoxContainer = HBoxContainer.new()
		for spec: Array in [[EventSheetL10n.translate("◀ Previous line"), _table.step_line.bind(-1)],
				[EventSheetL10n.translate("Next line ▶"), _table.step_line.bind(1)], [EventSheetL10n.translate("Done"), _line_window.hide]]:
			buttons.add_child(_button(str(spec[0]), spec[1] as Callable))
		buttons.get_child(2).size_flags_horizontal = Control.SIZE_SHRINK_END | Control.SIZE_EXPAND
		column.add_child(buttons)
		_line_window.add_child(EventSheetPopupUI.window_body(column))
		_window.add_child(_line_window)
	var record: Dictionary = {}
	var cells: PackedStringArray = _table.table.cells(row)
	for index: int in range(_table.table.columns.size()):
		record[_table.table.columns[index]] = cells[index]
	_fill_line(line_details(record))
	if _line_window.is_inside_tree() and not _line_window.visible:
		_line_window.popup_centered(Vector2i(EventSheetPalette.scaled(640), EventSheetPalette.scaled(480)))


func _fill_line(line: Dictionary) -> void:
	_line_window.title = EventSheetL10n.translate("Line %s  #%d") % [line["key"], _line_row + 1]
	_clear(_line_box)
	var muted: Color = EventSheetPopupUI.muted_text_color()
	var source: Label = _label(str(line["source"]), EventSheetPopupUI.text_color())
	source.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	source.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(320.0), 0.0)
	var said: VBoxContainer = VBoxContainer.new()
	said.add_child(EventSheetPopupUI.small_caps_label(EventSheetL10n.translate("English (source)"), muted))
	said.add_child(EventSheetPopupUI.panel_section(source))
	var seen: VBoxContainer = VBoxContainer.new()
	seen.add_child(EventSheetPopupUI.small_caps_label(EventSheetL10n.translate("Where players see it"), muted))
	if not str(line["where"]).is_empty():
		var place: PanelContainer = EventSheetPopupUI.metadata_badge(str(line["where"]))
		place.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		seen.add_child(place)
		seen.add_child(_label(EventSheetL10n.translate("Said by %s") % line["who"], EventSheetPopupUI.text_color()))
	if not str(line["note"]).is_empty():
		seen.add_child(EventSheetPopupUI.hint_label(EventSheetL10n.translate("Note for translators: %s") % line["note"], EventSheetPalette.scaled_f(200.0)))
	_line_box.add_child(EventSheetPopupUI.responsive_band(said, seen))
	_line_box.add_child(EventSheetPopupUI.small_caps_label(EventSheetL10n.translate("Every language"), muted))
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	var statuses: Dictionary = {"done": [EventSheetL10n.translate("Done"), EventSheetPopupUI.TONE_OK],
		"missing": [EventSheetL10n.translate("Missing"), EventSheetPopupUI.TONE_WARNING],
		"too_long": [EventSheetL10n.translate("Too long"), EventSheetPopupUI.TONE_WARNING]}
	for language: Variant in (line["languages"] as Array):
		var entry: Dictionary = language as Dictionary
		var status: Array = statuses[entry["status"]]
		var tone: Color = EventSheetPopupUI.tone_color(str(status[1]))
		grid.add_child(_label("%s  %s" % [TranslationServer.get_locale_name(str(entry["locale"])), entry["locale"]], EventSheetPopupUI.text_color()))
		var text: Label = _label(str(entry["text"]) if entry["status"] != "missing" else EventSheetL10n.translate("Not translated yet"),
			EventSheetPopupUI.text_color() if entry["status"] != "missing" else tone)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(280.0), 0.0)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cell: PanelContainer = EventSheetPopupUI.panel_section(text)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(cell)
		var verdict: VBoxContainer = VBoxContainer.new()
		var pill: PanelContainer = EventSheetPopupUI.metadata_badge(str(status[0]), tone)
		pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		verdict.add_child(pill)
		if entry["status"] != "missing":
			verdict.add_child(_label(EventSheetL10n.translate("%d / %d characters") % [str(entry["text"]).length(), line["room"]], tone if entry["status"] == "too_long" else muted))
		grid.add_child(verdict)
	_line_box.add_child(grid)
	_line_box.add_child(EventSheetPopupUI.hint_label(EventSheetL10n.translate("Each line has the room of its English plus 40%, the stretch the fake language tests, so a line that would be cut off shows as too long before anyone plays it.")))
