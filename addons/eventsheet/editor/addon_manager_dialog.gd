@tool
class_name EventSheetAddonManagerDialog
extends AcceptDialog

# Tools > Addon manager: every installed pack in one table.
#
# A pack is a folder, which used to mean "enabling" one was moving it somewhere and there was no
# list with versions anywhere. This is that list: pack, version, enabled, and the three buttons a
# pack ever needs (read its Guide, take its Update, Publish yours). Under the table, the two ways
# a pack arrives (a .zip, a URL), the update sweep, and the door to the Asset Library.
#
# Switching a pack off writes one project setting the scanner reads, so its actions leave the
# picker on the next refresh; the files stay where they are and the sheets using them still open.
# A pack that has not passed the reading check carries its score here ("reads 94%") until it does.

const IMPORT_TARGET := "res://eventsheet_addons"

var _table: VBoxContainer = null
var _status: Label = null
var _zip_dialog: FileDialog = null
var _url_dialog: ConfirmationDialog = null
var _url_edit: LineEdit = null
var _on_registry_changed: Callable = Callable()
var _on_open_guide: Callable = Callable()
var _on_open_sheet: Callable = Callable()
var _on_dry_run: Callable = Callable()
var _update_dialog: EventSheetPackUpdateDialog = null
var _update_zip_dialog: FileDialog = null
## The pack an Update… is being chosen for, held between the file dialog and the proposal.
var _updating: String = ""


func _init() -> void:
	title = "Addon manager"
	ok_button_text = "Close"
	add_child(EventSheetPopupUI.margined(_build_body()))


## `on_registry_changed` is called whenever the installed set or the enabled set changes, so the
## dock can refresh the vocabulary - the picker is the place a reader sees the difference.
## `on_open_guide` takes a Manual page id; `on_open_sheet` takes a script path. Both are the
## dock's, because the window itself knows nothing about the Manual or the tabs. `on_dry_run` takes
## nothing and opens the migrate receipt over the sheet in front of the reader - the door the pack
## update's vocabulary section offers, defaulted so a caller written before it existed still resolves.
func configure(on_registry_changed: Callable, on_open_guide: Callable, on_open_sheet: Callable,
		on_dry_run: Callable = Callable()) -> void:
	_on_registry_changed = on_registry_changed
	_on_open_guide = on_open_guide
	_on_open_sheet = on_open_sheet
	_on_dry_run = on_dry_run


func _build_body() -> Control:
	var page: VBoxContainer = EventSheetPopupUI.form_box()
	page.custom_minimum_size = Vector2(720.0, 420.0)
	_table = VBoxContainer.new()
	_table.add_theme_constant_override("separation", 4)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(700.0, 300.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(_table)
	_table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(EventSheetPopupUI.titled_card("installed packs", scroll))
	var actions: HBoxContainer = HBoxContainer.new()
	actions.add_theme_constant_override("separation", EventSheetPopupUI.ROW_SEPARATION)
	actions.add_child(_action_button("Import from .zip…",
		"Unpacks a pack folder into eventsheet_addons/ after checking that what it publishes reads as sentences.",
		_on_import_zip))
	actions.add_child(_action_button("Import from URL…",
		"Downloads a pack .zip and unpacks it the same way, after the same reading check.",
		_on_import_url))
	actions.add_child(_action_button("Check for updates",
		"Asks every pack that names a published source whether a newer version is out.",
		_on_check_updates))
	actions.add_child(_action_button("Find more (Asset Library)",
		"Opens Godot's Asset Library filtered to event-sheet packs.",
		_on_find_more))
	page.add_child(actions)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(700.0, 0.0)
	page.add_child(_status)
	return page


func _action_button(text: String, tooltip: String, handler: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.tooltip_text = tooltip
	button.pressed.connect(handler)
	return button


## Rebuilds the table from the catalog. Called every time the window opens, so a pack added on
## disk while it was closed is simply there.
func refresh() -> void:
	if _table == null:
		return
	for child: Node in _table.get_children():
		child.queue_free()
	# ONE grid rather than a row of HBoxes: a per-row box sizes to its own contents, so the
	# version and the buttons drifted a few pixels on every second line.
	var grid: GridContainer = GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 4)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(EventSheetPopupUI.small_caps_label("pack"))
	grid.add_child(EventSheetPopupUI.small_caps_label("version"))
	grid.add_child(EventSheetPopupUI.small_caps_label("enabled"))
	grid.add_child(EventSheetPopupUI.small_caps_label("what you can do"))
	grid.add_child(EventSheetPopupUI.small_caps_label("reads"))
	_table.add_child(grid)
	var packs: Array[Dictionary] = EventSheetPackCatalog.packs()
	for pack: Dictionary in packs:
		# The reading score is what the check promised the manager would show. It is cached on
		# each pack file's own mtime, so the sweep costs once per change rather than once per open.
		pack["reads_percent"] = int(EventSheetPackReadingCheck.check_script(
			str(pack.get("path", ""))).get("percent", 100))
		_add_row(grid, pack)
	if packs.is_empty():
		_table.add_child(EventSheetPopupUI.hint_label(
			"No packs installed yet. Import one from a .zip or a URL, or find more in the Asset Library.", 640.0))
	_set_status("%d pack%s installed, %d switched off." % [
		packs.size(), "" if packs.size() == 1 else "s", EventSheetPackCatalog.disabled_packs().size()])


func _add_row(grid: GridContainer, pack: Dictionary) -> void:
	var name_box: VBoxContainer = VBoxContainer.new()
	name_box.add_theme_constant_override("separation", 0)
	name_box.custom_minimum_size = Vector2(225.0, 0.0)
	var name_label: Label = Label.new()
	name_label.text = str(pack.get("name", ""))
	name_label.tooltip_text = str(pack.get("pitch", ""))
	name_label.mouse_filter = Control.MOUSE_FILTER_STOP
	name_box.add_child(name_label)
	var path_label: Label = Label.new()
	path_label.text = "eventsheet_addons/%s" % str(pack.get("dir", ""))
	path_label.modulate = Color(1.0, 1.0, 1.0, 0.6)
	name_box.add_child(path_label)
	grid.add_child(name_box)
	var version_label: Label = Label.new()
	var version: String = str(pack.get("version", "")).strip_edges()
	version_label.text = version if not version.is_empty() else "user pack"
	version_label.custom_minimum_size = Vector2(90.0, 0.0)
	version_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	grid.add_child(version_label)
	var enabled: CheckBox = CheckBox.new()
	enabled.button_pressed = bool(pack.get("enabled", true))
	enabled.tooltip_text = "Off takes this pack's conditions, actions and expressions out of the picker. The files stay, the sheets using them still open, and the Doctor says which ones do."
	var pack_dir: String = str(pack.get("dir", ""))
	enabled.toggled.connect(func(on: bool) -> void: _on_enabled_toggled(pack_dir, on))
	grid.add_child(enabled)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 4)
	buttons.add_child(_action_button("Guide", "Opens this pack's page in the Manual.",
		func() -> void: _open_guide_for(pack_dir)))
	buttons.add_child(_action_button("Update…", "Reads a new version's .zip and shows what it would do to each file of this pack before anything moves.",
		func() -> void: _on_update(pack)))
	buttons.add_child(_action_button("Source", "Asks this pack's published source whether a newer version is out.",
		func() -> void: _on_check_one(pack)))
	buttons.add_child(_action_button("Publish…", "Opens the pack so Publish New Version can run the reading check and bump the version.",
		func() -> void: _on_publish(pack)))
	grid.add_child(buttons)
	var reading: Label = Label.new()
	reading.text = reading_badge_text(pack)
	reading.modulate = Color(1.0, 1.0, 1.0, 0.7)
	reading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	reading.custom_minimum_size = Vector2(70.0, 0.0)
	grid.add_child(reading)


## The score the manager shows beside a pack: "" once it reads, "reads 94%" until it does. Pure,
## so the test can pin it without a window.
static func reading_badge_text(pack: Dictionary) -> String:
	var percent: Variant = pack.get("reads_percent", null)
	if percent == null:
		return ""
	if int(percent) >= 100:
		return ""
	return "reads %d%%" % int(percent)


func _on_enabled_toggled(pack_dir: String, enabled: bool) -> void:
	EventSheetPackCatalog.set_enabled(pack_dir, enabled)
	if _on_registry_changed.is_valid():
		_on_registry_changed.call()
	_set_status("%s is now %s. Its actions %s the picker on the next refresh." % [
		pack_dir, "on" if enabled else "off", "are back in" if enabled else "left"])


func _open_guide_for(pack_dir: String) -> void:
	if _on_open_guide.is_valid():
		_on_open_guide.call("Packs/%s" % pack_dir)
		hide()
		return
	_set_status("The Manual is not open in this window.")


func _on_check_one(pack: Dictionary) -> void:
	var source: String = str(pack.get("source", "")).strip_edges()
	if source.is_empty():
		_set_status("%s names no published source, so there is nowhere to check. A pack says where it lives with ## @ace_source(\"…\")." % str(pack.get("name", "")))
		return
	_set_status("%s publishes from %s - open it to compare with the version installed here (%s)." % [
		str(pack.get("name", "")), source, str(pack.get("version", "unversioned"))])
	OS.shell_open(source)


## Update… - THE PROPOSAL, NEVER THE INSTALL. Reads a new version's .zip and hands it to the update
## window, which lists every file it would touch (and every one it would leave) before the button
## that takes it exists. Nothing is written on the way here.
func _on_update(pack: Dictionary) -> void:
	_updating = str(pack.get("dir", ""))
	if _update_zip_dialog == null:
		_update_zip_dialog = FileDialog.new()
		_update_zip_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_update_zip_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_update_zip_dialog.filters = PackedStringArray(["*.zip ; Pack archive"])
		_update_zip_dialog.title = "Choose the new version's .zip"
		_update_zip_dialog.file_selected.connect(func(path: String) -> void: _set_status(propose_update(path)))
		add_child(_update_zip_dialog)
	_update_zip_dialog.popup_centered(Vector2i(680, 460))


## Opens the update proposal for the pack an Update… was pressed on. Returns the status line, so the
## refusals are pinnable without a window.
func propose_update(zip_path: String) -> String:
	if _updating.is_empty():
		return "No pack chosen to update."
	var folder: String = EventSheetPackManifest.folder_for(_updating)
	var incoming: Dictionary = EventSheetPackUpdate.read_zip(zip_path, _updating)
	if incoming.is_empty():
		return "%s holds no files for %s - an archive that would write outside the pack's own folder is refused whole." % [
			zip_path.get_file(), _updating]
	if _update_dialog == null:
		_update_dialog = EventSheetPackUpdateDialog.new()
		_update_dialog.configure(func(said: String) -> void:
				_set_status(said)
				refresh()
				if _on_registry_changed.is_valid():
					_on_registry_changed.call(),
			# The dry run carries the vocabulary this update WOULD leave, so the receipt it opens is
			# about the new version's forwarding addresses rather than about the packs installed today.
			func(vocabulary: Dictionary) -> void:
				if _on_dry_run.is_valid():
					_on_dry_run.call(vocabulary)
				hide())
		add_child(_update_dialog)
	if not _update_dialog.open_update(folder, incoming):
		return "%s holds no files for %s." % [zip_path.get_file(), _updating]
	_update_dialog.popup_centered(Vector2i(800, 600))
	return "Reading %s against the copy of %s in this project - nothing has moved." % [
		zip_path.get_file(), _updating]


func _on_check_updates() -> void:
	var checked: PackedStringArray = PackedStringArray()
	var skipped: int = 0
	for pack: Dictionary in EventSheetPackCatalog.packs():
		if str(pack.get("source", "")).strip_edges().is_empty():
			skipped += 1
		else:
			checked.append(str(pack.get("name", "")))
	if checked.is_empty():
		_set_status("No installed pack names a published source yet, so there is nothing to compare with. A pack says where it lives with ## @ace_source(\"…\").")
		return
	_set_status("%d pack%s name a published source: %s. %d name none." % [
		checked.size(), "" if checked.size() == 1 else "s", ", ".join(checked), skipped])


func _on_publish(pack: Dictionary) -> void:
	if not _on_open_sheet.is_valid():
		_set_status("Open %s as a sheet, then Sheet > Publish New Version." % str(pack.get("path", "")))
		return
	_on_open_sheet.call(str(pack.get("path", "")))
	hide()


func _on_find_more() -> void:
	OS.shell_open("https://godotengine.org/asset-library/asset?filter=event+sheet")
	_set_status("Opened the Asset Library filtered to event-sheet packs. Download a .zip, then Import from .zip… here.")


func _on_import_zip() -> void:
	if _zip_dialog == null:
		_zip_dialog = FileDialog.new()
		_zip_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_zip_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_zip_dialog.filters = PackedStringArray(["*.zip ; Pack archive"])
		_zip_dialog.title = "Import a pack from a .zip"
		_zip_dialog.file_selected.connect(func(path: String) -> void: _set_status(import_zip(path)))
		add_child(_zip_dialog)
	_zip_dialog.popup_centered(Vector2i(680, 460))


func _on_import_url() -> void:
	if _url_dialog == null:
		_url_dialog = ConfirmationDialog.new()
		_url_dialog.title = "Import a pack from a URL"
		_url_dialog.ok_button_text = "Open"
		var form: VBoxContainer = EventSheetPopupUI.form_box()
		_url_edit = LineEdit.new()
		_url_edit.placeholder_text = "https://…/pack.zip"
		form.add_child(EventSheetPopupUI.form_row("URL", _url_edit, EventSheetPopupUI.LABEL_MIN_WIDTH,
			"The address of a pack .zip. It opens in your browser; the downloaded file imports through Import from .zip…, which runs the reading check before anything lands in eventsheet_addons/."))
		form.add_child(EventSheetPopupUI.hint_label(
			"Nothing is downloaded in the background: the editor opens the address so you can see what you are taking, then you import the file you got.", 460.0))
		_url_dialog.add_child(EventSheetPopupUI.margined(form))
		_url_dialog.confirmed.connect(func() -> void:
			var url: String = _url_edit.text.strip_edges()
			if url.is_empty():
				_set_status("No URL given.")
				return
			OS.shell_open(url)
			_set_status("Opened %s. Import the .zip you downloaded with Import from .zip…." % url)
		)
		add_child(_url_dialog)
	_url_dialog.popup_centered(Vector2i(520, 220))


## Unpacks a pack .zip into eventsheet_addons/. Refuses an archive that would write outside the
## packs folder, and says what it did in the sheet's own words. Returns the status line, so the
## test can pin the refusal without a window.
func import_zip(zip_path: String) -> String:
	var result: String = unpack(zip_path, IMPORT_TARGET)
	refresh()
	if _on_registry_changed.is_valid():
		_on_registry_changed.call()
	return result


## The unpack itself, as a static so it is testable. Every entry must land under `target`; an
## entry with a `..` step or an absolute path is refused and NOTHING is written.
static func unpack(zip_path: String, target: String) -> String:
	if not FileAccess.file_exists(zip_path):
		return "No file at %s." % zip_path
	var reader: ZIPReader = ZIPReader.new()
	if reader.open(zip_path) != OK:
		return "%s is not a readable .zip." % zip_path.get_file()
	var entries: PackedStringArray = reader.get_files()
	for entry: String in entries:
		if not is_safe_entry(entry):
			reader.close()
			return "Refused %s: it writes to \"%s\", which is outside eventsheet_addons/." % [zip_path.get_file(), entry]
	var written: int = 0
	var landed: Dictionary = {}
	for entry: String in entries:
		if entry.ends_with("/"):
			continue
		var destination: String = target.path_join(entry)
		DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
		var file: FileAccess = FileAccess.open(destination, FileAccess.WRITE)
		if file == null:
			continue
		file.store_buffer(reader.read_file(entry))
		file.close()
		written += 1
		var top: String = entry.replace("\\", "/").get_slice("/", 0)
		if top != entry:
			landed[top] = true
	reader.close()
	# THE ATTACH IS WHERE A PACK'S FILES ARE HASHED. A pack is copied into the project on purpose, so
	# a year from now the only way to tell which of its files somebody edited is to have written down
	# what arrived - and the moment it arrives is the only moment that is knowable. No mtimes, no
	# guessing, no second copy kept somewhere: one manifest per pack, holding a content hash per file.
	var stamped: int = 0
	for pack_dir: Variant in landed.keys():
		var folder: String = target.path_join(str(pack_dir))
		if not EventSheetPackManifest.stamp(folder,
				str(EventSheetPackCatalog.describe(str(pack_dir)).get("version", ""))).is_empty():
			stamped += 1
	return "Imported %s - %d file%s under eventsheet_addons/, %d pack%s hashed so a later update can tell your edits from theirs." % [
		zip_path.get_file(), written, "" if written == 1 else "s",
		stamped, "" if stamped == 1 else "s"]


## True when a zip entry may be written under the packs folder: a relative path with no `..` step
## and no drive letter. The one thing standing between an import and someone else's files.
static func is_safe_entry(entry: String) -> bool:
	if entry.is_empty() or entry.begins_with("/") or entry.begins_with("\\") or entry.contains(":"):
		return false
	for part: String in entry.replace("\\", "/").split("/"):
		if part == "..":
			return false
	return true


func _set_status(text: String) -> void:
	if _status != null:
		_status.text = text
