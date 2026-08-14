@tool
class_name EventSheetTranslationStudio
extends RefCounted
# Translation Studio (Tools menu): the whole handoff to a translator in one window, three tabs.
#
#   1. Extract - sweep the project for every string the game says and write ONE translator CSV,
#      merging with the file already there so finished columns are never clobbered. The same tab
#      generates the pseudo language, because the pseudo column is made from exactly these keys.
#   2. Notes - each key with its provenance (which file, which line, and the row note beside it),
#      which is the single biggest quality lever a translator ever gets and is free here because
#      the row note already exists. The orphan list lives here too: a key the catalog holds that
#      no script says any more.
#   3. Import - read a returned CSV back, merge it, report coverage per language in words, and
#      register the catalogs under Localization - the step everyone forgets.
#
# WHY A SWEEP AND NOT POT GENERATION. Godot's POT route is manual (add every compiled .gd by hand,
# press Generate) and structurally blind to .tres data assets, where a narrative game keeps most of
# its words. This sweep reads the emitted scripts AND the data assets, and it writes the CSV shape
# Godot's own importer turns into a .translation on drop.
#
# NOTHING HERE IS A SECOND CSV DIALECT: the codec is EventSheetGridCSV's, the same one the grid
# round trip writes with, so a sentence with a comma survives both files identically. The work
# itself is EventSheetTranslationScan / EventSheetGameCatalog - this is the form around it, and
# every button calls exactly what the suite calls.

var _dock: Control = null
var _window: Window = null
var _extract_root_edit: LineEdit = null
var _extract_csv_edit: LineEdit = null
var _extract_notes_check: CheckBox = null
var _extract_output: CodeEdit = null
var _pseudo_locale_edit: LineEdit = null
var _pseudo_expansion: SpinBox = null
var _notes_tree: Tree = null
var _notes_output: Label = null
var _import_returned_edit: LineEdit = null
var _import_folder_edit: LineEdit = null
var _import_output: CodeEdit = null


func init(dock: Control) -> void:
	_dock = dock


func open() -> void:
	if _window == null:
		_build_window()
	_refresh_notes()
	_window.popup_centered(Vector2i(860, 640))


## The catalog every tab works on. One field owns it (the Extract tab's), so the window can never
## extract into one file and import into another by accident.
func catalog_path() -> String:
	var path: String = _extract_csv_edit.text.strip_edges() if _extract_csv_edit != null else ""
	return path if not path.is_empty() else "res://i18n/strings.csv"


func scan_root() -> String:
	var root: String = _extract_root_edit.text.strip_edges() if _extract_root_edit != null else ""
	return root if not root.is_empty() else "res://"

# ── Window construction ─────────────────────────────────────────────────────────────


func _build_window() -> void:
	_window = Window.new()
	_window.title = "Translation Studio"
	_window.close_requested.connect(func() -> void: _window.hide())
	var tabs: TabContainer = TabContainer.new()
	tabs.set_anchors_preset(Control.PRESET_FULL_RECT)
	tabs.add_child(_build_extract_tab())
	tabs.add_child(_build_notes_tab())
	tabs.add_child(_build_import_tab())
	var body: MarginContainer = EventSheetPopupUI.margined(tabs)
	body.set_anchors_preset(Control.PRESET_FULL_RECT)
	_window.add_child(body)
	EventSheetL10n.apply_to(_window)
	_dock.add_child(_window)


func _build_extract_tab() -> Control:
	var box: VBoxContainer = EventSheetPopupUI.form_box()
	box.name = "Extract"
	box.add_child(EventSheetPopupUI.hint_label("Sweeps every compiled script for the text your game shows, plus the data assets Godot's own POT generation cannot see, and writes one CSV a translator can open in a spreadsheet. Run it as often as you like: cells that are already filled are kept exactly as they are."))
	var form: VBoxContainer = EventSheetPopupUI.form_box()
	_extract_root_edit = LineEdit.new()
	_extract_root_edit.text = "res://"
	form.add_child(EventSheetPopupUI.form_row("Scan", _extract_root_edit, EventSheetPopupUI.LABEL_MIN_WIDTH,
		"Which folder to sweep. The plugin's own code and the bundled behaviour packs are skipped - their strings are not your game's."))
	_extract_csv_edit = LineEdit.new()
	_extract_csv_edit.text = "res://i18n/strings.csv"
	form.add_child(EventSheetPopupUI.form_row("Write to", _extract_csv_edit, EventSheetPopupUI.LABEL_MIN_WIDTH,
		"The translator's file. One row per key, one column per language - the shape Godot imports as a .translation when you drop it in."))
	_extract_notes_check = CheckBox.new()
	_extract_notes_check.button_pressed = true
	_extract_notes_check.text = "Write where each key is used"
	form.add_child(EventSheetPopupUI.form_row("Notes", _extract_notes_check, EventSheetPopupUI.LABEL_MIN_WIDTH,
		"Adds a notes column naming the file, the line, and the row note beside it - the context a translator is otherwise missing."))
	var extract_button: Button = Button.new()
	extract_button.text = "Extract Translatable Strings"
	extract_button.pressed.connect(func() -> void: run_extract())
	form.add_child(extract_button)
	box.add_child(EventSheetPopupUI.titled_card("What to sweep, and where it lands", form))
	var pseudo_form: VBoxContainer = EventSheetPopupUI.form_box()
	pseudo_form.add_child(EventSheetPopupUI.hint_label("A throwaway language made from your own strings: accented, longer, and bracketed. It finds the three bugs a paid translator would have found - labels that clip, text nobody marked (it stays plain on a page of accents), and sentences glued together from pieces (the brackets show the seams)."))
	_pseudo_locale_edit = LineEdit.new()
	_pseudo_locale_edit.text = EventSheetGameCatalog.PSEUDO_LOCALE
	pseudo_form.add_child(EventSheetPopupUI.form_row("Column", _pseudo_locale_edit, EventSheetPopupUI.LABEL_MIN_WIDTH,
		"The locale code for the pseudo column. Godot drops a subtag it does not recognise, so \"qps_ploc\" arrives as \"qps\" - name the column qps and switch to that."))
	_pseudo_expansion = SpinBox.new()
	_pseudo_expansion.min_value = 0.0
	_pseudo_expansion.max_value = 2.0
	_pseudo_expansion.step = 0.05
	_pseudo_expansion.value = EventSheetGameCatalog.DEFAULT_EXPANSION
	pseudo_form.add_child(EventSheetPopupUI.form_row("Expand by", _pseudo_expansion, EventSheetPopupUI.LABEL_MIN_WIDTH,
		"How much longer to make each string, as a fraction. 0.4 is the usual worst case for German."))
	var pseudo_button: Button = Button.new()
	pseudo_button.text = "Generate Pseudo Language"
	pseudo_button.pressed.connect(func() -> void: run_pseudo())
	pseudo_form.add_child(pseudo_button)
	box.add_child(EventSheetPopupUI.titled_card("See it in another language before a translator exists", pseudo_form))
	_extract_output = CodeEdit.new()
	EventSheetPopupUI.configure_code_editor(_extract_output)
	_extract_output.editable = false
	_extract_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var card: PanelContainer = EventSheetPopupUI.titled_card("What happened", _extract_output)
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(card)
	return box


func _build_notes_tab() -> Control:
	var box: VBoxContainer = EventSheetPopupUI.form_box()
	box.name = "Notes"
	box.add_child(EventSheetPopupUI.hint_label("Every key in the catalog with where it is said and how many languages have it. The note is what turns \"Open\" into a sentence a translator can render correctly - is it a verb on a button, or an adjective on a door?"))
	_notes_tree = Tree.new()
	_notes_tree.columns = 3
	_notes_tree.set_column_title(0, "Key")
	_notes_tree.set_column_title(1, "Where it is said")
	_notes_tree.set_column_title(2, "Languages")
	_notes_tree.column_titles_visible = true
	_notes_tree.hide_root = true
	_notes_tree.set_column_expand(2, false)
	_notes_tree.set_column_custom_minimum_width(2, 90)
	_notes_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var tree_card: PanelContainer = EventSheetPopupUI.panel_section(_notes_tree)
	tree_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(tree_card)
	var actions: HBoxContainer = HBoxContainer.new()
	var refresh_button: Button = Button.new()
	refresh_button.text = "Refresh"
	refresh_button.pressed.connect(_refresh_notes)
	actions.add_child(refresh_button)
	var orphan_button: Button = Button.new()
	orphan_button.text = "Find Orphans"
	orphan_button.tooltip_text = "Keys the catalog holds that no script says any more - a renamed string, or a deleted feature. A key your game builds at runtime cannot be seen here, so this is a list to read, never a delete to run."
	orphan_button.pressed.connect(func() -> void: run_orphans())
	actions.add_child(orphan_button)
	box.add_child(actions)
	_notes_output = EventSheetPopupUI.hint_label("")
	box.add_child(EventSheetPopupUI.titled_card("Keys nobody says any more", _notes_output))
	return box


func _build_import_tab() -> Control:
	var box: VBoxContainer = EventSheetPopupUI.form_box()
	box.name = "Import"
	box.add_child(EventSheetPopupUI.hint_label("A translator sent a file back. This merges it into your catalog (blank cells never overwrite anything), says what each language now covers, and registers the catalogs under Localization so the game really speaks them."))
	var form: VBoxContainer = EventSheetPopupUI.form_box()
	_import_returned_edit = LineEdit.new()
	_import_returned_edit.placeholder_text = "res://i18n/returned_fr.csv"
	form.add_child(EventSheetPopupUI.form_row("Returned file", _import_returned_edit, EventSheetPopupUI.LABEL_MIN_WIDTH,
		"The CSV that came back. Its language columns are merged into your catalog; a language your catalog never had becomes a new column."))
	var import_button: Button = Button.new()
	import_button.text = "Import Translations"
	import_button.pressed.connect(func() -> void: run_import())
	form.add_child(import_button)
	var coverage_button: Button = Button.new()
	coverage_button.text = "Report Coverage"
	coverage_button.pressed.connect(func() -> void: run_coverage())
	form.add_child(coverage_button)
	box.add_child(EventSheetPopupUI.titled_card("Merge what came back", form))
	var register_form: VBoxContainer = EventSheetPopupUI.form_box()
	_import_folder_edit = LineEdit.new()
	_import_folder_edit.text = "res://i18n"
	register_form.add_child(EventSheetPopupUI.form_row("Folder", _import_folder_edit, EventSheetPopupUI.LABEL_MIN_WIDTH,
		"Every .translation (or .po) in this folder is added to Project Settings > Localization > Translations. Godot turns a dropped CSV into a .translation for you."))
	var register_button: Button = Button.new()
	register_button.text = "Register Translation Catalogs"
	register_button.pressed.connect(func() -> void: run_register())
	register_form.add_child(register_button)
	box.add_child(EventSheetPopupUI.titled_card("The step everyone forgets", register_form))
	_import_output = CodeEdit.new()
	EventSheetPopupUI.configure_code_editor(_import_output)
	_import_output.editable = false
	_import_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var card: PanelContainer = EventSheetPopupUI.titled_card("What happened", _import_output)
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(card)
	return box

# ── The buttons (each one is exactly what the suite drives) ─────────────────────────


## Sweeps and writes the translator CSV. Returns the outcome the panel shows.
func run_extract() -> Dictionary:
	var include_notes: bool = _extract_notes_check == null or _extract_notes_check.button_pressed
	var outcome: Dictionary = EventSheetTranslationScan.extract(scan_root(), catalog_path(), include_notes)
	_report(_extract_output, outcome)
	_refresh_notes()
	return outcome


## Writes the pseudo column. It refuses a real language's column, so pseudo text can never end up
## in a locale a player picks.
func run_pseudo() -> Dictionary:
	var locale: String = _pseudo_locale_edit.text.strip_edges() if _pseudo_locale_edit != null else EventSheetGameCatalog.PSEUDO_LOCALE
	var expansion: float = float(_pseudo_expansion.value) if _pseudo_expansion != null else EventSheetGameCatalog.DEFAULT_EXPANSION
	var outcome: Dictionary = EventSheetGameCatalog.write_pseudo_column(catalog_path(), locale, expansion)
	_report(_extract_output, outcome)
	return outcome


func run_import() -> Dictionary:
	var returned: String = _import_returned_edit.text.strip_edges() if _import_returned_edit != null else ""
	if returned.is_empty():
		var missing: Dictionary = {"ok": false, "message": "Name the file that came back from the translator."}
		_report(_import_output, missing)
		return missing
	var outcome: Dictionary = EventSheetTranslationScan.import_catalog(returned, catalog_path())
	_report(_import_output, outcome)
	if bool(outcome.get("ok", false)):
		run_coverage()
	return outcome


func run_coverage() -> Array:
	var report: Array = EventSheetTranslationScan.coverage(catalog_path())
	var lines: PackedStringArray = PackedStringArray()
	for entry: Variant in report:
		lines.append(EventSheetTranslationScan.coverage_sentence(entry as Dictionary))
	if lines.is_empty():
		lines.append("%s has no language column yet - one column per language is what a translator fills in." % catalog_path())
	if _import_output != null:
		_import_output.text = "%s\n%s" % [_import_output.text, "\n".join(lines)] if not _import_output.text.is_empty() else "\n".join(lines)
	return report


## `persist` writes the new Translations list to project.godot. The suite drives the same button with
## it off, so a test can never leave a user:// catalog registered in the user's project file.
func run_register(persist: bool = true) -> Dictionary:
	var folder: String = _import_folder_edit.text.strip_edges() if _import_folder_edit != null else ""
	var outcome: Dictionary = EventSheetGameCatalog.register_catalogs(folder, persist)
	_report(_import_output, outcome)
	return outcome


func run_orphans() -> PackedStringArray:
	var orphans: PackedStringArray = EventSheetTranslationScan.orphans(catalog_path(), scan_root())
	if _notes_output != null:
		_notes_output.text = "Every key in the catalog is still said somewhere." if orphans.is_empty() \
			else "%d key(s) translated but emitted by nothing: %s.\nA key your game builds at runtime cannot be seen from here, so read this list rather than acting on it." % [orphans.size(), ", ".join(orphans)]
	return orphans


## Fills the Notes tab from the catalog on disk: the key, its note, and how many languages have it.
func _refresh_notes() -> void:
	if _notes_tree == null:
		return
	_notes_tree.clear()
	var catalog: Dictionary = EventSheetTranslationScan.read_catalog(catalog_path())
	var root: TreeItem = _notes_tree.create_item()
	var locales: PackedStringArray = catalog.get("locales", PackedStringArray())
	for row: Variant in (catalog.get("rows", []) as Array):
		var record: Dictionary = row as Dictionary
		var covered: int = 0
		var countable: int = 0
		for locale: String in locales:
			if locale == EventSheetTranslationScan.SOURCE_COLUMN:
				continue
			countable += 1
			if not str(record.get(locale, "")).strip_edges().is_empty():
				covered += 1
		var item: TreeItem = _notes_tree.create_item(root)
		item.set_text(0, str(record.get(EventSheetTranslationScan.KEY_COLUMN, "")))
		item.set_text(1, str(record.get(EventSheetTranslationScan.NOTES_COLUMN, "")))
		item.set_text(2, "%d / %d" % [covered, countable])


func _report(output: CodeEdit, outcome: Dictionary) -> void:
	var message: String = str(outcome.get("message", ""))
	if output != null:
		output.text = message
	if _dock != null:
		_dock._set_status(message, not bool(outcome.get("ok", false)))
