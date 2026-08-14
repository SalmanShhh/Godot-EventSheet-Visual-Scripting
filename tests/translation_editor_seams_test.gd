# EventForge - the localisation editor seams, driven the way the buttons drive them.
#
# Five features, one suite. Every case goes through the REAL path (the Studio object's own buttons,
# the grid dialog's `run()`, the dock's preview command, the offer that follows a params commit) and
# is asserted on the resulting FILE or SHEET state - never on "the method exists".
#
#  1. Translation Studio (extract / notes / import): what the sweep finds, what the merge must never
#     clobber, what coverage says, and what the orphan report names.
#  2. The translator's round trip on a grid: the third and fourth modes of the shipped CSV dialog,
#     which write Godot's own `keys,en` catalog and REPORT coverage rather than touching the grid.
#  3. Pseudo-localisation: reversible, never written into a real language's column, and - the case
#     the whole feature exists for - a {slot} that survives the accent pass intact.
#  4. Preview In Language: a lens over the rows, identical to the authored text when it is off.
#  5. The source string IS the key: renaming it moves every translation with it, or refuses out loud.
#
# ENGINE CLAIMS ARE PINNED, NOT ASSUMED. Godot's pseudolocalizer deletes a control character and
# accents "%1$s", so the only escape that survives a round trip is a bare "%s" - the slot cases here
# fail loudly if that ever changes. Nothing in this file writes to project.godot: the two paths that
# really do (the locale test setting, registering catalogs) are driven with their persist flag off.
@tool
class_name TranslationEditorSeamsTest
extends RefCounted

const PROJECT_DIR := "user://eventforge_l10n_project"
const SCRIPT_PATH := "user://eventforge_l10n_project/menu_sheet.gd"
const ASSET_PATH := "user://eventforge_l10n_project/quests.tres"
const CATALOG_PATH := "user://eventforge_l10n_strings.csv"
const RETURNED_PATH := "user://eventforge_l10n_returned_fr.csv"
const GRID_CATALOG_PATH := "user://eventforge_l10n_grid.csv"
## The data-asset fixture for the `key` column sweep: a resource whose grid DECLARES which of its
## columns hold sentences, which is the half of the sweep POT generation cannot see.
const KEY_GRID_DIR := "user://eventforge_l10n_keygrid"
const KEY_GRID_SCRIPT := "user://eventforge_l10n_keygrid/quest_rows.gd"
const KEY_GRID_ASSET := "user://eventforge_l10n_keygrid/quests.tres"
## A right-to-left sentence: it must survive the codec and the accent pass without being mangled,
## because the language that breaks a text pipeline is never the one the team reads.
const RTL_KEY := "احفظ اللعبة"

## The emitted script the sweep reads. This is what a compiled sheet really looks like: the row note
## became the comment above the line, and the marked value became a tr() call.
const EMITTED_SOURCE := """extends Node


func _ready() -> void:
	# The button on the title screen.
	$Play.text = tr("Play")
	$Door.text = tr("Open", "door")
	$Count.text = tr_n("%d apple", "%d apples", 3)
	$Rtl.text = tr("احفظ اللعبة")
	$Quote.text = tr("Say \\"hi\\"")
	# $Dead.text = tr("Cut feature")
	$Path.text = "res://ui/tr(not_a_call).tscn"
	var attr: int = 1
	$Sum.text = str(attr)
"""


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _run_scanner() and all_passed
	all_passed = _run_studio() and all_passed
	all_passed = _run_pseudo() and all_passed
	all_passed = _run_preview() and all_passed
	all_passed = _run_grid_round_trip() and all_passed
	all_passed = _run_key_rename() and all_passed
	all_passed = _run_language_variants() and all_passed
	all_passed = _run_key_column_sweep() and all_passed
	_cleanup()
	# One line on the way out, even when everything passed: a test that prints nothing at all is
	# indistinguishable in the suite log from a test that never ran, which is exactly how broken work
	# looks green here.
	print("[%s] translation_editor_seams_test: 7 seams driven through their real paths" % ("PASS" if all_passed else "FAIL"))
	return all_passed


# ── 8. A column DECLARED as translation keys ─────────────────────────────────


## The `key` column type is what tells the sweep that a grid's cells are sentences rather than ids -
## the half of the Studio's promise that POT generation structurally cannot see, because it only
## reads scripts. It has to survive every parser between the declaration and the sweep: both column
## readers used to flatten it to "String", which left the declaration unreachable and the data-asset
## half of the sweep contributing nothing at all while looking like it worked.
static func _run_key_column_sweep() -> bool:
	var all_passed: bool = true
	var declared: Dictionary = EventSheets.resource_grid(["title: key", "price: float"])
	var columns: Array = EventSheetGridCSV.columns_from_attributes(declared.get("attributes", {}))
	all_passed = _check("a key column survives the sheet-variable reader",
		str((columns[0] as Dictionary).get("type", "")), "key") and all_passed
	all_passed = _check("and a resource's own @export hint reads it back the same way",
		str((EventSheetAttributeDrawers.parse_table_columns("title=key,price=float")[0] as Dictionary).get("type", "")), "key") and all_passed
	all_passed = _check("so the export form offers exactly the declared column",
		", ".join(EventSheetGridCSVDialog.key_columns(columns)), "title") and all_passed
	all_passed = _check("the compiler emits the declaration rather than flattening it",
		SheetCompiler._emit_tree_variable_line(_key_grid_variable()).contains("eventsheet:table:title=key,price=float"), true) and all_passed

	# End to end: a .tres whose grid declares a key column, swept off disk. Every declared cell is a
	# key; the price column is not, and the id column is not, because neither is words.
	DirAccess.make_dir_recursive_absolute(KEY_GRID_DIR)
	var script: GDScript = GDScript.new()
	script.source_code = "@tool\nextends Resource\n\n\n@export_custom(PROPERTY_HINT_NONE, \"eventsheet:table:id=String,title=key,price=float\") var entries: Array = []\n"
	if script.reload() != OK:
		return _check("the key-column fixture compiles", false, true) and all_passed
	ResourceSaver.save(script, KEY_GRID_SCRIPT)
	var asset: Resource = Resource.new()
	asset.set_script(load(KEY_GRID_SCRIPT))
	asset.set("entries", [
		{"id": "lamb", "title": "Find the lost lamb", "price": 10.0},
		{"id": "bell", "title": RTL_KEY, "price": 1.0},
	])
	ResourceSaver.save(asset, KEY_GRID_ASSET)
	var swept: PackedStringArray = PackedStringArray()
	for entry: Variant in EventSheetTranslationScan.scan_data_assets(KEY_GRID_DIR):
		swept.append(str((entry as Dictionary).get("key", "")))
	all_passed = _check("the declared cells are swept as keys, and nothing else on the row is",
		", ".join(swept), "Find the lost lamb, %s" % RTL_KEY) and all_passed
	return all_passed


## The sheet variable behind the emission pin above: one grid, one key column.
static func _key_grid_variable() -> LocalVariable:
	var variable: LocalVariable = LocalVariable.new()
	variable.name = "quests"
	variable.type_name = "Array"
	variable.default_value = []
	# The marker only rides an EXPORTED variable - the hint is what the Inspector drawer reads.
	variable.exported = true
	variable.attributes = (EventSheets.resource_grid(["title: key", "price: float"]) as Dictionary).get("attributes", {})
	return variable


# ── 7. Language variants of an asset (Godot's own remap table) ───────────────


static func _run_language_variants() -> bool:
	var all_passed: bool = true
	# What counts as "a row that names an asset": a FILE path, never a node path or a group name.
	var row: EventRow = EventRow.new()
	var action: ACEAction = ACEAction.new()
	action.params = {"node": "$Sign", "property": "texture", "value": "load(\"res://art/sign.png\")",
		"group": "res://enemies", "sound": "\"res://audio/theme.ogg\""}
	row.actions = [action]
	all_passed = _check("the row's own file paths are found, node paths and extensionless ones are not",
		", ".join(EventSheetLanguageVariantsDialog.asset_paths_in(row)),
		"res://art/sign.png, res://audio/theme.ogg") and all_passed
	all_passed = _check("so the item is offered on that row",
		EventSheetLanguageVariantsDialog.names_an_asset(row), true) and all_passed
	var plain: ACEAction = ACEAction.new()
	plain.params = {"value": "score + 1"}
	all_passed = _check("and never on a row that names no file",
		EventSheetLanguageVariantsDialog.names_an_asset(plain), false) and all_passed
	all_passed = _check("the variant sits beside the original with the locale in its name",
		EventSheetGameCatalog.variant_path("res://art/sign.png", "ja"), "res://art/sign.ja.png") and all_passed
	all_passed = _check("a file with no extension still gets one",
		EventSheetGameCatalog.variant_path("res://art/sign", "ja"), "res://art/sign.ja") and all_passed

	# The remap table itself: Godot's own setting, in the exact shape Project Settings edits.
	var before: Variant = ProjectSettings.get_setting(EventSheetGameCatalog.REMAPS_SETTING, {})
	var wrote: Dictionary = EventSheetGameCatalog.set_remap("res://art/sign.png",
		{"ja": "res://art/sign.ja.png", "fr": "res://art/sign.fr.png"}, false)
	all_passed = _check("the table is written in the shape Project Settings > Remaps edits",
		", ".join(PackedStringArray(EventSheetGameCatalog.remaps()["res://art/sign.png"])),
		"res://art/sign.fr.png:fr, res://art/sign.ja.png:ja") and all_passed
	all_passed = _check("and the locales read back", ", ".join(EventSheetGameCatalog.remap_locales("res://art/sign.png")),
		"fr, ja") and all_passed
	all_passed = _check("the outcome says the rows do not change", str(wrote.get("message", "")),
		"res://art/sign.png now swaps for 2 language(s) - the engine returns the variant from load() with no rows changed.") and all_passed
	EventSheetGameCatalog.set_remap("res://art/sign.png", {}, false)
	all_passed = _check("an empty tick list removes the entry rather than leaving an empty one",
		EventSheetGameCatalog.remaps().has("res://art/sign.png"), false) and all_passed

	# THE finding nobody can see by looking: preload resolves at script load, so a live language
	# switch never swaps it. The corpus is the EMITTED code, because that is where it lives.
	DirAccess.make_dir_recursive_absolute(PROJECT_DIR)
	var frozen_file: FileAccess = FileAccess.open(SCRIPT_PATH, FileAccess.WRITE)
	frozen_file.store_string("extends Node\n\nconst SIGN := preload(\"res://art/sign.png\")\n")
	frozen_file.close()
	var late_file: FileAccess = FileAccess.open("%s/late.gd" % PROJECT_DIR, FileAccess.WRITE)
	late_file.store_string("extends Node\n\nfunc _swap() -> void:\n\t$Sign.texture = load(\"res://art/sign.png\")\n")
	late_file.close()
	var scripts: PackedStringArray = EventSheetTranslationScan.files_under(PROJECT_DIR, ["gd"])
	var frozen: PackedStringArray = EventSheetGameCatalog.frozen_preloads("res://art/sign.png", scripts)
	all_passed = _check("the preload that would ignore the remap is named", ", ".join(frozen), SCRIPT_PATH) and all_passed
	all_passed = _check("and the plain load beside it is not accused", frozen.size(), 1) and all_passed
	DirAccess.remove_absolute("%s/late.gd" % PROJECT_DIR)

	# The dialog: it reads the languages off the GAME's catalog, refuses to tick a variant that is
	# not there, and writes exactly what was ticked.
	EventSheetGridCSV.write_csv(CATALOG_PATH, [{"keys": "Play", "en": "Play", "fr": "Jouer", "ja": ""}],
		[{"name": "keys", "type": "String"}, {"name": "en", "type": "String"},
			{"name": "fr", "type": "String"}, {"name": "ja", "type": "String"}])
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.set_undo_redo_manager(RecordingUndoManager.new())
	editor.setup(EventSheetResource.new())
	editor._translation_studio._build_window()
	editor._translation_studio._extract_csv_edit.text = CATALOG_PATH
	var dialog: EventSheetLanguageVariantsDialog = editor._language_variants_dialog
	dialog.open(row)
	all_passed = _check("the dialog offers the files the row names", dialog.base_path(), "res://art/sign.png") and all_passed
	all_passed = _check("the languages offered are the GAME's, not the editor's own nine",
		", ".join(dialog.offered_locales()).contains("fr"), true) and all_passed
	all_passed = _check("a language whose variant file is not there yet cannot be ticked",
		dialog._checks[0].disabled, true) and all_passed
	all_passed = _check("and it says what to do about that",
		dialog._checks[0].tooltip_text.begins_with("Put a file called sign."), true) and all_passed
	dialog._checks[0].button_pressed = true
	var applied: Dictionary = dialog.apply(false)
	all_passed = _check("applying writes exactly the ticked pair",
		EventSheetGameCatalog.remap_locales("res://art/sign.png").size(), 1) and all_passed
	all_passed = _check("and reports it", str(applied.get("message", "")).contains("now swaps for 1 language(s)"), true) and all_passed
	EventSheetGameCatalog.set_remap("res://art/sign.png", {}, false)
	ProjectSettings.set_setting(EventSheetGameCatalog.REMAPS_SETTING, before)
	editor.free()
	return all_passed


# ── 1. What the sweep finds ──────────────────────────────────────────────────


static func _run_scanner() -> bool:
	var all_passed: bool = true
	var found: Array = EventSheetTranslationScan.keys_in(EMITTED_SOURCE)
	var keys: PackedStringArray = PackedStringArray()
	for entry: Variant in found:
		keys.append(str((entry as Dictionary).get("key", "")))
	all_passed = _check("every marked string is found, in the order the script says them",
		", ".join(keys), "Play, Open, %d apple, احفظ اللعبة, Say \"hi\"") and all_passed
	all_passed = _check("a commented-out row contributes nothing", keys.has("Cut feature"), false) and all_passed
	all_passed = _check("a tr( spelled inside a path literal is not a call", keys.has("not_a_call"), false) and all_passed
	# THE trap the params dialog leaves behind: translatable_parts refuses the context-carrying form,
	# so a scanner built on that rule alone silently skips every one of these keys.
	all_passed = _check("the params dialog still refuses to unwrap a context-carrying value",
		ACEParamsDialog.translatable_parts("tr(\"Open\", \"door\")").get("translatable", false), false) and all_passed
	all_passed = _check("but the sweep reads its context", str((found[1] as Dictionary).get("context", "")), "door") and all_passed
	all_passed = _check("a plural call keeps its second form", str((found[2] as Dictionary).get("plural", "")), "%d apples") and all_passed
	all_passed = _check("the note above the line travels with the key",
		EventSheetTranslationScan.note_above(EMITTED_SOURCE, int((found[0] as Dictionary).get("line", 0))),
		"The button on the title screen.") and all_passed
	# A language with more plural forms than English's two needs a ROW for every form, so both forms
	# of a tr_n become keys in their own right rather than one key with a hidden twin.
	var folded: Dictionary = EventSheetTranslationScan.fold(found)
	all_passed = _check("the plural form is a key a translator can fill in too", folded.has("%d apples"), true) and all_passed
	all_passed = _check("and the singular knows which form it pairs with",
		str((folded["%d apple"] as Dictionary).get("plural", "")), "%d apples") and all_passed
	all_passed = _check("an identifier that merely starts with tr is not a call", folded.has("attr"), false) and all_passed
	return all_passed


# ── 2. The Studio: extract, merge, coverage, import, orphans ─────────────────


static func _run_studio() -> bool:
	var all_passed: bool = true
	_write_project()
	var editor: EventSheetEditor = EventSheetEditor.new()
	var studio: EventSheetTranslationStudio = editor._translation_studio
	studio._build_window()
	studio._extract_root_edit.text = PROJECT_DIR
	studio._extract_csv_edit.text = CATALOG_PATH
	var first: Dictionary = studio.run_extract()
	all_passed = _check("the first extraction writes the catalog", first.get("ok", false), true) and all_passed
	var catalog: Dictionary = EventSheetTranslationScan.read_catalog(CATALOG_PATH)
	all_passed = _check("the file is Godot's own shape - keys first, then the source column",
		", ".join(catalog.get("columns", PackedStringArray())), "keys, en, notes") and all_passed
	all_passed = _check("the source column is seeded from the key, so a translator has a sentence",
		str((catalog.get("by_key", {}).get("Play", {}) as Dictionary).get("en", "")), "Play") and all_passed
	all_passed = _check("the note names where the key is said",
		str((catalog.get("by_key", {}).get("Play", {}) as Dictionary).get("notes", "")),
		"menu_sheet.gd:6 - The button on the title screen.") and all_passed
	all_passed = _check("a right-to-left sentence survives the codec byte for byte",
		catalog.get("by_key", {}).has(RTL_KEY), true) and all_passed
	# The words Godot's POT generation structurally cannot see: a data asset's own stored text.
	all_passed = _check("the .tres sweep finds prose no script says",
		catalog.get("by_key", {}).has("Bandit camp"), true) and all_passed

	# ---- a translator fills a column, and re-extracting must NEVER clobber it ----
	var filled: Dictionary = EventSheetTranslationScan.read_catalog(CATALOG_PATH)
	var rows: Array = []
	var columns: Array = [{"name": "keys", "type": "String"}, {"name": "en", "type": "String"},
		{"name": "fr", "type": "String"}, {"name": "notes", "type": "String"}]
	for row: Variant in (filled.get("rows", []) as Array):
		var record: Dictionary = (row as Dictionary).duplicate()
		record["fr"] = "Jouer" if str(record.get("keys", "")) == "Play" else ""
		rows.append(record)
	rows.append({"keys": "A line we deleted", "en": "A line we deleted", "fr": "Une ligne supprimée", "notes": ""})
	EventSheetGridCSV.write_csv(CATALOG_PATH, rows, columns)
	studio.run_extract()
	var merged: Dictionary = EventSheetTranslationScan.read_catalog(CATALOG_PATH)
	all_passed = _check("a finished cell is exactly as the translator left it",
		str((merged.get("by_key", {}).get("Play", {}) as Dictionary).get("fr", "")), "Jouer") and all_passed
	all_passed = _check("a key no script says any more is KEPT, never deleted on a guess",
		str((merged.get("by_key", {}).get("A line we deleted", {}) as Dictionary).get("fr", "")), "Une ligne supprimée") and all_passed
	all_passed = _check("and the outcome says so in words",
		str(EventSheetTranslationScan.extract(PROJECT_DIR, CATALOG_PATH).get("message", "")).contains("1 no script says any more"), true) and all_passed

	# ---- coverage: a locale with almost nothing in it says exactly how much ----
	var coverage: Array = EventSheetTranslationScan.coverage(CATALOG_PATH)
	var french: Dictionary = _entry_for(coverage, "fr")
	all_passed = _check("coverage counts only the cells a translator really filled",
		int(french.get("covered", 0)), 2) and all_passed
	all_passed = _check("and everything else is named as missing", int(french.get("missing", 0)),
		int(french.get("total", 0)) - 2) and all_passed
	all_passed = _check("the sentence reads the way every other outcome does",
		EventSheetTranslationScan.coverage_sentence({"locale": "ja", "total": 142, "covered": 138, "missing": 4}),
		"ja: 142 key(s), 138 covered, 4 missing.") and all_passed
	all_passed = _check("a finished language says so instead of counting to zero",
		EventSheetTranslationScan.coverage_sentence({"locale": "fr", "total": 12, "covered": 12, "missing": 0}),
		"fr: 12 key(s), all covered.") and all_passed

	# ---- a file comes back: blanks never overwrite, a new language becomes a column ----
	var returned: Array = [
		{"keys": "Play", "fr": "", "de": "Spielen"},
		{"keys": "Open", "fr": "Ouvrir", "de": ""},
		{"keys": "A key from another game", "fr": "Bonjour", "de": ""},
	]
	EventSheetGridCSV.write_csv(RETURNED_PATH, returned,
		[{"name": "keys", "type": "String"}, {"name": "fr", "type": "String"}, {"name": "de", "type": "String"}])
	studio._import_returned_edit.text = RETURNED_PATH
	var imported: Dictionary = studio.run_import()
	var after: Dictionary = EventSheetTranslationScan.read_catalog(CATALOG_PATH)
	all_passed = _check("a blank cell in the returned file leaves the finished one alone",
		str((after.get("by_key", {}).get("Play", {}) as Dictionary).get("fr", "")), "Jouer") and all_passed
	all_passed = _check("a language the catalog never had becomes a column",
		str((after.get("by_key", {}).get("Play", {}) as Dictionary).get("de", "")), "Spielen") and all_passed
	all_passed = _check("and a filled cell lands",
		str((after.get("by_key", {}).get("Open", {}) as Dictionary).get("fr", "")), "Ouvrir") and all_passed
	all_passed = _check("a key from somebody else's file is reported, never invented",
		", ".join(imported.get("unknown", PackedStringArray())), "A key from another game") and all_passed
	all_passed = _check("the import says how many cells it really filled", int(imported.get("filled", 0)), 2) and all_passed

	# ---- orphans: the key nobody says any more ----
	var orphans: PackedStringArray = studio.run_orphans()
	all_passed = _check("the orphan report names the deleted line",
		orphans.has("A line we deleted"), true) and all_passed
	all_passed = _check("and does not accuse a key the game still says", orphans.has("Play"), false) and all_passed
	all_passed = _check("the panel says out loud that a runtime-built key cannot be seen from here",
		studio._notes_output.text.contains("builds at runtime"), true) and all_passed
	# The Notes tab is the provenance a translator actually needs, read from the file on disk.
	studio._refresh_notes()
	var first_item: TreeItem = studio._notes_tree.get_root().get_first_child()
	all_passed = _check("the notes tab shows the key", first_item.get_text(0), "Play") and all_passed
	all_passed = _check("with how many languages have it so far", first_item.get_text(2), "2 / 2") and all_passed

	# ---- registering the catalogs: the step everyone forgets ----
	var registered_before: PackedStringArray = EventSheetGameCatalog.registered_translations()
	studio._import_folder_edit.text = PROJECT_DIR
	var register: Dictionary = studio.run_register(false)
	all_passed = _check("a folder with no compiled catalog in it says so rather than looking busy",
		str(register.get("message", "")), "Nothing new in %s - every catalog there is already registered." % PROJECT_DIR) and all_passed
	all_passed = _check("a folder that is not there answers in words",
		str(EventSheetGameCatalog.register_catalogs("user://eventforge_l10n_nowhere", false).get("message", "")),
		"There is no folder at user://eventforge_l10n_nowhere to register.") and all_passed
	ProjectSettings.set_setting(EventSheetGameCatalog.TRANSLATIONS_SETTING, registered_before)
	editor.free()
	return all_passed


# ── 3. Pseudo-localisation ───────────────────────────────────────────────────


static func _run_pseudo() -> bool:
	var all_passed: bool = true
	all_passed = _check("the pseudo pass is Godot's own - accents, and brackets that show the ends",
		EventSheetGameCatalog.pseudolocalize("Play", 0.0), "[Ṕłáý]") and all_passed
	all_passed = _check("expansion makes the string longer, which is what finds a clipped label",
		EventSheetGameCatalog.pseudolocalize("Press any key to start", 0.4).length() >
		EventSheetGameCatalog.pseudolocalize("Press any key to start", 0.0).length(), true) and all_passed
	# THE case this feature exists for. Godot accents the inside of a {slot} - "{count} of {total}"
	# really does come back as "{ćôüήŧ} ôf́ {ŧôŧáł}" - which would break the format call it feeds.
	all_passed = _check("a {slot} comes back exactly as it went in",
		EventSheetGameCatalog.pseudolocalize("{count} of {total}", 0.0), "[{count} ôf́ {total}]") and all_passed
	all_passed = _check("two different slots do not become the same one",
		EventSheetGameCatalog.pseudolocalize("{a} {b}", 0.0), "[{a} {b}]") and all_passed
	all_passed = _check("a printf placeholder the author wrote survives beside a slot",
		EventSheetGameCatalog.pseudolocalize("%s has {count}", 0.0), "[%s h̀áš {count}]") and all_passed
	all_passed = _check("a right-to-left sentence is not mangled by the accent pass",
		EventSheetGameCatalog.pseudolocalize(RTL_KEY, 0.0).contains(RTL_KEY), true) and all_passed
	all_passed = _check("previewing never leaves the project's own pseudolocalization settings changed",
		float(ProjectSettings.get_setting(EventSheetGameCatalog.PSEUDO_EXPANSION_SETTING, -1.0)), 0.0) and all_passed
	all_passed = _check("the q-range is a test language, not one a player picks",
		EventSheetGameCatalog.is_pseudo_locale("qps_ploc"), true) and all_passed
	all_passed = _check("and French is not", EventSheetGameCatalog.is_pseudo_locale("fr"), false) and all_passed

	# ---- the refusal that matters: pseudo text can never land in a shipped language ----
	var catalog_rows: Array = [{"keys": "Play", "en": "Play", "fr": "Jouer"},
		{"keys": "{count} left", "en": "{count} left", "fr": ""}]
	var columns: Array = [{"name": "keys", "type": "String"}, {"name": "en", "type": "String"},
		{"name": "fr", "type": "String"}]
	EventSheetGridCSV.write_csv(CATALOG_PATH, catalog_rows, columns)
	var refused: Dictionary = EventSheetGameCatalog.write_pseudo_column(CATALOG_PATH, "fr")
	all_passed = _check("writing pseudo into a real language is refused", refused.get("ok", true), false) and all_passed
	all_passed = _check("out loud", str(refused.get("message", "")),
		"\"fr\" is a real language - pseudo text only ever goes in a throwaway column (qps).") and all_passed
	all_passed = _check("and the French cell is untouched",
		str((EventSheetTranslationScan.read_catalog(CATALOG_PATH).get("by_key", {}).get("Play", {}) as Dictionary).get("fr", "")),
		"Jouer") and all_passed
	var wrote: Dictionary = EventSheetGameCatalog.write_pseudo_column(CATALOG_PATH, "qps", 0.0)
	all_passed = _check("the pseudo column is written for every key", int(wrote.get("rows", 0)), 2) and all_passed
	var pseudo_catalog: Dictionary = EventSheetTranslationScan.read_catalog(CATALOG_PATH)
	all_passed = _check("from the source sentence",
		str((pseudo_catalog.get("by_key", {}).get("Play", {}) as Dictionary).get("qps", "")), "[Ṕłáý]") and all_passed
	all_passed = _check("with the slot still intact, so the format call still works",
		str((pseudo_catalog.get("by_key", {}).get("{count} left", {}) as Dictionary).get("qps", "")),
		"[{count} łéf́ŧ]") and all_passed
	all_passed = _check("and the real language beside it is still the translator's",
		str((pseudo_catalog.get("by_key", {}).get("Play", {}) as Dictionary).get("fr", "")), "Jouer") and all_passed
	return all_passed


# ── 4. Preview In Language: a lens, never an edit ────────────────────────────


static func _run_preview() -> bool:
	var all_passed: bool = true
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.set_undo_redo_manager(RecordingUndoManager.new())
	editor.setup(EventSheetResource.new())
	editor._translation_studio._build_window()
	editor._translation_studio._extract_csv_edit.text = CATALOG_PATH
	var languages: PackedStringArray = editor._preview_languages()
	all_passed = _check("the languages offered are the catalog's own columns plus pseudo",
		", ".join(languages), "fr, qps") and all_passed
	var before: String = FileAccess.get_file_as_string(CATALOG_PATH)

	# Off: the identity. This is what makes the whole feature safe to ship on by default.
	all_passed = _check("with no preview a marked value reads exactly as authored",
		EventSheetGameCatalog.preview_param("tr(\"Play\")"), "tr(\"Play\")") and all_passed
	editor._preview_in_language("fr", false)
	all_passed = _check("previewing French renders the translation in the row",
		EventSheetGameCatalog.preview_param("tr(\"Play\")"), "\"Jouer\"") and all_passed
	# The locale with no translation for this key: tr() would return its argument, so the row must
	# read the English it will really ship as - not blank, and not an error.
	all_passed = _check("a key nobody has translated yet falls back to the source sentence",
		EventSheetGameCatalog.preview_param("tr(\"{count} left\")"), "\"{count} left\"") and all_passed
	all_passed = _check("the author's own GDScript is never touched by the preview",
		EventSheetGameCatalog.preview_param("$Player.health"), "$Player.health") and all_passed
	all_passed = _check("nor is a context-carrying value the params dialog refuses to unwrap",
		EventSheetGameCatalog.preview_param("tr(\"Open\", \"door\")"), "tr(\"Open\", \"door\")") and all_passed
	all_passed = _check("the next Play is pointed at the same language",
		EventSheetGameCatalog.test_locale(), "fr") and all_passed
	editor._preview_in_language(EventSheetGameCatalog.PSEUDO_LOCALE, false)
	all_passed = _check("pseudo needs no catalog at all - it is made from the source string",
		EventSheetGameCatalog.preview_param("tr(\"Play\")"), "\"[Ṕłáý]\"") and all_passed

	# Reversible, and nothing was written: the .csv on disk is byte-identical either way.
	editor._preview_in_language("", false)
	all_passed = _check("clearing the preview puts every row back exactly",
		EventSheetGameCatalog.preview_param("tr(\"Play\")"), "tr(\"Play\")") and all_passed
	all_passed = _check("and the catalog on disk was never written to",
		FileAccess.get_file_as_string(CATALOG_PATH), before) and all_passed
	all_passed = _check("the locale test setting is put back too", EventSheetGameCatalog.test_locale(), "") and all_passed
	# Put back means REMOVED, not stored empty: previewing and then picking "As authored" has to leave
	# project.godot exactly as it was found, rather than leaving an empty override in a VCS diff.
	all_passed = _check("and the setting itself is gone, not left standing as an empty string",
		ProjectSettings.has_setting(EventSheetGameCatalog.TEST_LOCALE_SETTING), false) and all_passed

	# The submenu the View menu opens, rebuilt from the catalog on disk each time.
	var menu: PopupMenu = PopupMenu.new()
	editor._preview_language_menu = menu
	editor._rebuild_preview_language_menu()
	all_passed = _check("the way back is always the first item", menu.get_item_text(0), "As authored (English)") and all_passed
	all_passed = _check("and it is the one ticked when nothing is previewed", menu.is_item_checked(0), true) and all_passed
	all_passed = _check("every language column is offered", menu.item_count, languages.size() + 1) and all_passed
	all_passed = _check("pseudo is named for what it finds, not for its locale code",
		menu.get_item_text(menu.item_count - 1), "Pseudo (finds clipped labels)") and all_passed
	menu.free()
	editor.free()
	return all_passed


# ── 5. The translator's round trip on a grid ─────────────────────────────────


static func _run_grid_round_trip() -> bool:
	var all_passed: bool = true
	# Which columns hold words: the ones DECLARED as keys, else every text column (the honest guess
	# the form shows and lets you correct before anything is written).
	all_passed = _check("a declared key column wins", ", ".join(EventSheetGridCSVDialog.key_columns(
		[{"name": "id", "type": "String"}, {"name": "title", "type": "key"}])), "title") and all_passed
	all_passed = _check("with nothing declared, the text columns are the honest guess",
		", ".join(EventSheetGridCSVDialog.key_columns(
			[{"name": "title", "type": "String"}, {"name": "price", "type": "int"}])), "title") and all_passed
	all_passed = _check("a grid of numbers offers nothing to translate",
		EventSheetGridCSVDialog.key_columns([{"name": "price", "type": "int"}]).size(), 0) and all_passed

	var editor: EventSheetEditor = EventSheetEditor.new()
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Resource"
	sheet.variables["quests"] = EventSheets.resource_grid(["title", "reward: int"])
	(sheet.variables["quests"] as Dictionary)["default"] = [
		{"title": "Find the lost lamb", "reward": 10},
		{"title": "Find the lost lamb", "reward": 20},
		{"title": RTL_KEY, "reward": 5},
	]
	editor.set_undo_redo_manager(RecordingUndoManager.new())
	editor.setup(sheet)
	var entry: Dictionary = {"name": "quests", "scope": "global", "type": "Array",
		"attributes": (sheet.variables["quests"] as Dictionary).get("attributes", {})}
	# The two translator items live on the same menu as the designer's, gated the same way.
	editor._variables._context_variable = {"name": "score", "scope": "global", "type": "int", "attributes": {}}
	editor._configure_context_menu(editor._variable_context_menu)
	var text_index: int = editor._variable_context_menu.get_item_index(editor.VARIABLE_MENU_TEXT_EXPORT)
	all_passed = _check("Export Text for Translation is disabled on a plain variable",
		editor._variable_context_menu.is_item_disabled(text_index), true) and all_passed
	editor._variables._context_variable = entry
	editor._configure_context_menu(editor._variable_context_menu)
	all_passed = _check("and enabled on a grid",
		editor._variable_context_menu.is_item_disabled(text_index), false) and all_passed

	var dialog: EventSheetGridCSVDialog = editor._grid_csv_dialog
	dialog.open("translate_export", entry)
	all_passed = _check("the translator's file defaults to a different path from the designer's",
		dialog._csv_edit.text, "res://translations/quests.csv") and all_passed
	all_passed = _check("and the form prefills the columns holding words",
		dialog._key_columns_edit.text, "title") and all_passed
	dialog._csv_edit.text = GRID_CATALOG_PATH
	dialog._asset_edit.text = ""
	var exported: Dictionary = dialog.run()
	all_passed = _check("the export writes Godot's catalog shape, one row per KEY",
		FileAccess.get_file_as_string(GRID_CATALOG_PATH),
		"keys,en\nFind the lost lamb,Find the lost lamb\n%s,%s\n" % [RTL_KEY, RTL_KEY]) and all_passed
	all_passed = _check("a title used by two quests is one key, not two", int(exported.get("rows", 0)), 2) and all_passed
	all_passed = _check("and it says what to do next",
		str(exported.get("message", "")).ends_with("Add a column per language and Godot imports it as a .translation."), true) and all_passed
	all_passed = _check("a first export is all new keys", int(exported.get("rows", 0)), 2) and all_passed

	# The returned file: coverage in words, and NOTHING written back into the grid.
	EventSheetGridCSV.write_csv(GRID_CATALOG_PATH,
		[{"keys": "Find the lost lamb", "en": "Find the lost lamb", "ja": "迷子の子羊を探す"},
			{"keys": RTL_KEY, "en": RTL_KEY, "ja": ""}],
		[{"name": "keys", "type": "String"}, {"name": "en", "type": "String"}, {"name": "ja", "type": "String"}])
	# THE case that costs money: the file now holds a translator's finished ja column, and the
	# designer adds a quest and exports again. The second export must MERGE - a flat write would
	# take every paid column with it, with no undo (a .csv is not on the undo stack).
	var filled: String = FileAccess.get_file_as_string(GRID_CATALOG_PATH)
	(editor._current_sheet.variables["quests"] as Dictionary)["default"] = [
		{"title": "Find the lost lamb", "reward": 10},
		{"title": RTL_KEY, "reward": 5},
		{"title": "Ring the bell", "reward": 1},
	]
	dialog.open("translate_export", entry)
	dialog._csv_edit.text = GRID_CATALOG_PATH
	dialog._asset_edit.text = ""
	var re_exported: Dictionary = dialog.run()
	var merged: Dictionary = EventSheetTranslationScan.read_catalog(GRID_CATALOG_PATH)
	all_passed = _check("re-exporting keeps the translator's finished column",
		str((merged.get("by_key", {}).get("Find the lost lamb", {}) as Dictionary).get("ja", "")),
		"迷子の子羊を探す") and all_passed
	all_passed = _check("...and the language column itself survives",
		", ".join(merged.get("locales", PackedStringArray())), "en, ja") and all_passed
	all_passed = _check("the new quest joined the file", merged.get("by_key", {}).has("Ring the bell"), true) and all_passed
	all_passed = _check("and the report says how much was already there",
		str(re_exported.get("message", "")).contains("1 new, 2 already there and left exactly as they were"), true) and all_passed
	# Put the file back to the two-key shape the coverage report below is about, the same way a
	# translator's returned file arrives.
	EventSheetGridCSV.write_csv(GRID_CATALOG_PATH,
		[{"keys": "Find the lost lamb", "en": "Find the lost lamb", "ja": "迷子の子羊を探す"},
			{"keys": RTL_KEY, "en": RTL_KEY, "ja": ""}],
		[{"name": "keys", "type": "String"}, {"name": "en", "type": "String"}, {"name": "ja", "type": "String"}])
	all_passed = _check("the returned file is the one the coverage report reads",
		FileAccess.get_file_as_string(GRID_CATALOG_PATH), filled) and all_passed
	(editor._current_sheet.variables["quests"] as Dictionary)["default"] = [
		{"title": "Find the lost lamb", "reward": 10},
		{"title": "Find the lost lamb", "reward": 20},
		{"title": RTL_KEY, "reward": 5},
	]
	dialog.open("translate_import", entry)
	dialog._csv_edit.text = GRID_CATALOG_PATH
	dialog._asset_edit.text = ""
	var report: Dictionary = dialog.run()
	all_passed = _check("the import reports coverage in words, never a silent success",
		str(report.get("message", "")), "eventforge_l10n_grid.csv: 2 key(s) in this grid - 1 covered, 1 missing in ja.") and all_passed
	var live_rows: Array = (editor._current_sheet.variables["quests"] as Dictionary).get("default", [])
	all_passed = _check("the grid still holds the keys, not the words",
		str((live_rows[0] as Dictionary).get("title", "")), "Find the lost lamb") and all_passed
	all_passed = _check("nothing was pushed onto the undo stack - the .tres was never touched",
		editor._undo_redo_adapter.has_undo(), false) and all_passed
	# A catalog with no language column yet is a state to name, not a success to report.
	EventSheetGridCSV.write_csv(GRID_CATALOG_PATH, [{"keys": "Find the lost lamb", "en": "Find the lost lamb"}],
		[{"name": "keys", "type": "String"}, {"name": "en", "type": "String"}])
	dialog.open("translate_import", entry)
	dialog._csv_edit.text = GRID_CATALOG_PATH
	dialog._asset_edit.text = ""
	var empty: Dictionary = dialog.run()
	all_passed = _check("a catalog nobody has translated yet says exactly that", empty.get("ok", true), false) and all_passed
	all_passed = _check("in words", str(empty.get("message", "")).ends_with("it is the file a translator fills in, one column per language."), true) and all_passed
	editor.free()
	return all_passed


# ── 6. The source string IS the key ──────────────────────────────────────────


static func _run_key_rename() -> bool:
	var all_passed: bool = true
	# What counts as a key rename, decided on the two values a params commit moved.
	all_passed = _check("editing a marked value is a key rename",
		str(EventSheetTranslationKeyDialog.renamed_key("tr(\"Press any key\")", "tr(\"Press any key to start\")").get("old", "")),
		"Press any key") and all_passed
	all_passed = _check("marking a value that was plain is not a rename - there is no old key",
		EventSheetTranslationKeyDialog.renamed_key("\"Press any key\"", "tr(\"Press any key\")").is_empty(), true) and all_passed
	all_passed = _check("nor is unmarking one",
		EventSheetTranslationKeyDialog.renamed_key("tr(\"Play\")", "\"Play\"").is_empty(), true) and all_passed
	all_passed = _check("nor is an edit that changed nothing",
		EventSheetTranslationKeyDialog.renamed_key("tr(\"Play\")", "tr(\"Play\")").is_empty(), true) and all_passed
	all_passed = _check("a params commit finds the field that moved",
		str(EventSheetTranslationKeyDialog.renamed_key_in(
			{"node": "$Label", "text": "tr(\"Press any key\")"},
			{"node": "$Label", "text": "tr(\"Press any key to start\")"}).get("new", "")),
		"Press any key to start") and all_passed

	# The plan, before anything is touched.
	EventSheetGridCSV.write_csv(CATALOG_PATH, [
		{"keys": "Press any key", "en": "Press any key", "fr": "Appuyez sur une touche", "de": "Taste drücken"},
		{"keys": "Play", "en": "Play", "fr": "Jouer", "de": ""},
	], [{"name": "keys", "type": "String"}, {"name": "en", "type": "String"},
		{"name": "fr", "type": "String"}, {"name": "de", "type": "String"}])
	var paths: PackedStringArray = PackedStringArray([CATALOG_PATH])
	var plan: Dictionary = EventSheetTranslationScan.rename_plan("Press any key", "Press any key to start", paths)
	all_passed = _check("the offer names how many catalogs and which languages change",
		EventSheetTranslationScan.rename_sentence(plan, "Press any key"),
		"1 catalog(s) hold \"Press any key\" (fr, de). Update the key in all of them?") and all_passed
	# The refusal that matters: renaming ONTO a key the catalog already holds would silently merge
	# two sentences into one and lose a translator's work.
	var collision: Dictionary = EventSheetTranslationScan.rename_plan("Press any key", "Play", paths)
	all_passed = _check("renaming onto an existing key is refused, not merged",
		str(collision.get("blocked", "")),
		"%s already holds \"Play\" - renaming onto it would merge two sentences into one." % CATALOG_PATH) and all_passed
	all_passed = _check("and the refusal is what the offer would say",
		EventSheetTranslationScan.rename_sentence(collision, "Press any key"),
		str(collision.get("blocked", ""))) and all_passed
	all_passed = _check("a key no catalog holds is nothing to offer",
		(EventSheetTranslationScan.rename_plan("Never said", "Still not", paths).get("files", []) as Array).size(), 0) and all_passed

	# The commit: every translation of the sentence follows the key.
	var applied: Dictionary = EventSheetTranslationScan.apply_rename("Press any key", "Press any key to start", plan)
	var after: Dictionary = EventSheetTranslationScan.read_catalog(CATALOG_PATH)
	all_passed = _check("the rename lands", applied.get("ok", false), true) and all_passed
	all_passed = _check("the old key is gone", after.get("by_key", {}).has("Press any key"), false) and all_passed
	all_passed = _check("the French translation followed it",
		str((after.get("by_key", {}).get("Press any key to start", {}) as Dictionary).get("fr", "")),
		"Appuyez sur une touche") and all_passed
	all_passed = _check("and the source sentence moved with the key, because the sentence IS the key",
		str((after.get("by_key", {}).get("Press any key to start", {}) as Dictionary).get("en", "")),
		"Press any key to start") and all_passed
	all_passed = _check("the untouched row is untouched",
		str((after.get("by_key", {}).get("Play", {}) as Dictionary).get("fr", "")), "Jouer") and all_passed

	# The offer itself, driven the way the params dialog drives it - and the project with no catalog
	# at all, which must never see a popup.
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor._translation_studio._build_window()
	editor._translation_studio._extract_csv_edit.text = CATALOG_PATH
	var offered: bool = editor._translation_key_dialog.offer("Play", "Start")
	all_passed = _check("the offer appears when a catalog really holds the old key", offered, true) and all_passed
	all_passed = _check("and it says what declining costs",
		editor._translation_key_dialog._message_label.text.contains("Find Orphans"), true) and all_passed
	var committed: Dictionary = editor._translation_key_dialog.confirm()
	all_passed = _check("confirming rewrites the catalog",
		str(EventSheetTranslationScan.read_catalog(CATALOG_PATH).get("by_key", {}).keys()[1]), "Start") and all_passed
	all_passed = _check("and says which file changed",
		str(committed.get("message", "")).begins_with("Renamed \"Play\" to \"Start\" in %s" % CATALOG_PATH), true) and all_passed
	all_passed = _check("a key no catalog holds never pops anything up",
		editor._translation_key_dialog.offer("Play", "Begin"), false) and all_passed
	all_passed = _check("...and says nothing, because there is nothing to say",
		editor._translation_key_dialog.last_refusal, "") and all_passed
	# THE refusal, out loud. Renaming onto a key the catalog already holds cannot be offered, and
	# returning a quiet false is indistinguishable from "no catalog holds this" - so the one case the
	# design calls dangerous would be the one case that produced no message at all.
	EventSheetGridCSV.write_csv(CATALOG_PATH, [
		{"keys": "Press any key", "en": "Press any key", "fr": "Appuyez sur une touche"},
		{"keys": "Press any key to start", "en": "Press any key to start", "fr": "Appuyez pour commencer"},
	], [{"name": "keys", "type": "String"}, {"name": "en", "type": "String"}, {"name": "fr", "type": "String"}])
	all_passed = _check("a rename onto an existing key is not offered",
		editor._translation_key_dialog.offer("Press any key", "Press any key to start"), false) and all_passed
	all_passed = _check("but it IS spoken, naming the file and what happens to the old key",
		editor._translation_key_dialog.last_refusal,
		"%s already holds \"Press any key to start\" - renaming onto it would merge two sentences into one. The row now says the new sentence, and the old key keeps its translations - Translation Studio ▸ Notes ▸ Find Orphans lists it." % CATALOG_PATH) and all_passed
	all_passed = _check("and neither key was touched",
		str((EventSheetTranslationScan.read_catalog(CATALOG_PATH).get("by_key", {}).get("Press any key", {}) as Dictionary).get("fr", "")),
		"Appuyez sur une touche") and all_passed
	editor.free()
	return all_passed


# ── Fixtures ─────────────────────────────────────────────────────────────────


## The emitted script plus a data asset holding prose, which is the half Godot's POT generation
## structurally cannot see because it only scans scripts.
static func _write_project() -> void:
	DirAccess.make_dir_recursive_absolute(PROJECT_DIR)
	var script_file: FileAccess = FileAccess.open(SCRIPT_PATH, FileAccess.WRITE)
	script_file.store_string(EMITTED_SOURCE)
	script_file.close()
	var asset: LootTableResource = LootTableResource.new()
	asset.entries = [{"item": "tr(\"Bandit camp\")", "weight": 1.0, "tags": ""}]
	ResourceSaver.save(asset, ASSET_PATH)


static func _entry_for(report: Array, locale: String) -> Dictionary:
	for entry: Variant in report:
		if str((entry as Dictionary).get("locale", "")) == locale:
			return entry as Dictionary
	return {}


static func _cleanup() -> void:
	EventSheetGameCatalog.clear_preview()
	for path: String in [SCRIPT_PATH, ASSET_PATH, CATALOG_PATH, RETURNED_PATH, GRID_CATALOG_PATH,
			KEY_GRID_ASSET, KEY_GRID_SCRIPT]:
		DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(PROJECT_DIR)
	DirAccess.remove_absolute(KEY_GRID_DIR)


## The editor's undo manager, as the EDITOR's own is shaped: the dock funnels edits through
## create_action / add_do_method / add_undo_method / commit_action, and the commit RUNS the do
## method. A plain UndoRedo takes Callables instead of (object, method, arg), so it silently
## registers nothing - which would make "nothing was pushed onto the undo stack" pass for the wrong
## reason.
class RecordingUndoManager:
	extends RefCounted
	var _pending_do: Array = []
	var _pending_undo: Array = []
	var _stack: Array = []

	func create_action(_action_name: Variant = null) -> void:
		_pending_do = []
		_pending_undo = []

	func add_do_method(target: Variant = null, method: Variant = null, argument: Variant = null) -> void:
		_pending_do = [target, method, argument]

	func add_undo_method(target: Variant = null, method: Variant = null, argument: Variant = null) -> void:
		_pending_undo = [target, method, argument]

	func commit_action() -> void:
		_stack.append(_pending_undo)
		if _pending_do.size() == 3:
			(_pending_do[0] as Object).call(str(_pending_do[1]), _pending_do[2])

	func undo() -> void:
		if _stack.is_empty():
			return
		var entry: Array = _stack.pop_back()
		if entry.size() == 3:
			(entry[0] as Object).call(str(entry[1]), entry[2])

	func has_undo() -> bool:
		return not _stack.is_empty()

	func has_redo() -> bool:
		return false

	func clear_history() -> void:
		_stack.clear()


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("  [FAIL] translation_editor_seams_test: %s (got %s, expected %s)" % [label, str(actual), str(expected)])
	return false
