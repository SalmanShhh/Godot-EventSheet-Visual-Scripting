@tool
class_name EventSheetHeadActions
extends RefCounted
# The gestures on the sheet's HEAD bands - the dock side of the band stack.
#
# Each band of the head stands for exactly one line of the file, so each gesture writes exactly that
# line: F2 on the name band renames the class everywhere, "change…" on the extends band opens the
# host picker, the icon swatch opens a file dialog, the `@tool` switch writes or removes the
# annotation, the description edits in place, and "+ add" offers only the lines this sheet could
# have and does not.
#
# The rewrite itself is `rewrite_prelude()` - pure, static and testable: a block of prelude text and
# one band goes in, the same text with that one line written goes out. Nothing here stores a fact
# anywhere but in the file (and, for a `.tres` sheet whose prelude the compiler writes, in the
# matching sheet field), so a band can never disagree with the line it echoes.

var _dock: Control = null
var _add_menu: PopupMenu = null
var _file_menu: PopupMenu = null
var _add_offers: PackedStringArray = PackedStringArray()
var _rename_dialog: ConfirmationDialog = null
var _text_dialog: ConfirmationDialog = null
var _text_edit: LineEdit = null
var _text_band: String = ""


func init(dock: Control) -> void:
	_dock = dock


## One band's gesture. The viewport names the band; everything a gesture needs (the sheet, the
## dialogs, the undo funnel) lives here.
func handle(action: String) -> void:
	if _dock._current_sheet == null:
		return
	# The bands that stand for a fact of the SCENE name the node they are about after
	# a colon. All of them mean the same gesture: the other editor of that fact - the Replication
	# panel, the Inspector - is over there, so open the scene and select the node. Asked of the band
	# model rather than listed here, so a scene band a later pass adds arrives already clickable.
	# The spawns band is about a FILE rather than about a node of a scene, so its gesture is the one
	# a file wants: show it where it lives. Answered before the loop below because it is the one scene
	# band whose reference is a scene path on its own, with no node inside it to select.
	if action.begins_with("%s:" % EventSheetHeadBands.BAND_SPAWNS):
		browse_to_scene(action.trim_prefix("%s:" % EventSheetHeadBands.BAND_SPAWNS))
		return
	for scene_band: Variant in EventSheetHeadBands.SCENE_BANDS.keys():
		if not action.begins_with("%s:" % scene_band):
			continue
		var reference: String = action.trim_prefix("%s:" % scene_band)
		reveal_scene_node(reference.get_slice("|", 0), reference.get_slice("|", 1))
		return
	match action:
		EventSheetHeadBands.BAND_NAME:
			open_class_rename()
		EventSheetHeadBands.BAND_EXTENDS:
			_dock._open_sheet_type_dialog()
		EventSheetHeadBands.BAND_ICON:
			open_icon_dialog()
		EventSheetHeadBands.BAND_TOOL:
			toggle_tool_mode()
		EventSheetHeadBands.BAND_DESCRIPTION:
			# The band's own line, not the whole doc-comment block: a one-line field cannot hold a
			# block, and seeding it with one would write the block back as a single line.
			_prompt_for_text(EventSheetHeadBands.BAND_DESCRIPTION, "Description",
				EventSheetHeadBands.description_line(_dock._current_sheet.class_description))
		EventSheetHeadBands.BAND_AUTOLOAD:
			_dock._set_status(EventSheetL10n.translate(
				"Project Settings ▸ Autoload is where this name lives - it is not in this file."))
		EventSheetHeadBands.BAND_INCLUDE:
			_dock._set_status(EventSheetL10n.translate(
				"Sheet ▸ Sheet Type… ▸ More is where the included sheets are listed."))
		EventSheetHeadBands.BAND_MODES:
			_dock.open_modes_dialog()
		EventSheetHeadBands.BAND_STATES:
			_dock.open_states_dialog()
		EventSheetHeadBands.BAND_MIGRATION:
			# The one door out of the counting line, and the only place Apply exists. It opens a
			# receipt; nothing is rewritten until somebody reads it and presses the button on it.
			_dock.open_migrate_dialog()
		EventSheetHeadBands.BAND_ATTACH:
			_dock._attach_behavior_to_selection()
		"add":
			open_add_menu()
		"file_options":
			open_file_options()


## Shows a spawned scene where it lives, in Godot's own FileSystem dock. Browsing rather than
## opening on purpose: a spawns band lists several scenes and a click meant "which file is that" far
## more often than it meant "close what I am editing". A band with no file behind it - the one that
## counts the scenes it did not name, or a scene the sheet builds a path for at run time - says so
## rather than doing nothing quietly.
func browse_to_scene(scene_path: String) -> void:
	var path: String = scene_path.strip_edges()
	if path.is_empty():
		_dock._set_status(EventSheetL10n.translate(
			"This one is named by an expression the sheet works out as it runs, so there is no file to show."))
		return
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		var editor_interface: Object = Engine.get_singleton("EditorInterface")
		if editor_interface.has_method("select_file"):
			editor_interface.call("select_file", path)
	_dock._set_status(EventSheetL10n.translate("%s - shown in the FileSystem dock.") % path.get_file())


## Opens the scene a replication fact lives in and selects the node that holds it, so Godot's
## own Replication panel and Inspector open on it. Says so on the status line either way: a node that
## is not there any more is a fact the sheet read from a file somebody has since changed.
func reveal_scene_node(scene_path: String, node_path: String) -> void:
	if EventSheetSceneReplication.reveal_node(scene_path, node_path):
		_dock._set_status(EventSheetL10n.translate("%s selected in %s - its panels are the Inspector and Replication.")
			% [node_path.get_file(), scene_path.get_file()])
		return
	_dock._set_status(EventSheetL10n.translate("%s is not in %s any more.")
		% [node_path.get_file(), scene_path.get_file()], true)


## What a class rename would touch, before anything is written: {"uses": N, "sheets": M}. The count
## is the whole point of the gesture - a rename nobody can see the blast radius of is a rename
## nobody presses.
##
## Counted BY DOING IT: the very walk the button runs, on throwaway copies, so the number before the
## button and the files after it cannot disagree. `extra_sheets` are the open tabs (this sheet among
## them), `skip_paths` files that are not sheets of their own (a `.tres` sheet's generated script),
## and `sheet_paths` the closed sheets to walk - every sheet in the project, both formats, when null.
static func rename_reach(class_name_text: String, extra_sheets: Dictionary = {},
		skip_paths: PackedStringArray = PackedStringArray(), sheet_paths: Variant = null) -> Dictionary:
	var wanted: String = class_name_text.strip_edges()
	if not wanted.is_valid_identifier():
		return {"uses": 0, "sheets": 0}
	var walked: PackedStringArray = sheet_paths if sheet_paths is PackedStringArray \
		else EventSheetProjectFind.list_all_project_sheets()
	var uses: int = 0
	var sheets: int = 0
	# Any other name gives the same count; nothing is written on this walk.
	for entry: Dictionary in rename_class_across(wanted, wanted + "_", extra_sheets, skip_paths,
			walked, false):
		var count: int = int(entry.get("count", 0))
		if count <= 0:
			continue
		uses += count
		sheets += 1
	return {"uses": uses, "sheets": sheets}


## Every sheet that names the class, rewritten by the rename the class line gets: [{path, count,
## open, saved}] in path order. Open tabs (`open_sheets`, {path: sheet}) are rewritten in memory - the
## live version of their file, left unsaved like any other edit. Closed sheets are rewritten and
## SAVED, in both formats: a `.tres` through the same model rename, a `.gd` as the text it is, one
## line at a time with string literals left alone. Each closed file's pre-save bytes go to the backup
## ring first, and `saved` is false for a file that could not be written. Paths in `skip_paths` are
## never touched, and neither is a behaviour pack's script (EventSheetProjectFind.is_pack_script).
## With `write` false the same walk runs on throwaway copies and writes nothing.
static func rename_class_across(old_name: String, new_name: String, open_sheets: Dictionary,
		skip_paths: PackedStringArray, sheet_paths: PackedStringArray, write: bool) -> Array[Dictionary]:
	var done: Array[Dictionary] = []
	if not old_name.is_valid_identifier() or not new_name.is_valid_identifier() or old_name == new_name:
		return done
	var word: RegEx = RegEx.create_from_string("\\b%s\\b" % old_name)
	var paths: PackedStringArray = sheet_paths.duplicate()
	for open_path: Variant in open_sheets.keys():
		if not paths.has(str(open_path)):
			paths.append(str(open_path))
	paths.sort()
	for path: String in paths:
		if path.is_empty() or skip_paths.has(path):
			continue
		if open_sheets.has(path):
			var live: EventSheetResource = open_sheets[path] as EventSheetResource
			if live == null:
				continue
			var target: EventSheetResource = live if write else live.duplicate(true)
			var moved: int = EventSheetRefactor.rename_symbol(target, old_name, new_name, true)
			if moved > 0:
				done.append({"path": path, "count": moved, "open": true, "saved": true})
			continue
		if path.get_extension().to_lower() == "gd":
			if EventSheetProjectFind.is_pack_script(path):
				continue
			var source: String = FileAccess.get_file_as_string(path)
			if word.search(source) == null:
				continue
			var lines: PackedStringArray = source.split("\n")
			var renamed: int = 0
			for index: int in range(lines.size()):
				var before: int = word.search_all(lines[index]).size()
				if before == 0:
					continue
				lines[index] = EventSheetRefactor.rename_in_code(lines[index], old_name, new_name)
				renamed += before - word.search_all(lines[index]).size()
			if renamed <= 0:
				continue
			var written: bool = true
			if write:
				EventSheetBackups.backup_sheet(path)
				written = EventSheetProjectFind.write_script_text(path, "\n".join(lines))
			done.append({"path": path, "count": renamed, "open": false, "saved": written})
			continue
		var closed: EventSheetResource = load(path) as EventSheetResource
		if closed == null:
			continue
		var copy: EventSheetResource = closed if write else closed.duplicate(true)
		var count: int = EventSheetRefactor.rename_symbol(copy, old_name, new_name, true)
		if count <= 0:
			continue
		var saved: bool = true
		if write:
			EventSheetBackups.backup_sheet(path)
			saved = ResourceSaver.save(copy, path) == OK
		done.append({"path": path, "count": count, "open": false, "saved": saved})
	return done


## True when the project already answers to `name` as a type: an engine class, a built-in type, or a
## `class_name` another script declares. Two classes sharing one name is a parse error for every
## script that names it. `own_paths` are this sheet's own files, whose current name is no clash.
static func class_name_taken(name: String, own_paths: PackedStringArray = PackedStringArray()) -> bool:
	if ClassDB.class_exists(name):
		return true
	for type_index: int in range(TYPE_MAX):
		if type_string(type_index) == name:
			return true
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if str(entry.get("class", "")) == name and not own_paths.has(str(entry.get("path", ""))):
			return true
	return false


## The sentence the rename dialog says before it writes anything.
static func rename_reach_text(reach: Dictionary) -> String:
	var uses: int = int(reach.get("uses", 0))
	var sheets: int = int(reach.get("sheets", 0))
	if uses <= 0:
		return EventSheetL10n.translate("renames nothing else - this name is used nowhere yet")
	var use_words: String = EventSheetL10n.translate("renames %d use") % uses if uses == 1 \
		else EventSheetL10n.translate("renames %d uses") % uses
	var sheet_words: String = EventSheetL10n.translate("in %d sheet") % sheets if sheets == 1 \
		else EventSheetL10n.translate("in %d sheets") % sheets
	return "%s %s" % [use_words, sheet_words]


## The head's name band, renamed everywhere: the class line of this file plus every row of every
## sheet that names the class.
## The question names every file the rename will change before it changes any of them, and refuses
## a name that is not a class name or that another class already has.
func open_class_rename() -> void:
	var current: String = _current_class_name()
	var edit: LineEdit = LineEdit.new()
	edit.text = current
	_rename_dialog = load(_dock.SMALL_PROMPT_PATH).open(_dock, {
		# The walk reads every script in the project, so the question shows first and the places
		# follow a frame later - a big project never stalls the click.
		"list": [[EventSheetL10n.translate("Looking for every place it is used..."), ""]],
		"body": EventSheetPopupUI.form_row(EventSheetL10n.translate("Class name"), edit),
		"note": class_rename_note(),
		"main": EventSheetL10n.translate("Rename"),
		"on_main": func() -> void: apply_class_rename_to(edit.text),
	})
	edit.text_changed.connect(func(typed: String) -> void: _sync_class_rename(current, typed))
	_sync_class_rename(current, current)
	if edit.is_inside_tree():
		# After the frame that draws the question, not merely later in the same one.
		RenderingServer.frame_post_draw.connect(fill_class_rename_places.bind(_rename_dialog, current),
			CONNECT_ONE_SHOT)
		edit.grab_focus()
		edit.select_all()


## What Ctrl+Z reaches after a class rename: only this sheet's edit is an undo step. Other open tabs
## are rewritten in memory and left unsaved; closed files are written, each backed up first.
static func class_rename_note() -> String:
	return EventSheetL10n.translate("Ctrl+Z undoes it in this sheet. Other open tabs change and stay unsaved; closed files are saved, each with a backup in Sheet Backups.")


## Lists every file the class rename would change, with its count - the very walk the button runs,
## on throwaway copies. Once per open: retyping the name does not walk the project again.
func fill_class_rename_places(dialog: ConfirmationDialog, current: String) -> void:
	if not is_instance_valid(dialog):
		return
	var places: Array = []
	for entry: Dictionary in rename_class_across(current, current + "_",
			EventSheetFindReferences.open_sheets_of(_dock), _generated_paths(),
			EventSheetProjectFind.list_all_project_sheets(), false):
		var count: int = int(entry.get("count", 0))
		places.append([str(entry.get("path", "")).get_file(),
			EventSheetL10n.translate("1 place") if count == 1 else EventSheetL10n.translate("%d places") % count])
	load(_dock.SMALL_PROMPT_PATH).set_list(dialog, places)


## Words the class-rename question to the name typed so far: the title asks it, the sentence says
## what it will do or why it cannot, and Rename is only pressable for a name it would accept.
func _sync_class_rename(current: String, typed: String) -> void:
	# The question frees itself once it closes; the reference outlives it.
	if not is_instance_valid(_rename_dialog):
		return
	var wanted: String = typed.strip_edges()
	var problem: String = ""
	if not wanted.is_empty() and not EventSheetIdentifierRules.is_valid(wanted):
		problem = EventSheetL10n.translate("\"%s\" cannot be a class name.") % wanted
	elif wanted != current and class_name_taken(wanted, class_name_own_paths()):
		problem = EventSheetL10n.translate("\"%s\" is already the name of another class.") % wanted
	var renaming: bool = problem.is_empty() and not wanted.is_empty() and wanted != current
	_rename_dialog.title = EventSheetL10n.translate("Rename %s to %s?") % [current, wanted] if renaming and not current.is_empty() \
		else EventSheetL10n.translate("Rename %s?") % current if not current.is_empty() \
		else EventSheetL10n.translate("Name this class?")
	(_rename_dialog.find_child("Say", true, false) as Label).text = problem if not problem.is_empty() \
		else EventSheetL10n.translate("%s will be the class name everywhere %s is used.") % [wanted, current] if renaming \
		else EventSheetL10n.translate("Type the new name; every place listed changes with it.")
	_rename_dialog.get_ok_button().disabled = not renaming


## What renaming this sheet's class would touch, as the sentence a rename dialog says before it
## writes anything. Every surface that offers the rename reads it here, so they cannot disagree.
func class_rename_reach_text() -> String:
	return rename_reach_text(
		rename_reach(_current_class_name(), EventSheetFindReferences.open_sheets_of(_dock), _generated_paths()))


## The class name this sheet answers to now: the one its sheet records, else the one its file declares.
func _current_class_name() -> String:
	var current: String = _dock._current_sheet.custom_class_name.strip_edges()
	if current.is_empty():
		current = str(head_facts().get("class_name", ""))
	return current


## Renames the sheet's class to new_name_text and every use with it - the class line, this sheet's
## rows and every other sheet that names it. Every surface that changes the class name comes through
## here, so a relabel can never leave the old name behind in the rows that use it. False when nothing
## was renamed (an empty, invalid or taken name, or the name it already has).
##
## `action_name` and `also` let a dialog that changes more than the name make it ONE undo step:
## `also` runs inside the same edit, after the rename, so a single Ctrl+Z takes back both.
func apply_class_rename_to(new_name_text: String, action_name: String = "Rename Class",
		also: Callable = Callable()) -> bool:
	var new_name: String = new_name_text.strip_edges()
	if new_name.is_empty():
		return false
	if not EventSheetIdentifierRules.is_valid(new_name):
		_dock._set_status(EventSheetL10n.translate("\"%s\" cannot be a class name.") % new_name, true)
		return false
	var old_name: String = _current_class_name()
	if old_name == new_name:
		return false
	var own_paths: PackedStringArray = _own_paths()
	if class_name_taken(new_name, class_name_own_paths()):
		_dock._set_status(EventSheetL10n.translate("\"%s\" is already the name of another class.") % new_name, true)
		return false
	var written: bool = _dock._perform_undoable_sheet_edit(action_name, func() -> bool:
		_write_head_line(EventSheetHeadBands.BAND_NAME, new_name)
		_dock._current_sheet.custom_class_name = new_name
		if not old_name.is_empty():
			EventSheetRefactor.rename_symbol(_dock._current_sheet, old_name, new_name, true)
		if also.is_valid():
			also.call()
		return true
	)
	if not written:
		return false
	# Every OTHER sheet that names the class, in both formats - the sheets the dialog counted. Open
	# tabs change in memory and are left unsaved; closed files are written.
	var elsewhere: Array[Dictionary] = []
	if not old_name.is_empty():
		var skip: PackedStringArray = own_paths.duplicate()
		skip.append_array(_generated_paths())
		elsewhere = rename_class_across(old_name, new_name,
			EventSheetFindReferences.open_sheets_of(_dock), skip,
			EventSheetProjectFind.list_all_project_sheets(), true)
	_mark_open_tabs_unsaved(elsewhere)
	_dock._refresh_after_edit()
	_dock._refresh_title_strip()
	_dock._mark_dirty(EventSheetL10n.translate("Renamed %s to %s.") % [old_name, new_name] \
		+ class_rename_elsewhere_text(old_name, elsewhere))
	return true


## What the status line adds after a class rename: the other files it rewrote, each with its count,
## and - said apart, because it is the part that broke something - any file it could not save.
static func class_rename_elsewhere_text(old_name: String, elsewhere: Array[Dictionary]) -> String:
	var touched: PackedStringArray = PackedStringArray()
	var failed: PackedStringArray = PackedStringArray()
	for entry: Dictionary in elsewhere:
		var file: String = str(entry.get("path", "")).get_file()
		if bool(entry.get("saved", true)):
			touched.append("%s (%d)" % [file, int(entry.get("count", 0))])
		else:
			failed.append(file)
	var text: String = "" if touched.is_empty() else " (%s)" % ", ".join(touched)
	if not failed.is_empty():
		text += " " + EventSheetL10n.translate("Could not save %s - still says %s.") % [
			", ".join(failed), old_name]
	return text


## This sheet's own files: the tab path and, for a sheet opened from a `.gd`, that file. The rename
## of their class line is the undoable edit itself, so the project walk leaves them alone.
func _own_paths() -> PackedStringArray:
	var own: PackedStringArray = PackedStringArray()
	if not str(_dock._current_sheet_path).is_empty():
		own.append(str(_dock._current_sheet_path))
	if not _dock._current_sheet.external_source_path.is_empty():
		own.append(_dock._current_sheet.external_source_path)
	return own


## The files whose `class_name` is this sheet's own, so a name one of them declares is no clash:
## its own files plus, for a `.tres` sheet, the script it compiles to - which still declares the OLD
## name until the next compile, so renaming A to B and straight back to A is not a clash with anybody.
func class_name_own_paths() -> PackedStringArray:
	var own: PackedStringArray = _own_paths()
	own.append_array(_generated_paths())
	return own


## The script a `.tres` sheet compiles to. It is this sheet's own output, not a sheet that uses the
## class, so neither the count nor the walk treats it as one - the next compile rewrites it anyway.
func _generated_paths() -> PackedStringArray:
	var generated: PackedStringArray = PackedStringArray()
	if _dock._current_sheet.external_source_path.is_empty() \
			and not _dock._current_sheet.resource_path.is_empty():
		var output: String = EventSheetSheetDiff.saved_path_for(_dock._current_sheet)
		if not output.is_empty():
			generated.append(output)
	return generated


## Marks each open tab the class rename rewrote in memory as unsaved, so its new text is saved with
## the tab rather than lost when it closes.
func _mark_open_tabs_unsaved(elsewhere: Array[Dictionary]) -> void:
	var open_sheets: Dictionary = EventSheetFindReferences.open_sheets_of(_dock)
	var changed: bool = false
	for entry: Dictionary in elsewhere:
		if not bool(entry.get("open", false)):
			continue
		var sheet: EventSheetResource = open_sheets.get(str(entry.get("path", ""))) as EventSheetResource
		for tab_index: int in range(_dock._open_tabs.size()):
			if _dock._open_tabs[tab_index].get("sheet") == sheet and sheet != null:
				_dock._open_tabs[tab_index]["dirty"] = true
				changed = true
	if changed:
		_dock._refresh_tab_bar()


## The `@icon` band's swatch: a file dialog filtered to images, writing the annotation.
func open_icon_dialog() -> void:
	EventSheetPopupUI.browse_file(_dock, ["*.svg, *.png, *.webp"], func(path: String) -> void:
		apply_band_value(EventSheetHeadBands.BAND_ICON, path))


## The `@tool` band's switch: the annotation goes in or comes out, in one undo step.
func toggle_tool_mode() -> void:
	var switching_on: bool = not _dock._current_sheet.tool_mode
	apply_band_value(EventSheetHeadBands.BAND_TOOL, "true" if switching_on else "false")


## True while the sheet could still gain one of the lines "+ add" offers.
func has_lines_to_add() -> bool:
	if _dock._current_sheet == null:
		return false
	return not EventSheetHeadBands.addable(head_facts()).is_empty()


## "+ add" under the stack (or the canvas menu's "Add to Class Head…" under a quiet class head): only
## the lines this sheet could have and does not.
func open_add_menu() -> void:
	_add_offers = EventSheetHeadBands.addable(head_facts())
	if _add_offers.is_empty():
		return
	if _add_menu == null:
		_add_menu = PopupMenu.new()
		_add_menu.id_pressed.connect(_on_add_menu_pressed)
		_dock.add_child(_add_menu)
	_add_menu.clear()
	for index: int in range(_add_offers.size()):
		_add_menu.add_item(EventSheetHeadBands.add_label(_add_offers[index]), index)
	_add_menu.position = Vector2i(_dock.get_screen_position() + _dock.size * 0.5)
	_add_menu.reset_size()
	_add_menu.popup()


func _on_add_menu_pressed(index: int) -> void:
	if index < 0 or index >= _add_offers.size():
		return
	handle(_add_offers[index])


## What a click on a behaviour's or a global's name offers: the same file in Godot's own script
## editor, or shown where it lives in the FileSystem dock.
func open_file_options() -> void:
	var path: String = str(_dock._current_sheet.external_source_path)
	if path.is_empty():
		return
	if _file_menu == null:
		_file_menu = PopupMenu.new()
		_file_menu.id_pressed.connect(func(id: int) -> void:
			if id == 0:
				_dock._open_generated_in_godot()
			else:
				browse_to_scene(str(_dock._current_sheet.external_source_path)))
		_dock.add_child(_file_menu)
	_file_menu.clear()
	_file_menu.add_item(EventSheetL10n.translate("Open in the script editor"), 0)
	_file_menu.add_item(EventSheetL10n.translate("Show in FileSystem"), 1)
	_file_menu.position = Vector2i(_dock.get_screen_position() + _dock.get_local_mouse_position())
	_file_menu.reset_size()
	_file_menu.popup()


## A one-field prompt for a band whose value is free text (the description). Kept here rather than
## in the Sheet Type dialog so "+ add ▸ description" answers where it was asked.
func _prompt_for_text(band_kind: String, label_text: String, seed_text: String) -> void:
	_text_band = band_kind
	if _text_dialog == null:
		_text_dialog = ConfirmationDialog.new()
		var form: VBoxContainer = EventSheetPopupUI.form_box()
		_text_edit = LineEdit.new()
		form.add_child(EventSheetPopupUI.form_row("Text", _text_edit))
		_text_dialog.add_child(EventSheetPopupUI.margined(form))
		_text_dialog.confirmed.connect(func() -> void: apply_band_value(_text_band, _text_edit.text))
		_dock.add_child(_text_dialog)
	_text_dialog.title = label_text
	_text_edit.text = seed_text
	_text_dialog.popup_centered(Vector2i(460, 0))
	_text_edit.grab_focus()


## Writes one band's line and the sheet field that mirrors it, in one undo step. The sheet field
## exists because a `.tres` sheet has no prelude text of its own - the compiler writes those lines
## from the fields - so both are kept in step and neither can go stale.
func apply_band_value(band_kind: String, new_value: String) -> void:
	if _dock._current_sheet == null:
		return
	var written: bool = _dock._perform_undoable_sheet_edit("Edit Sheet Head", func() -> bool:
		return _write_head_line(band_kind, new_value)
	)
	if not written:
		return
	_dock._refresh_after_edit()
	_dock._refresh_title_strip()
	_dock._mark_dirty(head_status_text(band_kind, new_value))


## What the status line says after a band was written - one sentence per band, so the reader is told
## which line of the file just changed.
static func head_status_text(band_kind: String, new_value: String) -> String:
	match band_kind:
		EventSheetHeadBands.BAND_ICON:
			return EventSheetL10n.translate("Icon set to %s.") % new_value
		EventSheetHeadBands.BAND_TOOL:
			return EventSheetL10n.translate("This sheet runs in the editor too.") if new_value == "true" \
				else EventSheetL10n.translate("This sheet no longer runs in the editor.")
		EventSheetHeadBands.BAND_DESCRIPTION:
			return EventSheetL10n.translate("Description updated.")
		EventSheetHeadBands.BAND_EXTENDS:
			return EventSheetL10n.translate("This sheet now extends %s.") % new_value
		EventSheetHeadBands.BAND_NAME:
			return EventSheetL10n.translate("Renamed to %s.") % new_value
	return EventSheetL10n.translate("Sheet head updated.")


## Writes one band's line into the sheet - the prelude row it lives in for a `.gd` sheet, the
## matching field for both. Runs INSIDE the undo funnel, and re-reads the live sheet rather than
## holding a row from before the edit.
func _write_head_line(band_kind: String, new_value: String) -> bool:
	var sheet: EventSheetResource = _dock._current_sheet
	if sheet == null:
		return false
	match band_kind:
		EventSheetHeadBands.BAND_NAME:
			sheet.custom_class_name = new_value.strip_edges()
		EventSheetHeadBands.BAND_EXTENDS:
			sheet.host_class = new_value.strip_edges()
		EventSheetHeadBands.BAND_ICON:
			sheet.custom_class_icon = new_value.strip_edges()
		EventSheetHeadBands.BAND_TOOL:
			sheet.tool_mode = new_value == "true"
		EventSheetHeadBands.BAND_DESCRIPTION:
			sheet.class_description = EventSheetHeadBands.replace_description_line(
				sheet.class_description, new_value)
	var target: RawCodeRow = _prelude_row_for(sheet, band_kind)
	if target == null:
		return true
	var rewritten: String = rewrite_prelude(target.code, band_kind, new_value)
	if rewritten == target.code:
		return true
	target.code = rewritten
	return true


## The prelude row a band's line lives in: the one already carrying that line, else the identity row
## (the block with `class_name` / `extends`), else the first block of scaffolding. null when this
## sheet has no prelude text at all, which is a `.tres` sheet - its fields are the whole answer.
func _prelude_row_for(sheet: EventSheetResource, band_kind: String) -> RawCodeRow:
	var identity: RawCodeRow = null
	var first: RawCodeRow = null
	for entry: Variant in sheet.events:
		var raw: RawCodeRow = entry as RawCodeRow
		if raw == null or not EventSheetViewport.is_scaffolding_code(raw.code):
			break
		if first == null:
			first = raw
		if _block_carries(raw.code, band_kind):
			return raw
		if identity == null and (raw.code.contains("class_name ") or raw.code.contains("extends ")):
			identity = raw
	return identity if identity != null else first


## True when this block of prelude text already carries the line a band stands for.
static func _block_carries(code: String, band_kind: String) -> bool:
	for raw_line: String in code.split("\n"):
		if EventSheetHeadBands.line_is(raw_line.strip_edges(), band_kind):
			return true
	return false


## One block of prelude text with one band's line written into it: replaced where it is there,
## inserted where GDScript wants it when it is not, removed when the new value is empty (or "false"
## for the `@tool` switch). PURE - the whole head-writing contract, testable without a dock.
static func rewrite_prelude(code: String, band_kind: String, new_value: String) -> String:
	var wanted: String = EventSheetHeadBands.line_text(band_kind, new_value)
	var lines: PackedStringArray = code.split("\n")
	var kept: PackedStringArray = PackedStringArray()
	var replaced: bool = false
	for line: String in lines:
		# ONE line is written: the FIRST the band matches. Every later one is left exactly as it was,
		# because the band never stood for it - a `##` block of several lines is several lines of
		# prose, and dropping the ones the band does not show rewrote a hand-written file behind its
		# author's back, which is the one thing the lossless rule forbids.
		if replaced or not EventSheetHeadBands.line_is(line.strip_edges(), band_kind):
			kept.append(line)
			continue
		replaced = true
		if wanted.is_empty():
			continue  # the line goes away
		kept.append(wanted)
	if wanted.is_empty() or replaced:
		return "\n".join(kept)
	return "\n".join(_insert_head_line(kept, band_kind, wanted))


## Where a line GDScript has rules about goes when the file does not have it yet: `@tool` opens the
## file, `@icon` and the `##` description sit directly above `class_name`, and `class_name` sits
## directly above `extends`.
static func _insert_head_line(lines: PackedStringArray, band_kind: String, wanted: String) -> PackedStringArray:
	var at: int = lines.size()
	match band_kind:
		EventSheetHeadBands.BAND_TOOL:
			at = 0
			while at < lines.size() and lines[at].strip_edges().begins_with("#"):
				at += 1
		EventSheetHeadBands.BAND_NAME:
			at = _index_of_line(lines, EventSheetHeadBands.BAND_EXTENDS, lines.size())
		_:
			at = _index_of_line(lines, EventSheetHeadBands.BAND_NAME,
				_index_of_line(lines, EventSheetHeadBands.BAND_EXTENDS, lines.size()))
	var out: PackedStringArray = PackedStringArray()
	for index: int in range(lines.size()):
		if index == at:
			out.append(wanted)
		out.append(lines[index])
	if at >= lines.size():
		out.append(wanted)
	return out


## The index of the line a band stands for, or `fallback` when the block has no such line.
static func _index_of_line(lines: PackedStringArray, band_kind: String, fallback: int) -> int:
	for index: int in range(lines.size()):
		if EventSheetHeadBands.line_is(lines[index].strip_edges(), band_kind):
			return index
	return fallback


## What the open sheet's head says now - class name, extends, icon, @tool, description, file - read
## the way the bands read it, so every surface that shows one of those lines shows the same value.
func head_facts() -> Dictionary:
	return EventSheetHeadBands.facts(_dock._current_sheet, _prelude_text())


## The sheet's whole prelude as text - what the band model reads.
func _prelude_text() -> String:
	var blocks: PackedStringArray = PackedStringArray()
	if _dock._current_sheet == null:
		return ""
	for entry: Variant in _dock._current_sheet.events:
		var raw: RawCodeRow = entry as RawCodeRow
		if raw == null or not EventSheetViewport.is_scaffolding_code(raw.code):
			break
		blocks.append(raw.code)
	return "\n".join(blocks)
