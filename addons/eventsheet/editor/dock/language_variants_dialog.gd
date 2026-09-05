@tool
class_name EventSheetLanguageVariantsDialog
extends RefCounted
# "Language Variants…" - Godot's own per-locale asset swap, reached from the row that names the
# asset instead of from Project Settings.
#
# The engine feature is genuinely good and simply unreachable from where the work happens: today you
# leave the dock, open Project Settings > Localization > Remaps, and hand-maintain a table of paths
# with no idea which locales you have covered. This writes that table from the row, ticking the
# locales that already have a file beside the base one. Remaps are PATH-level, so art, audio, video,
# fonts and scenes are all served identically - and no row changes at all: the ordinary load() the
# row already does starts returning sign.ja.png once the pair is registered.
#
# AND THE HALF NOBODY CAN SEE BY LOOKING. A remapped asset reached through `preload` resolves when
# the SCRIPT loads, so Set Language swaps the catalog and leaves the art in English. It looks perfect
# in the editor and ships wrong, with no error anywhere. Applying a remap therefore sweeps the
# emitted scripts for that exact preload and says so in the same breath - the emitted code is the
# corpus, because that is where the failure lives.
#
# The table itself lives in EventSheetGameCatalog (remaps / set_remap / variant_path /
# frozen_preloads); this is the form around it, and `apply()` is what the suite drives.

## Only a path that names a FILE can have a language variant - a group name or a node path cannot.
const ASSET_EXTENSIONS: Array[String] = ["png", "jpg", "jpeg", "webp", "svg", "ogg", "wav", "mp3",
	"ogv", "tscn", "scn", "ttf", "otf", "woff", "woff2", "res", "tres", "txt", "json"]

var _dock: Control = null
var _dialog: AcceptDialog = null
var _asset_option: OptionButton = null
var _locales_box: VBoxContainer = null
var _result_label: Label = null
var _checks: Array[CheckBox] = []


func init(dock: Control) -> void:
	_dock = dock


## True for a row that names an asset a language variant could stand in for - the filter the row
## menu asks before it offers the item at all.
static func names_an_asset(resource: Resource) -> bool:
	return not asset_paths_in(resource).is_empty()


## Every res:// file path the row's parameters name, in the order they appear and without repeats.
## An EventRow is asked about its trigger, its conditions and its actions, because the row a user
## right-clicks is the whole event when they click its header.
static func asset_paths_in(resource: Resource) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for text: String in _param_strings(resource):
		for path: String in _paths_in_text(text):
			if not found.has(path):
				found.append(path)
	return found


static func _param_strings(resource: Resource) -> PackedStringArray:
	var strings: PackedStringArray = PackedStringArray()
	if resource == null:
		return strings
	if resource is EventRow:
		var row: EventRow = resource as EventRow
		strings.append_array(_param_strings(row.trigger))
		for condition: Variant in row.conditions:
			strings.append_array(_param_strings(condition as Resource))
		for action: Variant in row.actions:
			strings.append_array(_param_strings(action as Resource))
		return strings
	for property_name: String in ["params", "parameters"]:
		var values: Variant = resource.get(property_name)
		if not (values is Dictionary):
			continue
		for key: Variant in (values as Dictionary).keys():
			strings.append(str((values as Dictionary)[key]))
	return strings


## The res:// paths inside one param value. The value is the author's own GDScript, so the path is
## usually wrapped in quotes and a load() call - the quotes are what bound it.
static func _paths_in_text(text: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var cursor: int = 0
	while true:
		var at: int = text.find("res://", cursor)
		if at == -1:
			break
		var end: int = at
		while end < text.length() and not ["\"", "'", " ", ")", ","].has(text[end]):
			end += 1
		var path: String = text.substr(at, end - at)
		if ASSET_EXTENSIONS.has(path.get_extension().to_lower()) and not found.has(path):
			found.append(path)
		cursor = maxi(end, at + 1)
	return found


## The locales worth offering: the ones the game's own catalog holds a column for, plus whatever
## Godot already has loaded. Never the plugin's own nine UI languages - those are the EDITOR's.
func offered_locales() -> PackedStringArray:
	var locales: PackedStringArray = PackedStringArray()
	if _dock != null:
		for locale: String in _dock._preview_languages():
			if not EventSheetGameCatalog.is_pseudo_locale(locale) and not locales.has(locale):
				locales.append(locale)
	for locale: String in TranslationServer.get_loaded_locales():
		var code: String = str(locale)
		if not code.begins_with("en") and not locales.has(code):
			locales.append(code)
	locales.sort()
	return locales


func open(resource: Resource) -> void:
	var paths: PackedStringArray = asset_paths_in(resource)
	if paths.is_empty():
		if _dock != null:
			_dock._set_status("This row names no file, so there is nothing to swap per language.", true)
		return
	_build_dialog()
	_asset_option.clear()
	for path: String in paths:
		_asset_option.add_item(path)
	_asset_option.select(0)
	refresh_locales()
	_result_label.text = ""
	if _dock != null and _dock.is_inside_tree():
		_dialog.popup_centered(Vector2i(620, 460))


func base_path() -> String:
	if _asset_option == null or _asset_option.selected < 0:
		return ""
	return _asset_option.get_item_text(_asset_option.selected)


## Refills the tick list for the selected asset: a locale is ticked when the remap table already
## names it, and shown as ready when the variant file is really sitting beside the base one.
func refresh_locales() -> void:
	_checks.clear()
	for child: Node in _locales_box.get_children():
		child.queue_free()
		_locales_box.remove_child(child)
	var base: String = base_path()
	var registered: PackedStringArray = EventSheetGameCatalog.remap_locales(base)
	for locale: String in offered_locales():
		var variant: String = EventSheetGameCatalog.variant_path(base, locale)
		var exists: bool = ResourceLoader.exists(variant) or FileAccess.file_exists(variant)
		var check: CheckBox = CheckBox.new()
		check.name = locale
		check.text = "%s - %s" % [locale, variant.get_file() if exists else "%s (not there yet)" % variant.get_file()]
		check.button_pressed = registered.has(locale)
		check.disabled = not exists and not registered.has(locale)
		check.tooltip_text = "Put a file called %s beside the original and this locale becomes tickable." % variant.get_file() \
			if not exists else "The engine returns this file from load(\"%s\") while the game runs in %s." % [base, locale]
		_checks.append(check)
		_locales_box.add_child(check)


## Writes the ticked pairs into Godot's own remap table, and names the preloads that would ignore
## them. `persist` writes project.godot; the suite drives the same button with it off.
func apply(persist: bool = true) -> Dictionary:
	var base: String = base_path()
	var pairs: Dictionary = {}
	for check: CheckBox in _checks:
		if check.button_pressed:
			pairs[check.name] = EventSheetGameCatalog.variant_path(base, str(check.name))
	var outcome: Dictionary = EventSheetGameCatalog.set_remap(base, pairs, persist)
	var frozen: PackedStringArray = EventSheetGameCatalog.frozen_preloads(base, EventSheetProjectDoctor.all_project_scripts())
	if not frozen.is_empty():
		outcome["frozen"] = frozen
		outcome["message"] = "%s\n%s preloads it, so the choice is fixed when that script loads and a live language switch never swaps it - use a plain load() under On Language Changed." % [
			str(outcome.get("message", "")), ", ".join(frozen)]
	if _result_label != null:
		_result_label.text = str(outcome.get("message", ""))
	if _dock != null:
		_dock._set_status(str(outcome.get("message", "")), not bool(outcome.get("ok", false)))
	return outcome


func _build_dialog() -> void:
	if _dialog != null:
		return
	_dialog = AcceptDialog.new()
	_dialog.title = "Language Variants"
	_dialog.ok_button_text = "Register the variants"
	_dialog.confirmed.connect(func() -> void: apply())
	var body: VBoxContainer = EventSheetPopupUI.form_box()
	body.add_child(EventSheetPopupUI.hint_label("Name one file per language and the engine hands the right one to the load() this row already does - no extra rows, no branching. Put the variant beside the original with the locale in its name, like sign.ja.png beside sign.png."))
	var form: VBoxContainer = EventSheetPopupUI.form_box()
	_asset_option = OptionButton.new()
	_asset_option.item_selected.connect(func(_index: int) -> void: refresh_locales())
	form.add_child(EventSheetPopupUI.form_row("Asset", _asset_option, EventSheetPopupUI.LABEL_MIN_WIDTH,
		"The file this row names. Remaps are path-level, so art, audio, video, fonts and whole scenes all work the same way."))
	body.add_child(EventSheetPopupUI.titled_card("Which file", form))
	_locales_box = EventSheetPopupUI.form_box()
	body.add_child(EventSheetPopupUI.titled_card("Which languages", _locales_box))
	_result_label = EventSheetPopupUI.hint_label("")
	body.add_child(EventSheetPopupUI.titled_card("What happened", _result_label))
	_dialog.add_child(EventSheetPopupUI.margined(body))
	EventSheetL10n.apply_to(_dialog)
	_dock.add_child(_dialog)
